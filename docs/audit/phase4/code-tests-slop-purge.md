# Phase 4 review — code, tests, slop purge (+ interloper)

Reviewer: Phase 4 code reviewer (did not author any reviewed change).
Branch: `ai-audit/2026-08-25`. All commands run with `--no-pub` (pub get fails
locally); `pubspec*` untouched. Working tree returned clean.

## Verdicts

| Commit | Subject | Verdict |
|---|---|---|
| 229c86f | router auth-redirect truth-table test | **APPROVE** |
| 0e920e4 | drop duplicated shell-tab comment | **APPROVE** |
| ea97e08 | trim stock prose from analysis_options | **APPROVE** |
| b0def9f | format widget_test helper indentation | **APPROVE** |
| 3802ef9 | separate coalesce-window note from _combineLatest6 | **APPROVE** |
| c2da56d | relocate ARB PowerShell lesson to RELEASING.md §4b | **APPROVE** |
| 265066e | delete spent tool/*.py l10n scripts | **APPROVE** |
| 6aa11e9 | delete stale Windows-era agent state | **APPROVE** |
| 2fdb01f | drop ExamDraftGroup typedef + ReviewStateX.isOverdueAt | **APPROVE** |
| 8f9d0ba | gitignore: drop wt-session exclusions | **APPROVE** |
| fa92b50 | subject-name cap (INTERLOPER — extra scrutiny) | **APPROVE-WITH-NITS** |

## A) 229c86f — router redirect test

- Calls the **real** redirect: `createRouter(...)` then
  `router.configuration.topRedirect(context, state)` — no fake closure, no
  rendered screens. `GoRouterState` built with `matchedLocation: uri.path`,
  mirroring go_router's own construction (doc'd in-file).
- Truth table matches current gate at `lib/app/router.dart:164-170`
  (verified line-by-line; the four-row table in the test header is exact,
  including the two pinned findings: dropped deep-link destination,
  unconditional post-login `/`). Line reference `164-170` is still accurate
  at HEAD.
- Stat confirms **test file only** — no lib/ edits smuggled in.
- Passes: included in 60/60 green run below.

## B) De-slop

- **0e920e4**: removes 2 comment lines above `initialLocation:`; code hunk
  otherwise empty. Clean.
- **ea97e08**: `git diff 053f079:analysis_options.yaml ea97e08:` shows the
  23 removed lines are **all** Flutter-stock comments. `include:
  package:flutter_lints/flutter.yaml`, `analyzer.exclude:` (wt-session-a/**,
  wt-session-b/**, .auto-claude/**) and `linter.rules:` are byte-identical to
  pre-audit. Functionally intact. (Platform-dir excludes re-added later are
  another wave's 7002fec, out of scope here.)
- **b0def9f**: pure re-indentation of `openWizard` inside its group (9+/9−,
  whitespace only). Empirically exonerated too: full `widget_test.dart`
  passes at 229c86f (see bisect table below).
- **3802ef9**: moves `_combineLatest6`'s doc block from above
  `kSnapshotCoalesceWindow` (where it documented the wrong symbol) to directly
  above `_combineLatest6`, adds a `[kSnapshotCoalesceWindow]` cross-reference.
  Zero code lines changed — const declaration and function signature
  untouched.

## C) Purge

- **c2da56d**: RELEASING.md gains §4b carrying the substance of
  `fix_p3_arb.py`'s header (PowerShell pipe mangled 11 Arabic values to `?`;
  strict UTF-8 in/out; never route ARB text through a console pipe; read a
  value back before committing). Relocated, not lost; deletion precondition
  satisfied before 265066e.
- **265066e**: `rg 'add_p5_arb|add_p5_rich_arb|fix_p3_arb'` outside `.git` →
  only audit docs + stale copies under `.claude/worktasks/release-apk/`.
  Not referenced by `.github/workflows/*`. Work-is-done spot check:
  `examVerdictWeak`/`examEveButton`/`reviewBodyDeclining` present in **both**
  ARBs (4 hits each file).
- **6aa11e9**: `.auto-claude-status`, `.auto-claude-security.json`,
  `.claude_settings.json` deleted. Zero live references in lib/test/tool/
  .github/windows/android/pubspec/docs (audit docs excepted). `.gitignore:93-95`
  still ignores them, so they cannot silently return.
- **2fdb01f**: re-ran the word-boundary sweeps.
  - `rg -n -w 'isOverdueAt|ReviewStateX'` across lib/test/tool/.github/docs →
    **0 code hits** (audit prose only).
  - `rg -n -w 'ExamDraftGroup'` → surviving hits are a **different, live
    symbol**: the class in `lib/data/exam_draft_store.dart:15`, used by
    `lib/presentation/exam_entry/exam_entry_screen.dart:153,155` (which imports
    exam_draft_store.dart at :26) and `test/data/exam_draft_store_test.dart`.
    The deleted typedef in review_cycle_service.dart re-exported
    `DraftQuestionGroup` to nobody; removal safe. Post-delete grep of
    review_cycle_service.dart: no remaining `exam_entry`/`DraftQuestionGroup`
    use — orphaned import correctly dropped, no needed import lost.
  - Consumer suites green: exam_draft_store + review_cycle_service +
    review_due_distribution + review_fixes tests all pass.
- **8f9d0ba**: removes `wt-session-a/`, `wt-session-b/` ignore entries + their
  stale gitlink-accident comment. Verified: `git worktree list` has only the
  main checkout; `git ls-files -s` contains no mode-160000 entries; no path in
  the repo references those directories as live inputs. Nothing live was
  un- or newly-ignored.

## D) fa92b50 — interloper under review (subject-name cap)

Wiring, verified end-to-end:

- Constant: `kSubjectNameMaxLength = 60` — `lib/domain/entities/subject.dart:55`.
- Column: `text().withLength(min:1, max:kSubjectNameMaxLength)` —
  `lib/data/db/tables.dart:27` (was literal 60).
- Call sites — exactly the three that write `subjects.name`, all now pass the
  constant: add via dashboard `dashboard_screen.dart:594`, add via settings
  `subjects_screen.dart:104`, rename `subjects_screen.dart:271`.
- Every other `showNamePrompt` caller writes a longer target and keeps the
  default 80: chapters 120 (`tables.dart:60`; prompts at `chapter_screen.dart:65,91`,
  `subject_screen.dart:38`), lessons 160 (`tables.dart:76`;
  `lesson_screen.dart:58`), task titles 200 (`tables.dart:149`;
  `tasks_screen.dart:45,75`), profile name → SharedPreferences via
  `profileNameProvider` (`profile_screen.dart:158`) — no column cap. The
  "subjects were the only ones that broke" claim checks out.
- **Schema/migration: none.** drift compiles `withLength` to
  `GeneratedColumn.checkTextLength(...)` in `app_database.g.dart:40-43` —
  client-side validation thrown as `InvalidDataException` on write. Text
  lengths produce **no SQL CHECK** (generated CHECKs are boolean-only,
  e.g. g.dart:887+). The commit does not touch the generated file and the
  value is unchanged (60→60), so DDL and schemaVersion are untouched. The
  entity doc's warning (constant changes require build_runner because
  literals are baked into `app_database.g.dart`) is accurate.
- Repro claim consistent with test evidence: boundary 60 accepted / 61 throws
  against a real in-memory NativeDatabase.

Test quality (`test/domain/subject_name_length_test.dart`):

- Boundary pair is real: writes through `DriftStudyRepository.createSubject`
  at exactly `kSubjectNameMaxLength` (accepted, round-trips) and +1 (throws).

Nits (all P2):

1. **P2** `test/domain/subject_name_length_test.dart:50-58` — third test
   asserts `80 > kSubjectNameMaxLength`: constant-vs-constant arithmetic that
   cannot fail on any wiring regression. It documents intent but verifies
   nothing; fine to keep as documentation-as-test, but it should not be read
   as coverage.
2. **P2** No widget-level assertion that `showNamePrompt` threads `maxLength`
   into `_NamePromptSheet`/`TextField` (`prompts.dart:33,119`) — the actual
   regression surface for the original bug sits above the DB tests.
3. **P2** `dashboard_screen.dart:29` — new entity import inserted after
   `domain/services/review_cycle_service.dart`, breaking the file's sorted
   grouping (analyze-neutral today).

## Cross-wave finding (NOT owned by this wave) — P1

**HEAD's suite is red: 4 failures in `test/widget_test.dart`**, introduced by
**191303d** ("fix: gate account switch on local data…", backup-gate C1),
not by any commit reviewed above.

Failure shape: on `bootApp(overdueSnapshot())` the stricter gate sees no
recorded uid + seeded local data and now opens the wipe-consent sheet over the
shell; the subsequent tap on the مراجعة tab lands on the sheet's theater
(warned "would not hit test"), so the تركيب الخلية row never appears →

- `leaving with nothing typed just closes`
- `leaving after typing asks first`
- `the system back steps back instead of closing`
- `the review centre offers the exam directly`

Bisect evidence (detached clone in /tmp/opencode/ather-rv, `--no-pub`):

| Commit | Owner | widget_test |
|---|---|---|
| 053f079 | pre-audit base | PASS 12/12 |
| 0e920e4 … 229c86f | this wave | PASS |
| b23286f, 047208d, 7002fec | other waves | PASS |
| **191303d** | **other wave (C1)** | **FAIL (these 4)** |
| fa92b50 … HEAD | this wave / l10n wave | FAIL (inherited) |

Required fix belongs to the C1 wave: make `bootApp` in widget_test either
record a prior uid or start empty, or have the gate not fire in the seeded
fixture — without weakening 191303d's own new test.

## Test results

- `flutter analyze --no-pub` → **No issues found** (at HEAD).
- `flutter test test/app/router_redirect_test.dart
  test/domain/subject_name_length_test.dart test/widget/prompts_test.dart
  test/data/exam_draft_store_test.dart test/domain/review_cycle_service_test.dart
  --no-pub` → **60/60 passed**.
- `flutter test test/widget_test.dart --no-pub` → **8/12 pass, 4 fail**
  (pre-existing at this wave's start; attributed to 191303d above).
