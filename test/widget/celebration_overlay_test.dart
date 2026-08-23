import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/core/l10n/formatting.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/core/widgets/animated_percentage.dart';
import 'package:ather/core/widgets/celebration_overlay.dart';
import 'package:ather/core/widgets/list_entrance.dart';

/// SP-04ب: the mastered-chapter celebration is retiming only -- the disc pops,
/// a ring echoes it, the number counts, the sentence explains. These pin the
/// beats and the reduced-motion collapse.
void main() {
  // The number under test. percent() wraps it in the same isolates the user
  // sees, so finders must look for exactly that.
  final finished = percent(87);

  Widget harness(Widget child, {bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  FadeTransition bodyFade(WidgetTester tester) =>
      tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(RiseIn),
          matching: find.byType(FadeTransition),
        ),
      );

  testWidgets('title opens at once; sentence follows; the number counts last', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        CelebrationOverlay(
          title: 'أتقنت الباب',
          body: 'جملة السياق',
          percentage: 87,
          onDismiss: () {},
        ),
      ),
    );
    await tester.pump(); // postFrame: both clocks start here.

    // t=0: the title names what the eye is already looking at.
    expect(find.text('أتقنت الباب'), findsOneWidget);

    // Inside the count's lead-in (t<150ms): no counter mounted yet, but its
    // finished figure already reserves the layout invisibly.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CountUpFromZero), findsNothing);
    expect(find.text(finished), findsOneWidget);

    // t=310ms: the count has been running since 150ms (so the finished string
    // is gone), and the sentence is part-way through its fade.
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.byType(CountUpFromZero), findsOneWidget);
    expect(find.text(finished), findsNothing);
    final fade = bodyFade(tester).opacity.value;
    expect(fade, greaterThan(0));
    expect(fade, lessThan(1));

    await tester.pumpAndSettle();
    expect(find.text(finished), findsOneWidget);
    expect(bodyFade(tester).opacity.value, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows every final state at once', (tester) async {
    await tester.pumpWidget(
      harness(
        CelebrationOverlay(
          title: 'أتقنت الباب',
          body: 'جملة السياق',
          percentage: 87,
          onDismiss: () {},
        ),
        reduced: true,
      ),
    );
    await tester.pump(); // postFrame lands everything.

    expect(find.text('أتقنت الباب'), findsOneWidget);
    expect(find.text('جملة السياق'), findsOneWidget);
    expect(find.text(finished), findsOneWidget);
    // RiseIn under reduced motion returns the bare child -- no fade layer.
    expect(
      find.descendant(
        of: find.byType(RiseIn),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap dismisses, as before', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      harness(
        CelebrationOverlay(
          title: 'أتقنت الباب',
          body: 'جملة السياق',
          percentage: 87,
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CelebrationOverlay));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });
}
