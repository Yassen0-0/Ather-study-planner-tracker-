import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

/// The small pill on the lesson screen: "باقي 21 يوم", "متأخر 16 يوم",
/// "مفيش امتحان".
///
/// Red only ever reaches the text and its 12% wash — never a card border or a
/// card background. A student who is behind on six lessons should not open a
/// screen that is entirely red; the point is to be honest, not punitive.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.overdue = false});

  final String label;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: overdue ? context.colors.wrongChip : context.colors.fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.style(
          size: 12.5,
          weight: AppTypography.bold,
          color: overdue ? context.colors.wrong : context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// The tiny badge on an exam-history row and the "أضعف درس" marker.
class MiniBadge extends StatelessWidget {
  const MiniBadge({super.key, required this.label, this.wrong = false});

  final String label;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: wrong ? context.colors.wrongTint : context.colors.fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          size: 11,
          weight: AppTypography.bold,
          color: wrong ? context.colors.wrong : context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// A filter chip on the progress screen. Selected is a solid black pill;
/// unselected is a white one.
class AtherFilterChip extends StatelessWidget {
  const AtherFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.colors.accent : context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTypography.chipLabel.copyWith(
            color: selected
                ? context.colors.onAccent
                : context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
