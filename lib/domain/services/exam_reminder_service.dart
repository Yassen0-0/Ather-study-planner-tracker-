import '../entities/scheduled_exam.dart';

/// How many days before an exam to post the preparation reminder.
///
/// 3 days gives the student time to re-prove decayed lessons without cramming.
/// Students study in the evening (§1.2), and an exam is usually a morning event,
/// so a reminder 3 days before gives two full evenings of prep time.
const int kReminderDaysBefore = 3;

/// The hour a reminder is posted on the day it becomes due.
///
/// 18:00 (6 PM) is after school and before the evening study session -- the
/// student sees it when they check their phone after class, and it surfaces
/// in time to plan that evening's review.
const int kReminderHour = 18;

/// Pure functions for exam reminder scheduling.
///
/// Every function takes `now` explicitly rather than calling `DateTime.now()`,
/// so the whole mechanic is testable without mocking time.
///
/// This is domain logic only -- no platform code, no notifications. The actual
/// scheduling happens in `ExamNotificationService` (data layer), which calls
/// these functions to compute *when* to remind.
abstract final class ExamReminderService {
  /// The calendar day [d] falls on, as a count of days.
  ///
  /// Normalised through UTC so the subtraction cannot be bent by a daylight-
  /// saving shift. Egypt observes DST, and two local midnights either side of
  /// it are 23 or 25 hours apart, which `Duration.inDays` would silently round
  /// the wrong way.
  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// Whole days until a scheduled exam, or null if the exam is in the past.
  ///
  /// **Calendar days, not 24-hour periods.** An exam at any time on day N is
  /// "tomorrow" from any time on day N-1. This matches how students think:
  /// "the exam is in 3 days" means 3 midnights from now, not 72 hours.
  static int? daysUntilExam(ScheduledExam exam, DateTime now) {
    final days = _dayNumber(exam.date) - _dayNumber(now);
    if (days < 0) return null; // Exam is in the past.
    return days;
  }

  /// Whether the exam is today or in the future.
  static bool isUpcoming(ScheduledExam exam, DateTime now) {
    return _dayNumber(exam.date) >= _dayNumber(now);
  }

  /// The moment to post the preparation reminder for this exam.
  ///
  /// Returns a [DateTime] exactly [kReminderDaysBefore] days before the exam
  /// date, at [kReminderHour] local time. This is the scheduled time for the
  /// notification that says "your Biology exam is in 3 days -- re-prove your
  /// Cell lessons."
  ///
  /// If the exam is in less than [kReminderDaysBefore] days, the reminder date
  /// is in the past and no notification should be scheduled -- the student
  /// created the exam too close to the date for a warning to be useful.
  ///
  /// Example:
  /// ```dart
  /// final exam = ScheduledExam(
  ///   id: 1,
  ///   date: DateTime(2026, 8, 25), // Exam on August 25
  ///   ...
  /// );
  /// final reminder = ExamReminderService.reminderDateFor(exam);
  /// // => DateTime(2026, 8, 22, 18, 0) // August 22 at 6 PM
  /// ```
  static DateTime reminderDateFor(ScheduledExam exam) {
    // Built from calendar components rather than subtracting a Duration:
    // subtracting 3x24h across a daylight-saving change lands an hour off.
    // Dart normalises an out-of-range day, so `day - 3` is exactly "the same
    // date three days earlier".
    return DateTime(
      exam.date.year,
      exam.date.month,
      exam.date.day - kReminderDaysBefore,
      kReminderHour,
    );
  }

  /// Whether the reminder for this exam should be scheduled now.
  ///
  /// Returns true if:
  /// - The exam is upcoming (today or future), AND
  /// - The reminder date is in the future (at least [kReminderDaysBefore] days away)
  ///
  /// If this returns false, the exam is either past or too close to remind for.
  static bool shouldScheduleReminder(ScheduledExam exam, DateTime now) {
    if (!isUpcoming(exam, now)) return false;
    final reminder = reminderDateFor(exam);
    return reminder.isAfter(now);
  }

  /// Exams happening within the next [withinDays] days, sorted by date (soonest first).
  ///
  /// Used for dashboard previews: "You have 2 exams this week". Excludes past
  /// exams -- those belong on the history timeline, not the upcoming list.
  ///
  /// Example:
  /// ```dart
  /// final upcoming = ExamReminderService.upcomingExamsIn(
  ///   allExams,
  ///   now,
  ///   withinDays: 7,
  /// );
  /// // => Exams in the next 7 days, soonest first
  /// ```
  static List<ScheduledExam> upcomingExamsIn(
    List<ScheduledExam> exams,
    DateTime now, {
    int withinDays = 7,
  }) {
    final upcoming = <ScheduledExam>[];
    for (final exam in exams) {
      final days = daysUntilExam(exam, now);
      if (days != null && days <= withinDays) {
        upcoming.add(exam);
      }
    }
    // Sort by date: soonest first.
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  }

  /// Count of exams happening within the next [withinDays] days.
  ///
  /// Convenience for dashboard summary cards: "3 exams this week". Excludes
  /// past exams.
  static int upcomingExamCount(
    List<ScheduledExam> exams,
    DateTime now, {
    int withinDays = 7,
  }) {
    return upcomingExamsIn(exams, now, withinDays: withinDays).length;
  }

  /// The next upcoming exam, or null if there are no future exams.
  ///
  /// "Next" means the soonest exam that is today or later. If multiple exams
  /// are scheduled for the same day, this returns the first one encountered
  /// (order is undefined -- sort by time-of-day if that matters).
  static ScheduledExam? nextUpcomingExam(
    List<ScheduledExam> exams,
    DateTime now,
  ) {
    final upcoming = upcomingExamsIn(exams, now, withinDays: 36500); // ~100 years
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// Exams scheduled for a specific calendar day.
  ///
  /// Used by the calendar view to show markers on dates. Compares only the
  /// date component (year, month, day), ignoring time.
  static List<ScheduledExam> examsOn(
    List<ScheduledExam> exams,
    DateTime date,
  ) {
    final targetDay = _dayNumber(date);
    return exams.where((exam) => _dayNumber(exam.date) == targetDay).toList();
  }
}
