# Data Audit

Phase 1, read-only. Scope: `lib/data/**`, `lib/domain/entities/study_backup.dart`, orchestration in
`lib/presentation/providers/*`, migration/restore/round-trip tests under `test/data` and
`test/domain`. Line numbers refer to the working tree as of 2026-08-25.

Note on test execution: this machine's `.dart_tool/package_config.json` resolves every package to
Windows paths (`C:/Users/...`), so the suite could not be re-run here. Test verdicts below are from
reading the test files against the code, not from executing them.

---

## Migration ladder verification table (step | DDL | test | verdict)

Ladder source of truth: `app_database.dart:56` (`schemaVersion = 5`) and `onUpgrade`
(`app_database.dart:71-110`). Every step is additive; nothing is dropped or rewritten anywhere in
the ladder.

| Step | DDL executed | Test (real file image) | Verdict |
|---|---|---|---|
| v1→v2 | `createTable(dailyTasks)` at current shape (incl. `surrendered`, so no later patch-up needed) — `app_database.dart:73` | `task_migration_test.dart:75` "upgrading from v1 adds daily_tasks and keeps the curriculum" — seeds a real v1 image via `DROP`-shaping + `PRAGMA user_version = 1` (:48) | PASS. Straight-climb guard is correct: table created at current shape, and the `from < 5 && from >= 2` guard at :90 prevents duplicate-column failure on this climb |
| v2→v3 | `addColumn` ×3 (`subjects.name/archivedAt/deletedAt`) + last-ever `_seedSubjects()` — :74-83 | `task_migration_test.dart:105` "upgrading from v2 adds the subject columns"; seed-suppression regression: `task_migration_test.dart:134` "the seed never runs again once a subject can be deleted" | PASS. Re-seed at :82 is safe only because pre-v3 subjects were undeletable; test pins that the seed stays dead from v3 onward |
| v3→v4 | `createTable(studyEvents)` — :88 | `study_events_migration_test.dart:68` "upgrading from v3 creates study_events and keeps everything" (`user_version = 3` at :64) | PASS |
| v4→v5 | `ALTER TABLE daily_tasks ADD COLUMN surrendered NOT NULL DEFAULT 0` via `m.addColumn` — :101 | `surrender_migration_test.dart:82` — builds a real v4 image by dropping the column off drift's own schema (:77), asserts rows survive field-for-field, default reads `false` (not null), both write directions work | PASS. This is the Rule-1 gate (1.8.0+15 on real phones) |
| straight climb v2→v5 | all three later steps in one pass | `surrender_migration_test.dart:129` and `study_events_migration_test.dart:109` (both set `user_version = 2`) | PASS. `from >= 2` guard skips the redundant `addColumn` because `createTable(dailyTasks)` already built the column in |
| fresh install | `createAll` + seed | covered in all three files ("a fresh install creates ... outright") | PASS |

Gaps (non-blocking):

- No dedicated v3→v5 image test (v3 is exercised only inside the v2 climb). The step logic
  involved is identical (`from < 4` createTable + `from<5 && from>=2` addColumn), so risk is low.
- `beforeOpen` sets `PRAGMA foreign_keys = ON` (:115) but no test asserts FK enforcement survives
  an upgrade path (e.g. purge-after-migrate cascades). See D-03 for why an assertion would be cheap.
- Migration failures are reported to Crashlytics then rethrown (:103-109), which leaves the app
  unopenable by design — correct for this data model, worth stating in RELEASE_NOTES if ever changed.

---

## Index/query gap list (query file:line | missing index | impact)

`tables.dart` declares **zero** indexes and `app_database.g.dart` contains **zero**
`CREATE INDEX` statements (verified by grep). Every query below is a full table scan.

| Query | Missing index | Impact |
|---|---|---|
| `drift_study_repository.dart:532-544` (deleteExam): `exam_entries WHERE lesson_id=? ORDER BY created_at DESC, id DESC LIMIT 1` | `exam_entries(lesson_id, created_at DESC)` | Full scan per exam deletion; deleteExam runs this plus lesson+chapter lookups in one transaction. Ms-scale today, grows linearly with lifetime exams |
| Cascade children: `lessons.chapter_id`, `exam_entries.lesson_id`, `exam_question_groups.exam_id`, `homework_entries.lesson_id` (`tables.dart:55,70-71,102,114-115,180-181`) | index on each child FK column | With `foreign_keys=ON`, each deleted parent row triggers an unindexed search of every child table. Purging a subject (30 chapters × ~20 lessons) walks `lessons` 30×, then `exams/groups/homework` per deleted lesson. Still sub-second at realistic sizes; degrades quadratically with record size |
| `drift_study_repository.dart:770-799` (_readCustomSubjectData): `chapters WHERE subject_id IN (...)`, `lessons WHERE chapter_id IN (...)`, `exams WHERE lesson_id IN (...)`, `groups WHERE exam_id IN (...)`, `homework WHERE lesson_id IN (...)` | same FK indexes | Runs once per restore of a v1 blob; scan cost paid inside the restore transaction (UI spinner window) |
| `drift_task_repository.dart:18-25` (watchTasks): `ORDER BY day, sort_order, id` | `daily_tasks(day, sort_order)` | Whole-table sort on every task write; table is small (a handful of rows/day) — negligible now |
| `drift_task_repository.dart:50-52` (addTask): `day BETWEEN ? AND ?` (±26h window) | `daily_tasks(day)` | Same small-table excuse |
| `drift_study_repository.dart:66-77` (readEvents): `study_events ORDER BY at, id` | `study_events(at)` | Unbounded append-only log (see D-07 growth note); the one table where an index will eventually matter |

Honest overall impact: P2. Realistic records are thousands of rows, not millions; SQLite scans of
that size are milliseconds. The cascade-child indexes are the ones I would actually add first,
because they turn purge/delete from O(parents × table) into O(parents × log).

---

## Integrity findings — EACH: id, file:line, concrete corruption sequence, severity, proposed fix, risk

### D-01 — Exam drafts survive account switch/wipe/delete-account (cross-student leak)
- **Where:** `presentation/exam_entry/exam_entry_screen.dart:119` (`_draftKeyFor => 'exam_draft_$lessonId'`); wipe paths that never touch it: `presentation/providers/backup_gate.dart:91-92` (`clear()` + `clearTasks()`), `presentation/settings/settings_screen.dart:736-737`.
- **Corruption sequence:** Student A opens the exam wizard for lesson id 3, types scores, kills the app without saving → draft persisted in SharedPreferences. Student B signs in on the same phone, confirms the wipe; `clear()` empties SQLite and new ids start at 1 again. B creates a curriculum, opens their own lesson id 3's wizard → `_loadDraft` (:132) finds `exam_draft_3` and pre-fills A's scores into B's exam form. B can save them as their own exam — wrong data written into the mastery pipeline, plus a privacy leak between minors sharing a device.
- **Severity:** P1.
- **Fix:** clear `exam_draft_*` keys wherever `kLastAccountUidKey` is rewritten (`backup_gate.dart:75,102`) or key drafts by uid (`exam_draft_${uid}_$lessonId`).
- **Risk:** trivial; pure prefs work, no schema change.

### D-02 — Restore / wipe span two transactions across two repositories (all-or-nothing broken at orchestration level)
- **Where:** `presentation/providers/backup_providers.dart:172-175`: `await studyRepository.restore(backup)` then `await taskRepository.restoreTasks(backup.tasks)`. Each half is individually transactional (`drift_study_repository.dart:623`, `drift_task_repository.dart:209`), but nothing joins them. Same shape for wipes: `backup_gate.dart:91-92`, `settings_screen.dart:736-737`.
- **Corruption sequence:** Auto-restore on empty device downloads a blob; `study.restore` commits (curriculum replaced, ids remapped); process is killed before `restoreTasks` commits. Device now holds the cloud curriculum but zero tasks (or, on a manual restore over existing data, the *old* tasks next to the *new* curriculum). Nothing detects the half-state; the next upload then mirrors it to the cloud, making it permanent. The spec promise is "restore all-or-nothing keeping ids".
- **Severity:** P1.
- **Fix:** move task restore inside the study-repo transaction (the database object is shared; expose `AppDatabase.restoreEverything(StudyBackup)` or pass a callback into `restore`). Same for `clear`+`clearTasks`.
- **Risk:** low-medium: single-writer transaction restructure; tests exist (`backup_restore_test.dart:145,188`) and would need to move with the logic. Window today is small but real (process death, task-restore throwing).

### D-03 — Zero indexes on FK/ordering columns (see gap list above)
- **Where:** `lib/data/db/tables.dart` entire file.
- **Corruption sequence:** none directly — performance/integrity-of-experience, not correctness. Worst realistic case: purging a large archived subject on a mid-range phone blocks the UI isolate's DB calls long enough for the recycle-bin screen to look hung; a user retrying sees duplicate purge attempts (idempotent, so harmless).
- **Severity:** P2.
- **Fix:** `@TableIndex.sql` on `lessons(chapter_id)`, `exam_entries(lesson_id, created_at)`, `exam_question_groups(exam_id)`, `homework_entries(lesson_id)` — all additive, needs `schemaVersion 6` + a `createIndex` migration step + Rule-1 test.
- **Risk:** migration ladder grows; must ship with its own file-image test like every rung.

### D-04 — reorderTasks leaves concurrently-added tasks outside the dense rewrite
- **Where:** `drift_task_repository.dart:178-204`. The batch assigns dense `0..n` only to ids present in `orderedIds`; a task added to the same day after the drag started (not in the list) keeps its stale `sortOrder`.
- **Corruption sequence:** Day has tasks sortOrder 0..3. User long-press-dragging while a widget/second flow inserts a new task (addTask computes max+1=4 in its own transaction, serialized before the reorder lands). Reorder writes 0..3 over its four known ids — the new row also holds 4, fine — but if instead the insert lands *after* the reorder read candidates and *before* commit… impossible (transactions serialize). The reachable case: reorder's `orderedIds` snapshot predates the insert → insert gets 4, reordered get 0..3 → consistent. The actual hole: `orderedIds` contains a subset (UI passed only visible rows of a filtered list) → untouched rows keep colliding values. Result: duplicate `sortOrder` within a day; `watchTasks` tie-breaks by id (:24) so order is deterministic but position semantics are silently bent until the next full reorder.
- **Severity:** P2 (no data loss; ordering ambiguity).
- **Fix:** after filtering to same-day ids, extend the rewrite to *all* same-day rows not in `orderedIds` (append them after the explicit prefix).
- **Risk:** small; localised to `reorderTasks`.

### D-05 — Stream errors surface as an *empty* snapshot everywhere
- **Where:** `drift_study_repository.dart:1111` correctly forwards source errors (`onError: controller.addError`), but the consumer contract throws that away: `app_providers.dart:154-156` `snapshotValueProvider` maps any non-data state (including `AsyncError`) to `StudySnapshot.empty()`.
- **Corruption sequence (display corruption, not disk):** a transient drift error (disk I/O hiccup, db closed during hot restart) emits AsyncError → dashboard/review/analytics all render "no subjects, no lessons" for as long as the error state stands. A student can reasonably conclude their record was deleted. Nothing distinguishes "empty" from "error".
- **Severity:** P2.
- **Fix:** keep `snapshotValueProvider` for genuinely-loading fallbacks, but branch screens on `snapshotProvider.hasError` to show the existing `error_banner.dart` instead of empty states.
- **Risk:** touches many screens' provider choice; mechanical.

### D-06 — combineLatest publishes latest-known-per-source, not a consistent cut
- **Where:** `drift_study_repository.dart:1042-1138`, coalesce window `kSnapshotCoalesceWindow = 16ms` (:1054), publish uses whatever each slot holds (:1077-1082).
- **Corruption sequence:** transaction T commits writing tables A+B. Drift re-emits A's stream, timer scheduled; B's stream re-emission lands 17ms later (query re-execution delayed behind other work). Publish fires at 16ms with A-new/B-old → one frame where e.g. a new exam exists but its question groups don't → exam rendered with `groups: []` for a frame. Self-corrects on B's emission. UI-transient only; no writer consumes snapshots.
- **Severity:** P2 (cosmetic flicker; worst case a one-frame `percentage` bar with missing group breakdown).
- **Fix (optional):** raise window, or have drift deliver all post-commit emissions before publish (already mostly true since events fire after commit on one connection).
- **Risk:** none if left as-is; the comment block documenting the trade-off is accurate.

### D-07 — Backup ceiling discovered only at failure time; events/tasks ride unbounded
- **Where:** `firestore_backup_repository.dart:169-173` refuses >900KiB after encoding; caller marks sync failed (`backup_providers.dart:159-166`) and retries forever on every debounce.
- **Arithmetic:** see capacity section — measured ceiling ≈41.7k exams on synthetic data, ≈12–20k exams assuming degraded compression on real Arabic titles. Marginal gzipped cost ≈20 B/exam. Checklist/task events add ~70 B raw each (~10 B gzipped) and grow forever (capture-only, never pruned, restored wholesale).
- **Corruption sequence:** three-year heavy user crosses the line; cloud silently stops advancing (card shows "failed: tooLarge" only when Settings is opened). Phone lost → cloud copy is up to years old. Not silent corruption, but silent *staleness* of the only surviving copy.
- **Severity:** P2 today (ceiling far above realistic density: ~1.4–2.2k exams/year heavy usage), trending worse with events growth.
- **Fix:** surface `tooLarge` outside Settings (badge on dashboard), and/or prune `study_events` older than N years at upload, and/or split doc.
- **Risk:** pruning trades history; needs a product decision, not a code patch.

### D-08 — Export exists, import does not
- **Where:** `data_export_service.dart` shares JSON built by `StudyBackup.toJson` (complete vs schema: subjects, chapters, lessons, exams incl. groups, homework, tasks, events — everything except nothing). But grep confirms **no** file-picker/import path anywhere in `lib/`: `StudyBackup.fromJson` is called only from `firestore_backup_repository.dart:142`.
- **Implication sequence:** offline-first student exports monthly to Drive, loses phone, reinstalls offline or with a different Google account → the app cannot read the export; the JSON is readable by humans and by nothing else. The export's framing ("the record is theirs") promises recoverability it doesn't deliver.
- **Severity:** P2 (product gap, not data bug).
- **Fix:** a file-picker → `fromJson` → existing confirmed `restore()` path; all validation/clamping already exists.
- **Risk:** import becomes a third destructive-write entry point; must reuse the confirmation + empty-check gates.

### D-09 — Restored subject rows accept arbitrary ids incl. seed range
- **Where:** `study_backup.dart:257-269` parses `id` unchecked; `drift_study_repository.dart:644-659` replaces subjects wholesale. Threat model for hostile blobs is already accepted in-code for scores (`study_backup.dart:398-418`) but subjects got no equivalent repair.
- **Corruption sequence:** hand-crafted Firestore doc (attacker/modified build holding the student's token) carries `{id: 2, code: 'custom', name: 'x'}`. Restore deletes seeds, inserts impostor at id 2. Chapters from the blob pointing at 2 render under it; `resetSubjectsToSeed`'s `insertOrIgnore` (`app_database.dart:152`) then keeps the impostor forever; ARB names for biology still render (code ignored for seeded display) but `renameSubject` scoped to `code='custom'` now renames slot 2. Local-only; requires authenticated hostile write.
- **Severity:** P2.
- **Fix:** on restore, clamp/validate: reject or re-id subjects whose `id <= 4` unless `code` is one of the four seeds.
- **Risk:** low; touches restore only.

### D-10 — recordHomework performs no range guard on direct writes
- **Where:** `drift_study_repository.dart:597-614` stores `score/maxScore` as given; restore clamps (`study_backup.dart:314-334`), the wizard presumably validates, but the repository contract allows `score=9999, maxScore=10`.
- **Corruption sequence:** future call site (import feature, debug tool) passes unchecked ints → lesson screen renders 99990% (the exact failure the restore clamping documents having seen on-device).
- **Severity:** P2.
- **Fix:** clamp in `recordHomework` exactly as `fromJson` does.
- **Risk:** none.

---

## Backup capacity math (show arithmetic)

Measured empirically with Dart `jsonEncode` + `gzip` replicating `StudyBackup.toJson` field shapes
exactly (epoch-ms ints, double percentages as Dart prints them, 2 groups/exam, 1 event per 2 exams,
Arabic titles):

```
budget            = 900 KiB                       = 921,600 bytes (gzipped)
raw bytes / exam  (measured)                      = 326 B   (2 question groups)
raw bytes / event (measured shape)                ≈ 70 B
gzip ratio observed on synthetic record           = 15.6–15.9×  (keys/titles repeat heavily;
                                                    real records will compress less)
binary-searched ceiling at observed ratio         ≈ 41,700 exams under budget
conservative planning band (assume 4–7× ratio):
    921,600 × 7 ÷ 326 ≈ 19,800 exams
    921,600 × 4 ÷ 326 ≈ 11,300 exams
marginal gzipped cost per extra exam at 10k scale = 19.9 B/exam (measured)
```

Density check: heavy usage ≈ 60 lessons × 1 exam per 30-day cycle × 12 cycles = 720 exams/year;
two simultaneous groups of question-groups already included. Even 3× that is 2,160/year → the
pessimistic floor (≈11k) buys ≈5 years. Events at ~2,500 toggles/year ≈ 175 KB raw/year ≈ 25 KB
gzipped — noise next to exams, but strictly growing and never pruned (feeds D-07).

Firestore headroom: doc hard limit 1,048,576 B − 921,600 B payload ≈ 124 KiB for checksum,
formatVersion, counts, timestamp — comfortable.

sqlite_sequence / restore id collisions — verified empirically today:

```
CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT);
INSERT INTO t(id,v) VALUES(500,'restored');   -- seq := 500
INSERT INTO t(v) VALUES('auto');              -- id 501 (seq raised above explicit max ✓)
DELETE FROM t;                                -- seq stays 500 (delete never lowers it ✓)
INSERT INTO t(v) VALUES('fresh');             -- id 502 > all restored ids ✓
```

Both directions hold: restoring ids *above* the local high-water mark raises the sequence with the
explicit insert; restoring ids *below* it leaves the higher local sequence intact. Next local insert
can never collide with a restored id. (`subjects` is deliberately *not* autoincrement and uses
max(id)+1 scanning — unaffected either way.)

---

## Verified-solid areas

1. **FK pragma actually executes**: `beforeOpen` runs `PRAGMA foreign_keys = ON`
   (`app_database.dart:111-116`) once per connection; `drift_flutter`'s `driftDatabase(name:)` uses a
   single background connection, and pragmas persist for the connection life. Cascades are live.
2. **Cascade chain is complete and recursive**: subjects→chapters→lessons→{exams→groups, homework}
   all `ON DELETE CASCADE` (`tables.dart:55,70,101,114,180`). Deleting a chapter removes its lessons'
   exams/groups/homework in one statement; there is **no lastReviewedAt hole** on chapter/lesson/
   subject deletion because the clock owners are deleted with it. The one place the clock could lie —
   deleting a single exam — is handled exhaustively in `deleteExam`
   (`drift_study_repository.dart:520-592`): newest-remaining-exam vs chapter-masteredAt comparison
   with the created-before-mastery guard, `didExam` following the evidence rather than the clock, and
   reminder bookkeeping cleared. This is the best-audited function in the file.
3. **done/surrendered mutual exclusion is structural**, not conventional: both writers read-modify-
   write inside one transaction and clear the opposite flag in the same statement
   (`drift_task_repository.dart:84-122,132-163`); transition-only event capture rides in the same
   transaction as the flip.
4. **Restore rollback**: single transaction around delete-all + inserts
   (`drift_study_repository.dart:623-752`); a failing insert rolls back to the pre-restore world —
   pinned by `backup_restore_test.dart:188` ("a restore that fails part-way leaves the database
   untouched"). Preserved-custom-subject path re-allocates ids above the backup's max and remaps
   every FK (`_reinsertCustomSubjectData`, :817-906), with the id-collision case tested
   (`backup_restore_test.dart:347`).
5. **Serialization round-trip symmetry**: every column appears in both `toJson` and `fromJson`,
   nullable edges (`masteredAt/lastReviewedAt/lastNotifiedAt/archivedAt/deletedAt`) via
   `_epochOrNull/_dateOrNull`; dates are epoch-ms UTC everywhere (no ISO strings, no locale parsing);
   format-version refusal is one-way tolerant exactly where documented (missing `events`/`surrendered`
   keys parse as historically-empty, newer versions refused). Covered by
   `study_backup_test.dart:101` (populated round trip), `:155` (exact instants), `:191-207`
   (surrender tolerance), plus clamping tests `:235-279`.
6. **Checksum scope is right**: SHA-256 over uncompressed JSON, stored beside (not inside) the payload,
   verified before the parsed record reaches the restore transaction, absent-checksum legacy docs
   tolerated (`firestore_backup_repository.dart:29-43,124-151`; tests `backup_checksum_test.dart:128-264`).
7. **Day-key discipline**: `dayOf` anchors to midnight UTC on write *and* re-normalizes on read;
   legacy local-midnight rows handled by day-number comparison in add/reorder windows
   (`drift_task_repository.dart:37-56,176-190`; `task_day_key_test.dart` covers write/read/round-trip/
   DST-bent instants).
8. **Seed safety on upgrade**: seed runs exactly twice in a DB's life (create + v2→v3), `insertOrIgnore`
   at fixed ids 1–4, suppression regression-tested (`task_migration_test.dart:134`). Custom ids always
   ≥5 because `createSubject` takes max+1 over surviving rows — no collision path with seeds through
   ordinary operation (hostile-blob exception logged as D-09).
9. **Upload guard rails**: uid-owner double-check before upload including re-check after awaits
   (`backup_providers.dart:99-141`), `.future` reads instead of loading-fallback values, empty-state
   upload deliberately allowed so deletions propagate — each decision documented at the site.
10. **Notification schedule hygiene**: fingerprint covers ids+moments+bodies+enabled flag, cleared
    before platform work so a crash can't strand a stale "applied" claim, persisted for cold-start
    dedupe (`review_notification_service.dart:349-444`); plan derives from `activeLessons` so
    deleted/archived subjects stop reminding. Orphaned alarms are impossible past one debounced
    rebuild because scheduling is cancel-all + rebuild.
