import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/services/insights_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regressions found reviewing the two sessions before the 1.8.0 release.
///
/// Each of these passed the suite it shipped with. They are here because the
/// tests that were supposed to cover them asserted something weaker than the
/// promise the feature makes to a student.
void main() {
  final DateTime january = DateTime(2026, 1, 10);
  final DateTime june = DateTime(2026, 6, 10);

  Lesson lessonAt(int id, int chapterId, DateTime createdAt) => Lesson(
    id: id,
    chapterId: chapterId,
    name: 'درس $id',
    createdAt: createdAt,
    checklist: const LessonChecklist(
      watchedLesson: false,
      readNotes: false,
      didHomework: false,
      didExam: false,
      reviewedNotes: false,
    ),
  );

  ExamEntry examAt(int id, int lessonId, DateTime at, double percentage) =>
      ExamEntry(
        id: id,
        lessonId: lessonId,
        isReviewExam: false,
        totalPossiblePoints: 10,
        correctPoints: (percentage / 10).round(),
        percentage: percentage,
        createdAt: at,
        groups: const <ExamQuestionGroup>[],
      );

  group('a trajectory reading matches what the student saw that day', () {
    /// One chapter. One lesson in January, ten by June, 80% on every exam.
    StudySnapshot growingSubject() {
      final lessons = <Lesson>[lessonAt(1, 1, january)];
      final exams = <ExamEntry>[examAt(1, 1, january, 80)];
      for (var i = 2; i <= 10; i++) {
        // Created in May, months after the January reading.
        lessons.add(lessonAt(i, 1, DateTime(2026, 5, 1)));
        exams.add(examAt(i, i, DateTime(2026, 5, 2), 80));
      }
      return StudySnapshot(
        subjects: const <Subject>[
          Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
        ],
        chapters: <Chapter>[
          Chapter(id: 1, subjectId: 1, name: 'الباب الأول', createdAt: january),
        ],
        lessons: lessons,
        exams: exams,
        homework: const <HomeworkEntry>[],
      );
    }

    test('lessons that did not exist yet are not counted as zeroes', () {
      // The bug: exams were filtered by date but the divisor was **today's**
      // lesson count, so the nine lessons created in May were scored 0 for
      // January. The January point came out (80 + 0x9) / 10 = 8%, and the
      // chart drew a climb from 8% to 80% for a student who had been flat at
      // 80% the whole time.
      final asOfJanuary = InsightsGenerator.subjectMasteryAsOf(
        growingSubject(),
        1,
        DateTime(2026, 1, 31),
      );

      expect(
        asOfJanuary,
        closeTo(80, 0.001),
        reason: 'the January reading must be the 80% the app showed in January',
      );
    });

    test('a flat student gets a flat line, not an invented climb', () {
      final snapshot = growingSubject();
      final first = InsightsGenerator.subjectMasteryAsOf(
        snapshot,
        1,
        DateTime(2026, 1, 31),
      );
      final last = InsightsGenerator.subjectMasteryAsOf(snapshot, 1, june);

      expect(last - first, closeTo(0, 0.001));
    });

    test('a chapter added later does not drag the earlier readings down', () {
      // Same failure one level up: the chapter divisor was also today's count.
      final snapshot = StudySnapshot(
        subjects: const <Subject>[
          Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
        ],
        chapters: <Chapter>[
          Chapter(id: 1, subjectId: 1, name: 'الأول', createdAt: january),
          Chapter(
            id: 2,
            subjectId: 1,
            name: 'الثاني',
            createdAt: DateTime(2026, 5, 1),
          ),
        ],
        lessons: <Lesson>[
          lessonAt(1, 1, january),
          lessonAt(2, 2, DateTime(2026, 5, 1)),
        ],
        exams: <ExamEntry>[
          examAt(1, 1, january, 90),
          examAt(2, 2, DateTime(2026, 5, 2), 90),
        ],
        homework: const <HomeworkEntry>[],
      );

      expect(
        InsightsGenerator.subjectMasteryAsOf(snapshot, 1, DateTime(2026, 1, 31)),
        closeTo(90, 0.001),
      );
    });

    test('a date before the subject existed reads as zero, not as a score', () {
      expect(
        InsightsGenerator.subjectMasteryAsOf(
          growingSubject(),
          1,
          DateTime(2025, 1, 1),
        ),
        0,
      );
    });
  });
}
