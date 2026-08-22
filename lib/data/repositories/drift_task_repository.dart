import 'package:drift/drift.dart';

import '../../domain/entities/daily_task.dart';
import '../../domain/repositories/task_repository.dart';
import '../db/app_database.dart';

/// Drift-backed [TaskRepository].
class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._db);

  final AppDatabase _db;

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
    await (_db.update(_db.dailyTasks)..where((t) => t.id.equals(taskId))).write(
      DailyTasksCompanion(done: Value(done)),
    );
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
          if (dayNumber(dayOf(row.day)) == target) row.id,
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
    return _db.transaction(() async {
      await _db.delete(_db.dailyTasks).go();
      await _db.batch((Batch batch) {
        batch.insertAll(_db.dailyTasks, <DailyTasksCompanion>[
          for (final t in tasks)
            DailyTasksCompanion.insert(
              id: Value(t.id),
              // The blob was written on another phone, possibly under another
              // UTC offset; its `day` is an instant that only means "that day"
              // where it was written. Re-truncating lands the row on the day
              // the backup meant rather than 23:00 of the evening before.
              day: dayOf(t.day),
              title: t.title,
              done: Value(t.done),
              sortOrder: t.sortOrder,
              createdAt: t.createdAt,
            ),
        ]);
      });
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
    // form, whatever the column held.
    day: dayOf(r.day),
    title: r.title,
    done: r.done,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
  );
}
