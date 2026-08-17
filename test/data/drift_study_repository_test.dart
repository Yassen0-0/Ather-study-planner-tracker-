// package:drift/drift.dart is deliberately NOT imported here: it exports SQL
// expression builders also called isNull / isNotNull, which shadow matcher's
// and break every null assertion in this file.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/instants.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/subject.dart';

void main() {
  late AppDatabase db;
  late DriftStudyRepository repo;

  setUp(() {
    // A real SQLite engine in memory -- cascades and PRAGMAs behave exactly as
    // they will on device, which a mocked repository would not prove.
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftStudyRepository(db);
  });

  tearDown(() async => db.close());

  group('seed', () {
    test('creates exactly the four fixed subjects, in order', () async {
      final snap = await repo.readSnapshot();

      expect(snap.subjects, hasLength(4));
      expect(snap.subjects.map((s) => s.code), <SubjectCode>[
        SubjectCode.biology,
        SubjectCode.physics,
        SubjectCode.chemistry,
        SubjectCode.english,
      ]);
      expect(snap.subjects.map((s) => s.id), <int>[1, 2, 3, 4]);
    });

    test('is idempotent across repeated opens', () async {
      // beforeOpen re-runs the seed on every connection; it must not duplicate.
      await repo.readSnapshot();
      await db.customStatement('SELECT 1');
      final snap = await repo.readSnapshot();

      expect(snap.subjects, hasLength(4));
    });
  });

  group('cascade deletes', () {
    test(
      'deleting a chapter removes its lessons, exams, groups and homework',
      () async {
        final chapterId = await repo.createChapter(
          subjectId: 1,
          name: 'الباب الأول',
          at: kSeedInstant,
        );
        final lessonId = await repo.createLesson(
          chapterId: chapterId,
          name: 'درس',
          at: kSeedInstant,
        );

        await repo.recordExam(
          lessonId: lessonId,
          groups: const <DraftQuestionGroup>[
            DraftQuestionGroup(
              pointsPerQuestion: 2,
              questionCount: 5,
              correctCount: 4,
            ),
          ],
          isReviewExam: false,
          at: DateTime(2026, 1, 1),
        );
        await repo.recordHomework(
          lessonId: lessonId,
          score: 8,
          maxScore: 10,
          at: DateTime(2026, 1, 1),
        );

        var snap = await repo.readSnapshot();
        expect(snap.lessons, hasLength(1));
        expect(snap.exams, hasLength(1));
        expect(snap.exams.single.groups, hasLength(1));
        expect(snap.homework, hasLength(1));

        await repo.deleteChapter(chapterId);

        snap = await repo.readSnapshot();
        expect(snap.chapters, isEmpty);
        expect(snap.lessons, isEmpty, reason: 'lessons must cascade');
        expect(snap.exams, isEmpty, reason: 'exams must cascade');
        expect(snap.homework, isEmpty, reason: 'homework must cascade');

        // The groups table has no repository read of its own, so assert directly.
        final groups = await db.select(db.examQuestionGroups).get();
        expect(groups, isEmpty, reason: 'question groups must cascade');
      },
    );
  });

  group('recordExam', () {
    test('derives totals and percentage from the groups', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );

      // 5 questions worth 1 (4 right) + 3 questions worth 2 (2 right)
      //   possible = 5*1 + 3*2 = 11
      //   earned   = 4*1 + 2*2 = 8
      //   => 72.7272...%
      await repo.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 5,
            correctCount: 4,
          ),
          DraftQuestionGroup(
            pointsPerQuestion: 2,
            questionCount: 3,
            correctCount: 2,
          ),
        ],
        isReviewExam: false,
        at: DateTime(2026, 1, 1),
      );

      final exam = (await repo.readSnapshot()).exams.single;
      expect(exam.totalPossiblePoints, 11);
      expect(exam.correctPoints, 8);
      expect(exam.percentage, closeTo(72.7272, 0.001));
      expect(exam.groups, hasLength(2));
    });

    test('a zero-point exam yields 0%, not NaN', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );

      await repo.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[],
        isReviewExam: false,
        at: DateTime(2026, 1, 1),
      );

      final exam = (await repo.readSnapshot()).exams.single;
      expect(exam.percentage, 0);
      expect(exam.percentage.isNaN, isFalse);
    });

    test(
      'resets the review clock and clears notification bookkeeping',
      () async {
        final chapterId = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        final lessonId = await repo.createLesson(
          chapterId: chapterId,
          name: 'درس',
          at: kSeedInstant,
        );

        await repo.markLessonNotified(
          lessonId: lessonId,
          at: DateTime(2026, 1, 1),
        );
        expect(
          (await repo.readSnapshot()).lessons.single.lastNotifiedAt,
          isNotNull,
        );

        final examAt = DateTime(2026, 3, 5);
        await repo.recordExam(
          lessonId: lessonId,
          groups: const <DraftQuestionGroup>[
            DraftQuestionGroup(
              pointsPerQuestion: 1,
              questionCount: 1,
              correctCount: 1,
            ),
          ],
          isReviewExam: true,
          at: examAt,
        );

        final lesson = (await repo.readSnapshot()).lessons.single;
        expect(lesson.lastReviewedAt, examAt);
        expect(
          lesson.lastNotifiedAt,
          isNull,
          reason: 'a new cycle must be allowed to notify again',
        );
        expect(lesson.checklist.didExam, isTrue);
      },
    );
  });

  group('markChapterMastered', () {
    test('stamps the chapter and resets every lesson in it', () async {
      final chapterId = await repo.createChapter(
        subjectId: 2,
        name: 'باب',
        at: kSeedInstant,
      );
      await repo.createLesson(
        chapterId: chapterId,
        name: 'درس ١',
        at: kSeedInstant,
      );
      await repo.createLesson(
        chapterId: chapterId,
        name: 'درس ٢',
        at: kSeedInstant,
      );

      final at = DateTime(2026, 5, 20);
      await repo.markChapterMastered(chapterId: chapterId, at: at);

      final snap = await repo.readSnapshot();
      expect(snap.chapters.single.masteredAt, at);
      expect(snap.chapters.single.isMastered, isTrue);
      expect(
        snap.lessons.map((l) => l.lastReviewedAt),
        everyElement(at),
        reason: 'mastering a chapter restarts the clock on all its lessons',
      );
    });

    test('does not touch lessons in other chapters', () async {
      final a = await repo.createChapter(
        subjectId: 1,
        name: 'باب أ',
        at: kSeedInstant,
      );
      final b = await repo.createChapter(
        subjectId: 1,
        name: 'باب ب',
        at: kSeedInstant,
      );
      await repo.createLesson(chapterId: a, name: 'درس أ', at: kSeedInstant);
      final otherLesson = await repo.createLesson(
        chapterId: b,
        name: 'درس ب',
        at: kSeedInstant,
      );

      await repo.markChapterMastered(chapterId: a, at: DateTime(2026, 5, 20));

      final snap = await repo.readSnapshot();
      expect(snap.lessonById(otherLesson)!.lastReviewedAt, isNull);
    });
  });

  group('checklist', () {
    test('round-trips all five flags', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );

      await repo.updateChecklist(
        lessonId: lessonId,
        checklist: const LessonChecklist(
          watchedLesson: true,
          readNotes: true,
          didHomework: false,
          didExam: false,
          reviewedNotes: true,
        ),
      );

      final checklist = (await repo.readSnapshot()).lessons.single.checklist;
      expect(checklist.watchedLesson, isTrue);
      expect(checklist.readNotes, isTrue);
      expect(checklist.didHomework, isFalse);
      expect(checklist.didExam, isFalse);
      expect(checklist.reviewedNotes, isTrue);
      expect(checklist.completedCount, 3);
      expect(checklist.isComplete, isFalse);
    });
  });

  group('snapshot indexing', () {
    test('orders a lesson\'s exams newest first', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );

      for (final day in <int>[1, 15, 8]) {
        await repo.recordExam(
          lessonId: lessonId,
          groups: <DraftQuestionGroup>[
            DraftQuestionGroup(
              pointsPerQuestion: 1,
              questionCount: 10,
              correctCount: day,
            ),
          ],
          isReviewExam: false,
          at: DateTime(2026, 2, day),
        );
      }

      final exams = (await repo.readSnapshot()).examsFor(lessonId);
      expect(exams.map((e) => e.createdAt.day), <int>[15, 8, 1]);
    });

    test('lessonsInSubject spans every chapter of that subject', () async {
      final a = await repo.createChapter(
        subjectId: 3,
        name: 'باب أ',
        at: kSeedInstant,
      );
      final b = await repo.createChapter(
        subjectId: 3,
        name: 'باب ب',
        at: kSeedInstant,
      );
      final other = await repo.createChapter(
        subjectId: 4,
        name: 'باب ج',
        at: kSeedInstant,
      );
      await repo.createLesson(chapterId: a, name: 'د١', at: kSeedInstant);
      await repo.createLesson(chapterId: b, name: 'د٢', at: kSeedInstant);
      await repo.createLesson(chapterId: other, name: 'د٣', at: kSeedInstant);

      final snap = await repo.readSnapshot();
      expect(snap.lessonsInSubject(3), hasLength(2));
      expect(snap.lessonsInSubject(4), hasLength(1));
    });

    test('unexamined lesson yields an empty exam list, never null', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );

      expect((await repo.readSnapshot()).examsFor(lessonId), isEmpty);
    });
  });

  group('watchSnapshot', () {
    test('emits an initial value and re-emits on every write', () async {
      final emissions = <int>[];
      final sub = repo.watchSnapshot().listen(
        (s) => emissions.add(s.chapters.length),
      );

      // Let the initial combined emission land.
      await pumpEventQueue();
      expect(emissions, isNotEmpty, reason: 'must emit an initial snapshot');
      expect(emissions.last, 0);

      await repo.createChapter(subjectId: 1, name: 'باب', at: kSeedInstant);
      await pumpEventQueue();
      expect(emissions.last, 1);

      await repo.createChapter(subjectId: 1, name: 'باب ٢', at: kSeedInstant);
      await pumpEventQueue();
      expect(emissions.last, 2);

      await sub.cancel();
    });

    test('a write to any table refreshes the whole snapshot', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );

      final seen = <int>[];
      final sub = repo.watchSnapshot().listen((s) => seen.add(s.exams.length));
      await pumpEventQueue();

      await repo.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 4,
            correctCount: 3,
          ),
        ],
        isReviewExam: false,
        at: DateTime(2026, 4, 1),
      );
      await pumpEventQueue();

      expect(seen.last, 1);
      await sub.cancel();
    });
  });

  // Deleting evidence has to move the clock that evidence started. Mastery is
  // derived and fixes itself; `lastReviewedAt` is stored and does not, so
  // without this the lesson keeps counting down from a date whose exam no
  // longer exists.
  group('deleteExam', () {
    Future<({int chapterId, int lessonId})> lesson() async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );
      return (chapterId: chapterId, lessonId: lessonId);
    }

    Future<int> record(int lessonId, DateTime at, int correct) {
      return repo.recordExam(
        lessonId: lessonId,
        groups: <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 10,
            correctCount: correct,
          ),
        ],
        isReviewExam: false,
        at: at,
      );
    }

    test('the only exam leaves the lesson unexamined again', () async {
      final ids = await lesson();
      final examId = await record(ids.lessonId, DateTime(2026, 3, 1), 7);

      await repo.deleteExam(examId);
      final snap = await repo.readSnapshot();

      expect(snap.examsFor(ids.lessonId), isEmpty);
      // Not overdue, not due -- never examined. Red means decayed, not
      // untouched, and a lesson with no exams has no clock at all.
      expect(snap.lessonById(ids.lessonId)!.lastReviewedAt, isNull);
    });

    test('the newest exam winds the clock back to the one before it', () async {
      final ids = await lesson();
      await record(ids.lessonId, DateTime(2026, 3, 1), 5);
      final newer = await record(ids.lessonId, DateTime(2026, 4, 1), 9);

      await repo.deleteExam(newer);
      final snap = await repo.readSnapshot();

      expect(snap.examsFor(ids.lessonId), hasLength(1));
      expect(
        snap.lessonById(ids.lessonId)!.lastReviewedAt,
        DateTime(2026, 3, 1),
      );
    });

    test('an older exam leaves the newest one holding the clock', () async {
      final ids = await lesson();
      final older = await record(ids.lessonId, DateTime(2026, 3, 1), 5);
      await record(ids.lessonId, DateTime(2026, 4, 1), 9);

      await repo.deleteExam(older);
      final snap = await repo.readSnapshot();

      expect(
        snap.lessonById(ids.lessonId)!.lastReviewedAt,
        DateTime(2026, 4, 1),
      );
    });

    test(
      'a mastered chapter still holds the clock with no exams left',
      () async {
        // "أتقنت الباب" restarts the cycle too, and it is not an exam. Deleting
        // the last exam must not quietly undo a chapter the student closed out.
        final ids = await lesson();
        final examId = await record(ids.lessonId, DateTime(2026, 3, 1), 9);
        await repo.markChapterMastered(
          chapterId: ids.chapterId,
          at: DateTime(2026, 5, 1),
        );

        await repo.deleteExam(examId);
        final snap = await repo.readSnapshot();

        expect(
          snap.lessonById(ids.lessonId)!.lastReviewedAt,
          DateTime(2026, 5, 1),
        );
      },
    );

    test('takes the exam question groups with it', () async {
      final ids = await lesson();
      final examId = await record(ids.lessonId, DateTime(2026, 3, 1), 7);

      await repo.deleteExam(examId);

      final groups = await db.select(db.examQuestionGroups).get();
      expect(groups, isEmpty);
    });
  });

  group('clear', () {
    test('empties the record but leaves the seeded subjects', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      final lessonId = await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );
      await repo.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 4,
            correctCount: 3,
          ),
        ],
        isReviewExam: false,
        at: DateTime(2026, 4, 1),
      );

      await repo.clear();
      final snap = await repo.readSnapshot();

      expect(snap.chapters, isEmpty);
      expect(snap.lessons, isEmpty);
      expect(snap.exams, isEmpty);
      expect(snap.homework, isEmpty);
      // Back to the four Ather ships with -- including any the student added,
      // which are as much "everything on this device" as a chapter is. Reset
      // rather than emptied: the seed only runs on create and on the 2 -> 3
      // migration, so an emptied table would still be empty at the next
      // sign-in.
      expect(snap.subjects, hasLength(4));
      expect(snap.subjects.every((s) => s.isSeeded), isTrue);
    });

    test('clear takes the subjects the student added with it', () async {
      final id = await repo.createSubject(name: 'رياضيات');
      expect((await repo.readSnapshot()).subjects, hasLength(5));

      await repo.clear();
      final snap = await repo.readSnapshot();

      expect(snap.subjects, hasLength(4));
      expect(snap.subjectById(id), isNull);
    });
  });

  group('subjects the student adds', () {
    test('a new subject lands after the seeded four and keeps its name', () async {
      final id = await repo.createSubject(name: '  رياضيات  ');
      final subject = (await repo.readSnapshot()).subjectById(id)!;

      expect(id, 5, reason: 'max(id) + 1 over the seeded 1-4');
      expect(subject.name, 'رياضيات', reason: 'trimmed on the way in');
      expect(subject.code, isNull, reason: 'not one of the four');
      expect(subject.isSeeded, isFalse);
      expect(subject.sortOrder, 4);
    });

    test('two subjects added back to back do not collide', () async {
      final first = await repo.createSubject(name: 'رياضيات');
      final second = await repo.createSubject(name: 'تاريخ');

      expect(first, isNot(second));
      expect((await repo.readSnapshot()).subjects, hasLength(6));
    });

    test('renaming is refused for the seeded four', () async {
      // Their names come from the ARB files so the language toggle can reach
      // them. A name written here would freeze one language into the database.
      await repo.renameSubject(subjectId: 1, name: 'حاجة تانية');
      expect((await repo.readSnapshot()).subjectById(1)!.name, isNull);

      final id = await repo.createSubject(name: 'رياضيات');
      await repo.renameSubject(subjectId: id, name: 'رياضيات بحتة');
      expect(
        (await repo.readSnapshot()).subjectById(id)!.name,
        'رياضيات بحتة',
      );
    });

    test('hiding a subject keeps everything under it', () async {
      final chapterId = await repo.createChapter(
        subjectId: 1,
        name: 'باب',
        at: kSeedInstant,
      );
      await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );

      await repo.setSubjectArchived(subjectId: 1, at: DateTime(2026, 8, 17));
      var snap = await repo.readSnapshot();

      expect(snap.subjectById(1)!.isArchived, isTrue);
      expect(
        snap.activeSubjects.map((s) => s.id),
        isNot(contains(1)),
        reason: 'hidden means out of every figure the student reads',
      );
      // Nothing was destroyed, which is the whole difference between this and
      // a delete.
      expect(snap.chapters, hasLength(1));
      expect(snap.lessons, hasLength(1));

      await repo.setSubjectArchived(subjectId: 1, at: null);
      snap = await repo.readSnapshot();
      expect(snap.activeSubjects.map((s) => s.id), contains(1));
      expect(snap.chapters, hasLength(1));
    });

    test('a subject with any chapter under it refuses to be deleted', () async {
      final id = await repo.createSubject(name: 'رياضيات');
      await repo.createChapter(
        subjectId: id,
        name: 'باب',
        at: kSeedInstant,
      );

      // The guard lives in the repository, not the screen, so no future caller
      // can route around it. Chapters cascade: without this, one confirmation
      // takes every exam ever recorded under the subject.
      expect(await repo.deleteEmptySubject(id), isFalse);
      expect((await repo.readSnapshot()).subjectById(id), isNotNull);
      expect((await repo.readSnapshot()).chapters, hasLength(1));
    });

    test('an empty subject deletes cleanly', () async {
      final id = await repo.createSubject(name: 'أُضيفت بالغلط');

      expect(await repo.deleteEmptySubject(id), isTrue);
      expect((await repo.readSnapshot()).subjectById(id), isNull);
    });
  });
}
