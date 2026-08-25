# Phase 4 — Copy-Parity Final Check

Scope: post-l10n-commit audit range `053f079..HEAD` (branch `ai-audit/2026-08-25`,
HEAD = `390c6c5`). Read-only check; this file is the only artifact written.

## Verdict: PASS (all six checks; one informational note on C2)

---

## C1 — Key-set parity (`app_ar.arb` vs `app_en.arb`)

- Non-`@` keys: **ar 348, en 348**.
- Set difference: ar-only = ∅, en-only = ∅. Sets **identical**.

## C2 — Placeholder names/types per key

- Compared `@key.placeholders` (name → declared type) for all 348 shared keys.
- Raw metadata mismatches: **14 keys**, and every one is the same shape:
  **ar declares placeholders, en has no `@key` block at all** (not a type conflict).
  Affected: `examErrorSumMismatch`, `examPointsLine`, `insightChapterWeak`,
  `insightLessonNotReviewed`, `insightStrongestSubject`, `insightSubjectImproved`,
  `lessonsExaminedOf`, `masteryCaptionWithExams`, `notReadyBody`,
  `reviewNotificationBody`, `reviewNotificationEarlyBody`, `subjectTemplateAdded`,
  `trendUp`, `trendDown`.
- Why this is not a failure: `l10n.yaml` sets `template-arb-file: app_ar.arb`
  (Arabic-first project), so ICU signature types are taken from ar for **all**
  locales; gen-l10n succeeded and emitted matching signatures (see C3). Placeholder
  names used inside en values all match the ar declarations.
- Informational: adding empty `@key.placeholder` stubs to `app_en.arb` would make
  the files self-describing, but changes nothing functionally today.
- Effective mismatch count: **0**.

## C3 — Generated-file consistency

- Fresh `flutter gen-l10n` in a scratch project (/tmp/opencode/gencheck, Flutter
  3.47.1, same l10n.yaml options, `flutter: generate: true`; pubspec untouched).
- Signature comparison of committed generated files: parameterized methods
  **ar 46 / en 46 / abstract 46; diffs = 0**; full method-name sets equal across
  all three files.
- Regen diff vs committed `generated/*`: byte-identical after normalizing only two
  scratch-setup artifacts (doc-comment import path `out/` vs `generated/`, and a
  leading blank line). Committed generated code is current with both ARBs.

## C4 — Digit policy (PROJECT.md §3.16: Western digits in BOTH locales)

- en values containing Arabic-Indic (U+0660–69) or Persian (U+06F0–79) digits: **0**.
- ar values containing Arabic-Indic/Persian digits anywhere (§3.16 violation): **0**.
- ar auth/error keys carrying digits (`authErrorPasswordShort`, `passwordTooShort`):
  Western `8` / `4`, mirrored exactly in en (`8` / `4`). Compliant.

## C5 — RTL safety sample (8 strings changed by the audit)

No bidi isolate/embed controls (LRM/RLM/LRE…PDI) exist anywhere in either ARB.
Every bare-digit occurrence below sits between strong directional runs or matches
the dashboard `lessonCount(int)` precedent (digit-leading branch followed by strong
Arabic, rendered inside the locale-forced RTL paragraph). Flags: **0**.

| String | Render site | Analysis |
|---|---|---|
| `comebackLine` | dashboard_screen.dart:172 | `{days}`/`{count}` always flanked by strong Arabic (`بعد … أيام/يوماً/يوم`, `دروس عبرت معادتها`); `—` has strong Arabic on both sides |
| `overdueByDays` | chapter_screen.dart:539, dashboard:755, lesson_screen:194, review_center:341, exam_eve_sheet:103 | digits embedded `متأخّر {days} أيام/يوماً/يوم`; =0/=1/=2 branches digit-free |
| `dueInDays` | lesson_screen.dart:196, exam_eve_sheet:104 | same shape `بقي {days} أيام`; digits strictly interior |
| `purgeCountsLine` | recycle_bin_screen.dart:95,242 | few/many/other branches may start a segment with a digit, but every segment ends in a strong Arabic word; each `·` neutral is adjacent to strong-R and resolves to R in the forced-RTL paragraph — same rendering path as `lessonCount` chips |
| `restoreCopyCounts` | backup_screen.dart:88 | anchored by strong prefix `النسخة السحابية:`; colon is neutral-before-strong/digit → resolves R |
| `examGroupLabel` | exam_entry_screen.dart:608 | `×` always adjacent to strong Arabic on at least one side; no plural branch ends with a digit |
| `analyticsVelocity` | analytics_screen.dart:850 | digit-leading branch followed by strong `نقاط`, trailing strong phrase `لكل دورة مراجعة` anchors RTL — lessonCount precedent shape |
| `chaptersMasteredOf` (my pick) | dashboard_screen.dart:392 | `أتقنت {mastered} من {total…}` — digits between strong runs on both sides |

## C6 — No new user-visible hardcoded literals escaped l10n

Range `git diff 053f079..HEAD -- lib/`: 34 files, +1653/−452. Added lines outside
`lib/core/l10n/`: 1055 scanned.

- Lines containing Arabic script: 6 — **all comments** (NumberField doc-comments,
  a tatweel inline comment). None user-visible.
- Quoted English UI-ish literals: none. Only multi-word quoted string added is a
  `debugPrint('Ather: holding empty upload -- no cloud copy has reached this device yet')`
  log line (excluded class per contract).
- No raw `Text('…')`, SnackBar/Tooltip/dialog literals added. Hits list: **empty**.

---

### Summary table

| # | Check | Result | Count |
|---|---|---|---|
| 1 | Key sets identical | PASS | 348 = 348, Δ 0 |
| 2 | Placeholders name/type parity | PASS* | 14 metadata gaps (en-side, template=ar); effective 0 |
| 3 | Generated consistent + fresh regen | PASS | 46 sigs × 3 files, 0 diffs; regen byte-equal modulo scratch path |
| 4 | §3.16 digit policy | PASS | 0 stray either direction |
| 5 | RTL sample (8 strings) | PASS | 0 bidi hazards |
| 6 | Hardcoded literal escape | PASS | 0 hits |

\* informational only — see C2 note if en-side `@` stubs are ever wanted.
