/// A chapter (باب) the student created inside a subject.
final class Chapter {
  const Chapter({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.createdAt,
    this.masteredAt,
    this.updatedAt,
  });

  final int id;
  final int subjectId;
  final String name;
  final DateTime createdAt;

  /// Set the moment "أتقنت الباب" succeeds. Null means the chapter has never
  /// been closed out — it does not mean the chapter is empty or weak.
  final DateTime? masteredAt;

  /// Server timestamp of last modification for multi-device sync. Null for
  /// entities created before sync was enabled.
  final DateTime? updatedAt;

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

  /// Serializes to Firestore-compatible JSON for multi-device sync.
  Map<String, Object?> toSyncJson() => <String, Object?>{
        'id': id,
        'subjectId': subjectId,
        'name': name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'masteredAt': masteredAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  /// Deserializes from Firestore JSON.
  static Chapter fromSyncJson(Map<String, Object?> json) {
    return Chapter(
      id: json['id']! as int,
      subjectId: json['subjectId']! as int,
      name: json['name']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']! as int),
      masteredAt: json['masteredAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['masteredAt']! as int)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt']! as int)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Chapter &&
      other.id == id &&
      other.subjectId == subjectId &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.masteredAt == masteredAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, subjectId, name, createdAt, masteredAt, updatedAt);
}
