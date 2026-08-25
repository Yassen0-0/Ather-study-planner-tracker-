# Phase 4 — Code Review: l10n/copy commits

Reviewer: Phase 4 COPY-CODE reviewer (did not author the reviewed changes). Branch: `ai-audit/2026-08-25`.
Range: 7d90366 (ICU plural retype), 504a8bd (digits/tanween/en register batch), 5bede70+b172cba (test follow-ups).
Specs implemented: docs/audit/phase2/arabic-copy-review.md + english-copy-review.md.
Method: independent python3 ARB extraction (keys/placeholders/ICU categories/tanween/digits at byte level),
intl-0.20.3 source read for plural-rule behavior, fresh `flutter gen-l10n` regen-diff, `flutter analyze`,
and test runs **in detached throwaway worktrees** (the main tree had another agent's uncommitted edits:
`M lib/presentation/exam_entry/exam_entry_screen.dart`, untracked `test/widget/_tmp_tally_probe_test.dart` —
not mine, excluded by reviewing committed refs only).

## 1 · Mechanical parity (independent extraction)

```
ar non-@ message keys : 348      en non-@ message keys : 348
key-set diff          : none either direction
cross-locale argument names/types (proper ICU brace walk): 0 mismatches
ICU plural keys       : 17 ar / 17 en (same key set)
@placeholder decls    : ar-only on 14 legacy String keys (see P2-D)
```

Placeholder declarations live in the template (`l10n.yaml`: `template-arb-file: app_ar.arb`), so the en-side
gaps cannot affect codegen; message-level argument parity is what matters and it is exact.

## 2 · ICU correctness (both locales)

- Categories used: ar full sets (=0/=1/=2/few/many/other where applicable), en =1/other (+selective =0).
  All valid CLDR categories; zero duplicates; no invalid slots. gen-l10n emits `one/two/few/many/other`.
- Arabic forms checked against the classical number classes: يوم واحد/يومان/أيام (3–10)/يوماً (11–99 tamyiz)/يوم
  (100+); باب/بابان/أبواب/باباً; درس/درسان/دروس/درساً; سؤال/سؤالان/أسئلة/سؤالاً × درجة/درجتان/درجات/درجة —
  every branch grammatical, including predicate-position duals («متأخّر يومين», بعد + genitive «يومين»).
- Generated output: fresh `flutter gen-l10n` in a clean HEAD worktree → **git diff empty** (byte-identical,
  never hand-edited). Signatures int-typed: `dueInDays(int)`, `examGroupLabel(int,int)`,
  `purgeCountsLine(int,int,int,int)`, `analyticsVelocity(int)`, `comebackLine(int,int)` etc.
- `flutter analyze --no-pub`: **No issues found.**

## 3 · Semantic spot-checks

- comebackLine dual «درسان عبرا معادهما»: correct (dual subject + dual verb with alif + معاد+هما);
  few/many «دروس عبرت معادتها»/«درساً عبرت معادتها» take fem-sg verb correctly; Egyptian =0 «ما حدش عبر
  معاده» matches house voice (phase-2 F-01 ratified this shape).
- overdueByDays =0 «متأخّر أقل من يوم»: sensible; daysOverdue==0 is genuinely reachable (cycle-day
  boundary), so the patch fixes a real state, not a hypothetical.
- dueInDays =0 «أقل من يوم» / long «أقل من يوم على المراجعة»: reads naturally standalone; dropping «بقي»
  in the =0 branch is idiomatic in a chip context.
- examGroupLabel singular agreement: «سؤال واحد × درجة واحدة» masc/fem agreement correct during recording.
- analyticsVelocity negatives: claim as worded in test/core/l10n/plurals_test.dart:54-57 is **mechanically
  wrong but harmless**: dart-intl `_ar_rule()` runs `_n % 100` on the signed value and Dart `%` returns a
  non-negative result (-3 % 100 == 97), so -3..-10 land in **MANY**, not OTHER (plural_rules.dart:155-169;
  `_n = howMany`, signed). many/other bodies are identical (`'$value نقطة'`, generated
  app_localizations_ar.dart:1169-1170), so the pinned expectation `-3 نقطة…` passes and the minus renders
  because `{value}` prints in every branch. Zero cannot reach the plural (`isFlat` guard,
  analytics_screen.dart:831-850 routes to analyticsVelocityFlat).

## 4 · Digit policy (PROJECT.md §3.16, PROJECT.md:322/:906/:1366)

- authErrorPasswordShort/passwordTooShort now Western 8/4 with sentence period — verified in diff and file.
- Full-file scan: **zero** Arabic-Indic (٠-٩) and zero Persian (۰-۹) codepoints anywhere in either arb.
- Bidi sampling of rendered contexts: «بقي 3 أيام», «متأخّر 11 يوماً», «أتقنت 2 من 5 أبواب»,
  «3 أسئلة × 4 درجات», «1 من باب واحد» — each digit run is bounded by strong RTL words (the shipped
  lessonCount precedent), so UBA resolves them in place. One exception class: see P2-C.

## 5 · Tanween normalization

Byte-level recount across the whole arb (values + descriptions): alef-then-fathatan «اً» = **48**,
fathatan-then-alef «ًا» = **0** → the 48:0 claim holds exactly. Spot-checked six sites: حساباً
(accountSwitchWipeMessage), معاً (lockMethodBoth), إتقاناً (examEveTierWeakest), معاداً
(examEveTierNearestDue — F-21 rename landed together with the normalization as instructed),
اتصالاً (authErrorNoNetwork), رابطاً (authResetSent).

## 6 · Call sites

Every retyped signature receives a raw int (dashboard :167/:390/:633/:752, lesson :191-196, chapter :536-541,
review_center :338, backup_screen :88, recycle_bin :95/:242, exam_eve_sheet :100-104, subject_screen :147,
exam_entry :605, analytics :141/:850). Remaining `iso()` uses sit on keys that stayed String-typed
(tasksDoneOf, insightLessonNotReviewed, insightDiscipline, reviewWaitingHeader, examErrorSumMismatch,
examNeedToCross, chart digits) — nothing accidentally stripped.

## 7 · Test runs (--no-pub, detached worktree at b172cba)

| Suite | Result | Baseline 053f079 | Pre-range 95aaed3 |
|---|---|---|---|
| test/core/l10n/plurals_test.dart | **PASS 7/7** | n/a (new in range) | n/a |
| test/widget/auth_test.dart | **PASS 19/19** | — | — |
| test/widget/lock_method_test.dart | **PASS 12/12** | — | — |
| test/widget/exam_eve_sheet_test.dart | **PASS 4/4** | — | — |
| test/widget/backup_test.dart | +6 −3 | PASS 9/9 | +6 −3 (**identical**) |
| test/widget/dashboard_p3_test.dart | +9 −1 | PASS 6/6 | +9 −1 (**identical**, same test) |
| test/widget/recycle_bin_test.dart | +1 −3 | PASS 4/4 | +1 −3 (**identical**) |
| test/widget/student_flow_test.dart | hangs on first test (timeout) | — | hangs identically |

All four failures reproduce byte-for-byte (counts and failing test names) at 95aaed3, the commit immediately
before 7d90366, so they were introduced between 053f079 and 95aaed3 (backup/read-path commits e.g. c771d13,
e81724f) and are **pre-existing relative to the review range**. Failure mode is harness-level («النسخة
السحابية» tile never renders; student_flow awaits forever), not an l10n assertion mismatch — the four suites
this range actually edited (plurals/auth/lock/exam_eve) all pass.

## Verdicts

| Commit | Verdict |
|---|---|
| 7d90366 ICU retype both locales | **APPROVE-WITH-NITS** (P2-A/B/C/D) |
| 504a8bd digits/tanween/en batch | **APPROVE** |
| 5bede70 exam-eve test assertions | **APPROVE** |
| b172cba auth/lock test assertions | **APPROVE** |

No P0, no P1. Findings:

- **P2-A** · app_ar.arb:671 — comebackLine lost its trailing period in the rewrite («…عبر معادها}}», old
  value ended «معاده.») while en keeps "meanwhile." — ar/en punctuation divergence on one key. Fix: add «.»
  to the final branch or drop it from en.
- **P2-B** · app_en.arb (comebackLine/dueInDays/dueInDaysLong/overdueByDays) — the =0 patches are ar-only;
  the reachable zero states render "0 days left"/"0 days overdue"/"0 lessons came due meanwhile." in en —
  the same false-fact class the ar side fixed («ما حدش عبر معاده»). The phase-2 en spec omitted =0, so this
  is faithful-to-spec, but the semantic gap is real. Fix: add =0 branches ("Under a day…", "No lessons came
  due meanwhile").
- **P2-C** · analytics_screen.dart:850 + PROJECT.md:906 — dropping iso() on a **signed** value removes the
  mandated isolation for the minus sign (positive counts are covered by the strong-word precedent; the
  hyphen is not). Risk: "-3" may visually detach in RTL («نقطة 3-»). Spec itself prescribed dropping iso()
  here, so guidance conflicts; recommend LRI/PDI inside the ICU branches carrying {value} or an owner
  ratification that colour/chart carry the sign. Related nit: plurals_test.dart:54-57 comment misstates the
  mechanism ("% keeps its sign", "lands in other") — Dart % is non-negative and the case is MANY; assertion
  unaffected (identical text).
- **P2-D** · @metadata parity (en F-12) remains partial after mirroring retyped keys: 14 placeholder-decl
  blocks + description-only blocks still exist only in ar. Documented no-build-impact under
  template-arb-file: app_ar.arb; the deferred step-4 mirror commit is still owed.

Not addressed by this range (open phase-2 items, correctly out of scope): F-06/F-07/F-15..F-24 register and
wording batch, including subjectTemplateCount =1 case government (F-24) — its missing `many` slot happens to
render acceptably through `other`.
