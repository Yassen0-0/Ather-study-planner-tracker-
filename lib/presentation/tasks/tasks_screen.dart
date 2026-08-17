import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/day_header.dart';
import '../../core/widgets/day_picker.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_entrance.dart';
import '../../core/widgets/reduced_motion.dart';
import '../../domain/entities/daily_task.dart';
import '../common/prompts.dart';
import '../common/settings_button.dart';
import '../common/write_guard.dart';
import '../providers/app_providers.dart';
import '../providers/task_providers.dart';
import 'widgets/task_row.dart';

/// The student's own plan for one day.
///
/// **This screen measures nothing.** Mastery comes exclusively from recorded
/// exams (PROJECT.md §1), so there is deliberately no percentage and no
/// [MasteryBar] anywhere here — a progress bar under a task list would say the
/// app scores you on your to-do list, which is the opposite of what the product
/// claims. The only figure is a plain count in the app's existing "X من Y"
/// grammar.
///
/// The [DayPicker] on top is the only date control in the app: the dashboard's
/// copy of the old seven-day strip is gone, and a dot under a day here means
/// "everything you set yourself that day is done".
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final day = ref.read(selectedTaskDayProvider);
    final title = await showNamePrompt(
      context,
      title: l.addTaskTitle,
      hint: l.taskNameHint,
    );
    if (title == null || !context.mounted) return;
    // No success toast. The toast is the acknowledgement for recording evidence,
    // and spending it on "task added" is how it stops meaning anything. A
    // *failure* still speaks: a row that never appears with no explanation reads
    // as a broken app.
    await runWrite(
      context,
      () => ref
          .read(taskRepositoryProvider)
          .addTask(day: day, title: title, at: ref.read(clockProvider).now()),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    DailyTask task,
  ) async {
    final l = L.of(context);
    await showEditSheet(
      context,
      title: task.title,
      renameLabel: l.renameTask,
      deleteLabel: l.deleteTask,
      onRename: () async {
        final title = await showNamePrompt(
          context,
          title: l.renameTask,
          hint: l.taskNameHint,
          initialValue: task.title,
        );
        if (title == null || !context.mounted) return;
        await runWrite(
          context,
          () => ref
              .read(taskRepositoryProvider)
              .renameTask(taskId: task.id, title: title),
        );
      },
      onDelete: () async {
        final confirmed = await confirmDestructive(
          context,
          title: l.deleteTask,
          message: l.deleteTaskConfirm,
        );
        if (!confirmed || !context.mounted) return;
        await runWrite(
          context,
          () => ref.read(taskRepositoryProvider).deleteTask(task.id),
        );
      },
    );
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    List<DailyTask> tasks,
    int oldIndex,
    int newIndex,
  ) {
    // `onReorderItem` (not the deprecated `onReorder`) already accounts for the
    // dragged row having left the list, so newIndex is the slot it lands in.
    final ids = <int>[for (final task in tasks) task.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));

    return runWrite(
      context,
      () => ref
          .read(taskRepositoryProvider)
          .reorderTasks(
            day: ref.read(selectedTaskDayProvider),
            orderedIds: ids,
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final now = ref.watch(nowValueProvider);
    final selected = ref.watch(selectedTaskDayProvider);
    final tasks = ref.watch(tasksForSelectedDayProvider);
    final completeDays = ref.watch(taskCompleteDaysProvider);

    final done = tasks.where((t) => t.done).length;
    final isToday = selected == dayOf(now);

    return AtherScreen(
      header: DayHeader(
        // The title says which day is on screen. "مهام اليوم" would be a lie
        // the moment the student taps Thursday.
        title: isToday ? l.tasksTitle : dateLabel(selected),
        actions: const <Widget>[SettingsButton()],
        picker: DayPicker(
          today: dayOf(now),
          selectedDay: selected,
          completeDays: completeDays,
          onSelect: (day) =>
              ref.read(selectedTaskDayProvider.notifier).select(day),
        ),
      ),
      children: <Widget>[
        if (tasks.isEmpty)
          EmptyState(
            title: l.noTasksYet,
            action: DashedAddButton(
              label: l.addTask,
              onTap: () => _add(context, ref),
            ),
          )
        else ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: 2,
              right: 2,
              bottom: AppSpacing.md,
            ),
            child: Text(
              l.tasksDoneOf(iso(done), iso(tasks.length)),
              style: context.text.secondaryStrong,
            ),
          ),
          _TaskList(
            tasks: tasks,
            onToggle: (task) => runWrite(
              context,
              () => ref
                  .read(taskRepositoryProvider)
                  .setTaskDone(taskId: task.id, done: !task.done),
            ),
            onEdit: (task) => _edit(context, ref, task),
            onReorder: (oldIndex, newIndex) =>
                _reorder(context, ref, tasks, oldIndex, newIndex),
          ),
          DashedAddButton(label: l.addTask, onTap: () => _add(context, ref)),
        ],
      ],
    );
  }
}

/// The reorderable list.
///
/// Not [CollapsingList]: a list cannot be both reorderable and collapsing, and
/// the drag is the feature the student asked for. The cost is that a deleted
/// task disappears rather than collapsing (PROJECT.md §3.20) — acceptable here
/// because the delete happens in a sheet over this very screen, so the row's
/// departure is already explained.
class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onReorder,
  });

  final List<DailyTask> tasks;
  final ValueChanged<DailyTask> onToggle;
  final ValueChanged<DailyTask> onEdit;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);

    return ReorderableListView.builder(
      // One child of the screen's own ListView; it must not scroll itself.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tasks.length,
      onReorderItem: onReorder,
      // Long-press to drag on touch platforms, which is what
      // buildDefaultDragHandles gives us. No visible handle: the row stays a
      // piece of information rather than a control panel.
      buildDefaultDragHandles: true,
      proxyDecorator: (child, index, animation) {
        // Material lifts the dragged row on an elevation. This app has no
        // shadows at all (PROJECT.md §3.10), so the default has to be replaced
        // rather than merely tuned -- a transparent Material at zero elevation,
        // and a scale small enough to read as "picked up" without becoming a
        // second animation vocabulary.
        return Material(
          type: MaterialType.transparency,
          child: reduced
              ? child
              : AnimatedBuilder(
                  animation: animation,
                  builder: (context, inner) => Transform.scale(
                    scale: 1 + 0.02 * Curves.easeOut.transform(animation.value),
                    child: inner,
                  ),
                  child: child,
                ),
        );
      },
      itemBuilder: (context, i) => Padding(
        key: ValueKey<int>(tasks[i].id),
        padding: const EdgeInsets.only(bottom: AppSpacing.listGap),
        child: ListEntrance(
          index: i,
          id: tasks[i].id,
          child: TaskRow(
            task: tasks[i],
            onToggle: () => onToggle(tasks[i]),
            onEdit: () => onEdit(tasks[i]),
          ),
        ),
      ),
    );
  }
}
