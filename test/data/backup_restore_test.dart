import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/instants.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/data/repositories/drift_task_repository.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/subject.dart';

/// Restore, against real SQLite.
///
/// Restore is the most destructive operation in the app: it deletes a student's
/// entire record before writing the replacement. Two things therefore have to be
/// true and are asserted here rather than argued -- ids survive (they are what
/// every relationship is made of), and a failure leaves the original database
/// untouched.
void main() {
  late AppDatabase db;
  late DriftStudyRepository study;
  late DriftTaskRepository tasks;

  final DateTime t0 = DateTime.fromMillisecondsSinceEpoch(1754300000000);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    study = DriftStudyRepository(db);
    tasks = DriftTaskRepository(db);
  });

  tearDown(() => db.close());

  StudyBackup backup({int chapterId = 7, int lessonId = 20}) => StudyBackup(
    subjects: const <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
      Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
      Subject.seeded(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
      Subject.seeded(id: 4, code: SubjectCode.english, sortOrder: 3),
      Subject(
        id: 5,
        code: null,
        name: 'رياضيات',
        sortOrder: 4,
        archivedAt: null,
      ),
    ],
    chapters: <Chapter>[
      Chapter(
        id: chapterId,
        subjectId: 1,
        name: 'الباب الأول',
        createdAt: t0,
        masteredAt: t0,
      ),
    ],
    lessons: <Lesson>[
      Lesson(
        id: lessonId,
        chapterId: chapterId,
        name: 'درس',
        createdAt: t0,
        lastReviewedAt: t0,
        checklist: const LessonChecklist(
          watchedLesson: true,
          readNotes: true,
          didHomework: false,
          didExam: true,
          reviewedNotes: false,
        ),
      ),
    ],
    exams: <ExamEntry>[
      ExamEntry(
        id: 55,
        lessonId: lessonId,
        isReviewExam: false,
        totalPossiblePoints: 10,
        correctPoints: 7,
        percentage: 70,
        createdAt: t0,
        groups: const <ExamQuestionGroup>[
          ExamQuestionGroup(
            id: 90,
            examId: 55,
            pointsPerQuestion: 1,
            questionCount: 10,
            correctCount: 7,
          ),
        ],
      ),
    ],
    homework: <HomeworkEntry>[
      HomeworkEntry(
        id: 3,
        lessonId: lessonId,
        score: 8,
        maxScore: 10,
        createdAt: t0,
      ),
    ],
    tasks: <DailyTask>[
      DailyTask(
        id: 4,
        day: dayOf(t0),
        title: 'مهمة',
        done: false,
        surrendered: true,
        sortOrder: 0,
        createdAt: t0,
      ),
    ],
  );

  test('restore preserves ids, so relationships survive', () async {
    await study.restore(backup());
    await tasks.restoreTasks(backup().tasks);

    final snapshot = await study.readSnapshot();

    // The ids themselves, not just the counts: autoincrement would happily
    // renumber these and reattach the exam to a lesson that never sat it.
    expect(snapshot.chapters.single.id, 7);
    expect(snapshot.lessons.single.id, 20);
    expect(snapshot.lessons.single.chapterId, 7);

    final exam = snapshot.examsFor(20).single;
    expect(exam.id, 55);
    expect(exam.groups.single.examId, 55);
    expect(exam.percentage, 70);
    expect(snapshot.homeworkFor(20).single.score, 8);

    // The surrender state is part of the record a restore owes back: a
    // restored task comes out exactly as the backup carried it in.
    final restoredTask = await tasks.watchTasks().first;
    expect(restoredTask.single.id, 4);
    expect(restoredTask.single.surrendered, isTrue);
    expect(restoredTask.single.done, isFalse);
  });

  test('restore replaces rather than merges', () async {
    await study.createChapter(subjectId: 1, name: 'باب قديم', at: kSeedInstant);
    expect((await study.readSnapshot()).chapters, hasLength(1));

    await study.restore(backup());

    final snapshot = await study.readSnapshot();
    expect(snapshot.chapters, hasLength(1));
    expect(snapshot.chapters.single.name, 'الباب الأول');
  });

  test('a restore brings the subjects the student added with it', () async {
    await study.restore(backup());
    final snapshot = await study.readSnapshot();

    // The whole reason subjects joined the backup format. Every chapter names
    // a subjectId; a restore onto a new phone that did not carry the subjects
    // would land chapters pointing at rows that do not exist.
    expect(snapshot.subjects, hasLength(5));
    expect(snapshot.subjectById(5)!.name, 'رياضيات');
    expect(snapshot.subjectById(5)!.isSeeded, isFalse);
  });

  test('a version 1 backup leaves the seeded four alone', () async {
    // Written before subjects were carried. Wiping the seeded four on its
    // behalf would leave every chapter it is about to insert pointing at
    // nothing, so an empty subject list means "do not touch them".
    await study.restore(
      StudyBackup(
        subjects: const <Subject>[],
        chapters: backup().chapters,
        lessons: backup().lessons,
        exams: const <ExamEntry>[],
        homework: const <HomeworkEntry>[],
        tasks: const <DailyTask>[],
      ),
    );

    final snapshot = await study.readSnapshot();
    expect(snapshot.subjects, hasLength(4));
    expect(snapshot.chapters, hasLength(1));
  });

  test('a restore that fails part-way leaves the database untouched', () async {
    final chapterId = await study.createChapter(
      subjectId: 1,
      name: 'شغل الطالب',
      at: kSeedInstant,
    );
    await study.createLesson(
      chapterId: chapterId,
      name: 'درس مهم',
      at: kSeedInstant,
    );

    // A lesson pointing at a chapter that is not in the backup: the foreign key
    // rejects it, part-way through the insert batch and after the delete.
    final broken = StudyBackup(
    subjects: const <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    ],
      chapters: backup().chapters,
      lessons: <Lesson>[
        Lesson(
          id: 21,
          chapterId: 999,
          name: 'يتيم',
          createdAt: t0,
          checklist: const LessonChecklist(
            watchedLesson: false,
            readNotes: false,
            didHomework: false,
            didExam: false,
            reviewedNotes: false,
          ),
        ),
      ],
      exams: const <ExamEntry>[],
      homework: const <HomeworkEntry>[],
      tasks: const <DailyTask>[],
    );

    await expectLater(study.restore(broken), throwsA(anything));

    // The claim the transaction exists for: the student still has everything
    // they had before they pressed the button.
    final snapshot = await study.readSnapshot();
    expect(snapshot.chapters, hasLength(1));
    expect(snapshot.chapters.single.name, 'شغل الطالب');
    expect(snapshot.lessons, hasLength(1));
    expect(snapshot.lessons.single.name, 'درس مهم');
  });

  test('restoring an empty backup empties the record', () async {
    await study.restore(backup());
    expect((await study.readSnapshot()).chapters, hasLength(1));

    await study.restore(
      const StudyBackup(
        subjects: <Subject>[
          Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
          Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
          Subject.seeded(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
          Subject.seeded(id: 4, code: SubjectCode.english, sortOrder: 3),
        ],
        chapters: <Chapter>[],
        lessons: <Lesson>[],
        exams: <ExamEntry>[],
        homework: <HomeworkEntry>[],
        tasks: <DailyTask>[],
      ),
    );

    final snapshot = await study.readSnapshot();
    expect(snapshot.chapters, isEmpty);
    expect(snapshot.lessons, isEmpty);
    // The subject the student added is gone with the rest: an empty record is
    // an empty record, and the four seeded ones came back with the backup.
    expect(snapshot.subjects, hasLength(4));
  });

  group('restoring a version 1 file keeps what no backup owns', () {
    // A version 1 file carries no subjects, so its chapters can only describe
    // the four seeded ones. A subject the student added themselves -- and its
    // whole subtree -- exists nowhere in that file; deleting it as part of
    // "restoring" destroyed data the restore was never given a replacement for.
    Future<int> addCustomWorld() async {
      final subjectId = await study.createSubject(name: 'فلسفة');
      final chapterId = await study.createChapter(
        subjectId: subjectId,
        name: 'المنطق',
        at: kSeedInstant,
      );
      final lessonId = await study.createLesson(
        chapterId: chapterId,
        name: 'المقدمات',
        at: kSeedInstant,
      );
      await study.recordExam(
        lessonId: lessonId,
        groups: const <DraftQuestionGroup>[
          DraftQuestionGroup(
            pointsPerQuestion: 1,
            questionCount: 10,
            correctCount: 8,
          ),
        ],
        isReviewExam: false,
        at: t0,
      );
      await study.recordHomework(
        lessonId: lessonId,
        score: 9,
        maxScore: 10,
        at: t0,
      );
      return chapterId;
    }

    StudyBackup v1({required int chapterId}) => StudyBackup(
      subjects: const <Subject>[],
      chapters: <Chapter>[
        Chapter(
          id: chapterId,
          subjectId: 1,
          name: 'الباب الأول',
          createdAt: t0,
        ),
      ],
      lessons: <Lesson>[
        Lesson(
          id: 20,
          chapterId: chapterId,
          name: 'درس',
          createdAt: t0,
          checklist: const LessonChecklist(),
        ),
      ],
      exams: const <ExamEntry>[],
      homework: const <HomeworkEntry>[],
      tasks: const <DailyTask>[],
    );

    test('the custom subject\'s chapters survive the restore', () async {
      final customChapter = await addCustomWorld();

      await study.restore(v1(chapterId: customChapter + 100));

      final snapshot = await study.readSnapshot();
      expect(snapshot.subjects.map((s) => s.name), contains('فلسفة'));
      expect(snapshot.chapters.map((c) => c.name), contains('المنطق'));

      final kept = snapshot.chapters.singleWhere((c) => c.name == 'المنطق');
      final lessons = snapshot.lessonsIn(kept.id);
      expect(lessons, hasLength(1));
      // And the evidence under it, not just the shell: an exam and a homework
      // score are the parts of a record that took evenings to make.
      expect(snapshot.examsFor(lessons.single.id), hasLength(1));
      expect(snapshot.examsFor(lessons.single.id).single.percentage, 80);
      expect(snapshot.homeworkFor(lessons.single.id), hasLength(1));
    });

    test('an id collision with the backup does not fail the restore', () async {
      // The first chapter on this device takes id 1 -- the same id the incoming
      // backup uses below. Keeping the preserved rows' old ids would collide on
      // the primary key and roll the whole transaction back.
      final customChapter = await addCustomWorld();
      expect(customChapter, 1);

      await study.restore(v1(chapterId: customChapter));

      final snapshot = await study.readSnapshot();
      // Both worlds landed: the backup's chapter and the student's own.
      expect(snapshot.chapters.map((c) => c.name), containsAll(<String>[
        'الباب الأول',
        'المنطق',
      ]));
      // The backup lesson still hangs off the backup chapter it came with.
      expect(
        snapshot.lessonById(20)!.chapterId,
        snapshot.chapters.singleWhere((c) => c.name == 'الباب الأول').id,
      );
      // And the preserved lesson followed its chapter to its new id rather
      // than being orphaned by the remap.
      final kept = snapshot.chapters.singleWhere((c) => c.name == 'المنطق');
      expect(kept.id, isNot(customChapter));
      expect(snapshot.lessonsIn(kept.id), hasLength(1));
      expect(
        snapshot.examsFor(snapshot.lessonsIn(kept.id).single.id),
        hasLength(1),
      );
    });
  });
}
