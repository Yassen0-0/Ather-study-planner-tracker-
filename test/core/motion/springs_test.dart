import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/core/motion/springs.dart';

/// The spring kit's own unit tests — the register, the simulations it builds,
/// the [SpringController] that drives them, and the [SpringScale] wrapper.
///
/// These sit beside `test/widget/motion_test.dart`, which proves consumers
/// finish; this file proves the physics underneath them behaves: overshoots
/// land in the bands the register promises, every spring terminates, and
/// interrupting never restarts — it redirects.
///
/// Trajectories are read straight off `SpringSimulation.x/dx`, which is the
/// closed-form solution, so dense sampling measures the real path rather than
/// integration error; a 2ms grid resolves every peak far inside the asserted
/// bands.
void main() {
  group('Springs', () {
    test('every entry is critically valid: mass, stiffness, ratio in range',
        () {
      for (final (name, spring) in <(String, SpringDescription)>[
        ('crisp', Springs.crisp),
        ('select', Springs.select),
        ('settle', Springs.settle),
        ('celebrate', Springs.celebrate),
      ]) {
        expect(spring.mass, greaterThan(0), reason: '$name.mass');
        expect(spring.stiffness, greaterThan(0), reason: '$name.stiffness');
        expect(spring.damping, greaterThan(0), reason: '$name.damping');

        // Recovered from the getters: c = ratio · 2√(mk), so invert it.
        final ratio =
            spring.damping / (2 * math.sqrt(spring.mass * spring.stiffness));
        expect(ratio, greaterThan(0), reason: '$name damping ratio');
        expect(ratio, lessThanOrEqualTo(1), reason: '$name damping ratio');
      }
    });

    test('damping ratios and stiffnesses match the documented register', () {
      // The doc pins both: zeta defines the feel, stiffness was solved from
      // the promised settling times. Pinning them here makes a silent retune
      // a failed test instead of a changed app.
      for (final (name, spring, zeta, stiffness)
          in <(String, SpringDescription, double, int)>[
        ('crisp', Springs.crisp, 1.0, 625),
        ('select', Springs.select, 0.70, 361),
        ('settle', Springs.settle, 0.81, 220),
        ('celebrate', Springs.celebrate, 0.45, 390),
      ]) {
        final ratio =
            spring.damping / (2 * math.sqrt(spring.mass * spring.stiffness));
        expect(ratio, closeTo(zeta, 0.005), reason: '$name damping ratio');
        expect(spring.stiffness, closeTo(stiffness.toDouble(), 0.5),
            reason: '$name stiffness');
      }
    });
  });

  group('SpringSimulation', () {
    /// Flies 0 -> 1 from rest on [spring], sampling every 2ms over a 3s
    /// horizon. Overshoot fractions below are of the unit gap.
    ({double peak, double endX, double endV, Duration? doneAt}) fly(
      SpringDescription spring,
    ) {
      final sim = SpringSimulation(spring, 0, 1, 0);
      const horizon = Duration(seconds: 3);
      var peak = 0.0;
      Duration? doneAt;
      for (var t = Duration.zero;
          t <= horizon;
          t += const Duration(milliseconds: 2)) {
        final s = t.inMicroseconds / Duration.microsecondsPerSecond;
        peak = math.max(peak, sim.x(s));
        doneAt ??= sim.isDone(s) ? t : null;
      }
      final s = horizon.inMicroseconds / Duration.microsecondsPerSecond;
      return (peak: peak, endX: sim.x(s), endV: sim.dx(s), doneAt: doneAt);
    }

    void expectLandsOnTarget(
      ({double peak, double endX, double endV, Duration? doneAt}) flight,
    ) {
      expect(flight.doneAt, isNotNull,
          reason: 'isDone must come true within the 3s horizon');
      // Well past the reported done point the solution sits on the target at
      // rest -- far tighter than the 1e-3 tolerance isDone itself uses.
      expect(flight.endX, closeTo(1, 1e-9), reason: 'lands on target');
      expect(flight.endV, closeTo(0, 1e-9), reason: 'and comes to rest');
    }

    test('crisp lands dead -- at most a tenth of a percent of bounce', () {
      final flight = fly(Springs.crisp);
      expect(flight.peak - 1, lessThanOrEqualTo(0.001),
          reason: 'critically damped: the press-down must not bounce');
      expectLandsOnTarget(flight);
    });

    test('select rebounds once, between two and eight percent of the gap', () {
      final flight = fly(Springs.select);
      expect(flight.peak - 1, inInclusiveRange(0.02, 0.08),
          reason: 'one clean visible rebound (~4.6% documented)');
      expectLandsOnTarget(flight);
    });

    test('settle barely leaves the target before returning', () {
      final flight = fly(Springs.settle);
      expect(flight.peak - 1, greaterThan(0),
          reason: 'underdamped: weight without playfulness still moves past');
      expect(flight.peak - 1, lessThan(0.02),
          reason: 'heavy: nowhere near the select rebound');
      expectLandsOnTarget(flight);
    });

    test('celebrate overshoots by at least a tenth of the gap', () {
      final flight = fly(Springs.celebrate);
      expect(flight.peak - 1, greaterThanOrEqualTo(0.10),
          reason: 'signature moments get a big warm overshoot (~20%)');
      expectLandsOnTarget(flight);
    });
  });

  group('SpringController', () {
    testWidgets('starts on its initial value without animating',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, initial: 0.85));
      final spring = key.currentState!.spring;

      expect(spring.value, 0.85);
      expect(spring.isAnimating, isFalse);

      await tester.pump(const Duration(milliseconds: 100));
      expect(spring.value, 0.85, reason: 'idle stays idle');
    });

    testWidgets('springTo converges on the target and then rests',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final spring = key.currentState!.spring;

      spring.springTo(100, spring: Springs.crisp);
      await tester.pump();
      expect(spring.isAnimating, isTrue);

      await tester.pump(const Duration(milliseconds: 40));
      expect(spring.value, inExclusiveRange(5, 95),
          reason: 'it travels; it neither teleports nor waits');

      await tester.pumpAndSettle();
      expect(spring.value, closeTo(100, 0.001));
      expect(spring.isAnimating, isFalse);
    });

    testWidgets('jump stops the animation and takes the value immediately',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final spring = key.currentState!.spring;

      spring.springTo(100);
      await tester.pump(const Duration(milliseconds: 80));
      expect(spring.isAnimating, isTrue);

      spring.jump(7);
      expect(spring.isAnimating, isFalse);
      expect(spring.value, 7.0);

      await tester.pump(const Duration(milliseconds: 200));
      expect(spring.value, 7.0, reason: 'nothing is scheduled after a jump');
    });

    testWidgets('retargeting mid-flight carries velocity instead of restarting',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final spring = key.currentState!.spring;

      spring.springTo(100);
      // The first pump consumes the simulation's start frame; motion reads
      // from the second onward (same rhythm the converges test uses).
      await tester.pump();
      var prev = spring.value;
      // 8ms steps keep the crossing point inside the asserted window: on a
      // 16ms grid the settle spring clears 30 by too wide a margin in one
      // stride for the band below to mean anything.
      for (var i = 0; i < 80 && spring.value < 30; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        expect(spring.value, greaterThan(prev),
            reason: 'still flying toward 100');
        prev = spring.value;
      }

      final atRetarget = spring.value;
      expect(atRetarget, inExclusiveRange(29, 38),
          reason: 'about a third of the way, still moving up');

      spring.springTo(0);
      await tester.pump(); // consume the start frame

      // The proof of carry-over: the very next frames keep travelling
      // UPWARD. A restart that dropped the velocity would turn around at
      // once; carried momentum cannot stop on a dime. (So the peak must
      // exceed the retarget point -- a value that never rose above it would
      // demonstrate the restart bug, not the feature.)
      await tester.pump(const Duration(milliseconds: 16));
      final rising = spring.value;
      expect(rising, greaterThan(atRetarget),
          reason: 'velocity flows through the retarget');

      await tester.pump(const Duration(milliseconds: 16));
      var peak = spring.value;
      expect(peak, greaterThan(rising));

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        peak = math.max(peak, spring.value);
      }
      // Momentum explains roughly ten units past the reversal point; anything
      // near the abandoned 100 would mean the old aim survived the retarget.
      expect(peak, inExclusiveRange(35, 60),
          reason: 'coasts past the turnaround, nowhere near 100');

      await tester.pumpAndSettle();
      expect(spring.value, closeTo(0, 0.001),
          reason: 'eventually lands on the new aim');
      expect(spring.isAnimating, isFalse);
    });

    testWidgets('springWithVelocity coasts on handed-in momentum even aiming '
        'home', (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final spring = key.currentState!.spring;

      // The day picker's release, distilled: the row stands at 0, home is 0,
      // and only the finger's velocity (+500 px/s) says otherwise. springTo
      // cannot express this -- it would read a resting controller's zero.
      expect(spring.value, 0);
      spring.springWithVelocity(0, velocity: 500);
      await tester.pump(); // consume the start frame
      expect(spring.value, closeTo(0, 0.001),
          reason: 'x(0) is the start position; all the energy is velocity');

      var peak = spring.value;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        peak = math.max(peak, spring.value);
      }
      // The proof the external velocity was received: the value leaves zero
      // and comes back on its own. A dropped seed never rises at all.
      expect(peak, greaterThan(0), reason: 'momentum coasts up before the '
          'settle spring pulls it back');

      await tester.pumpAndSettle();
      expect(spring.value, closeTo(0, 0.001),
          reason: 'and it lands exactly home regardless');
      expect(spring.isAnimating, isFalse);
    });
  });

  group('SpringScale', () {
    Widget harness(Widget child, {bool reduced = false}) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MaterialApp(home: Scaffold(body: child)),
        ),
      );
    }

    // SpringScale renders its live scale as a plain Transform; storage[0]
    // is the uniform x-scale.
    double scaleOf(WidgetTester tester) => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(SpringScale),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .storage[0];

    testWidgets('mounts exactly on its target -- no entrance animation',
        (tester) async {
      await tester.pumpWidget(
        harness(const SpringScale(target: 1.2, child: Text('chip'))),
      );
      await tester.pump();

      expect(scaleOf(tester), 1.2);
      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1.2);
    });

    testWidgets('a target change animates and settles exactly on the new one',
        (tester) async {
      await tester.pumpWidget(
        harness(const SpringScale(target: 1.0, child: Text('chip'))),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        harness(const SpringScale(target: 1.25, child: Text('chip'))),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(scaleOf(tester), inExclusiveRange(1.0, 1.249),
          reason: 'mid-flight toward 1.25, not snapped and not waiting');

      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1.25, 0.001));
    });

    testWidgets('a second change mid-flight redirects without throwing',
        (tester) async {
      await tester.pumpWidget(
        harness(const SpringScale(target: 1.0, child: Text('chip'))),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        harness(const SpringScale(target: 1.5, child: Text('chip'))),
      );
      await tester.pump(const Duration(milliseconds: 40));

      await tester.pumpWidget(
        harness(const SpringScale(target: 0.9, child: Text('chip'))),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(scaleOf(tester), closeTo(0.9, 0.001),
          reason: 'the latest aim wins');
    });

    testWidgets('reduce-motion jumps to the new target in the first frame',
        (tester) async {
      await tester.pumpWidget(
        harness(const SpringScale(target: 1.0, child: Text('chip')),
            reduced: true),
      );
      await tester.pump();
      expect(scaleOf(tester), 1.0);

      await tester.pumpWidget(
        harness(const SpringScale(target: 0.8, child: Text('chip')),
            reduced: true),
      );
      await tester.pump();
      expect(scaleOf(tester), 0.8,
          reason: 'jumps; nothing may be caught mid-flight');
    });

    testWidgets('alignment passes through to the transform', (tester) async {
      await tester.pumpWidget(
        harness(const SpringScale(
          target: 0.9,
          alignment: Alignment.bottomRight,
          child: Text('chip'),
        )),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(SpringScale),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.alignment, Alignment.bottomRight);
      expect(scaleOf(tester), closeTo(0.9, 0.001));
    });
  });
}

/// Owns a [SpringController] on a real ticker so controller tests drive it
/// with `tester.pump` like any animation in the tree.
class _Host extends StatefulWidget {
  const _Host({super.key, this.initial = 0});

  final double initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final SpringController spring =
      SpringController(vsync: this, initial: widget.initial);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    spring.dispose();
    super.dispose();
  }
}
