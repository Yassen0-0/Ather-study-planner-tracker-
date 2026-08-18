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
    this.updatedAt,
  });

  final int id;
  final int lessonId;
  final int score;
  final int maxScore;
  final DateTime createdAt;

  /// Server timestamp of last modification for multi-device sync. Null for
  /// entities created before sync was enabled.
  final DateTime? updatedAt;

  /// Guards against a zero denominator rather than throwing: a malformed row
  /// should render as 0%, not crash the lesson screen.
  double get percentage => maxScore <= 0 ? 0 : (score / maxScore) * 100;

  /// Serializes to Firestore-compatible JSON for multi-device sync.
  Map<String, Object?> toSyncJson() => <String, Object?>{
        'id': id,
        'lessonId': lessonId,
        'score': score,
        'maxScore': maxScore,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  /// Deserializes from Firestore JSON.
  static HomeworkEntry fromSyncJson(Map<String, Object?> json) {
    return HomeworkEntry(
      id: json['id']! as int,
      lessonId: json['lessonId']! as int,
      score: json['score']! as int,
      maxScore: json['maxScore']! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']! as int),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt']! as int)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeworkEntry &&
      other.id == id &&
      other.lessonId == lessonId &&
      other.score == score &&
      other.maxScore == maxScore &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, lessonId, score, maxScore, createdAt, updatedAt);
}
