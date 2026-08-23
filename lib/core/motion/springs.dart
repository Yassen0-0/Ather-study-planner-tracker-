import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../widgets/reduced_motion.dart';

/// The spring register — the physics layer beside [AppMotion], not instead of
/// it (animation/06_motion_specs.md SP-01).
///
/// §3.21 capped durations at 300ms and allowed overshoot only on
/// `pressCurve`/`celebrationCurve`. This register deliberately reopens both,
/// because the "alive" feel the owner asked for does not come from Cubic
/// curves at all — it comes from interruptible springs that carry velocity.
/// That collision was declared in the specs, costed, and adopted.
///
/// **Four entries, no fifth.** A motion that fits none of these is a design
/// discussion, not a new constant:
///
/// | name        | feel                          | used for                     |
/// |-------------|-------------------------------|------------------------------|
/// | [crisp]     | lands dead, no bounce         | presses, dips, quiet returns |
/// | [select]    | one clean visible rebound     | tab picks, releases          |
/// | [settle]    | heavy, barely overshoots      | sheets, panels, indicators   |
/// | [celebrate] | big warm overshoot            | rare signature moments       |
///
/// SP-01's table adds a fifth row, `fling(spring, from, to, v)` — not a fifth
/// spring but a member that *receives* a velocity, for drag releases. It is
/// realised as [SpringController.springWithVelocity] rather than as a register
/// constant: the four descriptions above are the feels; the fling is how a
/// gesture hands its momentum to any of them.
///
/// Durations below are *perceptual* settling times, not parameters — a spring
/// has stiffness and damping, and the stiffnesses here are solved from the
/// 2% settling time `t ≈ 4/(ζω)` so the register keeps the numbers the specs
/// promised.
abstract final class Springs {
  /// ζ = 1 · settles ≈ 160ms. The press-down: immediate, dead landing.
  static final SpringDescription crisp = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 625,
    ratio: 1,
  );

  /// ζ ≈ 0.70 · settles ≈ 300ms, overshoot ≈ 4.6%. The Telegram pick.
  static final SpringDescription select = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 361,
    ratio: 0.70,
  );

  /// The spec's own numbers: stiffness 220, damping ratio 0.81. Panels,
  /// sheets, sliding indicators — weight without playfulness.
  static final SpringDescription settle = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 220,
    ratio: 0.81,
  );

  /// ζ ≈ 0.45 · settles ≈ 450ms, overshoot ≈ 20% of the gap travelled.
  /// Signature moments only — the exam-result reveal, the emptied queue.
  /// If everything celebrates, nothing does.
  static final SpringDescription celebrate = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 390,
    ratio: 0.45,
  );
}

/// A single scalar driven by physics, interruptible from value *and* velocity.
///
/// Wraps an unbounded controller: re-aiming mid-flight starts a new
/// [SpringSimulation] seeded with the current position and the current
/// velocity ([AnimationController.velocity]), so a second tap never snaps,
/// reverses or restarts — it redirects, which is the entire point of springs
/// over tweens.
///
/// Reduce-motion is enforced here, once, at every call site: [jump] is what
/// `springTo` becomes when the platform asks for less motion. Callers do not
/// need their own guard unless they also skip building a transform outright.
class SpringController {
  SpringController({required TickerProvider vsync, double initial = 0})
      : _c = AnimationController.unbounded(vsync: vsync, value: initial);

  final AnimationController _c;

  double get value => _c.value;
  bool get isAnimating => _c.isAnimating;

  /// Live velocity, for callers reasoning about interrupts.
  double get velocity => _c.velocity;

  /// The driven value as a listenable, for callers building their own visuals
  /// (the kit's own [SpringScale] listens through the same channel).
  Animation<double> get view => _c;

  /// Aim at [target] on [spring], carrying whatever velocity is already there.
  ///
  /// Safe to call every frame or every tap: each call replaces the running
  /// simulation without losing momentum.
  void springTo(double target, {SpringDescription? spring}) {
    _c.animateWith(
      SpringSimulation(spring ?? Springs.settle, _c.value, target, _c.velocity),
    );
  }

  /// Aim at [target] seeded with an EXTERNAL velocity (px/s), e.g. the
  /// finger's release speed. Unlike [springTo], which carries whatever the
  /// controller itself is doing, this is how gestures hand their momentum in.
  void springWithVelocity(
    double target, {
    required double velocity,
    SpringDescription? spring,
  }) {
    _c.animateWith(
      SpringSimulation(spring ?? Springs.settle, _c.value, target, velocity),
    );
  }

  /// Land instantly. The reduce-motion path, and the way to seed a position
  /// that must not animate on mount.
  void jump(double value) {
    _c.stop();
    _c.value = value;
  }

  void dispose() => _c.dispose();
}

/// Scale about the centre, following [target] on [spring].
///
/// The common shape of the register's users — a press, a release, a pick —
/// so the boilerplate lives once. Mounting never animates: the first frame
/// sits exactly on [target]. Under reduce-motion every change jumps.
///
/// Every spring terminates (the simulations report `isDone` at rest), so
/// `pumpAndSettle` always returns — a standing requirement of this codebase's
/// tests.
class SpringScale extends StatefulWidget {
  const SpringScale({
    super.key,
    required this.child,
    required this.target,
    this.spring,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double target;

  /// Null means [Springs.settle] — the register's resting choice.
  final SpringDescription? spring;
  final Alignment alignment;

  @override
  State<SpringScale> createState() => _SpringScaleState();
}

class _SpringScaleState extends State<SpringScale>
    with SingleTickerProviderStateMixin {
  late final SpringController _spring;
  bool _wasReduced = false;

  @override
  void initState() {
    super.initState();
    _spring = SpringController(vsync: this, initial: widget.target);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion can flip mid-flight (the OS setting is live). A target
    // change would catch it, but a setting flip alone never rebuilds the
    // spring — so the flag is watched here and a running spring lands now.
    final reduced = prefersReducedMotion(context);
    if (_wasReduced && !reduced) {
      // Re-enablement lands nothing today, but the flip itself must be
      // recorded: leave the flag stale and the next reduce believes it, skips
      // the emergency landing below, and a flying spring never comes home.
      _wasReduced = reduced;
      return;
    }
    if (reduced && !_wasReduced && _spring.isAnimating) {
      _spring.jump(widget.target);
    }
    _wasReduced = reduced;
  }

  @override
  void didUpdateWidget(SpringScale old) {
    super.didUpdateWidget(old);
    if (widget.target == old.target) return;
    if (prefersReducedMotion(context)) {
      _spring.jump(widget.target);
      return;
    }
    _spring.springTo(widget.target, spring: widget.spring);
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spring.view,
      builder: (context, child) => Transform.scale(
        scale: _spring.value,
        alignment: widget.alignment,
        child: child,
      ),
      // The subtree does not change while the scale moves; build it once.
      child: widget.child,
    );
  }
}
