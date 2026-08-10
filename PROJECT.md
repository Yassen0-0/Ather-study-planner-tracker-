# Ather (أثر) — Mastery-Based Learning Platform

> Formerly "سهم / Sahm". The product is unchanged; the brand, the entire visual
> design and the navigation were replaced in the Ather redesign — see the work log in §10.

> ## Standing rule for any AI agent working on this project
>
> **Any AI agent (you or another one) working on this project must:**
> 1. **Read `PROJECT.md` first, before anything else**
> 2. **Update `PROJECT.md` with new details immediately after finishing any work — this is not optional**
> 3. **Check you are on the current design before you touch a pixel** — see below.
>
> ### Before you touch a pixel: confirm the base
>
> The approved design has been reverted **twice** by agents who were following
> instructions correctly. It is not a carelessness problem, it is a setup problem,
> and the setup has now been repaired — but the check is cheap and the failure is
> expensive, so do it anyway:
>
> ```bash
> flutter test test/design_invariants_test.dart
> ```
>
> Green means the tree carries the approved design: **one brand blue**
> (`AppColors.accent`), a tab bar of **four slots with no raised "+"**, and the
> icon-motion layer. Red almost never means the widget it names is broken — it
> means the tree was built on a stale base, and everything you are about to write
> will inherit that.
>
> **What went wrong the first two times, so it is recognisable:**
>
> * The refresh sat on an unmerged branch while `master` kept the design that came
>   before it. Every new worktree was cut from `master` and started wrong.
> * A worktree *directory* was named after the design branch with a *different*
>   branch checked out inside it. The name said "visual refresh"; the code was
>   pre-refresh. Never infer the branch from the directory — run `git branch --show-current`.
> * **This file described the superseded design in detail**, and rule 1 above sends
>   you straight to it. A document that is the source of truth is also the most
>   effective way to teach the wrong thing; §3.27–§3.29 are now the authority on
>   the visual language, and anything elsewhere that contradicts them is stale
>   text that should be fixed rather than obeyed.
>
> The history is a single line with no branches, deliberately (2026-08-10). Keep it
> that way: work on `master`, and if a branch is unavoidable, merge it the same day.

---

## 1. Description and Purpose

Sahm is an offline-first Flutter application for Egyptian Thanaweya Amma students on the
**علمي علوم** track.

It is **not** a to-do app, a habit tracker, or a study timer. It is a mastery-measurement
tool built on one claim:

> «إنت مش بتخلص الدروس... إنت بتتقنها»

Mastery is derived **exclusively from real exam performance**. Time spent studying,
checklist completion, and homework scores never influence it. The student builds their own
curriculum — chapters (أبواب) and lessons (دروس) they name themselves — inside four fixed
subjects, then proves understanding by entering actual exam results question by question.

Mastery **decays**: 30 days after a lesson was last proven, it turns red and must be
re-earned with a fresh exam. There is no "mark as reviewed" button anywhere in the app.

### Target users
Egyptian Thanaweya Amma (علمي علوم) students. Exactly four subjects, fixed and seeded, with
no subject-management UI: أحياء / فيزياء / كيمياء / إنجليزي.

---

## 2. Architecture and Tech Stack

**Clean Architecture**, three layers, dependencies point inward only
(`presentation → domain ← data`).

```
lib/
  main.dart
  app/            app.dart (MaterialApp, theme, locale)   router.dart
  core/
    clock/        clock.dart              injectable time source
    l10n/         app_ar.arb  app_en.arb  generated/
    layout/       breakpoints.dart        window size classes
    theme/        app_colors  app_spacing  app_typography
                  mastery_palette  app_theme
    widgets/      shared presentation primitives
  domain/
    entities/     pure Dart models (no drift, no Flutter)
    services/     mastery_calculator  review_cycle_service  insights_generator
    repositories/ abstract interfaces
  data/
    db/           drift database, tables, DAOs
    repositories/ drift-backed implementations
    seed/         the four fixed subjects
  presentation/   one folder per screen: *_screen.dart, widgets/, *_providers.dart
test/
  domain/  data/  widget/
```

### Stack

| Package | Version | Role |
|---|---|---|
| Flutter / Dart | 3.44.6 / 3.12.2 | SDK |
| `flutter_riverpod` | 3.4.2 | state management |
| `drift` / `drift_flutter` | 2.34.3 / 0.3.1 | SQLite, reactive `.watch()` streams |
| `drift_dev` + `build_runner` | 2.34.0 / 2.15.1 | database codegen |
| `go_router` | 17.3.0 | navigation |
| `fl_chart` | 1.2.0 | analytics charts |
| `flutter_local_notifications` | 22.2.0 | review reminders |
| `timezone` | 0.11.1 | zoned notification scheduling |
| `flutter_localizations` + `intl` | SDK / 0.20.2 | ar + en |
| `shared_preferences` | 2.5.5 | locale and notification prefs |

**Targets:** Android (phone) and Windows (desktop). Not one UI stretched across both — see
§6 Adaptive Layout.

---

## 3. Key Technical Decisions

Decisions are recorded as **chose X over Y because Z**, not as a changelog.

### 3.1 Drift over sqflite
Drift gives compile-time-checked SQL, typed row classes, and `.watch()` streams that push
updates into Riverpod automatically. With sqflite every write would need manual cache
invalidation across the dashboard, subject, chapter and analytics screens — the exact class
of bug where a recorded exam updates one screen but not another.

### 3.2 Exam questions stored as **groups**, not one row per question
*Deviation from the original spec, which typed questions as `List<{points:int}>`.*

The entry flow the spec itself describes is group-shaped: *"5 أسئلة بدرجة واحدة، 3 أسئلة
بدرجتين"*, then *"كام سؤال صح من كل مجموعة"*. Storing one row per question would write N rows
to represent two numbers the student typed, and no screen in the app ever needs an individual
question's identity. `exam_question_groups` holds
`(pointsPerQuestion, questionCount, correctCount)` and is the source of truth.

### 3.3 `needsReview` is **derived**, not stored
*Deviation from the spec's "mark the lesson as `needsReview = true`".*

A stored boolean is only as fresh as the last time the app ran its daily check. If the
student does not open the app for a week, a stored flag is wrong for that entire week.
Derived from `lastReviewedAt` it is correct the instant any widget reads it:

```dart
bool needsReview(Lesson l, DateTime now) =>
    l.lastReviewedAt != null && now.difference(l.lastReviewedAt!).inDays >= 30;
```

`lastNotifiedAt` *is* stored — but that is notification bookkeeping to prevent duplicate
reminders, not review state.

A lesson with `lastReviewedAt == null` (never examined) is **not** red. Red means *decayed*,
not *untouched*.

### 3.4 The celebration is one green disc, not a particle system
The previous build hand-simulated ~120 confetti particles over a black screen. The Ather
design replaced it with a full white screen, a single green disc that pops once, and the
percentage earned. Removed rather than toned down: the moment is about the number the student
proved, and an animation competing with it is the app celebrating itself.

### 3.5 Readex Pro bundled as a **variable** font asset, not `google_fonts`
Two decisions in one:

- **Bundled, not `google_fonts`:** the app is fully offline. `google_fonts` fetches over the
  network on first use and silently falls back to a Latin default when offline — unacceptable
  for an Arabic-first UI.
- **Variable, not static weights:** one file carries the whole 200–700 `wght` axis.
  **Consequence:** Flutter will not synthesise weights for a variable font from
  `TextStyle.fontWeight` alone — the axis must be driven via `TextStyle.fontVariations`, or
  the entire type hierarchy silently renders at one weight. `AppTypography.style()` sets both
  and is the only place allowed to construct a text style.
- **Never above 700.** The axis stops there; asking for 800 makes Flutter fake a weight, which
  reads coarse beside real 700.

### 3.6 Riverpod without code generation
`riverpod_generator` 4.x requires `analyzer ^13.0.0`; `drift_dev` requires an older analyzer.
They cannot coexist in one pubspec — pub version solving fails outright. `drift_dev` is
non-negotiable (it generates the database), so Riverpod providers are written manually.
Riverpod 3.x supports this fully; the only cost is a little boilerplate.

Related: `build_runner 2.16.0` needs `meta ^1.18.3` while the Flutter SDK pins `meta 1.18.0`,
so `build_runner` is held at 2.15.1.

### 3.7 Riverpod 3.x removed `StateProvider`
Simple mutable state uses `Notifier` + `NotifierProvider` instead (see `LocaleNotifier`).

### 3.8 Injectable `Clock`
The 30-day decay cycle is the core mechanic. A hard-coded `DateTime.now()` would make it
untestable without waiting a month. Everything that asks the time goes through `Clock`, so
tests pin the date and a debug tool fast-forwards it.

### 3.9 Checklist as five boolean columns, not a child table
The spec fixes exactly five study steps with no add/remove. A child table would add a join
and an ordering problem for zero flexibility gained.

### 3.10 Two themes from one description, and no shadows anywhere
The app ships light and dark (§7b). They are **one theme built twice**: `AppTheme._build` is the
only description of what an Ather surface looks like, and `light`/`dark` differ solely by the
`AppColors` handed to it, so a radius or a button height can only ever be changed in one place.

The depth system survives the second scheme intact. Depth is "a card on a page of a different
value" — in light a white card on `#EFEFF2`, in dark a `#1C1C1E` card on black — and nothing
else. `shadowColor` is transparent at theme level and Material's ink splash is switched off, so
a stray `Card` or `InkWell` cannot reintroduce either. The one shadow in the app is the switch
knob — without a lift it reads as a painted dot rather than a control.

*(This reverses the earlier decision to delete the dark theme. The claim then was that a second
surface scheme would have nothing to build depth from; that turned out to be wrong — inverting
the value ramp while keeping its **ordering** preserves every "quieter than" relationship the
design relies on, so the dark theme is a re-mapping rather than a redesign.)*

The palette is white + grey + black plus exactly **one blue** (`AppColors.accent` — `#4D9BFF`
dark / `#1B6EF3` light), **one red** (`#FF3B30`, wrong / weak / overdue / delete) and **one
green** (`#34C759`, right / mastered). No subject colours, no four-step mastery spectrum, no
gradients, no blur.

**The blue and the two state colours are different vocabularies, and they never mix** (§3.27).
Blue means *active*: the selected tab, a progress fill, a ticked box, a primary button, the
mark's arc. Red and green are verdicts about the work. A score in the middle is still simply a
number — blue is a fill, not a fifth mastery band, and `MasteryPalette.resolve` (the number)
and `MasteryPalette.fill` (the bar under it) are what keep those apart.

### 3.11 Unproven is not the same as weak
Mastery is 0 for anything unexamined, so the naive mapping paints a brand-new install
alarm-red across all four subjects — telling a student who has done nothing wrong that they
are failing. `MasteryPalette.resolve` therefore takes `hasData`, and renders neutral grey with
an em-dash instead of `0%` wherever no exam exists. Precedence is: **no data → grey**, then
**decayed → red**, then the mastery band. *(Found by looking at the first real screenshot on
the emulator, not by reading the code.)*

### 3.12 Hand-drawn icons instead of the Material set
The design allows one icon family: outline strokes at 1.7–2.2, black, grey or accent, 15–26px.
The
Material set is a different family with a different optical weight, and mixing the two was one
of the things the redesign set out to remove. `AtherIcon` draws the seventeen glyphs the
product actually needs from the design's own path data.

### 3.13 `Spacer` beside a `Flexible` splits the leftover width
On the summary cards, `Spacer` (an `Expanded`, flex 1) next to a `Flexible` (flex 1) shared
the leftover space evenly, wrapping "1 من 4 باب اتقنتها" onto two cramped lines. The layout is
a fixed number plus a single `Expanded` aligned to the end. *(Found by rendering the screen,
not by reading the code.)*

### 3.14 Core library desugaring enabled
`flutter_local_notifications` uses `java.time` APIs absent below API 26. Without
`isCoreLibraryDesugaringEnabled` plus `desugar_jdk_libs`, the Android build fails outright at
`:app:checkDebugAarMetadata`.

### 3.15 Inexact notification scheduling
`AndroidScheduleMode.inexactAllowWhileIdle`, and `SCHEDULE_EXACT_ALARM` is deliberately not
declared. Play treats exact alarms as a restricted permission, and a study reminder does not
justify it — delivery within the hour is fine for a 30-day cycle.

### 3.15a The reminders had never been switched on — two missing pieces, both silent
*Found 2026-08-10 by the audit in §10, and this is the entry to read before touching
notifications again.*

Every reminder in the app's history failed for two independent reasons, neither of which produced
an error anywhere:

1. **Nothing ever asked for the permission.** `permissionGranted` started `false` and was only
   ever set by `requestPermission()`, which **had no call site in `lib/` or `test/`**.
   `reschedule()` opens with `cancelAll()` and then returns early on that flag, so every pass
   cancelled the (empty) schedule and booked nothing. The manifest comment cheerfully described
   the intended call site — "at the moment the student masters their first chapter" — for code
   that was never written.
2. **The receivers were not declared.** Since `flutter_local_notifications` 16 the plugin's own
   manifest ships **permissions only** — verified against the copy in the pub cache, which
   contains nothing but `POST_NOTIFICATIONS` and `VIBRATE`. Without
   `ScheduledNotificationReceiver` in the app manifest, `zonedSchedule` succeeds, the alarm
   fires, and nothing is shown. `ScheduledNotificationBootReceiver` is what makes
   `RECEIVE_BOOT_COMPLETED` (declared since day one) mean anything; a 30-day cycle crosses at
   least one reboot or app update.

The fixes, and the rules that come with them:

- **`refreshPermission()` reads the OS on every sync** rather than trusting a flag. That is what
  lets a student who granted the permission months ago keep their reminders without being asked
  again, and what notices one revoked in system settings. A boolean that can only be set by a
  call that does not exist is indistinguishable from a feature that was never wired — so it is
  no longer the only way the flag can become true.
- **`requestPermission()` is called at two moments where the value is obvious**: the student
  turning the switch on in Settings, and the first recorded exam — the moment the first 30-day
  clock actually starts. Not on cold start, which is the original reasoning and still right.
- **The switch and the OS can disagree, and the card says so.** `osNotificationsAllowedProvider`
  is separate from `notificationsEnabledProvider`, and Settings shows a line when the preference
  is on but Android refuses. It is suppressed until `hasScheduledReviewsProvider` is true: on a
  fresh install nothing has a review clock yet, so the warning would describe a problem the
  student does not have.
- **Rescheduling is debounced 5s** (`ReviewScheduler`) with a re-entrancy guard. It is
  `cancelAll()` plus one platform round trip *per lesson*, and it was firing on every snapshot
  emission — so ticking one checklist box rebuilt a few hundred alarms. Two overlapping passes
  could also interleave a `cancelAll()` with the other's writes; `_running`/`_dirty` prevent it.
  The resume pass stays immediate: it is the one that has to be correct before the app is next
  backgrounded.
- **Tapping a reminder opens its lesson.** The payload was already written and parsed, then
  handed to an empty callback.

**Still unverified:** no reminder has been observed arriving on a device. Both defects above were
found by reading, not by watching one fail, and the fix deserves the same scepticism — see §9.

### 3.16 Western digits (0123) in both locales
Egyptian students read exam scores in Western numerals. Mixing digit systems between ar and en
would make the same score look like two different numbers.

### 3.17 Accounts, without giving up offline-first
Adding Firebase Auth to an app documented as "no accounts, no server, no network requests"
is a real contradiction, and it was resolved rather than ignored:

- **The gate is asked once.** A student signs in the first time and never again. Firebase
  caches the session on disk, `Firebase.initializeApp` restores it with no network call, and
  the router's redirect reads that cached answer synchronously. A signed-in student opens the
  app in airplane mode and everything works — verified by pulling the network, not assumed.
- **`Firebase.initializeApp` is wrapped in a try/catch.** Initialisation must never be the
  thing standing between a student and study data that is sitting on their own phone.
- ~~**No study data moved.**~~ **This is no longer true — see §3.26.** It was true when
  accounts were added, and the "future migration to per-account cloud sync" it named as a
  separate decision was taken on 2026-08-05. What survives unchanged is the part that
  mattered: **local SQLite is still the source of truth, the network is never on a read path,
  and the app is fully usable with the backup layer failing on every call** (asserted in
  `test/widget/backup_test.dart`). The cloud holds a mirror, not a second master.
- **`AuthFailure` is a structured enum, never a message string** — same reason as `Insight`:
  the data layer has no localisation, so an English Firebase error could never reach an Arabic
  student. Wrong password and unknown account collapse into one case on purpose; telling an
  attacker which emails are registered is a gift, and the student's next action is identical.

### 3.18 The biometric lock releases rather than traps — **but only when the device cannot answer**
*Rewritten 2026-08-05. The original rule was too broad and made the lock decorative.*

The lock was skippable two ways, both reported from a real phone:

1. **Every failure released it.** One `catch` around `authenticate` set `unlocked = true`, so a
   cancelled prompt, a refusal, and a too-many-attempts lockout all opened the app. The rule
   below was written for "the sensor can never say yes" and was being applied to "the student
   did not say yes".
2. **The back button walked straight past it.** The lock is a gate above the router rather than
   a route (§3.19's sheets and the wizard are why), so a back press had nothing to pop and fell
   through to the router underneath.

The rule now: **only codes that mean this device can never authenticate release the lock** —
`noBiometricHardware`, `noBiometricsEnrolled`, `noCredentialsSet` — and nothing else.
`LocalAuthExceptionCode` documents itself as open to new values, so a `default` that released
would hand every future code a way in. `uiUnavailable`, the modern spelling of §3.18's original
`no_fragment_activity` bug, is deliberately **not** on the list: releasing on it is exactly how
that misconfiguration hid for a whole release.

The student is still not trapped, which was the original point: `biometricOnly: false` means the
OS offers the device PIN or pattern on the same prompt, and a lockout says so in words.

Back is swallowed by `LockAwareBackButtonDispatcher` in `app.dart`. Neither usual guard works
from above the router — `PopScope` needs a `ModalRoute`, `BackButtonListener` needs a `Router`
ancestor and throws without one — so the dispatcher, the one thing above the router that sees
the press, is where it is enforced. That is also why `MaterialApp.router` is now given the
router's three parts individually instead of `routerConfig`: GoRouter hard-codes its own
`RootBackButtonDispatcher`, and a config and a dispatcher cannot both be supplied.

`test/widget/lock_test.dart` covers all seven paths against a `FakeLocalAuth`. None of this was
assertable before, because the lock only ever talked to the real platform — which is how it
shipped bypassable.

### 3.18a The original reasoning, still true for the release case
The fingerprint lock is a privacy convenience over data that is already behind the device's
own lock — it is not a security boundary. So when the sensor cannot answer (no enrolled print,
hardware failure, a restored device), `LockScreen` **unlocks**. The alternative is holding a
student's own study record hostage behind a sensor that will never say yes.

For the same reason the switch is only offered where `getAvailableBiometrics()` reports an
enrolled print, and the lock re-arms on `paused` rather than `resumed`: by the time an app is
resumed its content has already been composited into the task-switcher thumbnail.

**`MainActivity` must extend `FlutterFragmentActivity`.** `local_auth` raises the prompt via
AndroidX `BiometricPrompt`, which needs a `FragmentActivity` host; the default
`FlutterActivity` is not one, and the plugin throws `no_fragment_activity` the moment it is
called. That combined badly with the release-on-failure rule above: the app opened normally,
so a completely broken integration looked exactly like "this device has no fingerprint". The
catch now logs before releasing — a safe fallback that hides its own cause is a trap.

### 3.19 The tab bar is glass — a bounded exception to §3.10's blur ban
§3.10 rules out blur along with gradients and a second surface scheme. That ban still holds
everywhere except one surface: the bottom tab bar, approved explicitly by the owner. It is the
only place a student's own content passes *underneath* a chrome element, so it is the only
place depth carries information rather than decoration.

The exception is deliberately narrow, and every bound is enforced in `app_shell.dart`:

- **Exactly one `BackdropFilter` in the app.** Never inside a list item — a blur per row is a
  blur per frame per row.
- **`ClipRect` is mandatory.** Unbounded, a `BackdropFilter` blurs the entire layer tree.
- **The sigma is never animated** (`AppMotion.glassSigma = 24`). Animating a blur radius drops
  frames on the phones these students own. If the bar ever needs to react to scroll, the tint
  alpha is the thing to animate, not the blur.
- **Nothing is drawn outside the clip.** The raised "+" was the only thing that ever was, and
  it is gone (§3.28); the bar is now exactly the pill.
- **Platform-gated, never reduce-motion-gated.** `canBlur` is Android/iOS only. Blur is a
  *visual effect*, not motion: `disableAnimations` owns fades, scales, slides and pops, and a
  student who turns reduce-motion on because scrolling makes them ill has no reason to lose a
  frosted bar. Everywhere else, the opaque bar the app shipped with.

**Contrast, measured rather than assumed.** The inactive tab label is `#9A9AA0`. On today's
opaque white bar that is **2.80 : 1**; through the 0.72 white tint over a page or a card it is
**2.55 – 2.80 : 1**, because everything that passes under the bar in the light theme is
lighter than the tint. In the dark theme the bar tints toward the dark card instead, so the same
relationship holds inverted. Glass does not make it worse. The one real failure would be the black
toast passing underneath at **1.5 : 1** — which cannot happen, because the toast is pinned at
`bottom: 104`, clear of the bar. That constant is now load-bearing and says so in a comment.

Separately, and out of this work's scope: 2.80 : 1 at 11px already fails WCAG AA. That is a
pre-existing token decision, unchanged here, but it is written down now.

`AppShell` sets `extendBody: true` so the list actually scrolls under the bar — otherwise
there is nothing to blur — and `AtherScreen` adds the bar's height back as list padding, plus
real space under any pinned bottom button. A button may not sit behind glass.

### 3.20 A deleted row collapses — the one place height animates
§3.4 removed the confetti; the standing rule that came with it is that motion animates
`transform` and `opacity` only, never layout. Animating `height`, `padding` or flex weights in
a scrolling list is what causes jank on a mid-range Android.

One exception, approved with the motion spec: **a row leaving a list fades while its height
shrinks**, so the rows below settle into the gap instead of teleporting up. It lives in
`core/widgets/collapsing_removal.dart`, built on `AnimatedList` because the collapse has to be
*rendered* — the widget must outlive its record by 200ms.

It is data-driven, not button-driven: nothing in this app deletes a row from inside the list. A
student opens the chapter, deletes it there and pops back, so the removal arrives as a shorter
list on the next build. `CollapsingList` is what turns that into a collapse.

Everything else still animates transform and opacity only. No shrinking headers, no expanding
cards, no animated padding. An unrecorded exception becomes a licence for the next one.

### 3.21 Motion tokens, and why they are all under 300ms
`AppMotion` carries every duration and curve; no widget declares its own. The spec added one
curve — `standard = Cubic(0.23, 1, 0.32, 1)` — and twelve durations/distances on top of the
five that already existed.

Three rules the numbers encode:

1. **Under 300ms for interface motion.** 180ms reads as more responsive than 400ms. Only three
   things are allowed past it: the 600ms value settle, the 500ms celebration, and the 280ms
   sheet. This app is opened twenty times a day; every millisecond is paid twenty times.
2. **Never `ease-in`.** It starts slow and delays the exact moment the student is watching.
   Two curves overshoot on purpose — `pressCurve` and `celebrationCurve` — and nothing else.
3. **Frequency decides intensity.** A tab switch happens fifty times a day, so it is the
   shortest thing in the app (150ms) and the only one that is pure opacity. A chapter report is
   read once a week.

The twenty-three animations, by ID:

| ID | Surface | Trigger | What moves | Duration | Curve |
|---|---|---|---|---|---|
| M-01 | Dashboard / subject / chapter lists | first build | fade + rise 12px, 40ms stagger, cap 6 | 260ms | standard |
| M-02 | Any mastery % | value changes | counts to the new number; colour switches instantly | 600ms | easeOutCubic |
| M-03 | Week strip | a day becomes complete | the ring floods inward to a disc, then the tick scales 0.6 → 1 | 120 + 220ms | standard |
| M-04 | Tab bar | tab tap | branch cross-fade + icon/label colour tween | 150ms | standard |
| M-05 | Review badge | count appears / changes | scale 0.6 → 1 with opacity, no bounce | 200ms | standard |
| M-06 | Toast | exam / homework saved | fade + rise 12px in, fade out; 2200ms dwell | 180 / 150ms | standard |
| M-07 | Push routes | navigation | incoming fades + rises 8px; outgoing fades out | 220ms | standard |
| M-08 | Chapter / lesson row | added / deleted | fades + rises in place / collapses + fades (§3.20) | 260 / 200ms | standard |
| M-09 | Every tappable | press down | `scale(.97)` — `Pressable`, unchanged | 140ms | pressCurve |
| M-10 | Checklist | tap a step | the same flood at 24px, then the tick; label colour tweens over 180ms | 120 + 220ms | standard |
| M-11 | Bottom sheets | open / close | slide up + scrim fade — unchanged | 280ms | sheetCurve |
| M-12 | Error banners | validation fails | fade + rise 6px. **No shake.** | 180ms | standard |
| M-13 | Wizard body | next / back | current fades out, next fades in + rises 10px | 200ms | standard |
| M-14 | Wizard segments | step advances | `scaleX` from the leading edge, forced LTR | 250ms | standard |
| M-15 | Wizard result | step 4 appears | counts up from 0, once per flow; before → arrow → after at 0/60/120ms | 600ms | easeOutCubic |
| M-16 | Wizard route | open / close | slides up from the bottom, direction-agnostic | 280ms | sheetCurve |
| M-17 | Review rows | first build | `ListEntrance`. No pulse, no flash on overdue. | 260ms | standard |
| M-18 | Celebration | chapter mastered | one green disc, scale 0.6 → 1 — unchanged | 500ms | celebrationCurve |
| M-19 | Lock → app / login → dashboard | unlock / sign-in | fade only | 200 / 220ms | standard |
| M-20 | Tab bar | tab tap | the glyph's own weight: `home` fades its fill in, `review`/`chart`/`tasks` thicken — one tween with M-04's tint | 150ms | standard |
| M-21 | Settings cog | header tap | rotates 45°, accumulating. Eight teeth, so the turn lands the glyph exactly on itself | 180ms | standard |
| M-22 | Back chevron | reading direction changes | reflects `scaleX` 1 → −1 about its own centre, stroke 2.4 → 2.2 with it | 180ms | standard |
| M-23 | Overdue mark | lesson stops being overdue | ring floods to a disc (radius down, stroke up) and its dashes land as a tick; **colour switches instantly**; then the mark fades and collapses out of the row | 220 + 150ms | standard |

**M-03 and M-10 flood; they no longer snap.** Both used to fill on one frame, on the reasoning
that a partly-filled circle reads as a day half-proved. That holds for a fill that *rises* — a
level, which this app already uses to mean partial progress — and not for one that closes inward
from the rim, which never shows a level at all. The rising variant was built, looked at, and
rejected; this is the other one. The two halves run in sequence and total 340ms, which is over
the `tick` token on purpose: two things happen, one after the other.

**M-23 outlives the state it reports.** A row cannot drop the overdue glyph on the frame the
lesson stops being overdue — that is the frame the flood starts on. `OverdueMark` stays mounted
through the completion and takes itself out afterwards, gap included. It **leaves** rather than
holding the green tick: the mark answers "does this need review", and once the answer is no, a
permanent tick beside a healthy subject is a second claim the row never meant to make. A subject
that was never overdue builds no controller and occupies no space.

**Nothing animates on scroll position** — no parallax, no shrinking header, no fading app bar,
no shimmer (this app reads local SQLite; there is nothing to wait for). The four subject glyphs
are static marks. Body copy being read never moves. And the mastery **colour** switches on the
frame the value changes rather than tweening: a red score fading through black briefly tells
the student something untrue.

**Reduced motion is fewer and gentler, not none.** Every animated widget checks
`prefersReducedMotion`. Movement and scale are dropped entirely, short fades stay, count-ups
and bar settles go to `Duration.zero` at their final value, and stagger delays go to 0. Glass,
blur and transparency are untouched — see §3.19.

Entrances are expressed as an `Interval` on one `AnimationController`, never a
`Future.delayed`. A widget test's `pumpAndSettle` can settle a ticker; it hangs on a timer.

### 3.22 Daily tasks exist, and they are kept away from mastery on purpose
§1 says this is **not** a to-do app, and adding a task list is a real widening of the
product — so the rule that keeps §1 true is enforced structurally rather than by intention:

- **`daily_tasks` is not in `StudySnapshot`.** The snapshot exists because every *mastery*
  screen is cross-cutting; tasks are read by exactly one screen and must never be read by a
  calculation. Widening `_combineLatest6` to seven would have bought nothing and quietly
  seated tasks at the same table as the evidence.
- **A second, narrow `TaskRepository`** beside `StudyRepository`, on its own `.watch()`
  stream. Nothing in `lib/domain/services/` imports `daily_task.dart`.
- **The tasks screen shows no percentage and no `MasteryBar`.** Its only figure is a count in
  the app's existing "X من Y" grammar. A progress bar under a task list would tell the student
  the app scores them on their to-do list, which is the exact claim the product denies.

A task belongs to a **day**, not to a lesson, so the table has no foreign key at all. Unfinished
tasks deliberately do **not** roll over: a day's plan is a record of that day.

`sortOrder` is a dense integer rewritten wholesale in one transaction on a drag. A day holds a
handful of rows, so fractional indices would be cleverness bought with nothing.

### 3.23 The tab bar floats, and has four slots — not five
§3.19's blur exception is unchanged and every one of its bounds still holds: exactly one
`BackdropFilter`, a mandatory clip, a sigma that is never animated, and a platform gate rather
than a reduce-motion gate. What changed, in two passes: the bar became a pill inset by
`AppSpacing.pageMargin` on the sides and `AppSizes.barLift` top and bottom, and then the raised
"+" was removed from it entirely.

Four consequences, all of which are the reason this is written down:

1. **The hairline goes all the way round.** A full-bleed bar was separated from the page by one
   line along its top. A floating one has content on all four sides and there is no shadow
   anywhere in this app to lift it, so `Border.all` is the only thing holding it off the page.
2. **There is no "+", and no reserved slot for one.** The four tabs are `Expanded`, so each
   takes a quarter of the bar and the touch target runs edge to edge. See §3.28 for why the
   button went.
3. **The selected tab is the accent, not the foreground colour.** On a bar where every other
   pixel is grey, hue carries "you are here" further than value does — and it is the same blue
   the progress bars fill with, so there is one colour to learn rather than two.
4. **The toast's offset is derived, not typed.** `AppSizes.toastBottom` is
   `barLift * 2 + barHeight + 16`, plus the system inset resolved at build time. A black toast
   under the 0.72 tint drops the inactive tab label to 1.5:1, so it has to clear the whole bar.

**The bar does not react to scroll.** Shopify's collapses; this one does not, because §3.21
rules out scroll-driven motion outright and a listener rebuilding the bar every scroll frame was
already rejected once.

### 3.27 One brand blue, and it is not a state colour
*Added by the visual refresh; it supersedes the "white, grey, black and two states" reading of
§3.10.*

The app now has an accent: `AppColors.accent`, `#4D9BFF` on dark and `#1B6EF3` on light, with
`onAccent` and a low-alpha `accentSoft` beside it. It is used **everywhere something is active**:
the selected tab icon and label, every progress fill, the ticked checkbox and task disc, the
selected filter chip, the "Exam" pill, `PrimaryButton`'s default tone, the lock screen's Unlock
button, the week strip's completed and today rings, and the brand mark's 27% arc.

Chose one accent over the previous monochrome because the monochrome version had no way to say
"this one" without also saying "this is correct" — every emphasis had to borrow green, and green
is a verdict about a real exam. A brand colour that means *active* frees the two state colours to
mean only what they mean.

Two rules follow, and both are load-bearing:

* **`wrong` and `right` never move.** They are the red pen and the green tick; the refresh did
  not touch either value. Blue never means correct, green never means selected.
* **A number and the bar under it resolve separately.** `MasteryPalette.resolve` gives the
  number — neutral in the middle of the range, because a mid score is text and not a verdict —
  and `MasteryPalette.fill` maps exactly that neutral case, and no other, to the accent. Red,
  green and the no-data grey pass through untouched. One mapping in one direction, so the two
  can never disagree.

### 3.28 The "+" button was removed
*Reverses the earlier decision that the "+" deserved the most reachable pixel on the screen.*

The raised centre button and its "Log exam / Add task" popup are gone. The reasoning that put it
there — logging an exam is the only action the product exists to capture, so it gets the best
target — was true about the *action* and wrong about the *button*. Reached from the tab bar, "log
an exam" has no lesson attached, so the flow had to open by asking which lesson was meant; and
before a student has built any curriculum there is no answer, so the button's own affordance was
dead exactly when a new student was most likely to press it.

Logging an exam is now reachable only from a place that already knows the lesson: the "Exam" pill
on the dashboard's up-next card, and the sticky CTA on a lesson screen. Two entry points, both
carrying their subject with them, and no route that opens with "which one?".

### 3.29 The week strip carries three weeks, and signposts the way home
The strip is flat in-page content — no card, no pill, no blur; the glass exception stays spent on
the tab bar alone (§3.19). Today is marked by a dot, a darker letter and a 1.5px rule under it,
**never a filled cell**: a filled cell already means "this day is done" three pixels below, and
using one fill for both made the two unreadable together.

It holds the previous, current and next week and drags between them, snapping past a ±45px
release. Two things about that are worth writing down:

1. **The neighbours only exist while it is moving.** At rest the strip builds one week. An
   off-screen cell that stays in the tree answers hit tests and `find.text` alike, and a tap
   meant for Saturday would land on a Saturday three weeks ago.
2. **Direction is computed exactly once.** The drag is accumulated in *logical* start-to-end
   pixels and multiplied by a single `sign` at the point it becomes a physical offset. The HTML
   prototype had the sign flipped per direction at three separate call sites and broke under LTR;
   everything positional here is `PositionedDirectional` / `AlignmentDirectional` instead.

Off today's week, a 34px green edge glow appears on the side the student would drag toward to get
back, and tapping it returns in one move. Green rather than the accent on purpose: it is
wayfinding, not brand. Its pulse controller **runs only while the glow is mounted** — the design
layer left an opacity keyframe looping on a hidden element forever, which is also why
`pumpAndSettle` is a valid assertion in `test/widget/week_strip_test.dart`.

### 3.24 The first schema migration, and why `onUpgrade` is not optional
`schemaVersion` went 1 → 2 for `daily_tasks`. Every student on an earlier build already has a v1
file named `sahm` on disk, and **`onCreate` does not run for them** — without an `onUpgrade` the
app would open against a database missing a table it is about to read and throw on the first
frame. The migration is additive only: one `createTable`, nothing dropped and nothing rewritten,
because a student's curriculum is the one thing in this repo that cannot be regenerated.

`test/data/task_migration_test.dart` builds a genuine v1 image on a real file — drift creates the
current schema, then the test removes exactly what v2 added and resets `user_version` — rather
than hand-writing v1 DDL from memory, which would have tested a schema no student ever had.

### 3.25 The settings icon was a sun for the whole life of the app
`AtherGlyph.settings` was a circle with eight straight radial spokes. That is a sun, and it read
as one at every size it was used at — found by looking at a phone, not at the code. It is now a
cog: an eight-tooth outline walked in polar coordinates by `_cogPath()`, rather than forty
hand-typed points, so the tooth count and depth stay adjustable.

The three-dot `more` glyph went with the tab that used it. Settings is now the cog in **every**
root screen's header (`SettingsButton`), which is a place it always belonged more than a tab did.

### 3.26 Cloud backup: a mirror, not a second source of truth
The product's whole value is a record kept over two years, and until now that record existed on
exactly one phone with no way to get it off. A lost phone was a lost curriculum.

**The shape.** One Firestore document per student at `users/{uid}/backup/snapshot`, holding the
whole record as a gzipped JSON blob plus plain `updatedAt`, `chapterCount`, `examCount` and
`formatVersion` fields — plain so "is the cloud copy newer than mine?" costs one metadata read
rather than a download and a decompress.

**Deliberately not row-level sync.** A student uses one phone at a time; the problem is "my
phone died", not "my tablet disagrees with my phone about lesson 12". Row-level merge would mean
an `updatedAt` and a tombstone on every table plus a conflict policy per entity — a large amount
of machinery for a case that does not arise, and every piece of it a new way to lose data.

**Firestore rather than Firebase Storage** because Storage now requires a billing account on new
projects. A practical constraint, not a preference.

**The upload refuses rather than truncates.** Firestore's ceiling is 1 MiB per document and the
budget is 900 KiB. A backup silently missing the last two years is worse than no backup, because
the student believes they have one.

**Restore is all-or-nothing and keeps ids.** Ids are what every `chapterId`/`lessonId`/`examId`
relationship is made of, so letting autoincrement reassign them would silently reattach exams to
the wrong lessons — a corruption nothing would ever report. One transaction, so a failure leaves
the student's existing database exactly as it was; `test/data/backup_restore_test.dart` forces a
mid-restore failure and asserts precisely that.

**Two bugs the tests caught, both of the same shape: a safe default answering a question it
should not have.**

1. The auto-restore asked `snapshotValueProvider` whether the device was empty. That provider
   falls back to `StudySnapshot.empty()` while its stream is loading — deliberately, so a
   transient frame cannot crash a screen — so at sign-in it answered "empty" for a phone that
   already held a full curriculum, and the cloud copy replaced it. It now awaits
   `snapshotProvider.future`, which is a real answer and is still the seam tests stub.
2. `FirestoreBackupRepository` resolved `FirebaseFirestore.instance` in its constructor. `main()`
   tolerates a failed `Firebase.initializeApp` on purpose (§3.17); this turned that tolerated
   failure into a crash the moment Settings built. Both handles are resolved lazily inside the
   guard now.

**Auto-restore happens only onto an empty database**, where there is nothing to lose. Everything
else — local data present, cloud copy newer — is the student's choice, behind the explicit button
in Settings and the same `confirmDestructive` sheet the rest of the app uses.

**Uploads are debounced 20s and flushed on `AppLifecycleState.paused`**, which is when a student
closes the app after recording an exam. Offline, the upload is skipped and retried on the next
trigger: "لسه محفوظش" is a state, not an error, and colouring it red would teach students to
ignore red.

Failures cross the boundary as a `BackupFailure` enum, never a message string — the same rule as
`AuthFailure`. `permissionDenied` is distinguished from `offline` because unpublished security
rules otherwise look exactly like "sync quietly does nothing".

**Firestore security rules** (published 2026-08-05, `eur3`, and load-bearing — the default is
deny-all, so without these the feature silently never works):

```
match /users/{uid}/backup/{document} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

### 3.30 The device belongs to one account at a time
Signing out left the student's whole curriculum on the phone, and nothing checked whose it was.
A second student signing in on the same device opened the app to the first one's chapters — and
the backup sync then mirrored those chapters into the *second* student's cloud document,
corrupting a backup that had done nothing wrong.

**The wipe is keyed on a changed uid, not on sign-out.** `BackupSyncGate` stores
`last_account_uid` and clears the local database only when the account that just signed in
differs from it. Signing out destroys nothing: it is not a statement that the work is finished
with, the phone may hold edits that never reached the cloud, and the same student signing back
in — offline — must find everything where they left it. Data only becomes the *wrong* data when
somebody else's account arrives.

Two consequences worth knowing:

- **The uid is written after the wipe, never before**, so a crash mid-wipe leaves the device
  still claiming the old uid and the next launch tries again.
- **`flush()` refuses to upload while the stored uid and the signed-in uid disagree.** That
  closes the window between a sign-in and the wipe, which is the exact interval in which one
  student's data could reach another's document.

Clearing also feeds the existing auto-restore the answer it wants: the device is now genuinely
empty, so the new student's own cloud copy is pulled down by the ordinary path with no second
code branch. `test/widget/backup_test.dart` covers both directions — a different account wipes,
the same account keeps everything.

### 3.31 Deleting an exam moves the clock that exam started
`deleteExam` existed in the repository from the beginning and **no screen ever called it**, so a
mistyped result — 3 out of 30 entered as 30 out of 3 — was permanent. In an app whose entire
claim is that the number is trustworthy, an uncorrectable number is the worst defect available.

The delete is now reachable from the lesson's history card, behind the same `confirmDestructive`
sheet as every other deletion, with a line above the list saying so. Rows stay information; the
confirmation carries the weight.

**The part that is not obvious:** mastery is *derived* and fixes itself, but `lastReviewedAt` is
*stored* and does not. Removing the exam that stamped it would leave a lesson counting down from
a date nothing in the database supports. So `deleteExam` recomputes it in the same transaction,
from the newest remaining exam — or from `chapter.masteredAt` if that is later, because "أتقنت
الباب" also restarts the cycle and is not an exam. With neither, the lesson is unexamined again
and has no clock at all.

There is deliberately **no `deleteHomework`**. One existed, equally unreachable, and was removed:
only the most recent homework entry is ever read, so recording a new one supersedes a mistyped
one, and homework never touches mastery. If a homework history is ever shown, the delete comes
back with the UI that needs it.

---

## 4. Data Model

All foreign keys are `ON DELETE CASCADE`.

| Table | Columns |
|---|---|
| `subjects` | `id, nameAr, nameEn, iconCodePoint, colorValue, sortOrder` — 4 seeded rows, no add/edit UI |
| `chapters` | `id, subjectId, name, masteredAt?, createdAt` |
| `lessons` | `id, chapterId, name, lastReviewedAt?, lastNotifiedAt?, createdAt` + 5 checklist bools |
| `homework_entries` | `id, lessonId, score, maxScore, createdAt` |
| `exam_entries` | `id, lessonId, isReviewExam, totalPossiblePoints, correctPoints, percentage, createdAt` |
| `exam_question_groups` | `id, examId, pointsPerQuestion, questionCount, correctCount` |
| `daily_tasks` | `id, day, title, done, sortOrder, createdAt` — **feeds nothing** (§3.22) |

`daily_tasks` is the only table with no foreign key: a task belongs to a date, not to a lesson,
and nothing in `domain/services/` reads it. It is deliberately absent from `StudySnapshot`.

`percentage` is denormalised onto `exam_entries`: mastery is read on every dashboard and chart
query, and a past exam's score must stay historically stable.

### Mastery rules

```
lessonMastery:
  0 exams  -> 0
  1 exam   -> that exam's percentage
  n exams  -> last.percentage * 0.7 + mean(all others).percentage * 0.3

chapterMastery = mean(mastery of every lesson in the chapter)
                 (lessons with no exams contribute 0 — never excluded)
```

Bands: `<50` ضعيف · `50–69` متوسط · `70–89` كويس · `≥90` متفوق.

**Homework never enters this calculation.** It renders only as a readiness line:
`<60%` → «لسه محتاج تذاكر أكتر قبل ما تدخل الامتحان», otherwise «تمام، جاهز تدخل الامتحان».

`lastReviewedAt` is set on (a) a successful "أتقنت الباب" for every lesson in the chapter, and
(b) every exam submission, first or review.

**Chapter red rule** — exactly as specified, no averaging, no threshold: if even one lesson in
a chapter needs review, the whole chapter is red.

---

## 5. Features

| Feature | Status |
|---|---|
| Project scaffold, deps, git | Complete |
| Design tokens (colours, type, spacing, radii, motion) | Complete |
| Readex Pro variable font wired with `fontVariations` | Complete |
| ar/en ARB localization + generated delegate | Complete |
| Window size classes / adaptive breakpoints | Complete |
| Injectable `Clock` | Complete |
| Light theme (dark removed) | Complete |
| Drift schema, seed, repository, cascades | Complete |
| Mastery calculator (pure, tested) | Complete |
| Review cycle service (pure, tested) | Complete |
| Insights generator (pure, tested) | Complete |
| Riverpod providers + screen summaries | Complete |
| go_router shell + four-slot tab bar | Complete |
| Dashboard | Complete |
| Subject screen (chapter cards) | Complete |
| Chapter screen + "أتقنت الباب" gate | Complete |
| Lesson screen (checklist, homework, history) | Complete |
| Exam entry wizard (4 steps) | Complete |
| Chapter report | Complete |
| Review Center | Complete |
| Analytics dashboard + charts + insights | Complete |
| Settings (ar/en toggle, reminders, account, lock) | Complete |
| Firebase Auth: email/password + Google | Complete |
| Login screen in the Ather design language | Complete |
| Biometric app lock | Complete |
| Celebration (white screen + green disc) | Complete |
<<<<<<< HEAD
| Notification service + lifecycle reconciliation | Complete |
| Cloud backup + restore (Firestore) | Complete — verified against live Firestore 2026-08-05 |
=======
| Notification service + lifecycle reconciliation | Complete — **never once delivered a reminder before 2026-08-10**, see §3.15a; still unobserved on a device |
| Cloud backup + restore (Firestore) | Complete — not yet exercised against live Firestore |
>>>>>>> 4a9c8b6 (Audit fixes: notifications, account isolation, exam deletion, performance)
| Daily tasks tab (add / tick / edit / reorder / delete, per day) | Complete |
| Floating glass tab bar | Complete |
| Android build + on-device verification | Complete — full journey run on emulator |
| Windows desktop verification | **Blocked** — see §8, needs two user actions |

---

## 6. Adaptive Layout

Ather is a phone design, and the honest desktop answer is the same single-column layout with
room around it — not a second layout the handoff never specified.

| Class | Width | Shape |
|---|---|---|
| `compact` | `<600` | full width |
| `roomy` | `≥600` | same layout, capped at 520 and centred |

The previous build branched here into a side rail, desktop dialogs and a two-pane
master/detail. All three contradicted the four-slot tab bar and the single modal shape, so
they were deleted rather than kept switched off.

---

## 7. Localization and RTL

Arabic is the default locale and the fallback; English is a runtime toggle. All strings live in
`lib/core/l10n/*.arb` — no string literals in widgets. Layout uses `EdgeInsetsDirectional` and
`start`/`end`, never `left`/`right`. Direction-implying icons mirror explicitly.

Every screen must be verified in **both** directions. `test/widget_test.dart` asserts the
actual `TextDirection` flips, because a non-mirroring bug is invisible to a string-only check.

**Numbers are the hard part.** Every number is Western digits, laid out LTR and *isolated*
from the Arabic around it with `U+2066 … U+2069` (`core/l10n/formatting.dart`). Isolate the
number alone, never a phrase: `iso('1') + ' من ' + iso('4')` is correct, `iso('1 من 4')`
renders as "من 4 1". A literal `70%` inside an ARB string renders as `%70` — thresholds are
passed in as isolated placeholders instead. Progress bars are forced LTR too: a bar filling
from the right makes 20% look like 80%.

Arabic plurals go through ICU `plural` in the ARB (`=1` درس واحد · `=2` درسين · `few` N دروس ·
`many`/`other` N درس), so "1 دروس" cannot happen. The "X من Y درس" construction deliberately
uses the singular counting form and is a separate key.

---

## 7a. Brand Identity

The authored identity is three SVGs, shipped in `assets/branding/`:

| File | Role |
|---|---|
| `icon-mastery-light.svg` | The official launcher icon, and the in-app mark on a light surface |
| `icon-mastery-dark.svg` | The same mark on a dark surface |
| `glyph-mastery.svg` | The mark with no background plate — standalone symbol |

All three are one geometry — a single **organic, hand-wobbled ring**: a closed curve through
seven points at irregular radii, stroked twice, once whole in the foreground colour and once over
its first **27%** in the brand accent (§3.27). *(This replaced the original concentric track ring,
324° green arc and solid centre dot in the visual refresh. The meaning did not change — the ring
is the syllabus, the coloured run is the part that has been proven — only the drawing.)* The three
variants differ only in three colours, so the geometry is transcribed **once**, into
`lib/core/branding/ather_brand.dart`, and every surface is painted from it:

* In-app — `AtherLogo` (plated) and `AtherGlyph` (transparent), both in
  `lib/core/branding/ather_logo.dart`. Neither takes a light/dark argument: they resolve the
  variant through `AtherBrandPalette.of(context)`, which reads the ambient `Brightness`. That is
  the whole of the theme switch — no call site branches, and there is no second widget tree.
  Placed on the login screen, the lock screen (which is what a cold start actually shows) and the
  Settings → About card.
* Android bitmaps — generated by `tool/branding/export_branding_test.dart`, which paints with the
  same `AtherMarkPainter`. Nothing is hand-exported, so the launcher icon and the in-app logo
  cannot drift apart.

A `CustomPainter` rather than an SVG renderer because the mark is one path stroked twice: it stays
vector at every size, costs no dependency and no decode, and is what lets the icon export and the
UI share one drawing. The SVGs remain the authored artefact.

Regenerate every Android bitmap after any change to the geometry or palettes:

```bash
flutter test tool/branding/export_branding_test.dart
```

That writes `mipmap-*/ic_launcher.png` (48dp), `mipmap-*/ic_launcher_foreground.png` (108dp),
`drawable-*/splash_glyph.png` + `drawable-night-*/splash_glyph.png` (120dp) and
`android/app/src/main/ic_launcher-playstore.png` (1024², for the Play listing — outside `res/`, so
it is not packaged into the APK).

Three rules that are easy to break by accident:

1. **The launcher icon is always the light variant.** The installed icon belongs to the home
   screen, not to the app's theme, so it is never resolved from brightness. There is deliberately
   no `<monochrome>` layer in `mipmap-anydpi-v26/ic_launcher.xml` — a themed icon would let the
   launcher recolour the mark to the wallpaper palette and drop the accent.
2. **The adaptive foreground is drawn at the artwork's authored scale.** `AtherMarkGeometry.extent`
   is 0.6113 — carried over from the old mark deliberately — which on the 108dp adaptive canvas
   is 66.0dp, exactly the guaranteed-visible safe zone.
3. **The mark is centred on its own bounds, not on the viewBox.** The old mark was a circle and
   the two were the same thing. The organic ring is deliberately lopsided, so centring it by
   viewBox would leave it visibly off inside a launcher mask.
4. **The mark is only ever scaled uniformly.** `AtherMarkPainter` works in the design's own
   100-unit grid and applies one scale on both axes, letterboxing a non-square box rather than
   stretching. No rounded corners, no shadow, no gradient, no crop.
   *(`Path.transform` returns a new path rather than mutating one — a cascade onto it silently
   discards the result, which is exactly how the first port of this shipped a stroke wide enough
   to fill the ring solid.)*

The in-app mark follows the app's theme (§7b): `AtherBrandPalette.of(context)` reads the ambient
`Brightness`, so Light shows the light artwork, Dark shows the dark, and "follow system" needs no
special case — the framework has already resolved the OS setting into the ambient brightness by
the time the mark is painted. That one call is the *only* thing that chooses a logo anywhere in
the app.

The **launcher icon is not part of that** and never changes: it is the light artwork baked into
the Android resources, and it stays light whatever theme the student picks, because the icon lives
on the home screen rather than on the app's own surface. The Android launch window is the one
place the dark glyph is chosen by the OS rather than by the app — it follows the system night
setting via the `-night` resource bucket, which is also why the splash needs no second
`launch_background.xml`.

---

## 7b. Theming (light / dark / system)

The student picks **فاتح / داكن / النظام** in Settings → المظهر. `ThemeMode.system` is the
default and is what an unset preference reads back as: someone who never opens the setting gets
the app in whatever mode their phone is already in.

### How a colour reaches a widget

`AppColors` is a **`ThemeExtension`**, not a bag of constants. It is attached to `ThemeData` in
`AppTheme._build`, and every colour in the app is read back out of it:

```dart
final c = context.colors;      // AppColors for the ambient theme
... color: c.textSecondary
... style: context.text.secondary   // the colour-bearing text styles
```

**This indirection is load-bearing and must not be shortcut back to statics.** Reading through
the context registers the widget as a dependent of `Theme`, so it rebuilds the instant the theme
changes. A static constant — or a global "current brightness" variable — cannot do this: screens
parked in the `Navigator` are *not* rebuilt when `MaterialApp` rebuilds, so they would keep
painting the previous theme's colours until they happened to be rebuilt for some other reason.
That was tried first and is why it was abandoned.

### The type scale is split by whether a style owns a colour

* **Static, in `AppTypography`** — every style whose colour is just "the primary text colour".
  These leave `TextStyle.color` **null** and inherit it. `Text` merges its style over the ambient
  `DefaultTextStyle`, which `AppTheme` seeds from `textTheme.bodyMedium` = `textPrimary`, so an
  uncoloured style is black in light and white in dark with nothing at the call site. A null
  colour here is not an omission — it is how the style stays correct in both themes.
* **`AppTextStyles`, via `context.text`** — the handful that deliberately sit at a different
  colour: the secondary greys, the weekday label, the fine print, and the two that print onto a
  filled button.

### Two tokens that do *not* invert

`wrong` (#FF3B30) and `right` (#34C759) are identical in both palettes — they are the red pen and
the green tick, and the brand mark keeps the same green on both its plates. Two tokens exist
because of that:

* **`onState`** — what prints *onto* those two fills. White in both themes. Using `onPrimary`
  there would turn a sign-out button's label black on red, and the tick inside a green disc black
  on green.
* **`switchKnob`** — light in both themes. The knob rides the green track when on, and a knob the
  colour of the card is nearly invisible against `switchOff` on a dark page.

Anything else that sits on a fixed fill belongs on `onState`, not `onPrimary`.

### Persistence and first frame

`themeModeProvider` (a `Notifier`, matching `localeProvider`) stores the choice in
`SharedPreferences` under `theme_mode`, as the enum's **`name`** rather than its index — so
reordering `ThemeMode`, a framework enum we do not control, cannot silently reinterpret every
student's saved choice. `main()` already awaits `SharedPreferences` before `runApp`, so the
preference is read synchronously on the first frame: the app opens in the right theme rather than
flashing light and correcting itself.

### Verifying it

```bash
flutter test tool/render/ather_render_test.dart        # light, compares against goldens
flutter test tool/render/ather_dark_render_test.dart   # dark
```

The light suite is the regression net for "the redesign did not disturb the existing theme" — it
compares pixel-for-pixel against committed goldens. The dark suite boots the app with
`theme_mode: dark` already in `SharedPreferences` rather than overriding a provider, so it also
proves the preference survives a cold start and is applied on the first frame.

---

## 8. How to Run and Test

```bash
flutter pub get
flutter gen-l10n                                  # regenerate after editing any .arb
dart run build_runner build --delete-conflicting-outputs   # after editing drift tables

flutter analyze
flutter test                                      # host VM — needs no device

flutter run -d <emulator-id>                      # Android
flutter run -d windows                            # Windows desktop
```

**Producing a distributable build is documented separately in `RELEASING.md`** —
where the signing key lives, why neither it nor its passwords are in this repository,
registering its SHA-1 with Firebase, and how to verify what you actually built.

### Environment status on the current dev machine

| Item | Status |
|---|---|
| Flutter 3.44.6 / Dart 3.12.2 | OK |
| Android SDK `android-36.1`, build-tools `36.0.0`, licence accepted | OK |
| `JAVA_HOME` → Microsoft JDK 17 | OK |
| `flutter analyze` / `flutter test` | OK — no device required |
| Android `cmdline-tools` + `system-images;android-35;google_apis;x86_64` | Installed |
| Android emulator `nasaq_pixel_390` | Working — boots as `emulator-5554`, Android 15 (API 35) |
| `flutter build apk --debug` | Passing |
| Visual Studio C++ toolchain | **Missing** — required for `flutter run -d windows` |
| Windows Developer Mode | **Off** — plugin symlink support; blocks the desktop build first |

**To unblock Windows desktop, two user actions are needed:**
1. `start ms-settings:developers` → enable **Developer Mode** (symlink support for plugins).
2. Install the Visual Studio **Desktop development with C++** workload.

Until both are done, Windows desktop is **untested** and is reported as such — never as working.

---

## 9. Known Issues / Follow-ups

- **Google sign-in has not been exercised on a device.** Email/password, sign-out, the
  fingerprint lock and the airplane-mode relaunch were all run on the emulator (see §10); the
  Google account sheet was not, because it needs a Google account signed in on the device.
- **A test account exists in Firebase.** `test@ather.app` was created to verify the flow and
  can be deleted from the Authentication console. There is also a stray empty Google Cloud
  project, `ather-app-2026`, left over from a failed first attempt.
- ~~**The redesign was run on the emulator but not on a real phone.**~~ **Done (2026-08-05).**
  The visual refresh was driven end to end on a Nothing Phone (A015, Android 16, 1080×2400):
  add chapter → add lesson → tick study steps → both exam entry points → save → Progress,
  Tasks, Review; light/dark; Arabic/RTL and English/LTR; the week-strip drag in both directions;
  and the lock screen. `logcat` was clean — no Flutter exception, no overflow, no
  setState-after-dispose. Two things were found on the device that the render goldens had not
  caught; both are fixed and written up in the work log.
- **Windows desktop cannot be built on this machine.** `flutter doctor` reports Visual Studio
  absent, and plugin builds additionally need Developer Mode enabled. Both are user actions.
- ~~**Notification delivery has never been observed firing.**~~ **Observed 2026-08-10**, on a
  Nothing Phone A015 (Android 16, API 36), end to end for the first time in the app's history:
  recording the first exam raised the permission prompt; `dumpsys alarm` showed a pending
  `RTC_WAKEUP` for `ScheduledNotificationReceiver` at 30 days; moving the device clock past that
  date posted the reminder with the right Arabic title and body; and tapping it opened the lesson
  it was about. Deleting the exam withdrew the clock and the alarm came back
  `Reason=alarm_cancelled` with zero pending.

  Not covered by that run: a reminder surviving a **reboot** (the boot receiver is declared and
  registered, but was not exercised), and a real thirty-day wait rather than a clock jump.
- ~~**The exam wizard discards input on exit, by design.**~~ **Changed 2026-08-10.** The × and
  the system back both left without saving, which is what the handoff specified, but the on-screen
  Back stepped *back through the wizard* — so the three exits disagreed and a stray back gesture
  cost a fully described paper. All three now route through one path: back a step while there is
  one, then a discard confirmation if anything has been typed. New copy
  (`examDiscardTitle` / `examDiscardBody` / `examDiscardLeave` / `examDiscardStay`) is the part
  that was holding this up; it is written and wants a read.
- **A deleted task does not collapse.** Every other row in the app leaves via `CollapsingList`
  (§3.20), but a list cannot be both reorderable and collapsing, and the drag is what the
  feature was asked for. The cost is bounded: the delete happens in a sheet over that very
  screen, so the row's departure is already explained, whereas the collapse exists for removals
  that arrive from *another* screen as a shorter list.
- **The v1 → v2 migration has been exercised on a real file, but not on a real phone.**
  `test/data/task_migration_test.dart` builds an actual v1 image on disk and reopens it, which is
  the mechanism; it is not the same as relaunching an APK over an install that has been there for
  weeks.
- **The floating bar's contrast has not been re-measured.** §3.19's 2.55–2.80:1 for the inactive
  label was measured against a full-bleed bar. The pill exposes content on four sides instead of
  one; both light and dark renders were reviewed and read fine, but no numbers were taken. If it
  ever fails, the rule is already written: raise the tint alpha, never darken the label.
- 20 transitive packages are held back by the Flutter SDK's `meta 1.18.0` pin. Benign.
- **The release signing config is wired, but no keystore exists yet.**
  `android/app/build.gradle.kts` reads `android/key.properties` (git-ignored, alongside `*.jks`
  and `*.keystore`) and signs `release` from it. Until that file exists, a **release build fails
  outright** with instructions — it does *not* fall back to the debug key. That fallback is what
  shipped a `CN=Android Debug` APK once already, and Gradle's `logger.warn` is useless here
  because `flutter build` swallows it, so the warning would never have been read. Same principle
  as §3.18: a safe default that hides its own cause is a trap. `flutter build apk --debug` and
  `flutter run` are unaffected. Creating the keystore is a credential step and is deliberately
  left to a human — see `android/key.properties.example`.
- **A day-granular clock needs a resume trigger, not just a timer** — found on the phone, and
  worth remembering as a shape rather than a one-off. `nowProvider` was changed from a
  sixty-second poll to a single emission per midnight, which is right: everything downstream is
  whole days. But a `Timer` measures *elapsed* time, and the wall clock moves without any time
  elapsing — a device waking from doze, the network correcting the clock, a timezone crossed, a
  date changed by hand. The optimisation silently removed the only thing that noticed. On device
  the app rendered "باقي ⁦62⁩ يوم" against the date it had booted on, thirty days stale.
  `AppLifecycleListener(onResume:)` is the second trigger, and it emits only when the day really
  differs so an ordinary switch-away-and-back still costs nothing.

- **The motion work has not been profiled on real hardware.** §3.21's durations were chosen
  from the spec, not measured, and no raster time in this repo was observed on a mid-range
  Android. What is true instead: every animation touches `transform` or `opacity` only except
  the collapsing row (§3.20), nothing animates on scroll position, and there is exactly one
  `BackdropFilter` — which is what makes the profile run likely to be boring. Run it anyway, on
  the dashboard and the progress screen, and record the numbers here.
- **The animated icon layer (Lordicon / Lottie) was attempted and abandoned. The package cannot
  express the spec's central rule.** The handoff proposes eleven monochrome Lottie icons for
  positions the motion system already animates, fitted to two duration tiers: an icon that *is*
  the response to a tap lands in 240ms and may be sped up to ×3; a decorative draw gets 600ms
  and ×2; artwork that still overruns ships static. `lordicon 1.0.3` **exposes neither a speed
  setter nor a duration getter** — `_controller` and `_composition` are private, and the only
  playback API is `play` / `pause` / `playFromBeginning` / `goToFirstFrame` / `goToLastFrame`.
  There is no way to read a state's natural length or to play it faster.

  The measured asset durations make that fatal rather than inconvenient. Every state is authored
  at 683–2000ms: `in-check` is **683ms** against a 240ms feedback budget, `in-home` is
  **1000ms** against a 150ms tab response, and `in-growth` is **1500ms** against a 600ms
  decorative cap. Without a multiplier every one of the eleven overruns its tier, so by the
  spec's own fallback rule all eleven would ship *static* — 487 KB of JSON rendering still
  frames, strictly worse than the hand-drawn `AtherIcon` glyphs already there (§3.12).

  Secondary concerns, for whoever revisits this: `MOTION_BRIEF.md` §6 bans Lottie outright and
  allows at most one new dependency; the package is two years old with 16 likes; it resolves
  only by pulling `lottie 2.7.0` while the ecosystem is on 3.x; and `IconViewerState.dispose()`
  disposes a controller it does not own, which double-disposes any controller a caller also
  manages. The dependency **does** resolve against Flutter 3.44 / Dart 3.12 — that was verified,
  then reverted — so the blocker is the API surface, not the constraint solver.

  The only route to shipping this as specified is vendoring or forking the controller to expose
  `duration` and `speed`. That is a maintained fork for eleven icons a student mostly sees once
  each, and the motion system underneath does not depend on any of it. If it is ever taken up,
  the free licence requires a visible credit in Settings → About — a licence condition, not a
  follow-up.

### Found by rendering every screen (Ather redesign)
Six real defects, none of which a compiler or a passing test would have caught:
1. `Spacer` beside a `Flexible` split the leftover width, wrapping the summary context line
   onto two cramped lines (§3.13).
2. The week strip had no dot over today, so "today" was signalled by text colour alone.
3. `70%` sat un-isolated inside an Arabic sentence in the not-ready sheet and rendered `%70` —
   exactly the bug the design's checklist calls out.
4. Bottom sheets were presented on the branch navigator, so the tab bar stayed lit on top of
   the scrim instead of being covered by it.
5. Two `RenderFlex` overflows (the before/after row and the lesson status chip) that only
   appear at wide font metrics.
6. Review rows opened the lesson screen instead of the exam wizard the design asks for.

### Verified on device before the redesign (Android emulator, API 35)
Full journey run through the old UI: create chapter → add lesson → exam wizard (8 questions,
groups 5×1 and 3×2, 4 and 2 correct) → **73%**, matching the unit test's `closeTo(72.7272)`
exactly → saved → countdown started and the exam checklist item auto-ticked → language switched
to English → whole tree mirrored to LTR with Western digits intact. The mastery engine that
produced those numbers is untouched by the redesign.

---

## 10. Work Log

<<<<<<< HEAD
**Visual refresh: one brand blue, a new mark, and no "+" (2026-08-05).**
Ported the `design_handoff_visual_refresh` handoff into the Flutter app. Where it contradicted a
standing rule, **the design won and the rule was rewritten** — §3.10 no longer claims a
two-colour palette, §3.23 no longer describes a five-slot bar, and §7a no longer describes a
concentric ring. The new rules are §3.27 (one accent, and why it is not a state colour), §3.28
(why the "+" went) and §3.29 (the three-week strip).

- **Accent tokens** `accent` / `onAccent` / `accentSoft` on `AppColors`, and the accent applied
  everywhere "active" is meant: tab bar, `PrimaryButton` (its `black` tone renamed `primary`,
  which is the point — the tone is named for meaning, not colour), `PillButton`, checkboxes,
  task discs, filter chips, the segmented control, every progress bar and chart column.
  `MasteryPalette.fill` is the one mapping from the neutral number colour to the accent.
- **New brand mark.** Organic seven-point ring, stroked whole plus a 27% accent run.
  `AtherBrandPalette` lost `core` and renamed `track` → `ring`. All three SVGs in
  `assets/branding/` rewritten and every Android bitmap re-exported.
- **New subject icons**: a knee joint for Biology, a horseshoe magnet for Physics, an open book
  for English. Chemistry's flask is unchanged.
- **Week strip rewritten**: flat, underline-marked today, accent rings, a three-week drag buffer
  and the directional "return to today" glow. Both bugs the handoff flagged in the design layer
  are covered by `test/widget/week_strip_test.dart` (5 cases).
- **Lock screen**: 108px mark, 38px wordmark, no standing body copy. `lockTitle` and `lockBody`
  are deleted from both ARBs; the wordmark is `appName`, which in Arabic is now **أثر** rather
  than the Latin "Ather".
- `AppSizes` lost `fab`, `fabOverhang` and `fabLift`; `toastBottom` re-derived.

**160/160 tests pass**, `dart analyze` clean.

**Driven on a real phone (2026-08-05).** A Nothing Phone (A015, Android 16), debug build, the
whole flow. Two gaps the render goldens had missed, both the same mistake — a fill that was
never routed through `MasteryPalette.fill`:

1. **The exam wizard's result bar stayed white.** A mid-range score resolves to the neutral
   text colour, and the bar took it verbatim. It is the one bar a student stares at.
2. **Material's own `ColorScheme.primary`, `FilledButton`, focused input border, progress
   indicator, and the wizard's four step bars were still the foreground colour.** Every
   framework widget that has not been replaced by a hand-built one now tints itself the accent,
   which is what stops a stray `FilledButton` from looking like it belongs to the old design.

Neither is visible in a widget test — both are colour, and the goldens for those screens were
regenerated from the same code that had the bug. That is the honest limit of a golden: it
proves nothing changed, not that anything is right.

One consequence of the design worth knowing about, kept because the handoff is explicit that
the glow is tappable: **the return-to-today glow overlays the strip's first day cell**, so on
the Tasks screen (where the strip is a picker) that one day cannot be tapped while another
week is on screen. Narrowing the glow or making its inner half inert would fix it.

**First signed release, and the first live Firestore round-trip (2026-08-05).**
An upload key now exists (procedure and warnings: RELEASING.md). Its SHA-1 and SHA-256 are
registered against `com.ather.app` in Firebase and `android/app/google-services.json` was
re-downloaded — it now carries two certificate hashes for the package, the debug key and
`f3eaec08…`.

Verified on the device, in this order, because each step only proves the next one is worth
trying:

1. `apksigner verify` reports `CN=yassen, OU=per, O=ather, L=giza, ST=giza, C=eg` — not
   `CN=Android Debug`. 22.8 MB on arm64, AOT.
2. The debug build was **uninstalled** — a signing key cannot be changed in place — and the
   release APK installed onto an empty package.
3. Google Sign-In completed. This is what the SHA-1 registration buys: without it the account
   picker still opens and then fails with `ApiException: 10`. *(`DEVELOPER_ERROR` does appear in
   `logcat` around sign-in, but from Play Services' own Phenotype/FlagStore processes, not from
   the app's pid. Sign-in succeeding is the proof that it is unrelated.)*
4. **The curriculum came back on its own** from Firestore onto the wiped install — chapter,
   lesson and the 90% exam. `BackupSyncGate`'s auto-restore-onto-an-empty-device path had never
   run against a real backend before.

Two numbers on that restored dashboard look wrong at a glance and are not:
`overallMastery` showed 23% while Biology showed 90%, because untouched subjects deliberately
count as 0 (§ the calculator's own comment: a figure that ignored three empty subjects would
tell a student they are 85% ready for Thanaweya Amma); and "0 of 1 chapters mastered" is right
because `Chapter.isMastered` is `masteredAt != null` — an explicit press of the mastery gate,
never derived from a score.
=======
**Full audit, then five phases of fixes (2026-08-10).**
A read of every file in `lib/` against this document, followed by the work below. `flutter
analyze` clean, **163/163 tests pass** (155 before; four dead-code tests removed, twelve added),
and all seven golden render suites pass against regenerated goldens.

*Critical — each of these was silent, which is why none had been reported:*

- **Review reminders had never worked, for two independent reasons.** §3.15a. No call site ever
  requested the OS permission, and the plugin's receivers were not declared in the manifest.
- **A second student on the same phone saw the first one's curriculum** — and uploaded it into
  their own cloud document. §3.27.
- **The exam wizard hung permanently on a failed save.** No `try/catch`, and `_saving` was never
  cleared, so one failure left a fully entered paper behind a button that ignored every further
  tap. It now stays on step 4 with the numbers intact and says what happened.
- **A mistyped exam could never be corrected.** §3.28.
- **Every database write was fire-and-forget** — checklist, homework, mastering a chapter, every
  task operation. A failure changed nothing on screen and said nothing. All of them now go
  through `runWrite` (`presentation/common/write_guard.dart`), which resolves its context before
  the await and reports a failure as a toast in the app's own vocabulary.

*High impact:*

- **Turning the app lock on locked you out on the spot.** `LockStateNotifier.build` *watched* the
  preference, so flipping the switch rebuilt the notifier, reset the state to `true`, dropped the
  lock screen over Settings and fired a prompt — which, cancelled, left the student outside their
  own app with the back button already swallowed. It reads the preference once now.
- **The progress screen's filter reached two of its four cards.** The other two answered for all
  four subjects without saying so. Now the discipline card filters too, and the subject-comparison
  chart — which deliberately never filters, because comparing one subject with itself is not a
  chart — says as much in a line under its title.
- **The dashboard had no first-run state.** A new student saw "—", three zeroes and four rows,
  with the four-step path to a first exam written down nowhere. A card now *replaces* the two
  empty summary cards until there is a chapter — replacing, not stacking, because those two cards
  are pure noise when everything in them is zero.
- Real loading states on the two slow paths (exam save, cloud restore) via `PrimaryButton.busy`,
  the app's only spinner. Restore also catches failures from the local half of the write, which
  previously escaped unhandled.

*Performance — all of it measured against the shapes in this file, none of it profiled on
hardware yet (§9 still stands):*

- **The clock ticked every 60 seconds and rebuilt the world.** `nowProvider` drove
  `dashboardProvider`, which recomputes every summary for the whole curriculum, which rebuilt
  every screen watching it *and* `AppShell` — the widget holding the app's one `BackdropFilter`.
  Everything downstream is derived from whole days, so it now emits once per midnight.
- **Each lesson's mastery was computed about four times per dashboard build**, each time copying
  and re-sorting that lesson's exam list. `MasteryCalculator.lessonMasteries` computes the map
  once and `Summaries` threads it down. `mastery_calculator_test.dart` pins the fast path to the
  canonical one lesson-for-lesson, because a drift between them would silently falsify every
  number in the app.
- **List rows replayed their entrance on every scroll.** A row scrolled out is unmounted, and
  scrolling it back mounted a fresh `RiseIn`. `ListEntranceScope` remembers, per screen visit,
  which ids have already arrived.
- **Backup gzip + JSON ran on the UI isolate**, on a 20-second debounce — i.e. while the student
  was using the app. Both directions now go through `Isolate.run`.

*Accessibility and contrast:*

- **The app had two `Semantics` widgets in total.** `Pressable` now declares `button` and takes a
  `semanticLabel`, which is effectively required for anything whose content is a bare `AtherIcon`
  — every icon here is a `CustomPaint` and carries no accessible name. Back, the cog, the pencil,
  the wizard's × and the group-remove × were all announced as unnamed regions. The toast is a
  `liveRegion`; it was previously invisible.
- **48dp hit areas** via `Pressable.minTarget`, opt-in so it cannot shrink-wrap a card. The drawn
  sizes are unchanged: the 36px header circle, the 34px day, the 17px pencil all look identical.
- **`#34C759` is 2.2:1 on white** — under every threshold, including the 3:1 for large text — and
  it coloured every mastery figure at 90%+. New `rightText` token (`#1B7F3B`, 4.6:1) for green
  *words*; `right` stays the fill, and the two are the same value in dark, where the brand green
  already measures 7.7:1. The toast's success mark became a `CheckDisc` so it carries its own
  contrast onto a plate that inverts.
- **`textNoData` was 1.7:1** — the "—" meaning "never examined", and every field hint. Now 4.9:1,
  still a clear step quieter than `textSecondary`.

*Cleanup:* the injectable `Clock` now covers `createChapter` / `createLesson` / `addTask`, the
only three writes that still called `DateTime.now()` (§3.8); `lessonsAwaitingNotification` and
its four tests removed as dead code from the abandoned polling design; an empty name in the name
sheet says why instead of swallowing the tap; an overdue 0% lesson is red rather than "no data"
grey; `int.parse` on a route parameter can no longer crash route building; the router and its
auth subscription are disposed with the provider scope; two toasts can no longer stack on top of
each other; and the password toggle's `'abc'` — untranslated Latin in an Arabic form — is gone.

**Not done, and deliberately left for a decision:** account deletion (Play requires it for any
app with accounts, and it is a product decision about what happens to the cloud copy), local
file export, email verification, and Crashlytics. `flush()` still skips an upload when the local
database is empty, so a student who deletes everything cannot clear their cloud copy — that is a
real edge but the safe direction of the two.
>>>>>>> 4a9c8b6 (Audit fixes: notifications, account isolation, exam deletion, performance)


**The biometric lock was skippable (2026-08-05).**
Reported from a real phone: the back button walked past the lock. Investigating turned up a
second, worse bypass in the same screen — a lockout, a cancellation and a refusal all ran the
same `unlocked = true` branch, so the lock opened for anyone who failed it. Both are fixed and
§3.18 is rewritten; the release-on-unusable-device rule survives, narrowed to the three codes
that actually mean the device can never answer.

`MaterialApp.router` now takes the router's parts individually rather than `routerConfig`, so a
`LockAwareBackButtonDispatcher` can sit where the press is actually seen. New
`test/widget/lock_test.dart` (7 cases) and `test/support/fake_local_auth.dart` — the lock had
never been testable, having only ever talked to the real platform.

**155/155 tests pass**, `flutter analyze` clean.

**Cloud backup (2026-08-05).**
The app's record now leaves the phone. Full reasoning in §3.26; §3.17's "no study data moved" is
struck through rather than quietly contradicted.

- `StudyBackup` (pure Dart serialisation), `BackupRepository` + `BackupFailure`,
  `FirestoreBackupRepository` — the only file importing `cloud_firestore` — plus `restore()` on
  both drift repositories, `BackupSyncNotifier` (debounce + manual flush) and `BackupSyncGate`
  (lifecycle flush + auto-restore onto an empty device). One new dependency.
- A Settings card: last-saved line, "احفظ دلوقتي", and a confirmed "استرجع النسخة السحابية".
- **Two real bugs found by the new tests, not by reading the code** — the auto-restore
  overwriting an existing curriculum, and Firestore being resolved in a constructor. Both are
  written up in §3.26 because they share a root cause worth recognising again: a deliberately
  safe default being asked a question it could not answer honestly.
- Firebase console work done in-session: `com.ather.app` registered, the debug SHA-1 added,
  Firestore created in `eur3` (permanent), and the rules above published.

**Verification.** `flutter analyze` clean; **148/148 tests pass** (131 before). New:
`test/domain/study_backup_test.dart` (round-trip, empty case, exact instants, and a
newer-format backup refused rather than half-read), `test/data/backup_restore_test.dart` (ids
preserved, replace-not-merge, seeded subjects untouched, and a mid-restore failure rolling back),
`test/widget/backup_test.dart` (the app fully usable with every backup call failing, a named
permission failure, auto-restore onto empty, **no** auto-restore onto populated, and the manual
restore both confirmed and cancelled). Every existing widget test now injects
`FakeBackupRepository.failing()`.

~~**Not verified:** nothing has been written to or read from live Firestore.~~ **Verified
2026-08-05** — a signed release build on a wiped device signed in with Google and the whole
curriculum was restored from Firestore with no manual step. The size ceiling is still untested
against a large real curriculum; the round trip itself is not.

**Release signing wired (2026-08-05).**
A debug-signed release APK was built for testers, which surfaced the §9 signing item. The build
now reads `android/key.properties` for a real `release` signing config, and **refuses to build a
release at all** when that file is missing rather than falling back to the debug key. The
fallback was removed on purpose: it is silent (`flutter build` swallows Gradle warnings), and it
produces an APK that can never be upgraded in place by a properly signed one — so the failure
mode was strictly worse than a build error. `key.properties`, `*.jks` and `*.keystore` are
git-ignored; `android/key.properties.example` documents the shape. Both paths were verified:
`--release` refuses with its instructions, `--debug` still builds. **No keystore was created and
no password was chosen here** — that is the owner's to do and to back up, because a lost upload
key cannot be replaced.

**Daily tasks, a real gear, and a floating tab bar (2026-08-05).**
Three owner requests in one pass. The mastery engine, the wizard and `lib/domain/services/` were
not touched; the decisions worth reading are §3.22 (why tasks are kept structurally away from
mastery), §3.23 (the bar's new shape *inside* §3.19's existing bounds), §3.24 (the first
migration) and §3.25 (the sun that was supposed to be a cog).

- **The settings glyph was a sun.** Eight straight spokes round a circle, since the redesign
  shipped. Redrawn as an eight-tooth cog. `AtherGlyph.more` deleted with the tab that used it.
- **«المزيد» removed, «مهامك» added** in its slot — a fourth `StatefulShellBranch` at `/tasks`.
  Settings moved to a `SettingsButton` cog in every root header, which is a better home than a
  tab was: it is now one tap from anywhere rather than one tap from the dashboard.
- **The tasks screen**: the week strip on top as a **day picker**, then a plain count, then a
  `ReorderableListView`. Add via the same `showNamePrompt` as a chapter, rename/delete via the
  same `showEditSheet` and `confirmDestructive`, tick by tapping the row, reorder by long press.
  No new visual pattern was invented and no new dependency was added.
  - `WeekStrip` gained two optional parameters (`selectedDay`, `onSelect`). The dashboard passes
    neither, so its strip is byte-identical — not tappable, no third state.
  - `DayHeader` extracted from the dashboard so the two day-shaped screens cannot drift apart.
  - `proxyDecorator` is **overridden**, because Material lifts a dragged row on an elevation and
    this app has no shadows (§3.10). It returns the child on a transparent `Material` with a
    1.02 scale that collapses to 1.0 under reduced motion.
- **The bar floats**: a `ClipRRect` pill inset 16 at the sides and 12 from the bottom, the FAB
  raised 20 above it and drawn outside the clip. `AppSizes` gained `barLift`, `barHeight`,
  `fabOverhang`, a derived `fabLift` and a derived `toastBottom` — the toast's old hard-coded
  `104` would now sit behind the bar.
- **`daily_tasks`**, `schemaVersion` 2, and the app's first `onUpgrade`.

**Verification.** `flutter analyze` clean; **131/131 tests pass** (123 before), including a new
`test/widget/tasks_test.dart` — six cases driving the real screen against real in-memory SQLite:
add, tick and untick, rename, delete, a genuine long-press-and-drag whose new order is asserted
**on disk** rather than in the widget tree, per-day isolation in both directions, and a
reduced-motion case asserting the row renders with no fade layer at all — plus
`test/data/task_migration_test.dart` for v1 → v2 on a real file. Both render suites regenerated
and reviewed in light and dark, Arabic and English: the cog reads as a cog at 19px, the pill
lines up with the cards above it, content passes under it, and nothing mirrors the wrong way.

Three things worth knowing for whoever writes the next widget test against a database:
`await` on a drift future inside a `testWidgets` body **never completes** (the fake-async zone
never advances) — it must go through `tester.runAsync`; drift schedules a zero-duration timer
when a `.watch()` stream is cancelled, so the tree has to be torn down *inside* the body and
pumped twice or the binding fails with "A Timer is still pending"; and `close()` on a connection
whose streams are still unwinding does not return under the fake clock. Each of those presents as
a ten-minute hang rather than a failure, which is why they are recorded here.

**Final review and first release build (2026-08-04).**
A full pass over the motion work before cutting an APK. Findings, all fixed:

- **The before → after arrow pointed the wrong way in English.** Pre-existing, and only visible
  once the wizard was rendered in a mirrored layout for the first time. The glyph is drawn
  pointing left, which reads correctly in Arabic (before on the right, after on the left) and
  backwards in English, where it pointed from "after" back to "before". It is now mirrored when
  the ambient direction is LTR. It is deliberately **not** one of the three forced-LTR elements
  (§3.16): those are numbers and bars, where mirroring would misstate a score. An arrow is a
  direction, and direction is exactly what should flip.
- **`BranchCrossFade` used a loose `Stack`.** Replaced `IndexedStack`, which gives its children
  tight constraints; a bare `Stack` does not, so a branch could shrink-wrap instead of filling
  the screen. Now `fit: StackFit.expand`. Renders confirmed byte-identical before and after.
- **The overdue badge was mounted on all five tabs.** Four of them never carry a count, so they
  were each paying for a fade layer and a laid-out container forever to buy the review tab a
  150ms exit. It now returns `SizedBox.shrink()` until it has something to show.
- Two one-off wizard offsets (60ms, 120ms) moved into `AppMotion`. Nothing outside
  `app_spacing.dart` declares a duration now, with one documented exception: `AtherSwitch` keeps
  its pre-existing `Curves.easeOut`, which the motion spec's own table records as "existing".
- **New `test/widget/motion_test.dart`** — 16 tests covering what `pumpAndSettle` cannot prove:
  that entrances actually start from transparent, that a delayed entrance is an interval and not
  a timer, that `PopIn` never overshoots 1.0, that a count-up passes through intermediate values
  and lands exactly, that the em-dash is never counted to, and six `CollapsingList` cases
  (remove, add, add-and-remove in one rebuild, rename, empty). Suite is now **120 green**.
- A stricter lint pass (16 rules beyond `flutter_lints`, including `cancel_subscriptions`,
  `close_sinks`, `unawaited_futures`, `prefer_const_constructors`) reported **zero issues in any
  motion file**. The four hits elsewhere are pre-existing and benign — notably `close_sinks` on
  `_combineLatest6`, a false positive: the controller cancels every subscription in `onCancel`.

**Motion and the glass tab bar (2026-08-04).**
Nineteen animations (M-01…M-19) added to the finished app, plus one sanctioned glass surface.
Nothing was redesigned: no layout, colour, spacing, typography, copy, icon or navigation change,
and `lib/domain/` was not touched. The three decisions worth reading are §3.19 (the blur
exception and its measured contrast), §3.20 (the one place height animates), and §3.21 (the
tokens and why every interface duration is under 300ms).

- **Twelve new `AppMotion` tokens and one curve**, all in `core/theme/app_spacing.dart`. No
  widget declares its own duration or rise distance.
- **Six new widgets in `core/widgets/`**: `list_entrance.dart` (`ListEntrance` + `RiseIn` — the
  whole entrance vocabulary, reused by the error banner and the wizard's before/after card),
  `pop_in.dart`, `animated_percentage.dart` (`AnimatedPercentage` + `CountUpFromZero`),
  `error_banner.dart`, `collapsing_removal.dart`.
- **Route transitions live in `app/router.dart`**, defined once as `atherPage` and
  `atherModalPage`. Every `GoRoute` moved from `builder:` to `pageBuilder:`. Nothing slides
  horizontally anywhere in the app, which is how we know nothing can slide the wrong way in RTL.
- **`StatefulShellRoute.indexedStack` became the base `StatefulShellRoute`** so
  `navigatorContainerBuilder` could hand every branch to `BranchCrossFade` at once. A faded-out
  branch stays mounted — it keeps its stack and scroll position — but is wrapped in
  `IgnorePointer` + `ExcludeSemantics` + `TickerMode`: it does not stay alive.
- **Three duplicate private `_ErrorBanner` classes** (wizard, homework sheet, login) collapsed
  into one `ErrorBanner`. Three copies was three chances for one of them to start shaking.
- **`MasteryNumber` now takes `value` + `hasData`** rather than a pre-formatted string, so the
  number can count. Formatting still goes through `percentLabel`, so the LRI/PDI isolates and
  Western digits survive every frame — see §3.16.
- Two small proposals from the spec were taken: the empty review queue's disc pops (220ms, the
  same as a week-strip tick), and the overdue badge fades out at zero instead of vanishing
  mid-frame. A third — animating the bar's tint alpha on scroll — was rejected: a listener that
  rebuilds the bar on every scroll frame is not the "costs nothing" the brief allows.
- **Not** done: the eleven Lordicon Lottie icons the handoff proposes as a further layer. It was
  attempted, not waved away — the dependency resolves, but `lordicon 1.0.3` exposes no speed
  setter and no duration getter, so the spec's two-tier "fit the draw to 240ms or 600ms"
  rule cannot be built at all, and every icon would ship static. Full reasoning and the measured
  asset durations are in §9.

**Accounts and the biometric lock (2026-08-03).**
Firebase Auth (email/password + Google) and a `local_auth` app lock, added on top of the Ather
redesign. The offline-first contradiction this creates is resolved and recorded in §3.17 — the
short version is that the gate is asked **once** and answers from a session cached on disk, so
a signed-in student still opens the app with no network at all.

- `AuthRepository` in the domain layer, `FirebaseAuthRepository` the only file in the app that
  imports `firebase_auth`. Failures cross the boundary as an `AuthFailure` enum, never a
  message string.
- Login screen built from the existing kit only — no new visual pattern, no coloured Google
  mark (the design allows no coloured icons, and a monochrome redraw of a brand logo is worse
  than none).
- Router gate via `redirect` + a `refreshListenable` bridged from the account stream.
- The lock is a gate above the router, not a route, so it also covers sheets and the wizard.
- Settings gained an account card with sign-out and the fingerprint switch; the switch only
  appears where the device reports an enrolled print.

Firebase project `ather-49705`, wired with `flutterfire configure` (Android only).
`firebase login`, accepting the Firebase terms, and enabling the two providers were left to
the user — signing into their Google account and accepting a legal agreement are not mine to
do on their behalf.

**Verification.** `flutter analyze` clean; **103/103 tests pass**, including a new
`test/widget/auth_test.dart` covering the gate in both directions, sign-in, sign-out, wrong
password, the offline message, local validation and the lock covering the first frame. Every
widget test runs against `FakeAuthRepository` — a suite that needs live credentials is a suite
that stops being run.

Then run on the emulator (API 35), which is the only reason the lock works at all:

1. Registered `test@ather.app` — Firebase created the user, the gate let it through.
2. **Force-stopped the app, enabled airplane mode, relaunched → the dashboard opened
   immediately.** This is the claim §3.17 rests on, and it is now observed rather than argued.
3. Settings showed the account and signed out correctly, still with no network.
4. Enrolled a fingerprint on the emulator and switched the lock on — and the app opened
   straight to the dashboard with no prompt. That turned out to be the `FragmentActivity` bug
   in §3.18, found only because the lock was actually exercised. After the fix the system
   `BiometricPrompt` appears on launch and `adb emu finger touch 1` unlocks it.

The lock is also the reason to be sceptical of "the tests pass": the widget test asserting the
lock covers the first frame passed the entire time the feature was broken on device.

**Ather redesign (2026-08-03) — the entire presentation layer replaced.**
Implemented `ATHER_HANDOFF.md` and its interactive reference `Ather App.dc.html` to the letter.
**Product logic untouched**: the mastery formula, the 30-day decay, the chapter gate and every
domain test are byte-identical. What changed:

- **Brand and package** renamed `sahm` → `ather`. The SQLite file keeps its old name on
  purpose — renaming it would orphan every database already on a student's phone.
- **Tokens**: the two-colour rule (§3.10), Readex Pro replacing Cairo, the
  4/8/10/12/14/16/18/22/24 spacing ladder and concentric radii.
- **Widgets**: `GlassCard` and `MasteryRing` deleted. Mastery now reads as a large number plus
  a horizontal bar — there are no rings anywhere. New kit: `AtherCard`, `MasteryBar`,
  `MasteryNumber`, `StatusChip`, `WeekStrip`, `PrimaryButton` (5 tones), `DashedAddButton`,
  `AtherCheckbox`, `AtherSwitch`, `SegmentedControl`, `NumberField`, `AtherSheet`,
  `AtherToast`, `AtherIcon` (§3.12), `Pressable` (the single `scale(.97)` press response).
- **Navigation**: three tabs → five slots (الرئيسية · مراجعة · black FAB · تقدمك · المزيد —
  the last of which became مهامك on 2026-08-05).
  Settings moved above the shell; the exam wizard is a full-screen route on the root navigator
  with no tab bar. Sheets present on the root navigator so the scrim covers the tab bar.
- **Screens**: all nine rebuilt. New on the dashboard: the week strip and the "اللي بعده" card.
  Review rows now open the wizard directly. The chapter report's trend line tells the truth in
  three states instead of always saying "improved". Saving an exam or a homework score raises a
  black confirmation toast.
- **Copy**: both ARB files rewritten from the handoff's §9 dictionary, plus real ICU plurals
  and isolated numbers (§7).

**Verification.** `flutter analyze` clean; **95/95 tests pass**, including a new
`test/widget/student_flow_test.dart` that drives an empty app through chapter → lesson → the
four wizard steps (with both validation refusals) → save, against real in-memory SQLite, and
asserts the toast, the 75% the app derived, the restarted review clock and the auto-ticked
"حليت الامتحان". Android debug APK builds. Every screen was rendered to PNG and reviewed
(`tool/render/`), which is how the `Spacer`/`Flexible` bug (§3.13), the missing "today" dot on
the week strip, the `%70` in the not-ready sheet, the tab bar sitting on top of a modal sheet
and two `RenderFlex` overflows were found.

**Not verified on a device.** Windows needs Visual Studio (absent) and Developer Mode; the
Android emulator was not launched this session. The APK builds and the widget layer is
covered, but nothing here replaces a run on a real phone.

**Redesign documentation pass (2026-08-02, analysis only — zero code changes).**
Created `Redesign/` containing the full design documentation for a future Figma redesign:
App_Overview, Screens (all 9 screens + system UI), UserFlow (Mermaid), Components,
DesignSystem (extracted tokens), UX_Audit, UI_Audit, Redesign_Plan, and `Screenshots/`
(36 emulator captures incl. Arabic RTL variants, indexed in `Screenshots/INDEX.md`).
Live-confirmed defects recorded in UX_Audit: exam wizard loses input on system back;
chapter report says "Improved from X% to Y%" even when mastery declined; empty subject
app bar shows `0%` instead of the no-data em-dash; saving an exam pops to the dashboard
instead of the lesson. Side effects on the emulator's app data only: a homework entry
(4/10), a second exam (69%), and the Biology chapter marked mastered.

**Phases E–H — screens, notifications, polish, verification (complete except Windows).**
All nine screens built in the spec's order behind a `go_router` `StatefulShellRoute`, with
adaptive bottom-bar/rail navigation. Custom `CustomPainter` celebration (~120 particles with
per-particle mass, drag, spin and staggered launch; reduced-motion aware). Notification service
with resume-time reconciliation. **91/91 tests pass; `flutter analyze` clean.** Android build,
install and full manual journey verified on the emulator — see §9 for what that found.

Toolchain work needed along the way: installed Android `cmdline-tools` and the
`android-35;google_apis;x86_64` system image (the AVD pointed at an image that was never
installed), and enabled core-library desugaring (§3.14). Three extraction attempts were needed
for `cmdline-tools` — PowerShell `Expand-Archive` dies on the archive's >260-char guava path and
Git Bash's GNU `tar` cannot read zips; Windows' bundled `bsdtar` handles both.

**Phase C — pure domain services (complete).** `MasteryCalculator`,
`ReviewCycleService` and `InsightsGenerator`, all pure and clock-injected, with the full
unit suite written *before* any screen exists. **79/79 tests pass.** Coverage includes the
70/30 formula at 1/2/n exams, deterministic tie-breaking on identical timestamps, band
boundaries at 49.999/50/69.999/70/89.999/90, the review boundary at 29/30/31 days, chapter
red propagation from a single lesson, and an explicit assertion that perfect homework cannot
lift a weak exam score.

Two decisions taken here:
- **Insights are structured sealed classes, not formatted strings.** The domain layer has no
  localisation access; emitting variants lets presentation render them via ARB, so insights
  translate with the language toggle instead of being frozen at computation time.
- **`overallMastery` averages all four subjects including untouched ones.** An earlier draft
  excluded empty subjects; that was reverted as it contradicts the spec and would tell a
  student who has only touched Biology that they are 85% ready for Thanaweya Amma.

**Phase B — persistence (complete).** Drift schema with all six tables, `ON DELETE CASCADE`
throughout, idempotent four-subject seed, and `DriftStudyRepository`. **14/14 tests pass**
against real in-memory SQLite — cascades, seed idempotency, exam arithmetic and live stream
re-emission.

Two decisions taken here:
- **A single `StudySnapshot` stream instead of per-entity queries.** Every headline screen is
  cross-cutting (the dashboard averages all four subjects, Review Center scans every lesson),
  so separate repositories would mean hand-written joins in the UI and screens disagreeing
  because they read at different moments. Data volume makes it free: a maximal student is a
  few hundred lessons.
- **`_combineLatest6` hand-rolled** rather than adding rxdart for one operator.

**Phase A — scaffold and foundation (complete).**
`flutter create` (`sahm`, `com.sahm`, android + windows), git init, all dependencies pinned,
design tokens, Cairo variable font, ar/en ARB + generated delegate, breakpoints, `Clock`,
dark theme, bootstrap screen. Resolved three dependency conflicts (see §3.6) and the Cairo
static-TTF 404 (see §3.5). `flutter analyze` clean; 2/2 tests pass including the RTL→LTR
direction assertion.
