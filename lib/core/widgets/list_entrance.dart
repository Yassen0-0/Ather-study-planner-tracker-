import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';
import 'reduced_motion.dart';

/// Remembers which rows have already made their entrance on this screen.
///
/// **Why this is needed at all.** A row scrolled out of a list is unmounted, and
/// scrolling it back mounts a brand-new [RiseIn] that dutifully plays the
/// entrance again. On a chapter with twenty lessons that turned a scroll into a
/// procession of rows fading and rising past the finger — the exact "look at me"
/// motion the design spends most of its rules avoiding.
///
/// The set lives on the screen, so an entrance plays once per visit: leaving the
/// screen and coming back is a new arrival and animates again, which is right.
class ListEntranceScope extends StatefulWidget {
  const ListEntranceScope({super.key, required this.child});

  final Widget child;

  @override
  State<ListEntranceScope> createState() => _ListEntranceScopeState();
}

class _ListEntranceScopeState extends State<ListEntranceScope> {
  final Set<Object> _entered = <Object>{};

  @override
  Widget build(BuildContext context) =>
      _EnteredRows(entered: _entered, child: widget.child);
}

class _EnteredRows extends InheritedWidget {
  const _EnteredRows({required this.entered, required super.child});

  final Set<Object> entered;

  static Set<Object>? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_EnteredRows>()?.entered;

  // The set is mutated in place and never drives a rebuild -- it is read once,
  // during a row's first build, to decide whether that row animates.
  @override
  bool updateShouldNotify(_EnteredRows old) => false;
}

/// Why: a list that appears all at once reads as a screenshot; one that arrives
/// in order reads as a list. Capped at [AppMotion.staggerCap] because a student
/// with forty lessons must not wait through forty delays.
///
/// One controller, no timers: the delay is an [Interval] on the curve, so
/// `pumpAndSettle` settles it instead of hanging on a pending `Future`.
class ListEntrance extends StatelessWidget {
  const ListEntrance({
    super.key,
    required this.index,
    required this.child,
    this.id,
  });

  final int index;
  final Widget child;

  /// Stable identity for this row — a lesson id, a task id.
  ///
  /// With one, the entrance plays once per screen visit no matter how often the
  /// row is scrolled past. Without one it falls back to the index, which is
  /// still right for lists that never scroll (the dashboard's four subjects) and
  /// is the behaviour every caller had before.
  final Object? id;

  @override
  Widget build(BuildContext context) {
    final entered = _EnteredRows.of(context);
    final key = id ?? index;

    if (entered != null) {
      if (entered.contains(key)) return child;
      entered.add(key);
    }

    return RiseIn(
      delay: AppMotion.stagger * math.min(index, AppMotion.staggerCap),
      rise: AppMotion.enterRise,
      duration: AppMotion.enter,
      child: child,
    );
  }
}

/// The whole entrance vocabulary of this app: fade in, optionally rise, once,
/// on mount. [ListEntrance] is this with an index; the error banner is this
/// with a 6px rise; the wizard's "before" value is this with no rise at all.
///
/// Reuse it. Do not write a third entrance widget.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.rise = AppMotion.microRise,
    this.duration = AppMotion.micro,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// How far the child travels upward before settling. `0` means fade only.
  final double rise;

  /// How long the fade and rise take, *excluding* [delay].
  final Duration duration;

  /// How long the child waits before it starts. Expressed as an [Interval] on
  /// the same controller rather than a timer, so `pumpAndSettle` settles it
  /// instead of hanging on a pending `Future`.
  final Duration delay;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final Duration _delay = widget.delay;
  late final Duration _total = _delay + widget.duration;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMilliseconds / _total.inMilliseconds,
      1,
      curve: AppMotion.standard,
    ),
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
    // Reduced motion is the final state, immediately -- not a slower version.
    if (prefersReducedMotion(context)) return widget.child;

    final faded = FadeTransition(opacity: _t, child: widget.child);
    if (widget.rise == 0) return faded;

    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, widget.rise * (1 - _t.value)),
        child: child,
      ),
      child: faded,
    );
  }
}
