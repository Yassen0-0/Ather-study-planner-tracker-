import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/core/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The week strip's drag, and the "come back to today" glow.
///
/// Both of these are here because the design layer shipped them broken and the
/// handoff asked for a regression check on the ported version:
///
/// 1. **The drag did nothing.** The pointer handlers existed but were never
///    bound, so the strip was a static row that looked draggable.
/// 2. **The hidden glow pulsed forever.** Its `opacity: 0` was overridden by a
///    looping keyframe animation, so an invisible shape kept animating for the
///    life of the screen.
///
/// Neither is visible in a screenshot, which is exactly why they survived.
void main() {
  // A Wednesday. The week it falls in opens on Saturday 2026-08-01.
  final DateTime now = DateTime(2026, 8, 5);

  Widget host({
    TextDirection direction = TextDirection.rtl,
    ValueChanged<DateTime>? onSelect,
  }) {
    return MaterialApp(
      locale: direction == TextDirection.rtl
          ? const Locale('ar')
          : const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: WeekStrip(
            today: now,
            activeDays: const <DateTime>{},
            onSelect: onSelect,
          ),
        ),
      ),
    );
  }

  final Finder glow = find.byKey(returnGlowKey);

  /// Drags the strip by [dx] logical pixels and lets the snap finish.
  ///
  /// Deliberately not `pumpAndSettle`: once the strip is off today's week the
  /// glow pulses on a loop by design, and a repeating animation never settles.
  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.drag(find.byType(WeekStrip), Offset(dx, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a drag past the threshold moves to the next week', (
    tester,
  ) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(host(onSelect: picked.add));
    await tester.pumpAndSettle();

    // Wednesday, the day `now` falls on. Deliberately not Saturday: the glow
    // overlays the strip's first cell by design, and it would take the tap.
    await tester.tap(find.text('ر'));
    await tester.pumpAndSettle();
    expect(picked.single, DateTime(2026, 8, 5));

    // Under RTL a drag toward the physical left is a drag toward the *end* of
    // the strip, which pulls the previous week in.
    picked.clear();
    await swipe(tester, -120);

    await tester.tap(find.text('ر'));
    await tester.pump();
    expect(
      picked.single,
      DateTime(2026, 7, 29),
      reason: 'the strip should be showing the week before',
    );
  });

  testWidgets('a drag short of the threshold snaps back', (tester) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(host(onSelect: picked.add));
    await tester.pumpAndSettle();

    await swipe(tester, -20);

    await tester.tap(find.text('ر'));
    await tester.pumpAndSettle();
    expect(picked.single, DateTime(2026, 8, 5));
  });

  testWidgets('the same drag under LTR lands on the same week', (tester) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(
      host(direction: TextDirection.ltr, onSelect: picked.add),
    );
    await tester.pumpAndSettle();

    // Physically the opposite direction, because "toward the end of the strip"
    // is the other way round. The week reached must be the same one.
    await swipe(tester, 120);

    await tester.tap(find.text('W'));
    await tester.pump();
    expect(picked.single, DateTime(2026, 7, 29));
  });

  testWidgets('the glow is absent on today\'s week and does not tick', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // pumpAndSettle returning at all is half the assertion: a pulse looping on
    // a hidden glow never settles, and this call would have timed out.
    expect(glow, findsNothing);
  });

  testWidgets('the glow appears once another week is on screen', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    await swipe(tester, -120);
    expect(glow, findsOneWidget);

    // Tapping it goes home in one move -- and takes its ticker with it, which
    // is what lets pumpAndSettle return here.
    await tester.tap(glow);
    await tester.pumpAndSettle();
    expect(glow, findsNothing);
  });
}
