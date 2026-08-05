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
}

/// A moment reduced to the day it fell on.
///
/// The single day-truncation used by everything task-shaped, so a task written
/// at 23:59 and one written a minute later cannot disagree about which day they
/// belong to.
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
