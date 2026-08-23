import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// The capture-only study event log, end to end.
///
/// Schema version 4 exists for exactly one promise: from the day it ships,
/// "what did this student do?" starts having an answer. These tests hold the
/// three sides of that promise against real SQLite -- every checklist tick
/// lands one row, every task flip lands one row, and the rows a student has
/// accumulated survive the only things that ever move them: a backup
/// round-trip and a restore.
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

  Future<int> lessonWithChecklist() async {
    final chapterId = await study.createChapter(
      subjectId: 1,
      name: 'الباب الأول',
      at: t0,
    );
    return study.createLesson(
      chapterId: chapterId,
      name: 'تركيب الخلية',
      at: t0,
    );
  }

  Future<List<StudyEventRow>> events() => db.select(db.studyEvents).get();

  group('checklist capture', () {
    test('one tick produces exactly one event row', () async {
      final lessonId = await lessonWithChecklist();

      await study.updateChecklist(
        lessonId: lessonId,
        checklist: const LessonChecklist(watchedLesson: true),
        at: DateTime(2026, 8, 20, 10),
      );

      final rows = await events();
      expect(rows, hasLength(1));
      expect(rows.single.type, 'checklist');
      expect(rows.single.refId, lessonId);
      expect(rows.single.at, DateTime(2026, 8, 20, 10));

      // And the flag itself moved with it.
      final lesson = await (db.select(db.lessons)
            ..where((t) => t.id.equals(lessonId)))
          .getSingle();
      expect(lesson.watchedLesson, isTrue);
    });

    test('each changed step of one save gets its own row', () async {
      // The screen sends the whole checklist per tap and one step differs,
      // but nothing stops a caller from moving several at once -- each is a
      // separate thing that happened, so each is its own row.
      final lessonId = await lessonWithChecklist();

      await study.updateChecklist(
        lessonId: lessonId,
        checklist: const LessonChecklist(
          watchedLesson: true,
          readNotes: true,
          reviewedNotes: true,
        ),
        at: t0,
      );

      expect(await events(), hasLength(3));
    });

    test('an identical rewrite records nothing', () async {
      // History remembers changes, not attempts. A write that leaves all five
      // flags where they were did not happen as far as the record cares.
      final lessonId = await lessonWithChecklist();

      await study.updateChecklist(
        lessonId: lessonId,
        checklist: const LessonChecklist(watchedLesson: true),
        at: t0,
      );
      await study.updateChecklist(
        lessonId: lessonId,
        checklist: const LessonChecklist(watchedLesson: true),
        at: t0,
      );

      expect(await events(), hasLength(1));
    });

    test('unticking is captured too', () async {
      final lessonId = await lessonWithChecklist();

      await study.updateChecklist(
        lessonId: lessonId,
        checklist: const LessonChecklist(didExam: true),
        at: t0,
      );
      await study.updateChecklist(
        lessonId: lessonId,
        checklist: const LessonChecklist(),
        at: t0,
      );

      expect(await events(), hasLength(2));
    });

    test('a tick on a missing lesson neither crashes nor records', () async {
      await study.updateChecklist(
        lessonId: 999,
        checklist: const LessonChecklist(watchedLesson: true),
        at: t0,
      );

      expect(await events(), isEmpty);
    });
  });

  group('task capture', () {
    test('flipping done produces one event; flipping back another', () async {
      final taskId = await db
          .into(db.dailyTasks)
          .insert(
            DailyTasksCompanion.insert(
              day: DateTime(2026, 8, 5),
              title: 'أذاكر',
              sortOrder: 0,
              createdAt: t0,
            ),
          );

      await tasks.setTaskDone(taskId: taskId, done: true);
      final first = await events();
      expect(first, hasLength(1));
      expect(first.single.type, 'task_done');
      expect(first.single.refId, taskId);

      await tasks.setTaskDone(taskId: taskId, done: false);
      final both = await events();
      expect(both, hasLength(2));
      expect(both.every((e) => e.type == 'task_done'), isTrue);
    });

    test('a no-op flip writes nothing', () async {
      final taskId = await db
          .into(db.dailyTasks)
          .insert(
            DailyTasksCompanion.insert(
              day: DateTime(2026, 8, 5),
              title: 'أذاكر',
              sortOrder: 0,
              createdAt: t0,
            ),
          );

      await tasks.setTaskDone(taskId: taskId, done: false);

      expect(await events(), isEmpty);
    });

    test('a flip on a missing task neither crashes nor records', () async {
      await tasks.setTaskDone(taskId: 999, done: true);
      expect(await events(), isEmpty);
    });
  });

  group('backup round-trip', () {
    StudyBackup backupWithEvents() => StudyBackup(
      subjects: const <Subject>[
        Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
      ],
      chapters: <Chapter>[
        Chapter(id: 7, subjectId: 1, name: 'الباب الأول', createdAt: t0),
      ],
      lessons: <Lesson>[
        Lesson(
          id: 20,
          chapterId: 7,
          name: 'تركيب الخلية',
          createdAt: t0,
          checklist: const LessonChecklist(watchedLesson: true),
        ),
      ],
      exams: const <ExamEntry>[],
      homework: const <HomeworkEntry>[],
      tasks: const <DailyTask>[],
      events: <StudyEvent>[
        StudyEvent(
          id: 1,
          type: StudyEvent.typeChecklist,
          refId: 20,
          at: t0,
        ),
        StudyEvent(
          id: 2,
          type: StudyEvent.typeTaskDone,
          refId: 4,
          at: t0,
        ),
        StudyEvent(
          id: 9,
          type: StudyEvent.typeChecklist,
          refId: 21,
          at: t0,
        ),
      ],
    );

    test('a version 5 blob carries events out and back intact', () async {
      // Through real JSON, not just the map: this is the Firestore shape.
      final json = jsonDecode(jsonEncode(backupWithEvents().toJson()))
          as Map<String, Object?>;
      expect(json['formatVersion'], 5);

      final parsed = StudyBackup.fromJson(json);
      expect(parsed.events, hasLength(3));
      expect(parsed.events.map((e) => e.type), <String>[
        StudyEvent.typeChecklist,
        StudyEvent.typeTaskDone,
        StudyEvent.typeChecklist,
      ]);
      expect(parsed.events.map((e) => e.refId), <int>[20, 4, 21]);
      expect(parsed.events.every((e) => e.at == t0), isTrue);

      await study.restore(parsed);

      final rows = await events();
      expect(rows, hasLength(3));
      // Ids are re-allocated above the file's highest id (9), in file order --
      // nothing references an event id, so renumbering is free; determinism
      // is what the assertion buys.
      expect(rows.map((r) => r.id), <int>[10, 11, 12]);
      expect(rows.map((r) => r.type), parsed.events.map((e) => e.type));
      expect(rows.map((r) => r.refId), parsed.events.map((e) => e.refId));
    });

    test('restore replaces rather than merges', () async {
      // A pre-existing local history does not survive into the restored world:
      // restore means "the cloud copy is the record".
      await study.restore(backupWithEvents());
      expect(await events(), hasLength(3));

      await study.restore(backupWithEvents());
      expect(await events(), hasLength(3));
    });

    test('a blob written before format 4 parses with no events', () async {
      // Every blob actually sitting in the cloud right now lacks the key.
      // Tolerant in exactly that direction: absence reads as "nothing had
      // been captured yet", not corruption.
      final legacy = Map<String, Object?>.from(
        jsonDecode(jsonEncode(backupWithEvents().toJson()))
            as Map<String, Object?>,
      )..['formatVersion'] = 3..remove('events');

      final parsed = StudyBackup.fromJson(legacy);
      expect(parsed.events, isEmpty);

      await study.restore(parsed);
      expect(await events(), isEmpty);
    });

    test('account deletion empties the log with everything else', () async {
      await study.restore(backupWithEvents());
      expect(await events(), hasLength(3));

      await study.clear();

      expect(await events(), isEmpty);
    });
  });
}
