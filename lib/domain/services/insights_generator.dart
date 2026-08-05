import '../entities/mastery.dart';
import '../entities/study_snapshot.dart';
import 'mastery_calculator.dart';
import 'review_cycle_service.dart';

/// A generated observation about the student's real data.
///
/// Deliberately **structured, not pre-formatted text**. The generator lives in
/// the domain layer and has no access to localisation; emitting sealed variants
/// lets the presentation layer render each one through the ARB files, so
/// insights translate with the ar/en toggle instead of being frozen in one
/// language at the point they were computed.
sealed class Insight {
  const Insight();
}

/// A subject's mastery rose measurably over the trailing window.
final class SubjectImprovedInsight extends Insight {
  const SubjectImprovedInsight({
    required this.subjectId,
    required this.deltaPercentagePoints,
  });

  final int subjectId;
  final double deltaPercentagePoints;
}

/// A chapter is dragging its subject down.
final class ChapterNeedsAttentionInsight extends Insight {
  const ChapterNeedsAttentionInsight({
    required this.chapterId,
    required this.subjectId,
    required this.chapterName,
    required this.mastery,
  });

  final int chapterId;
  final int subjectId;
  final String chapterName;
  final double mastery;
}

/// A lesson has gone unproven for a long time.
final class LessonNotReviewedInsight extends Insight {
  const LessonNotReviewedInsight({
    required this.lessonId,
    required this.lessonName,
    required this.days,
  });

  final int lessonId;
  final String lessonName;
  final int days;
}

/// The student's current best subject.
final class StrongestSubjectInsight extends Insight {
  const StrongestSubjectInsight({
    required this.subjectId,
    required this.mastery,
  });

  final int subjectId;
  final double mastery;
}

/// Rule-based insight generation over real calculated deltas.
///
/// No machine learning and no invented categories: every insight below is
/// derived from data the app actually stores. If a claim cannot be computed from
/// exams, chapters and review dates, it is not generated.
abstract final class InsightsGenerator {
  /// Minimum rise, in percentage points, before "you improved" is worth saying.
  /// Below this it is noise from a single exam and reads as flattery.
  static const double _minimumImprovement = 5;

  /// A chapter must be at least this weak to be called out.
  static const double _attentionThreshold = 50;

  /// Days unreviewed before a lesson is worth mentioning by name.
  static const int _stalenessDays = 45;

  static const int _maxInsights = 4;

  static List<Insight> generate(
    StudySnapshot snapshot,
    DateTime now, {
    Duration window = const Duration(days: 30),
  }) {
    final insights = <Insight>[];

    _addImprovement(snapshot, now, window, insights);
    _addWeakestChapter(snapshot, insights);
    _addStalestLesson(snapshot, now, insights);
    _addStrongestSubject(snapshot, insights);

    return insights.take(_maxInsights).toList();
  }

  /// Compares each subject's mastery now against its mastery computed from
  /// only the exams that existed at the start of the window.
  static void _addImprovement(
    StudySnapshot snapshot,
    DateTime now,
    Duration window,
    List<Insight> out,
  ) {
    final cutoff = now.subtract(window);

    int? bestSubject;
    var bestDelta = 0.0;

    for (final subject in snapshot.subjects) {
      final before = _subjectMasteryAsOf(snapshot, subject.id, cutoff);
      // A subject with no exam history before the window has nothing to improve
      // *from* -- reporting "up 90%" on a first-ever exam is meaningless.
      if (before <= 0) continue;

      final delta =
          MasteryCalculator.subjectMasteryOf(snapshot, subject.id) - before;
      if (delta >= _minimumImprovement && delta > bestDelta) {
        bestDelta = delta;
        bestSubject = subject.id;
      }
    }

    if (bestSubject != null) {
      out.add(
        SubjectImprovedInsight(
          subjectId: bestSubject,
          deltaPercentagePoints: bestDelta,
        ),
      );
    }
  }

  static void _addWeakestChapter(StudySnapshot snapshot, List<Insight> out) {
    ({int chapterId, int subjectId, String name, double mastery})? worst;

    for (final chapter in snapshot.chapters) {
      final lessons = snapshot.lessonsIn(chapter.id);
      // Skip untouched chapters -- "your empty chapter is weak" is not an
      // insight, it is a tautology.
      if (lessons.isEmpty) continue;
      if (!lessons.any((l) => snapshot.examsFor(l.id).isNotEmpty)) continue;

      final mastery = MasteryCalculator.chapterMasteryOf(snapshot, chapter.id);
      if (mastery >= _attentionThreshold) continue;

      if (worst == null || mastery < worst.mastery) {
        worst = (
          chapterId: chapter.id,
          subjectId: chapter.subjectId,
          name: chapter.name,
          mastery: mastery,
        );
      }
    }

    if (worst != null) {
      out.add(
        ChapterNeedsAttentionInsight(
          chapterId: worst.chapterId,
          subjectId: worst.subjectId,
          chapterName: worst.name,
          mastery: worst.mastery,
        ),
      );
    }
  }

  static void _addStalestLesson(
    StudySnapshot snapshot,
    DateTime now,
    List<Insight> out,
  ) {
    ({int id, String name, int days})? stalest;

    for (final lesson in snapshot.lessons) {
      final days = ReviewCycleService.daysSinceReview(lesson, now);
      if (days == null || days < _stalenessDays) continue;
      if (stalest == null || days > stalest.days) {
        stalest = (id: lesson.id, name: lesson.name, days: days);
      }
    }

    if (stalest != null) {
      out.add(
        LessonNotReviewedInsight(
          lessonId: stalest.id,
          lessonName: stalest.name,
          days: stalest.days,
        ),
      );
    }
  }

  static void _addStrongestSubject(StudySnapshot snapshot, List<Insight> out) {
    int? best;
    var bestMastery = 0.0;

    for (final subject in snapshot.subjects) {
      final mastery = MasteryCalculator.subjectMasteryOf(snapshot, subject.id);
      if (mastery > bestMastery) {
        bestMastery = mastery;
        best = subject.id;
      }
    }

    // Requires a genuinely good subject. Crowning a "strongest" subject at 12%
    // would be technically true and actively misleading.
    if (best != null && bestMastery >= kChapterMasteryThreshold) {
      out.add(StrongestSubjectInsight(subjectId: best, mastery: bestMastery));
    }
  }

  /// Subject mastery recomputed from only the exams that existed at [asOf].
  static double _subjectMasteryAsOf(
    StudySnapshot snapshot,
    int subjectId,
    DateTime asOf,
  ) {
    final chapters = snapshot.chaptersIn(subjectId);
    if (chapters.isEmpty) return 0;

    var total = 0.0;
    for (final chapter in chapters) {
      final lessons = snapshot.lessonsIn(chapter.id);
      if (lessons.isEmpty) {
        continue; // contributes 0
      }
      var chapterTotal = 0.0;
      for (final lesson in lessons) {
        final past = snapshot
            .examsFor(lesson.id)
            .where((e) => !e.createdAt.isAfter(asOf))
            .toList();
        chapterTotal += MasteryCalculator.lessonMastery(past);
      }
      total += chapterTotal / lessons.length;
    }
    return total / chapters.length;
  }
}
