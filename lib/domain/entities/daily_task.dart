/// A single thing the student wrote down for one day.
///
/// **This is not evidence.** Mastery is derived exclusively from recorded exams
/// (PROJECT.md §1), and nothing in `domain/services/` reads this type. A task is
/// the student's own plan for a day; ticking one proves nothing, and no screen
/// may render it as a percentage or a mastery bar.
final class DailyTask {
  const DailyTask({
    required this.id,
    required this.day,
    required this.title,
    required this.done,
    required this.sortOrder,
    required this.createdAt,
    this.updatedAt,
  });

  final int id;

  /// Midnight local — always the output of [dayOf].
  final DateTime day;

  final String title;
  final bool done;

  /// Position within [day]. Dense, and rewritten wholesale when the student
  /// drags a row.
  final int sortOrder;

  final DateTime createdAt;

  /// Server timestamp of last modification for multi-device sync. Null for
  /// entities created before sync was enabled.
  final DateTime? updatedAt;

  /// Serializes to Firestore-compatible JSON for multi-device sync.
  Map<String, Object?> toSyncJson() => <String, Object?>{
        'id': id,
        'day': day.millisecondsSinceEpoch,
        'title': title,
        'done': done,
        'sortOrder': sortOrder,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  /// Deserializes from Firestore JSON.
  static DailyTask fromSyncJson(Map<String, Object?> json) {
    return DailyTask(
      id: json['id']! as int,
      day: DateTime.fromMillisecondsSinceEpoch(json['day']! as int),
      title: json['title']! as String,
      done: (json['done'] ?? false) as bool,
      sortOrder: (json['sortOrder'] ?? 0) as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']! as int),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt']! as int)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DailyTask &&
      other.id == id &&
      other.day == day &&
      other.title == title &&
      other.done == done &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, day, title, done, sortOrder, createdAt, updatedAt);
}

/// A moment reduced to the day it fell on.
///
/// The single day-truncation used by everything task-shaped, so a task written
/// at 23:59 and one written a minute later cannot disagree about which day they
/// belong to.
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
