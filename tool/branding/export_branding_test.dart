// This file lives outside `test/` so `flutter test` skips it by default: it
// writes files into the Android resource tree, which is a build step and not an
// assertion.
@Tags(<String>['branding'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ather/core/branding/ather_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rasterises the Ather identity into every bitmap Android and Play need.
///
/// Run from the project root:
///
/// ```
/// flutter test tool/branding/export_branding_test.dart
/// ```
///
/// Everything it writes is painted by [AtherMarkPainter] from the geometry in
/// `lib/core/branding/ather_brand.dart`, which is a transcription of the three
/// SVGs in `assets/branding/`. That is the point of doing it here rather than
/// with an external SVG rasteriser: the launcher icon, the splash bitmap and
/// the in-app logo cannot disagree, because there is one drawing of the mark.
///
/// Outputs, all square and all drawn at a single uniform scale (so nothing is
/// stretched, distorted or cropped):
///
/// * `mipmap-*/ic_launcher.png` — the legacy launcher icon, light variant.
/// * `mipmap-*/ic_launcher_foreground.png` — the adaptive foreground, glyph on
///   transparent, on the 108dp canvas.
/// * `drawable-*/splash_glyph.png` and `drawable-night-*/splash_glyph.png` —
///   the launch-window mark, light and dark.
/// * `android/app/src/main/ic_launcher-playstore.png` — the 1024×1024 Play
///   Store listing icon.

/// Android's density buckets and their multipliers against mdpi.
const Map<String, double> kDensities = <String, double>{
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// The legacy launcher icon is 48dp.
const double kLauncherDp = 48;

/// Adaptive icons are authored on a 108dp canvas, of which the centre 66dp is
/// the guaranteed-visible safe zone. The mark occupies
/// [AtherMarkGeometry.extent] of its canvas — 0.6113 — so drawing the artwork
/// at full canvas size puts it at 66.0dp. It fits the safe zone exactly, at its
/// authored scale, dead centre.
const double kAdaptiveDp = 108;

/// The launch-window mark. Sized like a splash logo rather than an icon: big
/// enough to read on a phone, small enough to leave the window quiet.
const double kSplashDp = 120;

final Directory kRes = Directory('android/app/src/main/res');

/// Paints [palette] into a [pixels]-square PNG.
Future<Uint8List> render(AtherBrandPalette palette, int pixels) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Size size = Size(pixels.toDouble(), pixels.toDouble());

  AtherMarkPainter(palette: palette).paint(canvas, size);

  final ui.Image image = await recorder.endRecording().toImage(pixels, pixels);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  if (data == null) {
    throw StateError('Failed to encode a ${pixels}px PNG.');
  }
  return data.buffer.asUint8List();
}

Future<void> write(String path, Uint8List bytes) async {
  final File file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('wrote $path (${bytes.length} bytes)');
}

/// Writes one PNG per density bucket, sized [dp] logical pixels.
Future<void> writeDensities({
  required String directoryPrefix,
  required String name,
  required AtherBrandPalette palette,
  required double dp,
}) async {
  for (final MapEntry<String, double> density in kDensities.entries) {
    final int pixels = (dp * density.value).round();
    await write(
      '${kRes.path}/$directoryPrefix-${density.key}/$name.png',
      await render(palette, pixels),
    );
  }
}

void main() {
  testWidgets('exports every launcher, adaptive and splash bitmap', (
    WidgetTester tester,
  ) async {
    // runAsync, because everything below is genuinely asynchronous: PNG
    // encoding hands off to the raster thread and the writes hit the disk.
    // Inside the test binding's fake-async zone those futures would never be
    // driven and the run would simply hang.
    await tester.runAsync(() async {
      // The launcher icon is the light variant at every density. It stays light
      // whatever theme the app itself is in: the installed icon belongs to the
      // launcher, not to the app's theme, so it is never resolved from
      // brightness the way the in-app logo is.
      await writeDensities(
        directoryPrefix: 'mipmap',
        name: 'ic_launcher',
        palette: AtherBrandPalette.light,
        dp: kLauncherDp,
      );

      // The adaptive foreground carries the mark only — the plate becomes the
      // background layer, so the launcher can mask and parallax the two.
      await writeDensities(
        directoryPrefix: 'mipmap',
        name: 'ic_launcher_foreground',
        palette: AtherBrandPalette.glyph,
        dp: kAdaptiveDp,
      );

      // The launch window paints its own background (white, or the night theme's
      // black), so the splash mark is the plateless glyph in both flavours. The
      // `-night` bucket means the OS picks the right one with no code and no
      // second launch_background.xml.
      await writeDensities(
        directoryPrefix: 'drawable',
        name: 'splash_glyph',
        palette: AtherBrandPalette.glyph,
        dp: kSplashDp,
      );
      await writeDensities(
        directoryPrefix: 'drawable-night',
        name: 'splash_glyph',
        palette: AtherBrandPalette.glyphDark,
        dp: kSplashDp,
      );

      // Play's listing icon: 1024×1024, full bleed, no transparency. It sits
      // beside `res/` rather than inside it — Android Studio's Image Asset
      // Studio uses exactly this path, and a 1024px PNG under res/ would be
      // packaged into the APK for nothing. Not in dist/, which is gitignored:
      // this one is a deliverable that should survive a clean checkout.
      await write(
        'android/app/src/main/ic_launcher-playstore.png',
        await render(AtherBrandPalette.light, 1024),
      );
    });
  });
}
