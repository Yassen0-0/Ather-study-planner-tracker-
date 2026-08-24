/// The Ather identity, drawn rather than rasterised.
///
/// ## The mark
///
/// A single **organic, hand-wobbled ring**: a closed curve through seven points
/// around a circle at irregular radii, so it reads as drawn rather than
/// constructed. It replaced the previous concentric-ring-and-dot mark in the
/// visual refresh.
///
/// It is one path, stroked twice:
///
/// 1. the whole ring in the foreground colour ([AtherBrandPalette.ring] —
///    black on light surfaces, white on dark), and
/// 2. the **first 27% of it** again in the brand [AtherBrandPalette.accent],
///    round-capped.
///
/// That 27% is the old mark's mastery arc, carried forward: the ring is the
/// whole syllabus, the coloured run is the part that has been proven. Drawing it
/// as a segment of a wobbling line rather than a perfect arc is the entire
/// difference between the two marks — the meaning did not change, the drawing
/// did.
///
/// ## Why a painter
///
/// A [CustomPainter] stays vector at any size — no stretching, no resampling, no
/// density bucket that is subtly soft — and costs no dependency and no decode.
/// The launcher PNGs, the Android splash bitmaps and every in-app placement are
/// all painted by [AtherMarkPainter] from the numbers below, which is what keeps
/// them from drifting apart.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The mark's proportions, verbatim from the design's `0 0 100 100` viewBox.
///
/// Everything here is in that 100-unit grid, and [AtherMarkPainter] applies one
/// uniform scale at paint time — so the mark can never stretch, distort or crop,
/// and these numbers stay directly comparable with the handoff's SVG.
abstract final class AtherMarkGeometry {
  /// The design's viewBox is square; so is every surface the mark is drawn onto.
  static const double grid = 100;

  /// `stroke-width` on both strokes.
  static const double strokeWidth = 8;

  /// How much of the ring the accent covers, as a fraction of the path's own
  /// length. The design expresses it as `stroke-dasharray: 27 100` against a
  /// `pathLength="100"` normalisation, which is exactly 27%.
  static const double sweepFraction = 0.27;

  /// Outer diameter of the drawn mark as a fraction of the square it is
  /// centred in.
  ///
  /// Unchanged from the previous mark on purpose. On Android's 108dp
  /// adaptive-icon canvas it lands the artwork at 66.0dp — exactly the
  /// guaranteed-visible safe zone — so the foreground layer still uses the
  /// artwork at its authored scale instead of being nudged to fit, and the
  /// in-app glyph is the same optical size it always was.
  static const double extent = 0.6113;

  /// The ring, in 100-grid coordinates. Seven points, Catmull-Rom, closed.
  ///
  /// Built fresh on each call rather than cached: a [Path] is mutable, and one
  /// shared instance handed to two painters is one `transform` away from a bug
  /// that only shows on the second frame.
  static Path ringPath() {
    return Path()
      ..moveTo(50, 22.48)
      ..cubicTo(58.46, 22.05, 72.24, 22.77, 77.02, 28.45)
      ..cubicTo(81.80, 34.13, 80.56, 47.48, 78.7, 56.55)
      ..cubicTo(76.84, 65.62, 72.65, 79.73, 65.83, 82.87)
      ..cubicTo(59.01, 86.01, 46.14, 79.54, 37.78, 75.37)
      ..cubicTo(29.42, 71.20, 17.61, 65.22, 15.68, 57.83)
      ..cubicTo(13.75, 50.44, 20.51, 36.94, 26.23, 31.05)
      ..cubicTo(31.95, 25.16, 41.54, 22.91, 50, 22.48)
      ..close();
  }
}

/// The three colours that separate one shipped variant from another.
@immutable
class AtherBrandPalette {
  const AtherBrandPalette({
    required this.plate,
    required this.ring,
    required this.accent,
  });

  /// The background square. Null on the glyph, which has none.
  final Color? plate;

  /// The full ring — the app's foreground colour, not a muted track. Black on a
  /// light surface, white on a dark one.
  final Color ring;

  /// The 27% mastery run. This is the brand blue, and it is the same value as
  /// `AppColors.accent` for the matching theme — the mark and the interface use
  /// one blue, not two that nearly match.
  final Color accent;

  /// `icon-mastery-light.svg`.
  static const AtherBrandPalette light = AtherBrandPalette(
    plate: Color(0xFFEFEFF2),
    ring: Color(0xFF000000),
    accent: Color(0xFF1B6EF3),
  );

  /// `icon-mastery-dark.svg`.
  static const AtherBrandPalette dark = AtherBrandPalette(
    plate: Color(0xFF000000),
    ring: Color(0xFFFFFFFF),
    accent: Color(0xFF4D9BFF),
  );

  /// `glyph-mastery.svg` — the light mark with the plate removed.
  static const AtherBrandPalette glyph = AtherBrandPalette(
    plate: null,
    ring: Color(0xFF000000),
    accent: Color(0xFF1B6EF3),
  );

  /// The glyph's dark-surface counterpart: the same subtraction applied to
  /// [dark]. Not a fourth authored asset — the plate is simply dropped.
  static const AtherBrandPalette glyphDark = AtherBrandPalette(
    plate: null,
    ring: Color(0xFFFFFFFF),
    accent: Color(0xFF4D9BFF),
  );

  /// The same palette with no background plate.
  AtherBrandPalette get withoutPlate =>
      AtherBrandPalette(plate: null, ring: ring, accent: accent);

  /// Resolves light vs dark from the ambient theme.
  ///
  /// **This is the only thing that decides which logo the app shows.** Every
  /// placement goes through it, so no call site branches on brightness itself
  /// and there is no second copy of a widget tree to keep in step.
  ///
  /// It reads `Theme.of(context).brightness` rather than the student's setting,
  /// which is what makes "follow the system" work for free: with
  /// [ThemeMode.system] the framework has already resolved the OS setting into
  /// the ambient brightness by the time this runs, so the mark follows without
  /// knowing the preference exists.
  ///
  /// The *launcher* icon is not resolved here and never changes — it is the
  /// light artwork baked into the Android resources. See PROJECT.md §7a.
  static AtherBrandPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  @override
  bool operator ==(Object other) =>
      other is AtherBrandPalette &&
      other.plate == plate &&
      other.ring == ring &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(plate, ring, accent);
}

/// Paints the mark from [AtherMarkGeometry] into whatever box it is given.
///
/// The scale is uniform on both axes and the artwork is centred **on its own
/// bounds**, not on the viewBox. The old mark was a circle and the two were the
/// same thing; the organic ring is deliberately lopsided, so centring it by
/// viewBox would leave it visibly off in a launcher mask. A non-square box
/// letterboxes rather than distorting.
class AtherMarkPainter extends CustomPainter {
  const AtherMarkPainter({required this.palette});

  final AtherBrandPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = size.shortestSide;
    if (side <= 0) return;

    final Color? plate = palette.plate;
    if (plate != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = plate,
      );
    }

    final Path path = AtherMarkGeometry.ringPath();

    // The drawn extent includes the stroke, which straddles the path: half of
    // it falls outside the geometric bounds on every side.
    final Rect bounds = path.getBounds().inflate(
      AtherMarkGeometry.strokeWidth / 2,
    );
    final double fit =
        (side * AtherMarkGeometry.extent) / math.max(bounds.longestSide, 1);

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(fit)
      ..translate(-bounds.center.dx, -bounds.center.dy);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AtherMarkGeometry.strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = palette.ring;

    canvas.drawPath(path, stroke);

    // The accent run, measured along the path itself rather than swept through
    // an angle: the ring is not a circle, so there is no angle to sweep.
    for (final ui.PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(
          0,
          metric.length * AtherMarkGeometry.sweepFraction,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AtherMarkGeometry.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..color = palette.accent,
      );
      // One subpath. Anything after the first would be a second ring.
      break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(AtherMarkPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
