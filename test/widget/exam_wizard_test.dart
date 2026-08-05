import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/services/mastery_calculator.dart';
import 'package:ather/domain/services/review_cycle_service.dart';
import 'package:ather/domain/services/summaries.dart';

/// Exercises the rules the exam wizard and the "أتقنت الباب" button enforce,
/// against a real database rather than a mocked one.
void main() {
  late AppDatabase db;
  late DriftStudyRepository repo;
  final now = DateTime(2026, 6, 1);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftStudyRepository(db);
  });

  tearDown(() async => db.close());

  group('exam arithmetic as the wizard computes it', () {
    test('mixed point groups produce the right percentage', () {
      // "5 أسئلة بدرجة واحدة، 3 أسئلة بدرجتين", 4 and 2 correct.
      const groups = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1, examId: 1, pointsPerQuestion: 1, questionCount: 5, correctCount: 4,
        ),
        ExamQuestionGroup(
          id: 2, examId: 1, pointsPerQuestion: 2, questionCount: 3, correctCount: 2,
        ),
      ];

      // possible 5*1 + 3*2 = 11; earned 4*1 + 2*2 = 8
      expect(ExamEntry.percentageOf(groups), closeTo(72.7272, 0.001));
    });

    test('an all-correct exam is exactly 100%', () {
      const groups = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1, examId: 1, pointsPerQuestion: 3, questionCount: 7, correctCount: 7,
        ),
      ];
      expect(ExamEntry.percentageOf(groups), 100);
    });

    test('an all-wrong exam is 0%, not NaN', () {
      const groups = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1, examId: 1, pointsPerQuestion: 2, questionCount: 4, correctCount: 0,
        ),
      ];
      expect(ExamEntry.percentageOf(groups), 0);
      expect(ExamEntry.percentageOf(groups).isNaN, isFalse);
    });

    test('higher-value questions weigh more than low-value ones', () {
      // Same number of questions right, but on the heavier group.
      const heavyRight = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1, examId: 1, pointsPerQuestion: 1, questionCount: 5, correctCount: 0,
        ),
        ExamQuestionGroup(
          id: 2, examId: 1, pointsPerQuestion: 5, questionCount: 5, correctCount: 5,
        ),
      ];
      const lightRight = <ExamQuestionGroup>[
        ExamQuestionGroup(
          id: 1, examId: 1, pointsPerQuestion: 1, questionCount: 5, correctCount: 5,
        ),
        ExamQuestionGroup(
          id: 2, examId: 1, pointsPerQuestion: 5, questionCount: 5, correctCount: 0,
        ),
      ];

      expect(
        ExamEntry.percentageOf(heavyRight),
        greaterThan(ExamEntry.percentageOf(lightRight)),
      );
    });
  });

  group('review exam flow end to end', () {
    test('an overdue lesson clears once a review exam is recorded', () async {
      final chapterId = await repo.createChapter(subjectId: 1, name: 'الباب الأول');
      final lessonId = await repo.createLesson(chapterId: chapterId, name: 'درس');

      // Proven 40 days ago -> decayed.
      await repo.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(pointsPerQuestion: 1, questionCount: 100, correctCount: 85),
        ],
        isReviewExam: false,
        at: now.subtract(const Duration(days: 40)),
      );

      var snapshot = await repo.readSnapshot();
      expect(
        ReviewCycleService.needsReview(snapshot.lessons.single, now),
        isTrue,
      );
      expect(
        ReviewCycleService.chapterNeedsReview(snapshot, chapterId, now),
        isTrue,
        reason: 'one decayed lesson reddens the whole chapter',
      );

      // The student sits the review exam.
      await repo.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(pointsPerQuestion: 1, questionCount: 100, correctCount: 95),
        ],
        isReviewExam: true,
        at: now,
      );

      snapshot = await repo.readSnapshot();
      expect(
        ReviewCycleService.needsReview(snapshot.lessons.single, now),
        isFalse,
        reason: 'a review exam is the only thing that clears decay',
      );
      expect(
        ReviewCycleService.chapterNeedsReview(snapshot, chapterId, now),
        isFalse,
      );

      // Mastery recomputes with the review exam as "last": 95*0.7 + 85*0.3.
      expect(
        MasteryCalculator.lessonMastery(snapshot.examsFor(lessonId)),
        closeTo(92, 1e-9),
      );
      expect(snapshot.examsFor(lessonId).first.isReviewExam, isTrue);
    });
  });

  group('chapter completion guard', () {
    test('blocks, then celebrates once every lesson clears 70%', () async {
      final chapterId = await repo.createChapter(subjectId: 1, name: 'باب');
      final a = await repo.createLesson(chapterId: chapterId, name: 'أ');
      final b = await repo.createLesson(chapterId: chapterId, name: 'ب');

      // Nothing examined yet.
      var snapshot = await repo.readSnapshot();
      expect(ReviewCycleService.canMasterChapter(snapshot, chapterId), isFalse);
      expect(ReviewCycleService.chapterBlockers(snapshot, chapterId), hasLength(2));

      // One strong lesson; the other still unexamined.
      await repo.recordExam(
        lessonId: a,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(pointsPerQuestion: 1, questionCount: 100, correctCount: 90),
        ],
        isReviewExam: false,
        at: now,
      );
      snapshot = await repo.readSnapshot();
      expect(
        ReviewCycleService.canMasterChapter(snapshot, chapterId),
        isFalse,
        reason: 'an unexamined lesson blocks regardless of the others',
      );

      // Second lesson examined but weak -> chapter average 55, still short.
      await repo.recordExam(
        lessonId: b,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(pointsPerQuestion: 1, questionCount: 100, correctCount: 20),
        ],
        isReviewExam: false,
        at: now,
      );
      snapshot = await repo.readSnapshot();
      expect(ReviewCycleService.canMasterChapter(snapshot, chapterId), isFalse);

      final blockers = ReviewCycleService.chapterBlockers(snapshot, chapterId);
      expect(blockers, hasLength(1));
      expect(blockers.single.lesson.name, 'ب');

      // Retake lifts it: 80*0.7 + 20*0.3 = 62 -> chapter (90+62)/2 = 76.
      await repo.recordExam(
        lessonId: b,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(pointsPerQuestion: 1, questionCount: 100, correctCount: 80),
        ],
        isReviewExam: false,
        at: now.add(const Duration(days: 1)),
      );
      snapshot = await repo.readSnapshot();

      expect(
        MasteryCalculator.chapterMasteryOf(snapshot, chapterId),
        closeTo(76, 1e-9),
      );
      expect(ReviewCycleService.canMasterChapter(snapshot, chapterId), isTrue);

      // The gate is the *chapter average*, so a chapter can qualify at 76%
      // while one lesson still sits at 62%. `chapterBlockers` keeps listing
      // that lesson -- it answers "what is weakest here", and is only ever
      // rendered when the gate fails, so the two never contradict on screen.
      final remaining =
          ReviewCycleService.chapterBlockers(snapshot, chapterId);
      expect(remaining, hasLength(1));
      expect(remaining.single.mastery, closeTo(62, 1e-9));
    });

    test('mastering restarts the review clock on every lesson', () async {
      final chapterId = await repo.createChapter(subjectId: 1, name: 'باب');
      for (var i = 0; i < 3; i++) {
        final id = await repo.createLesson(chapterId: chapterId, name: 'د$i');
        await repo.recordExam(
          lessonId: id,
          groups: const <DraftQuestionGroup>[
            DraftQuestionGroup(pointsPerQuestion: 1, questionCount: 100, correctCount: 88),
          ],
          isReviewExam: false,
          at: now.subtract(const Duration(days: 20)),
        );
      }

      await repo.markChapterMastered(chapterId: chapterId, at: now);
      final snapshot = await repo.readSnapshot();

      expect(snapshot.chapterById(chapterId)!.isMastered, isTrue);
      for (final lesson in snapshot.lessons) {
        expect(lesson.lastReviewedAt, now);
        expect(ReviewCycleService.daysUntilDue(lesson, now), 30);
      }
    });
  });

  group('summaries stay consistent with the calculators', () {
    test('a chapter summary reports the same numbers as the raw services',
        () async {
      final chapterId = await repo.createChapter(subjectId: 2, name: 'باب');
      final a = await repo.createLesson(chapterId: chapterId, name: 'أ');
      await repo.createLesson(chapterId: chapterId, name: 'ب');
      await repo.recordExam(
        lessonId: a,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(pointsPerQuestion: 1, questionCount: 100, correctCount: 60),
        ],
        isReviewExam: false,
        at: now,
      );

      final snapshot = await repo.readSnapshot();
      final summary = Summaries.chapter(
        snapshot,
        snapshot.chapterById(chapterId)!,
        now,
      );

      expect(
        summary.mastery,
        closeTo(MasteryCalculator.chapterMasteryOf(snapshot, chapterId), 1e-9),
      );
      expect(summary.lessonCount, 2);
      expect(summary.examinedLessonCount, 1);
      expect(summary.canMaster, isFalse);
      expect(summary.weakestLesson!.lesson.name, 'ب');
    });

    test('the dashboard counts remaining lessons and mastered chapters',
        () async {
      final chapterId = await repo.createChapter(subjectId: 1, name: 'باب');
      final strong = await repo.createLesson(chapterId: chapterId, name: 'قوي');
      await repo.createLesson(chapterId: chapterId, name: 'بدون');
      await repo.recordExam(
        lessonId: strong,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(pointsPerQuestion: 1, questionCount: 100, correctCount: 92),
        ],
        isReviewExam: false,
        at: now,
      );

      final snapshot = await repo.readSnapshot();
      final dashboard = Summaries.dashboard(snapshot, now);

      expect(dashboard.totalChapters, 1);
      expect(dashboard.masteredChapters, 0);
      // Only the unexamined lesson still counts as remaining.
      expect(dashboard.lessonsRemaining, 1);
      expect(dashboard.strongestSubject!.subject.id, 1);
      expect(dashboard.overdueCount, 0);
    });
  });
}
