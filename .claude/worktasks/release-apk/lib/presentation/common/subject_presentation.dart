import '../../core/l10n/generated/app_localizations.dart';
import '../../core/widgets/ather_icons.dart';
import '../../domain/entities/subject.dart';

/// How a subject is named and drawn.
///
/// Constants rather than database columns, still: the four Ather ships with
/// never change, so storing their appearance would create a second source of
/// truth a migration could desync from the code. Their names resolve through
/// the ARB files so they follow the language toggle.
///
/// There is deliberately **no colour here**. Subject colours were the largest
/// source of colour noise in the old design; the glyphs carry the identity, all
/// in the same stroke family and all black.
///
/// A subject the student added has neither a glyph nor a translated name — no
/// one can draw an icon for a word they have not read yet. It is drawn with its
/// own first letter instead, which is the same device the account header uses
/// and needs no artwork to be commissioned before a student can add "تاريخ".
extension SubjectPresentation on Subject {
  /// Null for a student-created subject, which draws [initial] instead.
  AtherGlyph? get glyph => switch (code) {
    SubjectCode.biology => AtherGlyph.biology,
    SubjectCode.physics => AtherGlyph.physics,
    SubjectCode.chemistry => AtherGlyph.chemistry,
    SubjectCode.english => AtherGlyph.english,
    null => null,
  };

  String label(L l) => switch (code) {
    SubjectCode.biology => l.subjectBiology,
    SubjectCode.physics => l.subjectPhysics,
    SubjectCode.chemistry => l.subjectChemistry,
    SubjectCode.english => l.subjectEnglish,
    // A custom subject always has a name -- the repository refuses to create
    // one without -- so the fallback is unreachable rather than meaningful.
    null => name ?? '',
  };

  /// The letter drawn in place of a glyph. Taken from the name rather than the
  /// translated label because a custom subject has no translated label.
  String get initial {
    final source = (name ?? '').trim();
    return source.isEmpty ? '؟' : source.substring(0, 1);
  }
}
