# Ather — Design-System Polish Report

**Scope:** the consolidation items in `ATHER_DESIGN_AUDIT.md` (P0 1–3, P1 4–7, P2 8–13, iconography).
**Branch:** `claude/ather-design-system-polish-72025b`.
**Base:** `155d34e`, build 1.3.1+8.
**Result:** 32 files changed under `lib/`, +584 / −516. No screen redesigned, no feature touched, no
colour re-picked, no font changed. `flutter analyze` clean, 220 tests pass, release invariants hold.

Before starting: `git worktree list` and a `git status --short -- lib` across all four worktrees —
all clean, so this worktree is the newest design (Rule 2).

---

## 1. Spacing system (P0-1)

**Changed.** `lib/core/theme/app_spacing.dart`, and ~130 call sites across 30 files.

The ladder was `4 · 8 · 10 · 12 · 14 · 16 · 18 · 22 · 24`. It is now `4 · 8 · 12 · 16 · 20 · 24`.

| Token | Was | Now | Call sites moved |
|---|---|---|---|
| `xxs` | 4 | 4 | — |
| `xs` | 8 | 8 | — |
| `sm` | 10 | **deleted** | 34 → `md` |
| `md` | 12 | 12 | — |
| `lg` | 14 | **deleted** | 44 → `xl` |
| `xl` | 16 | 16 | — |
| `xxl` | 18 | **20** | 8, in place |
| `section` | 22 | **deleted** | 4 → `xxxl` |
| `xxxl` | 24 | 24 | — |
| `cardPaddingLarge` | 18 | **deleted** | 23 → `cardPadding` (16) |
| `listGap` | 10 | **12** | 7, in place |

**Why this shape of change.** The four removed rungs were the audit's core complaint: a scale that
claims "anything off this ladder means the layout is wrong" cannot also contain a 4-grid *and* a
4+2 grid, because then the rule only ever applies to half of it — and a half-rule is what let raw
9s, 11s, 13s and 15s accumulate at call sites unchallenged.

**Why the surviving names were not renamed.** A full rename to a gapless `xxs…xxxl` ladder would
silently redefine `md`, `lg`, `xl` and `xxl` at ~200 call sites with no compiler error anywhere —
exactly the "blindly replace every value" failure mode the brief warns against. Deleting the
off-grid rungs instead makes every affected site a compile error, so all 130 were inspected
individually. The cost is a gap in the alphabet (`sm` and `lg` are missing); that gap is documented
in the class comment as the record of the cleanup. **Maximum movement at any single call site is
2dp**, and the ladder is monotonic.

**Two deliberate sub-grid values, now named instead of retyped:**

- `AppSpacing.opticalInset = 2` — the `SectionTitle` inset that lines a heading up with the card
  *content* beside it rather than the card edge, plus the two 2dp header nudges. Was raw at 4 sites.
- `AppSpacing.textGap = 6` — the optical gap between a heading and the sentence it introduces, and
  the vertical padding inside a pill. Was raw at **17** sites. `xxs` (4) closes it until the two
  lines read as one block; `xs` (8) opens it until the sentence stops belonging to the heading. Both
  line-heights either side already contribute 3–4 of their own, which is why the number on the grid
  is not the number the eye measures.

**Raw micro-values eliminated:** `2`, `3`, `4`, `5`, `9`, `11`, `13`, `15`, `20`, `28` are gone from
call sites. Row-title→status gaps (raw 2 and 3, 13 sites) unified on `xxs` (4). Row tap paddings
(raw 11 and 13, 4 sites) unified on `md` (12).

**Visual behaviour intentionally preserved:** yes, within 2dp everywhere. The one place where the
arithmetic was checked rather than eyeballed is the dashboard's three-up stat row on a 320dp phone:
card padding fell 18→16 on each side (+4 content) while the two gaps rose 14→16 (−4), so the width
per stat is **74.7dp before and after — identical**.

**Not changed, deliberately:** the two raw `3`s inside `WeekStrip`. They are not layout gaps; they
are terms in the strip's own fixed-height stack, which `AppSizes.weekStrip` already documents as
`4 dot + 3 + 21 letter + 6 + circle`. Moving them would require re-deriving that constant for no
visual gain. Also left: the switch knob's `horizontal: 2.5` margin, which is `(30 − 25) / 2` — the
control's own geometry, not spacing.

---

## 2. Colour tokens (P0-2)

**Changed.** `lib/core/theme/app_colors.dart`, `status_chip.dart`, `ather_card.dart`,
`chapter_screen.dart`, `app_shell.dart`.

### `wrongTint` / `wrongChip` — consolidated

They were 10% and 12% red in light, 15% and 18% in dark, and they appeared on the same screen — the
error banner and the overdue chip both live on `LessonScreen`. Two reds two percent apart is not a
semantic distinction; it is a decision nobody made twice on purpose. **`wrongChip` is deleted**, the
status chip now uses `wrongTint`. One wash, one name. The single-accent + two-state philosophy is
untouched.

### `divider` / `dividerStrong` — distinguished, not merged

These turned out to have genuinely different roles, so the distinction was made explicit rather than
removed:

- `divider` (6% / 8%) — the hairline inside a card, and now also the sheet-row separator on
  `ChapterScreen`, which had been reaching for the heavier token for no stated reason.
- **`dividerStrong` → renamed `glassBorder`** (7% / 10%) — with exactly one user left: the tab bar's
  own edge. That line is drawn on a translucent surface with a 24-sigma blur behind it, over
  whatever the student is scrolling. A 6% hairline that reads cleanly inside a white card disappears
  there. The extra weight belongs to the blur, not to a "strength" ladder — and the old name implied
  a ladder that did not exist.

`CardDivider`'s `strong` flag is removed: **no call site ever passed it.** A variant nobody chooses
is a variant nobody designed.

**Palette values changed: none.** Only which token a surface asks for, and what two of them are
called.

---

## 3. Dashboard `_Stat` row (P0-3)

**Changed.** `dashboard_screen.dart`, `app_typography.dart`.

`14 / 19 / 13 / 5 / 9` at the call site became:

| Was | Now |
|---|---|
| `size: 14, weight: semiBold` | `AppTypography.statLabel` (14/600/1.3) |
| `size: 19, weight: bold` | `AppTypography.statValue` — defined as `=> rowNumber`, because a stat *is* a number answering a label, which is what a row's trailing figure is, and the two sit on the same screen |
| `size: 13, weight: semiBold, textSecondary` | `AppTextStyles.statDenominator` (13/600/1.2) |
| `SizedBox(height: 5)` | `AppSpacing.xxs` (4) |
| `SizedBox(height: 9)` | `AppSpacing.xs` (8) |

**No `statGap` token was created**, though the brief offered it as an example. Both gaps landed
exactly on ladder rungs, and a bespoke name for 4 would be a fourth alias for a value that already
has one. The ladder *is* the token here.

**Visual behaviour preserved:** the three type sizes are unchanged; the two gaps each tightened by
1dp. Row height falls by 2dp in a card whose padding also fell by 4dp.

---

## 4. Bottom sheet padding (P1-4)

**Changed.** `ather_sheet.dart`.

`EdgeInsets.fromLTRB(20, 20, 20, 28)` → `fromLTRB(pageMargin, pageMargin, pageMargin, xxxl)`
= `16 / 16 / 16 / 24`. The app's one modal was the only surface in it that did not reach the page
margin; its content now lands on the same verticals as the screen behind it. The bottom stays a rung
larger than the sides because it clears the gesture bar, which the sides have nothing to clear.

Also tokenised here: the grab handle's `36 × 5` and its radius `3`, now `AppSizes.sheetHandleWidth`
/ `sheetHandleHeight` with the radius **derived** as `height / 2` rather than typed as a separate
number, and the title→body gap `6` → `AppSpacing.textGap`.

**Preserved:** the sheet's proportions and the 22 top radius are unchanged; the sides tighten by 4
and the bottom by 4.

---

## 5. Header padding unified (P1-5)

**Changed.** `ather_scaffold.dart` (`AtherHeader`), `day_header.dart` (`DayHeader`).

`AtherHeader` was `lg` (14) horizontally, `DayHeader` was `xxl` (18). Both are now
`AppSpacing.pageMargin` (16). Neither header is otherwise touched.

This is the change that matters most on a small phone, and it is not only about the two headers
agreeing with each other: 16 is also what the *body list* is inset by, so an inner screen's title
had been starting 2dp inside its own content and a day screen's title 2dp outside it. All three now
share one vertical. Measured effect on the tasks screen's 320dp overflow: **−4dp** (see §12).

The two raw `2` and `4` top nudges became `opticalInset` and `xxs`.

---

## 6. Typography scale (P1-6, P2-8, P2-9, P2-10, P2-11)

**Changed.** `app_typography.dart` and **60 call sites** across 22 files.

### Raw sizes at call sites: 60 → 0

`grep "AppTypography.style(" lib` outside `app_typography.dart` now returns nothing. Every size in
the app is a named role.

### Distinct sizes app-wide: 26 → 21

Gone: **11.5, 12.5, 13.5, 14.5, 15.5** (the half-steps below 16) and the raw **12**. Below 20 the
ramp is now integers only, one named role per rung.

| Token | Was | Now | Note |
|---|---|---|---|
| `micro` | 11.5 | 11 | |
| `small`, `smallStrong` | 12.5 | 12 | |
| `status`, `chipLabel` | 13.5 | 13 | joins the sublabel tier |
| `pillLabel` | 14.5 | 14 | |
| task row / checkbox label | 15.5 | 15 | **P2-8** — the outlier is gone; it is now `itemLabel`, at `body`'s size with a tighter leading |
| analytics chart label | 11 raw | 11 (`chartLabel`) | **P2-9** |
| analytics bar value | 12 raw | 12 (`chartValue`) | **P2-9** |
| analytics chapter percent | 13 raw | 12 (`chartValue`) | **P2-9** — one chart-label size, not three |
| settings sublabels | 13 raw ×4 | `sublabel` | **P2-10** |
| lesson homework card title | 15 raw | `cardTitle` (16) | demotion now carried by colour, not by a 1px size nobody can see |

### Tokens added

Uncoloured, in `AppTypography`: `rowStatus`, `statusLine`, `listTitle`, `rowNumberCompact`,
`itemLabel`, `emptyTitle`, `controlLabel`, `statLabel`, `statValue`, `chartValue`, `badgeLabel`,
`badgeCount`.
Coloured, in `AppTextStyles`: `sublabel`, `fieldLabel`, `statDenominator`, `chartLabel`,
`toastMessage`.

These are *names for sizes that already existed at call sites*, not new sizes. The count of tokens
went up; the count of values went down, which is the trade the audit asked for.

### Line heights (P2-11)

- `1.55` on the lesson mastery caption → the caption now uses `sublabel` at **1.5**.
- `1.6` on the dashboard first-run body, the settings About body and the login subtitle → all three
  dropped their `copyWith(height: 1.6)`; `AppTextStyles.secondary` / `secondaryStrong` moved from
  **1.45 → 1.5**, so those call sites need no override at all.
- `sublabel` sits at 1.5 for the same reason.

Arabic wrapping was checked at 320dp in both scripts (§10). 1.5 is the leading `body` has always
used, and Readex Pro's Arabic and Latin share a character height, so the two scripts wrap at the
same rhythm.

### Deliberately **not** collapsed

**`rowTitle`/`rowNumber` (17/19) and `rowTitleSmall`/`rowNumberSmall` (16.5/18).** Audit item 6 asks
to unify the three percentage sizes. Rejected after inspection: these are not three sizes for one
role, they are **two row densities each with a paired title and number**. A subject row is 17/19; a
lesson row is 16.5/18. Collapsing the numbers while leaving the titles would break the pairing that
makes the two densities read as a system. What *was* done instead is name the third size honestly:
the in-card rows (exam history, weakest lessons, the not-ready sheet) that used a raw 16 now use
`rowNumberCompact`, paired with `listTitle` at 15.

`rowTitleSmall` therefore keeps its 16.5 — the app's one remaining half-step. Collapsing it to 16
would give **three** names to one size (`cardTitle`, `cardLabel`, `rowTitleSmall`), which is worse
than one half-step. Noted in the class comment.

**`cardTitle` (16/700) vs `cardLabel` (16/600).** Audit §7.7 flags the same size at two weights.
Merging them changes a weight on the dashboard's dominant card, which is a hierarchy decision, not a
consolidation. Left alone; flagged in §13.

**`tabLabel` at 11.** One token, one call site, one job — not part of the raw-value problem. Left at
11 rather than nudged to match `micro`, because the tab bar's contrast is a tested invariant and
there was no reason to touch it.

---

## 7. Status chip, mini badge, filter chip, error banner (P1-7)

**Changed.** `status_chip.dart`, `error_banner.dart`.

| Component | Was | Now |
|---|---|---|
| `StatusChip` | `12 × 6` | `md × textGap` — same 12 × 6, with the 6 now named and its reason written down |
| `MiniBadge` | `9 × 4` | `xs × xxs` = `8 × 4` |
| `AtherFilterChip` | `15 × 9` | `xl × xs` = `16 × 8` |
| `ErrorBanner` | `15 × 13` | `xl × md` = `16 × 12` |

Every value is on the ladder except the status chip's 6, which is `textGap` and documented at the
call site: the label's line box already carries its own leading, so 8 draws a chip half again as
tall as it reads and 4 crops it onto the pill's curve.

**Visual size and hierarchy preserved:** no chip moves by more than 1dp on either axis.

`ErrorBanner`'s `height` parameter now defaults to the status line's 1.4 rather than the font's own
leading; the two callers that pass 1.5 are unchanged. Documented on the parameter.

---

## 8. Dashboard baseline alignment (P2-12)

**Changed.** `dashboard_screen.dart` (`_OverallCard`), `chapter_screen.dart`
(`_ChapterSummaryCard`), `mastery_bar.dart`.

`CrossAxisAlignment.end` → `CrossAxisAlignment.baseline` with `TextBaseline.alphabetic`.

Bottom alignment lines up the sentence's *last* line with the number. When "١ من ٤ باب اتقنتها"
wraps to two lines — narrow screen, or a large text scale — that lifts "١ من ٤ باب" clear above the
number's cap height and strands "اتقنتها" beside it, which is the awkwardness the audit describes.
On one baseline the sentence starts level with the figure and runs on underneath it, which is the
order it is read in.

In the one-line case the two alignments differ by ~1.7dp, so the common rendering is effectively
unchanged. `MasteryNumber` already exposes a baseline (it is a `Row` with `CrossAxisAlignment.baseline`
inside), so nothing needed restructuring.

**Applied to the chapter screen too.** It is the same component shape with the same wrap, one screen
over; fixing one and not the other would have re-created the inconsistency being removed.

---

## 9. Dead and redundant tokens (P2-13)

**Changed.** `app_spacing.dart`, `ather_controls.dart`.

- **`AppRadius.inner` (10) — deleted.** Zero references, confirmed by grep.
- **`AppRadius.headerButton` (18) — deleted.** Zero references. `CircleHeaderButton` already draws
  with `BoxShape.circle`, which is exactly why the token was dead. Nothing needed changing to
  "switch to the circular shape" — the app was already there.
- **`AppRadius.segment` (8) — added.** The segmented control's selected segment was a raw `9`. The
  concentric rule the class comment states gives `input (12) − padding (4) = 8`; the raw 9 was that
  rule missed by one. So the dead token was removed *and* the place that actually needed an inner
  radius now has a named, rule-derived one.

---

## 10. Iconography — eye / eyeOff

**Changed.** `ather_icons.dart`, `login_screen.dart`.

Two new glyphs in the existing family: authored in the same 24 grid, `strokeWidth 1.9`, round caps
and joins, no fill.

- `eye` — a lens built from two mirrored lid cubics meeting at a point on each side, plus a pupil at
  `r = 3.1`. The points are where the round join does the work; closed with a corner the same path
  reads as a leaf.
- `eyeOff` — the same lens with the pupil **dropped** and a slash across it. Dropped rather than
  crossed because a 1.9 stroke through a 3.1 circle meets itself at the centre and fills in as a
  blot at the 18px this is actually drawn at.

The login screen's `'•••'` / `'———'` text workaround is gone. The glyph shows what tapping will
*do*, not what the field is currently doing. The existing `semanticLabel` (`authShowPassword` /
`authHidePassword`) and the 48dp `minTarget` are untouched.

One wrinkle worth knowing: `AtherGlyph` is both the brand-mark **widget** in `ather_logo.dart` and
the icon **enum** in `ather_icons.dart`, and the login screen uses both. The icons import is
therefore prefixed (`as icons`) with a comment saying why.

**No other icon changed.**

---

## 11. Explicitly not done

| Item | Why |
|---|---|
| **Glass tab bar** | Kept, per the brief. No device evidence of a performance or readability problem was gathered, so there was no basis to remove it. The contrast invariant still passes. |
| **Motion system** | Untouched. No audit finding in scope required it. |
| **`right`/`wrong`/`accent` palette values** | Untouched. |
| **Readex Pro, weights, `fontVariations`, tabular figures** | Untouched. |
| **Row density pairs (17/19, 16.5/18)** | See §6 — a system, not a duplication. |
| **`cardTitle` vs `cardLabel`** | See §6 — merging is a hierarchy change, not a consolidation. |
| **`AppSizes.primaryButton = 52`** (audit §6.5) | Not in the brief. A button height is a hierarchy decision. |
| **Wizard 2:1 bottom bar ratio** (audit §6.6) | Not in the brief. |
| **Header 36-drawn / 48-hit gap** (audit §6.7, §9.3) | Not in the brief; the gap is documented behaviour in `pressable.dart`. |
| **Check-disc shadow to match the switch knob** (audit §11.4) | Adding a shadow is exactly what the brief forbids. |
| **`WeekStrip` internal 3s** | Terms in a documented fixed-height stack, not layout gaps. |
| **Tasks-screen week strip overflow** | Found during verification; the fix is a product decision. See §12. |

---

## 12. One defect found during verification, and left for you

**The tasks screen's week strip does not fit a phone narrower than ~368dp.** This is **pre-existing**
and unrelated to the spacing work, which in fact improved it by 4dp.

The strip is a *summary* on the dashboard and a *picker* on the tasks screen. As a picker each of
its seven day cells is a `Pressable` carrying `minTarget: kMinTarget` — the 48dp floor the whole app
honours — so the row demands `7 × 48 = 336` regardless of window width. With the page margin either
side it fits only from `336 + 32 = 368` up:

| Width | Overflow before this work | Overflow after |
|---|---|---|
| 320dp (iPhone SE 1 class) | 52dp | **48dp** |
| 360dp (commonest Android width) | 12dp | **8dp** |
| 400dp+ | none | none |

The dashboard's copy escapes because an inert cell gets no `Pressable`, and therefore no floor.

**It was not fixed here**, because the two available fixes each give up something the app has
already committed to in writing: distribute the cells with `Expanded` and let the touch target fall
to 41dp on a 320 screen (below the app's own stated 48dp rule, though still well above WCAG 2.2's
24dp minimum), or let the strip scroll and give up "the whole week at a glance". Seven 48dp targets
cannot be laid in 288dp — no arrangement exists — so the choice is the product's, not a refactor's.
**My recommendation is `Expanded`:** a clipped seventh day is worse for every user than a 41dp
target is for any user, and it only degrades below 368dp.

It is recorded as arithmetic in `test/widget/layout_matrix_test.dart`, with a note telling whoever
fixes it to put the tasks tab back into the width matrix unconditionally.

---

## 13. Tests, build, and what was verified

**Added:** `test/widget/layout_matrix_test.dart` — 9 tests. The ladder rebuild is a 2dp change
repeated 130 times, and 2dp repeated 130 times is not a 2dp change; it is every row, gap and card
padding moving at once. The failure mode is not ugliness, which a person notices, but a
`RenderFlex overflowed` on the one width nobody opened. So the check is mechanical and it is a
matrix:

- **Widths** 320 / 360 / 600 (the breakpoint itself) / 840, walking the dashboard, review, progress
  and settings screens. 320 is new — the suite previously stopped at 360.
- **Scripts × themes**: ar/en × light/dark at 320dp, asserting the direction actually took effect.
- The tasks-screen defect in §12, recorded as arithmetic.

`bootApp` in `test/widget_test.dart` gained an optional `locale`, seeded through the same
preferences key the settings toggle writes.

**Results:**

| Check | Result |
|---|---|
| `dart analyze lib test` | **No issues found** |
| `flutter test` | **220 passed** (211 before, +9 new) |
| `bash tool/check_invariants.sh` | **All invariants hold** |
| `test/design_invariants_test.dart` | passes — accent hue/saturation, tab-bar contrast ≥ 3:1 over all nine underlying fills in both themes, no `plus` glyph, icon-motion layer present |
| Arabic RTL | covered at 320dp, both themes |
| Light / dark | covered at 320dp, both scripts |
| Small phone (320, 360) | covered; one known defect, §12 |
| Tablet / wide (600, 840) | covered |

**No APK was built and `versionCode` was not bumped** — nothing here leaves the machine, so Rule 1's
four checks were run (`check_invariants.sh`) but no signing was attempted. Bump `+N` in
`pubspec.yaml` before handing anyone a build.

`dart format` was run only over the files this work touched; four unrelated test files and two
unrelated `lib` files that the local formatter version wanted to reflow were reverted, as were the
`windows/` plugin-registrant files that `flutter pub get` regenerated.

---

## 14. Remaining recommendations

1. **Decide the week-strip fix (§12).** This is the only item here that a student will actually see,
   and it affects the commonest Android width there is.
2. **Commit this branch** — Rule 3. It stands on its own.
3. Consider `cardLabel` (audit §7.7): two 16pt weights on one screen is a real observation, but the
   fix is a hierarchy decision someone should make deliberately rather than fold into a cleanup.
4. Consider the `today` (−0.5) vs `lockWordmark` (−0.6) letter-spacing inconsistency (audit §4.4).
   Too small to see; still a sign of two authorial heads.
5. `AppSizes.toastBottom`'s comment still cites the tab bar's old 0.72 tint; the value is now 0.85.
   Prose drift, not a behaviour bug.

---

## 15. Files changed

**Tokens (4):** `app_spacing.dart`, `app_typography.dart`, `app_colors.dart`, `app_theme.dart`.

**Core widgets (14):** `ather_card.dart`, `ather_controls.dart`, `ather_icons.dart`,
`ather_scaffold.dart`, `ather_sheet.dart`, `ather_toast.dart`, `buttons.dart`,
`celebration_overlay.dart`, `day_header.dart`, `empty_state.dart`, `error_banner.dart`,
`mastery_bar.dart`, `status_chip.dart`, `week_strip.dart`.

**Screens (14):** `analytics_screen.dart`, `lock_screen.dart`, `login_screen.dart`,
`chapter_screen.dart`, `chapter_report_screen.dart`, `prompts.dart`, `dashboard_screen.dart`,
`exam_entry_screen.dart`, `lesson_screen.dart`, `review_center_screen.dart`, `settings_screen.dart`,
`app_shell.dart`, `subject_screen.dart`, `tasks/widgets/task_row.dart`.

**Tests (2):** `test/widget_test.dart` (locale parameter), `test/widget/layout_matrix_test.dart`
(new).

---

*Same Ather. The spacing is one ladder, the type scale has no invented sizes, two near-identical
colour tokens became one and one became honestly named, and the password toggle is drawn rather
than typed.*
