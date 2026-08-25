# Phase 2 — Cross-Review: DATA domain

Reviewer: phase-2 cross-reviewer (did not author the phase1 report).
Input: `docs/audit/phase1/data-auditor.md`. Base: `ai-audit/2026-08-25` @ `c9a28ec`.
Method: every cited file:line opened and read; greps for cross-file claims (draft keys,
`fromJson` call sites, `CREATE INDEX`, wipe paths); cited test lines spot-checked.
No builds run, no code modified.

## Summary stats

| Verdict | Count | Findings |
|---|---|---|
| CONFIRMED | 7 | D-01, D-02, D-06, D-07, D-08, D-09, D-10 |
| DUPLICATE | 2 | D-03 → performance-auditor **PF3**; D-05 → correctness-auditor **C6** (+ phase0 N7) |
| FALSE-POSITIVE | 1 | D-04 |
| STALE | 0 | — |

Total findings reviewed: 10. The migration-ladder table, index gap list and capacity math were
also verified line-by-line; see "Ladder re-verification" below.

---

## Per-finding verdicts

### D-01 — Exam drafts survive account switch/wipe (cross-student leak)
**Claim:** drafts persist under `'exam_draft_$lessonId'`; no wipe path clears them; student B
inherits A's prefilled scores after ids restart at 1.
**VERDICT: CONFIRMED**
**Evidence (checked):**
- `lib/presentation/exam_entry/exam_entry_screen.dart:119` — `_draftKeyFor(int lessonId) => 'exam_draft_$lessonId'`.
- `:129-171` `_restoreDraft` silently refills fields from SharedPreferences; `:183-203`
  `_persistDraft` writes on every keystroke.
- Grep over `lib/`: the only occurrences of `exam_draft` are in this screen. Neither
  `backup_gate.dart:91-92` nor `settings_screen.dart` clears any draft key.
- Wipe sites confirmed at `backup_gate.dart:91-92` — plus a **second** wipe pair the report missed:
  `settings_screen.dart:749-750` (`_retryWithPassword`) alongside :736-737 (`_deleteEverything`).
  Same gap, one more entry point.
- Id-restart premise holds: SQLite AUTOINCREMENT sequences live in the deleted DB rows'
  table but `clear()` deletes chapters/tasks/events only; new lessons re-number from 1
  (`drift_study_repository.dart` inserts without explicit id). Collision with a stale draft key is real.
**Final severity:** P1 · **Effort:** S · **N-id:** N20 (phase0 bundles this fix at P2; P1 stands here
because the failure writes another child's scores into B's mastery record — wrong data, not just polish).
**One-line fix:** key drafts by uid (`exam_draft_${uid}_$lessonId`) or clear `exam_draft_*` wherever
`kLastAccountUidKey` is rewritten (`backup_gate.dart:75,102`) and in both settings wipe paths.

### D-02 — Restore/wipe span two transactions across two repositories
**Claim:** `backup_providers.dart:172-175` runs study restore then task restore as two separate
transactions; process death between them strands a half-state that the next upload makes cloud-permanent.
**VERDICT: CONFIRMED**
**Evidence (checked):**
- `lib/presentation/providers/backup_providers.dart:172-175` — exactly the two awaits, nothing joins them.
- `drift_study_repository.dart:623` — `_db.transaction(...)` around delete-all + inserts.
- `drift_task_repository.dart:209` — separate `_db.transaction(...)` for tasks.
- Poisoning path verified: `BackupSyncNotifier.build` listens to both streams (:76-77), so both
  re-emit after the partial restore and schedule `flush()`; empty upload is deliberately allowed
  (:124-137); uid owner check passes (same account). Half-state reaches Firestore unblocked.
- Same shape for wipes: `backup_gate.dart:91-92`, `settings_screen.dart:736-737` and :749-750.
**Final severity:** P1 (small window, but when hit the damage is permanent in the only surviving copy;
borderline P0 by the rubric) · **Effort:** M · **N-id:** NEW (adjacent to N4/N14 but different root —
this is transaction scope, not marker/surfacing).
**One-line fix:** move task restore inside the study repo's transaction (shared `AppDatabase`;
e.g. an `AppDatabase.restoreEverything(StudyBackup)` or a callback param), same for clear+clearTasks.

### D-03 — Zero indexes on FK/ordering columns
**Claim:** tables.dart declares no indexes; every listed query/cascade is a full scan.
**VERDICT: DUPLICATE** — identical finding already reported as **PF3** in
`docs/audit/phase1/performance-auditor.md:56-73` (same tables, same fix incl. schemaVersion 5→6 +
migration test). Factual basis independently re-verified: zero `@TableIndex` in `tables.dart`,
zero `CREATE INDEX` in `app_database.g.dart`; query citations match
(`deleteExam` scan `drift_study_repository.dart:532-544`; `_readCustomSubjectData` IN-scans
:762-808; `watchTasks` order :18-25; `addTask` window :50-52; `readEvents` :66-77).
**Final severity:** P2 · **Effort:** M · **N-id:** NEW (perf-domain owned by PF3).
**One-line fix:** adopt PF3's plan verbatim — additive `@TableIndex.sql` set behind a v5→v6 rung with
its own file-image test. **MIGRATION-RISKY (Rule 1): do not bundle with other data fixes.**

### D-04 — reorderTasks leaves concurrently-added tasks outside the dense rewrite
**Claim:** if UI passes a subset of the day's ids, unlisted rows keep colliding sortOrder values.
**VERDICT: FALSE-POSITIVE** (as a present defect; valid only as latent contract hardening).
**Evidence (checked):**
- Mechanism reading is correct: `drift_task_repository.dart:184-203` renumbers only
  `orderedIds ∩ sameDay`.
- But the premise ("UI passed only visible rows of a filtered list") has **no producer**: the sole
  caller is `tasks_screen.dart:104-125`, which builds ids from `tasks` = `tasksForSelectedDayProvider`
  (`tasks_screen.dart:167,212,222`), and that provider filters the *complete* tasks stream by day
  number (`task_providers.dart:45-54`). Every same-day row is always in `orderedIds`.
- With full-day lists both orderings serialize cleanly: insert-then-reorder leaves max+1 intact;
  reorder-then-insert computes max+1=4 over the renumbered 0..3. Transactions on one connection
  serialize (`addTask` reads max inside its own transaction, :49-58), so no interleaving produces a
  persistent duplicate. Auto-restore cannot race a drag (gate requires an empty DB first,
  `backup_gate.dart:210`).
**Residual value:** the repository still *permits* subsets; extend the rewrite to all same-day rows
not in `orderedIds` as cheap defense-in-depth. P2/S if adopted; not a bug today.

### D-05 — Stream errors surface as an empty snapshot everywhere
**VERDICT: DUPLICATE** — same finding as **C6** in `docs/audit/phase1/correctness-auditor.md:109-131`
(also phase0 **N7**). Shared citations re-verified:
`app_providers.dart:154-156` (`.value ?? StudySnapshot.empty()`; null on AsyncError too),
`drift_study_repository.dart:1111` (`onError: controller.addError`). C6 adds the sharper half
data-auditor missed: backgrounding during the error fires `flush()` whose `.future` awaits sit outside
the try (`backup_providers.dart:121-122` vs try at :144) → fatal Crashlytics noise.
**Severity divergence:** C6 says P2, N7 says P1. Final: **P2** (self-corrects when the stream
recovers; no disk harm) — C6's fuller analysis wins; note N7's rank in the merge.
**Effort:** M · **N-id:** N7.

### D-06 — combineLatest publishes latest-known-per-source, not a consistent cut
**VERDICT: CONFIRMED** (cosmetic, exactly as scoped).
**Evidence (checked):** `kSnapshotCoalesceWindow = 16ms` at `drift_study_repository.dart:1054`;
`publish()` emits whatever each slot holds (:1077-1082); slots assigned independently per source
(:1115-1120). A delayed B-emission can publish A-new/B-old for one frame; self-corrects on B's timer.
The auditor's own recommendation is "optional / none" — concur.
**Final severity:** P2 · **Effort:** S · **N-id:** NEW.
**One-line fix:** accept and document (comment block at :1084-1098 already accurate), or raise the
window; no correctness work warranted.

### D-07 — Backup ceiling discovered only at failure time; events/tasks ride unbounded
**VERDICT: CONFIRMED**
**Evidence (checked):**
- `firestore_backup_repository.dart:169-173` refuses > `_maxBlobBytes = 900*1024` (:75) with
  `BackupFailure.tooLarge`.
- Caller marks failed at `backup_providers.dart:159-166`; nothing surfaces it outside the Settings
  card, and there is no backoff — every subsequent write re-schedules an upload destined to fail.
- Events never pruned: only deleters of `study_events` are `clear()` (:931) and restore (:733);
  capture-only writers grow the table forever; every upload carries all of it (:148-152).
- Arithmetic re-checked: 921,600×7÷326 ≈ 19.8k; ×4÷326 ≈ 11.3k; headroom 1,048,576−921,600 ≈ 124 KiB. Sound.
- Partial overlaps: perf-auditor:65 (events grow unbounded) and security-auditor:18 (ceiling mention,
  quota context) — neither carries the staleness finding itself.
**Final severity:** P2 today, trending worse (ceiling ≈5+ years at pessimistic density; the events
curve is the real liability) · **Effort:** M-L · **N-id:** N15.
**One-line fix:** surface `tooLarge` outside Settings (dashboard badge + sync card), and take a
product decision on pruning/archiving `study_events` at upload.

### D-08 — Export exists, import does not
**VERDICT: CONFIRMED**
**Evidence (checked):** `data/export/data_export_service.dart` is write/share-only (:71-106);
grep confirms `StudyBackup.fromJson` has exactly one caller —
`firestore_backup_repository.dart:142`. No file-picker/import path anywhere in `lib/`.
**Final severity:** P2 (product gap; the export's recoverability promise goes unmet offline /
cross-account) · **Effort:** M · **N-id:** NEW.
**One-line fix:** file-picker → `StudyBackup.fromJson` → existing confirmed `restore()` path,
reusing the confirmation + gates (it becomes a third destructive-write entry point).

### D-09 — Restored subject rows accept arbitrary ids incl. seed range
**VERDICT: CONFIRMED**
**Evidence (checked):** `study_backup.dart:260` parses subject `id` unchecked
(`raw['id']! as int` within :257-269); `drift_study_repository.dart:644-659` deletes subjects then
inserts blob ids verbatim (`Value(s.id)`); score repair exists for exams/homework
(`study_backup.dart:271-334`, threat-model comment :398-418) but nothing validates subjects;
`resetSubjectsToSeed` uses `insertOrIgnore` (`app_database.dart:152`), so an impostor at id ≤4
survives every later reseed; `renameSubject`'s `code='custom'` scoping (:161-164) would hit it.
Requires a hostile authenticated write to the student's own doc — consistent with the accepted
threat model documented in-code.
**Final severity:** P2 · **Effort:** S-M · **N-id:** NEW (enabling condition covered by
security-auditor's App Check finding).
**One-line fix:** in `fromJson`/restore, reject or re-id subjects whose `id <= 4` unless `code` maps
to one of the four seeds.

### D-10 — recordHomework performs no range guard on direct writes
**VERDICT: CONFIRMED**
**Evidence (checked):** `drift_study_repository.dart:597-614` stores `score/maxScore` as given;
restore-path clamping exists only in `study_backup.dart:324,329` (max ≥1, score ∈ [0,max]).
Repository contract allows `score=9999, maxScore=10` to any future caller.
**Final severity:** P2 (no current bad caller; contract hardening mirroring the restore clamp)
· **Effort:** S · **N-id:** NEW.
**One-line fix:** apply the same clamp in `recordHomework` as `fromJson`.

---

## Ladder re-verification (report's table audited)

Re-checked against current code; **table verdict PASS confirmed on every row**:

- `schemaVersion = 5` (`app_database.dart:56`); guard structure matches exactly:
  `from < 2` createTable dailyTasks (:73), `from < 3` three addColumn + last seed (:74-83),
  `from < 4` createTable studyEvents (:88), `from < 5 && from >= 2` surrendered addColumn (:90-101),
  Crashlytics + rethrow (:103-109), `PRAGMA foreign_keys = ON` (:115).
- Test pins verified: `task_migration_test.dart:48,71,75,105,134,156`;
  `study_events_migration_test.dart:64,68,129(v2),150`;
  `surrender_migration_test.dart:78 (report cites :77 — off by one, immaterial),82,147(v2),174`;
  `backup_restore_test.dart:145 ("restore replaces rather than merges"),188,347`;
  `study_backup_test.dart:101,155,191-207,235-279` clamps.
- The three "gaps" notes are accurate as written (no dedicated v3→v5 image test; no FK-survives-upgrade
  assertion; migration failure = app-unopenable by design).

## Capacity math re-check

Arithmetic verified by hand (cannot execute Dart per constraints): planning band numbers and the
124 KiB Firestore-headroom figure are correct. The `sqlite_sequence` reasoning matches SQLite's
documented behavior (explicit larger insert raises seq; delete never lowers it). No dispute.

---

## Workstream proposal

**Workstream name:** `data-backup-trust` — restore atomicity, wipe hygiene, blob honesty.

**File set an implementer owns:**

| File | Changes |
|---|---|
| `lib/domain/entities/study_backup.dart` | subject id validation (D-09); nothing structural |
| `lib/data/repositories/drift_study_repository.dart` | host joined restore transaction (D-02); homework clamp (D-10) |
| `lib/data/repositories/drift_task_repository.dart` | fold `restoreTasks` into the joined transaction (D-02) |
| `lib/presentation/providers/backup_providers.dart` | single-transaction restore orchestration (D-02); surface `tooLarge` state (D-07) |
| `lib/presentation/providers/backup_gate.dart` | clear `exam_draft_*` at uid rewrite/wipe (D-01) |
| `lib/presentation/exam_entry/exam_entry_screen.dart` | uid-scoped draft keys (D-01) |
| `lib/presentation/settings/settings_screen.dart` | dedupe the two wipe pairs onto one helper that includes draft clearing (D-01) |
| `lib/presentation/dashboard/…` (sync badge surface) | `tooLarge` visibility outside Settings (D-07, code half) |
| `lib/data/export/data_export_service.dart` + import screen | import path reusing confirm gates (D-08) |
| Tests moved/extended | `test/data/backup_restore_test.dart` (atomicity cases move with the logic; keep :145/:188/:347 green), `test/domain/study_backup_test.dart` (+subject-id case), new draft-isolation test |

**Ordered fix sequence:**

1. **D-01** draft isolation (S, zero blast radius) — ship alone.
2. **D-10** recordHomework clamp (S) + **D-09** subject-id validation (S-M) — pure `fromJson`/repo guards, fully test-covered.
3. **D-02** joined restore/wipe transaction (M) — the core change; move `backup_restore_test.dart` cases with it; preserve the deliberate empty-upload semantics while doing so.
4. **D-07** code half: `tooLarge` surfaced outside Settings + failure backoff (M). Pruning/archiving events needs a product decision first — do not let an implementer invent retention policy.
5. **D-08** import via file picker (M), gated behind the same confirmation + emptiness checks.
6. **D-06** accept/document (S, optional).

**Explicitly deferred / separate gate:**

- **D-03 (= PF3) indexes**: requires `schemaVersion 5→6` in `app_database.dart` + a new `onUpgrade`
  rung + its own file-image migration test. **MIGRATION-RISKY under CLAUDE.md Rule 1** — must ship as
  its own release with `tool/check_invariants.sh` green and never bundled with the fixes above.
- **D-04**: optional reorder hardening (extend dense numbering to unlisted same-day rows); harmless
  follow-up, no defect behind it today.

**Risks:**

- Anything touching `app_database.dart` `schemaVersion`/`onUpgrade` is Rule-1-gated (D-03 only).
- D-02 modifies the most destructive flow in the app; the ordering comments in
  `drift_study_repository.dart:616-643` are load-bearing — do not reorder delete-before-insert of
  subjects/chapters while joining transactions.
- D-01's uid-keyed drafts change a prefs key shape; old unscoped keys must be cleared once on
  upgrade, not orphaned.
- D-08 creates a third destructive-write entry point; it must inherit confirmation + empty-state
  checks, not bypass them.
