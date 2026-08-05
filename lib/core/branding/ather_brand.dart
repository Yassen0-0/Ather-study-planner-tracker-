/// The Ather identity, drawn rather than rasterised.
///
/// The shipped source of truth is the three SVGs in `assets/branding/`:
///
/// * `icon-mastery-light.svg` — the official app icon, and the in-app mark on a
///   light surface.
/// * `icon-mastery-dark.svg`  — the same mark on a dark surface.
/// * `glyph-mastery.svg`      — the mark with no background plate, for anywhere
///   a standalone symbol is wanted.
///
/// All three are the *same geometry* differing only in four colours, so this
/// file holds the geometry once ([AtherMarkGeometry]) and the colours three
/// times ([AtherBrandPalette]). Nothing here re-implements a second mark: the
/// launcher PNGs, the Android splash bitmaps and every in-app placement are all
/// painted by [AtherMarkPainter] from these numbers, which is what keeps them
/// from drifting apart.
///
/// It is a painter and not an `AssetImage` because the mark is four primitives.
/// A `CustomPainter` stays vector at any size — no stretching, no resampling,
/// no density bucket that is subtly soft — and costs no dependency and no
/// decode. The SVGs remain the authored artefact; this is their transcription.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The mark's proportions, verbatim from the 1024×1024 SVG viewBox.
///
/// Every consumer works in these coordinates and applies one uniform scale, so
/// the mark can never stretch, distort or crop.
abstract final class AtherMarkGeometry {
  /// The SVG viewBox is square; so is every surface the mark is drawn onto.
  static const double canvas = 1024;

  /// `cx` and `cy` on all three circles.
  static const double center = canvas / 2;

  /// `r` on the track and the progress arc.
  static const double radius = 290;

  /// `stroke-width` on both rings.
  static const double strokeWidth = 46;

  /// `r` on the solid centre dot.
  static const double coreRadius = 66;

  /// The `stroke-dasharray` "on" length. The SVG pairs it with a 1822 gap,
  /// which is the ring's own circumference — that is what makes the dash a
  /// single arc rather than a repeating pattern.
  static const double dashLength = 1640;

  /// How much of the ring the green arc covers: 1640 / 2πr ≈ 0.900.
  static double get sweepFraction => dashLength / (2 * math.pi * radius);

  /// The arc's sweep in radians, ≈ 324°.
  static double get sweepRadians => sweepFraction * 2 * math.pi;

  /// The arc starts at twelve o'clock — the SVG's `rotate(-90 512 512)`.
  static const double startRadians = -math.pi / 2;

  /// Outer diameter of the drawn mark as a fraction of the canvas.
  ///
  /// `(2 × 290 + 46) / 1024 ≈ 0.6113`. On Android's 108dp adaptive-icon canvas
  /// that lands the mark at 66.0dp — exactly the guaranteed-visible safe zone —
  /// which is why the foreground layer can use the artwork at its authored
  /// scale instead of being nudged to fit.
  static const double extent = (2 * radius + strokeWidth) / canvas;
}

/// The four colours that separate one shipped variant from another.
@immutable
class AtherBrandPalette {
  const AtherBrandPalette({
    required this.plate,
    required this.track,
    required this.progress,
    required this.core,
  });

  /// The background square. Null on the glyph, which has none.
  final Color? plate;

  /// The full unfilled ring.
  final Color track;

  /// The mastery arc. Deliberately identical across variants — it is the one
  /// colour of the brand.
  final Color progress;

  /// The solid centre dot.
  final Color core;

  /// `icon-mastery-light.svg`.
  static const AtherBrandPalette light = AtherBrandPalette(
    plate: Color(0xFFEFEFF2),
    track: Color(0xFFDCDCE1),
    progress: Color(0xFF34C759),
    core: Color(0xFF000000),
  );

  /// `icon-mastery-dark.svg`.
  static const AtherBrandPalette dark = AtherBrandPalette(
    plate: Color(0xFF000000),
    track: Color(0xFF2A2A2E),
    progress: Color(0xFF34C759),
    core: Color(0xFFFFFFFF),
  );

  /// `glyph-mastery.svg` — the light mark with the plate removed.
  static const AtherBrandPalette glyph = AtherBrandPalette(
    plate: null,
    track: Color(0xFFDCDCE1),
    progress: Color(0xFF34C759),
    core: Color(0xFF000000),
  );

  /// The glyph's dark-surface counterpart: the same subtraction applied to
  /// [dark]. Not a fourth authored asset — the plate is simply dropped.
  static const AtherBrandPalette glyphDark = AtherBrandPalette(
    plate: null,
    track: Color(0xFF2A2A2E),
    progress: Color(0xFF34C759),
    core: Color(0xFFFFFFFF),
  );

  /// The same palette with no background plate.
  AtherBrandPalette get withoutPlate => AtherBrandPalette(
    plate: null,
    track: track,
    progress: progress,
    core: core,
  );

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
      other.track == track &&
      other.progress == progress &&
      other.core == core;

  @override
  int get hashCode => Object.hash(plate, track, progress, core);
}

/// Paints the mark from [AtherMarkGeometry] into whatever box it is given.
///
/// The scale is uniform on both axes and the artwork is centred, so a
/// non-square box letterboxes rather than distorting.
class AtherMarkPainter extends CustomPainter {
  const AtherMarkPainter({required this.palette});

  final AtherBrandPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const double c = AtherMarkGeometry.canvas;
    final double scale = size.shortestSide / c;
    if (scale <= 0) return;

    canvas.save();
    canvas.translate(
      (size.width - c * scale) / 2,
      (size.height - c * scale) / 2,
    );
    canvas.scale(scale);

    final Color? plate = palette.plate;
    if (plate != null) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, c, c), Paint()..color = plate);
    }

    const Offset middle = Offset(
      AtherMarkGeometry.center,
      AtherMarkGeometry.center,
    );

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AtherMarkGeometry.strokeWidth
      ..isAntiAlias = true;

    canvas.drawCircle(
      middle,
      AtherMarkGeometry.radius,
      ring..color = palette.track,
    );

    canvas.drawArc(
      Rect.fromCircle(center: middle, radius: AtherMarkGeometry.radius),
      AtherMarkGeometry.startRadians,
      AtherMarkGeometry.sweepRadians,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AtherMarkGeometry.strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = palette.progress,
    );

    canvas.drawCircle(
      middle,
      AtherMarkGeometry.coreRadius,
      Paint()
        ..isAntiAlias = true
        ..color = palette.core,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(AtherMarkPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
