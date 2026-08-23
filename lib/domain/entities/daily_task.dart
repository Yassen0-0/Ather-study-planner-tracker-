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
    this.surrendered = false,
    required this.sortOrder,
    required this.createdAt,
  });

  final int id;

  /// Midnight UTC of one calendar day -- always [dayOf] on write, and
  /// re-normalised through it on every read: rows written before the key was
  /// UTC-anchored carry a local midnight and are handed to callers in the
  /// canonical form whatever the column held.
  final DateTime day;

  final String title;
  final bool done;

  /// The student gave up on the task -- استسلام, counted as failure for the
  /// day. Defaults to false so every construction site that predates surrender
  /// (tests, older fixtures) keeps meaning "an ordinary task". Never true at
  /// the same time as [done]: the repository clears whichever flag the other
  /// one sets, so a caller holding both flags true has made a mistake this
  /// class will not carry.
  final bool surrendered;

  /// Position within [day]. Dense, and rewritten wholesale when the student
  /// drags a row.
  final int sortOrder;

  final DateTime createdAt;
}

/// A moment reduced to the day it fell on, as midnight UTC.
///
/// The single day-truncation used by everything task-shaped, so a task written
/// at 23:59 and one written a minute later cannot disagree about which day they
/// belong to.
///
/// **Midnight UTC, not local midnight.** A local midnight is an instant that
/// means "this day" only under the UTC offset it was written with: Egypt moves
/// between +3 and +2 every year, so a key stored as local midnight comes back
/// from SQLite reading 23:00 on the previous day (or 01:00) once the offset has
/// changed -- and a task written in July then vanishes from its own day every
/// winter. Midnight UTC is the same instant all year, so the key a write leaves
/// is still the key every later read compares against. Egypt sits east of UTC,
/// so the instant lands early inside its own day wherever it is read; the
/// calendar fields it carries are always the day it belongs to.
DateTime dayOf(DateTime moment) =>
    DateTime.utc(moment.year, moment.month, moment.day);

/// The calendar day [d] falls on, as a count of days -- the form days are
/// compared in.
///
/// Cloned from `ReviewCycleService._dayNumber`, for the same reason:
/// normalising through UTC keeps equality from being bent by a daylight-saving
/// shift. Two [DateTime]s for the same day can disagree about the *instant*
/// they name when one of them was built under another offset; their day numbers
/// cannot disagree about the day. Every "is this task on that day" question --
/// filtering, grouping, selecting -- goes through here rather than comparing
/// raw fields or instants.
int dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
