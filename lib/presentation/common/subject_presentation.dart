import '../../core/l10n/generated/app_localizations.dart';
import '../../core/widgets/ather_icons.dart';
import '../../domain/entities/subject.dart';

/// How each of the four fixed subjects is drawn and named.
///
/// Constants rather than database columns: the subjects never change, so
/// storing their appearance would create a second source of truth a migration
/// could desync from the code. Names resolve through the ARB files so they
/// follow the language toggle.
///
/// There is deliberately **no colour here any more**. Subject colours were the
/// largest source of colour noise in the old design; the four glyphs now carry
/// the identity, all in the same stroke family and all black.
extension SubjectPresentation on SubjectCode {
  AtherGlyph get glyph => switch (this) {
    SubjectCode.biology => AtherGlyph.biology,
    SubjectCode.physics => AtherGlyph.physics,
    SubjectCode.chemistry => AtherGlyph.chemistry,
    SubjectCode.english => AtherGlyph.english,
  };

  String label(L l) => switch (this) {
    SubjectCode.biology => l.subjectBiology,
    SubjectCode.physics => l.subjectPhysics,
    SubjectCode.chemistry => l.subjectChemistry,
    SubjectCode.english => l.subjectEnglish,
  };
}
