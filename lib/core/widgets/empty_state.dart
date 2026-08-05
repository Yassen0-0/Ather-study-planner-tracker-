import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'ather_icons.dart';
import 'pop_in.dart';

/// Shown where there is genuinely nothing yet.
///
/// Two shapes, and the difference matters:
///
/// * [EmptyState] — something is missing and the student can fix it. Text plus
///   the action that resolves it.
/// * [EmptyState.success] — nothing is missing *because the student is on top
///   of it*. Green disc, congratulation, and deliberately **no button**: an
///   empty review queue is a result, not a task.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.body, this.action})
    : _success = false;

  const EmptyState.success({super.key, required this.title, this.body})
    : action = null,
      _success = true;

  final String title;
  final String? body;
  final Widget? action;
  final bool _success;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: _success ? 80 : AppSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_success) ...<Widget>[
            // The queue reaching empty is a real achievement, and it arrived
            // with no acknowledgement at all. It gets a tick's pop -- the same
            // 220ms as a completed day, and nowhere near the celebration.
            const PopIn(
              duration: AppMotion.tick,
              child: CheckDisc(size: 64, checkSize: 30),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.style(size: 18, weight: AppTypography.bold),
          ),
          if (body != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: context.text.secondary.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            action!,
          ],
        ],
      ),
    );
  }
}
