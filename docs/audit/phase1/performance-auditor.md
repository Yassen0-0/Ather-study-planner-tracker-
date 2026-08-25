# Performance Audit

Phase 1 · auditor: PERFORMANCE-AUDITOR · branch `ai-audit/2026-08-25`, commit `d8ff4e0`.
Covers the three assigned areas: **startup/cold start**, **rebuild cost (riverpod / setState)**, **database (drift queries, streams, schema vs query patterns)**.

Method: every flagged path read end-to-end (`main.dart`, `app_shell.dart`, `exam_entry_screen.dart`, both repositories, `tables.dart`, all files under `lib/presentation/providers/`, plus router/app/dashboard/tasks/review screens). Recent landed perf work (`8ba3387` parallel boot, deferred App Check, 16 ms snapshot coalescing, `.select()` shell badge, debounced notification scheduler) was read and is deliberately **not** re-flagged. Generated files untouched.

`flutter analyze` could not run: `pub get` fails to resolve (`intl` constraint needs `^0.20.3` against the pinned SDK set). Environment issue, not a code finding; nothing was modified to work around it.

---

### PF1 — Exam wizard rebuilds the entire screen on every keystroke · **P1**
- File:line
  - `lib/presentation/exam_entry/exam_entry_screen.dart:213-216`
  - wired from every numeric field: `:541`, `:570` (via `_LabelledField` at `:1065`), `:613`
  - rebuild scope: whole `build()` `:423-521`, step bodies `:545-589` (step 2), `:592-621` (step 3)
- Evidence
  ```dart
  void _fieldChanged() {
    _persistDraft();
    setState(() => _error = null);
  }
  ```
  Every keystroke in every `NumberField` funnels through `_fieldChanged`. The `setState` is **unconditional** — it fires even when `_error == null`, which is the common case. Because `_fieldChanged` lives on the wizard's `State`, each call rebuilds the entire route: `PopScope` → `Scaffold` → header (four `TweenAnimationBuilder` segments, `:890-927`) → `AnimatedSwitcher` → the step's `ListView` with all `_GroupCard`s (each holding two `NumberField`/`TextField`s) → `_BottomBar`. The `ValueKey<int>(_step)` on the switcher (`:480`) only stops the *transition* replaying; it does not stop the rebuild. The only UI that actually depends on per-keystroke state is step 2's live tally (`fraction(_assigned, _totalValue)` + colour, `:554-561`) and the error banner.
- Impact
  Step 2 with G groups costs ≈ `20 + 12·G` widget rebuilds + a full `ListView` relayout per keystroke. A typical paper — total, then 3–4 groups × 2 fields, then 3–4 correct fields — is roughly 25–40 full-screen build/layout passes inside a few seconds of typing. On steps 1 and 3 essentially none of that work changes a single pixel (~100 % wasted); on step 2 only the tally line consumes it. On low-end Android this competes with IME commit frames during fast entry in the app's core flow ("the heart of the product", used multiple times daily).
- Proposed fix
  1. Guard the clear: `if (_error != null) setState(() => _error = null);` — removes the rebuild entirely on the no-error path.
  2. Move the step-2 tally under a `ListenableBuilder(listenable: Listenable.merge([for (final g in _groups) g.count, g.points]))` so only that `Text` rebuilds per keystroke; same pattern if a live figure is ever wanted on step 3.
  3. Keep `_persistDraft()` out of the build path entirely (see PF2).
- Risk
  Low–medium. Validation on Next still reads controllers directly, so behaviour is unchanged; the risk is missing a derived-on-keystroke surface (the tally) when restructuring step 2. Existing wizard tests pin step flow and validation.

### PF2 — Draft written through jsonEncode + SharedPreferences platform channel on every keystroke · **P2**
- File:line
  - `lib/presentation/exam_entry/exam_entry_screen.dart:183-203` (`_persistDraft`)
  - called from `_fieldChanged` `:214`, group remove `:574`, group add `:586`
- Evidence
  ```dart
  void _persistDraft() {
    if (_saving) return;
    unawaited(ref.read(sharedPreferencesProvider).setString(
      _draftKey,
      jsonEncode(<String, Object?>{ 'total': _total.text, 'groups': ... }),
    ));
  }
  ```
  Fired once per keystroke by design (comment at `:174-182`). Each call JSON-encodes every group's raw text on the main thread and issues a `SharedPreferences.setString` — a platform-channel round trip plus an Android `apply()` flush per call.
- Impact
  Entering a 3-group paper produces ≈ 15–30 encode+write operations within seconds. The writes are async so they do not directly drop frames, but each pays main-thread `jsonEncode` allocation proportional to draft size and queues a prefs-file flush; combined with PF1 they land on the same keystroke. The guarantee being bought ("the keystroke right before the process dies") does not need per-keystroke durability — it needs a flush at process-death boundaries.
- Proposed fix
  Debounce the write (~300–500 ms trailing) and add immediate flushes at the boundaries that can lose data: `AppLifecycleState.paused/resumed-detached`, `dispose()`, step change, and `_save()`/`_clearDraft()`. The existing intent survives because backgrounding — the realistic process-death precursor — flushes synchronously.
- Risk
  Low. The comment documents *why* per-change persistence exists; any debounce must keep the lifecycle flush or a killed process loses up to the debounce window of digits. Tests covering draft restore should be extended to pump past the timer.

### PF3 — No indexes on any foreign-key or filter column; cascades and scoped queries scan tables · **P2**
- File:line
  - `lib/data/db/tables.dart:50-213` — eight tables, zero `@TableIndex` declarations (grep over `lib/` confirms no index anywhere; the only `customStatement` is the FK pragma, `app_database.dart:115`)
  - queries filtered on un-indexed columns:
    - `chapters WHERE subject_id` — `drift_study_repository.dart:276-278`
    - `UPDATE lessons WHERE chapter_id` — `:333-335`
    - `exams WHERE lesson_id ORDER BY created_at DESC LIMIT 1` — `:532-544`
    - restore-preservation `isIn` scans — `:770-799`
    - `ORDER BY day, sort_order, id` per emission — `drift_task_repository.dart:18-25`
    - `study_events ORDER BY at, id` — `drift_study_repository.dart:66-72`; the capture log grows without bound (written by two paths, read by export only)
- Evidence
  SQLite auto-indexes primary keys only, never child foreign-key columns. With `PRAGMA foreign_keys = ON` (`app_database.dart:111-116`), every cascade delete — `purgeSubject` (`:193`), `deleteChapter` (`:320`), bin-empty and account `clear` (`:926`) — resolves children by scanning the child table once **per parent row deleted**: O(chapters × lessons) row visits for one subject purge.
- Impact
  Honest quantification: the dataset is small today (the snapshot contract in `study_snapshot.dart:16-19` budgets a few hundred lessons / few thousand exams), so each scan is sub-millisecond and students feel nothing yet. The structural costs grow linearly with history: `exam_entries` and `study_events` never shrink, restore/purge do quadratic-in-practice scans, and `watchSnapshot`'s six full-table streams are fine precisely because nothing else competes — adding indexes now is cheap insurance while every statement touching these columns is still instant.
- Proposed fix
  Add drift `@TableIndex.sql` entries: `chapters(subject_id)`, `lessons(chapter_id)`, `exam_entries(lesson_id, created_at)`, `exam_question_groups(exam_id)`, `homework_entries(lesson_id)`, `daily_tasks(day, sort_order)`, `study_events(at, id)`. Bump `schemaVersion` 5→6 with `m.createIndex` (or `m.createAll`) steps in `onUpgrade` — additive-only, no column touched — plus the migration test Rule 1 requires (`tool/check_invariants.sh` gates exactly this).
- Risk
  Medium-low. The code change is trivial and additive; the risk lives entirely in the upgrade path, which the invariant script and a v5→v6 test cover. Do not ship the index bump without its migration test.

---

## Areas examined and found clean (not re-flagged)

- **Startup** — `main.dart:35-56`: prefs and Firebase init already concurrent; App Check deferred to post-frame; Crashlytics release-only. First-frame readers (locale, cached session) correctly gate `runApp`. Tab branches lazy-load via go_router `StatefulShellRoute`, pinned by boot test (`8ba3387`).
- **Shell** — `app_shell.dart:52-54`: badge uses `.select((q) => q.length)`; the single `BackdropFilter` is clip-bounded, sigma never animated; hidden branches wrapped in `TickerMode(false)`, which also pauses riverpod subscriptions (`summary_providers.dart:69-83`).
- **Database streaming** — `watchSnapshot` coalesces burst writes into one emission per 16 ms window (`drift_study_repository.dart:1084-1102`); snapshot assembly is in-memory with pre-built maps (`study_snapshot.dart:27-37`) — **no N+1 patterns exist** in either repository; tasks ride a separate stream so ticking never rebuilds curriculum screens; notification rescheduling debounced 5 s (`notification_providers.dart:74`).
- **Riverpod** — summary providers are `autoDispose.family` with prior audit fixes applied; analytics' expensive series hoisted into `trajectoriesProvider`; dashboard/review/settings screens watch cached summaries, not raw snapshots per widget.

## Summary table

| ID | Finding | Area | Severity |
|----|---------|------|----------|
| PF1 | Wizard-wide `setState` per keystroke rebuilds the whole exam entry screen | Rebuilds | **P1** |
| PF2 | Per-keystroke `jsonEncode` + SharedPreferences platform-channel write | Rebuilds / I/O | P2 |
| PF3 | Zero indexes on FK/filter columns; cascade deletes and scoped queries scan tables | Database | P2 |

**Counts: P0 = 0 · P1 = 1 · P2 = 2**
