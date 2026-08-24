# Architecture Audit

Phase 1, read-only. Scope: all 112 dart files under `lib/` (excluding `*.g.dart`) plus the
test tree. Method: full import-graph extraction (`^import` per file, classified by owning
layer), provider watch/read census, route-literal grep, clock grep, test-tree comparison.
Line numbers verified against the working tree on 2026-08-25.

## Import-boundary verification table (claim | reality | violating edges file:line)

| # | Claim (PROJECT.md §2) | Reality | Verdict | Violating edges |
|---|---|---|---|---|
| B1 | `domain/` is pure Dart — no drift, no Flutter | 20 files; every import is an intra-domain relative path. Grep for `package:flutter`, `package:drift`, `dart:ui`, `package:intl` under `lib/domain/`: **zero hits** | PASS | none |
| B2 | `presentation → domain` | 38 presentation files import domain entities/services/repository interfaces; mastery math reached only through `Summaries.*`, `ReviewCycleService.*`, `lessonSummaryProvider(...).needsReview` | PASS | none |
| B3 | `presentation ↛ data` (screens never touch data) | Provider files import data as the composition root (acceptable, that is where wiring lives): `app_providers.dart:11-12`, `auth_providers.dart:7`, `backup_providers.dart:5`, `task_providers.dart:3`, `export_providers.dart:3`, `notification_providers.dart:10`. **But one screen constructs a data-layer class directly** | **FAIL (1 edge)** | `lib/presentation/chapter_report/chapter_report_screen.dart:19` imports `data/export/pdf_export_service.dart`; `:96` runs `const PdfExportService()`. Secondary: `lib/presentation/settings/export_screen.dart:13` imports `data_export_service.dart` for a doc-comment reference only (`[DataExportService]` at :22) — runtime-unused import |
| B4 | `data → domain` only (+ shared core) | Repos and services import domain entities/interfaces; the only cross-package-family edge is `core/clock`: `drift_study_repository.dart:6`, `drift_task_repository.dart:3`. `review_notification_service.dart:8-10` imports domain constants/services — inward, legal | PASS | none |
| B5 | `data ↛ presentation` | No file under `lib/data/` references any presentation path or symbol | PASS | none |
| B6 | `core ↛ features` | No file under `lib/core/` imports presentation/data/app. Core is a leaf shared kernel | PASS | none |
| B7 | drift `.watch()` streams feed one combined snapshot | `drift_study_repository.dart:31-39` combines exactly six table streams via `_combineLatest6` (:1056) with a 16 ms coalesce window (`kSnapshotCoalesceWindow`, :1040); every screen reads it through `snapshotProvider`/`snapshotValueProvider` — no screen opens its own query | PASS | none |

**Entity purity:** confirmed for all 10 files in `lib/domain/entities/` — no Flutter, no
drift, no intl; icons/colours are explicitly excluded (`subject.dart:40`). The one
drift type that leaks toward presentation is `QueryExecutor` in
`app_providers.dart:3,32` (`databaseExecutorProvider`) — a test seam, not a layering break.

## Provider topology findings

Measured, not impression:

- **No god-providers.** Largest fan-in of any single provider body is 2 watches
  (`summary_providers.dart:64-65`, `:89-92`, `:99-112` — snapshot + now). The derived chain
  is `snapshotValueProvider → dashboardProvider → homeStatsProvider`, each adding one edge.
  `navigation_providers.dart:31-33` reads 2. Nothing reads more than 3.
- **No widget reaches past providers into repositories on read paths.** All 31
  `ref.read(<x>RepositoryProvider)` call sites in screens are inside write callbacks behind
  `runWrite` (delete/create/clear) — the documented write idiom. Reads go exclusively through
  `ref.watch` of summary/derived providers.
- **Cross-feature reach-ins are narrow and documented.** `exam_entry_screen.dart:401`
  requests notification permission on first exam — the §3.15a rule. `settings_screen.dart`
  imports 5 provider files (app, auth, backup, notification, task) because it is the app's
  hub screen — see F-06. `app_shell.dart` reads only `app_providers.dart`.
- **Unwrap idiom is consistent:** three parallel `*ValueProvider`s
  (`snapshotValueProvider` :154, `accountValueProvider` auth_providers.dart:27,
  `tasksValueProvider` task_providers.dart:23) apply the same `.value ?? fallback` rule.

## Findings

### F-01 — P1 — Screen constructs a data-layer service directly
- **Where:** `lib/presentation/chapter_report/chapter_report_screen.dart:19` (import), `:96` (`const PdfExportService()`).
- **What's wrong:** the share-PDF path bypasses both the domain boundary claim (§2) and the
  provider seam every other I/O capability uses. There is no `pdfExportServiceProvider`;
  the widget owns construction.
- **Future cost:** the PDF pipeline cannot be faked at this screen without pumping real pdf
  codegen; a platform guard (e.g., desktop-only raster path) will land inside build code;
  the day export grows a constructor dependency (fonts, clock) every call site edits.
- **Fix:** add `pdfExportServiceProvider` beside `dataExportServiceProvider` in
  `lib/presentation/providers/export_providers.dart:8` and consume with `ref.read`.
- **Risk:** trivial — mechanical move, existing behaviour preserved.

### F-02 — P1 — Delete-account workflow (a four-repository use case) lives in screens, in near-duplicate
- **Where:** `lib/presentation/settings/settings_screen.dart:733-740` (`_deleteEverything`)
  and `:744-759` (`_retryWithPassword`) — two copies of
  flush→clear→clearTasks→deleteCloudData→deleteAccount; third wipe sequence in
  `lib/presentation/providers/backup_gate.dart:91-92` (`clear()` + `clearTasks()`); fourth
  clear pair in `settings_screen.dart` sign-out path context.
- **What's wrong:** the ordering contract ("each step only runs if the one before it
  succeeded" — comment at :730-732) is a business rule, yet it is enforced by hand in widget
  methods. The duplication has already diverged: `_retryWithPassword` deliberately skips
  `flush()` but re-copies the other four calls; `backup_gate`'s wipe knows nothing of the
  cloud-delete step by design but shares the local-wipe half.
- **Future cost:** every new persistent surface (next table, next cache, next mirror)
  requires finding N wipe sites by memory; missing one leaves a store surviving account
  deletion — a privacy defect, not a cosmetic one. Untestable except through the full
  settings-screen widget harness (`test/widget/delete_account_test.dart`).
- **Fix:** one application service (e.g., `AccountCleanup` in `lib/domain/services/` taking
  the repository interfaces, or a `deleteAccountProvider` orchestrator in providers/) owning
  the sequence; both retry paths call it with a flag.
- **Risk:** low-medium — must preserve the exact step order and the uid-write-after-wipe rule
  (`backup_gate.dart:100-102`); covered by `delete_account_test.dart` and
  `account_switch_gate_test.dart`.

### F-03 — P2 — Feature-specific widgets parked in `core/widgets/`
- **Where:** `day_picker.dart` (sole consumer `tasks/`), `task_strike_marks.dart`
  (`tasks/widgets/task_row.dart` only), `celebration_overlay.dart` (`chapter/` only),
  `settings_list.dart` (all 5 consumers under `settings/`).
- **What's wrong:** core is documented as "shared presentation primitives"; these four are
  single-feature. Usage census across lib/presentation confirms no second consumer.
- **Future cost:** core/widgets becomes the new grab-bag the feature folders were meant to
  prevent; a tasks redesign edits `core/`, inviting cross-feature regressions.
- **Fix:** relocate to `tasks/widgets/`, `chapter/widgets/`, `settings/widgets/` (imports are
  relative; churn is contained).
- **Risk:** low — pure moves; tests reference by path (`day_picker_test.dart`,
  `task_strike_painters_test.dart`, `celebration_overlay_test.dart`) and move with them.

### F-04 — P2 — Documented folder convention does not match reality
- **Where:** PROJECT.md §2 claims `presentation/ one folder per screen: *_screen.dart,
  widgets/, *_providers.dart`. Reality: **zero** feature-local `*_providers.dart` (all
  providers centralised in `lib/presentation/providers/`); only `tasks/widgets/` exists;
  `settings/` holds 7 screens, `auth/` 2; widgets live *inside* provider files:
  `ReviewScheduler` (`notification_providers.dart:63`), `BackupSyncGate`
  (`backup_gate.dart:22`), `DataExportNotifier` state machine (`export_providers.dart:32`);
  non-screen widget areas `common/` and `share/` are undocumented.
- **What's wrong:** the project's own standing rule sends every agent to PROJECT.md first;
  the map is wrong about the thing agents navigate by.
- **Future cost:** agents either "fix" the structure against the doc's intent or keep
  deepening the deviation silently; new screens get invented conventions per author.
- **Fix:** cheapest correct move is updating §2 to describe reality (centralised
  `presentation/providers/`, `common/`, `share/`, widgets-in-provider-files exceptions) and
  naming which convention governs new screens. Restructuring is optional, not required.
- **Risk:** documentation-only if updated; high if someone restructures casually mid-feature.

### F-05 — P2 — `ExamEntryScreen` is a 1,254-line god-screen
- **Where:** `lib/presentation/exam_entry/exam_entry_screen.dart` — wizard state machine
  (:299-336), draft persistence (:280-296), save orchestration incl. permission request and
  navigation (:338-419), plus 8 private widget classes (:842-1254: `_WizardHeader`,
  `_StepHeading`, `_GroupCard`, `_LabelledField`, `_BeforeAfter`, `_DelayedCountUp`,
  `_BottomBar`).
- **What's wrong:** largest file in the presentation layer (next: settings 871, lesson 690);
  the private widgets are untestable in isolation (only reachable through the full wizard).
- **Future cost:** every wizard change risks conflicts in one hot file; sub-widget tweaks
  pay the whole screen's compile/test cost; the M-13/M-14/M-15 motion work concentrates here.
- **Fix:** split the eight private widgets into `exam_entry/widgets/*.dart`; leave the state
  machine in the screen. No behaviour change.
- **Risk:** low — mechanical extraction, covered by `exam_wizard_test.dart`.

### F-06 — P2 — SettingsScreen build fans out to 9+ providers, snapshot watched three times inline
- **Where:** `lib/presentation/settings/settings_screen.dart:88-96` (locale, themeMode,
  accountValue, appLockEnabled, lockMethod, appPasscode, biometricsAvailable, backupSync,
  backupMetadata) plus `ref.watch(snapshotValueProvider)` repeated at :125, :132, :136.
- **What's wrong:** legal Riverpod (all inside build), but any snapshot emission rebuilds the
  entire 871-line page including lock/notification sections that do not depend on it; the
  triple inline watch is the same value re-read.
- **Future cost:** settings keeps accreting rows; each new section adds a rebuild trigger to
  every other section.
- **Fix:** hoist a `subjectsCountProvider`/`deletedCountProvider` pair (one watch), extract
  heavy groups (`_NotificationsRow` pattern already exists at :549) into small Consumers.
- **Risk:** trivial.

### F-07 — P2 — Router redirect guard has no direct test
- **Where:** `lib/app/router.dart:164-170` (the single auth redirect); grep for
  `createRouter|redirect` across `test/` matches nothing relevant (boot branches are exercised
  indirectly via `boot_branches_test.dart`).
- **What's wrong:** the auth gate is centralized (good) and prose-documented (§3.17), but its
  truth table — signed-out→login, signed-out-at-login stays, signed-in-at-login→dashboard,
  signed-in elsewhere stays — is asserted nowhere directly.
- **Future cost:** a refactor of `createRouter`'s signature or the refresh-listenable bridge
  (:132-152) can silently flip one branch; only full-boot widget tests would catch it, and
  only for the states they happen to pump.
- **Fix:** a `test/app/router_redirect_test.dart` driving `createRouter` with fake
  `isSignedIn`/`accountChanges` over the four cases.
- **Risk:** none — additive test only.

### F-08 — P2 — Integration-grade widget tests mixed into `test/widget/` (real drift DBs)
- **Where:** 13 of 33 files in `test/widget/` construct `AppDatabase(NativeDatabase.memory())`
  (e.g., `student_flow_test.dart:32`, `backup_test.dart`, `tasks_test.dart`) while 20 others
  stub providers.
- **What's wrong:** not a purity violation — overriding `databaseProvider` is the documented
  seam and in-memory drift is legitimate — but the suite blends unit-speed widget tests with
  full-stack flows in one directory with no naming distinction; suite time and flakiness
  budget become opaque.
- **Future cost:** contributors cannot tell which failures indicate a broken widget vs a
  broken schema/migration; CI time grows invisibly.
- **Fix:** either accept and document the split in PROJECT.md's test map, or move the DB-backed
  flows to `test/flow/` (structure already mirrors lib cleanly otherwise:
  `test/domain`↔`lib/domain`, `test/data`↔`lib/data`, `test/core`↔`lib/core`).
- **Risk:** none if documentation-only.

## Naming/folder deviation inventory

| Deviation | Where | Convention source |
|---|---|---|
| No `*_providers.dart` in any feature folder (doc promises one per screen) | all of `lib/presentation/` | PROJECT.md §2 |
| Only `tasks/widgets/` exists; other features put private widgets inline | `chapter_screen.dart` (589 l), `lesson_screen.dart` (690 l), `dashboard_screen.dart` (744 l) | PROJECT.md §2 |
| `settings/` = 7 screens, not "one folder per screen" | `about/backup/export/profile/recycle_bin/settings/subjects_screen.dart` | PROJECT.md §2 (spirit) |
| Widgets defined inside `*_providers.dart` files | `ReviewScheduler` notification_providers.dart:63; `BackupSyncGate` backup_gate.dart:22; `DataExportNotifier` export_providers.dart:32 | file-naming honesty |
| Undocumented widget areas `common/`, `share/` | `presentation/common/*` (5 files), `presentation/share/*` (2 files) | PROJECT.md §2 omits them |
| Feature-specific widgets in `core/widgets/` | see F-03 | §2 "shared primitives" |
| `backup_gate.dart` named neither `*_providers.dart` nor a widget suffix | `presentation/providers/backup_gate.dart` | local convention |

Route/naming positives worth recording: every screen ends `_screen.dart`; **zero literal
route strings outside `router.dart`** (all navigation goes through `Routes.*` constants,
`router.dart:30-54`, including the notification tap handler at
`notification_providers.dart:_openLesson` → `Routes.lesson(id)`); guard logic lives in exactly
one place (`createRouter` redirect, router.dart:164).

## Clean bills of health (explicitly checked)

1. **Clock discipline: PASS.** Exactly one production `DateTime.now()` in `lib/` —
   `review_notification_service.dart:452`, reading `.timeZoneOffset` — precisely the site §3.8
   documents. Every other hit is the Clock itself (`core/clock/clock.dart:16`), `MutableClock`,
   or comments. Screens take `now` from `clockProvider` (e.g., exam_entry_screen.dart:375).
2. **Mastery math confinement: PASS.** Decay/review arithmetic exists only in
   `lib/domain/services/` (`review_cycle_service.dart`, `mastery_calculator.dart`,
   `summaries.dart`, `insights_generator.dart`). Presentation counts booleans the domain
   derives (`summary_providers.dart:43-51`); the wizard classifies review exams via
   `lessonSummaryProvider(...).needsReview` (exam_entry_screen.dart:374), not its own date math
   (zero `.inDays`/`.difference(` in presentation outside a Timer).
3. **No duplicated data↔presentation logic found:** snapshot building exists once
   (`_buildSnapshot`), backup JSON once (`StudyBackup.fromJson`/formatVersion), summaries once.

---

## Summary

P0: 0 · P1: 2 · P2: 6

The claimed architecture is substantially real: the domain layer is provably pure, data never
looks up at presentation, core is a leaf, the combined-snapshot stream is the single read path,
routes and the auth guard are fully centralized, and clock discipline is exact. The debt that
exists is concentrated at the seams agents actually touch: one screen-built data service
(F-01), an account-deletion workflow scattered across three widget sites (F-02), and a
documented folder contract the tree stopped honouring (F-04) — the last being the most urgent
to fix *on paper*, because PROJECT.md is this repo's primary agent interface.
