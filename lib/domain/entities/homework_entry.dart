/// A homework score the student logged for a lesson.
///
/// **Never enters the mastery calculation.** It exists only to answer "am I
/// ready to sit the exam?" — see [kHomeworkReadinessThreshold] in `mastery.dart`.
/// Any future change that feeds this into mastery contradicts the product's
/// central claim and should be rejected.
final class HomeworkEntry {
  const HomeworkEntry({
    required this.id,
    required this.lessonId,
    required this.score,
    required this.maxScore,
    required this.createdAt,
  });

  final int id;
  final int lessonId;
  final int score;
  final int maxScore;
  final DateTime createdAt;

  /// Guards against a zero denominator rather than throwing: a malformed row
  /// should render as 0%, not crash the lesson screen.
  double get percentage => maxScore <= 0 ? 0 : (score / maxScore) * 100;

  @override
  bool operator ==(Object other) =>
      other is HomeworkEntry &&
      other.id == id &&
      other.lessonId == lessonId &&
      other.score == score &&
      other.maxScore == maxScore &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, lessonId, score, maxScore, createdAt);
}
