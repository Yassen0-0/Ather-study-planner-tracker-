import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/core/theme/app_spacing.dart';
import 'package:ather/core/widgets/ather_icons.dart';
import 'package:ather/core/widgets/icon_motion.dart';

/// The icon motion handoff's own unit tests (§2, §3, §5, §6).
///
/// Each transition is checked for three things the screens' `pumpAndSettle`
/// tests cannot see: that it runs at all, that it lands on the authored end
/// value, and that reduced motion arrives there on the first frame instead of
/// arriving there quickly.
Widget harness(
  Widget child, {
  bool reduced = false,
  TextDirection direction = TextDirection.rtl,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    // Inside the MaterialApp, not around it: MaterialApp inserts its own
    // Directionality from the locale, and an outer one would be shadowed by it
    // — which is exactly the wrongly-seeded-direction bug §5 warns about.
    child: MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: direction,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

double _selectionOf(WidgetTester tester) =>
    tester.widget<AtherIcon>(find.byType(AtherIcon)).selection;

void main() {
  group('TabGlyph — the weight axis (§2)', () {
    Widget tab({required bool selected}) => TabGlyph(
      glyph: AtherGlyph.chart,
      selected: selected,
      selectedColor: const Color(0xFF000000),
      unselectedColor: const Color(0xFF999999),
    );

    testWidgets('selecting drives the axis 0 → 1 over nav', (tester) async {
      await tester.pumpWidget(harness(tab(selected: false)));
      expect(_selectionOf(tester), 0);

      await tester.pumpWidget(harness(tab(selected: true)));
      await tester.pump(const Duration(milliseconds: 40));
      final mid = _selectionOf(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));

      await tester.pumpAndSettle();
      expect(_selectionOf(tester), 1);
    });

    testWidgets('the axis is front-loaded — no ease-in on a tap', (
      tester,
    ) async {
      await tester.pumpWidget(harness(tab(selected: false)));
      await tester.pumpWidget(harness(tab(selected: true)));
      // 40ms is a quarter of the 150ms nav token. easeOutQuint is well past
      // half way by then; an ease-in would still be near zero.
      await tester.pump(const Duration(milliseconds: 40));
      expect(_selectionOf(tester), greaterThan(0.5));
    });

    testWidgets('reduced motion lands selected on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(harness(tab(selected: false), reduced: true));
      await tester.pumpWidget(harness(tab(selected: true), reduced: true));
      await tester.pump();
      expect(_selectionOf(tester), 1);
    });

    testWidgets('the label is tinted from the same frame as the glyph', (
      tester,
    ) async {
      Color? seenTint;
      double? seenSelection;
      await tester.pumpWidget(
        harness(
          TabGlyph(
            glyph: AtherGlyph.home,
            selected: true,
            selectedColor: const Color(0xFF000000),
            unselectedColor: const Color(0xFFFFFFFF),
            builder: (context, tint, glyph) {
              seenTint = tint;
              seenSelection = _tintProbe(glyph);
              return glyph;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      // Both come from one tween: a half-selected glyph never gets a fully
      // selected label.
      expect(seenSelection, isNotNull);
      expect(seenTint, isNot(const Color(0xFFFFFFFF)));
    });
  });

  group('SpinningCog — 45° per open (§3)', () {
    testWidgets('one turn lands on exactly pi/4', (tester) async {
      final key = GlobalKey<SpinningCogState>();
      await tester.pumpWidget(harness(SpinningCog(key: key)));
      expect(_angle(key), 0);

      key.currentState!.turn();
      await tester.pumpAndSettle();
      expect(_angle(key), closeTo(math.pi / 4, 1e-9));
    });

    testWidgets('ten turns accumulate — no modulo, no unwind', (tester) async {
      final key = GlobalKey<SpinningCogState>();
      await tester.pumpWidget(harness(SpinningCog(key: key)));
      for (var i = 0; i < 10; i++) {
        key.currentState!.turn();
        await tester.pumpAndSettle();
      }
      expect(_angle(key), closeTo(10 * math.pi / 4, 1e-9));
    });

    testWidgets('an interrupting turn adds, it never rewinds', (tester) async {
      final key = GlobalKey<SpinningCogState>();
      await tester.pumpWidget(harness(SpinningCog(key: key)));

      key.currentState!.turn();
      // The first pump starts the ticker; the clock only advances from there.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final interrupted = _angle(key);
      expect(interrupted, greaterThan(0));

      key.currentState!.turn();
      await tester.pump();
      // The second turn picks up from the first turn's landing point, so the
      // angle steps forward. It must never drop back below where it was.
      expect(_angle(key), greaterThanOrEqualTo(interrupted - 1e-9));

      await tester.pumpAndSettle();
      expect(_angle(key), closeTo(2 * math.pi / 4, 1e-9));
    });

    testWidgets('reduced motion turns without animating', (tester) async {
      final key = GlobalKey<SpinningCogState>();
      await tester.pumpWidget(harness(SpinningCog(key: key), reduced: true));
      key.currentState!.turn();
      await tester.pump();
      expect(_angle(key), closeTo(math.pi / 4, 1e-9));
    });
  });

  group('AnimatedBackChevron — reflection (§5)', () {
    testWidgets('rests pointing right in Arabic, mirrored in English', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const AnimatedBackChevron()));
      await tester.pump();
      expect(_scaleX(tester), closeTo(1, 1e-9));
      expect(_strokeOf(tester), closeTo(2.4, 1e-9));

      await tester.pumpWidget(
        harness(const AnimatedBackChevron(), direction: TextDirection.ltr),
      );
      await tester.pumpAndSettle();
      expect(_scaleX(tester), closeTo(-1, 1e-9));
      expect(_strokeOf(tester), closeTo(2.2, 1e-9));
    });

    testWidgets('the resting state is correct before anything animates', (
      tester,
    ) async {
      // Seeded from Directionality, not from a hard-coded start value: a
      // wrongly-seeded controller looks right only after the first change.
      await tester.pumpWidget(
        harness(const AnimatedBackChevron(), direction: TextDirection.ltr),
      );
      await tester.pump();
      expect(_scaleX(tester), closeTo(-1, 1e-9));
    });

    testWidgets('the stroke travels with the reflection', (tester) async {
      await tester.pumpWidget(harness(const AnimatedBackChevron()));
      await tester.pumpWidget(
        harness(const AnimatedBackChevron(), direction: TextDirection.ltr),
      );
      await tester.pump(const Duration(milliseconds: 60));
      final stroke = _strokeOf(tester)!;
      expect(stroke, lessThan(2.4));
      expect(stroke, greaterThan(2.2));
    });
  });

  group('OverdueCheck — the flood (§6)', () {
    testWidgets('an already-complete mark does not replay', (tester) async {
      await tester.pumpWidget(harness(const OverdueCheck(done: true)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('completing runs over the tick token and settles', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const OverdueCheck(done: false)));
      await tester.pumpWidget(harness(const OverdueCheck(done: true)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(AppMotion.tick);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion completes without a running animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const OverdueCheck(done: false), reduced: true),
      );
      await tester.pumpWidget(
        harness(const OverdueCheck(done: true), reduced: true),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disposes cleanly mid-flight', (tester) async {
      await tester.pumpWidget(harness(const OverdueCheck(done: false)));
      await tester.pumpWidget(harness(const OverdueCheck(done: true)));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump();
    });
  });

  group('OverdueMark — the row\'s mark (§6)', () {
    testWidgets('a healthy subject costs nothing at all', (tester) async {
      await tester.pumpWidget(harness(const OverdueMark(needsReview: false)));
      await tester.pump();
      expect(tester.getSize(find.byType(OverdueMark)), Size.zero);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('an overdue subject holds the mark and its gap', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const OverdueMark(needsReview: true)));
      await tester.pump();
      final size = tester.getSize(find.byType(OverdueMark));
      expect(size.width, 15 + OverdueMark.gap);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('completing floods, then collapses out of the row', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const OverdueMark(needsReview: true)));
      await tester.pumpWidget(harness(const OverdueMark(needsReview: false)));
      await tester.pump();

      // The flood owns the first stretch: the mark still holds its full width
      // while the ring is closing, or the tick would land on a moving target.
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.getSize(find.byType(OverdueMark)).width,
        15 + OverdueMark.gap,
      );

      // Then it leaves, gap and all.
      await tester.pump(const Duration(milliseconds: 260));
      expect(
        tester.getSize(find.byType(OverdueMark)).width,
        lessThan(15 + OverdueMark.gap),
      );

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(OverdueMark)), Size.zero);
    });

    testWidgets('going overdue again brings the mark straight back', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const OverdueMark(needsReview: true)));
      await tester.pumpWidget(harness(const OverdueMark(needsReview: false)));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(OverdueMark)), Size.zero);

      await tester.pumpWidget(harness(const OverdueMark(needsReview: true)));
      await tester.pump();
      // Un-flooded and at full width on the first frame: decay coming back is
      // not an event to play an animation over.
      expect(
        tester.getSize(find.byType(OverdueMark)).width,
        15 + OverdueMark.gap,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion takes the mark out on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const OverdueMark(needsReview: true), reduced: true),
      );
      await tester.pumpWidget(
        harness(const OverdueMark(needsReview: false), reduced: true),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(OverdueMark)), Size.zero);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('disposes cleanly mid-flight', (tester) async {
      await tester.pumpWidget(harness(const OverdueMark(needsReview: true)));
      await tester.pumpWidget(harness(const OverdueMark(needsReview: false)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump();
    });
  });

  group('CompletionDisc — ring → disc (§7)', () {
    Widget disc({required bool done}) => CompletionDisc(
      done: done,
      size: 34,
      fill: const Color(0xFF000000),
      ring: const Color(0xFFCCCCCC),
      tickColor: const Color(0xFFFFFFFF),
      ringWidth: 1.6,
      tickSize: 16,
    );

    /// The tick, which only exists once the flood has finished.
    Finder tick() => find.byType(AtherIcon);

    testWidgets('an already-complete day does not replay', (tester) async {
      await tester.pumpWidget(harness(disc(done: true)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tick(), findsOneWidget);
    });

    testWidgets('the empty state carries no tick at all', (tester) async {
      await tester.pumpWidget(harness(disc(done: false)));
      await tester.pump();
      expect(tick(), findsNothing);
    });

    testWidgets('the flood finishes before the tick starts', (tester) async {
      await tester.pumpWidget(harness(disc(done: false)));
      await tester.pumpWidget(harness(disc(done: true)));
      await tester.pump();

      // Two things in sequence, not two things at once: nothing of the tick is
      // on screen while the ring is still closing.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tick(), findsNothing);

      await tester.pump(const Duration(milliseconds: 60));
      expect(tick(), findsOneWidget);
    });

    testWidgets('the whole thing runs 340ms, over the tick token', (
      tester,
    ) async {
      await tester.pumpWidget(harness(disc(done: false)));
      await tester.pumpWidget(harness(disc(done: true)));
      await tester.pump();

      // 330ms in it is still going; by 340 it has landed. Compressing this to
      // the 220ms token is the thing the handoff says not to do.
      await tester.pump(const Duration(milliseconds: 330));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('un-completing reverses rather than restarting', (
      tester,
    ) async {
      await tester.pumpWidget(harness(disc(done: false)));
      await tester.pumpWidget(harness(disc(done: true)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(harness(disc(done: false)));
      await tester.pumpAndSettle();
      expect(tick(), findsNothing);
    });

    testWidgets('reduced motion lands complete on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(harness(disc(done: false), reduced: true));
      await tester.pumpWidget(harness(disc(done: true), reduced: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      // The end state has to stay readable under reduced motion — this is the
      // one the handoff flags as at risk.
      expect(tick(), findsOneWidget);
    });

    testWidgets('disposes cleanly mid-flood', (tester) async {
      await tester.pumpWidget(harness(disc(done: false)));
      await tester.pumpWidget(harness(disc(done: true)));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump();
    });
  });
}

/// The cog's accumulated angle. Read off the state, not off the matrix: a
/// matrix angle wraps at π, which is precisely the drift this test exists to
/// rule out.
double _angle(GlobalKey<SpinningCogState> key) => key.currentState!.angle;

/// The chevron's current horizontal scale — 1 pointing right, −1 mirrored.
double _scaleX(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(AnimatedBackChevron),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getRow(0)[0];

double? _strokeOf(WidgetTester tester) =>
    tester.widget<AtherIcon>(find.byType(AtherIcon)).strokeWidth;

/// The selection the builder's glyph was handed, read back off the widget.
double _tintProbe(Widget glyph) => (glyph as AtherIcon).selection;
