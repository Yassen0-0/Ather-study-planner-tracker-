/// The four fixed Thanaweya Amma (علمي علوم) subjects.
///
/// These are seeded once and never editable — the app deliberately ships no
/// "add subject" UI. The enum, not a database string, is what the rest of the
/// app switches on.
enum SubjectCode {
  biology,
  physics,
  chemistry,
  english;

  static SubjectCode fromName(String name) =>
      SubjectCode.values.firstWhere((c) => c.name == name);
}

/// A subject row.
///
/// Deliberately carries **no display name, icon or colour**. Names live in the
/// ARB files so the ar/en toggle works without a database migration, and
/// icon/colour are presentation constants keyed off [code]. Storing them here
/// would create a second source of truth that the language switch could not
/// reach.
final class Subject {
  const Subject({
    required this.id,
    required this.code,
    required this.sortOrder,
  });

  final int id;
  final SubjectCode code;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is Subject &&
      other.id == id &&
      other.code == code &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, code, sortOrder);
}
