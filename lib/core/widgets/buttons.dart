// Material, for exactly one widget: the ring inside a busy [PrimaryButton].
// Nothing else here is a Material control.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

/// What a full-width primary button means, not what colour it is.
enum PrimaryButtonTone {
  /// The normal action. Named for what it means, not what colour it is — it
  /// was black before the visual refresh and is the brand accent now, and no
  /// call site had to change for that.
  primary,

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
    this.tone = PrimaryButtonTone.primary,
    this.leading,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final PrimaryButtonTone tone;
  final Widget? leading;

  /// A write is in flight: the label is replaced by a ring and the button stops
  /// taking taps.
  ///
  /// The app had no loading state anywhere, which mattered most on the two slow
  /// paths — saving an exam and restoring a cloud backup — where a student with
  /// nothing to look at taps again. The ring is deliberately the only spinner in
  /// the app and it never appears on a read: everything else in Ather reads
  /// local SQLite and has nothing to wait for.
  final bool busy;

  Color _background(AppColors c) => switch (tone) {
    PrimaryButtonTone.primary => c.accent,
    PrimaryButtonTone.wrong => c.wrong,
    PrimaryButtonTone.right => c.right,
    PrimaryButtonTone.unearned => c.actionDisabled,
    PrimaryButtonTone.secondary => c.card,
  };

  Color _foreground(AppColors c) => switch (tone) {
    PrimaryButtonTone.unearned => c.textSecondary,
    PrimaryButtonTone.secondary => c.textPrimary,
    // The red and green fills do not change between themes, so their label
    // cannot either -- onAccent would flip it to black on red in the dark.
    PrimaryButtonTone.wrong || PrimaryButtonTone.right => c.onState,
    PrimaryButtonTone.primary => c.onAccent,
  };

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color foreground = _foreground(c);

    return Semantics(
      button: true,
      enabled: onTap != null && !busy,
      label: label,
      child: ExcludeSemantics(
        child: Pressable(
          onTap: busy ? null : onTap,
          child: Container(
            height: AppSizes.primaryButton,
            decoration: BoxDecoration(
              color: _background(c),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            alignment: Alignment.center,
            child: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: foreground,
                    ),
                  )
                : Row(
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
                          style: context.text.button.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The small accent "امتحن" pill that sits at the end of a row.
///
/// One of exactly two ways into the exam sheet, now that the "+" is gone — the
/// other being the lesson screen's CTA. Both start from a row that already
/// knows which lesson is meant.
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
          color: context.colors.accent,
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
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: AppTypography.chipLabel),
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
            style: AppTypography.listTitle.copyWith(
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
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Null means the card colour for the current theme. It cannot default to a
  /// constant any more, because "the card colour" is now two colours.
  final Color? background;

  /// What this button does. Its content is always a bare `AtherIcon`, which is
  /// a `CustomPaint` and carries no accessible name of its own — so back,
  /// settings, edit and the wizard's × were all announced identically, as
  /// nothing.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      // Drawn at 36; hit at 48. The circle does not move or grow.
      minTarget: kMinTarget,
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
