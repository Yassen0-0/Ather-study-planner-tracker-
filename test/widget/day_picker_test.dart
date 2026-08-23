import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_spacing.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/core/widgets/day_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The day picker: how many cells it shows, which way a swipe goes, and where
/// today is when it is off screen.
///
/// Two of these are regressions carried over from the week strip this replaced,
/// because both defects were in the *design* rather than in the port, and a new
/// widget with the same two jobs is a new chance to reintroduce them:
///
/// 1. **The swipe was mirrored.** Direction was flipped per call site instead of
///    once, so the same gesture reached different days in Arabic and English.
/// 2. **The way home pointed away.** The "come back to today" edge marked the
///    side the finger travels toward, which is the opposite side from the one
///    today is on.
///
/// The third is the reason the widget exists: the strip laid seven cells at the
/// 48px target floor and so needed 368px, which a 360 phone does not have.
void main() {
  // A Wednesday, so there are days either side of it inside the same month.
  final DateTime today = DateTime(2026, 8, 5);

  /// Slack for the sub-pixel arithmetic of a centred row, and nothing more. A
  /// cell that misses its box by a real amount misses it by whole pixels.
  const double rounding = 0.01;

  /// Numbers reach the screen wrapped in Unicode isolates so they read
  /// correctly inside an Arabic sentence, and a finder has to look for the same
  /// thing the student sees. Written as escapes, not literals: pasted raw, the
  /// isolate characters silently reorder this source file in an editor.
  String iso(Object value) => '\u2066$value\u2069';

  late DateTime selected;
  late List<DateTime> picked;

  setUp(() {
    selected = today;
    picked = <DateTime>[];
  });

  /// Pumps the picker at [width] logical pixels of *content*, the way the tasks
  /// header hands it a box: the page margin has already been taken off.
  ///
  /// [reduceMotion] stands in for the platform's "disable animations" switch,
  /// which is what `prefersReducedMotion` reads.
  Future<void> pump(
    WidgetTester tester, {
    double width = 390 - 2 * AppSpacing.pageMargin,
    TextDirection direction = TextDirection.rtl,
    Set<DateTime> completeDays = const <DateTime>{},
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: direction == TextDirection.rtl
            ? const Locale('ar')
            : const Locale('en'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: reduceMotion
                      ? mq.copyWith(disableAnimations: true)
                      : mq,
                  child: SizedBox(
                    width: width,
                    child: DayPicker(
                      today: today,
                      selectedDay: selected,
                      completeDays: completeDays,
                      onSelect: picked.add,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drags the row by [dx] physical pixels and lets the change settle.
  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.drag(find.byType(DayPicker), Offset(dx, 0));
    await tester.pumpAndSettle();
  }

  int cellCount(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(of: find.byType(DayPicker), matching: find.byType(Text)),
      )
      .length;

  group('what it shows', () {
    testWidgets('today reads "اليوم" and carries the selection', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('اليوم'), findsOneWidget);
      // Its own date is not also on screen: one cell, one label.
      expect(find.text('أربعاء ${iso(5)}'), findsNothing);
      // The neighbours are named and dated.
      expect(find.text('ثلاثاء ${iso(4)}'), findsOneWidget);
      expect(find.text('خميس ${iso(6)}'), findsOneWidget);
    });

    testWidgets('today keeps saying "اليوم" after another day is picked', (
      tester,
    ) async {
      selected = DateTime(2026, 8, 6);
      await pump(tester);

      // The one cell whose text never changes. Everything around it is a date,
      // so this is the landmark the student navigates against -- and the way
      // back is a tap on a word rather than on arithmetic.
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('خميس ${iso(6)}'), findsOneWidget);
    });

    testWidgets('a completed day is marked without a second fill', (
      tester,
    ) async {
      await pump(tester, completeDays: <DateTime>{DateTime(2026, 8, 4)});

      // The dot is the only decorated circle in the row; the pills are
      // rounded rectangles. Finding one is the assertion.
      final dots = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final d = c.decoration;
        return d is BoxDecoration && d.shape == BoxShape.circle;
      });
      expect(dots, hasLength(1));
    });
  });

  group('it fits the width it is given', () {
    // The counts below are asserted as *relationships*, never as numbers. The
    // test font is Ahem, which draws every glyph as a full em square, so
    // "ثلاثاء 4" measures about twice what it measures on a phone. Pinning "3
    // at 320" here would pin a property of the test font. What is portable is
    // the behaviour: it adapts, it stays odd, it never overflows, and it never
    // shrinks the type. `layout_matrix_test.dart` holds the other half — the
    // real screen at 320 and 360, asserting no overflow with the whole app
    // around it.

    testWidgets('the narrowest phone overflows nothing', (tester) async {
      await pump(tester, width: 320 - 2 * AppSpacing.pageMargin);

      expect(tester.takeException(), isNull);
      expect(
        find.text('اليوم'),
        findsOneWidget,
        reason: 'the selected day is the one cell that is never dropped',
      );
      expect(
        cellCount(tester).isOdd,
        isTrue,
        reason: 'days are added in pairs so the selected pill stays centred',
      );
    });

    testWidgets('a wider window earns more days, up to a week', (tester) async {
      await pump(tester, width: 320 - 2 * AppSpacing.pageMargin);
      final narrow = cellCount(tester);

      await pump(tester, width: 1000);
      final wide = cellCount(tester);

      expect(
        wide,
        greaterThan(narrow),
        reason: 'width the student has is width the picker spends',
      );
      expect(wide.isOdd, isTrue);
      expect(
        wide,
        lessThanOrEqualTo(DayPicker.maxCells),
        reason: 'past a week it stops being navigation and becomes a calendar',
      );
    });

    testWidgets('the label is never scaled down to make it fit', (
      tester,
    ) async {
      await pump(tester, width: 320 - 2 * AppSpacing.pageMargin);

      final sizes = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(DayPicker),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.style?.fontSize);
      // One size, the design's. Shrinking text to fit is the failure this
      // widget exists to avoid: a date nobody can read is worse than a date
      // that is not on screen.
      expect(sizes.toSet(), hasLength(1));
    });

    testWidgets('what it measured is what it lays out, at every width', (
      tester,
    ) async {
      // The invariant the whole widget rests on, and the one that no amount of
      // "does it overflow at 320" catches on its own: `_visibleDays` decides
      // how many cells fit by *predicting* each cell's width, and the cells
      // then lay themselves out. If the prediction and the layout ever
      // disagree — a target floor applied in one and not the other, a gap
      // billed per cell instead of between them — the row keeps one pair too
      // many and runs over by exactly the difference.
      //
      // **Swept, not sampled, and that is the whole point.** A handful of
      // round widths tests nothing here: the disagreement only shows at a
      // width where the last pair *just* fits by the budget and *just* does not
      // in the layout, and the odds of a hand-picked 320 or 520 landing on that
      // boundary are poor. This walks every width in between, so the boundary
      // is hit whatever the two numbers happen to be. Written against a
      // deliberately broken build first — under-billing the gaps by 8 fails
      // this and passes everything else in the file.
      final overflowed = <double>[];

      for (double width = 120; width <= 1000; width += 3) {
        await pump(tester, width: width);

        final row = tester.getRect(find.byType(DayPicker));
        final cells = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(DayPicker),
                matching: find.byType(Text),
              ),
            )
            .map((t) => tester.getRect(find.byWidget(t)));

        for (final cell in cells) {
          if (cell.left < row.left - rounding ||
              cell.right > row.right + rounding) {
            overflowed.add(width);
            break;
          }
        }
        // Collected rather than asserted per width: the first failing width is
        // useful, and the *number* of them says whether the budget is off by a
        // constant or the floor is missing on one label.
        tester.takeException();
      }

      expect(overflowed, isEmpty, reason: 'cells ran outside their own box');
    });

    testWidgets('a very narrow box still renders, and still does not overflow', (
      tester,
    ) async {
      // Narrower than any phone the app claims to support. There is no width
      // at which clipping is the answer.
      await pump(tester, width: 140);

      expect(tester.takeException(), isNull);
      expect(cellCount(tester), greaterThanOrEqualTo(1));
    });
  });

  group('interaction', () {
    testWidgets('tapping a day selects it', (tester) async {
      await pump(tester);

      await tester.tap(find.text('خميس ${iso(6)}'));
      await tester.pumpAndSettle();

      expect(picked.single, DateTime(2026, 8, 6));
    });

    testWidgets('a swipe past the threshold moves one day', (tester) async {
      await pump(tester);

      // Under RTL a drag toward the physical left is a drag toward the *end* of
      // the row, which pulls the earlier day in.
      await swipe(tester, -120);

      expect(picked.single, DateTime(2026, 8, 4));
    });

    testWidgets('a swipe short of the threshold changes nothing', (
      tester,
    ) async {
      await pump(tester);

      await swipe(tester, -20);

      expect(picked, isEmpty);
    });

    testWidgets('the same swipe under LTR lands on the same day', (
      tester,
    ) async {
      await pump(tester, direction: TextDirection.ltr);

      // Physically the opposite direction, because "toward the end of the row"
      // is the other way round. The day reached must be the same one -- this is
      // the regression that shipped mirrored once.
      await swipe(tester, 120);

      expect(picked.single, DateTime(2026, 8, 4));
    });
  });

  group('SP-08 drag physics', () {
    // The drag preview is paint-only: one Transform.translate driven by an
    // animation controller, found here by its key. Its offset is what the
    // student sees moving; nothing about layout ever changes.
    Offset dragOffset(WidgetTester tester) {
      final transform = tester
          .widget<Transform>(find.byKey(DayPicker.dragOffsetKey))
          .transform;
      return Offset(transform.storage[12], transform.storage[13]);
    }

    Future<TestGesture> grab(WidgetTester tester) => tester.startGesture(
      tester.getCenter(find.byType(DayPicker)),
    );

    /// Moves the finger [dx] physical pixels in equal steps, pumping [gap] of
    /// fake clock between them so the gesture spans real (simulated) time and
    /// the release carries a genuine velocity.

    testWidgets('a long pull translates less than the finger travelled', (
      tester,
    ) async {
      await pump(tester);

      final gesture = await grab(tester);
      await gesture.moveBy(const Offset(-400, 0));
      await tester.pump();

      final off = dragOffset(tester);
      expect(off.dy, 0);
      expect(off.dx, isNegative, reason: 'the row follows the finger');
      expect(
        off.dx.abs(),
        lessThan(400 * DayPicker.dragResistance),
        reason: 'past the first cell the square-law buys less and less',
      );

      // Releasing still decides on raw travel: far past the band, it commits.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(picked.single, DateTime(2026, 8, 4));
    });

    testWidgets('a fast short flick commits though it never crossed 45px', (
      tester,
    ) async {
      await pump(tester);

      // `timedDrag` is the one harness that stamps its move events across the
      // fake clock, so the recognizer's VelocityTracker receives real spacing.
      // Raw moveBy/pump sequences stamp every event at one instant, which
      // reads as zero velocity no matter how the finger actually moved.
      //
      // Two budget lines decide the numbers below. The recognizer feeds its
      // tracker only AFTER winning the arena, and winning costs kTouchSlop
      // (~18px of the raw travel); and the end callback carries a nonzero
      // velocity only when the *tracked* path classifies as a fling — ≥18px
      // inside the estimate window at more than the minimum fling speed. So:
      // 42px raw keeps the Kowalski distance half quiet (45px), leaves ~24px
      // tracked after the slop, and 170ms puts those pixels through the last
      // window at ~280px/s — past both the fling bar and the 110px/s (0.11
      // px/ms) velocity half of the rule.
      await tester.timedDrag(
        find.byType(DayPicker),
        const Offset(-42, 0),
        const Duration(milliseconds: 170),
      );
      await tester.pumpAndSettle();

      expect(picked.single, DateTime(2026, 8, 4));
    });

    testWidgets('a slow short swipe springs home and picks nothing', (
      tester,
    ) async {
      await pump(tester);

      final gesture = await grab(tester);
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(
        dragOffset(tester).dx,
        isNegative,
        reason: 'while held, the row visibly follows the finger',
      );

      // 30px at about 66px/s clears neither half of the rule.
      await gesture.up();
      expect(picked, isEmpty);
      await tester.pumpAndSettle();

      // The settle spring terminates -- pumpAndSettle returned -- and lands
      // exactly home.
      expect(dragOffset(tester).dx.abs(), lessThan(0.01));
    });

    testWidgets('reduce-motion skips the preview but keeps the commitment', (
      tester,
    ) async {
      await pump(tester, reduceMotion: true);

      final gesture = await grab(tester);
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(
        dragOffset(tester),
        Offset.zero,
        reason: 'no translation preview for vestibular safety',
      );

      // The decision machinery is untouched: same thresholds, instant commit.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(picked.single, DateTime(2026, 8, 4));
      expect(dragOffset(tester), Offset.zero);
    });
  });

  group('the way back to today', () {
    final Finder glow = find.byKey(returnGlowKey);

    testWidgets('there is no marker while today is on screen', (tester) async {
      await pump(tester);

      // pumpAndSettle returning at all is half the assertion. The strip's
      // version of this pulsed on a loop, so a hidden one animated forever and
      // this call could not be used.
      expect(glow, findsNothing);
    });

    testWidgets('it appears on the side today is actually on', (tester) async {
      // A week ahead: today is earlier than everything on screen, and dates
      // grow toward the end of the row, so today lies past the *start* edge.
      selected = DateTime(2026, 8, 12);
      await pump(tester);

      expect(glow, findsOneWidget);

      final row = tester.getRect(find.byType(DayPicker));
      final marker = tester.getRect(glow);
      // Measured, not reasoned about: reasoning about a mirror is what put
      // this arrow backwards in the first place. Under RTL the start edge is
      // the physical right.
      expect(
        marker.right,
        row.right,
        reason: 'today is behind the student, so the marker sits at the start',
      );

      await tester.tap(glow);
      await tester.pumpAndSettle();
      expect(picked.single, today);
    });

    testWidgets('a week back puts it on the other side', (tester) async {
      selected = DateTime(2026, 7, 29);
      await pump(tester);

      final row = tester.getRect(find.byType(DayPicker));
      final marker = tester.getRect(glow);
      expect(
        marker.left,
        row.left,
        reason: 'today is ahead of the student, so the marker sits at the end',
      );
    });

    testWidgets('under LTR the two sides swap with the script', (tester) async {
      selected = DateTime(2026, 8, 12);
      await pump(tester, direction: TextDirection.ltr);

      final row = tester.getRect(find.byType(DayPicker));
      final marker = tester.getRect(glow);
      expect(marker.left, row.left, reason: 'start is the physical left here');
    });
  });
}
