/// A scheduled upcoming exam event.
///
/// Students use this to plan exam preparation -- the calendar shows which
/// scheduled exams are approaching, and for each one, which associated lessons
/// have decayed and need re-proof. A scheduled exam is forward-looking intent;
/// it does not affect mastery until an actual ExamEntry is recorded.
final class ScheduledExam {
  const ScheduledExam({
    required this.id,
    required this.subjectId,
    required this.date,
    required this.title,
    required this.chapterIds,
    required this.createdAt,
    this.notes,
  });

  final int id;
  final int subjectId;

  /// The date of the scheduled exam (midnight local).
  final DateTime date;

  final String title;

  /// Associated chapter IDs for this exam. Used to identify which lessons need
  /// review before the exam date.
  final List<int> chapterIds;

  /// Optional student notes about the exam (e.g., "Covers units 1-3").
  final String? notes;

  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is ScheduledExam &&
      other.id == id &&
      other.subjectId == subjectId &&
      other.date == date &&
      other.title == title &&
      other.notes == notes &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        subjectId,
        date,
        title,
        notes,
        createdAt,
      );
}
