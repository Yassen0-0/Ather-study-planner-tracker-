import 'package:flutter_test/flutter_test.dart';

import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/scheduled_exam.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';

void main() {
  group('StudySnapshot', () {
    test('empty snapshot has no scheduled exams', () {
      const snapshot = StudySnapshot.empty();

      expect(snapshot.scheduledExams, isEmpty);
      expect(snapshot.subjects, isEmpty);
      expect(snapshot.chapters, isEmpty);
      expect(snapshot.lessons, isEmpty);
      expect(snapshot.exams, isEmpty);
      expect(snapshot.homework, isEmpty);
    });

    test('snapshot includes scheduled exams', () {
      const subject = Subject.seeded(
        id: 1,
        code: SubjectCode.biology,
        sortOrder: 0,
      );

      final chapter = Chapter(
        id: 1,
        subjectId: 1,
        name: 'Chapter 1',
        createdAt: DateTime(2026, 1, 1),
      );

      final scheduledExam = ScheduledExam(
        id: 1,
        subjectId: 1,
        date: DateTime(2026, 2, 1),
        title: 'Midterm Exam',
        chapterIds: const <int>[1],
        createdAt: DateTime(2026, 1, 15),
        notes: 'Covers chapters 1-3',
      );

      final snapshot = StudySnapshot(
        subjects: <Subject>[subject],
        chapters: <Chapter>[chapter],
        lessons: const <Lesson>[],
        exams: const <ExamEntry>[],
        homework: const <HomeworkEntry>[],
        scheduledExams: <ScheduledExam>[scheduledExam],
      );

      expect(snapshot.scheduledExams, hasLength(1));
      expect(snapshot.scheduledExams.first.id, 1);
      expect(snapshot.scheduledExams.first.title, 'Midterm Exam');
      expect(snapshot.scheduledExams.first.subjectId, 1);
      expect(snapshot.scheduledExams.first.chapterIds, <int>[1]);
    });

    test('snapshot scheduled exams are sorted by date', () {
      final exam1 = ScheduledExam(
        id: 1,
        subjectId: 1,
        date: DateTime(2026, 3, 1),
        title: 'Final',
        chapterIds: const <int>[],
        createdAt: DateTime(2026, 1, 1),
      );

      final exam2 = ScheduledExam(
        id: 2,
        subjectId: 1,
        date: DateTime(2026, 2, 1),
        title: 'Midterm',
        chapterIds: const <int>[],
        createdAt: DateTime(2026, 1, 2),
      );

      final snapshot = StudySnapshot(
        subjects: const <Subject>[],
        chapters: const <Chapter>[],
        lessons: const <Lesson>[],
        exams: const <ExamEntry>[],
        homework: const <HomeworkEntry>[],
        scheduledExams: <ScheduledExam>[exam1, exam2],
      );

      // Even though exam1 is added first, the snapshot should sort by date
      expect(snapshot.scheduledExams, hasLength(2));
      expect(snapshot.scheduledExams.first.title, 'Midterm');
      expect(snapshot.scheduledExams.last.title, 'Final');
    });
  });
}
