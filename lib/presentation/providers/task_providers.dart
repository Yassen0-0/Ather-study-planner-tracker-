import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_task_repository.dart';
import '../../domain/entities/daily_task.dart';
import '../../domain/repositories/task_repository.dart';
import 'app_providers.dart';

/// Tasks are wired on their own stream, beside the study snapshot rather than
/// inside it. See [TaskRepository] for why, and PROJECT.md §3.22.

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => DriftTaskRepository(ref.watch(databaseProvider)),
);

/// Every task, ordered by day then by the student's own arrangement.
final tasksProvider = StreamProvider<List<DailyTask>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

/// The same list without the async wrapper. Falls back to empty rather than
/// throwing, so a transient loading frame cannot crash the screen.
final tasksValueProvider = Provider<List<DailyTask>>(
  (ref) => ref.watch(tasksProvider).value ?? const <DailyTask>[],
);

/// Which day the tasks screen is showing.
///
/// Seeded with `read`, never `watch`: [nowValueProvider] re-emits every minute,
/// and watching it here would drag the student back to today sixty times an
/// hour while they were looking at another day.
class SelectedTaskDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dayOf(ref.read(clockProvider).now());

  void select(DateTime day) => state = dayOf(day);
}

final selectedTaskDayProvider =
    NotifierProvider<SelectedTaskDayNotifier, DateTime>(
      SelectedTaskDayNotifier.new,
    );

/// The selected day's tasks, in the order the student put them.
final tasksForSelectedDayProvider = Provider<List<DailyTask>>((ref) {
  final day = ref.watch(selectedTaskDayProvider);
  return <DailyTask>[
    for (final task in ref.watch(tasksValueProvider))
      if (task.day == day) task,
  ];
});

/// Days on which the student finished everything they set themselves — what
/// fills a circle in the week strip **on the tasks screen only**.
///
/// A day with no tasks at all is not complete: an empty day is not an
/// achievement, and filling its circle would be the app congratulating a
/// student for writing nothing down.
final taskCompleteDaysProvider = Provider<Set<DateTime>>((ref) {
  final byDay = <DateTime, bool>{};
  for (final task in ref.watch(tasksValueProvider)) {
    byDay[task.day] = (byDay[task.day] ?? true) && task.done;
  }
  return <DateTime>{
    for (final entry in byDay.entries)
      if (entry.value) entry.key,
  };
});
