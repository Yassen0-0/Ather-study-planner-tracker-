import '../entities/exam_entry.dart';
import '../entities/homework_entry.dart';
import '../entities/mastery.dart';
import '../entities/study_snapshot.dart';

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
  /// - n exams   -> `last * 0.7 + mean(all others) * 0.3`
  ///
  /// The 70/30 weighting means the most recent attempt dominates -- current
  /// understanding is what matters -- while history still exerts a pull, so one
  /// lucky paper cannot erase a run of weak ones.
  ///
  /// [exams] may be in any order; this sorts defensively rather than trusting
  /// the caller, because getting "the last exam" wrong silently corrupts every
  /// number in the app.
  static double lessonMastery(List<ExamEntry> exams) {
    if (exams.isEmpty) return 0;

    final sorted = List<ExamEntry>.of(exams)
      ..sort(StudySnapshot.compareExamsNewestFirst);

    if (sorted.length == 1) return sorted.first.percentage;

    final last = sorted.first;
    final previous = sorted.skip(1);
    final previousAverage =
        previous.map((e) => e.percentage).reduce((a, b) => a + b) /
        previous.length;

    return last.percentage * 0.7 + previousAverage * 0.3;
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
  /// Untouched subjects count as 0 and are **not** excluded, matching the rule
  /// used for empty lessons inside a chapter. An overall figure that quietly
  /// ignored three empty subjects would tell a student they are 85% ready for
  /// Thanaweya Amma when they have only touched Biology.
  static double overallMastery(StudySnapshot snapshot) {
    if (snapshot.subjects.isEmpty) return 0;
    final total = snapshot.subjects
        .map((s) => subjectMasteryOf(snapshot, s.id))
        .reduce((a, b) => a + b);
    return total / snapshot.subjects.length;
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
