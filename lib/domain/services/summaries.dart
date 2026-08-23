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
    this.latestHomeworkAt,
    this.firstExamAt,
  });

  final Lesson lesson;
  final double mastery;
  final int examCount;
  final bool needsReview;
  final int daysOverdue;
  final int? daysUntilDue;
  final double? latestHomeworkPercentage;

  /// When [latestHomeworkPercentage] was logged; null with it.
  final DateTime? latestHomeworkAt;

  /// The earliest exam recorded on this lesson; null while it has none.
  final DateTime? firstExamAt;

  bool get hasExam => examCount > 0;
  MasteryBand get band => MasteryBand.fromPercentage(mastery);

  /// «أثبت» — there is exam evidence behind this lesson and it still stands
  /// today: examined, not decayed, at or above the chapter threshold.
  ///
  /// This is the app's one definition of a proven lesson. Every surface that
  /// says a lesson has been *proven* derives it from here — never from
  /// `masteredAt`, never from the percentage alone, and never from a compound
  /// condition re-written at the call site.
  bool get isProven =>
      hasExam && !needsReview && mastery >= kChapterMasteryThreshold;

  /// «متفوق» — proven, and in the excellent band (≥ 90).
  ///
  /// The boundary comes from [MasteryBand] rather than a second literal, so the
  /// 90 that colours every screen decides this too.
  bool get isExcellent => isProven && band == MasteryBand.excellent;

  /// True when the student has logged homework and it says "study more".
  ///
  /// One silence rule: a homework **older than the lesson's first exam never
  /// speaks**. If [latestHomeworkAt] falls before [firstExamAt], the exam is
  /// newer evidence that already answered the question the homework was
  /// asked -- its score sits in mastery, where homework by design does not --
  /// so repeating the homework's stale verdict would have it judging a time
  /// that has already been superseded. The percentage and its date stay on
  /// screen; only this present-tense warning goes quiet.
  ///
  /// Silence needs both timestamps: homework logged after (or on the same
  /// instant as) the first exam is still the newest word, and with no exam at
  /// all the homework always is.
  bool get homeworkSuggestsMoreStudy {
    final hw = latestHomeworkPercentage;
    if (hw == null || MasteryCalculator.isReadyForExam(hw)) return false;
    final hwAt = latestHomeworkAt;
    final examAt = firstExamAt;
    if (hwAt != null && examAt != null && hwAt.isBefore(examAt)) return false;
    return true;
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

  /// «باب مُغلق حاليًا» — the closure event happened (`masteredAt` is set)
  /// **and** its evidence still stands today: every lesson examined, and the
  /// chapter mean at or above the threshold right now.
  ///
  /// [isMastered] alone is a date, not a standing quality — a chapter closed in
  /// March that gains an unexamined lesson in April was mastered once but is
  /// not closed *now*. This is the gate for every present-tense claim: the
  /// «أتقنت X من Y باب» counter and the green badge both read it. The date
  /// itself keeps being shown (neutrally) even when this is false.
  bool get isCurrentlyClosed =>
      chapter.masteredAt != null &&
      lessons.isNotEmpty &&
      lessons.every((l) => l.hasExam) &&
      mastery >= kChapterMasteryThreshold;

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

  /// Chapters whose closure still stands today. Present tense on purpose: a
  /// chapter mastered last month that has since gained an unexamined lesson
  /// does not count here, or the row would claim «X من Y باب» the dashboard
  /// below it contradicts.
  int get masteredChapterCount =>
      chapters.where((c) => c.isCurrentlyClosed).length;
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
    final homework = snapshot.homeworkFor(lesson.id);

    // The oldest exam, by createdAt rather than list position: the snapshot's
    // newest-first order is an invariant, but the meaning here is "first", so
    // it is computed as first and stays correct even if that invariant ever
    // changes.
    final DateTime? firstExamAt = exams.isEmpty
        ? null
        : exams
              .map((e) => e.createdAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);

    // Same choice of entry as `latestHomeworkPercentage` (newest createdAt),
    // so the date shown beside the percentage always belongs to it.
    final DateTime? latestHomeworkAt = homework.isEmpty
        ? null
        : homework
              .map((h) => h.createdAt)
              .reduce((a, b) => b.isAfter(a) ? b : a);

    return LessonSummary(
      lesson: lesson,
      mastery: masteries?[lesson.id] ?? MasteryCalculator.lessonMastery(exams),
      examCount: exams.length,
      needsReview: ReviewCycleService.needsReview(lesson, now),
      daysOverdue: ReviewCycleService.daysOverdue(lesson, now),
      daysUntilDue: ReviewCycleService.daysUntilDue(lesson, now),
      latestHomeworkPercentage: MasteryCalculator.latestHomeworkPercentage(
        homework,
      ),
      latestHomeworkAt: latestHomeworkAt,
      firstExamAt: firstExamAt,
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
        // The counter reads the closure's *current* evidence, not the raw
        // masteredAt date. A chapter whose conditions have since broken (a new
        // unexamined lesson, a mean that slipped) leaves the count here and
        // stops being claimed anywhere else either.
        if (chapter.isCurrentlyClosed) masteredChapters++;
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
