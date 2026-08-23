import '../entities/lesson.dart';
import '../entities/mastery.dart';
import '../entities/study_snapshot.dart';
import 'mastery_calculator.dart';
import 'review_cycle_service.dart';

/// Which of the three exam-eve tiers a lesson landed in. The sheet draws its
/// section header from this, so the UI never re-derives the classification.
enum ExamEveTier {
  /// Never examined -- there is no evidence at all to stand on tonight.
  unsettled,

  /// Examined, but below [kChapterMasteryThreshold] -- proof exists and is thin.
  weakest,

  /// Proven today, and either already past its 30-day mark or approaching it.
  nearestDue,
}

/// One row of the exam-eve plan: everything the sheet needs to draw it and
/// send the student into the wizard.
final class ExamEveEntry {
  const ExamEveEntry({
    required this.lesson,
    required this.chapterName,
    required this.tier,
    required this.mastery,
    required this.hasExam,
    required this.daysUntilDue,
    required this.daysOverdue,
  });

  final Lesson lesson;
  final String chapterName;
  final ExamEveTier tier;

  /// [MasteryCalculator.lessonMastery] over the lesson's exams -- 0 while
  /// [hasExam] is false.
  final double mastery;
  final bool hasExam;

  /// Null while never examined or already past due; otherwise whole calendar
  /// days left in the current cycle.
  final int? daysUntilDue;
  final int daysOverdue;

  /// Sort key for the [ExamEveTier.nearestDue] tier. A lesson still inside its
  /// cycle sorts by the days it has left; one that has already fallen sorts
  /// *before every positive count*, because negative is closer than any number
  /// of remaining days. Both halves come straight from the review clock --
  /// [ReviewCycleService.daysUntilDue] and [ReviewCycleService.daysOverdue] --
  /// so this cannot disagree with the badges on the lesson screen.
  int get urgency => daysUntilDue ?? -daysOverdue;
}

/// The whole night's triage for one subject.
final class ExamEvePlan {
  const ExamEvePlan({
    required this.unsettled,
    required this.weakest,
    required this.nearestDue,
  });

  /// Tier 1, in curriculum order (chapter order, then creation order).
  final List<ExamEveEntry> unsettled;

  /// Tier 2, weakest mastery first.
  final List<ExamEveEntry> weakest;

  /// Tier 3, most urgent first: already-overdue leads, then fewest days left.
  final List<ExamEveEntry> nearestDue;

  bool get isEmpty =>
      unsettled.isEmpty && weakest.isEmpty && nearestDue.isEmpty;
}

/// وضع ليلة الامتحان (audit P5-04 / ideas #8).
///
/// The night before an exam the student does not want a curriculum browser;
/// they want to know **what to prove tonight, in what order**. This answers
/// that as three tiers over one subject:
///
/// 1. **غير مُثبت** -- no exam ever recorded. The hardest blocker there is:
///    not a weak score, no evidence at all (the same logic that puts
///    unexamined lessons first in `chapterBlockers`).
/// 2. **الأضعف إتقانًا** -- examined but under [kChapterMasteryThreshold], so
///    the chapter-closure promise does not hold for them yet; worst score on
///    top (`weakestLesson` extended from one lesson to the whole subject).
/// 3. **الأقرب سقوطًا** -- proven today, ranked by how soon the 30-day cycle
///    drops them (`daysUntilDue` ascending), with already-fallen lessons first
///    ([ExamEveEntry.urgency]).
///
/// Every lesson appears **exactly once**, under its most urgent tier: a weak
/// lesson that is also near its due date sits in tier 2, because raising it
/// re-proves it anyway, and a row listed twice reads to a student as a bug.
///
/// Pure over a snapshot plus `now`, like every service here -- no Flutter, no
/// database, testable in constructed fixtures in microseconds.
abstract final class ExamEveService {
  static ExamEvePlan plan(
    StudySnapshot snapshot,
    int subjectId,
    DateTime now,
  ) {
    final unsettled = <ExamEveEntry>[];
    final weakest = <ExamEveEntry>[];
    final nearestDue = <ExamEveEntry>[];

    // Walks chapters then lessons, the way the student built them, rather
    // than the flat `lessons` table -- curriculum order is meaningful on the
    // night before an exam, and `chaptersIn`/`lessonsIn` keep archived or
    // deleted subjects out for free.
    for (final chapter in snapshot.chaptersIn(subjectId)) {
      for (final lesson in snapshot.lessonsIn(chapter.id)) {
        final exams = snapshot.examsFor(lesson.id);
        final mastery = MasteryCalculator.lessonMastery(exams);
        final entry = ExamEveEntry(
          lesson: lesson,
          chapterName: chapter.name,
          tier: switch ((exams.isEmpty, mastery)) {
            (true, _) => ExamEveTier.unsettled,
            (false, < kChapterMasteryThreshold) => ExamEveTier.weakest,
            (false, _) => ExamEveTier.nearestDue,
          },
          mastery: mastery,
          hasExam: exams.isNotEmpty,
          daysUntilDue: ReviewCycleService.daysUntilDue(lesson, now),
          daysOverdue: ReviewCycleService.daysOverdue(lesson, now),
        );

        switch (entry.tier) {
          case ExamEveTier.unsettled:
            unsettled.add(entry);
          case ExamEveTier.weakest:
            weakest.add(entry);
          case ExamEveTier.nearestDue:
            nearestDue.add(entry);
        }
      }
    }

    // Ties break by id so two lessons with equal mastery (or equal urgency)
    // sort deterministically -- otherwise the sheet's order could flip between
    // rebuilds, which reads as the app losing its place.
    int tieBreak(ExamEveEntry a, ExamEveEntry b) =>
        a.lesson.id.compareTo(b.lesson.id);

    weakest.sort((a, b) {
      final byMastery = a.mastery.compareTo(b.mastery);
      return byMastery != 0 ? byMastery : tieBreak(a, b);
    });
    nearestDue.sort((a, b) {
      final byUrgency = a.urgency.compareTo(b.urgency);
      return byUrgency != 0 ? byUrgency : tieBreak(a, b);
    });

    return ExamEvePlan(
      unsettled: unsettled,
      weakest: weakest,
      nearestDue: nearestDue,
    );
  }
}
