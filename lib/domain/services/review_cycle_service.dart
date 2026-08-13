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
  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

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
    return _dayNumber(now) - _dayNumber(last);
  }

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
  static DateTime? dueAt(Lesson lesson) {
    final last = lesson.lastReviewedAt;
    if (last == null) return null;
    return last.add(const Duration(days: kReviewCycleDays));
  }

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
    for (final lesson in snapshot.lessons) {
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
  static List<ReviewItem> buildReviewQueue(
    StudySnapshot snapshot,
    DateTime now,
  ) {
    final items = <ReviewItem>[];

    for (final chapter in snapshot.chapters) {
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
