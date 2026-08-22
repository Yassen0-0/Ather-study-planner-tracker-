import '../entities/daily_task.dart';
import '../entities/exam_entry.dart';
import '../entities/lesson.dart';
import '../entities/mastery.dart';
import '../entities/study_snapshot.dart';
import 'mastery_calculator.dart';

/// Why a lesson surfaced in the Review Center, in priority order.
enum ReviewReason {
  /// Past the 30-day cycle. Highest priority -- this is decay, not weakness.
  overdue,

  /// Mastery below [kLowMasteryFlagThreshold], regardless of age.
  lowMastery,

  /// The most recent exam scored lower than the one before it.
  declining,
}

/// A lesson flagged for attention, with everything the UI needs to render a row.
final class ReviewItem {
  const ReviewItem({
    required this.lesson,
    required this.chapterId,
    required this.subjectId,
    required this.mastery,
    required this.reason,
    required this.daysOverdue,
  });

  final Lesson lesson;
  final int chapterId;
  final int subjectId;
  final double mastery;
  final ReviewReason reason;

  /// Days past the 30-day mark. Zero unless [reason] is [ReviewReason.overdue].
  final int daysOverdue;
}

/// The 30-day decay cycle.
///
/// Every function takes `now` explicitly rather than calling `DateTime.now()`,
/// so the whole mechanic is testable in milliseconds instead of a month.
abstract final class ReviewCycleService {
  /// The calendar day [d] falls on, as a count of days. Normalised through UTC
  /// so the subtraction cannot be bent by a daylight-saving shift -- Egypt
  /// observes one, and two local midnights either side of it are 23 or 25 hours
  /// apart, which `Duration.inDays` would silently round the wrong way.
  ///
  /// Delegates to [dayNumber] rather than carrying its own copy: the review
  /// clock and the task-day keys must not be able to drift apart, and the
  /// entity file is the single home of that arithmetic (services may depend on
  /// entities; never the reverse).
  static int _dayNumber(DateTime d) => dayNumber(d);

  /// Whole days since a lesson was last proven, or null if never examined.
  ///
  /// **Calendar days, not 24-hour periods.** This used to be
  /// `now.difference(last).inDays`, which counts elapsed time -- so a lesson
  /// examined at 15:00 fell due at 15:00 thirty days later. Everything that
  /// reads this is driven by `nowProvider`, which emits once per *midnight*
  /// (§3.8), so the app could not notice a mid-afternoon transition until the
  /// following midnight: the student saw "not due yet" for most of the day it
  /// became due, and the count only agreed with the calendar on lessons that
  /// happened to be examined at midnight.
  ///
  /// Measuring the day itself makes the two agree by construction -- the value
  /// can only change when the day changes, which is exactly when the clock ticks.
  static int? daysSinceReview(Lesson lesson, DateTime now) {
    final last = lesson.lastReviewedAt;
    if (last == null) return null;
    return calendarDaysBetween(last, now);
  }

  /// Whole calendar days from [from] to [to]. Negative if [to] is earlier.
  ///
  /// Public because this is not only the review cycle's unit -- anything that
  /// divides by an elapsed span needs it too, and `to.difference(from).inDays`
  /// is wrong for the same reason it is wrong here. Across the night Egypt puts
  /// its clocks forward, two dates a calendar month apart are 29 days and 23
  /// hours of elapsed time, which `inDays` truncates to 29. A rate computed
  /// against that denominator is silently 3% out, in a direction that changes
  /// twice a year.
  static int calendarDaysBetween(DateTime from, DateTime to) =>
      _dayNumber(to) - _dayNumber(from);

  /// Whether a lesson's mastery has decayed and must be re-proven.
  ///
  /// **Derived, never stored.** A persisted flag is only as fresh as the last
  /// time a background check ran; if the student does not open the app for a
  /// week, a stored flag is wrong for that whole week. Computed from
  /// [Lesson.lastReviewedAt] it is correct the instant any widget reads it.
  ///
  /// A lesson that has never been examined (`lastReviewedAt == null`) is **not**
  /// overdue -- red means decayed, not untouched.
  static bool needsReview(Lesson lesson, DateTime now) {
    final days = daysSinceReview(lesson, now);
    return days != null && days >= kReviewCycleDays;
  }

  /// Days remaining before a lesson falls due, or null if it never will
  /// (unexamined) or already has.
  static int? daysUntilDue(Lesson lesson, DateTime now) {
    final days = daysSinceReview(lesson, now);
    if (days == null || days >= kReviewCycleDays) return null;
    return kReviewCycleDays - days;
  }

  static int daysOverdue(Lesson lesson, DateTime now) {
    final days = daysSinceReview(lesson, now);
    if (days == null || days < kReviewCycleDays) return 0;
    return days - kReviewCycleDays;
  }

  /// The moment a lesson becomes due, or null if it has never been examined.
  /// Used to schedule the notification rather than polling daily.
  /// The hour a reminder is posted on the day a lesson falls due.
  ///
  /// A time of day has to be chosen because [needsReview] flips at midnight and
  /// a notification at midnight is a notification nobody reads. 18:00 is after
  /// school and before the evening these students actually study in.
  static const int kReminderHour = 18;

  static DateTime? dueAt(Lesson lesson) {
    final last = lesson.lastReviewedAt;
    if (last == null) return null;
    // Deliberately *not* `last.add(Duration(days: 30))`.
    //
    // That is hour-precise, while [needsReview] counts calendar days, and the
    // two then disagree for up to 23 hours -- widest for a student who studies
    // in the evening, which is most of them. A lesson examined at 23:00 was
    // notified as due at 23:00 on day 30 while the lesson screen still showed
    // "باقي ١ يوم", so the reminder contradicted the screen it opened. For a
    // product whose whole mechanic is this clock, that is a credibility
    // problem rather than a cosmetic one.
    //
    // Anchoring to the day makes them the same statement: the reminder lands on
    // the day the screen turns, at an hour someone is awake for.
    return _reminderOn(last, kReviewCycleDays);
  }

  /// How many days before [dueAt] the early warning lands.
  ///
  /// Three, not one: a lesson is re-proven by sitting an exam on it, and an
  /// exam takes an evening to prepare for. A warning that arrives the night
  /// before is a warning the student cannot act on, which is the same as no
  /// warning at all. Three days is one weekend's reach.
  static const int kEarlyReminderDays = 3;

  /// The moment a lesson's *early* warning is posted -- [kEarlyReminderDays]
  /// before it falls due -- or null if it has never been examined.
  ///
  /// Derived from the same calendar anchoring as [dueAt], through the same
  /// helper, so the two cannot drift apart. Computing this as
  /// `dueAt(lesson)!.subtract(const Duration(days: 3))` would reintroduce
  /// exactly the elapsed-time arithmetic the comment above rejects: across a
  /// daylight-saving change it lands an hour off [kReminderHour], and the pair
  /// of reminders for one lesson would then disagree about what time of day
  /// they belong at.
  ///
  /// Note this can be in the past even when [dueAt] is not -- a lesson examined
  /// 28 days ago is due in two days and its early warning was owed yesterday.
  /// The caller drops it; see `ReviewNotificationService.planReminders`.
  static DateTime? earlyReminderAt(Lesson lesson) {
    final last = lesson.lastReviewedAt;
    if (last == null) return null;
    return _reminderOn(last, kReviewCycleDays - kEarlyReminderDays);
  }

  /// [daysAfter] calendar days after [last], at [kReminderHour].
  ///
  /// Built from calendar components rather than by adding a Duration: adding
  /// 30x24h across a daylight-saving change lands an hour off, and Egypt has
  /// one. Dart normalises an out-of-range day, so `day + 30` is exactly "the
  /// same date thirty days later".
  static DateTime _reminderOn(DateTime last, int daysAfter) =>
      DateTime(last.year, last.month, last.day + daysAfter, kReminderHour);

  /// A chapter is red if **even one** lesson inside it needs review.
  ///
  /// No averaging and no threshold -- deliberately. A chapter is a promise that
  /// its contents are current, and one decayed lesson breaks that promise.
  static bool chapterNeedsReview(
    StudySnapshot snapshot,
    int chapterId,
    DateTime now,
  ) {
    return snapshot.lessonsIn(chapterId).any((l) => needsReview(l, now));
  }

  static bool subjectNeedsReview(
    StudySnapshot snapshot,
    int subjectId,
    DateTime now,
  ) {
    return snapshot
        .chaptersIn(subjectId)
        .any((c) => chapterNeedsReview(snapshot, c.id, now));
  }

  /// Lessons due within the next [withinDays] days -- the dashboard's
  /// "مراجعات قريبة" figure. Excludes already-overdue lessons, which are
  /// counted separately and more urgently.
  static int upcomingReviewCount(
    StudySnapshot snapshot,
    DateTime now, {
    int withinDays = 7,
  }) {
    var count = 0;
    for (final lesson in snapshot.activeLessons) {
      final remaining = daysUntilDue(lesson, now);
      if (remaining != null && remaining <= withinDays) count++;
    }
    return count;
  }

  /// Everything needing attention, sorted for the Review Center.
  ///
  /// Order: overdue first (most overdue at the top), then low mastery (weakest
  /// first), then declining trend. A lesson appears once, under its most urgent
  /// reason.
  ///
  /// Walks **active subjects only**. The snapshot carries everything -- that is
  /// its contract -- so iterating its flat chapter list let a lesson under a
  /// binned or archived subject surface here as an urgent red row while its
  /// notifications were already silenced for exactly that reason. The queue and
  /// the tab badge it feeds have to agree on what exists.
  static List<ReviewItem> buildReviewQueue(
    StudySnapshot snapshot,
    DateTime now,
  ) {
    final items = <ReviewItem>[];

    for (final subject in snapshot.activeSubjects) {
      for (final chapter in snapshot.chaptersIn(subject.id)) {
        for (final lesson in snapshot.lessonsIn(chapter.id)) {
          final exams = snapshot.examsFor(lesson.id);
          final mastery = MasteryCalculator.lessonMastery(exams);

          final ReviewReason? reason;
          if (needsReview(lesson, now)) {
            reason = ReviewReason.overdue;
          } else if (exams.isNotEmpty && mastery < kLowMasteryFlagThreshold) {
            // `exams.isNotEmpty` matters: an unexamined lesson has mastery 0,
            // and without this guard every brand-new lesson would be dumped into
            // the Review Center as "low mastery" before it was ever studied.
            reason = ReviewReason.lowMastery;
          } else if (MasteryCalculator.isDeclining(exams)) {
            reason = ReviewReason.declining;
          } else {
            reason = null;
          }

          if (reason == null) continue;

          items.add(
            ReviewItem(
              lesson: lesson,
              chapterId: chapter.id,
              subjectId: chapter.subjectId,
              mastery: mastery,
              reason: reason,
              daysOverdue: daysOverdue(lesson, now),
            ),
          );
        }
      }
    }

    items.sort((a, b) {
      final byReason = a.reason.index.compareTo(b.reason.index);
      if (byReason != 0) return byReason;
      return switch (a.reason) {
        ReviewReason.overdue => b.daysOverdue.compareTo(a.daysOverdue),
        ReviewReason.lowMastery => a.mastery.compareTo(b.mastery),
        ReviewReason.declining => a.mastery.compareTo(b.mastery),
      };
    });

    return items;
  }

  /// Lessons blocking "أتقنت الباب", worst first.
  ///
  /// Unexamined lessons lead -- they are a harder blocker than a merely weak
  /// score, since there is no evidence at all.
  static List<({Lesson lesson, double mastery, bool hasExam})> chapterBlockers(
    StudySnapshot snapshot,
    int chapterId,
  ) {
    final blockers = <({Lesson lesson, double mastery, bool hasExam})>[];

    for (final lesson in snapshot.lessonsIn(chapterId)) {
      final exams = snapshot.examsFor(lesson.id);
      final mastery = MasteryCalculator.lessonMastery(exams);
      if (exams.isEmpty || mastery < kChapterMasteryThreshold) {
        blockers.add((
          lesson: lesson,
          mastery: mastery,
          hasExam: exams.isNotEmpty,
        ));
      }
    }

    blockers.sort((a, b) {
      if (a.hasExam != b.hasExam) return a.hasExam ? 1 : -1;
      return a.mastery.compareTo(b.mastery);
    });

    return blockers;
  }

  /// Whether "أتقنت الباب" should celebrate.
  ///
  /// Requires a non-empty chapter, an exam on every lesson, and chapter mastery
  /// at or above [kChapterMasteryThreshold]. All three, no exceptions -- a
  /// celebration the student did not earn devalues every future one.
  static bool canMasterChapter(StudySnapshot snapshot, int chapterId) {
    if (!MasteryCalculator.everyLessonExamined(snapshot, chapterId)) {
      return false;
    }
    return MasteryCalculator.chapterMasteryOf(snapshot, chapterId) >=
        kChapterMasteryThreshold;
  }

  // There was a `lessonsAwaitingNotification` here, and it was dead.
  //
  // It belonged to an earlier design where the app polled for overdue lessons
  // on each launch and posted reminders itself, using `lastNotifiedAt` to avoid
  // notifying twice in one cycle. That was replaced by `zonedSchedule`, which
  // books each reminder with the OS at the lesson's due moment so it fires with
  // the app closed — and nothing has called this since. It kept a full set of
  // passing tests the whole time, which is how it stayed looking alive.
  //
  // `lastNotifiedAt` itself stays. Dropping a column means a migration over a
  // student's curriculum — the one thing in this repo that cannot be
  // regenerated (§3.24) — to reclaim eight bytes a row, and `deleteExam` and
  // `recordExam` already keep it coherent for free.
}

/// Convenience view used by exam entry to decide `isReviewExam`.
extension ReviewStateX on Lesson {
  bool isOverdueAt(DateTime now) => ReviewCycleService.needsReview(this, now);
}

/// Re-exported so callers touching review logic do not also need to import
/// the exam entity just for [DraftQuestionGroup].
typedef ExamDraftGroup = DraftQuestionGroup;
