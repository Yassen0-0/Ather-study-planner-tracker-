import 'package:flutter_test/flutter_test.dart';

import '../support/instants.dart';
import 'package:ather/domain/services/insights_generator.dart';

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
      // mastery before = 40; now = 90*0.7 + 40*0.3 = 75. Delta = 35.
      expect(insight.deltaPercentagePoints, closeTo(35, 1e-9));
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
}
