# Phase 4 — Regression Report & Final Diff Review

Branch `ai-audit/2026-08-25` @ HEAD `2a43eb7`. Date 2026-08-25.
Environment: Flutter 3.47.1 / pinned intl 0.20.2 — everything run `--no-pub`
against the existing `.dart_tool` resolution; `pubspec*` untouched.
All suites run **sequentially** (no concurrent flutter processes).

---

## Part 1 — Late fix commits

### 390c6c5 `test: seed established-install state…` — **APPROVE**
- `test/support/established_install.dart`: sound. `kSignedInTestUid='test-uid'`
  equals `FakeAuthRepository.signedIn()`'s id; key literal
  `kLastAccountUidKey='last_account_uid'` imported from prod, not duplicated.
  Mirrors the `account_switch_gate_test` seeding idiom.
- **No tautology**: the three seeded backup tests still assert substance
  (restore replaces cloud content; backing out changes nothing; failing-sync UI
  copy). Seeding only changes *which gate branch* lets the journey start.
- **Split is real**: `backup_test.dart` seeds exactly its 3 failing call sites
  (`a failing sync says why`, `manual restore confirms first`,
  `backing out of the restore`). Genuinely fresh/legacy boots stay unseeded —
  notably `an empty install pulls the cloud copy down` and
  `a populated install is never overwritten without being asked`, which
  *intentionally* exercises legacy-device interception. Unseeded boots remain
  at lines 146/208/231.
- **C1 suites untouched**: commit stat lists 6 files;
  `account_switch_gate_test.dart` and `backup_flush_test.dart` not among them.

### ffebfd6 `fix: badge digits use accent foreground off-alarm` — **APPROVE**
- `alarm ? onState : onAccent` matches the palette contract,
  lib/core/theme/app_colors.dart:133-138 (`onAccent` "flips with the theme";
  `onState` stays white in both).
- Values check out: light onAccent=white==onState (light pin asserting both is
  valid), dark onAccent=`0xFF04203F` ≠ onState white.
- Pins cover light accent, dark accent (`isNot(onState)`), and the alarm fill
  in **both** themes.

### 2a43eb7 `docs: update cross-references…` — **APPROVE**
- Comment-only verified: every added/removed line in the diff is `///` or `//`.
- References resolve: `e81724f` exists ("hold backup cycles when reads fail…")
  and really touched `backup_gate.dart`; `backup_gate.dart` exists;
  `ExamDraftStore`, `keyPrefix`, `scheduleSave`, `kExamDraftWriteDelay` all
  exist in `lib/data/exam_draft_store.dart`.

---

## Part 2 — Full regression

`flutter analyze --no-pub`: **No issues found** (whole project).
`tool/check_invariants.sh`: **all 9 invariants hold** (applicationId, keystore-
fail, versionCode 16, appVersion match, schema/migration pairing, ABI/engine,
no conflict markers, rules ceiling, explicit-delete grant).

### Per-suite results (67 files, sequential)

| suite | result | | suite | result |
|---|---|---|---|---|
| router_redirect | 11/11 | | exam_eve_sheet | 4/4 |
| app_haptics | 12/12 | | exam_wizard | 17/17 |
| plurals | 7/7 | | haptics_setting | 2/2 |
| springs | 16/16 | | icon_motion | 28/28 |
| backup_checksum | 10/10 | | layout_matrix | 12/12 |
| backup_restore | 11/11 | | lesson_p3 | 3/3 |
| drift_study_repository | 47/47 | | lock_method | 12/12 |
| exam_draft_store | 15/15 | | lock | 7/7 |
| data_export | 7/7 | | mastery_card | 12/12 |
| pdf_export | 7/7 | | motion | 27/27 |
| rn_service_persistence | 3/3 | | number_field | 9/9 |
| review_notification_service | 29/29 | | prompts | 6/6 |
| snapshot_load | 2/2 | | recycle_bin | 4/4 |
| study_events_capture | 12/12 | | review_center_p3 | 4/4 |
| study_events_migration | 3/3 | | security | 2/2 |
| surrender_migration | 3/3 | | shell_badge | 7/7 |
| task_day_key | 10/10 | | shell_first_frame | 2/2 |
| task_migration | 4/4 | | **student_flow** | **HANG (timeout)** |
| task_surrender | 9/9 | | tasks | 13/13 |
| design_invariants | 6/6 | | task_strike_painters | 12/12 |
| exam_eve_service | 5/5 | | widget_test | 12/12 |
| insights_generator | 35/35 | | theme_test | 3/3 |
| mastery_band | 6/6 | | account_switch_gate | 11/11 |
| mastery_calculator | 39/39 | | analytics_screen | 5/5 (~1 skip) |
| mastery_concepts | 7/7 | | auth | 19/19 |
| review_cycle_service | 25/25 | | backup_flush | 9/9 |
| review_due_distribution | 3/3 | | backup | 9/9 |
| review_fixes | 4/4 | | **boot_branches** | **FAIL 1/2** |
| study_backup_homework_clamp | 6/6 | | brand_draw_on | 8/8 |
| study_backup | 13/13 | | celebration_overlay | 3/3 |
| subject_name_length | 3/3 | | chapter_badge | 4/4 |
| summaries | 9/9 | | dashboard_p3 | 10/10 |
| security_configuration | 2/2 | | day_picker | 20/20 |
| | | | delete_account | 4/4 |

No suite exceeded the 4-minute budget except the two failures below.
`analytics_screen` has one deliberate skip (`~1`), pre-existing.

### Failures & classification — **both audit-introduced, must-fix P1**

**1. `test/widget/boot_branches_test.dart` — FAIL (1/2), deterministic (×2).**
`cold start builds the dashboard tab only`: "A Timer is still pending even
after the widget tree was disposed."
- Introducer (automated `git bisect`, throwaway worktrees + copied
  `.dart_tool/package_config.json`): **191303d** (C1 gate fix);
  `7002fec` good / `191303d` bad; base `053f079` good.
- Mechanism: 191303d removed the `previous == null` early return; an
  empty-prefs boot now falls through the gate, builds `BackupSyncNotifier`,
  whose `ref.listen(snapshotProvider/tasksProvider)` fires `_schedule()` →
  20 s upload-debounce `Timer` (lib/presentation/providers/backup_providers.dart:88)
  still pending at invariant check.
- Fix (validated locally, 2/2 green): seed
  `SharedPreferences.setMockInitialValues(establishedInstallPrefs())` in the
  file's `_boot()` — same idiom as 390c6c5.

**2. `test/widget/student_flow_test.dart` — HANG (>4 min, ×4 incl. isolated
quiet rerun). Not a machine-load flake: base runs it in 2 s.**
`empty app to a first recorded exam` stalls after tapping `احفظ النتيجة`, in
`await db.close()` (verified by temporary marker instrumentation; instrumentation
reverted).
- Automated bisect was poisoned by harness-level flakes ("Cannot close sink
  while adding stream" at loading stage) caused by TERM-killed runs; discarded.
  Clean manual probes, one commit at a time: `0e920e4` PASS, `b23286f` PASS,
  `92815b7` PASS ×2, **`f240a1f` HANG ×2** → introducer **f240a1f** (N14).
- Mechanism: N14's `reportFailure` forces `BackupSyncNotifier` to build during
  boot (failing fake repo → auto-restore throws); its persistent provider
  listens hold live drift stream queries, and mid-test `db.close()` then never
  completes under the test binding.
- Fix (validated locally, passes in 2 s): follow the house `closeApp` idiom —
  unmount the tree (`tester.pumpWidget(const SizedBox.shrink())` + settle pump)
  **before** `db.close()`, exactly as `backup_test`/`delete_account` already do.

Neither failure indicates a product-code defect surfaced on device; both are
test-side fallout from legitimate gate behaviour changes. Fixes are one-liners
following existing patterns; both were applied transiently, verified green, and
**reverted** — working tree is clean apart from this report.

### Known-good comparison at HEAD
- widget_test **12/12** ✅ · dashboard_p3 **10/10** ✅ (grew 9→10 via audit-added
  test; green) · recycle_bin **4/4** ✅ · backup **9/9** ✅
- review_center_p3 **4/4** ✅ — note: the "5/5" expectation is stale; the file
  has held 4 tests since c771d13 (3 at base, grew to 4 during audit). Nothing
  was lost.

### Launch smoke (headless)
The real `AtherApp` widget tree pumps without crash in three suites:
`widget_test` (12 full-app scenarios), `boot_branches` (cold start + tab
mounts; second test passes), and `student_flow` (real drift DB: boot → chapter
→ lesson → exam wizard → save, hundreds of settled frames — stall is confined
to its own teardown line, removed by the validated patch). No APK mandate;
`flutter build` not run.

---

## Verdict

**NO-GO as-is → GO conditional on landing the two P1 test fixes above**
(one-liners, patterns already in-repo, both pre-validated here). Everything
else is release-clean: analyze zero-issue, all invariants hold, 65/67 suites
and 682/684 tests green at HEAD, all three late fix commits APPROVED.
