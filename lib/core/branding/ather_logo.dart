import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'ather_brand.dart';

/// The app logo, wherever the app shows itself.
///
/// Two shapes, and the difference is the same one the SVGs draw:
///
/// * [AtherLogo] — the full icon, background plate included. `icon-mastery-*`.
/// * [AtherGlyph] — the symbol alone, transparent behind it. `glyph-mastery`.
///
/// Neither takes a light/dark argument. Both read the ambient brightness
/// through [AtherBrandPalette.of], so a screen places one widget and gets the
/// right variant — there is no `if (dark)` at any call site and no second
/// widget tree to keep in step.
///
/// Size is a single number because the mark is square. Passing one dimension
/// makes it impossible to stretch it by accident.
class AtherLogo extends StatelessWidget {
  const AtherLogo({super.key, this.size = 64, this.palette});

  /// Edge length of the square icon, in logical pixels.
  final double size;

  /// Forces a variant. Left null — the normal case — the theme decides.
  ///
  /// The one caller that should set this is anything rendering the *installed*
  /// identity, which is always the light icon regardless of theme.
  final AtherBrandPalette? palette;

  @override
  Widget build(BuildContext context) {
    return _Mark(
      size: size,
      palette: palette ?? AtherBrandPalette.of(context),
      label: L.of(context).appName,
    );
  }
}

/// The standalone symbol: same mark, no plate.
///
/// Use this anywhere the logo sits on a surface that already has a colour of
/// its own — a card, a header, a list row — where a second background square
/// would only draw a box around it.
class AtherGlyph extends StatelessWidget {
  const AtherGlyph({super.key, this.size = 24});

  /// Edge length of the square glyph, in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return _Mark(
      size: size,
      palette: AtherBrandPalette.of(context).withoutPlate,
      label: L.of(context).appName,
    );
  }
}

/// The single painted implementation behind both public shapes.
class _Mark extends StatelessWidget {
  const _Mark({required this.size, required this.palette, required this.label});

  final double size;
  final AtherBrandPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      image: true,
      // Decoration everywhere it appears, never a control: without this a
      // CustomPaint would answer hit tests and could swallow a tap meant for
      // whatever it is sitting inside.
      child: IgnorePointer(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: AtherMarkPainter(palette: palette)),
        ),
      ),
    );
  }
}
