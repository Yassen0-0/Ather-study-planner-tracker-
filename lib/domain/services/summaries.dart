import '../entities/chapter.dart';
import '../entities/lesson.dart';
import '../entities/mastery.dart';
import '../entities/study_snapshot.dart';
import '../entities/subject.dart';
import 'mastery_calculator.dart';
import 'review_cycle_service.dart';

/// Pre-computed rows for the UI.
///
/// Screens render these rather than calling [MasteryCalculator] themselves, so
/// a list of 200 lessons computes each mastery exactly once instead of once per
/// rebuild, and no two widgets can derive the same number differently.
/// Everything here is a pure function of a snapshot plus `now` — no Flutter, no
/// database, fully testable.

final class LessonSummary {
  const LessonSummary({
    required this.lesson,
    required this.mastery,
    required this.examCount,
    required this.needsReview,
    required this.daysOverdue,
    required this.daysUntilDue,
    required this.latestHomeworkPercentage,
  });

  final Lesson lesson;
  final double mastery;
  final int examCount;
  final bool needsReview;
  final int daysOverdue;
  final int? daysUntilDue;
  final double? latestHomeworkPercentage;

  bool get hasExam => examCount > 0;
  MasteryBand get band => MasteryBand.fromPercentage(mastery);

  /// True when the student has logged homework and it says "study more".
  bool get homeworkSuggestsMoreStudy {
    final hw = latestHomeworkPercentage;
    return hw != null && !MasteryCalculator.isReadyForExam(hw);
  }
}

final class ChapterSummary {
  const ChapterSummary({
    required this.chapter,
    required this.mastery,
    required this.lessons,
    required this.needsReview,
    required this.canMaster,
    required this.averageExamScore,
  });

  final Chapter chapter;
  final double mastery;
  final List<LessonSummary> lessons;

  /// True if **any** lesson inside has decayed. Overrides the mastery colour.
  final bool needsReview;

  final bool canMaster;
  final double averageExamScore;

  int get lessonCount => lessons.length;
  int get examinedLessonCount => lessons.where((l) => l.hasExam).length;
  MasteryBand get band => MasteryBand.fromPercentage(mastery);
  bool get isMastered => chapter.isMastered;

  /// Whether any evidence exists at all. Drives neutral-vs-red rendering, so an
  /// untouched chapter never looks like a failed one.
  bool get hasAnyExam => examinedLessonCount > 0;

  LessonSummary? get weakestLesson {
    if (lessons.isEmpty) return null;
    return lessons.reduce((a, b) => a.mastery <= b.mastery ? a : b);
  }
}

final class SubjectSummary {
  const SubjectSummary({
    required this.subject,
    required this.mastery,
    required this.chapters,
    required this.needsReview,
    required this.averageExamScore,
    required this.mostRecentChapterId,
    required this.mostRecentLessonId,
  });

  final Subject subject;
  final double mastery;
  final List<ChapterSummary> chapters;
  final bool needsReview;
  final double averageExamScore;

  /// Targets for the "كمّل" quick action.
  final int? mostRecentChapterId;
  final int? mostRecentLessonId;

  int get chapterCount => chapters.length;
  int get masteredChapterCount => chapters.where((c) => c.isMastered).length;
  MasteryBand get band => MasteryBand.fromPercentage(mastery);
  bool get hasContent => chapters.isNotEmpty;

  bool get hasAnyExam => chapters.any((c) => c.hasAnyExam);
}

final class DashboardSummary {
  const DashboardSummary({
    required this.subjects,
    required this.overallMastery,
    required this.masteredChapters,
    required this.totalChapters,
    required this.lessonsRemaining,
    required this.upcomingReviews,
    required this.overdueCount,
    required this.weakestSubject,
    required this.strongestSubject,
  });

  final List<SubjectSummary> subjects;
  final double overallMastery;
  final int masteredChapters;
  final int totalChapters;

  /// Lessons with no exam yet, or mastery below the 70% mastery threshold.
  final int lessonsRemaining;

  /// Lessons falling due within the next 7 days (excluding already-overdue).
  final int upcomingReviews;

  final int overdueCount;

  /// Null until at least one subject has content — ranking four empty subjects
  /// would name an arbitrary "weakest".
  final SubjectSummary? weakestSubject;
  final SubjectSummary? strongestSubject;

  bool get isEmpty => totalChapters == 0;

  bool get hasAnyExam => subjects.any((s) => s.hasAnyExam);
}

abstract final class Summaries {
  /// Every summary here takes an optional precomputed `masteries` map.
  ///
  /// **Why it is threaded through rather than recomputed.** A dashboard build
  /// used to reach each lesson about four times — its own summary, the chapter's
  /// mastery gate, the subject mean, and the overall mean — and every visit
  /// copied and re-sorted that lesson's exam list. Multiply by a few hundred
  /// lessons and it was the most expensive thing in the app, running on every
  /// database write and (before the clock was fixed) once a minute besides.
  ///
  /// Null means "compute it here", which keeps the per-screen family providers
  /// working unchanged.
  static LessonSummary lesson(
    StudySnapshot snapshot,
    Lesson lesson,
    DateTime now, {
    Map<int, double>? masteries,
  }) {
    final exams = snapshot.examsFor(lesson.id);
    return LessonSummary(
      lesson: lesson,
      mastery: masteries?[lesson.id] ?? MasteryCalculator.lessonMastery(exams),
      examCount: exams.length,
      needsReview: ReviewCycleService.needsReview(lesson, now),
      daysOverdue: ReviewCycleService.daysOverdue(lesson, now),
      daysUntilDue: ReviewCycleService.daysUntilDue(lesson, now),
      latestHomeworkPercentage: MasteryCalculator.latestHomeworkPercentage(
        snapshot.homeworkFor(lesson.id),
      ),
    );
  }

  static ChapterSummary chapter(
    StudySnapshot snapshot,
    Chapter chapter,
    DateTime now, {
    Map<int, double>? masteries,
  }) {
    final lessons = <LessonSummary>[
      for (final l in snapshot.lessonsIn(chapter.id))
        Summaries.lesson(snapshot, l, now, masteries: masteries),
    ];

    final mastery = MasteryCalculator.chapterMastery(
      lessons.map((l) => l.mastery).toList(),
    );

    return ChapterSummary(
      chapter: chapter,
      mastery: mastery,
      lessons: lessons,
      needsReview: lessons.any((l) => l.needsReview),
      // Read off the summaries just built rather than re-deriving the chapter's
      // mastery from the snapshot a second time. Identical by definition:
      // `canMasterChapter` is "every lesson examined, and the same chapter mean
      // at or above the threshold", and an empty chapter can never qualify.
      canMaster:
          lessons.isNotEmpty &&
          lessons.every((l) => l.hasExam) &&
          mastery >= kChapterMasteryThreshold,
      averageExamScore: MasteryCalculator.averageExamScore(
        snapshot,
        lessons.map((l) => l.lesson.id),
      ),
    );
  }

  static SubjectSummary subject(
    StudySnapshot snapshot,
    Subject subject,
    DateTime now, {
    Map<int, double>? masteries,
  }) {
    final chapters = <ChapterSummary>[
      for (final c in snapshot.chaptersIn(subject.id))
        Summaries.chapter(snapshot, c, now, masteries: masteries),
    ];

    // "Most recent activity" means the newest lesson in the newest chapter --
    // where the student was last working, which is where "كمّل" should land.
    ChapterSummary? recentChapter;
    for (final c in chapters) {
      if (recentChapter == null ||
          c.chapter.createdAt.isAfter(recentChapter.chapter.createdAt)) {
        recentChapter = c;
      }
    }
    LessonSummary? recentLesson;
    for (final l in recentChapter?.lessons ?? const <LessonSummary>[]) {
      if (recentLesson == null ||
          l.lesson.createdAt.isAfter(recentLesson.lesson.createdAt)) {
        recentLesson = l;
      }
    }

    return SubjectSummary(
      subject: subject,
      // The mean of the chapter means just computed. `subjectMasteryOf` is the
      // same arithmetic over the same numbers, so calling it here would walk
      // every lesson in the subject again for an answer already in hand.
      mastery: MasteryCalculator.chapterMastery(
        chapters.map((c) => c.mastery).toList(),
      ),
      chapters: chapters,
      needsReview: chapters.any((c) => c.needsReview),
      averageExamScore: MasteryCalculator.averageExamScore(
        snapshot,
        snapshot.lessonsInSubject(subject.id).map((l) => l.id),
      ),
      mostRecentChapterId: recentChapter?.chapter.id,
      mostRecentLessonId: recentLesson?.lesson.id,
    );
  }

  static DashboardSummary dashboard(StudySnapshot snapshot, DateTime now) {
    // Computed once here and handed down through every subject, chapter and
    // lesson below. This is the call the whole `masteries` parameter exists for.
    final masteries = MasteryCalculator.lessonMasteries(snapshot);

    // Archived subjects are excluded from every figure on this screen, not
    // merely hidden from the list. A student who archives a subject they are
    // not taking has said it should stop counting; leaving it in the overall
    // mean would drag their number down with a 0 for work they never intended
    // to do, which is the opposite of what the control promised.
    //
    // Nothing under an archived subject is deleted, so unarchiving restores
    // every number here exactly as it was.
    final subjects = <SubjectSummary>[
      for (final s in snapshot.activeSubjects)
        Summaries.subject(snapshot, s, now, masteries: masteries),
    ];

    var totalChapters = 0;
    var masteredChapters = 0;
    var lessonsRemaining = 0;
    var overdueCount = 0;

    for (final subject in subjects) {
      for (final chapter in subject.chapters) {
        totalChapters++;
        if (chapter.isMastered) masteredChapters++;
        for (final lesson in chapter.lessons) {
          if (!lesson.hasExam || lesson.mastery < kChapterMasteryThreshold) {
            lessonsRemaining++;
          }
          if (lesson.needsReview) overdueCount++;
        }
      }
    }

    final withContent = subjects.where((s) => s.hasContent).toList();
    SubjectSummary? weakest;
    SubjectSummary? strongest;
    for (final s in withContent) {
      if (weakest == null || s.mastery < weakest.mastery) weakest = s;
      if (strongest == null || s.mastery > strongest.mastery) strongest = s;
    }

    return DashboardSummary(
      subjects: subjects,
      // Again the same arithmetic over numbers already computed: the mean of
      // the four subject means, with untouched subjects counting as 0 rather
      // than being excluded (see `overallMastery`).
      overallMastery: MasteryCalculator.chapterMastery(
        subjects.map((s) => s.mastery).toList(),
      ),
      masteredChapters: masteredChapters,
      totalChapters: totalChapters,
      lessonsRemaining: lessonsRemaining,
      upcomingReviews: ReviewCycleService.upcomingReviewCount(snapshot, now),
      overdueCount: overdueCount,
      weakestSubject: weakest,
      strongestSubject: strongest,
    );
  }
}
