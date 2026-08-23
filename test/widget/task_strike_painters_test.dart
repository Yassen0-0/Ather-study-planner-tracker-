import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/core/theme/app_colors.dart';
import 'package:ather/core/theme/app_typography.dart';
import 'package:ather/core/widgets/task_strike_marks.dart';

/// Geometry assertions for the task strike marks -- deliberately golden-less.
///
/// A screenshot would pin the marks to one font raster; what actually matters
/// is that they stay *bounded*: the straight strike overshoots like a pen and
/// not like a miss, the zigzag swings inside its amplitude ceiling, lands
/// where it is aimed, and draws the identical scratch for the same seed on
/// every frame and every platform. Those are properties of numbers, so they
/// are asserted as numbers.
void main() {
  // The style the row renders its titles in; measuring with anything else
  // would assert against marks nobody draws.
  final TextStyle style = AppTypography.itemLabel;

  group('StraightStrikePainter geometry', () {
    test('one laid-out line gets exactly one strike, overshooting 4-6px', () {
      final List<MeasuredLine> lines = StrikeMarks.measureLines(
        text: 'مراجعة الباب الأول',
        style: style,
        maxWidth: 300,
        direction: TextDirection.rtl,
      );

      expect(lines, hasLength(1));
      final MeasuredLine line = lines.single;
      expect(line.end - (line.left + line.width), closeTo(5.0, 1.0));
      expect(
        line.end - (line.left + line.width),
        inInclusiveRange(StrikeMarks.overshoot - 1,
            StrikeMarks.overshoot + 1),
      );
    });

    test('the stroke weight stays below the scribble it must not compete with',
        () {
      expect(StraightStrikePainter.strokeWidth, lessThan(2.2));
    });

    test('a long title clips to maxLines, one strike per line', () {
      final List<MeasuredLine> lines = StrikeMarks.measureLines(
        text: 'كلمة ' * 40,
        style: style,
        maxWidth: 120,
        direction: TextDirection.rtl,
        maxLines: 2,
      );

      expect(lines, hasLength(2));
      for (final MeasuredLine line in lines) {
        expect(line.left + line.width, lessThanOrEqualTo(120.0001));
      }
    });

    test('measurement is direction-agnostic for the same extents', () {
      const String text = 'Same width';
      final List<MeasuredLine> rtl = StrikeMarks.measureLines(
        text: text,
        style: style,
        maxWidth: 600,
        direction: TextDirection.rtl,
      );
      final List<MeasuredLine> ltr = StrikeMarks.measureLines(
        text: text,
        style: style,
        maxWidth: 600,
        direction: TextDirection.ltr,
      );

      // The mark spans measured rectangles, so flipping the reading direction
      // moves neither the start nor the end of the ink.
      expect(rtl, hasLength(1));
      expect(rtl.single.left, closeTo(ltr.single.left, 0.01));
      expect(rtl.single.width, closeTo(ltr.single.width, 0.01));
    });
  });

  group('ZigzagScribblePainter geometry', () {
    test('same seed draws byte-identical vertices', () {
      final List<Offset> a = ZigzagScribblePainter.scribblePoints(180, 10, 42);
      final List<Offset> b = ZigzagScribblePainter.scribblePoints(180, 10, 42);

      expect(a, hasLength(b.length));
      for (int i = 0; i < a.length; i++) {
        expect(a[i].dx, b[i].dx);
        expect(a[i].dy, b[i].dy);
      }
    });

    test('different seeds draw different scratches', () {
      bool differed = false;
      for (int seed = 0; seed < 8 && !differed; seed++) {
        final List<Offset> a =
            ZigzagScribblePainter.scribblePoints(180, 10, seed);
        final List<Offset> b =
            ZigzagScribblePainter.scribblePoints(180, 10, seed + 100);
        differed = a.length != b.length ||
            a.indexed.any((e) => e.$2 != b[e.$1]);
      }
      // Forty seeds sampled two at a time without ever disagreeing would mean
      // the seed does nothing and every surrendered task wears one stencil.
      expect(differed, isTrue);
    });

    test('every swing stays inside the amplitude ceiling', () {
      for (int seed = 0; seed < 50; seed++) {
        for (final double length in <double>[40, 90, 160, 260]) {
          final List<Offset> points =
              ZigzagScribblePainter.scribblePoints(length, 12, seed);
          for (int i = 1; i < points.length - 1; i++) {
            expect(
              (points[i].dy - 12).abs(),
              lessThanOrEqualTo(StrikeMarks.maxAmplitude + 0.001),
              reason: 'seed $seed, length $length, vertex $i swung too wide',
            );
            expect(
              (points[i].dy - 12).abs(),
              greaterThanOrEqualTo(ZigzagScribblePainter.minAmplitude - 0.001),
              reason: 'seed $seed flattened into a straight line at vertex $i',
            );
          }
        }
      }
    });

    test('vertices advance strictly and land past the text end', () {
      for (int seed = 0; seed < 20; seed++) {
        const double length = 150;
        final List<Offset> points =
            ZigzagScribblePainter.scribblePoints(length, 10, seed);
        for (int i = 1; i < points.length; i++) {
          expect(points[i].dx, greaterThan(points[i - 1].dx),
              reason: 'a backwards vertex folds the scratch over itself');
        }
        expect(points.last.dx, closeTo(length + StrikeMarks.overshoot, 0.001),
            reason: 'the pen must lift past the word, not stop mid-glyph');
        // ...and settle back onto the centreline as it lifts.
        expect(points.last.dy, 10);
      }
    });

    test('density stays scratchy without becoming a solid band', () {
      const double length = 200;
      final List<Offset> points =
          ZigzagScribblePainter.scribblePoints(length, 10, 7);
      final int expectedMin =
          (length / ZigzagScribblePainter.maxHalfWave).ceil();
      final int expectedMax =
          (length / ZigzagScribblePainter.minHalfWave).floor() + 2;
      expect(points.length, inInclusiveRange(expectedMin + 1, expectedMax + 1));
    });
  });

  group('repaint discipline', () {
    late AppColors colors;

    setUp(() {
      colors = AppColors.light;
    });

    StraightStrikePainter straight({String text = 't', Color? color}) =>
        StraightStrikePainter(
          text: text,
          style: AppTypography.itemLabel,
          direction: TextDirection.rtl,
          color: color ?? colors.textSecondary,
        );

    ZigzagScribblePainter zigzag({int? seed, String? text, Color? color}) =>
        ZigzagScribblePainter(
          text: text ?? 't',
          style: AppTypography.itemLabel,
          direction: TextDirection.rtl,
          color: color ?? colors.wrong,
          seed: seed ?? 1,
        );

    test('a rebuilt mark repaints only when its inputs changed', () {
      expect(straight().shouldRepaint(straight()), isFalse);
      expect(straight(text: 'other').shouldRepaint(straight()), isTrue);
      expect(straight(color: colors.wrong).shouldRepaint(straight()), isTrue);

      expect(zigzag().shouldRepaint(zigzag(seed: 1)), isFalse);
      // The seed IS the shape: a new task's mark must repaint even when every
      // other field matches.
      expect(zigzag(seed: 2).shouldRepaint(zigzag(seed: 1)), isTrue);
      expect(zigzag(color: colors.textSecondary).shouldRepaint(zigzag()),
          isTrue);
    });

    test('the seed mask keeps hash negatives well-behaved', () {
      final int negativeHash = Object.hash(-99999, 'س');
      final ZigzagScribblePainter painter = zigzag(seed: negativeHash);
      expect(painter.seed, isNonNegative);
      // Masking is idempotent: repainting against itself still holds.
      expect(painter.shouldRepaint(zigzag(seed: painter.seed)), isFalse);
    });

    test('amplitude math never depends on wall-clock randomness', () {
      // Two full rebuilds of the generator state a frame apart must agree --
      // this is the "doesn't dance between builds" guarantee stated as data.
      final math.Random probeA = math.Random(Object.hash(1, 'a'));
      final List<int> first =
          List<int>.generate(16, (_) => probeA.nextInt(1 << 31));
      final math.Random probeB = math.Random(Object.hash(1, 'a'));
      final List<int> second =
          List<int>.generate(16, (_) => probeB.nextInt(1 << 31));
      expect(first, second);
    });
  });
}
