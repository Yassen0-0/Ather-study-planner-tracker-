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
  Future<int> addTask({required DateTime day, required String title}) {
    final normalised = dayOf(day);

    // The read and the insert are one transaction: two adds racing on the same
    // day would otherwise both read the same max and land on top of each other.
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.dailyTasks)
                ..where((t) => t.day.equals(normalised)))
              .get();

      var next = 0;
      for (final row in existing) {
        if (row.sortOrder >= next) next = row.sortOrder + 1;
      }

      return _db
          .into(_db.dailyTasks)
          .insert(
            DailyTasksCompanion.insert(
              day: normalised,
              title: title.trim(),
              sortOrder: next,
              createdAt: DateTime.now(),
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
    final normalised = dayOf(day);

    return _db.transaction(() async {
      await _db.batch((Batch batch) {
        for (var i = 0; i < orderedIds.length; i++) {
          batch.update(
            _db.dailyTasks,
            DailyTasksCompanion(sortOrder: Value(i)),
            // Scoped by day as well as id: a stale list of ids from another day
            // must not be able to renumber rows the student is not looking at.
            where: (t) =>
                t.id.equals(orderedIds[i]) & t.day.equals(normalised),
          );
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
              day: t.day,
              title: t.title,
              done: Value(t.done),
              sortOrder: t.sortOrder,
              createdAt: t.createdAt,
            ),
        ]);
      });
    });
  }

  DailyTask _toTask(DailyTaskRow r) => DailyTask(
    id: r.id,
    day: r.day,
    title: r.title,
    done: r.done,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
  );
}
