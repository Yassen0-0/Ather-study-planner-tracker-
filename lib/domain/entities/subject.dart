/// The four subjects Ather ships with.
///
/// These are still seeded on a fresh install — a student who opens the app for
/// the first time should find something to work in — but they stopped being
/// *the* list of subjects when subjects became something a student can add. A
/// subject the student created has no code; its name is its identity.
///
/// The enum survives rather than becoming a plain string because the four it
/// names carry drawn glyphs and translated labels, and both of those are keyed
/// off it. Everything else about a subject is now data.
enum SubjectCode {
  biology,
  physics,
  chemistry,
  english;

  /// Null for anything that is not one of the four — which is every subject
  /// the student added. Callers must handle it; there is deliberately no
  /// throwing variant any more, because a row written by a future version of
  /// the app must not crash an older one on read.
  static SubjectCode? tryFromName(String name) {
    for (final code in SubjectCode.values) {
      if (code.name == name) return code;
    }
    return null;
  }
}

/// The `code` column's value for a subject the student created.
///
/// A sentinel rather than a null column: making `code` nullable would mean
/// rewriting the table, and a migration that rewrites a table holding the
/// student's curriculum is a migration that can lose it. Anything that does
/// not parse to a [SubjectCode] is a custom subject, so the exact string only
/// has to be stable, not meaningful.
const String kCustomSubjectCode = 'custom';

/// A subject.
///
/// Carries **no icon or colour**, exactly as before: those are presentation
/// constants keyed off [code], and a subject with no code draws its first
/// letter instead. What it now carries is [name] and [archivedAt], because
/// neither can be derived from anything else.
///
/// [name] is null for the four seeded subjects and only for them: their names
/// live in the ARB files so the ar/en toggle works without a migration, and a
/// name stored here would freeze "أحياء" into a database the language switch
/// cannot reach. A student-created subject has the opposite problem — nobody
/// can translate it — so it stores the name it was given.
final class Subject {
  const Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.archivedAt,
  });

  /// A seeded subject: named by the ARB files, drawn with its glyph.
  const Subject.seeded({
    required this.id,
    required SubjectCode this.code,
    required this.sortOrder,
  }) : name = null,
       archivedAt = null;

  final int id;

  /// Null for a subject the student added.
  final SubjectCode? code;

  /// Set for a subject the student added, null for the four seeded ones.
  final String? name;

  final int sortOrder;

  /// Set when the student hid the subject. **Not a delete**: everything under
  /// it is still there, and unarchiving brings it back untouched.
  ///
  /// This exists because `Chapters.subjectId` cascades. Deleting a subject
  /// takes every chapter, lesson and exam beneath it, and for a student two
  /// years into their record that is the largest single act of destruction the
  /// app is capable of — reachable, before this, from one row and one
  /// confirmation. Hiding is what a student almost always means, so hiding is
  /// what the screen offers; deleting is kept for the case where there is
  /// nothing to lose.
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  /// True for the four Ather ships with. They can be archived like any other,
  /// but they cannot be renamed — their names come from the ARB files.
  bool get isSeeded => code != null;

  Subject copyWith({DateTime? archivedAt, bool clearArchived = false}) {
    return Subject(
      id: id,
      code: code,
      name: name,
      sortOrder: sortOrder,
      archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Subject &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      other.archivedAt == archivedAt;

  @override
  int get hashCode => Object.hash(id, code, name, sortOrder, archivedAt);
}
