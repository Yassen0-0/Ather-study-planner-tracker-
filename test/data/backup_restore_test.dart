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

    expect((await tasks.watchTasks().first).single.id, 4);
  });

  test('restore replaces rather than merges', () async {
    await study.createChapter(subjectId: 1, name: 'باب قديم', at: kSeedInstant);
    expect((await study.readSnapshot()).chapters, hasLength(1));

    await study.restore(backup());

    final snapshot = await study.readSnapshot();
    expect(snapshot.chapters, hasLength(1));
    expect(snapshot.chapters.single.name, 'الباب الأول');
  });

  test('the four seeded subjects are left alone', () async {
    await study.restore(backup());
    // A backup carries no subjects, so a restore that cleared them would leave
    // the app with four missing rows every chapter points at.
    expect((await study.readSnapshot()).subjects, hasLength(4));
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
    expect(snapshot.subjects, hasLength(4));
  });
}
