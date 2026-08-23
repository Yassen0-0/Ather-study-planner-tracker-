import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Strike-through marks drawn **over** a task title, never through relayout.
///
/// Three states, three marks, one grammar borrowed from a teacher's pen:
///
/// * **Done** — a clean straight line ([StraightStrikePainter]) in
///   `textSecondary`, quiet the way a finished thing is quiet. Beside it the
///   row keeps the tick it already had in the leading disc, so success reads
///   line-and-check together.
/// * **Surrendered** — a nervous zigzag scribble ([ZigzagScribblePainter]) in
///   the exam-paper red. متعرجة عن قصد: التعرّج هو الإحساس بالعصبية والاستسلام
///   الذي لا يستطيع خط مستقيم حمله. It is counted as a failure elsewhere; here
///   it only has to look like one.
///
/// Every painter here is **paint-only**: it hangs as a `foregroundPainter` on a
/// [CustomPaint] whose child is the existing [Text], so laying the mark out
/// costs the tree nothing — no re-wrap, no re-flow, no second Text. The marks
/// are also **still**: no draw-on reveal exists to suppress, which is how they
/// respect `prefersReducedMotion` by construction — the final state is the
/// first state.
///
/// All of them are RTL-safe by measurement, not by mirroring: each mark is laid
/// against the *measured* extents of the text's laid-out lines
/// ([StrikeMarks.measureLines]), which are direction-agnostic rectangles. An
/// Arabic line and an English line of the same width get the same mark.
abstract final class StrikeMarks {
  /// How far past the text's end a mark may run, in logical pixels.
  ///
  /// A line that stops dead at the last glyph looks typeset; running a hair
  /// past it is what a pen does. Kept inside 4–6px so the overshoot reads as
  /// life and not as missing the word.
  static const double overshoot = 5.0;

  /// Upper bound for the scribble's swing off the centreline.
  ///
  /// Exposed because it is asserted: a nervous scribble is bounded nerves, not
  /// noise. Anything swinging wider stops being handwriting and becomes static.
  static const double maxAmplitude = 4.2;

  /// Measures where each laid-out text line actually sits, so a mark can cross
  /// the glyphs rather than the box.
  ///
  /// Returns one entry per line the text occupies under [maxLines] (ellipsis
  /// included — the ellipsis is ink like any other). The vertical centre is
  /// optically corrected upward from the geometric middle: a strike sits
  /// through the x-height, roughly a third of the way down the ascent, which
  /// is where every handwritten correction lands.
  @visibleForTesting
  static List<MeasuredLine> measureLines({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextDirection direction,
    TextScaler textScaler = TextScaler.noScaling,
    int maxLines = 2,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: maxLines,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);

    return <MeasuredLine>[
      for (final LineMetrics m in painter.computeLineMetrics())
        MeasuredLine(
          left: m.left,
          width: m.width,
          // baseline - ~35% of the ascent: through the x-height, above the
          // descenders, under the capitals. The geometric midpoint of the line
          // box reads visibly low against Arabic type especially.
          strikeY: m.baseline - m.ascent * 0.35,
        ),
    ];
  }
}

/// One laid-out line of text, in the coordinates [CustomPaint] paints in.
@visibleForTesting
class MeasuredLine {
  const MeasuredLine({
    required this.left,
    required this.width,
    required this.strikeY,
  });

  /// Where the line's ink starts, horizontally.
  final double left;

  /// How far the ink runs — glyphs plus punctuation plus, on the last line of
  /// a clipped text, the ellipsis.
  final double width;

  /// The vertical position the mark is drawn through.
  final double strikeY;

  /// Where the ink ends with the pen's overshoot applied.
  double get end => left + width + StrikeMarks.overshoot;
}

/// The success mark: one clean horizontal line per laid-out text line.
///
/// Straight because finishing is calm. The only concession to a human hand is
/// the overshoot past the line's end — a pen lifted slightly late.
class StraightStrikePainter extends CustomPainter {
  /// Creates the mark for [text] rendered in [style] inside the painted box.
  ///
  /// [color] arrives resolved (`context.colors.textSecondary` at the call
  /// site) because painters live below the theme's convenience accessors.
  StraightStrikePainter({
    required this.text,
    required this.style,
    required this.direction,
    required this.color,
    this.textScaler = TextScaler.noScaling,
    this.maxLines = 2,
  });

  /// The struck text, re-measured against the painted width.
  final String text;

  /// The exact style the child [Text] renders in — the mark must sit on the
  /// same glyphs, so it measures with the same ruler.
  final TextStyle style;

  /// The ambient reading direction. Used only for measurement; the resulting
  /// rectangles are direction-free.
  final TextDirection direction;

  /// `textSecondary`: quieter than the surviving text, because the words are
  /// finished being important.
  final Color color;

  final TextScaler textScaler;
  final int maxLines;

  /// The stroke weight. Two logical pixels: present at arm's length, hairline
  /// beside the 2.2 scribble it must not compete with.
  static const double strokeWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final MeasuredLine line in StrikeMarks.measureLines(
      text: text,
      style: style,
      maxWidth: size.width,
      direction: direction,
      textScaler: textScaler,
      maxLines: maxLines,
    )) {
      // One segment per line. Clamped at the box edge plus the overshoot so a
      // full-width line bleeds into the card padding by exactly the pen lift
      // and no further.
      canvas.drawLine(
        Offset(line.left, line.strikeY),
        Offset(math.min(line.end, size.width + StrikeMarks.overshoot),
            line.strikeY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StraightStrikePainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.direction != direction ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.maxLines != maxLines;
}

/// The surrender mark: an irregular zigzag scratched across the title.
///
/// متعرجة، توحي بالإهمال والعصبية والاستسلام — the segments deliberately refuse
/// the even rhythm a ruler produces. Amplitude and half-wavelength are drawn
/// per-point from a generator seeded **per task**
/// ([Object.hash] of the id, falling back to title+day for callers without
/// one), so a given task carries the *same* scratch every build: the mark is
/// a fact about the task, not a screensaver. Between tasks the seeds differ,
/// which is the point — forty surrenders should look like forty bad mornings,
/// not one stencil.
class ZigzagScribblePainter extends CustomPainter {
  /// Creates the mark for [text], shaped by [seed].
  ZigzagScribblePainter({
    required this.text,
    required this.style,
    required this.direction,
    required this.color,
    required int seed,
    this.textScaler = TextScaler.noScaling,
    this.maxLines = 2,
  }) : seed = seed & 0x7fffffff;

  /// The struck text.
  final String text;

  /// The style the child [Text] renders in; see [StraightStrikePainter.style].
  final TextStyle style;

  final TextDirection direction;

  /// The exam-paper red (`colors.wrong`). A failure colour for a failure.
  final Color color;

  /// Deterministic shape source. Masked positive so `Object.hash`'s negative
  /// results cannot flip the generator's behaviour between platforms.
  final int seed;

  final TextScaler textScaler;
  final int maxLines;

  /// The stroke weight. A touch heavier than the straight strike: the red has
  /// to carry the sentence "this one did not go well" without shouting.
  static const double strokeWidth = 2.2;

  /// Half-wavelength range, logical pixels. Short enough to read as scratchy,
  /// long enough that a two-line title is not a solid band.
  static const double minHalfWave = 5.0;
  static const double maxHalfWave = 13.0;

  /// Amplitude floor. Below this the zigzag flattens into the straight strike
  /// it must never be mistaken for.
  static const double minAmplitude = 1.4;

  /// Builds the scribble's vertices for one line of [length], centred on
  /// [centerY].
  ///
  /// Pure and deterministic: same `(length, seed)` in, byte-identical vertex
  /// list out — which is what lets tests assert bounds here instead of
  /// screenshotting pixels. The walk alternates sides of the centreline every
  /// vertex, with independently randomised step and swing, and settles onto
  /// the centreline for a short tail past the text's end (the pen lifting).
  @visibleForTesting
  static List<Offset> scribblePoints(double length, double centerY, int seed) {
    final math.Random random = math.Random(seed & 0x7fffffff);
    final List<Offset> points = <Offset>[Offset(0, centerY)];

    double x = 0;
    bool above = random.nextBool();
    while (x < length) {
      above = !above;
      final double step =
          minHalfWave + random.nextDouble() * (maxHalfWave - minHalfWave);
      final double swing =
          minAmplitude + random.nextDouble() * (StrikeMarks.maxAmplitude -
              minAmplitude);
      x = math.min(x + step, length);
      points.add(Offset(x, centerY + (above ? -swing : swing)));
    }

    // The tail: past the text's end, back to the centreline — a pen finishing
    // a stroke, not a signal cutting out. Same overshoot the straight strike
    // uses, so the two marks end at the same place for the same line.
    points.add(Offset(length + StrikeMarks.overshoot, centerY));
    return points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final List<MeasuredLine> lines = StrikeMarks.measureLines(
      text: text,
      style: style,
      maxWidth: size.width,
      direction: direction,
      textScaler: textScaler,
      maxLines: maxLines,
    );

    for (int i = 0; i < lines.length; i++) {
      final MeasuredLine line = lines[i];
      // Each line gets its own shape: a constant seed across lines would stamp
      // the same zigzag twice and turn two rows of handwriting into a stencil.
      final List<Offset> points =
          scribblePoints(line.width, line.strikeY, seed + i * 7919);
      final Path path = Path()
        ..moveTo(line.left + points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        // Straight segments, not curves: sharp corners are what make the mark
        // read as scratched rather than decorative.
        path.lineTo(line.left + points[i].dx, points[i].dy);
      }

      final Paint paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.miter
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);

      // Second pass, 1px down-right at reduced opacity: the double-stroke of
      // a hand that went over its own line. Derived from the same vertices,
      // so it cannot drift out of registration between frames.
      canvas.save();
      canvas.translate(1, 1);
      canvas.drawPath(path, paint..color = color.withAlpha(115));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ZigzagScribblePainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.seed != seed ||
      oldDelegate.direction != direction ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.maxLines != maxLines;
}

/// The surrender control's icon: an outlined circle with a diagonal slash.
///
/// The app's icon family has no flag, and borrowing a Material one would put a
/// second drawing style on the row — the same mistake the share glyph was
/// introduced to remove. A slashed circle is the universal "struck out", drawn
/// here with the same stroke weights the family uses, and it doubles as the
/// button's resting face: the mark previews the act.
class SurrenderMarkIconPainter extends CustomPainter {
  /// Creates the icon in [color] — `textSecondary` at rest, `colors.wrong`
  /// once the task is surrendered.
  const SurrenderMarkIconPainter({required this.color});

  final Color color;

  /// Circle radius inside the square canvas the caller provides (~20px).
  static const double _radius = 7.2;

  /// How far the slash pokes past the rim — the same pen-lift overshoot the
  /// title marks use, kept consistent on purpose.
  static const double _slashOvershoot = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, _radius, paint);

    // Top-left to bottom-right, extended past the rim on both ends.
    final double d = (_radius + _slashOvershoot) * math.sqrt1_2;
    canvas.drawLine(center - Offset(d, d), center + Offset(d, d), paint);
  }

  @override
  bool shouldRepaint(SurrenderMarkIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
