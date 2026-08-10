import 'package:flutter_test/flutter_test.dart';

import '../support/instants.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/mastery.dart';
import 'package:ather/domain/services/review_cycle_service.dart';

import 'fixtures.dart';

/// Fixed reference point. Every date below is relative to this.
final DateTime kAnchor = DateTime(2026, 6, 1);

Lesson lessonWith({DateTime? lastReviewedAt, DateTime? lastNotifiedAt}) {
  return Lesson(
    id: 1,
    chapterId: 1,
    name: 'درس',
    createdAt: DateTime(2026, 1, 1),
    lastReviewedAt: lastReviewedAt,
    lastNotifiedAt: lastNotifiedAt,
  );
}

void main() {
  group('needsReview boundary', () {
    test('29 days is not yet due', () {
      final lesson = lessonWith(lastReviewedAt: kAnchor);
      expect(
        ReviewCycleService.needsReview(
          lesson,
          kAnchor.add(const Duration(days: 29)),
        ),
        isFalse,
      );
    });

    test('exactly 30 days is due', () {
      final lesson = lessonWith(lastReviewedAt: kAnchor);
      expect(
        ReviewCycleService.needsReview(
          lesson,
          kAnchor.add(const Duration(days: 30)),
        ),
        isTrue,
      );
    });

    test('31 days is due', () {
      final lesson = lessonWith(lastReviewedAt: kAnchor);
      expect(
        ReviewCycleService.needsReview(
          lesson,
          kAnchor.add(const Duration(days: 31)),
        ),
        isTrue,
      );
    });

    test('29 days and 23 hours is still not due -- whole days only', () {
      final lesson = lessonWith(lastReviewedAt: kAnchor);
      final now = kAnchor.add(const Duration(days: 29, hours: 23));
      expect(ReviewCycleService.needsReview(lesson, now), isFalse);
    });

    test('a never-examined lesson is never overdue', () {
      final lesson = lessonWith();
      expect(
        ReviewCycleService.needsReview(
          lesson,
          kAnchor.add(const Duration(days: 3650)),
        ),
        isFalse,
        reason: 'red means decayed, not untouched',
      );
      expect(ReviewCycleService.daysSinceReview(lesson, kAnchor), isNull);
      expect(ReviewCycleService.daysUntilDue(lesson, kAnchor), isNull);
      expect(ReviewCycleService.dueAt(lesson), isNull);
    });

    test('the cycle length is 30 days', () {
      expect(kReviewCycleDays, 30);
    });
  });

  group('countdown helpers', () {
    test('daysUntilDue counts down and stops at due', () {
      final lesson = lessonWith(lastReviewedAt: kAnchor);
      expect(ReviewCycleService.daysUntilDue(lesson, kAnchor), 30);
      expect(
        ReviewCycleService.daysUntilDue(
          lesson,
          kAnchor.add(const Duration(days: 25)),
        ),
        5,
      );
      expect(
        ReviewCycleService.daysUntilDue(
          lesson,
          kAnchor.add(const Duration(days: 30)),
        ),
        isNull,
        reason: 'already due has no countdown',
      );
    });

    test('daysOverdue is 0 before due, then counts up', () {
      final lesson = lessonWith(lastReviewedAt: kAnchor);
      expect(ReviewCycleService.daysOverdue(lesson, kAnchor), 0);
      expect(
        ReviewCycleService.daysOverdue(
          lesson,
          kAnchor.add(const Duration(days: 30)),
        ),
        0,
      );
      expect(
        ReviewCycleService.daysOverdue(
          lesson,
          kAnchor.add(const Duration(days: 45)),
        ),
        15,
      );
    });

    test('dueAt is exactly 30 days after the last proof', () {
      final lesson = lessonWith(lastReviewedAt: kAnchor);
      expect(
        ReviewCycleService.dueAt(lesson),
        kAnchor.add(const Duration(days: 30)),
      );
    });
  });

  group('chapter red propagation', () {
    test('one overdue lesson among many turns the whole chapter red', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        // Four lessons proven today, one proven long ago.
        for (var i = 0; i < 4; i++) {
          final id = await repo.createLesson(
            chapterId: chapter,
            name: 'د$i',
            at: kSeedInstant,
          );
          await recordPercentage(repo, id, 85, kAnchor);
        }
        final stale = await repo.createLesson(
          chapterId: chapter,
          name: 'قديم',
          at: kSeedInstant,
        );
        await recordPercentage(
          repo,
          stale,
          85,
          kAnchor.subtract(const Duration(days: 40)),
        );
      });

      final chapterId = snap.chapters.single.id;
      expect(
        ReviewCycleService.chapterNeedsReview(snap, chapterId, kAnchor),
        isTrue,
        reason: 'no averaging, no threshold -- one lesson is enough',
      );
      expect(ReviewCycleService.subjectNeedsReview(snap, 1, kAnchor), isTrue);
    });

    test('a chapter with all lessons current is not red', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        for (var i = 0; i < 3; i++) {
          final id = await repo.createLesson(
            chapterId: chapter,
            name: 'د$i',
            at: kSeedInstant,
          );
          await recordPercentage(repo, id, 85, kAnchor);
        }
      });

      expect(
        ReviewCycleService.chapterNeedsReview(
          snap,
          snap.chapters.single.id,
          kAnchor,
        ),
        isFalse,
      );
    });

    test('a chapter of never-examined lessons is not red', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        await repo.createLesson(
          chapterId: chapter,
          name: 'د',
          at: kSeedInstant,
        );
      });

      expect(
        ReviewCycleService.chapterNeedsReview(
          snap,
          snap.chapters.single.id,
          kAnchor.add(const Duration(days: 999)),
        ),
        isFalse,
      );
    });
  });

  group('canMasterChapter', () {
    test('rejects an empty chapter', () async {
      final snap = await buildSnapshot((repo) async {
        await repo.createChapter(subjectId: 1, name: 'فاضي', at: kSeedInstant);
      });
      expect(
        ReviewCycleService.canMasterChapter(snap, snap.chapters.single.id),
        isFalse,
      );
    });

    test(
      'rejects when any lesson has no exam, even with high mastery elsewhere',
      () async {
        final snap = await buildSnapshot((repo) async {
          final chapter = await repo.createChapter(
            subjectId: 1,
            name: 'باب',
            at: kSeedInstant,
          );
          final a = await repo.createLesson(
            chapterId: chapter,
            name: 'أ',
            at: kSeedInstant,
          );
          await repo.createLesson(
            chapterId: chapter,
            name: 'ب',
            at: kSeedInstant,
          );
          await recordPercentage(repo, a, 100, kAnchor);
        });

        expect(
          ReviewCycleService.canMasterChapter(snap, snap.chapters.single.id),
          isFalse,
        );
      },
    );

    test('rejects at 69% and accepts at exactly 70%', () async {
      final below = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final a = await repo.createLesson(
          chapterId: chapter,
          name: 'أ',
          at: kSeedInstant,
        );
        await recordPercentage(repo, a, 69, kAnchor);
      });
      expect(
        ReviewCycleService.canMasterChapter(below, below.chapters.single.id),
        isFalse,
      );

      final atThreshold = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final a = await repo.createLesson(
          chapterId: chapter,
          name: 'أ',
          at: kSeedInstant,
        );
        await recordPercentage(repo, a, 70, kAnchor);
      });
      expect(
        ReviewCycleService.canMasterChapter(
          atThreshold,
          atThreshold.chapters.single.id,
        ),
        isTrue,
      );
      expect(kChapterMasteryThreshold, 70);
    });
  });

  group('chapterBlockers', () {
    test('lists unexamined lessons first, then weakest to strongest', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final strong = await repo.createLesson(
          chapterId: chapter,
          name: 'قوي',
          at: kSeedInstant,
        );
        final weak = await repo.createLesson(
          chapterId: chapter,
          name: 'ضعيف',
          at: kSeedInstant,
        );
        final middling = await repo.createLesson(
          chapterId: chapter,
          name: 'متوسط',
          at: kSeedInstant,
        );
        await repo.createLesson(
          chapterId: chapter,
          name: 'بدون امتحان',
          at: kSeedInstant,
        );

        await recordPercentage(repo, strong, 95, kAnchor);
        await recordPercentage(repo, weak, 20, kAnchor);
        await recordPercentage(repo, middling, 55, kAnchor);
      });

      final blockers = ReviewCycleService.chapterBlockers(
        snap,
        snap.chapters.single.id,
      );

      expect(blockers.map((b) => b.lesson.name), <String>[
        'بدون امتحان', // no evidence at all -- hardest blocker
        'ضعيف', // 20
        'متوسط', // 55
      ]);
      expect(
        blockers.map((b) => b.lesson.name),
        isNot(contains('قوي')),
        reason: 'a lesson at 95% is not blocking anything',
      );
    });
  });

  group('review queue', () {
    test(
      'orders overdue first (most overdue on top), then low, then declining',
      () async {
        final snap = await buildSnapshot((repo) async {
          final chapter = await repo.createChapter(
            subjectId: 1,
            name: 'باب',
            at: kSeedInstant,
          );

          // Overdue by 20 days.
          final veryOverdue = await repo.createLesson(
            chapterId: chapter,
            name: 'متأخر جدًا',
            at: kSeedInstant,
          );
          await recordPercentage(
            repo,
            veryOverdue,
            80,
            kAnchor.subtract(const Duration(days: 50)),
          );

          // Overdue by 5 days.
          final slightlyOverdue = await repo.createLesson(
            chapterId: chapter,
            name: 'متأخر شوية',
            at: kSeedInstant,
          );
          await recordPercentage(
            repo,
            slightlyOverdue,
            80,
            kAnchor.subtract(const Duration(days: 35)),
          );

          // Current but weak.
          final weak = await repo.createLesson(
            chapterId: chapter,
            name: 'ضعيف',
            at: kSeedInstant,
          );
          await recordPercentage(repo, weak, 20, kAnchor);

          // Current, decent, but trending down (90 then 75 -> mastery 79.5).
          final declining = await repo.createLesson(
            chapterId: chapter,
            name: 'بينزل',
            at: kSeedInstant,
          );
          await recordPercentage(
            repo,
            declining,
            90,
            kAnchor.subtract(const Duration(days: 3)),
          );
          await recordPercentage(repo, declining, 75, kAnchor);

          // Current and healthy -- must not appear.
          final healthy = await repo.createLesson(
            chapterId: chapter,
            name: 'كويس',
            at: kSeedInstant,
          );
          await recordPercentage(repo, healthy, 88, kAnchor);
        });

        final queue = ReviewCycleService.buildReviewQueue(snap, kAnchor);

        expect(queue.map((i) => i.lesson.name), <String>[
          'متأخر جدًا',
          'متأخر شوية',
          'ضعيف',
          'بينزل',
        ]);
        expect(queue.first.reason, ReviewReason.overdue);
        expect(queue.first.daysOverdue, 20);
        expect(queue[2].reason, ReviewReason.lowMastery);
        expect(queue[3].reason, ReviewReason.declining);
      },
    );

    test(
      'a brand-new unexamined lesson is not flagged as low mastery',
      () async {
        final snap = await buildSnapshot((repo) async {
          final chapter = await repo.createChapter(
            subjectId: 1,
            name: 'باب',
            at: kSeedInstant,
          );
          await repo.createLesson(
            chapterId: chapter,
            name: 'جديد',
            at: kSeedInstant,
          );
        });

        expect(
          ReviewCycleService.buildReviewQueue(snap, kAnchor),
          isEmpty,
          reason: 'mastery 0 from "never studied" is not a warning sign yet',
        );
      },
    );

    test('each lesson appears once, under its most urgent reason', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        // Overdue AND weak AND declining, all at once.
        final lesson = await repo.createLesson(
          chapterId: chapter,
          name: 'كله',
          at: kSeedInstant,
        );
        await recordPercentage(
          repo,
          lesson,
          60,
          kAnchor.subtract(const Duration(days: 90)),
        );
        await recordPercentage(
          repo,
          lesson,
          10,
          kAnchor.subtract(const Duration(days: 60)),
        );
      });

      final queue = ReviewCycleService.buildReviewQueue(snap, kAnchor);
      expect(queue, hasLength(1));
      expect(queue.single.reason, ReviewReason.overdue);
    });
  });

  group('upcomingReviewCount', () {
    test(
      'counts lessons falling due within the window, excluding overdue ones',
      () async {
        final snap = await buildSnapshot((repo) async {
          final chapter = await repo.createChapter(
            subjectId: 1,
            name: 'باب',
            at: kSeedInstant,
          );

          // Due in 3 days.
          final soon = await repo.createLesson(
            chapterId: chapter,
            name: 'قريب',
            at: kSeedInstant,
          );
          await recordPercentage(
            repo,
            soon,
            80,
            kAnchor.subtract(const Duration(days: 27)),
          );

          // Due in 20 days -- outside a 7-day window.
          final later = await repo.createLesson(
            chapterId: chapter,
            name: 'بعدين',
            at: kSeedInstant,
          );
          await recordPercentage(
            repo,
            later,
            80,
            kAnchor.subtract(const Duration(days: 10)),
          );

          // Already overdue -- counted elsewhere, more urgently.
          final overdue = await repo.createLesson(
            chapterId: chapter,
            name: 'متأخر',
            at: kSeedInstant,
          );
          await recordPercentage(
            repo,
            overdue,
            80,
            kAnchor.subtract(const Duration(days: 40)),
          );
        });

        expect(ReviewCycleService.upcomingReviewCount(snap, kAnchor), 1);
        expect(
          ReviewCycleService.upcomingReviewCount(snap, kAnchor, withinDays: 25),
          2,
        );
      },
    );
  });

  // The 'notification bookkeeping' group lived here. It exercised
  // `lessonsAwaitingNotification`, which was removed as dead code -- see the
  // note in review_cycle_service.dart. Four passing tests around a function
  // nothing called is the reason it looked alive for so long.

  group('MutableClock', () {
    test(
      'pins and advances time so the 30-day cycle is testable instantly',
      () {
        final clock = MutableClock(kAnchor);
        final lesson = lessonWith(lastReviewedAt: kAnchor);

        expect(ReviewCycleService.needsReview(lesson, clock.now()), isFalse);

        clock.advanceDays(29);
        expect(ReviewCycleService.needsReview(lesson, clock.now()), isFalse);

        clock.advanceDays(1);
        expect(ReviewCycleService.needsReview(lesson, clock.now()), isTrue);

        clock.setNow(kAnchor);
        expect(ReviewCycleService.needsReview(lesson, clock.now()), isFalse);
      },
    );
  });
}

// `_snapshotOf` lived here, building a lessons-only snapshot for the
// notification-bookkeeping tests. It went with them.
