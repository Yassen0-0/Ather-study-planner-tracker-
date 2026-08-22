import '../entities/chapter.dart';
import '../entities/exam_entry.dart';
import '../entities/lesson.dart';
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

    // Every lesson's mastery, computed once and threaded through everything
    // below -- the same arrangement `Summaries.dashboard` uses. The walks this
    // replaces each reached every lesson again and copied and re-sorted its
    // exam list on every visit; the map holds exactly those same values read
    // off the ordering the snapshot already guarantees.
    final masteries = MasteryCalculator.lessonMasteries(snapshot);

    _addImprovement(snapshot, now, window, insights);
    _addWeakestChapter(snapshot, masteries, insights);
    _addStalestLesson(snapshot, now, insights);
    _addStrongestSubject(snapshot, masteries, insights);

    return insights.take(_maxInsights).toList();
  }

  /// Compares each subject's recent exam scores against where that subject
  /// stood when the window opened.
  ///
  /// Both sides are plain means of raw exam percentages read straight off
  /// the snapshot -- not the weighted mastery figure -- so one claim never
  /// mixes two different units.
  ///
  /// The baseline:
  ///
  /// - exams before the window exist -> their mean. The ordinary case.
  /// - none do -> the subject was born inside the window, so its **first**
  ///   exam is the baseline and the rise is measured only in what came
  ///   after it. Skipping zero-baseline subjects outright -- the old rule --
  ///   meant the best improvement story there is, 0 -> 90 in a first month,
  ///   could never be told until a month of history existed. Starting at
  ///   zero is a real starting point; only having no paper after it is
  ///   nothing to measure.
  ///
  /// Either way [_minimumImprovement] stands guard: against a one-exam
  /// baseline especially, a smaller move is noise from a single paper, and
  /// reporting it would be flattery rather than insight.
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
      final chronological =
          List<ExamEntry>.of(_examsIn(snapshot, subject.id))
            ..sort(_oldestFirst);

      final before = <double>[];
      final inside = <ExamEntry>[];
      for (final exam in chronological) {
        if (exam.createdAt.isAfter(cutoff)) {
          inside.add(exam);
        } else {
          before.add(exam.percentage);
        }
      }
      // Nothing sat inside the window: whatever changed changed too long
      // ago for "you improved" to be news today.
      if (inside.isEmpty) continue;

      final double baseline;
      final List<ExamEntry> measured;
      if (before.isNotEmpty) {
        baseline = _averageOf(before);
        measured = inside;
      } else {
        baseline = inside.first.percentage;
        measured = inside.sublist(1);
      }
      if (measured.isEmpty) continue;

      final delta = _averageOf(<double>[
        for (final exam in measured) exam.percentage,
      ]) - baseline;
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

  /// Every exam recorded under a subject's lessons, across all its chapters.
  static List<ExamEntry> _examsIn(StudySnapshot snapshot, int subjectId) =>
      <ExamEntry>[
        for (final lesson in snapshot.lessonsInSubject(subjectId))
          ...snapshot.examsFor(lesson.id),
      ];

  /// Oldest first; ties break by ascending id -- the mirror of
  /// [StudySnapshot.compareExamsNewestFirst], so "the first exam" stays
  /// deterministic even between papers saved in the same millisecond.
  static int _oldestFirst(ExamEntry a, ExamEntry b) {
    final byDate = a.createdAt.compareTo(b.createdAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  static double _averageOf(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  static void _addWeakestChapter(
    StudySnapshot snapshot,
    Map<int, double> masteries,
    List<Insight> out,
  ) {
    ({int chapterId, int subjectId, String name, double mastery})? worst;

    // Active subjects only. The snapshot carries binned and archived subjects
    // by design, and crowning a chapter under one as "needs attention" would
    // have the app nagging about work the student deliberately put away --
    // while every other surface had already agreed to fall silent on it.
    for (final subject in snapshot.activeSubjects) {
      for (final chapter in snapshot.chaptersIn(subject.id)) {
        final lessons = snapshot.lessonsIn(chapter.id);
        // Skip untouched chapters -- "your empty chapter is weak" is not an
        // insight, it is a tautology.
        if (lessons.isEmpty) continue;
        if (!lessons.any((l) => snapshot.examsFor(l.id).isNotEmpty)) continue;

        final mastery = _chapterMastery(snapshot, chapter.id, masteries);
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

  static void _addStrongestSubject(
    StudySnapshot snapshot,
    Map<int, double> masteries,
    List<Insight> out,
  ) {
    int? best;
    var bestMastery = 0.0;

    for (final subject in snapshot.activeSubjects) {
      final mastery = _subjectMastery(snapshot, subject.id, masteries);
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

  /// Chapter mastery read off a precomputed [masteries] map.
  ///
  /// The same arithmetic as `MasteryCalculator.chapterMasteryOf` with the same
  /// answer -- the map holds exactly that function's per-lesson values -- minus
  /// the fresh copy and defensive sort of every lesson's exam list at every
  /// visit. An unexamined lesson is already mapped to 0, matching the rule
  /// that untouched lessons count rather than being filtered out.
  static double _chapterMastery(
    StudySnapshot snapshot,
    int chapterId,
    Map<int, double> masteries,
  ) {
    return MasteryCalculator.chapterMastery(<double>[
      for (final lesson in snapshot.lessonsIn(chapterId))
        masteries[lesson.id] ?? 0,
    ]);
  }

  /// Subject mastery read off the same shared map: the mean of its chapters'
  /// means, each chapter an equal unit of curriculum, as before.
  static double _subjectMastery(
    StudySnapshot snapshot,
    int subjectId,
    Map<int, double> masteries,
  ) {
    final chapters = snapshot.chaptersIn(subjectId);
    if (chapters.isEmpty) return 0;
    final total = chapters
        .map((c) => _chapterMastery(snapshot, c.id, masteries))
        .reduce((a, b) => a + b);
    return total / chapters.length;
  }

  /// Subject mastery as the student would have seen it on [asOf].
  ///
  /// Shared with [MasteryTrends]: a trajectory is this same figure sampled at a
  /// series of past moments, and computing it two ways would let the chart and
  /// the "you improved" insight disagree about the same student.
  ///
  /// **The curriculum is rewound too, not just the exams.** Filtering exams by
  /// date while dividing by *today's* lesson count reports every lesson the
  /// student had not created yet as a lesson they scored zero on. The bias is
  /// small across a 30-day insight window and dominates across a whole
  /// history, which is exactly what the trajectory chart asks for:
  ///
  /// A student with one lesson scores 80% in January, and the app shows the
  /// subject at 80% that day. By June they have ten lessons and 80% on every
  /// one, so the subject still reads 80%. Sampled with today's roster, the
  /// January point comes out `(80 + 0x9) / 10` = **8%** -- and the chart draws
  /// a line climbing from 8 to 80 for a student who has been flat for five
  /// months, with a velocity to match. It invents progress, for every student
  /// who adds lessons over time, which is all of them.
  ///
  /// So chapters and lessons are filtered by `createdAt` on the same boundary
  /// as the exams. The reading is then checkable against what the student
  /// actually saw, which is the only thing that makes it worth showing.
  static double subjectMasteryAsOf(
    StudySnapshot snapshot,
    int subjectId,
    DateTime asOf,
  ) {
    final chapters = <Chapter>[
      for (final chapter in snapshot.chaptersIn(subjectId))
        if (!chapter.createdAt.isAfter(asOf)) chapter,
    ];
    if (chapters.isEmpty) return 0;

    var total = 0.0;
    for (final chapter in chapters) {
      final lessons = <Lesson>[
        for (final lesson in snapshot.lessonsIn(chapter.id))
          if (!lesson.createdAt.isAfter(asOf)) lesson,
      ];
      if (lessons.isEmpty) {
        continue; // contributes 0
      }
      var chapterTotal = 0.0;
      for (final lesson in lessons) {
        chapterTotal += _masteryAt(snapshot.examsFor(lesson.id), asOf);
      }
      total += chapterTotal / lessons.length;
    }
    return total / chapters.length;
  }

  /// The 70/30 mastery figure over only the exams recorded by [asOf].
  ///
  /// Reads straight off the list instead of copying and re-sorting it:
  /// `examsFor` arrives newest-first **sorted by construction** -- once, in the
  /// snapshot's constructor -- and filtering by date preserves that order.
  /// That is the same invariant `MasteryCalculator.lessonMasteries` relies on,
  /// and this is its innermost loop: one call per lesson per trajectory point,
  /// where the old defensive copy-and-sort at every visit dominated the whole
  /// computation.
  ///
  /// The arithmetic is identical to `MasteryCalculator.lessonMastery`: newest
  /// exam x 0.7 + mean of the rest x 0.3; none -> 0; a single paper -> its
  /// percentage. Ties on date keep the snapshot's descending-id break, so "the
  /// last exam" names the same paper both ways.
  static double _masteryAt(List<ExamEntry> exams, DateTime asOf) {
    ExamEntry? latest;
    var previousTotal = 0.0;
    var previousCount = 0;
    for (final exam in exams) {
      if (exam.createdAt.isAfter(asOf)) continue;
      if (latest == null) {
        latest = exam;
      } else {
        previousTotal += exam.percentage;
        previousCount++;
      }
    }
    if (latest == null) return 0;
    if (previousCount == 0) return latest.percentage;
    return latest.percentage * 0.7 + (previousTotal / previousCount) * 0.3;
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
  /// Measured across the trailing [MasteryTrends.velocityWindowPoints]
  /// readings of [points], not the whole line: it is displayed as the speed
  /// *today*, and anchoring its far end at the first exam ever taken let one
  /// early panic paper speak for months of stillness. See
  /// [MasteryTrends.velocityOf].
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
  /// line. Thinned evenly, always keeping the first and last reading so the
  /// drawn line still spans the whole history; [velocityOf] measures only
  /// across its trailing [velocityWindowPoints] of these.
  static const int maxPoints = 12;

  /// How many trailing readings the velocity is measured across.
  ///
  /// Four exam days reach back roughly two review cycles for a student who
  /// sits papers every fortnight to month -- the stretch "how am I doing
  /// lately?" lives in -- while staying wide enough that no single odd paper
  /// can swing the rate on its own.
  static const int velocityWindowPoints = 4;

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

  /// Change per review cycle across the student's most recent readings --
  /// the trailing [velocityWindowPoints] points of [points], never the whole
  /// history.
  ///
  /// **Why a recent window:** this figure answers the question the student
  /// asks when they see it -- "am I improving *now*?" Measuring first-to-last
  /// across the entire series answers a different question ("how far have I
  /// come since the beginning?") and goes stale: one panicked first exam
  /// kept reporting "+12 per cycle" beneath a line flat for four months, and
  /// a strong start kept reporting decline through months of holding
  /// steady. The window ages those anchors out -- what happened before the
  /// last few readings is history, not speed.
  ///
  /// Endpoint-to-endpoint within that window rather than a fitted slope: the
  /// student can check this against the two ends of the segment it describes
  /// -- both of them drawn on the chart -- and a least-squares figure that
  /// disagrees with the picture would be a number they cannot verify.
  /// Ather's one rule is that its figures are checkable.
  ///
  /// Returns 0 for fewer than two points, and 0 when both readings land on the
  /// same day -- an interval of no time has no rate, and dividing by it would
  /// report an infinite one.
  static double velocityOf(List<TrajectoryPoint> points) {
    if (points.length < 2) return 0;

    // Only the trailing edge measures; the older points are context for the
    // eye, not input to the rate.
    final recent = points.length <= velocityWindowPoints
        ? points
        : points.sublist(points.length - velocityWindowPoints);

    final first = recent.first;
    final last = recent.last;
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
