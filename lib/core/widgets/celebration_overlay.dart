import 'package:flutter/material.dart';

import '../haptics/app_haptics.dart';
import '../l10n/formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'animated_percentage.dart';
import 'icon_motion.dart';
import 'list_entrance.dart';
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
///
/// The beat sheet is SP-04ب, and it is retiming only -- nothing new may enter
/// the frame:
///
/// * t=0      title, and the disc's pop ([AppMotion.celebrationCurve]) opens.
/// * t=0–120  a ring floods outward around the disc once ([CompletionDisc]'s
///            celebrateRing) -- the pop's echo.
/// * t=150    the earned percentage counts up from zero over
///            [AppMotion.value]; it finishes at ~750ms.
/// * t=250    the context sentence fades in under the title.
/// * t≈750    [AppHaptics.success], when the count completes.
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
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.celebration,
  );

  /// SP-04ب pins the count to start at 150ms; raw milliseconds because the
  /// spec does.
  static const Duration _countLead = Duration(milliseconds: 150);

  /// The context sentence joins at 250ms, fade-only.
  static const Duration _bodyLead = Duration(milliseconds: 250);

  /// One-shot clock of the count window: the lead-in, then the count itself.
  /// Its completion *is* the haptic moment (~t=750ms) -- this listener is the
  /// one [AppHaptics.success] in this file, and it fires on every path that
  /// completes, including reduce-motion's jump straight to 1 below. Whether
  /// the count is *mounted* is read off the clock's own value in [build] -- a
  /// status listener would be the wrong tool for that: it only ever reports
  /// "completed", which is the end of the count, not its beginning.
  late final AnimationController _countClock = AnimationController(
    vsync: this,
    duration: _countLead + AppMotion.value,
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed) AppHaptics.success();
  });

  /// Where the lead-in hands over to the count, as a fraction of [_countClock].
  static double get _leadFraction =>
      _countLead.inMicroseconds / (_countLead + AppMotion.value).inMicroseconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reduced motion gets the finished state immediately, not a slower
      // version of the same movement. Setting the clock's value to 1 completes
      // it, so its status listener above fires [AppHaptics.success] here --
      // exactly once, same as the animated path. (This branch used to fire it
      // again by hand, and reduce-motion students felt the beat twice.)
      if (prefersReducedMotion(context)) {
        _controller.value = 1;
        _countClock.value = 1;
      } else {
        _controller.forward();
        _countClock.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _countClock.dispose();
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
              // Headroom for the ring flooding outward past the rim, so the
              // celebration never paints outside its own layout.
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.6, end: 1).animate(pop),
                  child: FadeTransition(
                    opacity: _controller,
                    child: CompletionDisc(
                      size: 112,
                      done: true,
                      fill: context.colors.right,
                      ring: context.colors.right,
                      ringWidth: 2,
                      tickSize: 54,
                      tickColor: context.colors.onState,
                      tickStroke: 2.8,
                      celebrateRing: context.colors.right,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // The title at t=0, deliberately unanimated: it names what the
              // eye is already looking at, and naming is not an event.
              Text(widget.title, style: AppTypography.stepTitle),
              const SizedBox(height: AppSpacing.xl),
              // The sentence explains the number, so it waits until the
              // number is on its way before explaining it.
              RiseIn(
                rise: 0,
                delay: _bodyLead,
                duration: AppMotion.micro,
                child: Text(
                  widget.body,
                  style: AppTypography.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AnimatedBuilder(
                animation: _countClock,
                builder: (context, _) => _CountedPercentage(
                  counting: _countClock.value >= _leadFraction,
                  percentage: widget.percentage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The earned percentage, mounted only once its beat arrives (t=150ms).
///
/// Until then the finished figure stands in its place at opacity 0 -- same
/// style, same metrics -- because a Column that suddenly grows a number
/// shoves the title and disc upward mid-celebration. The stand-in is also
/// kept out of semantics: an invisible number announced ahead of the reveal
/// is noise, not information.
class _CountedPercentage extends StatelessWidget {
  const _CountedPercentage({
    required this.counting,
    required this.percentage,
  });

  final bool counting;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    if (!counting) {
      return ExcludeSemantics(
        child: Opacity(
          opacity: 0,
          child: Text(
            percent(percentage),
            style: AppTypography.celebrationNumber.copyWith(
              color: context.colors.rightText,
            ),
          ),
        ),
      );
    }

    // The wizard owns the counted-once flag for its own flow; here the clock
    // above is the completion signal, so onDone has nothing to do.
    return CountUpFromZero(
      value: percentage,
      already: false,
      onDone: () {},
      color: context.colors.rightText,
      style: AppTypography.celebrationNumber,
    );
  }
}
