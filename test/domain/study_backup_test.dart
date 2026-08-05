import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';

/// The serialisation, on its own, with no network and no database.
///
/// This is the layer where a bug loses a student's entire record without ever
/// throwing: a dropped field, a date that comes back an hour off, an exam whose
/// groups lost their exam id. None of that is visible from the UI, so it is
/// tested here as pure data.
void main() {
  final DateTime t0 = DateTime.fromMillisecondsSinceEpoch(1754300000000);

  StudyBackup populated() => StudyBackup(
    chapters: <Chapter>[
      Chapter(
        id: 7,
        subjectId: 1,
        name: 'الباب الأول — الخلية',
        createdAt: t0,
        masteredAt: t0.add(const Duration(days: 3)),
      ),
      Chapter(id: 8, subjectId: 2, name: 'الحركة', createdAt: t0),
    ],
    lessons: <Lesson>[
      Lesson(
        id: 20,
        chapterId: 7,
        name: 'تركيب الخلية',
        createdAt: t0,
        lastReviewedAt: t0.add(const Duration(days: 1)),
        lastNotifiedAt: t0.add(const Duration(days: 2)),
        checklist: const LessonChecklist(
          watchedLesson: true,
          readNotes: false,
          didHomework: true,
          didExam: true,
          reviewedNotes: false,
        ),
      ),
    ],
    exams: <ExamEntry>[
      ExamEntry(
        id: 55,
        lessonId: 20,
        isReviewExam: true,
        totalPossiblePoints: 11,
        correctPoints: 8,
        percentage: 72.72727272727273,
        createdAt: t0,
        groups: const <ExamQuestionGroup>[
          ExamQuestionGroup(
            id: 90,
            examId: 55,
            pointsPerQuestion: 1,
            questionCount: 5,
            correctCount: 4,
          ),
          ExamQuestionGroup(
            id: 91,
            examId: 55,
            pointsPerQuestion: 2,
            questionCount: 3,
            correctCount: 2,
          ),
        ],
      ),
    ],
    homework: <HomeworkEntry>[
      HomeworkEntry(id: 3, lessonId: 20, score: 9, maxScore: 10, createdAt: t0),
    ],
    tasks: <DailyTask>[
      DailyTask(
        id: 2,
        day: dayOf(t0),
        title: 'أذاكر',
        done: true,
        sortOrder: 0,
        createdAt: t0,
      ),
    ],
  );

  /// Through real JSON text, not just the map: that is what actually crosses the
  /// wire, and it is where a type that only survives in memory would be lost.
  StudyBackup roundTrip(StudyBackup backup) => StudyBackup.fromJson(
    jsonDecode(jsonEncode(backup.toJson())) as Map<String, Object?>,
  );

  test('a populated backup survives a round trip intact', () {
    final out = roundTrip(populated());

    expect(out.chapters, hasLength(2));
    expect(out.chapters.first.id, 7);
    expect(out.chapters.first.name, 'الباب الأول — الخلية');
    expect(out.chapters.first.masteredAt, t0.add(const Duration(days: 3)));
    // A chapter that was never mastered must come back null, not epoch zero.
    expect(out.chapters.last.masteredAt, isNull);

    final lesson = out.lessons.single;
    expect(lesson.chapterId, 7);
    expect(lesson.lastReviewedAt, t0.add(const Duration(days: 1)));
    expect(lesson.lastNotifiedAt, t0.add(const Duration(days: 2)));
    // Five separate booleans; a copy-paste in the map would silently align them.
    expect(lesson.checklist.watchedLesson, isTrue);
    expect(lesson.checklist.readNotes, isFalse);
    expect(lesson.checklist.didHomework, isTrue);
    expect(lesson.checklist.didExam, isTrue);
    expect(lesson.checklist.reviewedNotes, isFalse);

    final exam = out.exams.single;
    expect(exam.lessonId, 20);
    expect(exam.isReviewExam, isTrue);
    // Carried, never recomputed: a past score has to stay historically stable.
    expect(exam.percentage, closeTo(72.7272, 0.001));
    expect(exam.groups, hasLength(2));
    expect(exam.groups.first.correctCount, 4);
    // The groups' examId is derived on the way back in rather than stored twice.
    expect(exam.groups.every((g) => g.examId == 55), isTrue);

    expect(out.homework.single.score, 9);
    expect(out.tasks.single.title, 'أذاكر');
    expect(out.tasks.single.done, isTrue);
  });

  test('an empty backup round-trips to an empty backup', () {
    const empty = StudyBackup(
      chapters: <Chapter>[],
      lessons: <Lesson>[],
      exams: <ExamEntry>[],
      homework: <HomeworkEntry>[],
      tasks: <DailyTask>[],
    );

    final out = roundTrip(empty);
    expect(out.isEmpty, isTrue);
    expect(out.chapterCount, 0);
    expect(out.examCount, 0);
  });

  test('dates survive as exact instants', () {
    // Epoch milliseconds rather than an ISO string, so nothing here can shift by
    // a timezone when a student restores onto a phone set to another zone.
    final out = roundTrip(populated());
    expect(
      out.chapters.first.createdAt.millisecondsSinceEpoch,
      t0.millisecondsSinceEpoch,
    );
  });

  test('a backup from a newer app is refused, not half-read', () {
    final json = populated().toJson()..['formatVersion'] = 99;

    // The alternative -- reading the fields it recognises -- would restore a
    // partial record over a complete one, which is a silent deletion.
    expect(
      () => StudyBackup.fromJson(json),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('a backup with no version marker is refused', () {
    final json = populated().toJson()..remove('formatVersion');
    expect(
      () => StudyBackup.fromJson(json),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('counts report what the restore prompt shows the student', () {
    final backup = populated();
    expect(backup.chapterCount, 2);
    expect(backup.examCount, 1);
    expect(backup.isEmpty, isFalse);
  });
}
