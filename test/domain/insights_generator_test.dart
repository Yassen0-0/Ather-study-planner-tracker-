import 'package:flutter_test/flutter_test.dart';

import '../support/instants.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/services/insights_generator.dart';
import 'package:ather/domain/services/mastery_calculator.dart';

import 'fixtures.dart';

final DateTime kNow = DateTime(2026, 6, 1);

void main() {
  group('no fabricated insights', () {
    test('an empty database produces none', () async {
      final snap = await buildSnapshot((_) async {});
      expect(InsightsGenerator.generate(snap, kNow), isEmpty);
    });

    test('a chapter with no exams is never called weak', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'فاضي',
          at: kSeedInstant,
        );
        await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
      });

      expect(
        InsightsGenerator.generate(
          snap,
          kNow,
        ).whereType<ChapterNeedsAttentionInsight>(),
        isEmpty,
        reason:
            '"your untouched chapter is weak" is a tautology, not an insight',
      );
    });

    test('a first-ever exam is not reported as improvement', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        // Only exam, taken inside the window -- nothing to improve *from*.
        await recordPercentage(
          repo,
          lesson,
          95,
          kNow.subtract(const Duration(days: 2)),
        );
      });

      expect(
        InsightsGenerator.generate(
          snap,
          kNow,
        ).whereType<SubjectImprovedInsight>(),
        isEmpty,
      );
    });
  });

  group('improvement', () {
    test('fires on a real rise over the trailing window', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        // Before the window: 40. Inside it: 90.
        await recordPercentage(
          repo,
          lesson,
          40,
          kNow.subtract(const Duration(days: 60)),
        );
        await recordPercentage(
          repo,
          lesson,
          90,
          kNow.subtract(const Duration(days: 5)),
        );
      });

      final insight = InsightsGenerator.generate(
        snap,
        kNow,
      ).whereType<SubjectImprovedInsight>().single;

      expect(insight.subjectId, 1);
      // Baseline: the plain mean of the pre-window papers = 40. The papers
      // inside the window average 90, so the delta reads 50.
      expect(insight.deltaPercentagePoints, closeTo(50, 1e-9));
    });

    test('ignores a rise too small to be meaningful', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        await recordPercentage(
          repo,
          lesson,
          70,
          kNow.subtract(const Duration(days: 60)),
        );
        await recordPercentage(
          repo,
          lesson,
          72,
          kNow.subtract(const Duration(days: 5)),
        );
      });

      expect(
        InsightsGenerator.generate(
          snap,
          kNow,
        ).whereType<SubjectImprovedInsight>(),
        isEmpty,
      );
    });

    test('does not fire on a decline', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        await recordPercentage(
          repo,
          lesson,
          90,
          kNow.subtract(const Duration(days: 60)),
        );
        await recordPercentage(
          repo,
          lesson,
          30,
          kNow.subtract(const Duration(days: 5)),
        );
      });

      expect(
        InsightsGenerator.generate(
          snap,
          kNow,
        ).whereType<SubjectImprovedInsight>(),
        isEmpty,
      );
    });

    test('a first-month subject rising 0 -> 90 gets the insight', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        // The whole story lives inside the window -- opened at zero and now
        // at 90. Exactly the shape the old before<=0 gate refused to tell.
        await recordPercentage(
          repo,
          lesson,
          0,
          kNow.subtract(const Duration(days: 20)),
        );
        await recordPercentage(
          repo,
          lesson,
          90,
          kNow.subtract(const Duration(days: 5)),
        );
      });

      final insight = InsightsGenerator.generate(
        snap,
        kNow,
      ).whereType<SubjectImprovedInsight>().single;

      expect(insight.subjectId, 1);
      // Baseline = the first paper ever (0); the papers after it average 90.
      expect(insight.deltaPercentagePoints, closeTo(90, 1e-9));
    });

    test('a first-month jump smaller than the minimum is not flattered',
        () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        // A thin baseline makes even a small rise look like a story; the
        // minimum-improvement guard has to hold here too.
        await recordPercentage(
          repo,
          lesson,
          2,
          kNow.subtract(const Duration(days: 20)),
        );
        await recordPercentage(
          repo,
          lesson,
          4,
          kNow.subtract(const Duration(days: 5)),
        );
      });

      expect(
        InsightsGenerator.generate(
          snap,
          kNow,
        ).whereType<SubjectImprovedInsight>(),
        isEmpty,
        reason: '2% -> 4% in a first month is noise, not progress',
      );
    });
  });

  group('weakest chapter', () {
    test('names the worst chapter below 50%', () async {
      final snap = await buildSnapshot((repo) async {
        final bad = await repo.createChapter(
          subjectId: 1,
          name: 'الأسوأ',
          at: kSeedInstant,
        );
        final worse = await repo.createChapter(
          subjectId: 1,
          name: 'أسوأ كمان',
          at: kSeedInstant,
        );
        final fine = await repo.createChapter(
          subjectId: 1,
          name: 'كويس',
          at: kSeedInstant,
        );

        final a = await repo.createLesson(
          chapterId: bad,
          name: 'أ',
          at: kSeedInstant,
        );
        final b = await repo.createLesson(
          chapterId: worse,
          name: 'ب',
          at: kSeedInstant,
        );
        final c = await repo.createLesson(
          chapterId: fine,
          name: 'ج',
          at: kSeedInstant,
        );

        await recordPercentage(repo, a, 45, kNow);
        await recordPercentage(repo, b, 15, kNow);
        await recordPercentage(repo, c, 85, kNow);
      });

      final insight = InsightsGenerator.generate(
        snap,
        kNow,
      ).whereType<ChapterNeedsAttentionInsight>().single;

      expect(insight.chapterName, 'أسوأ كمان');
      expect(insight.mastery, closeTo(15, 1e-9));
      expect(insight.subjectId, 1);
    });

    test('stays quiet when every chapter is healthy', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        await recordPercentage(repo, lesson, 88, kNow);
      });

      expect(
        InsightsGenerator.generate(
          snap,
          kNow,
        ).whereType<ChapterNeedsAttentionInsight>(),
        isEmpty,
      );
    });
  });

  group('stale lesson', () {
    test('names the longest-unreviewed lesson past 45 days', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final old = await repo.createLesson(
          chapterId: chapter,
          name: 'قديم جدًا',
          at: kSeedInstant,
        );
        final newer = await repo.createLesson(
          chapterId: chapter,
          name: 'أحدث',
          at: kSeedInstant,
        );

        await recordPercentage(repo, old, 80, daysBefore(kNow, 100));
        await recordPercentage(repo, newer, 80, daysBefore(kNow, 50));
      });

      final insight = InsightsGenerator.generate(
        snap,
        kNow,
      ).whereType<LessonNotReviewedInsight>().single;

      expect(insight.lessonName, 'قديم جدًا');
      expect(insight.days, 100);
    });

    test('ignores lessons inside the staleness threshold', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        await recordPercentage(
          repo,
          lesson,
          80,
          kNow.subtract(const Duration(days: 40)),
        );
      });

      expect(
        InsightsGenerator.generate(
          snap,
          kNow,
        ).whereType<LessonNotReviewedInsight>(),
        isEmpty,
      );
    });

    test('never names an unexamined lesson', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        await repo.createLesson(
          chapterId: chapter,
          name: 'مفيش امتحان',
          at: kSeedInstant,
        );
      });

      expect(
        InsightsGenerator.generate(
          snap,
          kNow,
        ).whereType<LessonNotReviewedInsight>(),
        isEmpty,
      );
    });
  });

  group('strongest subject', () {
    test('crowns a subject only once it is genuinely strong', () async {
      final weak = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        await recordPercentage(repo, lesson, 40, kNow);
      });
      expect(
        InsightsGenerator.generate(
          weak,
          kNow,
        ).whereType<StrongestSubjectInsight>(),
        isEmpty,
        reason: 'calling 40% your strongest subject is misleading',
      );

      final strong = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 3,
          name: 'باب',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس',
          at: kSeedInstant,
        );
        await recordPercentage(repo, lesson, 92, kNow);
      });
      final insight = InsightsGenerator.generate(
        strong,
        kNow,
      ).whereType<StrongestSubjectInsight>().single;
      expect(insight.subjectId, 3);
      expect(insight.mastery, closeTo(92, 1e-9));
    });
  });

  test('caps the number of insights shown', () async {
    final snap = await buildSnapshot((repo) async {
      for (var subject = 1; subject <= 4; subject++) {
        final chapter = await repo.createChapter(
          subjectId: subject,
          name: 'باب$subject',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'درس$subject',
          at: kSeedInstant,
        );
        await recordPercentage(
          repo,
          lesson,
          20,
          kNow.subtract(const Duration(days: 200)),
        );
        await recordPercentage(
          repo,
          lesson,
          95,
          kNow.subtract(const Duration(days: 100)),
        );
      }
    });

    expect(InsightsGenerator.generate(snap, kNow).length, lessThanOrEqualTo(4));
  });

  group('exam score trajectory', () {
    test('a subject with no exams has no points and no direction', () async {
      final snap = await subjectExaminedOn(const []);
      final trajectory = MasteryTrends.forSubject(snap, 1);

      expect(trajectory.points, isEmpty);
      expect(trajectory.hasTrend, isFalse);
      expect(trajectory.velocityPerCycle, 0);
    });

    test('one exam is a dot, not a line', () async {
      final snap = await subjectExaminedOn(const [
        (daysBeforeNow: 10, percentage: 70),
      ]);
      final trajectory = MasteryTrends.forSubject(snap, 1);

      expect(trajectory.points, hasLength(1));
      expect(
        trajectory.hasTrend,
        isFalse,
        reason: 'a single reading has no direction to draw',
      );
      expect(trajectory.velocityPerCycle, 0);
    });

    test('two exams on the same day are one reading, not two', () async {
      final snap = await subjectExaminedOn(const [
        (daysBeforeNow: 10, percentage: 40),
        (daysBeforeNow: 10, percentage: 90),
      ]);

      expect(MasteryTrends.forSubject(snap, 1).points, hasLength(1));
    });

    test('the points are the scores the student actually recorded', () async {
      // 50 on day -60, then 90 on day -30.
      final snap = await subjectExaminedOn(const [
        (daysBeforeNow: 60, percentage: 50),
        (daysBeforeNow: 30, percentage: 90),
      ]);
      final trajectory = MasteryTrends.forSubject(snap, 1);

      expect(trajectory.points, hasLength(2));
      expect(trajectory.points.first.at, daysBefore(kNow, 60));
      expect(trajectory.points.last.at, daysBefore(kNow, 30));

      // One exam so far: mastery is that exam.
      expect(trajectory.points.first.mastery, closeTo(50, 0.001));
      // Two exams: 90 x 0.7 + 50 x 0.3.
      expect(trajectory.points.last.mastery, closeTo(78, 0.001));
    });

    test('the last point equals the subject mastery shown everywhere '
        'else', () async {
      final snap = await subjectExaminedOn(const [
        (daysBeforeNow: 60, percentage: 50),
        (daysBeforeNow: 30, percentage: 90),
        (daysBeforeNow: 5, percentage: 72),
      ]);
      final trajectory = MasteryTrends.forSubject(snap, 1);

      expect(
        trajectory.points.last.mastery,
        closeTo(MasteryCalculator.subjectMasteryOf(snap, 1), 0.001),
        reason: 'the end of the line must agree with the subject bar above it',
      );
    });

    test('points come back oldest first', () async {
      final snap = await subjectExaminedOn(const [
        (daysBeforeNow: 10, percentage: 60),
        (daysBeforeNow: 90, percentage: 40),
        (daysBeforeNow: 50, percentage: 80),
      ]);
      final points = MasteryTrends.forSubject(snap, 1).points;

      expect(points, hasLength(3));
      for (var i = 1; i < points.length; i++) {
        expect(points[i].at.isAfter(points[i - 1].at), isTrue);
      }
    });

    test('a long history is thinned but keeps both ends', () async {
      // 40 exam days, well past the cap.
      final snap = await subjectExaminedOn(
        <({int daysBeforeNow, int percentage})>[
          for (var i = 0; i < 40; i++)
            (daysBeforeNow: 200 - i * 5, percentage: 50),
        ],
      );
      final points = MasteryTrends.forSubject(snap, 1).points;

      expect(points, hasLength(MasteryTrends.maxPoints));
      expect(points.first.at, daysBefore(kNow, 200));
      expect(points.last.at, daysBefore(kNow, 200 - 39 * 5));
    });

    test(
      'every active subject is returned, including the untouched ones',
      () async {
        final snap = await subjectExaminedOn(const [
          (daysBeforeNow: 10, percentage: 70),
        ]);
        final all = MasteryTrends.forAllSubjects(snap);

        expect(all, hasLength(snap.activeSubjects.length));
        expect(
          all.where((t) => t.points.isEmpty),
          isNotEmpty,
          reason:
              'a subject with no exams must still come back, so the screen '
              'can say "not enough data" for it rather than dropping it',
        );
      },
    );
  });

  group('mastery velocity', () {
    test(
      'rising mastery gives a positive figure, in points per cycle',
      () async {
        // 50 -> 78 across 30 days, so exactly one cycle of +28.
        final snap = await subjectExaminedOn(const [
          (daysBeforeNow: 60, percentage: 50),
          (daysBeforeNow: 30, percentage: 90),
        ]);

        expect(
          MasteryTrends.forSubject(snap, 1).velocityPerCycle,
          closeTo(28, 0.001),
        );
      },
    );

    test('a flat line has zero velocity, not a rounding artefact', () async {
      final snap = await subjectExaminedOn(const [
        (daysBeforeNow: 60, percentage: 60),
        (daysBeforeNow: 30, percentage: 60),
      ]);

      expect(MasteryTrends.forSubject(snap, 1).velocityPerCycle, 0);
    });

    test('falling mastery is reported as negative, not clamped', () async {
      // 90 -> 62 across 30 days.
      final snap = await subjectExaminedOn(const [
        (daysBeforeNow: 60, percentage: 90),
        (daysBeforeNow: 30, percentage: 50),
      ]);

      expect(
        MasteryTrends.forSubject(snap, 1).velocityPerCycle,
        closeTo(-28, 0.001),
        reason: 'going backwards is the case most worth telling them about',
      );
    });

    test('half a cycle of change is reported as the full-cycle rate', () async {
      // The same +28 across 15 days is twice the rate.
      final snap = await subjectExaminedOn(const [
        (daysBeforeNow: 45, percentage: 50),
        (daysBeforeNow: 30, percentage: 90),
      ]);

      expect(
        MasteryTrends.forSubject(snap, 1).velocityPerCycle,
        closeTo(56, 0.001),
      );
    });

    test('a single point has no rate', () {
      expect(
        MasteryTrends.velocityOf(<TrajectoryPoint>[
          TrajectoryPoint(at: kNow, mastery: 80),
        ]),
        0,
      );
    });

    test('two readings on the same instant do not divide by zero', () {
      expect(
        MasteryTrends.velocityOf(<TrajectoryPoint>[
          TrajectoryPoint(at: kNow, mastery: 20),
          TrajectoryPoint(at: kNow, mastery: 90),
        ]),
        0,
        reason: 'an interval of no time has no rate',
      );
    });

    test('an old spike does not govern a line flat for months', () async {
      // The anchor defect itself: one panicked first paper, months of
      // genuinely steady work after it. Endpoint-to-endpoint across the
      // whole history reported ~+7 per cycle for this data; the flat right
      // end of the line must read flat.
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final opener = await repo.createLesson(
          chapterId: chapter,
          name: 'الافتتاحية',
          at: kSeedInstant,
        );
        final steady = await repo.createLesson(
          chapterId: chapter,
          name: 'المستقرة',
          at: kSeedInstant,
        );

        await recordPercentage(repo, opener, 15, daysBefore(kNow, 200));
        // Five identical readings spread wider than the velocity window,
        // so every point it measures across is the same height.
        for (var i = 0; i < 5; i++) {
          await recordPercentage(
            repo,
            steady,
            80,
            daysBefore(kNow, 160 - i * 30),
          );
        }
      });

      final trajectory = MasteryTrends.forSubject(snap, 1);
      // The spike must be real for this test to mean anything: the drawn
      // line does climb from its opening to its plateau...
      expect(
        trajectory.points.first.mastery,
        lessThan(trajectory.points.last.mastery),
      );
      // ...and yet today's speed reads exactly zero.
      expect(trajectory.velocityPerCycle, closeTo(0, 1e-9));
    });

    test('velocity measures across the trailing window, not the series', () {
      DateTime d(int daysAgo) => daysBefore(kNow, daysAgo);
      final rate = MasteryTrends.velocityOf(<TrajectoryPoint>[
        TrajectoryPoint(at: d(400), mastery: 10), // ancient panic, long gone
        TrajectoryPoint(at: d(90), mastery: 60),
        TrajectoryPoint(at: d(60), mastery: 65),
        TrajectoryPoint(at: d(30), mastery: 70),
        TrajectoryPoint(at: kNow, mastery: 75),
      ]);

      // Last four readings only: +15 over 90 days -> +5 per cycle.
      // Anchoring at the first reading would have reported (75 - 10) / 400
      // x 30 ~= +4.9 -- close enough to pass a loose test, so the tolerance
      // below is tight on purpose.
      expect(rate, closeTo(5, 1e-9));
    });
  });
}

/// A subject with one chapter and one lesson, examined on the given days.
///
/// One lesson in one chapter so subject mastery *is* lesson mastery, and the
/// weighted formula (last x 0.7 + mean of the rest x 0.3) can be applied by
/// hand in the expectations below.
Future<StudySnapshot> subjectExaminedOn(
  List<({int daysBeforeNow, int percentage})> exams,
) {
  return buildSnapshot((repo) async {
    final chapter = await repo.createChapter(
      subjectId: 1,
      name: 'باب',
      at: kSeedInstant,
    );
    final lesson = await repo.createLesson(
      chapterId: chapter,
      name: 'درس',
      at: kSeedInstant,
    );
    for (final e in exams) {
      await recordPercentage(
        repo,
        lesson,
        e.percentage,
        daysBefore(kNow, e.daysBeforeNow),
      );
    }
  });
}
