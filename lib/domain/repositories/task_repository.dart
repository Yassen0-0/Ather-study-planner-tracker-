import '../entities/daily_task.dart';

/// Everything the app can read or change about the student's daily tasks.
///
/// **Why this is a second interface and not six more methods on
/// `StudyRepository`:** that repository serves one [StudySnapshot] stream
/// because every mastery screen is cross-cutting -- the dashboard averages four
/// subjects, Review Center scans every lesson. Tasks are read by exactly one
/// screen and must never be read by a mastery calculation. Widening the snapshot
/// would buy nothing and would quietly seat tasks at the same table as the
/// evidence, which is the one thing this feature must not do.
abstract interface class TaskRepository {
  /// Every task the student has, newest day last, ordered within each day.
  ///
  /// All of them rather than a query per day: a student's whole task history is
  /// a few hundred short rows, and re-subscribing to a new `.watch()` every time
  /// they tap a different day in the week strip costs more than it saves.
  Stream<List<DailyTask>> watchTasks();

  /// Appends to the end of [day]'s list.
  Future<int> addTask({required DateTime day, required String title});

  Future<void> renameTask({required int taskId, required String title});

  Future<void> setTaskDone({required int taskId, required bool done});

  Future<void> deleteTask(int taskId);

  /// Rewrites the whole day's order from [orderedIds].
  ///
  /// Implementations must do it in **one transaction**: a half-applied reorder
  /// leaves two rows claiming the same position, and the list would then settle
  /// somewhere the student did not put it.
  Future<void> reorderTasks({
    required DateTime day,
    required List<int> orderedIds,
  });

  /// Replaces every task with [tasks], in one transaction, keeping ids.
  ///
  /// Separate from `StudyRepository.restore` because tasks are a separate table
  /// with no foreign key into the study data -- the same separation that keeps
  /// them out of mastery. Both are called from the same restore flow.
  Future<void> restoreTasks(List<DailyTask> tasks);
}
