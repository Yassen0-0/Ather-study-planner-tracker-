import 'package:flutter/material.dart';

import '../l10n/formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'ather_icons.dart';
import 'reduced_motion.dart';

/// The app's single emotional payoff: a chapter proved finished.
///
/// The previous version fired 120 hand-simulated confetti particles over a
/// black screen. That is gone. What replaced it is a full white screen, one
/// green disc that pops once, and the number the student earned — quieter, and
/// it makes the moment about the score rather than the animation.
///
/// It only ever appears when `canMasterChapter` is true. A celebration that was
/// not earned devalues every later one.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.body,
    required this.percentage,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final double percentage;
  final VoidCallback onDismiss;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.celebration,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reduced motion gets the finished state immediately, not a slower
      // version of the same movement.
      if (prefersReducedMotion(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.celebrationCurve,
    );

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: context.colors.card,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(pop),
                child: FadeTransition(
                  opacity: _controller,
                  child: const CheckDisc(
                    size: 112,
                    checkSize: 54,
                    strokeWidth: 2.8,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(widget.title, style: AppTypography.stepTitle),
              const SizedBox(height: AppSpacing.xl),
              Text(
                widget.body,
                style: AppTypography.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                percent(widget.percentage),
                style: AppTypography.celebrationNumber.copyWith(
                  color: context.colors.rightText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
