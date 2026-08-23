import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics/app_haptics.dart';
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
import '../../core/widgets/pop_in.dart';
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
/// grammar — which becomes the closing sentence once every task on the
/// selected day is ticked: 4/4 read in the same grey as 0/4 makes a finished
/// day look exactly like an untouched one.
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

  /// Surrender, or take it back. The asymmetry is the design: surrendering
  /// counts the task as a failure, so it passes through the destructive-confirm
  /// seam — whose affirmative answer *is* the commit and fires [AppHaptics.heavy]
  /// exactly once, after the sheet resolves and before the write. Taking it
  /// back is a restoration, not a destruction: no dialog, one light tap on the
  /// wrist. The repository clears `done` in the same transaction, so a task
  /// can never be ticked and surrendered at once.
  Future<void> _setSurrender(
    BuildContext context,
    WidgetRef ref,
    DailyTask task,
  ) async {
    final l = L.of(context);
    final bool target = !task.surrendered;

    if (target) {
      final confirmed = await confirmDestructive(
        context,
        title: l.surrenderConfirmTitle,
        message: l.surrenderConfirmBody,
        confirmLabel: l.surrenderTask,
      );
      if (!confirmed || !context.mounted) return;
    } else {
      AppHaptics.light();
    }

    await runWrite(
      context,
      () => ref
          .read(taskRepositoryProvider)
          .setTaskSurrendered(taskId: task.id, surrendered: target),
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
    // The else branch below guarantees the list is not empty, so 4/4 here
    // really means "the day is finished" and may say so.
    final allDone = done == tasks.length;

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
        _TaskQueueArea(
          day: selected,
          hasTasks: tasks.isNotEmpty,
          listContent: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(
                  left: 2,
                  right: 2,
                  bottom: AppSpacing.md,
                ),
                child: Text(
                  allDone
                      ? l.tasksDayDone(iso(done), iso(tasks.length))
                      : l.tasksDoneOf(iso(done), iso(tasks.length)),
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
                onSurrender: (task) => _setSurrender(context, ref, task),
                onEdit: (task) => _edit(context, ref, task),
                onReorder: (oldIndex, newIndex) =>
                    _reorder(context, ref, tasks, oldIndex, newIndex),
              ),
              DashedAddButton(
                label: l.addTask,
                onTap: () => _add(context, ref),
              ),
            ],
          ),
          clearedTitle: l.tasksQueueClearedTitle,
          clearedBody: l.tasksQueueClearedBody,
          plainEmpty: EmptyState(
            title: l.noTasksYet,
            action: DashedAddButton(
              label: l.addTask,
              onTap: () => _add(context, ref),
            ),
          ),
        ),
      ],
    );
  }
}

/// The queue's body: the rows, or whatever replacing them looks like.
///
/// One keyed [AnimatedSwitcher] owns the whole flip between "rows" and
/// "nothing", which is what makes SP-10 a sequence rather than a cut: when the
/// last row leaves, the outgoing subtree runs [AppMotion.exit] as its fade-out
/// while the incoming one carries its own entrance -- for the just-cleared day
/// that entrance is [SpringPopIn], the register's biggest pop. Only the
/// *leaving* side gets the switcher's fade; the arriving side is passed
/// through untouched so it is never faded by two clocks at once. Every part
/// terminates, so `pumpAndSettle` returns.
///
/// The celebration is earned, not shown: it plays only when this day's own
/// rows cross to zero under the student's hand. Landing on an already-empty
/// day from the picker is not a victory and stays the plain [EmptyState] --
/// something is missing there and the add button fixes it, which is exactly
/// the difference `empty_state.dart` documents between its two shapes.
class _TaskQueueArea extends StatefulWidget {
  const _TaskQueueArea({
    required this.day,
    required this.hasTasks,
    required this.listContent,
    required this.clearedTitle,
    required this.clearedBody,
    required this.plainEmpty,
  });

  final DateTime day;
  final bool hasTasks;
  final Widget listContent;
  final String clearedTitle;
  final String clearedBody;
  final Widget plainEmpty;

  @override
  State<_TaskQueueArea> createState() => _TaskQueueAreaState();
}

class _TaskQueueAreaState extends State<_TaskQueueArea> {
  /// Whether the just-cleared state was reached by the last row leaving.
  bool _clearedByFinishing = false;

  @override
  void didUpdateWidget(_TaskQueueArea old) {
    super.didUpdateWidget(old);
    if (widget.day != old.day) {
      // Another day is on screen; whatever happened to the old one, the new
      // one starts quiet even if it too is empty.
      _clearedByFinishing = false;
    } else if (old.hasTasks && !widget.hasTasks) {
      // The last row just left THIS day: SP-10's moment.
      _clearedByFinishing = true;
      // Fired once per crossing, at entry start. Vibration is not visual
      // motion, so reduce-motion does not suppress it (PH-04 appendix) -- and
      // among the app's list screens, only this moment earns success().
      AppHaptics.success();
    } else if (widget.hasTasks) {
      _clearedByFinishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    final Key contentKey;

    if (widget.hasTasks) {
      contentKey = const ValueKey<String>('queue');
      content = widget.listContent;
    } else if (_clearedByFinishing) {
      contentKey = const ValueKey<String>('cleared');
      content = SpringPopIn(
        child: EmptyState.success(
          title: widget.clearedTitle,
          body: widget.clearedBody,
        ),
      );
    } else {
      contentKey = const ValueKey<String>('empty');
      content = widget.plainEmpty;
    }

    return AnimatedSwitcher(
      // Reduced motion swaps in place: the arrival is already settled, so a
      // 200ms curtain over it would be motion for its own sake.
      duration:
          prefersReducedMotion(context) ? Duration.zero : AppMotion.exit,
      child: KeyedSubtree(key: contentKey, child: content),
      transitionBuilder: (child, animation) => child.key == contentKey
          ? child
          : FadeTransition(opacity: animation, child: child),
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
    required this.onSurrender,
    required this.onEdit,
    required this.onReorder,
  });

  final List<DailyTask> tasks;
  final ValueChanged<DailyTask> onToggle;
  final ValueChanged<DailyTask> onSurrender;
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
                     scale: 1 +
                         0.02 * AppMotion.standard.transform(animation.value),
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
            onSurrender: () => onSurrender(tasks[i]),
            onEdit: () => onEdit(tasks[i]),
          ),
        ),
      ),
    );
  }
}
