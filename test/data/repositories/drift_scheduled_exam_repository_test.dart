// package:drift/drift.dart is deliberately NOT imported here: it exports SQL
// expression builders also called isNull / isNotNull, which shadow matcher's
// and break every null assertion in this file.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/instants.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_scheduled_exam_repository.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/scheduled_exam.dart';

void main() {
  late AppDatabase db;
  late DriftScheduledExamRepository repo;
  late DriftStudyRepository studyRepo;

  setUp(() {
    // A real SQLite engine in memory -- cascades and PRAGMAs behave exactly as
    // they will on device, which a mocked repository would not prove.
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftScheduledExamRepository(db);
    studyRepo = DriftStudyRepository(db);
  });

  tearDown(() async => db.close());

  group('createScheduledExam', () {
    test('creates a scheduled exam with chapter associations', () async {
      final chapterId1 = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 1',
        at: kSeedInstant,
      );
      final chapterId2 = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 2',
        at: kSeedInstant,
      );

      final examDate = DateTime(2026, 6, 15);
      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: examDate,
        title: 'Midterm Exam',
        chapterIds: [chapterId1, chapterId2],
        notes: 'Covers units 1-2',
        at: kSeedInstant,
      );

      final exams = await repo.readScheduledExams();
      expect(exams, hasLength(1));

      final exam = exams.single;
      expect(exam.id, id);
      expect(exam.subjectId, 1);
      expect(exam.date, examDate);
      expect(exam.title, 'Midterm Exam');
      expect(exam.chapterIds, unorderedEquals([chapterId1, chapterId2]));
      expect(exam.notes, 'Covers units 1-2');
      expect(exam.createdAt, kSeedInstant);
    });

    test('trims title and notes', () async {
      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: '  Final Exam  ',
        chapterIds: [],
        notes: '  Important exam  ',
        at: kSeedInstant,
      );

      final exam = (await repo.readScheduledExams()).single;
      expect(exam.title, 'Final Exam');
      expect(exam.notes, 'Important exam');
    });

    test('handles empty chapter associations', () async {
      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'General Exam',
        chapterIds: [],
        notes: null,
        at: kSeedInstant,
      );

      final exam = (await repo.readScheduledExams()).single;
      expect(exam.chapterIds, isEmpty);
      expect(exam.notes, isNull);
    });
  });

  group('updateScheduledExam', () {
    test('updates exam details and chapter associations', () async {
      final chapterId1 = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 1',
        at: kSeedInstant,
      );
      final chapterId2 = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 2',
        at: kSeedInstant,
      );
      final chapterId3 = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 3',
        at: kSeedInstant,
      );

      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Original Title',
        chapterIds: [chapterId1],
        notes: 'Original notes',
        at: kSeedInstant,
      );

      await repo.updateScheduledExam(
        id: id,
        subjectId: 1,
        date: DateTime(2026, 6, 20),
        title: 'Updated Title',
        chapterIds: [chapterId2, chapterId3],
        notes: 'Updated notes',
      );

      final exam = (await repo.readScheduledExams()).single;
      expect(exam.date, DateTime(2026, 6, 20));
      expect(exam.title, 'Updated Title');
      expect(exam.chapterIds, unorderedEquals([chapterId2, chapterId3]));
      expect(exam.notes, 'Updated notes');
    });

    test('can clear chapter associations', () async {
      final chapterId = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 1',
        at: kSeedInstant,
      );

      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Exam',
        chapterIds: [chapterId],
        at: kSeedInstant,
      );

      await repo.updateScheduledExam(
        id: id,
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Exam',
        chapterIds: [],
        notes: null,
      );

      final exam = (await repo.readScheduledExams()).single;
      expect(exam.chapterIds, isEmpty);
    });

    test('trims title and notes on update', () async {
      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Original',
        chapterIds: [],
        at: kSeedInstant,
      );

      await repo.updateScheduledExam(
        id: id,
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: '  Updated  ',
        chapterIds: [],
        notes: '  Note  ',
      );

      final exam = (await repo.readScheduledExams()).single;
      expect(exam.title, 'Updated');
      expect(exam.notes, 'Note');
    });
  });

  group('deleteScheduledExam', () {
    test('removes the exam and its chapter associations', () async {
      final chapterId = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 1',
        at: kSeedInstant,
      );

      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Exam',
        chapterIds: [chapterId],
        at: kSeedInstant,
      );

      expect(await repo.readScheduledExams(), hasLength(1));

      // Verify chapter associations exist
      final chapterAssociations = await db.select(db.scheduledExamChapters).get();
      expect(chapterAssociations, hasLength(1));

      await repo.deleteScheduledExam(id);

      expect(await repo.readScheduledExams(), isEmpty);

      // Verify chapter associations are cascade deleted
      final remainingAssociations = await db.select(db.scheduledExamChapters).get();
      expect(remainingAssociations, isEmpty);
    });
  });

  group('cascade deletes', () {
    test('deleting a subject removes its scheduled exams', () async {
      final chapterId = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 1',
        at: kSeedInstant,
      );

      await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Exam 1',
        chapterIds: [chapterId],
        at: kSeedInstant,
      );

      expect(await repo.readScheduledExams(), hasLength(1));

      await studyRepo.purgeSubject(1);

      expect(await repo.readScheduledExams(), isEmpty);
    });

    test('deleting a chapter removes it from exam associations', () async {
      final chapterId1 = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 1',
        at: kSeedInstant,
      );
      final chapterId2 = await studyRepo.createChapter(
        subjectId: 1,
        name: 'Chapter 2',
        at: kSeedInstant,
      );

      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Exam',
        chapterIds: [chapterId1, chapterId2],
        at: kSeedInstant,
      );

      await studyRepo.deleteChapter(chapterId1);

      final exam = (await repo.readScheduledExams()).single;
      expect(exam.chapterIds, [chapterId2]);
    });
  });

  group('readScheduledExams and watchScheduledExams', () {
    test('returns exams sorted by date', () async {
      await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 8, 1),
        title: 'Later Exam',
        chapterIds: [],
        at: kSeedInstant,
      );

      await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 1),
        title: 'Earlier Exam',
        chapterIds: [],
        at: kSeedInstant.add(Duration(seconds: 1)),
      );

      await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 7, 1),
        title: 'Middle Exam',
        chapterIds: [],
        at: kSeedInstant.add(Duration(seconds: 2)),
      );

      final exams = await repo.readScheduledExams();
      expect(exams.map((e) => e.title), [
        'Earlier Exam',
        'Middle Exam',
        'Later Exam',
      ]);
    });

    test('watchScheduledExams emits on create', () async {
      final stream = repo.watchScheduledExams();

      // First emission should be empty
      expect(await stream.first, isEmpty);

      // Create an exam and expect the stream to emit
      await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'New Exam',
        chapterIds: [],
        at: kSeedInstant,
      );

      final exams = await stream.first;
      expect(exams, hasLength(1));
      expect(exams.single.title, 'New Exam');
    });

    test('watchScheduledExams emits on update', () async {
      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Original',
        chapterIds: [],
        at: kSeedInstant,
      );

      final stream = repo.watchScheduledExams();

      // Skip initial emission
      await stream.first;

      await repo.updateScheduledExam(
        id: id,
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Updated',
        chapterIds: [],
        notes: null,
      );

      final exams = await stream.first;
      expect(exams.single.title, 'Updated');
    });

    test('watchScheduledExams emits on delete', () async {
      final id = await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Exam',
        chapterIds: [],
        at: kSeedInstant,
      );

      final stream = repo.watchScheduledExams();

      // Skip initial emission
      await stream.first;

      await repo.deleteScheduledExam(id);

      final exams = await stream.first;
      expect(exams, isEmpty);
    });

    test('handles multiple exams across different subjects', () async {
      await repo.createScheduledExam(
        subjectId: 1,
        date: DateTime(2026, 6, 15),
        title: 'Biology Exam',
        chapterIds: [],
        at: kSeedInstant,
      );

      await repo.createScheduledExam(
        subjectId: 2,
        date: DateTime(2026, 6, 16),
        title: 'Physics Exam',
        chapterIds: [],
        at: kSeedInstant,
      );

      final exams = await repo.readScheduledExams();
      expect(exams, hasLength(2));
      expect(exams.map((e) => e.subjectId), unorderedEquals([1, 2]));
    });
  });
}
