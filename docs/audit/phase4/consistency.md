# Phase 4 — Consistency Review

Repo: `ather` @ `ai-audit/2026-08-25` · Diff scope: `053f079..HEAD -- lib/ test/ tool/ analysis_options.yaml .gitignore` (36 commits) · Reviewer: consistency pass · Date: 2026-08-25

Question: does the codebase still read like one deliberate engineer wrote it?

**Verdict: substantially yes.** Voice, naming, comment culture, error-handling convention, state modeling and test architecture are uniform across all ten hands. The drift that did slip through is concentrated in three places: two doc-comments that went stale *within this same branch* (code they describe was rewritten by a later commit), a handful of import-block/formatting artifacts from mixed toolchains, and one speculative API.

Severity: **P1** = actively confuses future readers · **P2** = polish.

---

## 1. Naming — CLEAN

Sampled old symbols: `kLastAccountUidKey`, `snapshotValueProvider`, `nowProvider`, `clockProvider`, `databaseProvider`, `studyRepositoryProvider`, `kChapterMasteryThreshold`, `ReviewStateX`, `_draftKeyFor`, `iso()`.

New symbols: `kWeakBandUpperEdge`, `kGoodBandLowerEdge`, `kExcellentBandLowerEdge`, `kSubjectNameMaxLength`, `kExamDraftWriteDelay`, `kLastCloudDownloadKey`, `snapshotReadProvider`, `wipeAccountPreferences`, `restoreEverything`, `restoreTasksWithin`, `badgeIsAlarm`, `_nameHasVisibleContent`, `belowGood`, test-side `kProtectedLocations`.

Every new constant is k-prefixed exactly like its neighbours (`lib/domain/entities/mastery.dart:40-45`, `subject.dart:54`); providers keep the `xxxProvider` suffix; extensions keep `X`. The `kWeakBandUpperEdge`-style names flagged as a risk are actually *on* convention. Note: `kGoodBandLowerEdge = 70` (`mastery.dart:41`) numerically duplicates pre-existing `kChapterMasteryThreshold = 70` (`mastery.dart:45`) — both concepts are separately documented, so this reads as coincidence, not drift. No action required.

## 2. Comments — why-not-what density consistent; no tutorial creep

The diff's long narrative comments (e.g. the N4 empty-upload guard in `backup_providers.dart`, the C1 legacy-device note in `backup_gate.dart`) match the pre-existing register set by `nowProvider`'s doc in `app_providers.dart`. No decorative or tutorial-ish additions found. The one deleted why-comment (`app_shell.dart`, "tapping the selected tab returns to the root") was a genuine dedup — commit `0e920e4`; the explanation survives at `app_shell.dart:129`. Stale cross-references are listed in §8.

## 3. Error handling voice — CLEAN

All seven new catch/guard sites in the diff, graded:

| Site | Log line | Grade |
|---|---|---|
| `backup_gate.dart:106` | `'Ather: account-switch check held -- device read failed: $error\n$stack'` | A |
| `backup_gate.dart:258` | `'Ather: automatic restore held -- device read failed: …'` | A |
| `backup_gate.dart:288` | `'Ather: automatic restore held -- re-read failed: …'` | A |
| `backup_gate.dart:299` | `'Ather: automatic restore failed -- ${e.failure}'` | A− |
| `backup_providers.dart:144` | `'Ather: holding upload -- local read failed: $error\n$stack'` | A |
| `backup_providers.dart:181` | `'Ather: holding empty upload -- no cloud copy has reached…'` (guard, not catch) | A |
| `notification_providers.dart:177` | `'Ather: review reminder sync failed -- $error\n$stack'` | A |

Uniform `Ather: <what> -- <detail>` voice with the ` -- ` separator and `\n$stack` tail, matching every pre-existing site (`write_guard.dart:43`, `backup_screen.dart:111`). The `(e)` binding on the typed `BackupException` catches matches the sibling typed-catch convention (`backup_screen.dart:104`, `export_providers.dart:46`), while generic `on Object` catches use `(error, stack)` — both are house patterns applied correctly. The `catch (_)` → logged upgrade at `notification_providers.dart:175` is an improvement in the house direction. Pre-existing unlogged `on Object` in `settings_screen.dart:707` is out of scope (not touched by this diff).

## 4. State modeling — CLEAN

`SnapshotRead` + four `final class` subclasses (`app_providers.dart:165-193`) reproduces the `Insight` sealed idiom (`insights_generator.dart:16`) verbatim: bare `sealed class X { const X(); }`, final leaves, exhaustive switches at call sites. Consistent with `SyncState`/`ExportState` for the mutable sibling. No ad-hoc enum+nullable-field hybrids introduced.

## 5. Test style — mostly consistent; fixture-seeding uniform

New files (`plurals_test`, `prompts_test`, `number_field_test` additions, `shell_badge_test`, `router_redirect_test`, `exam_draft_store_test`) all follow house shape: file-level doc stating the finding being pinned, `group`/`testWidgets` with sentence-length names, override-based `boot()`/`pump*()` helpers, fixtures seeded via `SharedPreferences.setMockInitialValues` and `Stream.error/value` — same as the surrounding suites. Post-main top-level helper (`_emptyBackup`, `backup_flush_test.dart:410`) has precedent (`shell_first_frame_test.dart`). `kProtectedLocations` follows the `kAnchor`/`kNow` test-constant convention. Drift found:

- **P2 — `test/core/l10n/plurals_test.dart:3-5`**: stray blank line splits `package:` imports into two blocks (flutter block, then lone `package:ather`). Every sibling keeps one package block. Fix: delete the blank line.
- **P2 — `test/widget/backup_flush_test.dart:7-9`**: lone `import 'package:drift/native.dart';` in its own block between third-party and ather groups. Fix: move into the existing package block.
- **P2 — delegates idiom split**: `prompts_test.dart`, `dashboard_p3_test.dart` (`bootScreen`), `review_center_p3_test.dart` list four delegates manually while `shell_badge_test.dart:82` and pre-existing `exam_eve_sheet_test.dart:118` use `L.localizationsDelegates` (which already includes the Global* delegates). Pick one — the shorter house form.
- **P2 — `test/widget/dashboard_p3_test.dart:323`**: group title `'snapshotReadProvider [N7/C6]'` — bracketed ticket tags appear in no other group title (`'cold-start race'`, `'the decode matrix'` style everywhere else). Fix: fold the tag into the body comment.

## 6. File organization — CLEAN (one import-order nit)

`exam_draft_store.dart` sits correctly in `data/` as pure Dart (no Flutter imports), consumed by presentation — layering direction preserved. The key-prefix coupling to `presentation/` is explicitly documented rather than papered over with a layering violation. Import ordering matches siblings everywhere except:

- **P2 — `lib/presentation/dashboard/dashboard_screen.dart:139`**: `import '../../domain/entities/subject.dart';` inserted *after* `domain/services/review_cycle_service.dart`, breaking the file's entities-before-services alphabetical grouping. Fix: move directly under `entities/study_snapshot.dart`.

## 7. Leftover debris — CLEAN

No `TODO`/`FIXME`/`print()`/commented-out code added anywhere in the diff (the `print(` hits in `test/data/snapshot_load_test.dart` are pre-existing, outside the diff). `widget_test.dart` re-indent *removes* old drift. One artifact:

- **P2 — `test/domain/mastery_band_test.dart:71`**: stray trailing `//` inside the `percentages` list (`70, 70.001, //`) used as a manual wrap marker. Fix: delete it and let the list flow.

### Formatter-dialect mix (P2)

`dart format --output=none --set-exit-if-changed` flags 34/55 changed files — **but also 22/79 untouched baseline files**, so most of that is SDK-version noise (repo predates tall style), not audit sloppiness. Within the diff itself, two hands clearly used different formatters:

- **P2 — `lib/presentation/providers/backup_gate.dart:262-264` and `290-292`**: `reportFailure(\n          BackupFailure.unknown,\n        );` deep-indent shape matches no formatter output for this position (current `dart format` rewrites it). Hand-mangled indentation.
- **P2 — `lib/presentation/providers/backup_providers.dart:176-183`**: leading-operator continuation `.getInt(kLastCloudDownloadKey)\n== null)` — the only `==` at line start in all of `lib/`; plus the split `setInt(\n …\n)` chain. New-dialect artifacts against the repo baseline.

Fix for all three: run `dart format` once over the branch's changed files before merge (accepting that a repo-wide reformat is a separate decision).

## 8. Cross-references — 3 stale, rest resolve

Verified resolvable: `wipeAccountPreferences`, `kExamDraftKeyPrefix`, `ExamDraftStore.keyPrefix`, `createSubject`, `showNamePrompt`, `runWrite`, `app_database.g.dart`, `snapshotReadProvider`, `[MasteryBand.fromPercentage]`, `[kSnapshotCoalesceWindow]`, `[createRouter]`, `commonSomethingWentWrong`. Stale:

- **P1 — `lib/presentation/providers/app_providers.dart:282-289`** (`kExamDraftKeyPrefix` doc): says drafts are "written on every keystroke by `ExamEntryScreen._persistDraft`" and that the prefix "must stay in sync with that screen's `_draftKeyFor`". Both halves were obsoleted by `01f8c7d` earlier *in this same branch*: `_draftKeyFor` no longer exists (grep confirms this doc is its only remaining mention), writes go through the debounced `ExamDraftStore.scheduleSave`, and the byte-equal partner is `ExamDraftStore.keyPrefix`. Fix: point the doc at `ExamDraftStore.keyPrefix` / `scheduleSave` and drop `_draftKeyFor`.
- **P1 — `test/widget/dashboard_p3_test.dart:377-381`** (`bootScreen` doc): present-tense claim that "the backup gate awaits `snapshotProvider.future` outside its try, so an errored read escapes as an unhandled zone error". False at HEAD — commit `e81724f` guarded all three gate awaits (`backup_gate.dart:104, 256, 284`). Written before that commit landed and never updated. Fix: reword to past tense ("was unguarded when this was written; now guarded") or drop the rationale.
- **P1 — `test/widget/review_center_p3_test.dart:242-246`**: same stale sentence duplicated. Same fix.

Honourable mention: `test/widget/backup_flush_test.dart:283-286` carries a near-identical clause but in explicit past tense ("sat", "escaped"), which reads as history explaining the guard — correct as written.

---

## Scoreboard

| Domain | Verdict |
|---|---|
| 1. Naming | CLEAN |
| 2. Comment culture | CLEAN (density/register) |
| 3. Error-handling voice | CLEAN (7/7 graded A/A−) |
| 4. State modeling | CLEAN |
| 5. Test style | Dirty — 4×P2 |
| 6. File organization | Dirty — 1×P2 |
| 7. Debris / formatting | Dirty — 7×P2 |
| 8. Cross-references | Dirty — 3×P1 |

**Totals: 3 P1 · 12 P2.** All P1s are documentation rot, not code behaviour; none require touching logic.
