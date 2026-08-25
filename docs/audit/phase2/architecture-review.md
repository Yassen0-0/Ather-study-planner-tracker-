# Phase 2 — Architecture Cross-Review

Reviewer: phase-2 cross-reviewer (not the phase-1 author). Branch `ai-audit/2026-08-25`.
Input: [phase1/architecture-auditor.md](../phase1/architecture-auditor.md). Method: every cited
file:line reopened and read; every census re-run by grep; duplicate sweep across all nine sibling
phase1 reports. Read-only on code.

## Summary stats

| Metric | Count |
|---|---|
| Findings reviewed | 8 |
| CONFIRMED (holds today, not duplicated elsewhere) | 5 |
| DUPLICATE (same finding in another phase1 report) | 2 |
| FALSE-POSITIVE | 0 |
| STALE | 0 |
| P0 after re-rank | 0 (agree with original) |
| P1 after re-rank | 2 (F-02 kept, F-07 raised) |

The phase-1 report is unusually accurate: all 8 findings factually hold at the cited lines.
Two are the same findings maintainability-auditor.md already filed (M5, M6). Line-cite
imprecisions found (do not change verdicts): F-02's "fourth wipe in sign-out path" overcounts
(`_signOut` at settings_screen.dart:649-673 does flush + signOut only, no clear pair); F-05's
draft-persistence cite :280-296 is actually the discard-confirm block; F-06's `_NotificationsRow`
is at :545 not :549; F-08 counts 33 test/widget files, actual is **31** (13 DB-backed — ratio
holds); boundary table's `kSnapshotCoalesceWindow` is at drift_study_repository.dart:1054 not
:1040. Negative claims spot-checked and held: domain purity grep = 0 hits for flutter/drift/
dart:ui/intl under lib/domain/; exactly one production `DateTime.now()`
(lib/data/notifications/review_notification_service.dart:452); no `pdfExportServiceProvider`
exists anywhere in lib/ or test/.

---

## Per-finding verdicts

### F-01 — Screen constructs PdfExportService directly — original P1
**Claim:** chapter_report_screen.dart:19 imports pdf_export_service.dart; :96 runs
`const PdfExportService()`; no provider seam exists.
**VERDICT: DUPLICATE** → [phase1/maintainability-auditor.md](../phase1/maintainability-auditor.md) **M6** (its lines 136-165: same file, same `:96` instantiation, same proposed `pdfExportServiceProvider` fix, bundled with its share-scaffolding triplication).
**Evidence (mine):** import at chapter_report_screen.dart:19; construction at :96; grep confirms zero `pdfExportService*Provider` in lib/+test/; sibling seam exists at export_providers.dart:8-10; export_screen.dart:13 is a doc-comment-only import ([DataExportService] sole occurrence at :22) — runtime-unused, as claimed.
**Final severity:** P2 / effort **S** (downgraded from P1: wiring hygiene, zero current student impact).
**N-id:** NEW.
**Fix:** register `pdfExportServiceProvider` next to `dataExportServiceProvider` (export_providers.dart:8), consume via `ref.read` at :96; fold into M6's `runShareAction` extraction if both are scheduled.

### F-02 — Delete-account wipe sequence duplicated across widget sites — original P1
**Claim:** two hand-copies in settings_screen.dart (:733-740, :744-759), third local wipe pair in backup_gate.dart:91-92, ordering contract enforced by hand.
**VERDICT: DUPLICATE** → maintainability-auditor.md **M5** (its lines 114-134: identical file:lines, identical divergence observation, closure-based fix proposal).
**Evidence (mine):** `_deleteEverything` settings_screen.dart:733-740 = flush→clear→clearTasks→deleteCloudData→deleteAccount, exact order confirmed; `_retryWithPassword` :744-759 = same four minus flush, ends `deleteAccountWithPassword`; backup_gate.dart:91-92 clear+clearTasks with uid-write-after-wipe rule at :100-102. One imprecision: the claimed fourth wipe in the sign-out path does not exist (`_signOut` :649-677 only flushes then signs out).
**Final severity:** P1 / effort **M** (kept above M5's P2: this is the data-destruction path — a missed future store survives account deletion, a privacy defect; architecture's third-site evidence widens M5's blast radius). Closure-helper variant is S; full application service is M.
**N-id:** NEW (fix surface intersects N20's exam_draft key cleanup — do them together).
**Fix:** one orchestrator owning the ordered sequence (closure param for the delete-account variant), both call sites delegate; preserve uid-after-wipe rule (backup_gate.dart:100-102); covered by delete_account_test.dart + account_switch_gate_test.dart.

### F-03 — Feature-specific widgets parked in core/widgets — original P2
**VERDICT: CONFIRMED.**
**Evidence (mine, full census):** day_picker.dart consumed only by tasks/tasks_screen.dart:12; task_strike_marks.dart only by tasks/widgets/task_row.dart:12; celebration_overlay.dart only by chapter/chapter_screen.dart:18; settings_list.dart by exactly five consumers, all under settings/ (subjects:12, settings:19, recycle_bin:13, profile:12, backup:14). PROJECT.md:87 defines core/widgets as "shared presentation primitives".
**Final severity:** P2 / effort **S**.
**N-id:** NEW.
**Fix:** move the four files into tasks/widgets/, chapter/widgets/, settings/widgets/; update relative imports and move their tests with them.

### F-04 — PROJECT.md §2 folder convention contradicts the tree — original P2
**VERDICT: CONFIRMED.**
**Evidence (mine):** PROJECT.md:97 promises "one folder per screen: *_screen.dart, widgets/, *_providers.dart". Reality: zero feature-local *_providers.dart (all 8 live in presentation/providers/); only tasks/widgets/ exists as a feature widgets dir; settings/ holds 7 screens, auth/ 2; widgets-in-provider-files confirmed at notification_providers.dart:63 (`ReviewScheduler`), backup_gate.dart:22 (`BackupSyncGate`), export_providers.dart:32 (`DataExportNotifier`); undocumented areas common/ (5 files) and share/ (2 files) exist.
**Final severity:** P2 / effort **S** — but highest-priority P2: PROJECT.md is this repo's primary agent interface (see CLAUDE.md Rule 2 incidents), so map drift compounds.
**N-id:** NEW (same [DOC] class as N13 — reconcile in one docs pass).
**Fix:** update §2 to describe reality (centralised providers/, common/, share/, named exceptions) and state which convention governs new screens; no restructuring required.

### F-05 — ExamEntryScreen god-screen — original P2
**VERDICT: CONFIRMED** (with cross-reference, not duplicate).
**Evidence (mine):** 1254 lines (wc); largest in lib/ (settings 871, dashboard 744, lesson 690 next). Wizard machine `_next` :299-336 verified step-by-step; save orchestration `_save` :338-419 incl. permission request :401, needsReview classification :374, clock read :375. Private widgets at :842 `_WizardHeader`, :938 `_StepHeading`, :963 `_GroupCard`, :1042 `_LabelledField`, :1071 `_BeforeAfter`, :1113+:1132 `_DelayedCountUp`, :1198 `_BottomBar`. Minor cite imprecision: ":280-296 draft persistence" is actually discard-confirm logic.
**Cross-ref:** maintainability-auditor.md **M11** decomposes the same file differently (extract ExamDraftStore). Complementary halves of one split — schedule together or sequence deliberately.
**Final severity:** P2 / effort **M**.
**N-id:** NEW.
**Fix:** extract the seven private widgets to exam_entry/widgets/*.dart; leave `_next`/`_save` in the screen; exam_wizard_test.dart covers the move.

### F-06 — SettingsScreen fans out to 9+ providers, triple inline snapshot watch — original P2
**VERDICT: CONFIRMED.**
**Evidence (mine):** build watches locale :82, themeMode :83, accountValue :84, appLockEnabled :85, lockMethod :86, appPasscode :87, biometricsAvailable :93, backupSync :95, backupMetadata :96; `ref.watch(snapshotValueProvider)` repeated at :125, :132, :136. `_NotificationsRow` extraction pattern exists at :545 (report said :549).
**Final severity:** P2 / effort **S**.
**N-id:** NEW.
**Fix:** hoist subjects/deleted-counts into one derived watch; wrap heavy groups in small Consumer widgets following the :545 pattern.

### F-07 — Router auth redirect has no direct test — original P2
**VERDICT: CONFIRMED** — severity raised.
**Evidence (mine):** redirect truth table lives solely at router.dart:164-170 inside `createRouter` (:154-157), bridged by `_AuthRefresh` (:136-148); grep for `createRouter` across test/ = zero hits; boot_branches_test.dart exists (test/widget/) but exercises boot branches, not the four redirect cases.
**Final severity:** **P1** / effort **S** (raised from P2: a flipped branch fails silently in exactly the class the rubric calls P1 — either locks every student out or exposes signed-out access; it also guards any future work on N3's mandatory-login redesign).
**N-id:** NEW (prerequisite guard for N3).
**Fix:** add test/app/router_redirect_test.dart driving `createRouter` over the four cases (signed-out→login; signed-out-at-login stays; signed-in-at-login→dashboard; signed-in elsewhere stays).

### F-08 — Integration-grade tests mixed into test/widget/ — original P2
**VERDICT: CONFIRMED** (one count corrected).
**Evidence (mine):** grep counts **13 files** in test/widget/ constructing `AppDatabase(NativeDatabase.memory())` out of **31** .dart files (report said "of 33"); examples verified: student_flow_test.dart setUp at :32-33; backup_test.dart, tasks_test.dart exist. The rest stub providers. test/domain↔lib/domain, test/data↔lib/data, test/core↔lib/core mirroring otherwise holds.
**Final severity:** P2 / effort **S** for the documentation option (recommended first); physical move to test/flow/ would be L and is optional.
**N-id:** NEW.
**Fix:** document the two tiers in PROJECT.md's test map (which failures mean broken widget vs broken schema); revisit physical separation only if CI flakiness materialises.

### Boundary table & clean bills of health (spot-checked)
B1 domain purity re-verified (0 hits); clock discipline re-verified (single production site, correct path lib/data/notifications/review_notification_service.dart:452); B7 stream combiner verified (_combineLatest6 at drift_study_repository.dart:1056; kSnapshotCoalesceWindow const at :1054, report's :1040 off by 14); no screen outside chapter_report_screen.dart imports data/ directly (grep over presentation minus providers/ = the two known edges only).

---

## Workstream proposal

### Workstream: `presentation-seams`

One implementer owns the seams agents touch most: the destructive account flow, the router
guard's safety net, and mechanical de-tangling. Ordered so the test lands before anything moves,
and the privacy-critical consolidation lands before cosmetic splits.

**File set:**
- New: `test/app/router_redirect_test.dart`
- Touched: `lib/presentation/settings/settings_screen.dart`, `lib/presentation/providers/backup_gate.dart`, new `lib/presentation/providers/account_cleanup_provider.dart` (or `lib/domain/services/` equivalent taking repository interfaces)
- Touched: `lib/presentation/providers/export_providers.dart`, `lib/presentation/chapter_report/chapter_report_screen.dart`
- Touched: `lib/presentation/settings/settings_screen.dart` (rebuild hoist), possibly `lib/presentation/providers/summary_providers.dart`
- Moved: `lib/core/widgets/{day_picker,task_strike_marks,celebration_overlay,settings_list}.dart` → feature folders; import updates in `tasks/tasks_screen.dart`, `tasks/widgets/task_row.dart`, `chapter/chapter_screen.dart`, 5 settings screens; corresponding test files move too
- Split: `lib/presentation/exam_entry/exam_entry_screen.dart` + new `lib/presentation/exam_entry/widgets/*.dart`
- Docs: `PROJECT.md` §2 (+ test-map note)

**Ordered fix sequence:**
1. Router redirect truth-table test (F-07, S) — pure additive; protects everything below.
2. Account-cleanup orchestrator (F-02/M5, S-M) — fold in N20's exam_draft key clearing; keep exact step order and backup_gate.dart:100-102 uid rule.
3. `pdfExportServiceProvider` registration + ref.read consumption (F-01/M6 provider half, S).
4. Settings rebuild hoist (F-06, S).
5. core/widgets relocation (F-03, S) — pure moves, run full widget suite after.
6. exam_entry widget extraction (F-05, M) — coordinate with M11's ExamDraftStore extraction if that workstream runs; do not interleave edits to the same file.
7. PROJECT.md §2 + test-map reconciliation (F-04 + F-08 doc option, S) — last, describing the structure as it now stands.

**Risks:**
- Step 2 is the only behaviour-risk item: an exception mid-sequence must leave the retry path able to finish (comment contract at settings_screen.dart:730-732); delete_account_test.dart asserts order — extend, never weaken, it. Do not run concurrently with any N3 login-gate redesign (both touch router/auth assumptions).
- Steps 5-6 churn import paths; land as isolated commits so regressions bisect cleanly (CLAUDE.md Rule 3).
- Step 3 gains test-stubbing ability for PDF export but must not alter share error handling (M6's scaffolding extraction is a separate decision).
