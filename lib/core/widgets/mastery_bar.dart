import 'package:flutter/widgets.dart';

import '../l10n/formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'animated_percentage.dart';
import 'reduced_motion.dart';

/// The horizontal progress bar that replaced the old mastery ring.
///
/// Always laid out left-to-right, in both languages. A bar that filled from the
/// right under RTL would make a 20% score read as 80% at a glance -- the number
/// beside it says otherwise, but the bar is what the eye reads first.
class MasteryBar extends StatelessWidget {
  const MasteryBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = AppSizes.barTrack,
    this.trackColor,
  });

  /// 0..1. Callers pass `MasteryPalette.barFraction` so an unexamined item is
  /// an empty track rather than a hairline of colour.
  final double fraction;
  final Color color;
  final double height;

  /// Null means the theme's track colour.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final reduced = prefersReducedMotion(context);

    return Ltr(
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          height: height,
          color: trackColor ?? context.colors.track,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: fraction, end: fraction.clamp(0, 1)),
              duration: reduced ? Duration.zero : AppMotion.value,
              curve: AppMotion.valueCurve,
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(color: color, borderRadius: radius),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dominant number on a summary card: `87%`.
///
/// This used to compose the number with a grey `/ 100` in a baseline-aligned
/// row, and the comment here defended that as what made a *bare* number read
/// as a score out of a hundred. Then `percentLabel` grew a `%` and nothing came
/// back to this composition, so the card rendered `38% / 100` -- two notations
/// for one number on the largest type on the screen. The `%` won because the
/// rest of the app already speaks it: every subject row, every exam result,
/// every chart label. One notation, and no structure left over from the other.
class MasteryNumber extends StatelessWidget {
  const MasteryNumber({
    super.key,
    required this.value,
    required this.hasData,
    required this.color,
    required this.style,
  });

  /// The raw percentage. Formatting stays inside [AnimatedPercentage] so the
  /// number can count to its new value instead of being handed a finished
  /// string -- the change is the thing worth showing.
  final double value;
  final bool hasData;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Ltr(
      child: AnimatedPercentage(
        value: value,
        hasData: hasData,
        color: color,
        style: style,
      ),
    );
  }
}
