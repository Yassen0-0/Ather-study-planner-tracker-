import 'package:flutter_test/flutter_test.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/services/exam_eve_service.dart';

/// The exam-eve triage, over hand-built snapshots.
///
/// Pure by construction: the service reads a snapshot plus `now` and nothing
/// else, so the fixtures below assemble entities directly rather than going
/// through SQLite -- the database path is already covered by every other
/// snapshot consumer's tests.
void main() {
  final DateTime now = DateTime(2026, 6, 1);

  DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n, 15);

  Lesson lesson(int id, int chapterId, {DateTime? reviewed}) => Lesson(
    id: id,
    chapterId: chapterId,
    name: 'درس $id',
    createdAt: DateTime(2025, 1, 1),
    lastReviewedAt: reviewed,
  );

  ExamEntry examAt(int id, int lessonId, double percentage, DateTime at) =>
      ExamEntry(
        id: id,
        lessonId: lessonId,
        isReviewExam: false,
        totalPossiblePoints: 100,
        correctPoints: percentage.round(),
        percentage: percentage,
        createdAt: at,
      );

  StudySnapshot snap({
    List<Chapter> chapters = const <Chapter>[],
    List<Lesson> lessons = const <Lesson>[],
    List<ExamEntry> exams = const <ExamEntry>[],
  }) {
    return StudySnapshot(
      subjects: const <Subject>[
        Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
        Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
      ],
      chapters: chapters,
      lessons: lessons,
      exams: exams,
      homework: const <HomeworkEntry>[],
    );
  }

  test('every lesson lands in exactly one of the three tiers', () {
    final plan = ExamEveService.plan(
      snap(
        chapters: [
          Chapter(id: 10, subjectId: 1, name: 'أ', createdAt: now),
          Chapter(id: 11, subjectId: 1, name: 'ب', createdAt: now),
        ],
        lessons: [
          lesson(101, 10), // never examined
          lesson(102, 10, reviewed: daysAgo(1)), // weak
          lesson(103, 11, reviewed: daysAgo(10)), // weak
          lesson(104, 11, reviewed: daysAgo(28)), // proven, due soon
          lesson(105, 11, reviewed: daysAgo(35)), // proven, overdue
          lesson(106, 11, reviewed: daysAgo(3)), // proven, far from due
        ],
        exams: [
          examAt(1, 102, 40, daysAgo(1)),
          examAt(2, 103, 55, daysAgo(10)),
          examAt(3, 104, 80, daysAgo(28)),
          examAt(4, 105, 85, daysAgo(35)),
          examAt(5, 106, 90, daysAgo(3)),
        ],
      ),
      1,
      now,
    );

    final all = <int>[
      for (final e in plan.unsettled) e.lesson.id,
      for (final e in plan.weakest) e.lesson.id,
      for (final e in plan.nearestDue) e.lesson.id,
    ]..sort();
    expect(all, <int>[101, 102, 103, 104, 105, 106]);
  });

  test('tiers order: unexamined, weakest first, then most-urgent proof', () {
    final plan = ExamEveService.plan(
      snap(
        chapters: [
          Chapter(id: 10, subjectId: 1, name: 'أ', createdAt: now),
          Chapter(id: 11, subjectId: 1, name: 'ب', createdAt: now),
        ],
        lessons: [
          lesson(101, 10),
          lesson(102, 10, reviewed: daysAgo(1)),
          lesson(103, 11, reviewed: daysAgo(10)),
          lesson(104, 11, reviewed: daysAgo(28)),
          lesson(105, 11, reviewed: daysAgo(35)),
          lesson(106, 11, reviewed: daysAgo(3)),
        ],
        exams: [
          examAt(1, 102, 40, daysAgo(1)),
          examAt(2, 103, 55, daysAgo(10)),
          examAt(3, 104, 80, daysAgo(28)),
          examAt(4, 105, 85, daysAgo(35)),
          examAt(5, 106, 90, daysAgo(3)),
        ],
      ),
      1,
      now,
    );

    expect(
      [for (final e in plan.unsettled) e.lesson.id],
      <int>[101],
      reason: 'tier 1 holds only never-examined lessons',
    );

    expect(
      [for (final e in plan.weakest) e.lesson.id],
      <int>[102, 103],
      reason: 'tier 2 is examined-but-under-threshold, worst score on top',
    );
    expect(plan.weakest[0].mastery, lessThan(plan.weakest[1].mastery));

    expect(
      [for (final e in plan.nearestDue) e.lesson.id],
      <int>[105, 104, 106],
      reason:
          'already-overdue proof sorts ahead of any positive day count; '
          'then daysUntilDue ascending',
    );
  });

  test('urgency derives from the review clock, not a second calendar', () {
    final plan = ExamEveService.plan(
      snap(
        chapters: [Chapter(id: 10, subjectId: 1, name: 'أ', createdAt: now)],
        lessons: [
          lesson(104, 10, reviewed: daysAgo(28)),
          lesson(105, 10, reviewed: daysAgo(35)),
        ],
        exams: [
          examAt(3, 104, 80, daysAgo(28)),
          examAt(4, 105, 85, daysAgo(35)),
        ],
      ),
      1,
      now,
    );

    final overdue = plan.nearestDue[0];
    expect(overdue.daysOverdue, 5);
    expect(overdue.daysUntilDue, isNull);
    expect(overdue.urgency, -5);

    final near = plan.nearestDue[1];
    expect(near.daysOverdue, 0);
    expect(near.daysUntilDue, 2);
    expect(near.urgency, 2);
  });

  test('a lesson under another subject never reaches this plan', () {
    final plan = ExamEveService.plan(
      snap(
        chapters: [
          Chapter(id: 10, subjectId: 1, name: 'أ', createdAt: now),
          Chapter(id: 12, subjectId: 2, name: 'غريب', createdAt: now),
        ],
        lessons: [
          lesson(201, 12),
          lesson(202, 12, reviewed: daysAgo(40)),
        ],
        exams: [examAt(9, 202, 30, daysAgo(40))],
      ),
      1,
      now,
    );

    expect(plan.isEmpty, isTrue);
  });

  test('an empty tier is empty -- the sheet hides it', () {
    final plan = ExamEveService.plan(
      snap(
        chapters: [Chapter(id: 10, subjectId: 1, name: 'أ', createdAt: now)],
        lessons: [
          lesson(106, 10, reviewed: daysAgo(3)),
        ],
        exams: [examAt(5, 106, 90, daysAgo(3))],
      ),
      1,
      now,
    );

    expect(plan.unsettled, isEmpty);
    expect(plan.weakest, isEmpty);
    expect(plan.nearestDue, hasLength(1));
    expect(plan.isEmpty, isFalse);
  });
}
