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
| Margin rule | red @ 38% | red @ 45% | — |

Radii (`AppRadius`): sheet 22 · card/boxes 16 · button 14 · score box 12 · pill 999.
Primary button height 52 (`AppSizes.primaryButton`). Page gutter 16.
Answer-line ruling 34px. Ruled margin at 30px from the inline-start edge.

## Type

- **Readex Pro** (the app's face), variable 200–700, self-hosted woff2, Arabic + Latin subsets.
  Tabular figures everywhere, as in the app. Western digits in both languages.
- **Aref Ruqaa 700**, self-hosted, **only** for the teacher's red-pen marks: the score and the
  margin notes. Ruqaa is how Egyptian teachers actually write. Never for UI text, never in blue.
- Scale: answer headline `clamp(38px, 11vw, 76px)` / 700 / −0.02em; sheet question
  `clamp(26px, 6.6vw, 40px)` / 700; body 16–17 / 500; small 13.

## Components

- **Sheet**: white on the desk, radius 22, 1px red margin rule at inline-start, no shadow (depth
  is value only, as in the app). The hero sheet sits on a second sheet rotated +2.2°, itself −1°.
- **Header fields**: `الاسم` / `المادة` on dashed rules, filled in ballpoint blue.
- **Score box**: 78px square, 1.5px ink border, Ruqaa grade in red over a red fraction line,
  circled by a drawn red pen stroke.
- **Answer rows**: numbered `س1…`, 46px, hairline rules, mark (tick / cross) drawn in the margin.
- **Report rows**: chapter, sub-line, value, 6px bar (blue neutral, red weak, green mastered,
  forced LTR like the app). The weakest row is circled in red pen.
- **30-day clock**: 30 cells per lesson, blue elapsed, all red when overdue.
- **Instructions box** («تعليمات هامة»): 1.5px ink border, radius 16, underlined title, numbered.
- **Button**: ballpoint blue, radius 14, 52px, 0.97 press scale.

## Motion

One authored moment: the red pen marks each sheet once as it enters the viewport (stroke draw,
520ms, `cubic-bezier(.23,1,.32,1)`, staggered), and Ruqaa notes settle in. Content is visible
without JavaScript; `prefers-reduced-motion` shows every mark already drawn.

## Rules

- Red and green keep their app meaning. Never use red for emphasis or green for "selected".
- Blue is for the action and the student's own writing only.
- No gradients except the answer-line ruling (a paper texture), no shadows, no glass.
- Demonstration data (grades, chapters, dates) is labelled as an example on the page.
