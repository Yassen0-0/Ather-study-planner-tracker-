# Design

This file describes the **public site** (`public/`). The app's own design system lives in
PROJECT.md §3.10, §3.27 and §7a–7b and in `lib/core/theme/`; the site takes its tokens from
there and must move with them.

## World: the corrected answer sheet

The site is an exam answer booklet lying on the app's desk and graded in red pen. The metaphor
exists because the app's colour grammar already *is* marking: red means wrong or weak, green
means right, and the one blue means *active*. On the site that blue is the student's own
ballpoint: what they wrote, and the one thing to do (download).

## Tokens (from `lib/core/theme/app_colors.dart`)

| Role | Light | Dark | App token |
|---|---|---|---|
| Desk (page) | `#EFEFF2` | `#000000` | `pageBackground` |
| Sheet | `#FFFFFF` | `#1C1C1E` | `card` |
| Sheet underneath | `#F4F4F6` | `#2A2A2E` | `muted` / `fill` |
| Field | `#F1F1F4` | `#2A2A2E` | `fill` |
| Ink | `#000000` | `#FFFFFF` | `textPrimary` |
| Ink 2 | `#63636A` | `#A1A1A8` | `textSecondary` |
| Ballpoint (action, student's writing) | `#1B6EF3` | `#4D9BFF` | `accent` |
| On ballpoint | `#FFFFFF` | `#04203F` | `onAccent` |
| Red pen (marks, crosses, weak) | `#FF3B30` | `#FF3B30` | `wrong` |
| Red pen at text size | `#C93229` | `#FF6961` | `wrongText` (dark lifted for contrast on the sheet) |
| Tick (right, mastered) | `#34C759` | `#34C759` | `right` |
| Margin rule | red @ 35% | red @ 45% | (site only) |

Radii (`AppRadius`): sheet 22 · card/notes 16 · button 14 · score box 12 · pill 999.
Primary button 56px tall. Page gutter 20 (40 from 880px). Sheet max width 520.
Ruled margin 28px (32 from 880px) from the sheet's inline-start edge.
Spacing is one 4-based scale: 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96 · 128, with more space
above a heading than below it.

## Type

- **Readex Pro** (the app's face), variable 200–700, self-hosted woff2, Arabic + Latin subsets.
  Tabular figures everywhere, as in the app. Western digits in both languages.
- **Aref Ruqaa 700**, self-hosted, **only** for the teacher's red-pen marks: the score and the
  margin notes. Ruqaa is how Egyptian teachers actually write. Never for UI text, never in blue.
- Scale: display `clamp(40px, 10.5vw, 68px)` / 700 / −0.02em (English section 60px max);
  section heading `clamp(28px, 6.4vw, 44px)` / 700; lede 18–21; body 17 / 500 / 1.75; fine 14.

## Components

- **Sheet**: flat, white on the desk, radius 22, 1px red margin rule at inline-start, no shadow
  and no tilt (depth is value only, as in the app). The owner liked the sheets flat; the tilted
  stack and ruled paragraphs of the first pass were dropped with the rest of it.
- **Sheet head**: subject in bold over a secondary line, 1.5px ink rule underneath.
- **Score box**: 72px square, 1.5px ink border, Ruqaa grade in red over a red fraction line,
  circled by a drawn red pen stroke.
- **Rows**: 52px minimum, hairline rules. Marks (tick / cross) and question numbers sit in the
  margin. A wrong row is struck through in red. Scores read LTR ("0 / 4").
- **Checklist**: ticked study steps in the app's blue boxes; the unticked "recorded an exam"
  row carries the Ruqaa note.
- **30-day clock**: 30 cells per lesson, blue elapsed, all red when overdue.
- **Chapter report**: value plus 6px bar (blue neutral, red weak, green mastered, forced LTR
  like the app). The weak value is circled in red pen, with a Ruqaa note under it.
- **Numbered sheet** (privacy facts): numbers in the margin, bold line plus secondary line.
- **Button**: ballpoint blue, radius 14, 56px, 0.97 press scale.

## Layout

Headline and one sentence on the desk beside the graded exam sheet; then chapters of one text
column (max ~32em) beside one sheet, alternating sides, the sheet flush to the gutter. No app
screenshots anywhere (owner, 2026-09-25).

## Copy

Egyptian colloquial throughout, like a student talking to a student. No em dashes, no
"not X but Y" constructions beyond the pinned tagline. Say only what the app does: mastery
moves only with an exam (70% latest, 30% the ones before); after 30 days a lesson turns red
and its chapter with it; the number itself does not drop.

## Motion

One authored moment: the red pen marks each sheet once as it enters the viewport (stroke draw,
560ms, `cubic-bezier(.23,1,.32,1)`, staggered), and Ruqaa notes settle in. Content is visible
without JavaScript; `prefers-reduced-motion` shows every mark already drawn.

## Rules

- Red and green keep their app meaning. Never use red for emphasis or green for "selected".
- Blue is for the action and the student's own writing only.
- No gradients, no shadows, no glass, no tilt.
- Demonstration data (grades, chapters, dates) is labelled as an example on the page.
