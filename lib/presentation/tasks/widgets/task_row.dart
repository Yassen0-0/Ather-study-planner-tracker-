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
import '../../../domain/entities/daily_task.dart';

/// One task.
///
/// Three targets on one row, and the split is deliberate: tapping the row is the
/// act the student came here for, so it gets the whole card; editing is a
/// pencil, exactly as it is on a chapter or a lesson header; and reordering is a
/// long press, so the row carries no drag handle and stays a piece of
/// information rather than a control panel.
///
/// The done state borrows `AtherCheckbox`'s vocabulary rather than inventing
/// one: the disc fills instantly (a disc that fills gradually reads as a task
/// half-done), the tick pops, and the label tweens quieter. **No strikethrough**
/// — there is none anywhere in this app, and "ticked reads quieter" already
/// carries the meaning.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
  });

  final DailyTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);

    return AtherCard(
      onTap: onToggle,
      child: Row(
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
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: reduced ? Duration.zero : AppMotion.micro,
              curve: AppMotion.standard,
              style: AppTypography.itemLabel.copyWith(
                color: task.done
                    ? context.colors.textSecondary
                    : context.colors.textPrimary,
              ),
              child: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
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
      ),
    );
  }
}
