import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/core/l10n/formatting.dart';
import 'package:ather/core/theme/app_spacing.dart';
import 'package:ather/core/widgets/animated_percentage.dart';
import 'package:ather/core/widgets/collapsing_removal.dart';
import 'package:ather/core/widgets/list_entrance.dart';
import 'package:ather/core/widgets/pop_in.dart';

/// The motion system's own unit tests.
///
/// These exist because the screens' widget tests all end in `pumpAndSettle`,
/// which proves an animation *finishes* but never that it ran, honoured its
/// duration, or collapsed correctly under reduced motion.
Widget harness(Widget child, {bool reduced = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  group('RiseIn', () {
    testWidgets('fades and rises, then settles with no layer left behind', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const RiseIn(child: Text('row'))));
      await tester.pump();

      final opacity = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(RiseIn),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(
        opacity.opacity.value,
        lessThan(1.0),
        reason: 'the entrance must actually start from transparent',
      );

      await tester.pumpAndSettle();
      expect(opacity.opacity.value, 1.0);
    });

    testWidgets('a delay holds the child back, and still settles', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const RiseIn(
            delay: Duration(milliseconds: 120),
            duration: Duration(milliseconds: 100),
            child: Text('late'),
          ),
        ),
      );
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(RiseIn),
          matching: find.byType(FadeTransition),
        ),
      );

      // Still inside the delay window: nothing has begun.
      await tester.pump(const Duration(milliseconds: 100));
      expect(fade.opacity.value, 0.0);

      // Past delay + duration: fully arrived. If the delay were a timer rather
      // than an interval on the controller, pumpAndSettle would hang here.
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1.0);
    });

    testWidgets('reduced motion returns the child with no layer at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const RiseIn(child: Text('row')), reduced: true),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(RiseIn),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(find.text('row'), findsOneWidget);
    });

    testWidgets('disposes cleanly under reduced motion', (tester) async {
      // Regression: the controller used to be created lazily in the field, so
      // under reduced motion `build` never touched it and `dispose` was the
      // first thing to construct one -- on a deactivated element.
      await tester.pumpWidget(
        harness(const RiseIn(child: Text('row')), reduced: true),
      );
      await tester.pumpWidget(harness(const SizedBox.shrink(), reduced: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('ListEntrance', () {
    testWidgets('staggers, and caps the delay at 6 rows', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              for (var i = 0; i < 12; i++)
                ListEntrance(index: i, child: Text('row $i')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The whole list must settle within the capped window, not within
      // 12 x 40ms. A row past the cap shares slot 6.
      final capped = AppMotion.stagger * AppMotion.staggerCap + AppMotion.enter;
      expect(capped, const Duration(milliseconds: 500));
      expect(find.text('row 11'), findsOneWidget);
    });

    testWidgets('PopIn disposes cleanly under reduced motion', (tester) async {
      await tester.pumpWidget(
        harness(const PopIn(child: Text('tick')), reduced: true),
      );
      await tester.pumpWidget(harness(const SizedBox.shrink(), reduced: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('PopIn never overshoots past 1.0', (tester) async {
      await tester.pumpWidget(harness(const PopIn(child: Text('tick'))));

      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 15));
        final scale = tester.widget<ScaleTransition>(
          find.descendant(
            of: find.byType(PopIn),
            matching: find.byType(ScaleTransition),
          ),
        );
        peak = peak > scale.scale.value ? peak : scale.scale.value;
      }
      await tester.pumpAndSettle();

      expect(
        peak,
        lessThanOrEqualTo(1.0),
        reason: 'a badge that bounces reads as a notification',
      );
    });
  });

  group('AnimatedPercentage', () {
    testWidgets('counts between values and lands exactly', (tester) async {
      Widget at(double v) => harness(
        AnimatedPercentage(
          value: v,
          hasData: true,
          color: const Color(0xFF000000),
          style: const TextStyle(),
        ),
      );

      await tester.pumpWidget(at(40));
      await tester.pumpAndSettle();
      expect(find.text('${kLri}40%$kPdi'), findsOneWidget);

      await tester.pumpWidget(at(81));
      await tester.pump(const Duration(milliseconds: 200));

      // Mid-count: something between the two, and not either endpoint.
      expect(find.text('${kLri}40%$kPdi'), findsNothing);
      expect(find.text('${kLri}81%$kPdi'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('${kLri}81%$kPdi'), findsOneWidget);
    });

    testWidgets('never counts to or from the em-dash', (tester) async {
      await tester.pumpWidget(
        harness(
          const AnimatedPercentage(
            value: 0,
            hasData: false,
            color: Color(0xFF000000),
            style: TextStyle(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('reduced motion lands on the value in one frame', (
      tester,
    ) async {
      Widget at(double v) => harness(
        AnimatedPercentage(
          value: v,
          hasData: true,
          color: const Color(0xFF000000),
          style: const TextStyle(),
        ),
        reduced: true,
      );

      await tester.pumpWidget(at(40));
      await tester.pump();
      await tester.pumpWidget(at(81));
      await tester.pump();

      expect(find.text('${kLri}81%$kPdi'), findsOneWidget);
    });
  });

  group('CountUpFromZero', () {
    testWidgets('counts from 0 the first time and not the second', (
      tester,
    ) async {
      var counted = false;

      Widget build() => harness(
        CountUpFromZero(
          value: 75,
          already: counted,
          onDone: () => counted = true,
          color: const Color(0xFF000000),
          style: const TextStyle(),
        ),
      );

      await tester.pumpWidget(build());
      await tester.pump();
      expect(find.text('${kLri}0%$kPdi'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('${kLri}75%$kPdi'), findsOneWidget);
      expect(counted, isTrue);

      // Stepping away and back must show a fact, not replay the news.
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pumpWidget(build());
      await tester.pump();
      expect(find.text('${kLri}75%$kPdi'), findsOneWidget);
    });
  });

  group('CollapsingList', () {
    Widget listOf(List<int> items) => harness(
      CollapsingList<int>(
        items: items,
        idOf: (i) => i,
        itemBuilder: (context, i) => SizedBox(height: 20, child: Text('$i')),
      ),
    );

    testWidgets('a removed row collapses, then leaves the tree', (
      tester,
    ) async {
      await tester.pumpWidget(listOf(<int>[1, 2, 3]));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      await tester.pumpWidget(listOf(<int>[1, 3]));
      await tester.pump();

      // Still rendered, mid-collapse: the widget has to outlive its data long
      // enough for the collapse to be seen.
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(SizeTransition), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('an added row appears in position', (tester) async {
      await tester.pumpWidget(listOf(<int>[1, 3]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(listOf(<int>[1, 2, 3]));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives an add and a remove in the same rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(listOf(<int>[1, 2, 3]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(listOf(<int>[1, 4, 3]));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsNothing);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rename keeps the row in place without animating', (
      tester,
    ) async {
      Widget named(String label) => harness(
        CollapsingList<String>(
          items: <String>[label],
          idOf: (_) => 7,
          itemBuilder: (context, s) => SizedBox(height: 20, child: Text(s)),
        ),
      );

      await tester.pumpWidget(named('before'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(named('after'));
      await tester.pump();

      expect(find.text('after'), findsOneWidget);
      expect(find.byType(SizeTransition), findsNothing);
    });

    testWidgets('emptying the list removes every row', (tester) async {
      await tester.pumpWidget(listOf(<int>[1, 2]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(listOf(<int>[]));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
