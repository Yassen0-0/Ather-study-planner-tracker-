import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'ather_brand.dart';

/// The app logo, wherever the app shows itself.
///
/// **One shape, not two.** There was an `AtherLogo` here as well — the plated
/// icon, `icon-mastery-*` — and nothing ever placed it. Every surface that
/// shows the mark (login, lock, Settings → About) sits on a card or a coloured
/// page and therefore wants the plateless [AtherGlyph]; a second background
/// square would only draw a box around the symbol. The plated artwork is still
/// the launcher icon, which Android composites from the exported bitmaps rather
/// than from a widget, so nothing in the app ever needed to draw it.
///
/// It takes no light/dark argument: it reads the ambient brightness through
/// [AtherBrandPalette.of], so a screen places one widget and gets the right
/// variant — no `if (dark)` at any call site and no second widget tree.
///
/// Size is a single number because the mark is square. Passing one dimension
/// makes it impossible to stretch it by accident.
///
/// Use it anywhere the logo sits on a surface that already has a colour of its
/// own — a card, a header, a list row.
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

/// The painted implementation behind [AtherGlyph].
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
