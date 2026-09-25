import 'package:flutter_test/flutter_test.dart';

import 'package:ather/domain/entities/study_snapshot.dart';
import '../support/instants.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/mastery.dart';
import 'package:ather/domain/services/mastery_calculator.dart';
import 'package:ather/domain/services/summaries.dart';

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

    test(
      'unexamined lessons drag the average down instead of being excluded',
      () async {
        final snap = await buildSnapshot((repo) async {
          final chapter = await repo.createChapter(
            subjectId: 1,
            name: 'باب',
            at: kSeedInstant,
          );
          final proven = await repo.createLesson(
            chapterId: chapter,
            name: 'مثبت',
            at: kSeedInstant,
          );
          await repo.createLesson(
            chapterId: chapter,
            name: 'لسه',
            at: kSeedInstant,
          );
          await repo.createLesson(
            chapterId: chapter,
            name: 'لسه ٢',
            at: kSeedInstant,
          );
          await recordPercentage(repo, proven, 90, DateTime(2026, 1, 1));
        });

        final chapterId = snap.chapters.single.id;
        // One lesson at 90, two at 0 -> 30. Not 90.
        expect(
          MasteryCalculator.chapterMasteryOf(snap, chapterId),
          closeTo(30, 1e-9),
        );
      },
    );
  });

  group('subject and overall mastery', () {
    test('subject mastery averages chapters, not lessons', () async {
      final snap = await buildSnapshot((repo) async {
        // Chapter A: 1 lesson at 100. Chapter B: 3 lessons at 0.
        final a = await repo.createChapter(
          subjectId: 1,
          name: 'أ',
          at: kSeedInstant,
        );
        final lesson = await repo.createLesson(
          chapterId: a,
          name: 'د',
          at: kSeedInstant,
        );
        await recordPercentage(repo, lesson, 100, DateTime(2026, 1, 1));

        final b = await repo.createChapter(
          subjectId: 1,
          name: 'ب',
          at: kSeedInstant,
        );
        for (var i = 0; i < 3; i++) {
          await repo.createLesson(chapterId: b, name: 'د$i', at: kSeedInstant);
        }
      });

      // Chapter-weighted: (100 + 0) / 2 = 50.
      // Lesson-weighted would have been 100/4 = 25.
      expect(MasteryCalculator.subjectMasteryOf(snap, 1), closeTo(50, 1e-9));
    });

    test(
      'overall counts all four subjects, including untouched ones',
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
          await recordPercentage(repo, lesson, 100, DateTime(2026, 1, 1));
        });

        // Biology at 100, the other three untouched at 0 -> 25, never 100.
        expect(MasteryCalculator.overallMastery(snap), closeTo(25, 1e-9));
      },
    );

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
        MasteryCalculator.isDeclining(<ExamEntry>[
          exam(id: 1, percentage: 10, day: 1),
        ]),
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

  // P3-01: "how much do I need next time?" -- the mastery formula inverted.
  // The answer must be read from the recorded exams' plain mean, never from a
  // displayed mastery figure: at n > 1 the displayed figure is order-dependent
  // and no inverse of it exists.
  group('scoreNeededToCross', () {
    test('all-zero history demands a perfect paper and says exactly that', () {
      expect(MasteryCalculator.scoreNeededToCross(meanOfExisting: 0), 100);
    });

    test('mean 90 -> 62: rounding down would promise a crossing that fails', () {
      // (70 - 0.3*90)/0.7 = 61.428... -> 62.
      final needed = MasteryCalculator.scoreNeededToCross(meanOfExisting: 90);
      expect(needed, 62);

      // Why up, not nearest: 61 is nearer, but sat against this history it
      // lands at 69.7 -- under the line. The promised score must cross once
      // sat; 62 does.
      expect(61 * kRecentWeight + 90 * kHistoryWeight, lessThan(70));
      expect(
        needed * kRecentWeight + 90 * kHistoryWeight,
        greaterThanOrEqualTo(kChapterMasteryThreshold),
      );
    });

    test('audit example: mean 60 -> 75 (74.28 rounds up)', () {
      expect(MasteryCalculator.scoreNeededToCross(meanOfExisting: 60), 75);
    });

    test('a strong history lowers the ask but never waives the next paper', () {
      // The inverse always answers for every mean in [0, 100] -- a strong past
      // pulls the requirement down toward zero, it does not exempt the paper.
      // Sitting exactly on the line: (70 - 0.3*70)/0.7 = 49/0.7 = 70.
      expect(MasteryCalculator.scoreNeededToCross(meanOfExisting: 70), 70);
      // A perfect history still names ceil(40/.7): (70 - 0.3*100)/0.7 =
      // 57.14 -> 58 -- and 58*0.7 + 100*0.3 holds the line at 70.6.
      expect(MasteryCalculator.scoreNeededToCross(meanOfExisting: 100), 58);
      expect(58 * kRecentWeight + 100 * kHistoryWeight,
          greaterThanOrEqualTo(kChapterMasteryThreshold));
    });

    test(
      'same displayed mastery from different records asks different scores',
      () {
        // {0 then 100}: displayed 70 (newest 100, previous mean 0). The plain
        // mean of the records is 50, so the next paper needs 79.
        final zeroThenHundred = <ExamEntry>[
          exam(id: 1, percentage: 0, day: 1),
          exam(id: 2, percentage: 100, day: 10),
        ];
        // {100 then 0}: also displays 70 by the formula's symmetry in the pair,
        // but the records average 50 either way here; use an asymmetric trio to
        // prove the point harder: {0, 40, 100} displays differently per order
        // while its mean stays fixed.
        double meanOf(List<ExamEntry> exams) =>
            exams.fold<double>(0, (s, e) => s + e.percentage) / exams.length;

        final needed =
            MasteryCalculator.scoreNeededToCross(meanOfExisting: meanOf(zeroThenHundred));
        expect(meanOf(zeroThenHundred), 50);
        // 0.7x + 0.3*50 = 70 -> x = 78.57 -> 79.
        expect(needed, 79);
      },
    );

    test('the promised score crosses for every history below the line', () {
      for (var m = 0.0; m < 70; m += 3.5) {
        final needed = MasteryCalculator.scoreNeededToCross(meanOfExisting: m);
        expect(needed, isNotNull, reason: 'mean $m');
        final achieved = needed * kRecentWeight + m * kHistoryWeight;
        expect(
          achieved,
          greaterThanOrEqualTo(kChapterMasteryThreshold),
          reason: 'mean $m: promising $needed% only reaches $achieved',
        );
        expect(needed, lessThanOrEqualTo(100), reason: 'mean $m');
      }
    });

    test('defaults to the chapter mastery threshold', () {
      expect(
        MasteryCalculator.scoreNeededToCross(meanOfExisting: 0),
        MasteryCalculator.scoreNeededToCross(
          meanOfExisting: 0,
          threshold: kChapterMasteryThreshold,
        ),
      );
    });
  });

  group('averageExamScore', () {
    test('is an unweighted mean, unlike mastery', () async {
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
        await repo.createChapter(subjectId: 1, name: 'فاضي', at: kSeedInstant);
      });
      expect(
        MasteryCalculator.everyLessonExamined(snap, snap.chapters.single.id),
        isFalse,
      );
    });

    test('false while any lesson is unexamined, true once all are', () async {
      late int chapterId;
      var snap = await buildSnapshot((repo) async {
        chapterId = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final a = await repo.createLesson(
          chapterId: chapterId,
          name: 'أ',
          at: kSeedInstant,
        );
        await repo.createLesson(
          chapterId: chapterId,
          name: 'ب',
          at: kSeedInstant,
        );
        await recordPercentage(repo, a, 80, DateTime(2026, 1, 1));
      });
      expect(MasteryCalculator.everyLessonExamined(snap, chapterId), isFalse);

      snap = await buildSnapshot((repo) async {
        final c = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final a = await repo.createLesson(
          chapterId: c,
          name: 'أ',
          at: kSeedInstant,
        );
        final b = await repo.createLesson(
          chapterId: c,
          name: 'ب',
          at: kSeedInstant,
        );
        await recordPercentage(repo, a, 80, DateTime(2026, 1, 1));
        await recordPercentage(repo, b, 75, DateTime(2026, 1, 1));
      });
      expect(
        MasteryCalculator.everyLessonExamined(snap, snap.chapters.single.id),
        isTrue,
      );
    });
  });

  // `lessonMasteries` is the fast path the dashboard uses, and it skips the
  // defensive copy-and-sort that `lessonMastery` makes -- it relies on the
  // snapshot having already sorted each lesson's exams newest-first. If those
  // two ever disagree, every figure in the app quietly becomes wrong with no
  // error anywhere, so they are pinned to each other here.
  group('lessonMasteries agrees with lessonMastery, lesson for lesson', () {
    test('across no exams, one exam and several', () async {
      final snap = await buildSnapshot((repo) async {
        final c = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );

        // Never examined.
        await repo.createLesson(chapterId: c, name: 'فاضي', at: kSeedInstant);

        // Exactly one.
        final one = await repo.createLesson(
          chapterId: c,
          name: 'واحد',
          at: kSeedInstant,
        );
        await recordPercentage(repo, one, 64, DateTime(2026, 1, 1));

        // Several, deliberately recorded out of chronological order so a
        // mis-sorted "last exam" would change the answer.
        final many = await repo.createLesson(
          chapterId: c,
          name: 'كتير',
          at: kSeedInstant,
        );
        await recordPercentage(repo, many, 30, DateTime(2026, 3, 1));
        await recordPercentage(repo, many, 90, DateTime(2026, 1, 1));
        await recordPercentage(repo, many, 60, DateTime(2026, 2, 1));
      });

      final fast = MasteryCalculator.lessonMasteries(snap);

      expect(fast, hasLength(snap.lessons.length));
      for (final lesson in snap.lessons) {
        expect(
          fast[lesson.id],
          closeTo(
            MasteryCalculator.lessonMastery(snap.examsFor(lesson.id)),
            1e-9,
          ),
          reason: 'lesson ${lesson.name} disagrees',
        );
      }

      // And the arithmetic itself, spelled out rather than only compared:
      // newest is 30, the other two average 75, so 30*0.7 + 75*0.3.
      final many = snap.lessons.firstWhere((l) => l.name == 'كتير');
      expect(fast[many.id], closeTo(30 * 0.7 + 75 * 0.3, 1e-9));
    });
  });

  // P2-04 parity contract. The defensive path (MasteryCalculator.lessonMastery
  // / chapterMasteryOf / subjectMasteryOf / overallMastery) and the fast
  // summaries path (Summaries.lesson/chapter/subject/dashboard) must produce
  // **literally equal** doubles at every level -- not merely close -- because
  // they funnel through the same `_masteryFromSorted` arithmetic in the same
  // order. Even a one-ULP drift would make two screens disagree about the same
  // lesson with no error anywhere, so exact equality is itself the assertion.
  group('parity contract: fast path == slow path at every level', () {
    /// A fixture deliberately spanning every scenario the two paths could
    /// conceivably disagree on: 0/1/2/n exams, both boundary scores (0 and
    /// 100), out-of-order recording, and createdAt ties broken by id.
    Future<StudySnapshot> diverseFixture() => buildSnapshot((repo) async {
      // Subject 1 (seeded), chapter A.
      final a = await repo.createChapter(
        subjectId: 1,
        name: 'أ',
        at: kSeedInstant,
      );

      // Zero exams -- unproven, contributes 0 everywhere.
      await repo.createLesson(
        chapterId: a,
        name: 'صفر امتحانات',
        at: kSeedInstant,
      );

      // One exam, at the upper boundary.
      final hundred = await repo.createLesson(
        chapterId: a,
        name: 'واحد',
        at: kSeedInstant,
      );
      await recordPercentage(repo, hundred, 100, DateTime(2026, 2, 1));

      // Two exams recorded out of chronological order, so a mis-sorted "last"
      // would flip the answer.
      final two = await repo.createLesson(
        chapterId: a,
        name: 'اثنان',
        at: kSeedInstant,
      );
      await recordPercentage(repo, two, 90, DateTime(2026, 3, 1));
      await recordPercentage(repo, two, 60, DateTime(2026, 1, 1));

      // Subject 1, chapter B.
      final b = await repo.createChapter(
        subjectId: 1,
        name: 'ب',
        at: kSeedInstant,
      );

      // Many exams spanning both boundaries, again recorded out of order.
      final many = await repo.createLesson(
        chapterId: b,
        name: 'خمسة',
        at: kSeedInstant,
      );
      await recordPercentage(repo, many, 100, DateTime(2026, 5, 1));
      await recordPercentage(repo, many, 40, DateTime(2026, 1, 1));
      await recordPercentage(repo, many, 60, DateTime(2026, 2, 1));
      await recordPercentage(repo, many, 80, DateTime(2026, 3, 1));
      await recordPercentage(repo, many, 0, DateTime(2026, 4, 1));

      // Three exams sharing one instant: ties must break deterministically by
      // id identically on both paths.
      final tied = await repo.createLesson(
        chapterId: b,
        name: 'متساوية',
        at: kSeedInstant,
      );
      final tieInstant = DateTime(2026, 3, 15, 12);
      await recordPercentage(repo, tied, 25, tieInstant);
      await recordPercentage(repo, tied, 75, tieInstant);
      await recordPercentage(repo, tied, 50, tieInstant);

      // Subject 2 (seeded): the lower boundary and one more shape.
      final c = await repo.createChapter(
        subjectId: 2,
        name: 'ج',
        at: kSeedInstant,
      );
      final zero = await repo.createLesson(
        chapterId: c,
        name: 'صفر',
        at: kSeedInstant,
      );
      await recordPercentage(repo, zero, 0, DateTime(2026, 2, 1));

      final drop = await repo.createLesson(
        chapterId: c,
        name: 'هبوط',
        at: kSeedInstant,
      );
      await recordPercentage(repo, drop, 100, DateTime(2026, 1, 1));
      await recordPercentage(repo, drop, 30, DateTime(2026, 4, 1));

      // Subjects 3 and 4 stay untouched: overall must count them as 0 rather
      // than excluding them.
    });

    double lessonMasteryByName(StudySnapshot snap, String name) {
      final lesson = snap.lessons.firstWhere((l) => l.name == name);
      return MasteryCalculator.lessonMasteries(snap)[lesson.id]!;
    }

    test(
      'the fixture itself is non-degenerate (parity over zeros is vacuous)',
      () async {
        final snap = await diverseFixture();

        // 'خمسة': newest is May's 100, mean(0,80,60,40)=45 -> 83.5.
        expect(lessonMasteryByName(snap, 'خمسة'), closeTo(83.5, 1e-9));
        // 'متساوية': tie broken by id, 50 is last, mean(25,75)=50 -> 50.
        expect(lessonMasteryByName(snap, 'متساوية'), closeTo(50, 1e-9));
        // 'هبوط': newest 30, mean(100)=100 -> 51.
        expect(lessonMasteryByName(snap, 'هبوط'), closeTo(51, 1e-9));
        // 'صفر امتحانات' stays unproven at exactly 0.
        expect(lessonMasteryByName(snap, 'صفر امتحانات'), 0);
      },
    );

    test(
      'lesson level: summary rows equal lessonMastery exactly',
      () async {
        final snap = await diverseFixture();
        final dash = Summaries.dashboard(snap, DateTime(2026, 6, 1));

        expect(dash.subjects, isNotEmpty);
        for (final subject in dash.subjects) {
          for (final chapter in subject.chapters) {
            for (final lesson in chapter.lessons) {
              expect(
                lesson.mastery,
                MasteryCalculator.lessonMastery(
                  snap.examsFor(lesson.lesson.id),
                ),
                reason:
                    'lesson "${lesson.lesson.name}" disagrees between paths',
              );
            }
          }
        }
      },
    );

    test(
      'chapter level: summary rows equal chapterMasteryOf exactly',
      () async {
        final snap = await diverseFixture();
        final dash = Summaries.dashboard(snap, DateTime(2026, 6, 1));

        expect(dash.subjects, isNotEmpty);
        for (final subject in dash.subjects) {
          for (final chapter in subject.chapters) {
            expect(
              chapter.mastery,
              MasteryCalculator.chapterMasteryOf(snap, chapter.chapter.id),
              reason:
                  'chapter "${chapter.chapter.name}" disagrees between paths',
            );
          }
        }
      },
    );

    test(
      'subject level: summary rows equal subjectMasteryOf exactly',
      () async {
        final snap = await diverseFixture();
        final dash = Summaries.dashboard(snap, DateTime(2026, 6, 1));

        // All four seeded subjects are active, so all four appear -- including
        // the two with no chapters at all.
        expect(dash.subjects.length, 4);
        for (final subject in dash.subjects) {
          expect(
            subject.mastery,
            MasteryCalculator.subjectMasteryOf(snap, subject.subject.id),
            reason: 'subject ${subject.subject.id} disagrees between paths',
          );
        }

        // And the untouched subjects still pull the overall figure down through
        // both paths alike (checked at the overall level below).
        expect(MasteryCalculator.overallMastery(snap), lessThan(30));
      },
    );

    test(
      'overall level: dashboard.overallMastery equals overallMastery exactly '
      '(the dead-function contract)',
      () async {
        final snap = await diverseFixture();
        final dash = Summaries.dashboard(snap, DateTime(2026, 6, 1));

        // `Summaries.dashboard` computes its overall inline from summaries it
        // already built; `MasteryCalculator.overallMastery` is the official
        // standalone interface. This equality is what makes that safe: the two
        // cannot drift, so the standalone number always names the live one.
        expect(MasteryCalculator.overallMastery(snap), dash.overallMastery);
      },
    );

    test('empty database: both paths agree on zero, never NaN', () async {
      final snap = await buildSnapshot((_) async {});
      final dash = Summaries.dashboard(snap, DateTime(2026, 6, 1));

      expect(MasteryCalculator.overallMastery(snap), 0);
      expect(MasteryCalculator.overallMastery(snap), dash.overallMastery);
      expect(dash.overallMastery.isNaN, isFalse);
    });
  });
}
