import '../entities/exam_entry.dart';
import '../entities/homework_entry.dart';
import '../entities/mastery.dart';
import '../entities/study_snapshot.dart';

/// Weight of the most recent exam in the mastery formula.
///
/// Why 0.7: the figure must describe how the student performs **now**, so the
/// latest paper carries the majority of the weight -- but not all of it. A pure
/// last-exam rule would let one bad morning erase a term of evidence, and one
/// lucky guess fake a term of it.
const double kRecentWeight = 0.7;

/// Weight of the mean of every exam before the most recent one.
///
/// Why 0.3: history must keep exerting a real pull against a single outlier,
/// yet stay the minority voice next to [kRecentWeight]. The two sum to exactly
/// 1 so mastery stays on the 0-100 scale. Changing either number rewrites
/// every figure in the app at once -- a product decision, not a tweak.
const double kHistoryWeight = 0.3;

/// The mastery formula. Pure, dependency-free, and the single place these rules
/// exist -- no screen re-implements any of it.
///
/// The product's whole claim rests on this file: mastery comes from exam
/// performance and nothing else. Time studied, checklist ticks and homework
/// scores are deliberately absent from every function here.
abstract final class MasteryCalculator {
  /// Mastery for one lesson, from its exams.
  ///
  /// - no exams  -> 0 (an unexamined lesson is not "in progress", it is unproven)
  /// - one exam  -> that exam's percentage
  /// - n exams   -> `last * kRecentWeight + mean(all others) * kHistoryWeight`
  ///
  /// The weighting lives in [kRecentWeight] and [kHistoryWeight]; see them for
  /// why these two numbers.
  ///
  /// [exams] may be in any order; this sorts defensively rather than trusting
  /// the caller, because getting "the last exam" wrong silently corrupts every
  /// number in the app.
  ///
  /// The copy-and-sort is why [Summaries] threads a precomputed map around
  /// instead of calling this repeatedly: a dashboard build reaches every lesson
  /// roughly four times (its own summary, the chapter gate, the subject mean and
  /// the overall mean), and each visit used to allocate a fresh list and re-sort
  /// it. The defensive sort stays — this is a public entry point and a caller
  /// handing it unsorted exams must still get the right answer.
  static double lessonMastery(List<ExamEntry> exams) {
    final sorted = List<ExamEntry>.of(exams)
      ..sort(StudySnapshot.compareExamsNewestFirst);
    return _masteryFromSorted(sorted);
  }

  /// Every lesson's mastery, computed once.
  ///
  /// The snapshot already indexes exams by lesson **and sorts each list
  /// newest-first in its constructor**, so this can skip the defensive copy that
  /// [lessonMastery] makes — the invariant holds by construction here, and it is
  /// the one place allowed to rely on it.
  static Map<int, double> lessonMasteries(StudySnapshot snapshot) {
    final byLesson = <int, double>{};
    for (final lesson in snapshot.lessons) {
      byLesson[lesson.id] = _masteryFromSorted(snapshot.examsFor(lesson.id));
    }
    return byLesson;
  }

  /// The mastery arithmetic itself, over exams already sorted newest-first.
  ///
  /// Both entry points funnel through here -- [lessonMastery] after its
  /// defensive sort, [lessonMasteries] on the snapshot's constructor-sorted
  /// lists -- so the formula exists at exactly one place and the two paths
  /// cannot drift apart. Callers own the ordering contract; the size cases are
  /// part of the formula:
  ///
  /// - no exams  -> 0
  /// - one exam  -> that percentage
  /// - n exams  -> `first * kRecentWeight + mean(rest) * kHistoryWeight`
  static double _masteryFromSorted(List<ExamEntry> sorted) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first.percentage;

    var previousTotal = 0.0;
    for (var i = 1; i < sorted.length; i++) {
      previousTotal += sorted[i].percentage;
    }
    return sorted.first.percentage * kRecentWeight +
        (previousTotal / (sorted.length - 1)) * kHistoryWeight;
  }

  /// Mastery for a chapter: the plain mean of its lessons' mastery.
  ///
  /// Lessons with no exams contribute **0** and are never filtered out. Dropping
  /// them would let a chapter with one examined lesson and nine untouched ones
  /// report full mastery -- the exact self-deception this app exists to prevent.
  static double chapterMastery(List<double> lessonMasteries) {
    if (lessonMasteries.isEmpty) return 0;
    return lessonMasteries.reduce((a, b) => a + b) / lessonMasteries.length;
  }

  /// Chapter mastery read straight from a snapshot.
  static double chapterMasteryOf(StudySnapshot snapshot, int chapterId) {
    final lessons = snapshot.lessonsIn(chapterId);
    return chapterMastery(<double>[
      for (final lesson in lessons) lessonMastery(snapshot.examsFor(lesson.id)),
    ]);
  }

  /// Subject mastery: the mean across every chapter in the subject.
  ///
  /// Averaged over chapters rather than over all lessons, so a 40-lesson chapter
  /// does not drown out a 4-lesson one — each chapter is an equal unit of
  /// curriculum.
  static double subjectMasteryOf(StudySnapshot snapshot, int subjectId) {
    final chapters = snapshot.chaptersIn(subjectId);
    if (chapters.isEmpty) return 0;
    final total = chapters
        .map((c) => chapterMasteryOf(snapshot, c.id))
        .reduce((a, b) => a + b);
    return total / chapters.length;
  }

  /// Overall mastery: the mean of all four subject masteries.
  ///
  /// This is the **official interface** for computing the number standalone --
  /// reports, insights, tests. [Summaries.dashboard] deliberately does not call
  /// it: the dashboard derives the same mean inline from the subject summaries
  /// it has already built rather than walking the curriculum a second time.
  /// That inline path and this one are pinned together by the parity contract
  /// test in `test/domain/mastery_calculator_test.dart`, so neither can drift
  /// from the figure the student actually sees.
  ///
  /// Untouched subjects count as 0 and are **not** excluded, matching the rule
  /// used for empty lessons inside a chapter. An overall figure that quietly
  /// ignored three empty subjects would tell a student they are 85% ready for
  /// Thanaweya Amma when they have only touched Biology.
  ///
  /// *Archived* subjects are a different case and are excluded: the student
  /// said this subject should stop counting, and counting it as a 0 anyway
  /// would punish them for saying so.
  static double overallMastery(StudySnapshot snapshot) {
    final active = snapshot.activeSubjects;
    if (active.isEmpty) return 0;
    final total = active
        .map((s) => subjectMasteryOf(snapshot, s.id))
        .reduce((a, b) => a + b);
    return total / active.length;
  }

  /// Mean of the raw exam percentages under a set of lessons.
  /// Distinct from mastery: no 70/30 weighting, every exam counts once.
  static double averageExamScore(
    StudySnapshot snapshot,
    Iterable<int> lessonIds,
  ) {
    final percentages = <double>[
      for (final id in lessonIds)
        ...snapshot.examsFor(id).map((e) => e.percentage),
    ];
    if (percentages.isEmpty) return 0;
    return percentages.reduce((a, b) => a + b) / percentages.length;
  }

  /// The percentage the *next* paper must reach for the lesson to cross
  /// [threshold], or null when there is nothing to cross.
  ///
  /// Answers the student's one real question after a bad paper: "how much do I
  /// need next time?". The formula is [lessonMastery] inverted around the paper
  /// that would arrive next: that paper becomes the newest, so what stands as
  /// its history is every exam the lesson already has --
  ///
  ///     mastery' = x·kRecentWeight + meanOfExisting·kHistoryWeight >= threshold
  ///     =>       x = (threshold - kHistoryWeight·meanOfExisting) / kRecentWeight
  ///
  /// [meanOfExisting] is the plain mean of **all** the percentages the lesson's
  /// exams already hold, read from the records themselves -- never derived from
  /// a displayed mastery figure. The displayed figure collapses {0,100} and
  /// {100,0} to different numbers depending on order; the records do not, and
  /// only the records know the history weight will actually pull on.
  ///
  /// null when [meanOfExisting] already sits at or above [threshold]: there is
  /// no line to cross, and inventing one would nag a student who has crossed.
  ///
  /// Rounds **up**: a promised score must clear the threshold once sat, and a
  /// rounded-down 61% against mean 90 lands at 69.7 -- a promise that breaks.
  /// Clamped into [0, 100] so floating-point overshoot at the exact-100 end
  /// cannot advertise more than a perfect paper.
  static int? scoreNeededToCross({
    required double meanOfExisting,
    double threshold = kChapterMasteryThreshold,
  }) {
    // No early return for a high mean: the question is "what does the NEXT
    // paper need for the lesson to sit at or above the threshold", and that
    // has an answer for every mean in [0, 100] -- a strong past pulls the
    // requirement down, it does not exempt the next paper. Whether the line
    // is worth SHOWING is the caller's call (it appears only when today's
    // mastery sits below the threshold).
    final double needed =
        (threshold - kHistoryWeight * meanOfExisting) / kRecentWeight;
    return needed.ceil().clamp(0, 100);
  }

  /// Most recent homework percentage for a lesson, or null if none logged.
  static double? latestHomeworkPercentage(List<HomeworkEntry> entries) {
    if (entries.isEmpty) return null;
    final sorted = List<HomeworkEntry>.of(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.percentage;
  }

  /// Whether the student should study more before sitting the exam.
  ///
  /// Advisory only. This never touches [lessonMastery] -- if it ever does, the
  /// product has broken its core promise.
  static bool isReadyForExam(double homeworkPercentage) =>
      homeworkPercentage >= kHomeworkReadinessThreshold;

  /// True when every lesson in the chapter has at least one exam.
  static bool everyLessonExamined(StudySnapshot snapshot, int chapterId) {
    final lessons = snapshot.lessonsIn(chapterId);
    if (lessons.isEmpty) return false;
    return lessons.every((l) => snapshot.examsFor(l.id).isNotEmpty);
  }

  /// Whether the mastery trend across a lesson's last two exams is downward.
  /// Requires at least two exams; a single exam has no trend.
  static bool isDeclining(List<ExamEntry> exams) {
    if (exams.length < 2) return false;
    final sorted = List<ExamEntry>.of(exams)
      ..sort(StudySnapshot.compareExamsNewestFirst);
    return sorted[0].percentage < sorted[1].percentage;
  }
}
