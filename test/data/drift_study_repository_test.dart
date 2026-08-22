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
import 'package:ather/domain/services/curriculum_templates.dart';

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
    /// Outwaits the combined stream's coalescing window.
    ///
    /// The stream deliberately emits once per burst rather than once per
    /// contributing table -- one write usually touches three of the six, and
    /// each emission rebuilds the whole record. That window is a real [Timer],
    /// so `pumpEventQueue` alone no longer reaches past it.
    Future<void> settle() async {
      await Future<void>.delayed(kSnapshotCoalesceWindow * 3);
      await pumpEventQueue();
    }

    test('emits an initial value and re-emits on every write', () async {
      final emissions = <int>[];
      final sub = repo.watchSnapshot().listen(
        (s) => emissions.add(s.chapters.length),
      );

      // Let the initial combined emission land.
      await settle();
      expect(emissions, isNotEmpty, reason: 'must emit an initial snapshot');
      expect(emissions.last, 0);

      await repo.createChapter(subjectId: 1, name: 'باب', at: kSeedInstant);
      await settle();
      expect(emissions.last, 1);

      await repo.createChapter(subjectId: 1, name: 'باب ٢', at: kSeedInstant);
      await settle();
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
      await settle();

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
      await settle();

      expect(seen.last, 1);
      // Saving an exam writes three of the six tables -- `exam_entries`,
      // `exam_question_groups` and `lessons` -- and this used to emit once per
      // table, rebuilding the entire record three times for one action.
      expect(
        seen.length,
        2,
        reason: 'one initial emission, then one for the whole write',
      );
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

    test('deleting the only exam clears the checklist tick too', () async {
      // `recordExam` sets `didExam` as a side effect; deleting the evidence
      // must unset it again, or the screen says mastery 0 and "sat an exam"
      // at once.
      final ids = await lesson();
      final examId = await record(ids.lessonId, DateTime(2026, 3, 1), 7);

      await repo.deleteExam(examId);
      final snap = await repo.readSnapshot();

      expect(snap.examsFor(ids.lessonId), isEmpty);
      expect(snap.lessonById(ids.lessonId)!.checklist.didExam, isFalse);
      expect(snap.lessonById(ids.lessonId)!.lastReviewedAt, isNull);
    });

    test('an exam that remains keeps the checklist tick set', () async {
      final ids = await lesson();
      await record(ids.lessonId, DateTime(2026, 3, 1), 5);
      final newer = await record(ids.lessonId, DateTime(2026, 4, 1), 9);

      await repo.deleteExam(newer);
      final snap = await repo.readSnapshot();

      expect(snap.examsFor(ids.lessonId), hasLength(1));
      expect(snap.lessonById(ids.lessonId)!.checklist.didExam, isTrue);
    });

    test(
      'a lesson born after the gate is not proven by deleting into it',
      () async {
        // Mastering stamps every lesson that existed. A lesson added later
        // inherited nothing from that stamp -- so when its own exam is deleted,
        // falling back to `masteredAt` would leave it proven days before it
        // was created.
        final chapterId = await repo.createChapter(
          subjectId: 1,
          name: 'باب',
          at: kSeedInstant,
        );
        await repo.markChapterMastered(
          chapterId: chapterId,
          at: DateTime(2026, 2, 1),
        );
        final lateLesson = await repo.createLesson(
          chapterId: chapterId,
          name: 'درس لاحق',
          at: DateTime(2026, 3, 1),
        );
        final examId = await record(lateLesson, DateTime(2026, 3, 10), 8);

        await repo.deleteExam(examId);
        final snap = await repo.readSnapshot();

        final l = snap.lessonById(lateLesson)!;
        expect(l.lastReviewedAt, isNull);
        expect(l.checklist.didExam, isFalse);
      },
    );

    test('with an exam remaining, mastery and the exam compete for the clock', () async {
      // The lesson predates the gate, so the mastery stamp *is* admissible --
      // and the newer of it and the surviving exam wins.
      final ids = await lesson();
      await record(ids.lessonId, DateTime(2026, 3, 1), 6);
      final newer = await record(ids.lessonId, DateTime(2026, 4, 1), 7);
      await repo.markChapterMastered(
        chapterId: ids.chapterId,
        at: DateTime(2026, 5, 1),
      );

      await repo.deleteExam(newer);
      final snap = await repo.readSnapshot();

      expect(snap.lessonById(ids.lessonId)!.lastReviewedAt, DateTime(2026, 5, 1));
      expect(snap.lessonById(ids.lessonId)!.checklist.didExam, isTrue);
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
    test(
      'a new subject lands after the seeded four and keeps its name',
      () async {
        final id = await repo.createSubject(name: '  رياضيات  ');
        final subject = (await repo.readSnapshot()).subjectById(id)!;

        expect(id, 5, reason: 'max(id) + 1 over the seeded 1-4');
        expect(subject.name, 'رياضيات', reason: 'trimmed on the way in');
        expect(subject.code, isNull, reason: 'not one of the four');
        expect(subject.isSeeded, isFalse);
        expect(subject.sortOrder, 4);
      },
    );

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
      expect((await repo.readSnapshot()).subjectById(id)!.name, 'رياضيات بحتة');
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

    test(
      'deleting a subject keeps everything under it, and it comes back',
      () async {
        // The claim the recycle bin is built on. An earlier design refused to
        // delete a subject that had chapters at all, which protected the data and
        // left a dead end: a subject the student did not take could never be
        // removed. Delete is a flag now, and this is what makes that honest.
        final id = await repo.createSubject(name: 'رياضيات');
        final chapterId = await repo.createChapter(
          subjectId: id,
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
          at: kSeedInstant,
        );

        await repo.setSubjectDeleted(subjectId: id, at: DateTime(2026, 8, 17));
        var snap = await repo.readSnapshot();

        expect(snap.subjectById(id)!.isDeleted, isTrue);
        expect(snap.activeSubjects.map((s) => s.id), isNot(contains(id)));
        expect(snap.deletedSubjects.map((s) => s.id), contains(id));
        // Nothing was destroyed -- that is the entire difference between this
        // and emptying the bin.
        expect(snap.chapters, hasLength(1));
        expect(snap.lessons, hasLength(1));
        expect(snap.exams, hasLength(1));

        await repo.setSubjectDeleted(subjectId: id, at: null);
        snap = await repo.readSnapshot();

        expect(snap.activeSubjects.map((s) => s.id), contains(id));
        expect(
          snap.exams,
          hasLength(1),
          reason: 'the exam survived the round trip',
        );
      },
    );

    test(
      'a deleted subject stops feeding reminders and the review queue',
      () async {
        // The hole `activeSubjects` alone left. Three things walk the flat lesson
        // list rather than descending from subjects, so a subject put away kept
        // sending reminders carrying its lesson names to a lock screen.
        final id = await repo.createSubject(name: 'رياضيات');
        final chapterId = await repo.createChapter(
          subjectId: id,
          name: 'باب',
          at: kSeedInstant,
        );
        await repo.createLesson(
          chapterId: chapterId,
          name: 'درس مخفي',
          at: kSeedInstant,
        );

        expect((await repo.readSnapshot()).activeLessons, hasLength(1));

        await repo.setSubjectDeleted(subjectId: id, at: DateTime(2026, 8, 17));
        expect((await repo.readSnapshot()).activeLessons, isEmpty);

        await repo.setSubjectDeleted(subjectId: id, at: null);
        await repo.setSubjectArchived(subjectId: id, at: DateTime(2026, 8, 17));
        expect(
          (await repo.readSnapshot()).activeLessons,
          isEmpty,
          reason: 'archiving has to silence it too, for the same reason',
        );
      },
    );

    test('emptying the bin is the one thing that actually destroys', () async {
      final id = await repo.createSubject(name: 'رياضيات');
      final chapterId = await repo.createChapter(
        subjectId: id,
        name: 'باب',
        at: kSeedInstant,
      );
      await repo.createLesson(
        chapterId: chapterId,
        name: 'درس',
        at: kSeedInstant,
      );
      await repo.setSubjectDeleted(subjectId: id, at: DateTime(2026, 8, 17));

      await repo.purgeSubject(id);
      final snap = await repo.readSnapshot();

      expect(snap.subjectById(id), isNull);
      // The cascade finally firing, which is why this is behind a confirmation
      // that counts what goes.
      expect(snap.chapters, isEmpty);
      expect(snap.lessons, isEmpty);
      // And it took only its own: the seeded four are untouched.
      expect(snap.subjects, hasLength(4));
    });

    test('archived and deleted are independent states', () async {
      final id = await repo.createSubject(name: 'رياضيات');

      await repo.setSubjectArchived(subjectId: id, at: DateTime(2026, 8, 1));
      await repo.setSubjectDeleted(subjectId: id, at: DateTime(2026, 8, 17));
      var subject = (await repo.readSnapshot()).subjectById(id)!;
      expect(subject.isArchived, isTrue);
      expect(subject.isDeleted, isTrue);
      expect(subject.isActive, isFalse);

      // Restoring from the bin returns it to the archive it was in, not to the
      // active list. Two flags, two answers -- which is the point of keeping
      // them separate.
      await repo.setSubjectDeleted(subjectId: id, at: null);
      subject = (await repo.readSnapshot()).subjectById(id)!;
      expect(subject.isArchived, isTrue);
      expect(subject.isActive, isFalse);
    });
  });

  group('curriculum templates', () {
    // Biology is subject 1 in the seed.
    const int biology = 1;

    test('applying a template creates every chapter, in order', () async {
      final template = CurriculumTemplates.chaptersFor(SubjectCode.biology)!;

      final created = await repo.addChapters(
        subjectId: biology,
        names: template,
        at: kSeedInstant,
      );

      expect(created, template.length);

      final chapters = (await repo.readSnapshot()).chaptersIn(biology);
      expect(chapters.map((c) => c.name), template);
    });

    test('order survives past the point Dart sort stops being stable', () async {
      // `List.sort` is only stable below 32 elements; above that Dart switches
      // to dual-pivot quicksort and reorders equal keys arbitrarily. Every
      // chapter of a template is written under one `createdAt`, so the whole
      // template is one tie block -- and the test above cannot see the problem
      // because ten rows in an empty database stays under the threshold.
      //
      // Four templates plus a few chapters of the student's own crosses it.
      // Before the id tie-break, this produced Physics with باب 1 and باب 2
      // swapped, and English with Unit 1 rendered last.
      for (final (subjectId, code) in <(int, SubjectCode)>[
        (1, SubjectCode.biology),
        (2, SubjectCode.physics),
        (3, SubjectCode.chemistry),
        (4, SubjectCode.english),
      ]) {
        await repo.addChapters(
          subjectId: subjectId,
          names: CurriculumTemplates.chaptersFor(code)!,
          at: kSeedInstant,
        );
      }
      for (final name in <String>['بابي الأول', 'بابي الثاني', 'بابي الثالث']) {
        await repo.createChapter(subjectId: 1, name: name, at: kSeedInstant);
      }

      final snapshot = await repo.readSnapshot();
      expect(
        snapshot.chapters.length,
        greaterThan(32),
        reason: 'the sample has to cross the stability threshold to mean anything',
      );

      for (final (subjectId, code) in <(int, SubjectCode)>[
        (2, SubjectCode.physics),
        (3, SubjectCode.chemistry),
        (4, SubjectCode.english),
      ]) {
        expect(
          snapshot.chaptersIn(subjectId).map((c) => c.name),
          CurriculumTemplates.chaptersFor(code)!,
          reason: 'the taught order of $code was scrambled',
        );
      }
    });

    test('a name differing only in Arabic spelling is not a second chapter',
        () async {
      // The promise is "applying a template never duplicates a chapter you
      // already have", and a student types their chapter names on a phone
      // keyboard. Writing ه for ة, or skipping the hamza on أ/إ, is ordinary
      // Arabic -- not a mistake -- and a byte-exact comparison called each of
      // these a different chapter, leaving the student with two rows for one
      // باب and their lessons hanging off only one of them.
      await repo.createChapter(subjectId: 1, name: 'الوراثه', at: kSeedInstant);
      await repo.createChapter(
        subjectId: 1,
        name: 'الاخراج في الكائنات الحيه',
        at: kSeedInstant,
      );

      final created = await repo.addChapters(
        subjectId: 1,
        names: <String>[
          'الوراثة',
          'الإخراج في الكائنات الحية',
          'باب جديد فعلاً',
        ],
        at: kSeedInstant,
      );

      expect(created, 1, reason: 'only the genuinely new chapter is added');

      final names = (await repo.readSnapshot())
          .chaptersIn(1)
          .map((c) => c.name)
          .toList();
      expect(names, hasLength(3));
      // The student's own spelling is what stays on screen -- matching is not
      // the same as rewriting what they typed.
      expect(names, contains('الوراثه'));
      expect(names, isNot(contains('الوراثة')));
    });

    test('case and stray spaces do not create a second chapter', () async {
      await repo.createChapter(subjectId: 4, name: 'unit 1', at: kSeedInstant);

      final created = await repo.addChapters(
        subjectId: 4,
        names: <String>['Unit  1', 'Unit 2'],
        at: kSeedInstant,
      );

      expect(created, 1);
      expect((await repo.readSnapshot()).chaptersIn(4), hasLength(2));
    });

    test('applying it twice does not duplicate anything', () async {
      final template = CurriculumTemplates.chaptersFor(SubjectCode.physics)!;

      await repo.addChapters(subjectId: 2, names: template, at: kSeedInstant);
      final second = await repo.addChapters(
        subjectId: 2,
        names: template,
        at: kSeedInstant,
      );

      expect(second, 0, reason: 'the second apply has nothing to add');
      expect(
        (await repo.readSnapshot()).chaptersIn(2),
        hasLength(template.length),
      );
    });

    test('a chapter the student already typed is never touched', () async {
      // The student typed one of the template's chapters themselves, then
      // renamed a lesson under it -- the row has their work hanging off it.
      final mine = await repo.createChapter(
        subjectId: biology,
        name: 'المناعة',
        at: kSeedInstant,
      );
      await repo.createLesson(chapterId: mine, name: 'درسي', at: kSeedInstant);

      final template = CurriculumTemplates.chaptersFor(SubjectCode.biology)!;
      final created = await repo.addChapters(
        subjectId: biology,
        names: template,
        at: kSeedInstant,
      );

      expect(created, template.length - 1);

      final snap = await repo.readSnapshot();
      final chapters = snap.chaptersIn(biology);
      expect(
        chapters.where((c) => c.name == 'المناعة'),
        hasLength(1),
        reason:
            'the template must not add a second copy of a chapter the '
            'student already has',
      );
      // Same row, with the lesson still on it.
      expect(chapters.singleWhere((c) => c.name == 'المناعة').id, mine);
      expect(snap.lessonsIn(mine), hasLength(1));
    });

    test('a renamed chapter is left alone and its name is added', () async {
      // The student renamed a template chapter to their own wording. That is
      // now a different name, so the template's version is genuinely missing
      // and gets added -- but the renamed row is not disturbed.
      final renamed = await repo.createChapter(
        subjectId: 3,
        name: 'الكيمياء الكهربية',
        at: kSeedInstant,
      );
      await repo.renameChapter(chapterId: renamed, name: 'باب الكهرباء');

      final template = CurriculumTemplates.chaptersFor(SubjectCode.chemistry)!;
      await repo.addChapters(subjectId: 3, names: template, at: kSeedInstant);

      final chapters = (await repo.readSnapshot()).chaptersIn(3);
      expect(
        chapters.singleWhere((c) => c.id == renamed).name,
        'باب الكهرباء',
        reason: 'the student renamed it; the template does not rename it back',
      );
      expect(chapters, hasLength(template.length + 1));
    });

    test('it only touches the subject it was asked about', () async {
      await repo.addChapters(
        subjectId: biology,
        names: CurriculumTemplates.chaptersFor(SubjectCode.biology)!,
        at: kSeedInstant,
      );

      final snap = await repo.readSnapshot();
      expect(snap.chaptersIn(2), isEmpty);
      expect(snap.chaptersIn(3), isEmpty);
      expect(snap.chaptersIn(4), isEmpty);
    });

    test('a repeated name inside one template is inserted once', () async {
      final created = await repo.addChapters(
        subjectId: biology,
        names: const <String>['باب', 'باب', 'باب آخر'],
        at: kSeedInstant,
      );

      expect(created, 2);
      expect((await repo.readSnapshot()).chaptersIn(biology), hasLength(2));
    });

    test('blank entries are skipped rather than written', () async {
      final created = await repo.addChapters(
        subjectId: biology,
        names: const <String>['باب', '   ', ''],
        at: kSeedInstant,
      );

      expect(created, 1);
      expect(
        (await repo.readSnapshot()).chaptersIn(biology).single.name,
        'باب',
      );
    });

    test('an empty template writes nothing and reports nothing', () async {
      expect(
        await repo.addChapters(
          subjectId: biology,
          names: const <String>[],
          at: kSeedInstant,
        ),
        0,
      );
      expect((await repo.readSnapshot()).chaptersIn(biology), isEmpty);
    });

    test('every seeded subject has a template, and no template is empty', () {
      for (final code in SubjectCode.values) {
        final template = CurriculumTemplates.chaptersFor(code);
        expect(template, isNotNull, reason: '${code.name} has no template');
        expect(template, isNotEmpty);
        expect(
          template!.toSet(),
          hasLength(template.length),
          reason: '${code.name} lists the same chapter twice',
        );
        for (final name in template) {
          expect(name.trim(), isNotEmpty);
        }
      }
    });

    test(
      'a template aimed at a subject that is not there writes nothing',
      () async {
        // The rollback itself is drift's `transaction()` guarantee and cannot be
        // forced from outside without a fake database. What is observable is the
        // outcome the guarantee exists for: a rejected apply leaves the
        // curriculum exactly as it was, with no half of a template in it.
        await expectLater(
          repo.addChapters(
            subjectId: 999,
            names: const <String>['أول', 'ثانٍ', 'ثالث'],
            at: kSeedInstant,
          ),
          throwsA(anything),
        );

        final snap = await repo.readSnapshot();
        expect(snap.chapters, isEmpty);
      },
    );

    test('a subject the student created has no template', () async {
      final id = await repo.createSubject(name: 'الجيولوجيا');
      final subject = (await repo.readSnapshot()).subjectById(id)!;

      expect(
        CurriculumTemplates.forSubject(subject),
        isNull,
        reason:
            'the app has never heard of this subject, so it has no '
            'standard structure to offer',
      );
    });
  });
}
