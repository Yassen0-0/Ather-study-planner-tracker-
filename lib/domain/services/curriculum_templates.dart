import '../entities/subject.dart';

/// The standard chapter structure of the four seeded subjects, as data.
///
/// ## Why this is a data file and not ARB keys
///
/// These are student-facing strings, so the rule is that they are reviewed
/// rather than typed inline at a call site — which this file satisfies. They
/// are deliberately **not** in the ARB files: a chapter name written into the
/// database is a row the student then owns, renames and deletes. It is seeded
/// content, not interface copy. Putting it in the ARB would imply the name
/// changes with the language toggle, and it cannot: the row was written once,
/// in whatever language was on at the time, and the toggle has no way to reach
/// back into a table of the student's own chapters and rewrite them.
///
/// Arabic only, for the same reason. The curriculum these name is taught in
/// Arabic and examined in Arabic; an English translation of "الكيمياء
/// الكهربية" is not what is written on the student's own book.
///
/// ## These are a starting point, not an authority
///
/// The Egyptian curriculum is revised, and chapters are added, merged and
/// dropped between years. Nothing here is treated as the truth about what a
/// student is sitting: applying a template writes ordinary chapters that the
/// student then edits, renames or deletes like any they typed themselves. That
/// is the entire promise being made — a student should not have to type out
/// twenty-odd chapter names before the app can measure anything, and if two of
/// them are wrong for their year, fixing two is still far less work than
/// typing twenty.
abstract final class CurriculumTemplates {
  /// Chapters for [code], oldest-first in the order they are taught, or null
  /// when there is no template for that subject.
  ///
  /// Null rather than an empty list, so "no template exists" and "a template
  /// with nothing in it" cannot be confused at a call site.
  static List<String>? chaptersFor(SubjectCode code) => switch (code) {
    SubjectCode.biology => _biology,
    SubjectCode.physics => _physics,
    SubjectCode.chemistry => _chemistry,
    SubjectCode.english => _english,
  };

  /// The template for a subject, or null for one the student created.
  ///
  /// A custom subject has no standard structure by definition — it is a
  /// subject the app has never heard of — so the action is not offered for it.
  static List<String>? forSubject(Subject subject) {
    final code = subject.code;
    return code == null ? null : chaptersFor(code);
  }

  static const List<String> _biology = <String>[
    'الدعامة والحركة في الكائنات الحية',
    'النقل في الكائنات الحية',
    'التنفس في الكائنات الحية',
    'الإخراج في الكائنات الحية',
    'التنسيق الهرموني',
    'التنسيق العصبي',
    'المناعة',
    'التكاثر في الكائنات الحية',
    'الوراثة',
    'التقنية الحيوية',
  ];

  static const List<String> _physics = <String>[
    'التيار الكهربي وقانون أوم',
    'الأثر المغناطيسي للتيار الكهربي',
    'الحث الكهرومغناطيسي',
    'الدوائر المتذبذبة والتيار المتردد',
    'الطبيعة الموجية للضوء',
    'الفيزياء الحديثة',
    'الإلكترونيات الحديثة',
  ];

  static const List<String> _chemistry = <String>[
    'الكيمياء الكهربية',
    'الكيمياء التحليلية',
    'كيمياء العناصر الانتقالية',
    'الكيمياء العضوية',
    'الصناعات الكيميائية',
  ];

  /// English is taught in units rather than أبواب, and the unit list changes
  /// with the set book. Numbered rather than titled for that reason: a number
  /// is right whatever this year's book is called, and the student renames it
  /// to whatever their own copy says.
  static const List<String> _english = <String>[
    'Unit 1',
    'Unit 2',
    'Unit 3',
    'Unit 4',
    'Unit 5',
    'Unit 6',
    'Unit 7',
    'Unit 8',
    'The Novel',
  ];
}
