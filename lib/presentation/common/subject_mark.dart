import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_icons.dart';
import '../../domain/entities/subject.dart';
import 'subject_presentation.dart';

/// A subject's mark: its drawn glyph, or its first letter when it has none.
///
/// The four subjects Ather ships with have glyphs, drawn in one stroke family
/// and all black — that is what carries subject identity now that the design
/// has no per-subject colour. Nothing can draw a glyph for a subject a student
/// invents, and waiting for artwork before they can add "تاريخ" would make the
/// feature useless, so a custom subject is marked with its own first letter.
///
/// Same box either way, so a list of both kinds keeps one column of marks and
/// one alignment.
class SubjectMark extends StatelessWidget {
  const SubjectMark({super.key, required this.subject, this.size = 26});

  final Subject subject;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = subject.glyph;
    if (glyph != null) return AtherIcon(glyph, size: size);

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          subject.initial,
          textAlign: TextAlign.center,
          style: AppTypography.style(
            // The letter has to read at the glyph's weight without occupying
            // the glyph's full box -- a character drawn to 26 sits visually
            // larger than a 26 icon, which is thin line work inside its bounds.
            size: size * 0.72,
            weight: AppTypography.bold,
            height: 1,
            color: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
