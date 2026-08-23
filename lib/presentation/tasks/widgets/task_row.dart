import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ather_card.dart';
import '../../../core/widgets/ather_icons.dart';
import '../../../core/widgets/pop_in.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/reduced_motion.dart';
import '../../../core/widgets/task_strike_marks.dart';
import '../../../domain/entities/daily_task.dart';

/// One task.
///
/// Four targets on one row, and the split is deliberate: tapping the row is the
/// act the student came here for, so it gets the whole card; editing is a
/// pencil, exactly as it is on a chapter or a lesson header; surrendering is a
/// small slashed circle beside it, behind its own confirm; and reordering is a
/// long press, so the row carries no drag handle and stays a piece of
/// information rather than a control panel.
///
/// The done state borrows `AtherCheckbox`'s vocabulary rather than inventing
/// one: the disc fills instantly (a disc that fills gradually reads as a task
/// half-done), the tick pops, and the label tweens quieter. Over the label
/// itself the row draws the teacher's pen: a clean straight strike
/// ([StraightStrikePainter]) — line through the words, tick in the disc, one
/// sentence in two marks. It is painted rather than [TextDecoration] because a
/// text decoration cannot overshoot like ink, and because the surrender state
/// below must share its exact geometry.
///
/// The surrendered state is the failure twin: the label scratched out by an
/// irregular red zigzag ([ZigzagScribblePainter]), the whole content dimmed
/// slightly, and the slashed circle turning red. متعرّج عن قصد — التعرّج هو
/// الإحساس بالعصبية والاستسلام الذي لا يحمله خط مستقيم. The repository
/// guarantees done and surrendered never both stand, but the *painter* choice
/// still gives surrender precedence, so no possible input can make this row
/// say "success" about a failure.
///
/// Nothing here animates: the zigzag is seeded per task
/// ([Object.hash]) and drawn whole on its first frame, which is how reduced
/// motion gets the final state immediately — there is no reveal to suppress.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onSurrender,
  });

  final DailyTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  /// Confirms (or un-confirms) surrender at the screen level, where the
  /// destructive-confirm seam lives. The row only renders the state.
  final VoidCallback onSurrender;

  @override
  Widget build(BuildContext context) {
    final L l = L.of(context);

    return AtherCard(
      onTap: onToggle,
      child: task.surrendered
          // The dim is instant, not animated: Opacity rather than
          // AnimatedOpacity keeps a FadeTransition out of this subtree, which
          // reduced-motion tests assert on -- and a state that says "I gave
          // up" has no business sliding in gracefully anyway.
          ? Opacity(opacity: 0.72, child: _row(context, l))
          : _row(context, l),
    );
  }

  Widget _row(BuildContext context, L l) {
    return Row(
      children: <Widget>[
        Container(
          width: AppSizes.checkbox,
          height: AppSizes.checkbox,
          decoration: BoxDecoration(
            color: task.done ? context.colors.accent : context.colors.card,
            shape: BoxShape.circle,
            border: task.done
                ? null
                : Border.all(
                    color: context.colors.checkboxBorder,
                    width: 1.8,
                  ),
          ),
          alignment: Alignment.center,
          child: task.done
              ? PopIn(
                  duration: AppMotion.micro,
                  child: AtherIcon(
                    AtherGlyph.check,
                    size: 14,
                    color: context.colors.onAccent,
                    strokeWidth: 3,
                  ),
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _title(context, l)),
        const SizedBox(width: AppSpacing.xs),
        Pressable(
          onTap: onSurrender,
          semanticLabel:
              task.surrendered ? l.undoSurrender : l.surrenderTask,
          // Same optical weight as the pencil beside it, same minTarget
          // guarantee under the padding.
          minTarget: kMinTarget,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox.square(
              dimension: 20,
              child: CustomPaint(
                painter: SurrenderMarkIconPainter(
                  color: task.surrendered
                      ? context.colors.wrong
                      : context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        Pressable(
          onTap: onEdit,
          semanticLabel: L.of(context).commonEdit,
          // The pencil stays 17px like every other one. The padding used to
          // be the whole story and reached 37px, short of the 48 a finger
          // needs; `minTarget` now guarantees the rest without redrawing it.
          minTarget: kMinTarget,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AtherIcon(
              AtherGlyph.edit,
              size: 17,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// The title, with whatever strike the state earns drawn over it.
  ///
  /// The paint-only rule lives here: the [Text] is wrapped in a [CustomPaint]
  /// whose *foreground* painter draws across the laid-out glyphs. The tree
  /// gains no layout participants — constraints pass through untouched, so a
  /// row striking its title occupies exactly the space it did before.
  Widget _title(BuildContext context, L l) {
    final bool surrendered = task.surrendered;
    final TextStyle style = AppTypography.itemLabel.copyWith(
      color: task.done || surrendered
          ? context.colors.textSecondary
          : context.colors.textPrimary,
    );

    return AnimatedDefaultTextStyle(
      duration: prefersReducedMotion(context) ? Duration.zero : AppMotion.micro,
      curve: AppMotion.standard,
      style: style,
      child: Semantics(
        // The mark is ink, not text: screen readers get the state as words on
        // the node they are already reading, not as a separate stop.
        label: surrendered
            ? l.taskMarkedSurrendered
            : task.done
                ? l.taskCompletedStrike
                : null,
        child: surrendered || task.done
            ? CustomPaint(
                foregroundPainter: surrendered
                    ? ZigzagScribblePainter(
                        text: task.title,
                        style: style,
                        direction: Directionality.of(context),
                        color: context.colors.wrong,
                        seed: Object.hash('surrender', task.id),
                      )
                    : StraightStrikePainter(
                        text: task.title,
                        style: style,
                        direction: Directionality.of(context),
                        color: context.colors.textSecondary,
                      ),
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
