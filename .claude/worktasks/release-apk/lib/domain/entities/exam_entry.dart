/// A set of questions on one exam that share the same point value.
///
/// The student enters exams the way Thanaweya Amma papers are actually built --
/// "5 أسئلة بدرجة واحدة، 3 أسئلة بدرجتين" -- so a group, not an individual
/// question, is the unit that gets stored. This is the source of truth for an
/// exam's arithmetic.
final class ExamQuestionGroup {
  const ExamQuestionGroup({
    required this.id,
    required this.examId,
    required this.pointsPerQuestion,
    required this.questionCount,
    required this.correctCount,
  });

  final int id;
  final int examId;
  final int pointsPerQuestion;
  final int questionCount;
  final int correctCount;

  int get possiblePoints => pointsPerQuestion * questionCount;
  int get earnedPoints => pointsPerQuestion * correctCount;

  @override
  bool operator ==(Object other) =>
      other is ExamQuestionGroup &&
      other.id == id &&
      other.examId == examId &&
      other.pointsPerQuestion == pointsPerQuestion &&
      other.questionCount == questionCount &&
      other.correctCount == correctCount;

  @override
  int get hashCode =>
      Object.hash(id, examId, pointsPerQuestion, questionCount, correctCount);
}

/// A recorded exam result -- **the only thing in the app that moves mastery**.
final class ExamEntry {
  const ExamEntry({
    required this.id,
    required this.lessonId,
    required this.isReviewExam,
    required this.totalPossiblePoints,
    required this.correctPoints,
    required this.percentage,
    required this.createdAt,
    this.groups = const <ExamQuestionGroup>[],
  });

  final int id;
  final int lessonId;

  /// False for a lesson's first exam, true for any exam taken to clear an
  /// overdue review.
  final bool isReviewExam;

  final int totalPossiblePoints;
  final int correctPoints;

  /// Denormalised from [groups] at write time.
  ///
  /// Kept on the row rather than recomputed on read for two reasons: mastery is
  /// queried on every dashboard and chart render, and a past exam's score must
  /// stay historically stable even if the grouping logic is ever revised.
  final double percentage;

  final DateTime createdAt;

  /// Empty unless the caller explicitly loaded the groups; the mastery
  /// calculation only ever needs [percentage].
  final List<ExamQuestionGroup> groups;

  /// Computes the percentage for a set of groups.
  ///
  /// Returns 0 for an empty or zero-point exam rather than producing NaN, which
  /// would poison every average it later flows into.
  static double percentageOf(Iterable<ExamQuestionGroup> groups) {
    var possible = 0;
    var earned = 0;
    for (final g in groups) {
      possible += g.possiblePoints;
      earned += g.earnedPoints;
    }
    if (possible <= 0) return 0;
    return (earned / possible) * 100;
  }

  @override
  bool operator ==(Object other) =>
      other is ExamEntry &&
      other.id == id &&
      other.lessonId == lessonId &&
      other.isReviewExam == isReviewExam &&
      other.totalPossiblePoints == totalPossiblePoints &&
      other.correctPoints == correctPoints &&
      other.percentage == percentage &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    lessonId,
    isReviewExam,
    totalPossiblePoints,
    correctPoints,
    percentage,
    createdAt,
  );
}

/// An exam group being built in the entry wizard, before it has a database id.
final class DraftQuestionGroup {
  const DraftQuestionGroup({
    required this.pointsPerQuestion,
    required this.questionCount,
    this.correctCount = 0,
  });

  final int pointsPerQuestion;
  final int questionCount;
  final int correctCount;

  int get possiblePoints => pointsPerQuestion * questionCount;
  int get earnedPoints => pointsPerQuestion * correctCount;

  DraftQuestionGroup copyWith({
    int? pointsPerQuestion,
    int? questionCount,
    int? correctCount,
  }) {
    return DraftQuestionGroup(
      pointsPerQuestion: pointsPerQuestion ?? this.pointsPerQuestion,
      questionCount: questionCount ?? this.questionCount,
      correctCount: correctCount ?? this.correctCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DraftQuestionGroup &&
      other.pointsPerQuestion == pointsPerQuestion &&
      other.questionCount == questionCount &&
      other.correctCount == correctCount;

  @override
  int get hashCode =>
      Object.hash(pointsPerQuestion, questionCount, correctCount);
}
