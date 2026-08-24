/// A chapter (باب) the student created inside a subject.
final class Chapter {
  const Chapter({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.createdAt,
    this.masteredAt,
  });

  final int id;
  final int subjectId;
  final String name;
  final DateTime createdAt;

  /// Set the moment "أتقنت الباب" succeeds. Null means the chapter has never
  /// been closed out — it does not mean the chapter is empty or weak.
  final DateTime? masteredAt;

  bool get isMastered => masteredAt != null;

  Chapter copyWith({
    String? name,
    DateTime? masteredAt,
    bool clearMasteredAt = false,
  }) {
    return Chapter(
      id: id,
      subjectId: subjectId,
      name: name ?? this.name,
      createdAt: createdAt,
      masteredAt: clearMasteredAt ? null : (masteredAt ?? this.masteredAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Chapter &&
      other.id == id &&
      other.subjectId == subjectId &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.masteredAt == masteredAt;

  @override
  int get hashCode => Object.hash(id, subjectId, name, createdAt, masteredAt);
}
