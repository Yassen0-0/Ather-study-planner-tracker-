# Ather — Motion & Glass Brief

You are implementing **motion design** in an existing, finished Flutter app. Read this whole
file before writing a line of code. Read `PROJECT.md` next — it carries the product rules and
every design decision, and it outranks your instincts.

## 0. Your scope, and its edges

You are doing exactly two things:

1. Adding **animation** to the app's existing surfaces.
2. Converting **one** surface — the bottom tab bar — to glass.

You are **not** redesigning. Do not change layout, colour, spacing, typography, copy, icons,
navigation structure, or any product logic. Every number this app shows is derived from a
mastery formula that is deliberately unchanged; do not touch `lib/domain/`.

**Do not add ideas that are not in this brief.** No parallax, no confetti, no page-curl
transitions, no animated illustrations, no mascot, no sound, no haptics beyond what is
specified, no "while I was here I also…". If something here is ambiguous, implement the
smaller, quieter version and say so in your final report. If you believe something in this
brief is wrong, say so before implementing it — do not silently substitute your own approach.

## 1. What this app is

Ather measures **mastery** for Egyptian Thanaweya Amma students. A student records real exam
results question by question; the app computes a percentage that decays after 30 days. It is
offline-first, Arabic-first (RTL), and light-theme only.

Two consequences for motion:

- **The number is the product.** Motion exists to make the number's *change* legible — before
  vs after an exam, a bar filling, a chapter turning green. Motion that competes with the
  number is wrong.
- **The tone is honest, not celebratory.** The app deliberately shows a student bad news in
  red. There is exactly one moment of joy in the entire product (mastering a chapter). Do not
  add a second one.

The app is opened many times a day, for short sessions, often at night, often on a mid-range
Android phone. Every millisecond you add is paid by the student twenty times a day.

## 2. What already exists — extend it, do not replace it

The motion system is already partly built. **Reuse these. Do not create a parallel system.**

`lib/core/theme/app_spacing.dart` → `AppMotion`:

```dart
pressScale       = 0.97
press            = 140ms   Cubic(0.34, 1.4, 0.64, 1)
sheet            = 280ms   Cubic(0.22, 1, 0.36, 1)
celebration      = 500ms   Cubic(0.34, 1.56, 0.64, 1)
value            = 600ms   Curves.easeOutCubic     // bars and numbers settling
toast            = 2200ms                          // dwell time, not a curve
```

Add new tokens to this class. Do not scatter durations through widgets.

Already animated, and correct — leave the behaviour alone unless this brief says otherwise:

| File | What it does |
|---|---|
| `core/widgets/pressable.dart` | The single press response: `scale(.97)`, 140ms. Every tappable surface already routes through it. |
| `core/widgets/mastery_bar.dart` | `TweenAnimationBuilder` fill, 600ms `easeOutCubic`, forced LTR. |
| `core/widgets/celebration_overlay.dart` | The one green-disc pop. |
| `core/widgets/ather_controls.dart` | `AtherSwitch` knob slide. |
| `core/widgets/ather_toast.dart` | Overlay toast fade-in. |
| `core/widgets/reduced_motion.dart` | `prefersReducedMotion(context)`. |

**Material's own animations are switched off on purpose** — `NoSplash.splashFactory`,
transparent highlight, zero elevation, no surface tint. Do not switch them back on to get
motion. The app's press response is `Pressable`, not ink.

## 3. Motion principles you must follow

These are not preferences. They come from the practitioner standards linked in §8, and the
reviewer will check against them.

1. **Under 300ms for interface motion.** 180ms reads as more responsive than 400ms. The only
   things allowed past 300ms are the existing 600ms value settle and the 500ms celebration.
2. **Never `ease-in` on UI.** It starts slow and delays the exact moment the user is watching.
   Default to a strong ease-out: `Cubic(0.23, 1, 0.32, 1)`.
3. **Frequency decides intensity.** The more often an interaction happens, the less it should
   animate. A tab switch happens fifty times a day; a chapter report is read once a week.
4. **Animate `transform` and `opacity` only.** In Flutter that means `FadeTransition`,
   `SlideTransition`, `ScaleTransition`, `AnimatedOpacity`, `AnimatedScale`, `AnimatedSlide`,
   `AnimatedAlign`, `TweenAnimationBuilder`. **Never animate layout** — no animated `height`,
   `padding`, `margin`, or `Flex` weights in a scrolling list. That is what causes jank on the
   phones these students own.
5. **Never scale from 0.** Enter from `0.94–0.97` with opacity 0 → 1.
6. **Reduced motion means fewer and gentler, not none.** When `prefersReducedMotion(context)`
   is true: no movement or scale, but a short opacity fade is still allowed, and the final
   state must be correct and immediate. Every animation you add must be checked.
7. **RTL is the default direction.** Any slide must use direction-aware offsets
   (`AnimatedSlide` inside the ambient `Directionality`, or `EdgeInsetsDirectional` logic).
   A hard-coded left-to-right slide is a bug in this app. Exception: progress bars and numbers
   are deliberately forced LTR — do not "fix" them.

## 4. What to animate, surface by surface

Implement exactly this table. Column 3 is what moves; nothing else moves.

### Navigation

| Surface | Trigger | Motion | Duration / curve |
|---|---|---|---|
| Screen push (subject → chapter → lesson) | navigation | incoming page fades in + rises 8px; outgoing fades out | 220ms, `Cubic(0.23,1,0.32,1)` |
| Tab switch (home / review / progress) | tab tap | cross-fade only, **no slide** — happens too often to move | 150ms, ease-out |
| Exam wizard (full-screen route) | open / close | slide up from bottom, direction-agnostic | 280ms, `AppMotion.sheetCurve` |
| Tab bar icon | becomes selected | icon + label colour tween grey → black | 150ms |
| Tab bar FAB | tap | existing `Pressable` only — nothing extra | — |
| Review badge | count appears / changes | scale 0.6 → 1 with opacity, no bounce past 1.05 | 200ms |

### Lists and cards

| Surface | Trigger | Motion | Duration / curve |
|---|---|---|---|
| Dashboard subject rows, chapter cards, lesson rows, review rows | first build of a screen | staggered entrance: fade + rise 12px, **40ms stagger, capped at 6 items** | 260ms each, ease-out |
| Any list | scrolling | **nothing.** Do not animate on scroll position. | — |
| A row added (new chapter/lesson) | after the sheet saves | the new row fades + rises in place | 260ms |
| A row removed (delete) | after confirm | fade out + collapse | 200ms |

Stagger caps at 6 because a student with forty lessons must not wait through forty delays.

### Numbers and bars — the important ones

| Surface | Trigger | Motion | Duration / curve |
|---|---|---|---|
| Mastery percentage (dashboard, subject, chapter, lesson) | value changes | **count up/down to the new number**, tabular figures already prevent width jitter | 600ms, `AppMotion.valueCurve` |
| `MasteryBar` | value changes | already correct — leave it | — |
| Exam result number (step 4) | step 4 appears | count up from 0 **once**, then never again | 600ms |
| Before → after card | step 4 appears | "before" fades in, arrow fades, "after" counts up 120ms later | 220ms + 600ms |
| Week strip circle | a day becomes complete | tick scales in 0.6 → 1 | 220ms |
| Stat row bars (6px) | value changes | existing bar behaviour | — |

The count-up is the single highest-value animation in this app: it is the moment a student
sees their work move a number. Build it as one reusable widget (e.g.
`core/widgets/animated_percentage.dart`) driven by `TweenAnimationBuilder<double>`, reusing the
existing `percentLabel` / `percent` formatters in `core/l10n/formatting.dart` so isolates and
Western digits are preserved. **Do not reimplement number formatting.**

### Overlays and state

| Surface | Trigger | Motion | Duration / curve |
|---|---|---|---|
| Bottom sheets | open / close | already correct (280ms) — leave it | — |
| Toast | appear / leave | fade + rise 12px in, fade out | 180ms in, 150ms out |
| Error banner (wizard, login, homework) | error appears | fade + rise 6px; **no shake** | 180ms |
| Wizard step change | next / back | current step fades out, next fades in + rises 10px | 200ms |
| Wizard progress segments | step advances | segment fills from the leading edge, LTR | 250ms, ease-out |
| Checklist checkbox | tick | disc fills + tick scales 0.6 → 1; label colour tween | 180ms |
| Celebration | earned | already correct — leave it | — |
| Lock screen → app | unlock | fade only | 200ms |
| Login → dashboard | sign-in succeeds | fade only | 220ms |

### Explicitly do NOT animate

Say no to all of these, and do not be talked into them by your own judgement:

- Anything on scroll position (parallax headers, shrinking titles, fading app bars).
- The four subject glyphs. They are static marks.
- Text that is being read: card body copy, the homework disclaimer, section headings.
- The mastery **colour** — red/black/green must switch instantly. A colour that fades through
  an in-between shade briefly tells the student something untrue about their score.
- Loading skeletons or shimmer. This app reads local SQLite; there is nothing to wait for.
- The keyboard-adjacent fields in the exam wizard. A student enters numbers fast.
- Anything on the settings screen beyond the existing switch.

## 5. The glass tab bar

**Read this first: `ATHER_HANDOFF.md` §0.4 forbids blur and glassmorphism, and `PROJECT.md`
§3.10 records that ban.** The app owner has explicitly approved glass for the tab bar and
**only** the tab bar. This is a sanctioned exception, not a licence to reinterpret the design
system. When you are done, add a decision entry to `PROJECT.md` §3 recording the exception and
why it is bounded — a future reader will otherwise think the ban was simply violated.

Target: the bar reads as frosted glass with the student's content visible and blurred beneath
it, so scrolling a list produces a live sense of depth in the one place the app has any.

Build it in `lib/presentation/shell/app_shell.dart`, replacing the current opaque
`Container(color: AppColors.card)`:

```dart
ClipRect(                                   // bound the blur to the bar's rect
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    child: Container(
      color: AppColors.card.withValues(alpha: 0.72),   // tint over the blur
      // existing 1px top hairline stays: AppColors.dividerStrong
    ),
  ),
)
```

Rules, all of which the reviewer will check:

- **Exactly one `BackdropFilter` in the whole app.** Blur is the most expensive thing you can
  put on screen. Never nest them, never put one in a list item.
- **`ClipRect` is mandatory.** An unbounded `BackdropFilter` blurs the entire layer tree.
- **Never animate the blur sigma.** Animating blur radius drops frames on mid-range hardware.
  If you want the bar to react to scroll, animate the *tint alpha* instead — and only if it
  costs nothing; otherwise skip it.
- **The FAB stays fully opaque black.** It is the primary action and must not go translucent.
- **Contrast is not negotiable.** The inactive-label grey `#9A9AA0` on a 72%-white blur over
  arbitrary content must stay legible. Measure it against a dark screenshot; if it fails,
  raise the tint alpha rather than darkening the label.
- **Provide a non-blur fallback.** If `MediaQuery.of(context).disableAnimations` is true or the
  platform is not Android/iOS, render the current opaque bar. Blur is a decoration, not a
  feature.

## 6. How to build it — keep it simple

This is a maintenance constraint, not a style preference. Someone has to read this in a year.

- **Prefer implicit animations.** `AnimatedOpacity`, `AnimatedScale`, `AnimatedSlide`,
  `AnimatedAlign`, `AnimatedDefaultTextStyle`, `TweenAnimationBuilder`, `AnimatedSwitcher`.
  Reach for `AnimationController` only when you genuinely need to sequence or reverse.
- **At most ONE new dependency**, and only if it removes real work —
  `flutter_staggered_animations` for the list entrances is the only one pre-approved. If you
  can do it with `TweenAnimationBuilder` and an index delay in ~20 lines, add nothing.
- **No Lottie, no Rive, no shaders** beyond the single blur. This app is offline and its APK is
  already 22MB; animation assets are not paying rent here.
- **No custom `RenderObject`s.**
- **Route transitions belong in the router** (`lib/app/router.dart`) as a shared
  `CustomTransitionPage`, defined once — not copy-pasted per route.
- Put every reusable animated widget in `lib/core/widgets/`, matching the existing file style:
  a doc comment that says *why*, not what.

## 7. Definition of done

Do not report success until all of these hold:

1. `flutter analyze` → **No issues found.**
2. `flutter test` → **all 103 tests pass.** Widget tests use `pumpAndSettle`; an animation that
   never settles will hang the suite. If a test needs updating, update it — do not delete it.
3. **Reduced motion**: with `MediaQuery(disableAnimations: true)`, every screen reaches its
   final state immediately and correctly. Add at least one widget test asserting this.
4. **Performance**: profile-mode run on a mid-range Android device or emulator, scrolling the
   dashboard and the progress screen, with no sustained frame drops. Report the raster times
   you actually observed — do not assert 60fps without measuring.
5. **RTL and LTR**: run in Arabic and English. No animation may slide the wrong way.
6. Regenerate the screen renders with
   `flutter test tool/render/ather_render_test.dart --update-goldens` and confirm nothing
   regressed visually.
7. Update `PROJECT.md`: the glass exception in §3, a motion section describing the tokens you
   added, and a work-log entry. The standing rule at the top of that file is not optional.

## 8. Sources to study before you start

Read these. The rules in §3 are taken from them, and your work will be reviewed against them.

**Motion craft**
- Emil Kowalski — *Animations on the Web* standards: durations by element, the ease-in ban, the
  frequency table, `cubic-bezier(0.23, 1, 0.32, 1)`.
  https://github.com/emilkowalski/skills/blob/main/skills/review-animations/STANDARDS.md
  and https://emilkowal.ski/ui
- Material 3 Expressive motion — spatial vs effect specs, and why effects must never overshoot.
  https://m3.material.io/blog/m3-expressive-motion-theming
- Flutter's own staggered-animation guidance.
  https://docs.flutter.dev/ui/animations/staggered-animations

**Glass**
- Flutter Liquid Glass / iOS 26 techniques and the `BackdropFilter` performance envelope.
  https://theflutterk.it.com/blog/flutter-liquid-glass-ios-26-cupertino-guide
- Flutter Gems, glassmorphic UI packages — read them for technique; **do not add one**.
  https://fluttergems.dev/glassmorphic-ui/

**Where practitioners publish — study real products, not dribbble shots**
- **Mobbin** (https://mobbin.com) — real shipped mobile flows, screen by screen. The most
  useful of these for an app like this one.
- **Screenlane** (https://screenlane.com) — real-world mobile screenshots by pattern.
- **Codrops** (https://tympanus.net/codrops/) — implementation detail behind effects.
- **Awwwards** (https://www.awwwards.com) and **Dribbble** (https://dribbble.com) — visual
  direction only. Treat these as mood, never as spec: most of what wins there is a video that
  was never built, at durations no real product would ship.
- **LottieFiles** (https://lottiefiles.com) — for reference only; you are not adding Lottie.

When these sources disagree with this brief, **this brief wins**. When this brief is silent,
the quieter option wins.

## 9. Report back with

- A table of every animation added: surface, trigger, duration, curve.
- Every new token added to `AppMotion`.
- The measured frame timings from §7.4, including the device.
- Anything in this brief you disagreed with, and what you did instead.
