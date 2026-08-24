import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Every icon in the app, hand-drawn to one specification.
///
/// The design allows exactly one icon family: outline strokes at 1.7-2.2,
/// black or grey, 15-26px. Material's icon set is a different family with a
/// different optical weight, and mixing the two was one of the things the
/// redesign set out to remove -- so the handful of glyphs the product actually
/// needs are drawn here from the design's own path data instead.
///
/// The only filled glyphs are the ones the design explicitly fills: the home
/// tab, the "more" dots, and a white tick inside a solid black or green disc.
enum AtherGlyph {
  // Tab bar. Four destinations, and no "+" — the raised centre button was
  // removed with the visual refresh (§3.28) and the glyph went with it, so
  // there is nothing left to draw one from by habit.
  home,
  review,
  chart,

  /// The tasks tab: a tick beside three list lines.
  tasks,

  // Header and rows
  /// A cog, not a sun. It was drawn as a circle with eight straight radial
  /// spokes for the whole life of the app, which reads as a sun at every size
  /// this icon is used at.
  settings,
  edit,

  /// The share sheet's affordance, in the dashboard and chapter-report
  /// headers. It replaced the one Material glyph left in the app
  /// (`Icons.ios_share`), whose optical weight sat visibly apart from the
  /// hand-drawn cog and chevron beside it — one icon family means zero
  /// Material imports that paint.
  share,

  /// Chevron pointing along the reading direction's "forward". Drawn pointing
  /// right; the header flips it for RTL by placing it on the correct side.
  back,
  close,
  chevron,

  /// The one "add" affordance drawn as geometry.
  ///
  /// The enum note above says there was nothing left to draw a "+" from by
  /// habit, because the raised centre tab-bar button was removed with the
  /// visual refresh. This is not that button coming back: it is a 20px control
  /// beside a section heading, and it exists because "add a subject" had no
  /// home outside Settings. Drawn rather than typed for the reason the eye
  /// toggle below was redrawn -- a control is not the place for a rebus.
  plus,

  /// The password field's "show" toggle, and its "hide" partner below.
  ///
  /// These are the last two controls in the app that were drawn with type
  /// rather than geometry: the toggle printed the literal strings `•••` and
  /// `———`, which is a clever workaround and reads as one — Latin punctuation
  /// inside an Arabic form, at a weight and optical centre no other control in
  /// the app shares. A control is not the place for a rebus.
  eye,

  /// [eye] with its pupil dropped and a slash across it. The pupil goes rather
  /// than being crossed: a 1.9 stroke through a 3.1 circle meets itself at the
  /// centre and fills in as a blot at the 18px this is actually drawn at.
  eyeOff,

  // State
  check,

  /// Circle with a dashed vertical bar -- the overdue mark. Decay is always an
  /// icon *and* a colour, never colour alone.
  overdue,
  beforeAfterArrow,

  // Subjects
  biology,
  physics,
  chemistry,
  english,
}

class AtherIcon extends StatelessWidget {
  const AtherIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth,
    this.selection = 1,
  });

  final AtherGlyph glyph;
  final double size;

  /// Null means the theme's primary text colour.
  final Color? color;
  final double? strokeWidth;

  /// How selected this glyph is, 0..1 — the bottom bar's weight axis.
  ///
  /// Only the four tab glyphs read it; everything else is drawn the same at
  /// every value. It is a *paint* property, never a path change: [AtherGlyph.home]
  /// fades its fill in over the outline it always carries, and `review`, `chart`
  /// and `tasks` thicken their stroke. Defaults to 1 so the dozens of static call
  /// sites keep the weight they were authored at.
  ///
  /// An explicit [strokeWidth] wins: the caller has then asked for a specific
  /// weight and the axis has nothing left to say.
  final double selection;

  @override
  Widget build(BuildContext context) {
    // Icons are geometry, not text: they must not mirror or resize with the
    // ambient text direction or the user's font scale.
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph: glyph,
          color: color ?? context.colors.textPrimary,
          strokeWidth: strokeWidth,
          selection: selection.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    this.strokeWidth,
    this.selection = 1,
  });

  final AtherGlyph glyph;
  final Color color;
  final double? strokeWidth;
  final double selection;

  /// The weight axis: [from] unselected, [to] selected, unless the caller pinned
  /// a width of their own.
  double _weight(double from, double to) =>
      strokeWidth ?? from + (to - from) * selection;

  @override
  void paint(Canvas canvas, Size size) {
    // Every path below is authored in the design's 24x24 grid (the before/after
    // arrow in 26x14) and scaled once here, so the source numbers stay
    // comparable with the reference prototype.
    final double grid = glyph == AtherGlyph.beforeAfterArrow ? 26 : 24;
    final scale = size.width / grid;
    canvas
      ..save()
      ..scale(scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      // The canvas is already scaled to the 24-grid, so widths are authored in
      // grid units and stay optically identical at any icon size.
      ..strokeWidth = strokeWidth ?? _defaultStroke;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case AtherGlyph.home:
        // The one glyph whose selected state is a fill rather than a weight, so
        // it carries its outline at every value and fades the fill in over it.
        // Painting the fill under the stroke (not instead of it) is what keeps
        // the silhouette from growing by half a stroke as it selects.
        final house = Path()
          ..moveTo(3, 10.5)
          ..lineTo(12, 3)
          ..lineTo(21, 10.5)
          ..lineTo(21, 20)
          ..lineTo(20, 21)
          ..lineTo(15, 21)
          ..lineTo(15, 15)
          ..lineTo(9, 15)
          ..lineTo(9, 21)
          ..lineTo(4, 21)
          ..lineTo(3, 20)
          ..close();
        stroke.strokeWidth = strokeWidth ?? 1.9;
        if (selection > 0) {
          canvas.drawPath(
            house,
            fill..color = color.withValues(alpha: selection),
          );
        }
        canvas.drawPath(house, stroke);

      case AtherGlyph.review:
        stroke.strokeWidth = _weight(2, 3);
        final heads = <Path>[
          Path()
            ..moveTo(17.5, 3)
            ..lineTo(17.5, 7)
            ..lineTo(13.5, 7),
          Path()
            ..moveTo(6.5, 21)
            ..lineTo(6.5, 17)
            ..lineTo(10.5, 17),
        ];
        canvas
          ..drawPath(
            Path()
              ..moveTo(4, 12)
              ..arcToPoint(
                const Offset(17.6, 6.3),
                radius: const Radius.circular(8),
              ),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(20, 12)
              ..arcToPoint(
                const Offset(6.4, 17.7),
                radius: const Radius.circular(8),
              ),
            stroke,
          );
        // The arrowheads are the same two authored polylines either way: the
        // selected state fills the corner they already enclose, it does not add
        // a triangle. Fill first, stroke over it, same as the house above.
        if (selection > 0) {
          fill.color = color.withValues(alpha: selection);
          for (final head in heads) {
            canvas.drawPath(head, fill);
          }
        }
        for (final head in heads) {
          canvas.drawPath(head, stroke);
        }

      case AtherGlyph.chart:
        stroke.strokeWidth = _weight(2.1, 3.4);
        canvas
          ..drawLine(const Offset(4, 19), const Offset(4, 11), stroke)
          ..drawLine(const Offset(9.3, 19), const Offset(9.3, 5), stroke)
          ..drawLine(const Offset(14.7, 19), const Offset(14.7, 11), stroke)
          ..drawLine(const Offset(20, 19), const Offset(20, 8), stroke);

      case AtherGlyph.tasks:
        stroke.strokeWidth = _weight(1.9, 2.9);
        canvas
          // The tick sits over the first line, so the glyph reads as "a list
          // being worked through" rather than as three unrelated rules.
          ..drawPath(
            Path()
              ..moveTo(3.5, 7)
              ..lineTo(5.5, 9)
              ..lineTo(9.5, 5),
            stroke,
          )
          ..drawLine(const Offset(12.5, 7), const Offset(20.5, 7), stroke)
          ..drawLine(const Offset(3.5, 13), const Offset(20.5, 13), stroke)
          ..drawLine(const Offset(3.5, 19), const Offset(20.5, 19), stroke);

      case AtherGlyph.settings:
        stroke.strokeWidth = strokeWidth ?? 1.8;
        canvas
          ..drawPath(_cogPath(), stroke)
          ..drawCircle(const Offset(12, 12), 3, stroke);

      case AtherGlyph.edit:
        stroke.strokeWidth = strokeWidth ?? 1.8;
        canvas.drawPath(
          Path()
            ..moveTo(4, 20)
            ..lineTo(5, 16)
            ..lineTo(16, 5)
            ..lineTo(19, 8)
            ..lineTo(8, 19)
            ..close(),
          stroke,
        );

      case AtherGlyph.share:
        // The iOS paper-plane-free share mark: a tray open at the top, with
        // the arrow rising out of it. Drawn on the same 24-grid and stroke as
        // the header family around it (see [settings] and [back]), which is
        // the entire point — the Material original carried a different weight
        // and sat in the two most-seen headers in the app.
        stroke.strokeWidth = strokeWidth ?? 1.9;
        canvas.drawPath(
          // The tray: three sides of a rounded-corner box, its top edge split
          // to leave a gap the arrow leaves through.
          Path()
            ..moveTo(9.2, 10)
            ..lineTo(6.5, 10)
            ..lineTo(6.5, 20.5)
            ..lineTo(17.5, 20.5)
            ..lineTo(17.5, 10)
            ..lineTo(14.8, 10),
          stroke,
        );
        canvas
          ..drawLine(const Offset(12, 13.2), const Offset(12, 3), stroke)
          ..drawPath(
            Path()
              ..moveTo(8.4, 6.4)
              ..lineTo(12, 3)
              ..lineTo(15.6, 6.4),
            stroke,
          );

      case AtherGlyph.back:
        stroke.strokeWidth = strokeWidth ?? 2.4;
        canvas.drawPath(
          Path()
            ..moveTo(9, 6)
            ..lineTo(15, 12)
            ..lineTo(9, 18),
          stroke,
        );

      case AtherGlyph.chevron:
        stroke.strokeWidth = strokeWidth ?? 2.2;
        canvas.drawPath(
          Path()
            ..moveTo(15, 6)
            ..lineTo(9, 12)
            ..lineTo(15, 18),
          stroke,
        );

      case AtherGlyph.close:
        stroke.strokeWidth = strokeWidth ?? 2.2;
        canvas
          ..drawLine(const Offset(6, 6), const Offset(18, 18), stroke)
          ..drawLine(const Offset(18, 6), const Offset(6, 18), stroke);

      case AtherGlyph.plus:
        // The same two strokes as `close`, unrotated, on the same 6..18 span,
        // so the two read as one family at the same optical weight.
        stroke.strokeWidth = strokeWidth ?? 2.2;
        canvas
          ..drawLine(const Offset(12, 6), const Offset(12, 18), stroke)
          ..drawLine(const Offset(6, 12), const Offset(18, 12), stroke);

      case AtherGlyph.eye:
      case AtherGlyph.eyeOff:
        stroke.strokeWidth = strokeWidth ?? 1.9;
        // A lens: two mirrored lid curves meeting at a point on each side. The
        // points are where the round join earns its keep -- closed with a
        // corner the same path reads as a leaf, which is the wrong object.
        canvas.drawPath(
          Path()
            ..moveTo(2.6, 12)
            ..cubicTo(5.5, 7.5, 8.5, 5, 12, 5)
            ..cubicTo(15.5, 5, 18.5, 7.5, 21.4, 12)
            ..cubicTo(18.5, 16.5, 15.5, 19, 12, 19)
            ..cubicTo(8.5, 19, 5.5, 16.5, 2.6, 12)
            ..close(),
          stroke,
        );
        if (glyph == AtherGlyph.eye) {
          canvas.drawCircle(const Offset(12, 12), 3.1, stroke);
        } else {
          canvas.drawLine(
            const Offset(4.4, 4.4),
            const Offset(19.6, 19.6),
            stroke,
          );
        }

      case AtherGlyph.check:
        stroke.strokeWidth = strokeWidth ?? 3;
        canvas.drawPath(
          Path()
            ..moveTo(5, 12.5)
            ..lineTo(9.5, 17)
            ..lineTo(19, 7),
          stroke,
        );

      case AtherGlyph.overdue:
        stroke.strokeWidth = strokeWidth ?? 1.9;
        canvas.drawCircle(const Offset(12, 12), 9, stroke);
        // The bar is dashed on purpose: overdue must be distinguishable from
        // "weak" without relying on the red, which both states share.
        var y = 7.5;
        while (y < 12.5) {
          final end = (y + 1.8).clamp(0.0, 12.5);
          canvas.drawLine(Offset(12, y), Offset(12, end), stroke);
          y += 1.8 + 2.6;
        }

      case AtherGlyph.beforeAfterArrow:
        stroke.strokeWidth = strokeWidth ?? 2;
        canvas
          ..drawLine(const Offset(26, 7), const Offset(2, 7), stroke)
          ..drawPath(
            Path()
              ..moveTo(9, 1)
              ..lineTo(2, 7)
              ..lineTo(9, 13),
            stroke,
          );

      // A knee joint: the femur's condyles above, the tibia and fibula below,
      // each with a rounded notch facing the other. Biology on this syllabus is
      // human biology, and a joint is the one structure a student meets in every
      // chapter of it -- more specific than a generic cell or leaf.
      case AtherGlyph.biology:
        stroke.strokeWidth = strokeWidth ?? 1.8;
        canvas
          // Femur, ending in two condyles.
          ..drawPath(
            Path()
              ..moveTo(8.8, 0.8)
              ..lineTo(8.8, 4.9)
              ..cubicTo(8.8, 6.2, 6, 7.4, 6, 9.6)
              ..cubicTo(6, 11.5, 7.6, 12.6, 9, 12.6)
              ..cubicTo(10.2, 12.6, 10.9, 11.6, 12, 11.6)
              ..cubicTo(13.1, 11.6, 13.8, 12.6, 15, 12.6)
              ..cubicTo(16.4, 12.6, 18, 11.5, 18, 9.6)
              ..cubicTo(18, 7.4, 15.2, 6.2, 15.2, 4.9)
              ..lineTo(15.2, 0.8),
            stroke,
          )
          // Tibia: the wider shaft, plateau first.
          ..drawPath(
            Path()
              ..moveTo(6.2, 13.6)
              ..cubicTo(7.4, 13.6, 8.2, 14.4, 9.3, 14.4)
              ..cubicTo(10.4, 14.4, 11, 13.4, 12, 13.4)
              ..cubicTo(13, 13.4, 13.6, 14.4, 14.7, 14.4)
              ..cubicTo(15.8, 14.4, 16.6, 13.6, 17.8, 13.6)
              ..cubicTo(18.5, 13.6, 18.6, 14.7, 18.2, 15.9)
              ..cubicTo(17.7, 17.4, 15.2, 18.4, 15.2, 19.8)
              ..lineTo(15.2, 23.2),
            stroke,
          )
          // Fibula, the slimmer bone beside it.
          ..drawPath(
            Path()
              ..moveTo(6.2, 13.6)
              ..cubicTo(5.5, 13.6, 5.4, 14.7, 5.8, 15.9)
              ..cubicTo(6.3, 17.4, 8.8, 18.4, 8.8, 19.8)
              ..lineTo(8.8, 23.2),
            stroke,
          )
          ..drawLine(
            const Offset(12.9, 20.5),
            const Offset(12.9, 23.2),
            stroke,
          );

      // A horseshoe magnet with two pole tips. Rotated 205 degrees about the
      // icon's centre so it tilts up-and-to-the-right rather than sitting flat,
      // which is what stops it reading as a plain "U".
      case AtherGlyph.physics:
        stroke.strokeWidth = strokeWidth ?? 1.8;
        canvas
          ..save()
          ..translate(12, 12)
          ..rotate(205 * math.pi / 180)
          ..translate(-12, -12)
          // Outer arm.
          ..drawPath(
            Path()
              ..moveTo(4, 20)
              ..lineTo(4, 11.5)
              ..arcToPoint(
                const Offset(20, 11.5),
                radius: const Radius.circular(8),
              )
              ..lineTo(20, 20),
            stroke,
          )
          // Inner arm.
          ..drawPath(
            Path()
              ..moveTo(9, 20)
              ..lineTo(9, 11.5)
              ..arcToPoint(
                const Offset(15, 11.5),
                radius: const Radius.circular(3),
              )
              ..lineTo(15, 20),
            stroke,
          )
          // The two pole tips.
          ..drawLine(const Offset(4, 16), const Offset(9, 16), stroke)
          ..drawLine(const Offset(15, 16), const Offset(20, 16), stroke)
          ..restore();

      case AtherGlyph.chemistry:
        stroke.strokeWidth = strokeWidth ?? 1.9;
        canvas
          ..drawLine(const Offset(10, 3), const Offset(14, 3), stroke)
          ..drawPath(
            Path()
              ..moveTo(10.5, 3)
              ..lineTo(10.5, 9)
              ..lineTo(5.8, 18.4)
              ..arcToPoint(
                const Offset(7.6, 21),
                radius: const Radius.circular(2),
                clockwise: false,
              )
              ..lineTo(16.4, 21)
              ..arcToPoint(
                const Offset(18.2, 18.4),
                radius: const Radius.circular(2),
                clockwise: false,
              )
              ..lineTo(13.5, 9)
              ..lineTo(13.5, 3),
            stroke,
          );

      // An open book: a spine with a leaf falling away on each side. The old
      // chevrons read as a code bracket, which is the wrong subject entirely.
      case AtherGlyph.english:
        stroke.strokeWidth = strokeWidth ?? 1.8;
        canvas
          ..drawLine(const Offset(12, 7.6), const Offset(12, 20.2), stroke)
          ..drawPath(
            Path()
              ..moveTo(12, 7.6)
              ..cubicTo(10, 6, 7, 5.4, 3.6, 5.7)
              ..lineTo(3.6, 17.5)
              ..cubicTo(7, 17.2, 10, 18.4, 12, 20.2),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(12, 7.6)
              ..cubicTo(14, 6, 17, 5.4, 20.4, 5.7)
              ..lineTo(20.4, 17.5)
              ..cubicTo(17, 17.2, 14, 18.4, 12, 20.2),
            stroke,
          );
    }

    canvas.restore();
  }

  double get _defaultStroke => 1.9;

  /// The cog silhouette behind [AtherGlyph.settings], in the design's 24-grid.
  ///
  /// Eight teeth walked in polar coordinates rather than forty hand-typed
  /// points: the constants below are the shape's actual parameters, so the tooth
  /// count or depth can be adjusted without re-deriving a path by hand.
  ///
  /// It starts at twelve o'clock, which is what keeps the cog symmetric about
  /// the vertical and reading as upright at the 19px the header uses.
  static Path _cogPath() {
    const centre = Offset(12, 12);
    const outerR = 8.7;
    const innerR = 6.9;
    const teeth = 8;
    const step = 2 * math.pi / teeth;

    // Half a tooth's flat top, and the shoulder it falls away over. ~11° and ~6°.
    const half = 0.19;
    const shoulder = 0.105;

    Offset at(double radius, double angle) => Offset(
      centre.dx + radius * math.cos(angle),
      centre.dy + radius * math.sin(angle),
    );

    final path = Path();
    for (var i = 0; i < teeth; i++) {
      final c = -math.pi / 2 + i * step;
      final start = at(outerR, c - half);
      if (i == 0) path.moveTo(start.dx, start.dy);

      final toothEnd = at(outerR, c + half);
      path.arcToPoint(toothEnd, radius: const Radius.circular(outerR));

      final valleyStart = at(innerR, c + half + shoulder);
      path.lineTo(valleyStart.dx, valleyStart.dy);

      final valleyEnd = at(innerR, c + step - half - shoulder);
      path.arcToPoint(valleyEnd, radius: const Radius.circular(innerR));

      final nextTooth = at(outerR, c + step - half);
      path.lineTo(nextTooth.dx, nextTooth.dy);
    }
    // The last lineTo lands back on the first point, so this closes a
    // zero-length gap and joins the stroke cleanly instead of leaving a seam.
    return path..close();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.selection != selection;
}

/// A white tick inside a solid disc — the one place a filled icon is allowed.
///
/// Used for the mastered-chapter badge (green), completed week days (black),
/// the review-centre success state and the celebration.
class CheckDisc extends StatelessWidget {
  const CheckDisc({
    super.key,
    required this.size,
    this.color,
    this.checkSize,
    this.strokeWidth,
  });

  final double size;

  /// Null means the theme's green.
  final Color? color;
  final double? checkSize;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? context.colors.right,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AtherIcon(
        AtherGlyph.check,
        size: checkSize ?? size * 0.52,
        color: context.colors.onState,
        strokeWidth: strokeWidth ?? 3,
      ),
    );
  }
}
