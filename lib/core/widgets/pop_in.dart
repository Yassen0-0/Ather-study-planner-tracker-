import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';
import 'reduced_motion.dart';

/// Why: three things in this app *appear* rather than change -- an overdue
/// badge, a completed day, a ticked step. They all enter identically and none
/// of them overshoots: a badge that bounces reads as a notification begging to
/// be tapped, and this app does not beg.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.duration = AppMotion.pop});

  final Widget child;
  final Duration duration;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    // Started here, not lazily in the field: under reduced motion `build`
    // returns the child untouched and never reads the controller, so a lazy
    // one would first come into existence inside dispose() -- on an element
    // that has already been deactivated.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) return widget.child;

    // 0.6 -> 1, never 0 -> 1: scaling from nothing draws the eye to the motion
    // rather than to the thing that appeared.
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.standard),
      ),
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}

/// The register's biggest pop, spent once: SP-10's emptied queue.
///
/// **Two weights for two moments.** [PopIn] above is the daily weight -- an
/// overdue badge, a completed day, a ticked step: 0.6 -> 1 on
/// [AppMotion.standard], never past 1.0, because something small that bounces
/// reads as a notification begging to be tapped. This widget is the other
/// weight, for the moment a whole list finishes instead of a single item
/// appearing (animation/06_motion_specs.md SP-10): seeded at 0.6 and aimed at
/// 1.0 on a deliberately diluted celebration -- see [_dilutedCelebrate] for
/// the solved numbers. SP-10 pins this pop at ~1.04 peak inside ~320ms; full
/// `Springs.celebrate` (ζ ≈ 0.45) overshoots past that latitude at ≈1.08 over
/// ~450ms. Physics still hands back the overshoot that §3.21 forbids curves
/// but the spring register deliberately reopened for signature moments -- just
/// at the weight the spec asked for. If everything celebrates, nothing does --
/// ordinary completions keep [PopIn].
///
/// The fade rides the same spring -- opacity is the scale's remaining
/// distance home, clamped -- so scale and opacity land together instead of
/// fading on a second clock. Every spring terminates, so `pumpAndSettle`
/// returns; under reduced motion nothing ever ticks and the child is returned
/// untouched and settled, exactly as [PopIn] does.
class SpringPopIn extends StatefulWidget {
  const SpringPopIn({super.key, required this.child});

  final Widget child;

  @override
  State<SpringPopIn> createState() => _SpringPopInState();
}

class _SpringPopInState extends State<SpringPopIn>
    with SingleTickerProviderStateMixin {
  /// Where every pop starts: 0.6 -> 1, never 0 -> 1 -- same rule as [PopIn].
  static const double _from = 0.6;

  /// SP-10's pinned pop, solved locally rather than taken from the register:
  /// SP-01 fixes the register at four entries ("a motion that fits none of
  /// these is a design discussion"), so the spec's "celebrate مخفف" cannot
  /// become a fifth. Same solving algebra as the register itself
  /// (animation/06_motion_specs.md SP-10 pins scale 0.6 -> ~1.04 -> 1 in
  /// ~320ms):
  ///
  /// - ζ = 0.58 damps the overshoot to e^(-ζπ/√(1-ζ²)) ≈ 10.7% of the 0.4
  ///   gap travelled, so the peak lands at 1 + 0.4·0.107 ≈ **1.04**.
  /// - The 2% settling time t ≈ 4/(ζω) then fixes stiffness: ω =
  ///   4/(0.58 · 0.32s) ≈ 21.5 rad/s ⇒ K = mω² ≈ 21.5² ≈ **463**
  ///   (settling checks out at √463: 4/(0.58·21.5) ≈ 320ms).
  static final SpringDescription _dilutedCelebrate =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 463, ratio: 0.58);

  /// Unbounded because the simulation owns the clock; there is no duration to
  /// give a controller (the Springs kit, SP-01). `SpringController` itself is
  /// not observable from outside its library, so the unbounded controller it
  /// wraps is created directly here with the identical pattern.
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this);

  /// Whether the mount decision has been made in [didChangeDependencies].
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    // Seeded here only. Starting the spring waits for didChangeDependencies,
    // where the reduce-motion decision can actually read context -- starting
    // from initState ran the simulation invisibly whenever the platform asked
    // for less motion: build returned the settled child while the ticker
    // burned through the whole flight behind it.
    _controller.value = _from;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion can flip mid-flight (the OS setting is live), same watch
    // as SpringScale: the flag here catches a flip that no other trigger
    // would rebuild.
    final reduced = prefersReducedMotion(context);
    if (!_decided) {
      _decided = true;
      if (reduced) {
        _controller.stop();
        _controller.value = 1;
        return;
      }
      _controller.animateWith(
        SpringSimulation(_dilutedCelebrate, _from, 1, 0),
      );
      return;
    }
    if (reduced && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion is the final state, immediately -- not a slower version.
    if (prefersReducedMotion(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          // The spring's progress home: value runs 0.6 -> ~1.04 -> 1, so the
          // raw ratio would leave the disc slightly translucent forever --
          // clamping keeps the overshoot visible in scale only.
          opacity: ((_controller.value - _from) / (1 - _from)).clamp(0.0, 1.0),
          child: Transform.scale(scale: _controller.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
