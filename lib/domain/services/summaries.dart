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
  static LessonSummary lesson(
    StudySnapshot snapshot,
    Lesson lesson,
    DateTime now,
  ) {
    final exams = snapshot.examsFor(lesson.id);
    return LessonSummary(
      lesson: lesson,
      mastery: MasteryCalculator.lessonMastery(exams),
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
    DateTime now,
  ) {
    final lessons = <LessonSummary>[
      for (final l in snapshot.lessonsIn(chapter.id))
        Summaries.lesson(snapshot, l, now),
    ];

    return ChapterSummary(
      chapter: chapter,
      mastery: MasteryCalculator.chapterMastery(
        lessons.map((l) => l.mastery).toList(),
      ),
      lessons: lessons,
      needsReview: lessons.any((l) => l.needsReview),
      canMaster: ReviewCycleService.canMasterChapter(snapshot, chapter.id),
      averageExamScore: MasteryCalculator.averageExamScore(
        snapshot,
        lessons.map((l) => l.lesson.id),
      ),
    );
  }

  static SubjectSummary subject(
    StudySnapshot snapshot,
    Subject subject,
    DateTime now,
  ) {
    final chapters = <ChapterSummary>[
      for (final c in snapshot.chaptersIn(subject.id))
        Summaries.chapter(snapshot, c, now),
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
      mastery: MasteryCalculator.subjectMasteryOf(snapshot, subject.id),
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
    final subjects = <SubjectSummary>[
      for (final s in snapshot.subjects) Summaries.subject(snapshot, s, now),
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
      overallMastery: MasteryCalculator.overallMastery(snapshot),
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
