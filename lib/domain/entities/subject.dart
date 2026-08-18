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
    this.deletedAt,
    this.updatedAt,
  });

  /// A seeded subject: named by the ARB files, drawn with its glyph.
  const Subject.seeded({
    required this.id,
    required SubjectCode this.code,
    required this.sortOrder,
  }) : name = null,
       archivedAt = null,
       deletedAt = null,
       updatedAt = null;

  final int id;

  /// Null for a subject the student added.
  final SubjectCode? code;

  /// Set for a subject the student added, null for the four seeded ones.
  final String? name;

  final int sortOrder;

  /// Set when the student **archived** the subject — put it away because they
  /// are done with it. Nothing beneath it is touched, and unarchiving restores
  /// every figure exactly as it was.
  final DateTime? archivedAt;

  /// Set when the student **deleted** the subject. Also touches nothing
  /// beneath it: the row moves to the recycle bin, where it can be restored or
  /// destroyed for real.
  ///
  /// Two columns rather than one flag, because archive and trash are different
  /// intentions and not two words for hiding — archive is "I am done with
  /// this", trash is "I did not mean to have this". A single flag would force
  /// one list to answer both questions, which is what the earlier "hidden"
  /// state did badly enough to be worth replacing.
  ///
  /// `Chapters.subjectId` cascades, so the real destruction — every chapter,
  /// lesson and exam beneath it — happens only when the bin is emptied. That
  /// is the one act in this feature that cannot be undone, and it is the only
  /// one behind a confirmation that names what goes.
  final DateTime? deletedAt;

  /// Server timestamp of last modification for multi-device sync. Null for
  /// entities created before sync was enabled. Set automatically on every
  /// write operation once sync is active.
  final DateTime? updatedAt;

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;

  /// Neither archived nor deleted: shown everywhere and counted in every
  /// figure.
  bool get isActive => archivedAt == null && deletedAt == null;

  /// True for the four Ather ships with. They can be archived like any other,
  /// but they cannot be renamed — their names come from the ARB files.
  bool get isSeeded => code != null;

  /// Serializes to Firestore-compatible JSON for multi-device sync.
  ///
  /// Separate from the backup format: sync sends individual rows, backup sends
  /// the whole database at once. DateTime fields are stored as epoch
  /// milliseconds to match the backup format and avoid locale parsing issues.
  Map<String, Object?> toSyncJson() => <String, Object?>{
        'id': id,
        'code': code?.name ?? kCustomSubjectCode,
        'name': name,
        'sortOrder': sortOrder,
        'archivedAt': archivedAt?.millisecondsSinceEpoch,
        'deletedAt': deletedAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  /// Deserializes from Firestore JSON. Throws if required fields are missing
  /// or have the wrong type — a malformed sync document should fail loudly
  /// rather than corrupting local state.
  static Subject fromSyncJson(Map<String, Object?> json) {
    return Subject(
      id: json['id']! as int,
      code: SubjectCode.tryFromName((json['code'] ?? '') as String),
      name: json['name'] as String?,
      sortOrder: (json['sortOrder'] ?? 0) as int,
      archivedAt: json['archivedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['archivedAt']! as int)
          : null,
      deletedAt: json['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['deletedAt']! as int)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt']! as int)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Subject &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, code, name, sortOrder, archivedAt, deletedAt, updatedAt);
}
