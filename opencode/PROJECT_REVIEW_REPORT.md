# Ather — Technical Review Report

**Reviewed commit:** `8e026a2` (branch `claude/project-review-report-d63cdb`)
**Review date:** 2026-08-11
**Reviewer role:** Technical Reviewer — analysis only, no code was modified.

**Verification performed for this review**

| Check | Command | Result |
|---|---|---|
| Static analysis | `dart analyze` | **No issues found** |
| Test suite | `flutter test` | **200 / 200 passing** (~14s) |
| Worktree state | `git worktree list` + `git status` per worktree | All three worktrees clean — this checkout is the current design |
| ARB locale parity | JSON key diff `app_ar.arb` ↔ `app_en.arb` | 226 / 226 keys, **zero drift in either direction** |

---

# Executive Summary

Ather is an offline-first Flutter application that measures **mastery** for Egyptian Thanaweya
Amma students. Its single product claim — mastery is derived from real exam performance and
nothing else, and it decays after 30 days — is enforced structurally, not just documented:
`MasteryCalculator` is a pure, dependency-free file, homework is explicitly excluded from every
function in it, and there is no "mark as reviewed" affordance anywhere in the UI.

**This is a genuinely well-engineered codebase, well above the norm for a project of its size.**
The layering is clean and the dependency direction is never violated. `firebase_auth` is imported
in exactly one file, `cloud_firestore` in exactly one file, and both translate every foreign error
into a domain enum at the boundary so no vendor error string can reach a screen. Static analysis
is clean, there is not a single `TODO`, `FIXME`, or stray `print()` in `lib/`, and the tests pass.
The commentary is exceptional: most non-obvious decisions carry the *failure that motivated them*,
which is the rarest and most useful form of documentation there is.

The weaknesses are almost entirely at the **edges** — the places where the app meets an
infrastructure the repository does not control or describe.

The dominant finding is that **the Firestore security rules that protect every student's backup do
not exist anywhere in this repository.** There is no `firestore.rules` file, `firebase.json`
contains no `firestore` section, so `firebase deploy` would not deploy rules even if they existed,
and no test asserts them. Every student's entire exam history is stored at
`users/{uid}/backup/snapshot`, and whether one student can read another's is decided entirely by
console configuration that is invisible to this repo, unreviewable in a diff, and unrecoverable if
it is ever changed by accident. The code is clearly aware rules matter — two separate comments name
"the rules were never published" as a known failure mode — which makes their absence from version
control a gap rather than an oversight in thinking.

The second-order findings are a **notification/UI clock disagreement** (a reminder can fire up to
23 hours before the in-app screen agrees the lesson is due, and the resume trigger deliberately
does not correct it), **two dependencies that are declared but never used** — including `fl_chart`,
which the analytics screen's own doc comment says it deliberately does not use — **no CI**, **no
crash reporting**, **R8 minification disabled** on release builds, and a **stock, unmodified
`analysis_options.yaml`** that is well below the discipline the rest of the codebase displays.

Nothing found blocks the app from working. Nothing found risks the local database, which the
project correctly treats as its most valuable asset. But the cloud boundary needs attention before
this reaches real students at scale.

---

# Project Overview

## Project type

A **single-market, offline-first Android mobile application** (Flutter), with a Windows desktop
target that is scaffolded but documented as unbuildable on the current machine. No iOS, macOS,
Linux, or web platform directories exist.

The product is a study-tracking tool for Egyptian Thanaweya Amma (علمي علوم) students. The student
builds their own curriculum inside four fixed subjects (Biology, Physics, Chemistry, English), then
proves understanding by entering real exam results question-group by question-group. The app
computes the percentage; the student never types one.

## Technologies used

| Layer | Choice | Version | Notes |
|---|---|---|---|
| Framework | Flutter / Dart | SDK `^3.12.2` | |
| State | `flutter_riverpod` | `3.4.2` | Pinned exactly |
| Persistence | `drift` + `drift_flutter` | `2.34.3` / `0.3.1` | SQLite with reactive `.watch()` |
| Navigation | `go_router` | `17.3.0` | `StatefulShellRoute`, per-tab stacks |
| Auth | `firebase_auth` + `google_sign_in` | `^6.5.6` / `^7.2.0` | |
| Cloud backup | `cloud_firestore` | `^6.8.0` | One gzipped blob per student |
| Local lock | `local_auth` | `^3.0.2` | Biometric / device-PIN gate |
| Reminders | `flutter_local_notifications` + `timezone` | `22.2.0` / `0.11.1` | `zonedSchedule`, inexact alarms |
| Preferences | `shared_preferences` | `2.5.5` | Locale, theme, lock, last-uid |
| Charts | `fl_chart` | `1.2.0` | **Declared but never imported — see H-2** |
| Icons | `cupertino_icons` | `^1.0.8` | **Declared but never imported — see L-1** |

Direct dependency versions are largely **pinned exactly** rather than caret-ranged, which is the
right call for an app whose upgrade path must never surprise a student mid-term.

## Project structure

```
lib/
├── app/                      app.dart, router.dart — composition root
├── core/                     framework-facing, no domain knowledge
│   ├── branding/             CustomPainter mark + logo
│   ├── clock/                Clock abstraction (SystemClock / MutableClock)
│   ├── l10n/                 ARB sources + generated delegates + formatting
│   ├── layout/               breakpoints
│   ├── theme/                colors, spacing, typography, mastery palette
│   └── widgets/              22 shared widgets (design system)
├── data/                     the ONLY layer that touches the outside world
│   ├── auth/                 firebase_auth_repository.dart   (only firebase_auth import)
│   ├── backup/               firestore_backup_repository.dart (only cloud_firestore import)
│   ├── db/                   app_database.dart, tables.dart, app_database.g.dart
│   ├── notifications/        review_notification_service.dart
│   └── repositories/         drift_study_repository.dart, drift_task_repository.dart
├── domain/                   pure Dart — no Flutter, no drift, no Firebase
│   ├── entities/             9 entities incl. StudySnapshot, StudyBackup
│   ├── repositories/         4 abstract interfaces
│   └── services/             mastery_calculator, review_cycle_service,
│                             insights_generator, summaries
└── presentation/             13 screens + 8 provider files
```

**Size:** ~25,600 lines in `lib/` across 90 files, of which ~8,900 are generated
(`app_database.g.dart` 5,612 + the three localization files ~3,036). Hand-written application
code is roughly **16,700 lines**, against **6,055 lines of tests** — a test-to-source ratio of
about **0.36**, which is healthy.

**Layering is respected.** `domain/` imports nothing from `data/` or `presentation/`. Every
`domain/services/` file is pure and takes `now` as an explicit parameter rather than calling
`DateTime.now()`, which is why the entire 30-day decay mechanic is testable in milliseconds.

---

# Overall Score

| Dimension | Score | Basis |
|---|---:|---|
| **Architecture** | **92** / 100 | Clean layering, single-file vendor boundaries, correct dependency direction. Ceiling: the whole-database snapshot model (M-1). |
| **Code Quality** | **94** / 100 | Zero analyzer issues, zero TODOs, zero stray prints, exceptional rationale comments. Held back only by the stock lint config (M-4). |
| **Maintainability** | **90** / 100 | Outstanding decision records; every non-obvious choice explains the bug that caused it. Held back by 600–960 line screen files (M-5) and no CI (H-4). |
| **Performance** | **72** / 100 | Correct for the stated scale and consciously reasoned, but O(total data) per write, eager `ListView` children, serial notification scheduling, R8 off. |
| **Security** | **58** / 100 | Excellent error-boundary and multi-account hygiene, but Firestore rules are absent from the repo (C-1), no App Check (H-3), no obfuscation. |
| **UI** | **93** / 100 | Real design system, mechanically asserted design invariants, golden renders for both themes, full RTL. |
| **UX** | **90** / 100 | Honest failure states, offline-first by construction, no false celebration. Held back by the clock disagreement (H-1). |
| **Documentation** | **96** / 100 | `PROJECT.md` (1,668 lines) is a genuine design source of truth with an honest known-issues register. |
| *(Supplementary)* **Testing** | **80** / 100 | 200 passing tests incl. migration, backup round-trip, design invariants. Gap: the three files that touch the outside world have no direct tests (M-3). |

## Final rating

> ## **84 / 100 — Strong**
>
> A disciplined, well-documented, product-coherent codebase whose weaknesses cluster almost
> entirely at the infrastructure boundary rather than in the application itself.
>
> **One Critical item must be resolved before real students depend on cloud backup.**
> The rest is hardening, not repair.

---

# Strengths

**1. The product rule is enforced by structure, not by convention.**
`lib/domain/services/mastery_calculator.dart` is pure Dart with no Flutter, drift, or Firebase
import. Homework, checklist ticks, and time-studied are absent from every function in it, and the
file says so explicitly. A future contributor cannot accidentally let homework influence mastery
without deleting a comment that tells them not to.

**2. Vendor SDKs are quarantined to one file each.**
`firebase_auth` appears only in [`firebase_auth_repository.dart`](../lib/data/auth/firebase_auth_repository.dart),
`cloud_firestore` only in [`firestore_backup_repository.dart`](../lib/data/backup/firestore_backup_repository.dart).
Both translate every failure into a domain enum (`AuthFailure`, `BackupFailure`) at the boundary,
so no Firebase error code and no untranslated English string can reach a screen. This is textbook,
and it is actually followed.

**3. Migration discipline matches the stated stakes.**
`schemaVersion` and `onUpgrade` are documented as moving together
([`app_database.dart:35-56`](../lib/data/db/app_database.dart#L35)), the migration is additive
only, `PRAGMA foreign_keys = ON` is set per-connection in `beforeOpen` (without which every
`ON DELETE CASCADE` in `tables.dart` would be silently inert), and
[`test/data/task_migration_test.dart`](../test/data/task_migration_test.dart) builds a real v1
database image on disk and reopens it.

**4. Restore is transactional and refuses rather than truncates.**
[`DriftStudyRepository.restore`](../lib/data/repositories/drift_study_repository.dart#L362) wraps
the delete and every insert in one transaction, so a failure mid-way rolls back rather than leaving
a half-erased curriculum. `upload` refuses a payload over 900 KiB rather than truncating it, with
the reasoning stated: a backup missing its most recent two years is worse than no backup, because
the student believes they have one.

**5. Multi-account contamination is handled in both directions.**
[`backup_gate.dart:50-61`](../lib/presentation/providers/backup_gate.dart#L50) wipes the device
when a *different* uid signs in, writes the new uid only **after** the wipe (so a crash mid-wipe
leaves the device claiming the old uid and retries next launch), and
[`backup_providers.dart:99-102`](../lib/presentation/providers/backup_providers.dart#L99) refuses
to upload until the stored uid and the signed-in uid agree. Both guards exist to stop one student's
curriculum reaching another student's cloud document, and both are needed.

**6. Auto-restore reads the database, not the UI-safe provider.**
`_restoreIfEmpty` deliberately awaits `snapshotProvider.future` rather than reading
`snapshotValueProvider`, because the latter falls back to `StudySnapshot.empty()` while loading —
and asking "is this device empty?" at the one moment the honest answer is "not known yet" is how a
student's existing curriculum got replaced by a cloud copy. The comment documents exactly that.

**7. Deleting an exam correctly moves the clock that exam started.**
[`deleteExam`](../lib/data/repositories/drift_study_repository.dart#L271) recomputes
`lastReviewedAt` from the newest surviving exam *and* the chapter's `masteredAt`, taking whichever
is later. Most codebases would delete the row and leave a review clock the student never earned.

**8. Design regressions are asserted mechanically.**
[`test/design_invariants_test.dart`](../test/design_invariants_test.dart) asserts the brand accent
is saturated and in the blue hue range, and that the tab bar has no "+". Its header explains that
the approved refresh was reverted **twice** by agents working from a stale base. Converting a
recurring process failure into a failing test is the correct response.

**9. Heavy work is moved off the frame thread.**
Backup serialization and gzip run in `Isolate.run` with the reason stated: a two-year record is
tens of milliseconds of solid CPU, and it ran on a 20-second debounce — meaning it landed *while
the student was using the app*.

**10. Localization is complete and correct.**
226 keys, **exact parity** between `app_ar.arb` and `app_en.arb` with zero drift in either
direction. Arabic is the template and the fallback (`kSupportedLocales` puts `ar` first), Arabic
plural rules are tested rather than assumed, and there is a dedicated test that percentages inside
Arabic sentences are bidi-isolated — a bug the team found and fixed by rendering every screen.

**11. Text scaling is capped deliberately, not accidentally.**
`MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` in
[`app.dart:109-115`](../lib/app/app.dart#L109), with the reasoning given: the dense number rows
break apart past ~1.3×, and a student who cannot read the score is worse off than one reading it
slightly smaller.

**12. The known-issues register is honest.**
`PROJECT.md` §9 documents unexercised paths (Google sign-in on a device, reboot survival), records
an abandoned feature with the measured evidence for abandoning it (the Lottie/Lordicon layer, with
asset durations against budget), and strikes through items as they are resolved with dates. Very
few projects maintain this.

---

# Issues

Severity legend — **Critical:** must be fixed immediately. **High:** important, does not stop the
app working. **Medium:** worthwhile improvement. **Low:** optional polish.

---

## Critical

### C-1 — Firestore security rules exist nowhere in this repository

**Where:** `firebase.json`; absence of any `firestore.rules` file anywhere in the tree.

**Cause.** Every student's complete study record is written to
`users/{uid}/backup/snapshot` ([`firestore_backup_repository.dart:56-64`](../lib/data/backup/firestore_backup_repository.dart#L56)).
What prevents student A from reading student B's document is a Firestore security rule. That rule
is not in this repository:

- `find . -name "*.rules"` returns nothing.
- `firebase.json` contains only a `flutter.platforms` block — **no `firestore` section**, so
  `firebase deploy` would not deploy rules even if a file existed.
- No test asserts the rules (the Firebase emulator suite is not configured).

The code is plainly aware that rules are load-bearing: `BackupFailure.permissionDenied` is
documented in [`backup_providers.dart:26-28`](../lib/presentation/providers/backup_providers.dart#L26)
as meaning "the rules were never published", and `backup_gate.dart:130` repeats the phrase. So the
mechanism is understood — it simply lives only in a web console.

**Impact.** The confidentiality of every student's entire exam history depends on configuration
that is invisible to this repository, unreviewable in a pull request, not restorable from git, and
silently destroyable by one wrong click in the Firebase console. If the project was ever created in
Firestore **test mode**, the default rule grants open read/write to any authenticated caller until
it expires — and after expiry it denies everything, which would break backup for every student with
no code change to explain it. Nobody reading this repository can tell which state it is in. This is
the single highest-consequence unknown in the project.

Compounding it: `android/app/google-services.json` is committed (which is normal — it holds client
identifiers, not secrets), so the project id and API key are in the repo. That is only a problem
*because* the rules are unverifiable.

**Proposed fix.** Bring the rules into version control and into the deploy path.

1. Create `firestore.rules` at the repository root:

   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // A student's backup is readable and writable by that student and nobody else.
       match /users/{uid}/backup/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
       // Nothing else in this project is reachable from a client.
       match /{document=**} {
         allow read, write: if false;
       }
     }
   }
   ```

2. Register it in `firebase.json` so it actually deploys:

   ```json
   { "firestore": { "rules": "firestore.rules" } }
   ```

3. Verify the console currently matches, then deploy with `firebase deploy --only firestore:rules`.
4. Add a rules test under the Firebase emulator asserting that uid `A` is denied a read of uid
   `B`'s document. That single test is what stops this regressing.

Consider also a `request.resource.size() < 1048576` guard so the 900 KiB client-side budget in
`_maxBlobBytes` is enforced server-side rather than trusted from the client.

---

## High

### H-1 — A review reminder can fire up to 23 hours before the app agrees the lesson is due

**Where:** [`review_cycle_service.dart:46-50`](../lib/domain/services/review_cycle_service.dart#L46)
and [`app_providers.dart:79-137`](../lib/presentation/providers/app_providers.dart#L79).

**Cause.** Two clocks disagree about what "30 days" means.

- The **notification** is scheduled at `dueAt` = `lastReviewedAt + 30 days`, which is
  hour-precise ([`review_notification_service.dart:139-143`](../lib/data/notifications/review_notification_service.dart#L139)).
- The **UI** derives overdue state from `daysSinceReview`, which is
  `now.difference(last).inDays` — elapsed 24-hour periods, truncated.
- But `nowProvider` only re-emits at **local midnight** and on **app resume**, and the resume
  branch deliberately returns early when the calendar day has not changed
  (`if (lastDay != null && dayOnly(clock.now()) == lastDay) return;`).

Worked example. A student records an exam at **23:00 on day 0**.

| Moment | `dueAt` reached? | `inDays` | UI says | Notification |
|---|---|---|---|---|
| Day 30, 00:00:01 (midnight tick) | no | 29 | "1 day left" | — |
| Day 30, 23:00 | **yes** | 30 | still "1 day left" — no emission scheduled | **fires** |
| Student taps it → app resumes | yes | 30 | still "1 day left" — resume returns early, same calendar day | — |
| Day 31, 00:00:01 | yes | 30 | now overdue / red | — |

**Impact.** The student receives a notification saying a lesson is due, taps it, lands on the
lesson screen, and finds a green "باقي 1 يوم" countdown that contradicts the notification they just
tapped. The window is up to ~23 hours wide and is *widest for students who study in the evening* —
which is most of them. The resume trigger added specifically to fix stale clocks does not help
here, because the calendar day genuinely has not changed. For a product whose entire mechanic is
the review clock, the notification and the screen disagreeing about it is a credibility problem,
not a cosmetic one.

**Proposed fix.** Make the two definitions agree. Either:

- **(a)** schedule the notification at the start of the day the UI will flip — i.e.
  `dayOnly(lastReviewedAt + 30 days) + 1 day` at a chosen hour — so the reminder never precedes
  the in-app state; **or**
- **(b)** make `daysSinceReview` calendar-day based (`dayOnly(now).difference(dayOnly(last)).inDays`)
  and schedule the notification at `dayOnly(dueAt)` at a fixed hour.

**(b) is the better fit** for a codebase that already states everything downstream is derived from
whole days. Either way, add a test in
[`review_cycle_service_test.dart`](../test/domain/review_cycle_service_test.dart) that pins an
evening `lastReviewedAt` and asserts `dueAt` and the first `needsReview == true` fall on the same
calendar day.

### H-2 — `fl_chart` is a declared dependency that no file imports

**Where:** [`pubspec.yaml:28-29`](../pubspec.yaml#L28).

**Cause.** `pubspec.yaml` declares `fl_chart: 1.2.0` under the comment `# Analytics charts`. A
grep across `lib/`, `test/`, and `tool/` finds **zero** references. The analytics screen's own
doc comment states the opposite intent explicitly:

> *"Deliberately plain geometry: plain rectangles, one colour rule, no chart library."*
> — [`analytics_screen.dart:26-27`](../lib/presentation/analytics/analytics_screen.dart#L26)

The screen was evidently rewritten to hand-draw its bars and the dependency was never removed.

**Impact.** Three costs. It ships unused Dart code into every APK, inflating a download for
students the project explicitly targets as bandwidth-sensitive. It is a live entry in the
dependency-resolution graph, so it can block a future SDK or `intl` upgrade for no benefit. And it
actively misleads: the next contributor reading `pubspec.yaml` will reasonably conclude charts are
drawn with `fl_chart` and may build a new screen on it, contradicting a design decision the
analytics screen documents as deliberate.

**Proposed fix.** Remove the `fl_chart` line and its comment from `pubspec.yaml`, run
`flutter pub get`, and confirm the analytics screen and its goldens are unaffected (they will be —
nothing imports it). If hand-drawn geometry is a standing rule rather than a one-off, promote it to
a line in `PROJECT.md` §2 so it is not re-litigated.

### H-3 — Firebase App Check is not configured

**Where:** No `firebase_app_check` dependency; no initialization in `main.dart`.

**Cause.** `google-services.json` is committed to the repository (correctly — it holds client
identifiers, not secrets). But with App Check absent, nothing verifies that a request to Firestore
or Firebase Auth originates from the genuine Ather app. Any party with the config file can call the
project's backend directly with a script.

**Impact.** Combined with C-1 this is serious; alone it is still meaningful. An unattested backend
permits automated account creation against Firebase Auth, and Firestore reads and writes billed to
this project by callers that are not the app. On the Firebase free tier the practical outcome of
abuse is a quota exhaustion that takes cloud backup down for every real student at once.

**Proposed fix.** Add `firebase_app_check`, activate the Play Integrity provider for Android
release builds and the debug provider for local development, then enable enforcement for Firestore
and Auth in the console. Enforce only after a release with App Check active has been in the field
long enough that older installs are not locked out — the app's own Rule 1 (every APK must upgrade
the one before it) applies to backend enforcement too.

### H-4 — No continuous integration

**Where:** No `.github/` directory; no CI configuration of any kind in the tree.

**Cause.** The project has genuinely valuable quality gates — `dart analyze` clean, 200 tests
passing, `test/design_invariants_test.dart` guarding the approved design, golden renders under
`tool/render/` — and **none of them run automatically.** Every one depends on a human remembering.

**Impact.** This is the mechanism that would have caught the failures `CLAUDE.md` and
`design_invariants_test.dart` describe. The approved design was reverted **twice**; a debug-signed
APK shipped; a stale-base build went out. The design-invariant tripwires now exist, but a tripwire
nobody is required to trigger is a tripwire that gets skipped precisely on the rushed commit that
needed it. `CLAUDE.md` Rule 3 ("finished work gets committed") is enforced by prose alone, which
the repository's own history shows is insufficient.

**Proposed fix.** A single workflow on push and pull request:

```yaml
# .github/workflows/ci.yaml
name: CI
on: [push, pull_request]
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.44.x' }
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze --fatal-infos
      - run: flutter test
```

Add a second job that fails when `pubspec.yaml`'s `+N` build number is unchanged relative to the
base branch — that converts Rule 1's first condition from a discipline into a gate.

### H-5 — No crash or error reporting in production

**Where:** No `firebase_crashlytics` / `sentry_flutter` dependency; no `FlutterError.onError` or
`PlatformDispatcher.onError` handler anywhere.

**Cause.** All six error paths in the app terminate at `debugPrint`
(`main.dart:30`, `lock_screen.dart:96,106`, `write_guard.dart:39`,
`exam_entry_screen.dart:256`, `settings_screen.dart:359`). `debugPrint` is a no-op sink in a
release build. Several `catch` blocks are intentionally silent — `notification_providers.dart:133`
and `backup_gate.dart:129` both swallow deliberately, and both are correct decisions in isolation.

**Impact.** The project's own history is a list of **silent** failures: notifications that
scheduled successfully and never appeared because two receivers were undeclared; a
`permissionGranted` flag that only a never-called method could set, so no reminder was ever
scheduled on any device; a lock screen that released on any exception, making it decorative. Every
one was found by a human on a physical device, months later. A crash reporter would not have caught
all of them — but it is the only mechanism that turns "a student's writes are silently failing" from
something nobody learns into something visible the same day.

**Proposed fix.** Add Crashlytics (already in the Firebase stack, so no new vendor):

```dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

Then upgrade the deliberate `debugPrint` sites in `write_guard.dart` and
`firestore_backup_repository.dart` to non-fatal `recordError` calls so a student whose writes are
failing is *countable* rather than merely apologised to. Ship it behind the existing opt-in cloud
posture and say so in Settings — the project's privacy stance deserves consistency.

---

## Medium

### M-1 — Every write re-reads and re-derives the entire database

**Where:** [`drift_study_repository.dart:24-39`](../lib/data/repositories/drift_study_repository.dart#L24)
and [`summaries.dart:260`](../lib/domain/services/summaries.dart#L260).

**Cause.** `watchSnapshot()` combines six full-table `.watch()` streams. Drift re-runs each query in
full whenever its table is written, so **ticking one checkbox on one lesson re-reads all six
tables**, rebuilds `StudySnapshot`, and re-runs `Summaries.dashboard`, which walks every subject,
chapter, and lesson to recompute every mastery figure in the app.

To be fair to the design: this is a *reasoned* choice, not an accident. The comments state it —
"a snapshot is only coherent if all six agree" — and the coherence guarantee it buys is real, which
is why no screen ever invalidates a cache by hand. The `masteries` map threaded through `Summaries`
already removed the worst of the redundancy (each lesson was being visited about four times, each
visit copying and re-sorting its exam list).

**Impact.** Cost is O(total student data) per write regardless of what changed. At the stated
scale — a few hundred lessons, a few thousand exams — this is genuinely fine, and the team measured
enough to fix the multiplier. But it is the app's hard scaling ceiling, and the growth is silent:
nothing degrades until a two-year student's dataset makes each checklist tap visibly janky. Note
that `MasteryCalculator.subjectMasteryOf` and `overallMastery` still use the un-memoized path
(`chapterMasteryOf` → `lessonMastery`, with its defensive copy-and-sort per lesson) — `Summaries`
avoids them, but any future caller reaching for the obviously-named public API pays the old cost.

**Proposed fix.** No change is warranted today; the current design is correct for the current
scale. What *is* warranted is a measurement and a tripwire. Add a benchmark test that builds a
snapshot at ~500 lessons / ~3,000 exams and asserts `Summaries.dashboard` completes inside a frame
budget. If it ever fails, the escalation path is already visible: narrow the watched queries so a
lesson-only write does not re-read exams, and memoize per-chapter summaries keyed on chapter id.

### M-2 — `AtherScreen` builds every row of every list eagerly

**Where:** [`ather_scaffold.dart:134-142`](../lib/core/widgets/ather_scaffold.dart#L134).

**Cause.** The chrome shared by every screen in the app takes `List<Widget> children` and passes it
to `ListView(children: children)`. The caller has therefore already constructed every child widget
before the `ListView` exists. `ListView.builder` / `SliverChildBuilderDelegate` — which construct
children lazily as they scroll into range — is used in exactly one place in `lib/`
(`tasks_screen.dart:213`, and only because `ReorderableListView.builder` requires it).

**Impact.** A chapter with 200 lessons constructs 200 widget subtrees on every rebuild of that
screen, and M-1 means every database write *is* a rebuild. Element and render-object creation
remains lazy, so this is a widget-construction and garbage-collection cost rather than a layout
one — but it compounds with M-1 exactly where the data is largest.

**Proposed fix.** Change `AtherScreen` to accept an optional `itemBuilder` alongside `children`, and
migrate the screens that render unbounded collections — chapter (lessons), review center, analytics
(chapters and weakest lessons) — to the builder form. Screens with a fixed handful of cards can keep
the current API unchanged.

### M-3 — The three files that touch the outside world have no direct tests

**Where:** `firestore_backup_repository.dart`, `firebase_auth_repository.dart`,
`review_notification_service.dart`.

**Cause.** No file in `test/` references any of the three. Testing is done against fakes
(`test/support/fake_auth.dart`, `fake_backup.dart`, `fake_local_auth.dart`), which correctly proves
that *callers* behave — but leaves the adapters themselves unexercised. Both Firebase adapters do
accept injection (`FirestoreBackupRepository([this._firestore, this._auth])`), so the seam already
exists.

**Impact.** The untested logic is exactly where the project's documented silent failures have lived.
`_guard`'s `FirebaseException.code` switch decides whether a student is told "you are offline" or
"backup is misconfigured" — and given C-1, `permission-denied` is the code most likely to fire in
production. `_map` in the auth repository decides every login error message a student ever reads.
Neither mapping is asserted anywhere, so a Firebase SDK upgrade that renames a code would silently
degrade every message to `AuthFailure.unknown` with all tests still green.

**Proposed fix.** Table-driven tests over the pure mapping functions, which need no network:
feed each `FirebaseAuthException` code to `_map` and each `FirebaseException` code to `_guard`,
asserting the resulting enum. Extract `_encode` / `_decode` (already top-level) into a round-trip
test including the >900 KiB `tooLarge` refusal and a corrupt-gzip `unreadable` path. For
`ReviewNotificationService`, assert `reschedule` skips lessons whose `dueAt` is in the past and
emits nothing when `permissionGranted` is false — both are pure decisions above the plugin call.

### M-4 — `analysis_options.yaml` is the unmodified Flutter template

**Where:** [`analysis_options.yaml`](../analysis_options.yaml).

**Cause.** The file is the stock template: `include: package:flutter_lints/flutter.yaml`, an empty
`rules:` block containing only the two commented-out examples the template ships with, and **no
`analyzer:` section at all**. That means `strict-casts`, `strict-raw-types`, and `strict-inference`
are all off.

**Impact.** The gap between the project's actual discipline and its enforced discipline is wide.
The codebase already writes explicit generic type arguments everywhere by hand
(`<Widget>[...]`, `<String, Object?>{...}`) — a convention `strict-raw-types` would enforce for
free and which will erode the first time someone is in a hurry. `strict-casts` is directly relevant
to `StudyBackup.fromJson`, which is full of unchecked `as int` / `as bool` casts on untrusted
decoded JSON. Those are currently safe *only* because `download()` catches `Object` and converts
everything to `BackupFailure.unreadable` — a defence that works but that the analyzer cannot see.

**Proposed fix.**

```yaml
analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
    strict-inference: true

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - prefer_final_locals
    - unawaited_futures        # already respected by hand in backup_providers.dart:84
    - use_build_context_synchronously
```

Given `dart analyze` currently reports zero issues, this should be a near-empty diff — which is the
point: it costs almost nothing now and locks in a standard that is otherwise unenforced. Exclude
`lib/**/*.g.dart` and `lib/core/l10n/generated/**` from the strict modes.

### M-5 — Several screen files carry too much for one file

**Where:** `exam_entry_screen.dart` (962 lines), `lesson_screen.dart` (666),
`analytics_screen.dart` (600), `chapter_screen.dart` (487).

**Cause.** Each holds its screen widget plus every private sub-widget it uses. `analytics_screen.dart`
alone contains `_InsightsCard`, `_FilterRow`, `_SubjectBarsCard`, `_ChapterBarsCard`, `_WeakestCard`,
and `_DisciplineCard`. `exam_entry_screen.dart` holds a four-step wizard, its `_GroupDraft`
controller model, validation for each step, and every step's rendering.

**Impact.** Modest and localized — these files are well-organized internally and thoroughly
commented, so this is a readability tax rather than a defect risk. But it is the reason
`analytics_screen.dart` and `settings_screen.dart` have no widget tests: there is no seam to test a
card through without pumping the whole screen. It also raises merge-conflict probability on the
screens most likely to change.

**Proposed fix.** Follow the pattern the project has already established at
`lib/presentation/tasks/widgets/task_row.dart` — a `widgets/` subdirectory per screen. Extract the
six analytics cards to `presentation/analytics/widgets/`, and the wizard's four steps to
`presentation/exam_entry/steps/`. Doing this to analytics first also unblocks the widget tests it
currently lacks.

### M-6 — Release builds ship unminified, unshrunk, and unobfuscated

**Where:** [`android/app/build.gradle.kts:99-111`](../android/app/build.gradle.kts#L99).

**Cause.** The `release` build type sets only `signingConfig`. There is no `isMinifyEnabled`, no
`isShrinkResources`, and no ProGuard/R8 rules file anywhere in the project. `RELEASING.md` does not
mention `--obfuscate` or `--split-debug-info`.

**Impact.** Three costs, all avoidable. The APK is larger than it needs to be — which matters for
the target market. Unused resources ship, including the Material and Cupertino defaults the design
does not use. And with no obfuscation the compiled Dart retains readable class and method names, so
the mastery formula, the review-cycle constants, and the backup document path are all trivially
readable by anyone who unpacks the APK — which is the same path an attacker takes to find the
Firestore layout that C-1 leaves unprotected.

**Proposed fix.**

```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    signingConfig = /* unchanged */
}
```

Add a `proguard-rules.pro` with the keep rules for `flutter_local_notifications` receivers (they are
referenced by name from `AndroidManifest.xml`, so R8 will otherwise strip them — reproducing exactly
the silent-notification failure `PROJECT.md` §9 records). Add `--obfuscate --split-debug-info=` to
the release command in `RELEASING.md`, and store the symbol files with the keystore backup —
obfuscated stack traces are unreadable without them, which matters more once H-5 is done.

### M-7 — Timezone resolution guesses from UTC offset

**Where:** [`review_notification_service.dart:166-179`](../lib/data/notifications/review_notification_service.dart#L166).

**Cause.** `_resolveTimeZoneName()` reads `DateTime.now().timeZoneOffset` and returns
`Africa/Cairo` for UTC+2 or UTC+3, and `UTC` for everything else. The comment is candid that this is
a deliberate trade to avoid a native timezone plugin.

**Impact.** Two distinct wrong answers. A student in Riyadh, Nairobi, Istanbul, or Johannesburg —
plausible for an expatriate Egyptian family, which is a real segment for Thanaweya Amma — is at
UTC+2 or +3 and gets silently mapped to Cairo, so reminders land at the wrong local hour whenever
Egypt's DST rules diverge from theirs. A student anywhere else falls back to UTC, so a 30-day
reminder can arrive in the middle of the night. Neither case produces an error; the reminder simply
arrives at an unhelpful time, which is indistinguishable from the feature being poor.

**Proposed fix.** Use `flutter_timezone` to read the device's actual IANA zone name and pass it to
`tz.getLocation`, keeping the current offset heuristic as the fallback when the lookup throws. This
is one small dependency for correctness on the app's only time-sensitive outbound feature. If a new
dependency is unacceptable under `MOTION_BRIEF.md` §6's budget, the cheaper mitigation is to
schedule reminders at a fixed local hour (e.g. 18:00) derived from `DateTime`, which is timezone
correct by construction — and pairs naturally with the H-1 fix.

### M-8 — Notification rescheduling is serial and unbounded

**Where:** [`review_notification_service.dart:128-159`](../lib/data/notifications/review_notification_service.dart#L128).

**Cause.** `reschedule` calls `cancelAll()` then `await`s one `zonedSchedule` per eligible lesson
inside a `for` loop — one platform-channel round trip each, sequentially. The count is bounded only
by how many lessons the student has created.

**Impact.** Two concerns. Performance: at a few hundred lessons this is a few hundred sequential
platform hops, and it runs on every app resume (`_sync` is called unconditionally on `resumed`).
The 5-second debounce in `ReviewScheduler` correctly protects the write path, but not resume. More
importantly, correctness at scale: **Android caps pending alarms at roughly 500 per app.** A
two-year student with 500+ lessons carrying live review clocks would silently stop getting
reminders past the cap, with no error surfaced — the exact silent-failure shape this project has
been bitten by three times.

**Proposed fix.** Cap the schedule at the N soonest-due lessons (100 is generous; the student only
acts on the nearest few) and rely on the existing resume reconciliation to roll the window forward.
Log a non-fatal via H-5 when the eligible set exceeds the cap, so the ceiling is observed rather
than guessed at. Batching the `zonedSchedule` calls with `Future.wait` in chunks would also cut the
resume cost, though the cap matters more.

### M-9 — A student who deletes everything never has that reflected in the cloud

**Where:** [`backup_providers.dart:104-106`](../lib/presentation/providers/backup_providers.dart#L104).

**Cause.** `flush()` returns early when `snapshot.isEmpty && tasks.isEmpty`, so an empty local state
is never uploaded.

**Impact.** This guard is defensible and probably deliberate — it stops a transient empty snapshot
from destroying a good cloud backup, which is the far worse failure. But it has an unstated
consequence: a student who intentionally deletes all their chapters keeps a stale cloud copy
forever, and on the next fresh install `_restoreIfEmpty` silently restores the curriculum they
deleted. From the student's side the app resurrected data they meant to remove, with no explanation.

**Proposed fix.** Distinguish "empty because loading" from "empty because deleted". The simplest
version: allow the upload when the local state is empty *and* a previous successful upload is known
(`state.lastSavedAt != null`), which means this session actively emptied a record that existed. Add
an explicit "delete cloud backup" action in Settings alongside the existing restore, so a student
who wants the cloud copy gone can say so directly.

---

## Low

### L-1 — `cupertino_icons` is declared but never used

**Where:** [`pubspec.yaml:16`](../pubspec.yaml#L16). The only `cupertino` matches in `lib/` are
`GlobalCupertinoLocalizations`, which comes from `flutter_localizations`, not this package. No
`CupertinoIcons.*` reference exists. It is a Flutter template leftover.
**Fix:** remove the line; confirm `flutter test` and the golden renders are unchanged.

### L-2 — `_combineLatest6` is bespoke stream infrastructure with no direct test

**Where:** [`drift_study_repository.dart:518-574`](../lib/data/repositories/drift_study_repository.dart#L518).
Hand-rolling this instead of adding `rxdart` for one operator is the right call, and the
implementation looks correct (it emits only once all six sources have produced a value, forwards
errors, and cancels every subscription on cancel). But every screen's data flows through it and it
is only covered indirectly. **Fix:** a focused test with six `StreamController`s asserting no
emission before all six have fired, one emission per subsequent change, error forwarding, and that
all six subscriptions cancel.

### L-3 — `windows/` is a scaffolded target that nothing verifies

**Where:** `windows/`, and `WindowsInitializationSettings` /`WindowsNotificationDetails` in
`review_notification_service.dart`. The desktop target carries real code — including a hard-coded
notification GUID — but `PROJECT.md` §9 records that it cannot be built on the current machine.
Untested platform code drifts. **Fix:** either state in `README.md` that Windows is
unsupported-and-unverified, or add a build-only CI job for it. The choice is a product decision, not
a technical one.

### L-4 — `Routes.exam` encodes a boolean as a query string

**Where:** [`router.dart:39-40`](../lib/app/router.dart#L39). `from=lesson|list` is parsed back with
`state.uri.queryParameters['from'] != 'list'`, so any unexpected value silently means "from
lesson". Consistent with the `_intParam` philosophy of never throwing during route building, and
harmless today. Worth a note only because a restored deep link with a typo'd `from` lands the
student on a lesson screen they did not come from. **Fix:** none needed; document the default at the
parse site.

### L-5 — `debugPrint` messages are inconsistently prefixed

Four of six use an `Ather:` or `Ather lock:` prefix; `main.dart:30` uses a bare
`'Firebase init failed: …'`. Trivial, but it matters once H-5 makes these searchable.
**Fix:** one prefix everywhere.

---

# Recommendations

Ordered by (impact × certainty) ÷ effort. The first three are small, high-certainty changes that
close the largest exposures.

| # | Action | Issue | Effort | Why first |
|---|---|---|---|---|
| **1** | Commit `firestore.rules`, wire it into `firebase.json`, deploy, and add an emulator test proving uid A cannot read uid B | C-1 | ~2 h | The only finding where the current state is genuinely *unknown* from the repository. Everything else is a known cost. |
| **2** | Reconcile the notification clock with the UI clock; add the evening-`lastReviewedAt` regression test | H-1 | ~3 h | Directly undermines the product's core mechanic, and it is most visible to evening studiers — i.e. most students. |
| **3** | Delete `fl_chart` and `cupertino_icons` from `pubspec.yaml` | H-2, L-1 | ~10 min | Two lines. Removes real APK weight and a documented-as-wrong signal about how charts are drawn. |
| **4** | Add the CI workflow (format, analyze, test) plus a `versionCode`-must-increase gate | H-4 | ~2 h | Makes the design-invariant tripwires and Rule 1 automatic instead of remembered. Multiplies the value of every other test in the repo. |
| **5** | Enable R8, `isShrinkResources`, and `--obfuscate`, with keep rules for the notification receivers | M-6 | ~3 h | Smaller download for a bandwidth-sensitive market. **Test notifications on a release build afterwards** — the keep rules are the risky part. |
| **6** | Add Crashlytics with `FlutterError.onError`; promote `write_guard` and backup failures to non-fatals | H-5 | ~3 h | Converts this project's characteristic failure mode — silent, found months later on a physical device — into something countable. |
| **7** | Add Firebase App Check (Play Integrity), enforce after a release has aged in the field | H-3 | ~3 h | Closes the backend to non-app callers. Sequence after #1; enforce carefully so older installs are not locked out. |
| **8** | Tighten `analysis_options.yaml` with the strict modes and five lints | M-4 | ~1 h | Near-empty diff today. Locks in a standard the codebase already meets but does not enforce. |
| **9** | Add mapping tests for `_map`, `_guard`, and the backup encode/decode round trip | M-3 | ~3 h | Pure functions, no network needed. Covers the code most likely to fire in production once #1 lands. |
| **10** | Fix timezone resolution (`flutter_timezone`, or a fixed local hour) | M-7 | ~2 h | Pairs naturally with #2 — do them together. |
| **11** | Cap the notification schedule at ~100 soonest-due lessons; log when the eligible set exceeds it | M-8 | ~2 h | Prevents a silent reminder failure for exactly the long-tenured students the product is built for. |
| **12** | Extract screen sub-widgets into `widgets/` subdirectories, analytics first | M-5 | ~4 h | Unblocks the widget tests analytics and settings currently lack. |
| **13** | Add a scale benchmark (500 lessons / 3,000 exams) asserting `Summaries.dashboard` fits a frame budget | M-1, M-2 | ~2 h | Turns the known scaling ceiling into something that reports itself instead of arriving as jank. |
| **14** | Resolve the empty-state backup asymmetry; add "delete cloud backup" to Settings | M-9 | ~2 h | Small correctness and trust fix. |
| **15** | Test `_combineLatest6` directly; unify `debugPrint` prefixes; decide the Windows target's status | L-2, L-5, L-3 | ~3 h | Housekeeping. |

**Not recommended.** Do not restructure the snapshot architecture (M-1) yet — it is a considered
trade that buys real coherence guarantees, it is correct at current scale, and the team already
removed its worst multiplier. Measure it (#13) and revisit only if the benchmark fails. Likewise,
do not revisit the Lottie icon layer: `PROJECT.md` §9 documents the abandonment with measured asset
durations against the spec's own budgets, and that analysis is sound.

---

# Future Roadmap

## Phase 1 — Close the cloud boundary (1–2 weeks)

*Nothing here is a feature. All of it is the work that makes the existing features trustworthy.*

1. Firestore rules in version control, deployed, and tested under the emulator **(C-1)**
2. Notification/UI clock reconciliation **(H-1)** and timezone correctness **(M-7)**
3. Dead dependencies removed **(H-2, L-1)**
4. CI running format, analyze, and test on every push, with a `versionCode` gate **(H-4)**
5. Crash reporting live **(H-5)**

**Exit criterion.** A reviewer can determine, from this repository alone, who can read a student's
backup — and CI fails if that answer changes.

## Phase 2 — Harden the release path (2–3 weeks)

6. App Check added, enforced after field-aging **(H-3)**
7. R8, resource shrinking, obfuscation, with notification receivers verified on a real release
   build **(M-6)**
8. Strict analyzer modes and additional lints **(M-4)**
9. Adapter and mapping tests for the three outward-facing files **(M-3)**
10. Notification schedule capped and observed **(M-8)**
11. Close the two open items in `PROJECT.md` §9 that need a device: **reboot survival** of a pending
    reminder, and a **real Google sign-in** run

**Exit criterion.** A release build can be produced, signed, and shipped by someone who was not
present for any prior release, following `RELEASING.md` alone, with CI green.

## Phase 3 — Prepare for scale (3–4 weeks)

12. Scale benchmark for `Summaries.dashboard` **(M-1)**, with a frame-budget assertion
13. `AtherScreen` gains a lazy `itemBuilder` path; unbounded lists migrated **(M-2)**
14. Screen sub-widgets extracted; widget tests added for analytics and settings **(M-5)**
15. The motion profiling run `PROJECT.md` §9 asks for, on mid-range Android hardware, with numbers
    recorded back into §3.21
16. Backup empty-state asymmetry resolved; explicit cloud-backup deletion in Settings **(M-9)**

**Exit criterion.** A simulated two-year student dataset renders every screen inside frame budget,
and the numbers are written down.

## Phase 4 — Product surface (ongoing, after Phases 1–3)

*Deliberately last. Every item below is worth less than the trust the earlier phases buy, and each
one enlarges the surface those phases have to protect.*

17. **iOS.** The largest single reach expansion, and the domain layer is already pure enough to
    port. Non-trivial: `local_auth`, notification permissions, and the signing story all differ, and
    Rule 1's in-place-upgrade guarantee needs an iOS equivalent written down before the first build.
18. **Exam history and per-lesson trend view.** Every exam is already stored with its question
    groups; nothing in the UI shows a lesson's full history. Highest value-per-effort feature
    available, because the data exists and the calculation is already correct.
19. **Backup format v2 with incremental upload.** `formatVersion` and the refuse-newer guard are
    already in place. Worth doing only if the 900 KiB budget is observed to be approached in the
    field — instrument first (H-5), then decide.
20. **Widen the subject model.** Four subjects are hard-coded at ids 1–4 with an idempotent seed.
    Supporting other Thanaweya tracks (أدبي, رياضة) means a migration over the one table that
    cannot be regenerated, so it needs the migration test discipline of §3.24 applied deliberately —
    not a quick change.
21. **Windows desktop:** support it properly or remove it **(L-3)**. Either is fine; the current
    middle state is the only bad one.

---

## Closing note

The gap between this codebase's *internal* quality and its *infrastructure* quality is the whole
story of this review. The Dart is careful, honest, and unusually well-reasoned — decisions carry the
failures that produced them, the product's central claim is enforced structurally rather than by
convention, and the known-issues register does not flatter itself. That standard simply has not yet
been extended to the parts of the system that live outside the repository: the Firestore rules, the
release pipeline, and the continuous verification that would catch the next regression before a
human does.

Phase 1 is a small amount of work. It is what closes that gap.

---

*Report produced by static review, static analysis (`dart analyze`), and the project's own test
suite (`flutter test`, 200 passing). No application file was created, modified, or deleted; no
commit, branch, or pull request was made. The application was not run on a device or emulator, so
all runtime claims are reasoned from source and are marked as such where the distinction matters.*
