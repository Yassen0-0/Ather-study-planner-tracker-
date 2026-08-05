import 'package:flutter/widgets.dart';

import '../l10n/formatting.dart';
import '../theme/app_spacing.dart';
import 'reduced_motion.dart';

/// Why: this is the moment a student sees their work move a number. Counting
/// the digits is what makes the *change* legible -- a hard swap makes it
/// something they have to remember instead of something they saw.
///
/// Formatting is not reimplemented here: [percentLabel] keeps the Western
/// digits and the LRI/PDI isolates that RTL layout depends on. Tabular figures
/// already prevent width jitter, so nothing beside the number shifts.
class AnimatedPercentage extends StatelessWidget {
  const AnimatedPercentage({
    super.key,
    required this.value,
    required this.hasData,
    required this.color,
    required this.style,
  });

  final double value;
  final bool hasData;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // The colour is applied, never tweened: red/black/green must switch on the
    // frame the value changes. A shade in between is a lie about the score.
    final resolved = style.copyWith(color: color);

    // "—" is not a number and must not be counted to or from.
    if (!hasData) {
      return Text(percentLabel(value, hasData: false), style: resolved);
    }

    return TweenAnimationBuilder<double>(
      // `begin == end` is deliberate, and matches MasteryBar: on rebuild the
      // builder tweens from the *previous* end, so the widget stays stateless
      // and a first build has nothing to animate.
      tween: Tween<double>(begin: value, end: value),
      duration: prefersReducedMotion(context) ? Duration.zero : AppMotion.value,
      curve: AppMotion.valueCurve,
      builder: (context, v, _) =>
          Text(percentLabel(v, hasData: true), style: resolved),
    );
  }
}

/// The wizard result only: counts up from zero, once per flow.
///
/// Separate from [AnimatedPercentage] because everywhere else the interesting
/// thing is the *change* from a previous value; here there is no previous
/// value, and the count from 0 is the reveal. [already] short-circuits it to
/// the final frame, so stepping back to 3 and forward again shows a fact rather
/// than replaying news.
class CountUpFromZero extends StatefulWidget {
  const CountUpFromZero({
    super.key,
    required this.value,
    required this.already,
    required this.onDone,
    required this.color,
    required this.style,
  });

  final double value;
  final bool already;
  final VoidCallback onDone;
  final Color color;
  final TextStyle style;

  @override
  State<CountUpFromZero> createState() => _CountUpFromZeroState();
}

class _CountUpFromZeroState extends State<CountUpFromZero> {
  late final bool _skip = widget.already;

  @override
  void initState() {
    super.initState();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = widget.style.copyWith(color: widget.color);
    final reduced = prefersReducedMotion(context);

    if (_skip || reduced) {
      return Text(percent(widget.value), style: resolved);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.value),
      duration: AppMotion.value,
      curve: AppMotion.valueCurve,
      builder: (context, v, _) => Text(percent(v), style: resolved),
    );
  }
}
