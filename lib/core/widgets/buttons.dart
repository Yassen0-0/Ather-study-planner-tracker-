import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

/// What a full-width primary button means, not what colour it is.
enum PrimaryButtonTone {
  /// The normal action.
  black,

  /// A review exam — the action that clears decay.
  wrong,

  /// "أتقنت الباب" when it has been earned.
  right,

  /// Not earned yet. Grey, **but still tappable**: it opens the sheet that
  /// explains why. A disabled button that does nothing when tapped teaches the
  /// student nothing.
  unearned,

  /// White on grey — a secondary action of equal size.
  secondary,
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = PrimaryButtonTone.black,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final PrimaryButtonTone tone;
  final Widget? leading;

  Color _background(AppColors c) => switch (tone) {
    PrimaryButtonTone.black => c.actionPrimary,
    PrimaryButtonTone.wrong => c.wrong,
    PrimaryButtonTone.right => c.right,
    PrimaryButtonTone.unearned => c.actionDisabled,
    PrimaryButtonTone.secondary => c.card,
  };

  Color _foreground(AppColors c) => switch (tone) {
    PrimaryButtonTone.unearned => c.textSecondary,
    PrimaryButtonTone.secondary => c.textPrimary,
    // The red and green fills do not change between themes, so their label
    // cannot either -- onPrimary would flip it to black on red in the dark.
    PrimaryButtonTone.wrong || PrimaryButtonTone.right => c.onState,
    PrimaryButtonTone.black => c.onPrimary,
  };

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: AppSizes.primaryButton,
        decoration: BoxDecoration(
          color: _background(c),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.button.copyWith(color: _foreground(c)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small black "امتحن" pill that sits at the end of a row.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: context.colors.actionPrimary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: context.text.pillLabel),
      ),
    );
  }
}

/// A white pill on a muted card — used by "سجل درجة واجب".
class QuietPillButton extends StatelessWidget {
  const QuietPillButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTypography.style(size: 13.5, weight: AppTypography.bold),
        ),
      ),
    );
  }
}

/// "+ إضافة باب" / "+ إضافة درس" — a dashed outline rather than a filled
/// button, so adding structure never competes with recording evidence.
class DashedAddButton extends StatelessWidget {
  const DashedAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.radius = AppRadius.card,
    this.padding = 15,
  });

  final String label;
  final VoidCallback onTap;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          radius: radius,
          color: context.colors.dashedBorder,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.style(
              size: 15,
              weight: AppTypography.semiBold,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.radius, required this.color});

  final double radius;

  /// Passed in rather than read from a constant: a painter has no context, so
  /// the theme has to be resolved by the widget that mounts it.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );

    // Walked with a PathMetric rather than drawn as a solid stroke: Flutter has
    // no dashed border, and faking one with a repeated container leaks at the
    // rounded corners.
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.radius != radius || old.color != color;
}

/// The 36x36 white circle used for back, settings and edit in a header.
class CircleHeaderButton extends StatelessWidget {
  const CircleHeaderButton({
    super.key,
    required this.child,
    required this.onTap,
    this.background,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Null means the card colour for the current theme. It cannot default to a
  /// constant any more, because "the card colour" is now two colours.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: AppSizes.headerButton,
        height: AppSizes.headerButton,
        decoration: BoxDecoration(
          color: background ?? context.colors.card,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
