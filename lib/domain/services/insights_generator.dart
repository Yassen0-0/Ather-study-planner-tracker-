import '../entities/exam_entry.dart';
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

    for (final subject in snapshot.activeSubjects) {
      final before = subjectMasteryAsOf(snapshot, subject.id, cutoff);
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

    for (final lesson in snapshot.activeLessons) {
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

    for (final subject in snapshot.activeSubjects) {
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
  ///
  /// Shared with [MasteryTrends]: a trajectory is this same figure sampled at a
  /// series of past moments, and computing it two ways would let the chart and
  /// the "you improved" insight disagree about the same student.
  static double subjectMasteryAsOf(
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

/// One point on a subject's score-over-time line.
final class TrajectoryPoint {
  const TrajectoryPoint({required this.at, required this.mastery});

  /// The day this reading belongs to. Every exam recorded on that day is
  /// counted in [mastery]; nothing recorded after it is.
  final DateTime at;

  final double mastery;
}

/// A subject's mastery over time, and how fast it is moving.
final class SubjectTrajectory {
  const SubjectTrajectory({
    required this.subjectId,
    required this.points,
    required this.velocityPerCycle,
  });

  final int subjectId;

  /// Oldest first. One point per day the student sat an exam in this subject,
  /// thinned to [MasteryTrends.maxPoints] if there are more.
  final List<TrajectoryPoint> points;

  /// Percentage points gained (or lost) per review cycle -- per 30 days, the
  /// same unit the whole app is built around, so the figure is comparable to
  /// everything else the student reads here.
  ///
  /// Zero for a flat line, and zero when there is nothing to measure across.
  /// Negative when they are going backwards, which is the case worth showing
  /// and the reason this is not clamped at zero.
  final double velocityPerCycle;

  /// A line needs two readings.
  ///
  /// One exam is a dot, and a dot has no direction -- drawing a trend through
  /// it would invent one. The screen shows its existing "not enough data" state
  /// instead.
  bool get hasTrend => points.length >= 2;

  double get first => points.isEmpty ? 0 : points.first.mastery;
  double get last => points.isEmpty ? 0 : points.last.mastery;
}

/// Score-over-time and mastery-velocity, computed from recorded exams.
///
/// Separate from [InsightsGenerator] because it answers a different question --
/// that one picks the single most worth saying, this one hands back the whole
/// series -- but it samples through [InsightsGenerator.subjectMasteryAsOf] so
/// the chart and the insights cannot disagree.
abstract final class MasteryTrends {
  /// The most points a trajectory will carry.
  ///
  /// A student with two years of weekly exams has around a hundred exam days,
  /// and a hundred segments in a card 56 pixels tall is a smear rather than a
  /// line. Thinned evenly, always keeping the first and last reading, so the
  /// endpoints the velocity is computed from are the endpoints drawn.
  static const int maxPoints = 12;

  /// Every active subject's trajectory, in the snapshot's subject order.
  ///
  /// Subjects with no exams at all are included and come back with no points,
  /// so the caller can say "not enough data yet" for that subject rather than
  /// silently dropping it and leaving the student wondering where it went.
  static List<SubjectTrajectory> forAllSubjects(StudySnapshot snapshot) {
    return <SubjectTrajectory>[
      for (final subject in snapshot.activeSubjects)
        forSubject(snapshot, subject.id),
    ];
  }

  static SubjectTrajectory forSubject(StudySnapshot snapshot, int subjectId) {
    final days = _examDays(snapshot, subjectId);

    if (days.isEmpty) {
      return SubjectTrajectory(
        subjectId: subjectId,
        points: const <TrajectoryPoint>[],
        velocityPerCycle: 0,
      );
    }

    final sampled = _thin(days, maxPoints);
    final points = <TrajectoryPoint>[
      for (final day in sampled)
        TrajectoryPoint(
          at: day,
          // End of that day, so an exam sat that morning counts towards the
          // reading the student sees against that date.
          mastery: InsightsGenerator.subjectMasteryAsOf(
            snapshot,
            subjectId,
            _endOf(day),
          ),
        ),
    ];

    return SubjectTrajectory(
      subjectId: subjectId,
      points: points,
      velocityPerCycle: velocityOf(points),
    );
  }

  /// Change per review cycle across the whole series.
  ///
  /// Endpoint-to-endpoint rather than a fitted slope: the student can check
  /// this against the two ends of the line they are looking at, and a
  /// least-squares figure that disagrees with the picture would be a number
  /// they cannot verify. Ather's one rule is that its figures are checkable.
  ///
  /// Returns 0 for fewer than two points, and 0 when both readings land on the
  /// same day -- an interval of no time has no rate, and dividing by it would
  /// report an infinite one.
  static double velocityOf(List<TrajectoryPoint> points) {
    if (points.length < 2) return 0;

    final first = points.first;
    final last = points.last;
    // Calendar days, through the review cycle's own helper. **Not**
    // `difference().inDays`: that is elapsed time, and across the night Egypt
    // puts its clocks forward a 30-day span measures 29, which would report a
    // rate 3% too high for half the year. It is the same defect the comment on
    // `ReviewCycleService.dueAt` exists to prevent, arriving through division
    // instead of through addition.
    final days = ReviewCycleService.calendarDaysBetween(first.at, last.at);
    if (days <= 0) return 0;

    return (last.mastery - first.mastery) / days * kReviewCycleDays;
  }

  /// The distinct days on which this subject was examined, oldest first.
  static List<DateTime> _examDays(StudySnapshot snapshot, int subjectId) {
    final days = <DateTime>{};
    for (final lesson in snapshot.lessonsInSubject(subjectId)) {
      for (final ExamEntry exam in snapshot.examsFor(lesson.id)) {
        final at = exam.createdAt;
        days.add(DateTime(at.year, at.month, at.day));
      }
    }
    return days.toList()..sort();
  }

  /// [days] reduced to at most [limit] entries, keeping both endpoints.
  static List<DateTime> _thin(List<DateTime> days, int limit) {
    if (days.length <= limit) return days;

    final out = <DateTime>[];
    // Spread the interior samples evenly across the range; the -1s put the
    // last sample exactly on the last day rather than one step short of it.
    for (var i = 0; i < limit; i++) {
      out.add(days[(i * (days.length - 1) / (limit - 1)).round()]);
    }
    return out;
  }

  static DateTime _endOf(DateTime day) =>
      DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
}
