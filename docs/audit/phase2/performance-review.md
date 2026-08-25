# Performance Audit — Phase 2 Cross-Review

Phase 2 · reviewer: PERF-CROSS-REVIEWER · branch `ai-audit/2026-08-25` · read-only re-verification of
`docs/audit/phase1/performance-auditor.md`. Every verdict below was checked against current code by
opening the cited file:line. No builds, no benchmarks — static reading only.

Input report covers 3 findings (PF1 P1, PF2 P2, PF3 P2) plus "clean area" notes.
Clean-area notes were not findings and were not re-verified line-by-line.

---

## Summary stats

| Verdict | Count | Findings |
|---|---|---|
| CONFIRMED | 2 | PF1, PF2 |
| STALE | 0 | — |
| FALSE-POSITIVE | 0 | — |
| DUPLICATE | 1 | PF3 → data-auditor.md D-03 |

Severity after re-rank: **P0 = 0 · P1 = 0 · P2 = 3** (PF1 downgraded P1→P2).

Dup sweep result: the input report's only cross-report overlap is PF3, which data-auditor.md
already carries as **D-03** ("Zero indexes on FK/ordering columns", data-auditor.md:75–80 plus its
gap list at :39–55) with an identical mechanism description, a superset query table
(data-auditor.md:46–51 adds `daily_tasks day BETWEEN ? AND ?`), and the same fix shape
(schemaVersion 6 + `createIndex` + Rule-1 migration test). For `exam_entry_screen.dart`, the other
phase1 hits are different concerns, not duplicates of PF1/PF2:
maintainability-auditor.md M11 (:251–276) — draft protocol as a *structure* finding;
correctness-auditor.md :44 — draft *restore* correctness; data-auditor.md D-01 (:61–66) — draft keys
survive account wipe (= N20); security-auditor.md :73 — same leak from the threat side.

---

## Per-finding verdicts

### PF1 — Wizard rebuilds the entire screen on every keystroke

**Original claim:** unconditional `setState(() => _error = null)` in `_fieldChanged` funnels every
keystroke into a full-route rebuild (~20 + 12·G widgets + "a full ListView relayout") on the app's
core flow; P1.

**VERDICT: CONFIRMED** — severity re-ranked **P1 → P2**, effort **S**, N-id: **NEW**
(serves roadmap opportunity #3 "fast exam-entry"; no N-id covers it).

**Evidence (checked):**
- `_fieldChanged` with the unconditional `setState` — exam_entry_screen.dart:213–216 (`setState` at :215).
- Wired from step 1 total field :541, step 2 via `_GroupCard.onChanged` :570 through
  `_LabelledField` :1065, step 3 correct fields :613. All verified.
- Rebuild scope is the whole route build() :423–521; the `ValueKey<int>(_step)` at :481 only stops
  transition replay, exactly as claimed. Header segment `TweenAnimationBuilder`s :890–927 do not
  replay on unchanged tween ends, so they are rebuild-passed but not re-animated — also as claimed.

**Why the downgrade:** the mechanism is real but the impact sentence "a full ListView relayout per
keystroke" is wrong. Flutter only re-runs layout for dirty render objects; on steps 1 and 3 nothing
in the tree changes geometry on a keystroke, so the pass costs widget instantiation + element-tree
diffing over tens of small widgets — sub-millisecond on a mid-range phone. `NumberField` is a
stateless `TextField` wrapper with no internal per-change work (ather_controls.dart:308–350,
onChanged passthrough at :350). The genuinely expensive part of the keystroke path is the encode +
platform-channel write, which is PF2's finding. With no plausible user-visible jank from the
rebuild alone, this fails the P1 bar ("lag users feel"); it stays worth fixing because the fix is a
one-line guard plus optional tally scoping.

**Fix (one line each):** guard `if (_error != null) setState(() => _error = null);` in
`_fieldChanged`; optionally move step 2's live tally (:554–561) under a controller-listener-driven
builder so only the tally text rebuilds.

### PF2 — Draft written via jsonEncode + SharedPreferences platform channel per keystroke

**Original claim:** `_persistDraft` fires jsonEncode + `setString` once per keystroke by documented
design; async so no direct frame drops, but repeated main-thread allocation and prefs flushes that
don't need per-keystroke durability; P2.

**VERDICT: CONFIRMED** — severity **P2** (agreed), effort **M**, N-id: **NEW**.

**Evidence (checked):**
- `_persistDraft` exam_entry_screen.dart:183–203; intent comment :173–182 ("runs once per keystroke
  -- deliberately").
- Callsites: `_fieldChanged` :214 (per keystroke), group remove :574, group add :586. All verified.
- Mechanism accurate: synchronous main-thread `jsonEncode` of all groups' raw text, then one async
  platform-channel round trip per call (Android side writes the whole prefs file via `apply()`).

**Cross-report tension to resolve during implementation:** maintainability-auditor M11 proposes
extracting an `ExamDraftStore` but pins "Keep the keystroke-frequency write semantics identical"
(maintainability-auditor.md:276). This review disagrees with that pin: debounce the write
(~300–500 ms trailing) and add immediate flushes at the loss boundaries the original comment cares
about — `AppLifecycleState.paused/detached`, `dispose()`, step change, `_save()`/`_clearDraft()`.
Do both changes inside the store extraction so the durability contract lives in one testable place.
The wizard tests covering draft restore must pump past the timer.

### PF3 — Zero indexes on FK/filter columns; cascades and scoped queries scan tables

**Original claim:** eight tables, zero `@TableIndex`; FK enforcement makes cascade deletes scan the
child table per deleted parent row; scoped queries and unbounded `study_events` grow linearly; P2
with honest "students feel nothing yet" quantification.

**VERDICT: DUPLICATE** → data-auditor.md **D-03** (+ its gap list, data-auditor.md:39–55).
Severity **P2**, effort **M** (the index DDL is S; the mandatory v5→v6 migration image test under
CLAUDE.md Rule 1 makes it M), N-id: **NEW**.

**Evidence independently confirmed before deduplicating (all current code):**
- Zero indexes anywhere: full read of tables.dart:1–213 (no `@TableIndex`) and grep across `lib/`
  for `TableIndex|CREATE INDEX` → none. Only `customStatement` is the FK pragma,
  app_database.dart:115; `schemaVersion => 5` at app_database.dart:56; `onUpgrade` ladder :71–110
  is where the v6 rung goes.
- Cascade children declared with `onDelete: KeyAction.cascade`: chapters.subjectId tables.dart:55,
  lessons.chapterId :71, homeworkEntries.lessonId :102, examEntries.lessonId :115,
  examQuestionGroups.examId :181.
- Cited queries all exist as written: chapters WHERE subject_id drift_study_repository.dart:276–278;
  UPDATE lessons WHERE chapter_id :333–335; deleteExam newest-remaining
  `WHERE lesson_id ORDER BY created_at DESC LIMIT 1` :532–544; restore-preservation `isIn` scans
  :770–799; study_events ORDER BY at,id :66–72; daily_tasks ORDER BY day,sort_order,id
  drift_task_repository.dart:18–25.
- Cascade sites: purgeSubject :193, deleteChapter :320, clear() transaction :926–933. Mechanism
  correct: SQLite auto-indexes primary keys only, so with `foreign_keys=ON` each parent-row delete
  resolves children by scanning the child table — O(chapters × lessons) row visits for one subject
  purge.
- The dataset-budget quote is accurate (study_snapshot.dart:16–19).

D-03 is the stronger record (superset query list, exact index set). The performance report adds one
index D-03 omits — `chapters(subject_id)` (used by addChapters' dedup read :276–278) and
`study_events(at, id)` vs D-03's `study_events(at)` — merge those two details into D-03's fix when
it is implemented.

---

## Re-ranked severity table

| ID | Finding | Original | Final | Effort | N-id | Status |
|----|---------|----------|-------|--------|------|--------|
| PF1 | Whole-wizard setState per keystroke | P1 | **P2** | S | NEW | CONFIRMED |
| PF2 | Per-keystroke jsonEncode + prefs write | P2 | **P2** | M | NEW | CONFIRMED |
| PF3 | Zero FK/filter indexes | P2 | **P2** | M | NEW | DUPLICATE of data-auditor D-03 |

No P0 or P1 performance findings survive review. The recent perf work the auditor declined to
re-flag (parallel boot, snapshot coalescing, `.select()` badge, debounced scheduler) was spot-read
and the refusal looks right.

---

## Workstream proposal

**Workstream name:** `perf-input-path-and-indexes`

**File set an implementer owns:**
- `lib/presentation/exam_entry/exam_entry_screen.dart` (PF1 guard + tally scoping, PF2 debounce callsites)
- new `lib/data/exam_draft_store.dart` (PF2 + M11 joint extraction: save/load/clear + debounce + lifecycle flush)
- `lib/data/db/tables.dart` (PF3/D-03: `@TableIndex.sql` entries — chapters(subject_id),
  lessons(chapter_id), exam_entries(lesson_id, created_at DESC), exam_question_groups(exam_id),
  homework_entries(lesson_id), daily_tasks(day, sort_order), study_events(at, id))
- `lib/data/db/app_database.dart` (schemaVersion 5→6 + `m.createIndex`/createAll rung in `onUpgrade`)
- tests: `exam_wizard_test.dart` (draft debounce pumping), new `indexes_migration_test.dart`
  (v5 file-image → v6, per Rule 1 / `tool/check_invariants.sh`)
- generated `app_database.g.dart` via build_runner (implementer runs it; reviewer did not)

**Ordered fix sequence:**
1. PF1 guard (`if (_error != null) …`) + step-2 tally scoping — smallest, zero-risk, immediately shippable.
2. ExamDraftStore extraction (M11) *with* the PF2 debounce and lifecycle/dispose/step-change/save
   flushes in the same commit — keeps M11's "behaviour preserved" honest by defining the contract once.
3. PF3/D-03 index migration last — additive-only DDL, schemaVersion bump, Rule-1 image test; never
   ship the bump without its test.

**Risks:**
- Debounce widens the process-death loss window to the debounce period; mitigated only if the
  paused/detached flush lands first — test both paths (backgrounding mid-typing, kill without backgrounding).
- Migration ladder grows to v6; a wrong rung bricks upgrades for real students (Rule 1). Additive
  indexes are safe DDL, but the test must open a real v5 file, not just a fresh createAll.
- Do not touch statement ordering/comments inside restore transactions (drift_study_repository.dart
  :618–906 region is load-bearing per maintainability-auditor.md:284).
- `chapters(subject_id)` index slightly slows chapter inserts; negligible at this scale, note it.
