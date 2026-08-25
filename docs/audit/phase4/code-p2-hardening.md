# Phase 4 — Code review: WS10 P2 hardening (N16, N17, N22)

Reviewer: Phase 4 code-reviewer (independent; not the implementer).
Range: `171c7e6` (N16 NumberField reject), `bc5c2f6` (N17 invisible-char name
validator), `95aaed3` (N22 badge red-reserved-for-overdue). Interloper
`fa92b50` examined for interaction risk only. Branch `ai-audit/2026-08-25`.
Plan context: `docs/audit/verified-plan.md` WS10.

Method: full diffs re-read against current tree; every factual claim in the
commit messages independently re-verified at file:line; all three suites run
`--no-pub`; `flutter analyze` on the six touched files.

## Verdicts

| Commit | Finding | Verdict |
|---|---|---|
| `171c7e6` | N16 reject separator edits | **APPROVE-WITH-NITS** |
| `bc5c2f6` | N17 invisible-char name gate | **APPROVE-WITH-NITS** |
| `95aaed3` | N22 badge red-reserved-for-overdue | **APPROVE-WITH-NITS** |

No P0. One P1 (`app_shell.dart:548`, dark-mode badge text token) — one-line
fix required before the next release build; does not warrant a fresh
implementer cycle since count semantics and the light theme are correct.

## N16 — `171c7e6` APPROVE-WITH-NITS

**Integer-domain claim re-verified independently — it holds.**
`HomeworkEntries.score/maxScore` are `integer()` (`tables.dart:107-108`);
`ExamEntries.totalPossiblePoints` is `integer()` (`tables.dart:122`; the
`percentage` RealColumn is denormalised compute output, never typed input).
All consumers parse with `int.tryParse` (`exam_entry_screen.dart:70-72`,
`:213`, `:215`; `lesson_screen.dart:473-474`) and null falls back to 0 — so
normalising `2.5` would have written nothing usable anyway. REJECT-not-strip
is therefore the right call; there is no fractional sink to normalise into.
NumberField consumers are only exam/homework score fields
(`exam_entry_screen.dart:539,615,1073`, `lesson_screen.dart:560`) — no decimal
legit use anywhere.

**Legit editing flows checked — safe by construction.** The field can only
ever contain ASCII digits (translation runs first, rejection keeps old value),
so "backspace over separator" and "mid-string decimal deletion" cannot arise:
there is no separator in the buffer to delete. Deletion → empty text passes
(`ather_controls.dart:493-495`). Selection-replace with junk returns oldValue,
which also restores the old selection — the pre-edit text survives intact.
Partial selection-replace is logically covered (formatter inspects text only,
selection-independent) though not directly widget-tested.

**Test matrix:** paste-decimal-keeps-old (`number_field_test.dart:66-75`),
Arabic separator (`:77-85`), multi/trailing separators (`:87-98`),
refuse-then-digits-land (`:100-109`), translation pinned (`:25-52`), length
limit after translation (`:111-121`). Would catch a revert of either half
(reject *or* translate). Gaps below.

- **P2** — paste-with-trailing-newline now silently does nothing. Copying a
  score out of a spreadsheet yields `"25\n"`; `_RejectNonDigits`
  (`ather_controls.dart:494-496`) rejects the whole edit on `\n` where the old
  stripping code landed a correct 25. No error copy exists for this field, so
  the student sees dead keys. Suggested fix: trim leading/trailing whitespace
  from `newValue.text` before validating; reject only if inner non-digits
  remain.
- **P3** — IME composing regions untested and untestable via
  `tester.enterText`; a whole-edit refusal cancels composition mid-stream.
  Residual device-only risk for digits-only keyboards; acceptable, but record
  it.
- **P3** — no backspace/deletion widget test (safe by construction, but the
  suite wouldn't notice if that clause regressed).
- **P3** — doc glyph labels swapped at `ather_controls.dart:471`: "Western ٫
  or Arabic ٬" — U+066B ٫ is the *Arabic* decimal separator, U+066C ٬ the
  Arabic thousands separator; Western decimal is `.`. Comment-only.
- Pre-existing, unchanged: `LengthLimitingTextInputFormatter` still truncates
  long pastes silently (`ather_controls.dart:409`). Out of scope.

## N17 — `bc5c2f6` APPROVE-WITH-NITS

**Strip-before-trim is genuinely enforced by a test.** `\u200B \u200F \u0640 `
(`prompts_test.dart:91-99`) distinguishes the orders: strip→trim yields empty
(rejected), whereas trim-first-then-strip-without-retrim leaves an interior
space and would pass. Gate used consistently in initial state, onChanged, and
_submit (`prompts.dart:113,132,164`). Error path reuses `nameRequired` — no
new copy, as claimed.

**Single funnel verified.** Every name in the app goes through
`showNamePrompt` (subjects ×3 `settings/subjects_screen.dart:100,266`,
chapters `chapter_screen.dart:65,91`, lessons `dashboard_screen.dart:590`,
`subject_screen.dart:38`, tasks `tasks_screen.dart:45,75`, profile
`profile_screen.dart:158`) — one gate covers all. Saved-as-typed is intended
and consistent with `DriftStudyRepository` matching, which folds tatweel/
diacritics/hamza only for duplicate *keys* and never normalises stored names
(`drift_study_repository.dart`, `n()`); `fa92b50`'s maxLength mechanism
untouched (`prompts.dart:33,169`). Legit-name tests pass and assert exact
round-trip including surrounding invisibles (`prompts_test.dart:104-119`).

- **P2** — the set is *not* all of category Cf, though the doc comment
  (`prompts.dart:89`) and commit message claim it. Verified missing Cf blocks:
  U+0600–U+0605, U+06DD (Arabic number signs / end-of-ayah), U+070F, U+0890–
  U+0891, U+08E2, U+110BD/U+110CD, U+1D173–1D17A, U+13430–1345F, U+E0001,
  U+E0020–E007F. A "name" of only U+0600 still passes the gate — and these
  are the Arabic-script members, this app's own script. Fix: add the ranges
  or soften the comment to an enumeration ("the common format characters").
- **P3** — consistency gap with the dedup key: `n()` strips tatweel and
  diacritics but not ZWSP/Cf, so `الدرس` and `\u200Bالدرس` produce different
  match keys and can coexist as visually identical rows. The gate and the key
  disagree about what counts as invisible. Not introduced as a regression
  (pre-existing on the key side), but worth one follow-up ticket.

## N22 — `95aaed3` APPROVE-WITH-NITS

**Accent tier choice justified — verified against the palette contract.**
`app_colors.dart:5-6`: white/grey/black plus exactly one brand blue, one red,
one green. There is no amber/warn tier to reach for, and grey is taken by
disabled/secondary semantics — accent is the correct remaining tier, matching
how Review Center already greys declining rows while reserving red
(`review_center_screen.dart:374-379`). Tab and contents now agree.

**Count semantics unchanged.** Badge count remains `queue.length`; colour is
orthogonal (`app_shell.dart:61-67,99-101`). Pop animation still keyed on the
count (`app_shell.dart:523`).

**Select-record refactor safe.** `reviewQueueProvider` is still
`Provider<List<ReviewItem>>` (`app_providers.dart:219-224`) — its shape never
changed, so no other consumer could break. `rg` confirms consumers: Review
Center watches the full list (`review_center_screen.dart:51`), the shell's
`.select` is local to AppShell. Dart records give structural `==`, so Riverpod
select rebuilds only when length or hasOverdue flips — the BackdropFilter perf
property documented at `summary_providers.dart:78` is preserved verbatim.

**Overdue source of truth — correct.** `reason == ReviewReason.overdue` is
not a parallel computation: `buildReviewQueue` assigns `overdue` exactly when
`needsReview(lesson, now)` passes (`review_cycle_service.dart:271-274`), i.e.
the decay computation itself, evaluated against the same `nowValueProvider`
clock that rebuilds the queue. `daysOverdue > 0` would be equivalent by
construction (`:36-37`, zero unless overdue).

- **P1** — dark-mode badge digit uses the wrong palette token:
  `_badge` prints `context.colors.onState` on the accent fill
  (`app_shell.dart:548`). `onState` is white in both themes
  (`app_colors.dart:275,326`) and is contracted for wrong/right fills
  (`:195`); accent's contract token is `onAccent`, which flips to near-black
  `#04203F` in dark precisely because "the dark accent … needs near-black on
  it" (`:133-138`, `:261`, `:314`). Result: dark theme renders white-on-
  `#4D9BFF` ≈ 2.8:1 on a 10pt bold digit — below even the 3:1 graphics bar,
  and contrary to seven sibling call sites that all use `onAccent` on accent
  fills (e.g. `buttons.dart:69-71`, `status_chip.dart:109`,
  `day_picker.dart:552`). Light theme unaffected (`onAccent == onState ==
  white` there). Fix: `color: alarm ? c.onState : c.onAccent`. Tests assert
  background colour only (`shell_badge_test.dart:96-102`), which is why this
  slipped; add a dark-theme/text-colour assertion with the fix.
- **P3** — residual semantic tension: a lowMastery row still shows the red
  glyph inside Review Center while the tab over the same queue wears accent.
  Pre-existing row design, arguably intentional per-row urgency; noting only.

## fa92b50 (interloper) — interaction check

Touched only prompts.dart length plumbing + tables/entities. With N16: no
shared code (different widget, different file). With N17: orthogonal gates —
maxLength counts raw characters (`LengthLimitingTextInputFormatter` /
TextField), validity counts visible content; neither weakens the other, and
column widths are respected regardless of invisibles because the cap applies
to raw length. No interaction risk; no further review needed.

## Cross-file consistency (Q5)

The three changes read like one hand: narrative why-comments in house voice,
const private formatter mirroring `_ArabicIndicDigits`'s shape (static int
literals, single-pass loop), switch-expression classifier next to its only
consumer, tests opening with rationale doc-comments. Only defect: the swapped
separator glyphs at `ather_controls.dart:471` (above).

## Test results

```
flutter test test/widget/number_field_test.dart test/widget/prompts_test.dart \
            test/widget/shell_badge_test.dart --no-pub
00:01 +19: All tests passed!   (7 number_field + 8 prompts + 4 shell_badge)

flutter analyze <six touched files> --no-pub
No issues found!
```

pubspec* untouched throughout.
