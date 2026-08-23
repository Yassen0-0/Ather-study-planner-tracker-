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
    this.animateOnEnter = false,
  });

  /// 0..1. Callers pass `MasteryPalette.barFraction` so an unexamined item is
  /// an empty track rather than a hairline of colour.
  final double fraction;
  final Color color;
  final double height;

  /// Null means the theme's track colour.
  final Color? trackColor;

  /// Fill from zero on first appearance instead of standing there pre-filled.
  ///
  /// False -- the default, and every caller before the wizard's step 4 --
  /// keeps the old contract: a bar on a summary card or a report is a *fact*,
  /// and facts do not perform. True is for the one position where a bar enters
  /// beside a number still counting it (SP-04أ): starting filled there
  /// contradicts the count above it, and the column and the number measure the
  /// same thing, so they must begin, run, and end together.
  ///
  /// The enter timeline therefore holds [AppMotion.beforeAfterValueDelay] --
  /// the beat on which the wizard's before→after sentence reaches its "after"
  /// and the count starts -- then fills over [AppMotion.value] with
  /// [AppMotion.valueCurve]. Only the first build animates; a later fraction
  /// change tweens from wherever the bar already is, exactly as before. That
  /// asymmetry is why this is opt-in for reveal positions whose value is
  /// settled for the widget's lifetime, not for live-updating bars.
  final bool animateOnEnter;

  /// The synced-enter timeline: the before→after lead-in, then the fill.
  static final Duration _enterTotal =
      AppMotion.beforeAfterValueDelay + AppMotion.value;

  /// The lead-in expressed as an [Interval], so the delay costs no timer and
  /// `pumpAndSettle` settles the whole thing.
  static final Curve _enterCurve = Interval(
    AppMotion.beforeAfterValueDelay.inMicroseconds /
        _enterTotal.inMicroseconds,
    1,
    curve: AppMotion.valueCurve,
  );

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
              // `begin == end` is the deliberate default: on rebuild the
              // builder tweens from the previous end, so the widget stays
              // stateless and a first build has nothing to animate. Opting in
              // breaks the tie only on that first build, from zero.
              tween: Tween<double>(
                begin: animateOnEnter ? 0.0 : fraction,
                end: fraction.clamp(0, 1),
              ),
              duration: reduced
                  ? Duration.zero
                  : (animateOnEnter ? _enterTotal : AppMotion.value),
              curve: animateOnEnter && !reduced
                  ? _enterCurve
                  : AppMotion.valueCurve,
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
