import 'package:drift/drift.dart';

import '../../core/clock/clock.dart';
import '../../domain/entities/daily_task.dart';
import '../../domain/entities/study_backup.dart';
import '../../domain/repositories/task_repository.dart';
import '../db/app_database.dart';

/// Drift-backed [TaskRepository].
class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._db, {this._clock = const SystemClock()});

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<List<DailyTask>> watchTasks() {
    final query = _db.select(_db.dailyTasks)
      ..orderBy(<OrderClauseGenerator<$DailyTasksTable>>[
        (t) => OrderingTerm(expression: t.day),
        (t) => OrderingTerm(expression: t.sortOrder),
        // Two rows can share a sortOrder only mid-transaction, but a stable
        // final key means the list can never flicker between rebuilds.
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toTask).toList(growable: false),
    );
  }

  @override
  Future<int> addTask({
    required DateTime day,
    required String title,
    required DateTime at,
  }) {
    final normalised = dayOf(day);
    final target = dayNumber(normalised);
    // A raw `day.equals` would miss rows written before the day key was
    // anchored to UTC -- a legacy local midnight sits an hour off the
    // canonical instant, and the new task would land on top of it. Prefilter
    // a wide window in SQL (cheap; the table is small), then match on the
    // calendar-day number itself.
    final windowStart = normalised.subtract(const Duration(hours: 26));
    final windowEnd = normalised.add(const Duration(hours: 26));

    // The read and the insert are one transaction: two adds racing on the same
    // day would otherwise both read the same max and land on top of each other.
    return _db.transaction(() async {
      final window = await (_db.select(
        _db.dailyTasks,
      )..where((t) => t.day.isBetweenValues(windowStart, windowEnd))).get();

      var next = 0;
      for (final row in window) {
        if (dayNumber(row.day) != target) continue;
        if (row.sortOrder >= next) next = row.sortOrder + 1;
      }

      return _db
          .into(_db.dailyTasks)
          .insert(
            DailyTasksCompanion.insert(
              day: normalised,
              title: title.trim(),
              sortOrder: next,
              createdAt: at,
            ),
          );
    });
  }

  @override
  Future<void> renameTask({required int taskId, required String title}) async {
    await (_db.update(_db.dailyTasks)..where((t) => t.id.equals(taskId))).write(
      DailyTasksCompanion(title: Value(title.trim())),
    );
  }

  @override
  Future<void> setTaskDone({required int taskId, required bool done}) async {
    // One transaction around read, write and event: the tick and its history
    // land together or not at all. A flip on a missing task records nothing.
    await _db.transaction(() async {
      final current =
          await (_db.select(
            _db.dailyTasks,
          )..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (current == null) return;

      // Success and surrender are mutually exclusive: marking done revokes a
      // surrender in the same write, so no interleaving of calls can leave a
      // row claiming both.
      final revokesSurrender = done && current.surrendered;
      if (current.done == done && !revokesSurrender) return;

      await (_db.update(
        _db.dailyTasks,
      )..where((t) => t.id.equals(taskId))).write(
        DailyTasksCompanion(
          done: Value(done),
          surrendered:
              revokesSurrender ? const Value(false) : const Value.absent(),
        ),
      );

      // Transition-only: a no-op flip is not something that happened. Clearing
      // a surrender as a side effect of ticking is part of that same single
      // action and gets no event of its own.
      if (current.done != done) {
        await _db
            .into(_db.studyEvents)
            .insert(
              StudyEventsCompanion.insert(
                type: StudyEvent.typeTaskDone,
                refId: taskId,
                at: _clock.now(),
              ),
            );
      }
    });
  }

  @override
  Future<void> setTaskSurrendered({
    required int taskId,
    required bool surrendered,
  }) async {
    // The mirror of [setTaskDone], down to the transaction shape: surrendering
    // revokes success in the same write rather than leaving one row with two
    // truths about the same day.
    await _db.transaction(() async {
      final current =
          await (_db.select(
            _db.dailyTasks,
          )..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (current == null) return;

      final revokesDone = surrendered && current.done;
      if (current.surrendered == surrendered && !revokesDone) return;

      await (_db.update(
        _db.dailyTasks,
      )..where((t) => t.id.equals(taskId))).write(
        DailyTasksCompanion(
          surrendered: Value(surrendered),
          done: revokesDone ? const Value(false) : const Value.absent(),
        ),
      );

      // Transition-only, same rule as above.
      if (current.surrendered != surrendered) {
        await _db
            .into(_db.studyEvents)
            .insert(
              StudyEventsCompanion.insert(
                type: StudyEvent.typeTaskSurrendered,
                refId: taskId,
                at: _clock.now(),
              ),
            );
      }
    });
  }

  @override
  Future<void> deleteTask(int taskId) async {
    await (_db.delete(_db.dailyTasks)..where((t) => t.id.equals(taskId))).go();
  }

  @override
  Future<void> reorderTasks({
    required DateTime day,
    required List<int> orderedIds,
  }) {
    final target = dayNumber(dayOf(day));

    return _db.transaction(() async {
      // The student's own ids are the authority, but a legacy row written
      // before the day key was UTC-anchored carries a local midnight and sits
      // an hour outside the exact instant. Matching by calendar-day number
      // keeps those rows inside the renumbering instead of tangling around
      // them -- while an id from another day is still refused outright.
      final candidates = await (_db.select(
        _db.dailyTasks,
      )..where((t) => t.id.isIn(orderedIds))).get();
      final sameDay = <int>{
        for (final row in candidates)
          if (dayNumber(dayOfStoredKey(row.day)) == target) row.id,
      };

      await _db.batch((Batch batch) {
        var position = 0;
        for (final id in orderedIds) {
          if (!sameDay.contains(id)) continue;
          batch.update(
            _db.dailyTasks,
            DailyTasksCompanion(sortOrder: Value(position)),
            where: (t) => t.id.equals(id),
          );
          position++;
        }
      });
    });
  }

  @override
  Future<void> restoreTasks(List<DailyTask> tasks) {
    return _db.transaction(() => restoreTasksWithin(tasks));
  }

  /// The body of [restoreTasks] without a transaction of its own, so
  /// `DriftStudyRepository.restoreEverything` can run the study and task
  /// halves of a restore inside **one** transaction (D-02). Statements issued
  /// here while an outer transaction is open on [_db] join it; called
  /// standalone there is no outer transaction and each statement stands
  /// alone -- which is why this is not public API for general use.
  Future<void> restoreTasksWithin(List<DailyTask> tasks) async {
    await _db.delete(_db.dailyTasks).go();
    await _db.batch((Batch batch) {
      batch.insertAll(_db.dailyTasks, <DailyTasksCompanion>[
        for (final t in tasks)
          DailyTasksCompanion.insert(
            id: Value(t.id),
            // The blob was written on another phone, possibly under another
            // UTC offset; its `day` is an instant that only means "that day"
            // where it was written. Re-truncating lands the row on the day
            // the backup meant rather than 23:00 of the evening before. Read by
            // its instant, not its local fields (D5): the parser hands it
            // back local, and west of UTC that is the previous evening.
            day: dayOfStoredKey(t.day),
            title: t.title,
            done: Value(t.done),
            surrendered: Value(t.surrendered),
            sortOrder: t.sortOrder,
            createdAt: t.createdAt,
          ),
      ]);
    });
  }

  @override
  Future<void> clearTasks() => _db.delete(_db.dailyTasks).go();

  DailyTask _toTask(DailyTaskRow r) => DailyTask(
    id: r.id,
    // Normalised on read as well as on write: rows written before the day key
    // was anchored to UTC carry a local midnight, and a row like that read
    // under a different UTC offset comes back at 23:00 or 01:00. Re-truncating
    // here hands every caller -- screens and providers alike -- the canonical
    // form, whatever the column held. `dayOfStoredKey`, not `dayOf`: drift
    // returns the column as a *local* DateTime, and midnight UTC read as local
    // fields west of UTC is the previous day (D5).
    day: dayOfStoredKey(r.day),
    title: r.title,
    done: r.done,
    surrendered: r.surrendered,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
  );
}
