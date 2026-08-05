import 'package:flutter_test/flutter_test.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/mastery.dart';
import 'package:ather/domain/services/mastery_calculator.dart';

import 'fixtures.dart';

void main() {
  group('lessonMastery', () {
    test('no exams -> 0 (unproven, not "in progress")', () {
      expect(MasteryCalculator.lessonMastery(const <ExamEntry>[]), 0);
    });

    test('single exam -> that exam percentage verbatim', () {
      final exams = <ExamEntry>[exam(id: 1, percentage: 63.5, day: 1)];
      expect(MasteryCalculator.lessonMastery(exams), 63.5);
    });

    test('two exams -> last*0.7 + previous*0.3', () {
      final exams = <ExamEntry>[
        exam(id: 1, percentage: 50, day: 1),
        exam(id: 2, percentage: 90, day: 10),
      ];
      // 90*0.7 + 50*0.3 = 63 + 15 = 78
      expect(MasteryCalculator.lessonMastery(exams), closeTo(78, 1e-9));
    });

    test('many exams -> last*0.7 + mean(all others)*0.3', () {
      final exams = <ExamEntry>[
        exam(id: 1, percentage: 40, day: 1),
        exam(id: 2, percentage: 60, day: 5),
        exam(id: 3, percentage: 80, day: 9),
        exam(id: 4, percentage: 100, day: 20),
      ];
      // mean(40,60,80) = 60 -> 100*0.7 + 60*0.3 = 70 + 18 = 88
      expect(MasteryCalculator.lessonMastery(exams), closeTo(88, 1e-9));
    });

    test('input order does not matter', () {
      final ascending = <ExamEntry>[
        exam(id: 1, percentage: 40, day: 1),
        exam(id: 2, percentage: 100, day: 20),
      ];
      final descending = ascending.reversed.toList();

      expect(
        MasteryCalculator.lessonMastery(ascending),
        MasteryCalculator.lessonMastery(descending),
      );
    });

    test('identical timestamps break the tie deterministically by id', () {
      final sameInstant = DateTime(2026, 3, 3);
      final exams = <ExamEntry>[
        exam(id: 1, percentage: 20, at: sameInstant),
        exam(id: 2, percentage: 100, at: sameInstant),
      ];

      // Highest id wins as "last": 100*0.7 + 20*0.3 = 76. Must be stable across
      // repeated calls and input orderings, or mastery would flicker.
      expect(MasteryCalculator.lessonMastery(exams), closeTo(76, 1e-9));
      expect(
        MasteryCalculator.lessonMastery(exams.reversed.toList()),
        closeTo(76, 1e-9),
      );
    });

    test('a review exam is weighted exactly like any other exam', () {
      final normal = <ExamEntry>[
        exam(id: 1, percentage: 50, day: 1),
        exam(id: 2, percentage: 90, day: 10),
      ];
      final withReview = <ExamEntry>[
        exam(id: 1, percentage: 50, day: 1),
        exam(id: 2, percentage: 90, day: 10, isReview: true),
      ];

      expect(
        MasteryCalculator.lessonMastery(withReview),
        MasteryCalculator.lessonMastery(normal),
      );
    });
  });

  group('chapterMastery', () {
    test('empty chapter -> 0', () {
      expect(MasteryCalculator.chapterMastery(const <double>[]), 0);
    });

    test('plain mean of lesson masteries', () {
      expect(
        MasteryCalculator.chapterMastery(const <double>[60, 80, 100]),
        closeTo(80, 1e-9),
      );
    });

    test('unexamined lessons drag the average down instead of being excluded',
        () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(subjectId: 1, name: 'باب');
        final proven = await repo.createLesson(chapterId: chapter, name: 'مثبت');
        await repo.createLesson(chapterId: chapter, name: 'لسه');
        await repo.createLesson(chapterId: chapter, name: 'لسه ٢');
        await recordPercentage(repo, proven, 90, DateTime(2026, 1, 1));
      });

      final chapterId = snap.chapters.single.id;
      // One lesson at 90, two at 0 -> 30. Not 90.
      expect(
        MasteryCalculator.chapterMasteryOf(snap, chapterId),
        closeTo(30, 1e-9),
      );
    });
  });

  group('subject and overall mastery', () {
    test('subject mastery averages chapters, not lessons', () async {
      final snap = await buildSnapshot((repo) async {
        // Chapter A: 1 lesson at 100. Chapter B: 3 lessons at 0.
        final a = await repo.createChapter(subjectId: 1, name: 'أ');
        final lesson = await repo.createLesson(chapterId: a, name: 'د');
        await recordPercentage(repo, lesson, 100, DateTime(2026, 1, 1));

        final b = await repo.createChapter(subjectId: 1, name: 'ب');
        for (var i = 0; i < 3; i++) {
          await repo.createLesson(chapterId: b, name: 'د$i');
        }
      });

      // Chapter-weighted: (100 + 0) / 2 = 50.
      // Lesson-weighted would have been 100/4 = 25.
      expect(MasteryCalculator.subjectMasteryOf(snap, 1), closeTo(50, 1e-9));
    });

    test('overall counts all four subjects, including untouched ones', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(subjectId: 1, name: 'باب');
        final lesson = await repo.createLesson(chapterId: chapter, name: 'درس');
        await recordPercentage(repo, lesson, 100, DateTime(2026, 1, 1));
      });

      // Biology at 100, the other three untouched at 0 -> 25, never 100.
      expect(MasteryCalculator.overallMastery(snap), closeTo(25, 1e-9));
    });

    test('a completely empty database is 0, not NaN', () async {
      final snap = await buildSnapshot((_) async {});

      expect(MasteryCalculator.overallMastery(snap), 0);
      expect(MasteryCalculator.overallMastery(snap).isNaN, isFalse);
    });
  });

  group('MasteryBand boundaries', () {
    test('exact thresholds land in the higher band', () {
      expect(MasteryBand.fromPercentage(0), MasteryBand.weak);
      expect(MasteryBand.fromPercentage(49.999), MasteryBand.weak);
      expect(MasteryBand.fromPercentage(50), MasteryBand.medium);
      expect(MasteryBand.fromPercentage(69.999), MasteryBand.medium);
      expect(MasteryBand.fromPercentage(70), MasteryBand.good);
      expect(MasteryBand.fromPercentage(89.999), MasteryBand.good);
      expect(MasteryBand.fromPercentage(90), MasteryBand.excellent);
      expect(MasteryBand.fromPercentage(100), MasteryBand.excellent);
    });
  });

  group('homework is never part of mastery', () {
    test('perfect homework does not lift a weak exam score', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(subjectId: 1, name: 'باب');
        final lesson = await repo.createLesson(chapterId: chapter, name: 'درس');
        await recordPercentage(repo, lesson, 30, DateTime(2026, 1, 1));
        // Full marks on homework, repeatedly.
        for (var i = 1; i <= 5; i++) {
          await repo.recordHomework(
            lessonId: lesson,
            score: 100,
            maxScore: 100,
            at: DateTime(2026, 1, i),
          );
        }
      });

      final lessonId = snap.lessons.single.id;
      expect(
        MasteryCalculator.lessonMastery(snap.examsFor(lessonId)),
        closeTo(30, 1e-9),
        reason: 'homework must not influence mastery in any way',
      );
      expect(snap.homeworkFor(lessonId), hasLength(5));
    });

    test('readiness threshold sits at 60%', () {
      expect(MasteryCalculator.isReadyForExam(59.999), isFalse);
      expect(MasteryCalculator.isReadyForExam(60), isTrue);
      expect(kHomeworkReadinessThreshold, 60);
    });

    test('latestHomeworkPercentage picks the newest entry', () {
      final entries = <HomeworkEntry>[
        HomeworkEntry(
          id: 1,
          lessonId: 1,
          score: 30,
          maxScore: 100,
          createdAt: DateTime(2026, 1, 1),
        ),
        HomeworkEntry(
          id: 2,
          lessonId: 1,
          score: 90,
          maxScore: 100,
          createdAt: DateTime(2026, 2, 1),
        ),
      ];

      expect(MasteryCalculator.latestHomeworkPercentage(entries), 90);
      expect(
        MasteryCalculator.latestHomeworkPercentage(const <HomeworkEntry>[]),
        isNull,
      );
    });

    test('a zero max score renders as 0%, not NaN', () {
      final entry = HomeworkEntry(
        id: 1,
        lessonId: 1,
        score: 5,
        maxScore: 0,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(entry.percentage, 0);
      expect(entry.percentage.isNaN, isFalse);
    });
  });

  group('isDeclining', () {
    test('needs at least two exams', () {
      expect(MasteryCalculator.isDeclining(const <ExamEntry>[]), isFalse);
      expect(
        MasteryCalculator.isDeclining(<ExamEntry>[exam(id: 1, percentage: 10, day: 1)]),
        isFalse,
      );
    });

    test('true only when the newest exam is worse than the one before', () {
      final falling = <ExamEntry>[
        exam(id: 1, percentage: 80, day: 1),
        exam(id: 2, percentage: 60, day: 5),
      ];
      final rising = <ExamEntry>[
        exam(id: 1, percentage: 60, day: 1),
        exam(id: 2, percentage: 80, day: 5),
      ];
      final flat = <ExamEntry>[
        exam(id: 1, percentage: 70, day: 1),
        exam(id: 2, percentage: 70, day: 5),
      ];

      expect(MasteryCalculator.isDeclining(falling), isTrue);
      expect(MasteryCalculator.isDeclining(rising), isFalse);
      expect(MasteryCalculator.isDeclining(flat), isFalse);
    });

    test('compares the two newest only, ignoring older history', () {
      final exams = <ExamEntry>[
        exam(id: 1, percentage: 10, day: 1),
        exam(id: 2, percentage: 95, day: 5),
        exam(id: 3, percentage: 90, day: 9),
      ];
      expect(MasteryCalculator.isDeclining(exams), isTrue);
    });
  });

  group('averageExamScore', () {
    test('is an unweighted mean, unlike mastery', () async {
      final snap = await buildSnapshot((repo) async {
        final chapter = await repo.createChapter(subjectId: 1, name: 'باب');
        final lesson = await repo.createLesson(chapterId: chapter, name: 'درس');
        await recordPercentage(repo, lesson, 40, DateTime(2026, 1, 1));
        await recordPercentage(repo, lesson, 100, DateTime(2026, 2, 1));
      });

      final lessonId = snap.lessons.single.id;
      // Plain mean 70, whereas mastery would be 100*0.7 + 40*0.3 = 82.
      expect(
        MasteryCalculator.averageExamScore(snap, <int>[lessonId]),
        closeTo(70, 1e-9),
      );
      expect(
        MasteryCalculator.lessonMastery(snap.examsFor(lessonId)),
        closeTo(82, 1e-9),
      );
    });

    test('no exams -> 0', () async {
      final snap = await buildSnapshot((_) async {});
      expect(MasteryCalculator.averageExamScore(snap, const <int>[]), 0);
    });
  });

  group('everyLessonExamined', () {
    test('false for an empty chapter', () async {
      final snap = await buildSnapshot((repo) async {
        await repo.createChapter(subjectId: 1, name: 'فاضي');
      });
      expect(
        MasteryCalculator.everyLessonExamined(snap, snap.chapters.single.id),
        isFalse,
      );
    });

    test('false while any lesson is unexamined, true once all are', () async {
      late int chapterId;
      var snap = await buildSnapshot((repo) async {
        chapterId = await repo.createChapter(subjectId: 1, name: 'باب');
        final a = await repo.createLesson(chapterId: chapterId, name: 'أ');
        await repo.createLesson(chapterId: chapterId, name: 'ب');
        await recordPercentage(repo, a, 80, DateTime(2026, 1, 1));
      });
      expect(MasteryCalculator.everyLessonExamined(snap, chapterId), isFalse);

      snap = await buildSnapshot((repo) async {
        final c = await repo.createChapter(subjectId: 1, name: 'باب');
        final a = await repo.createLesson(chapterId: c, name: 'أ');
        final b = await repo.createLesson(chapterId: c, name: 'ب');
        await recordPercentage(repo, a, 80, DateTime(2026, 1, 1));
        await recordPercentage(repo, b, 75, DateTime(2026, 1, 1));
      });
      expect(
        MasteryCalculator.everyLessonExamined(snap, snap.chapters.single.id),
        isTrue,
      );
    });
  });
}
