import 'dart:convert';

import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/services/data_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The export, as text.
///
/// Everything worth testing about an export is in the bytes: the file layer is
/// two `path_provider` calls and a share sheet, and neither exists in a unit
/// test. What can go wrong here and never throw is the payload -- a field the
/// encoder drops, a version marker that is not written, an empty database that
/// serialises to something no parser will take back.
void main() {
  final DateTime t0 = DateTime.fromMillisecondsSinceEpoch(1754300000000);
  const service = DataExportService();

  StudyBackup populated() => StudyBackup(
    subjects: const <Subject>[
      Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    ],
    chapters: <Chapter>[
      Chapter(
        id: 7,
        subjectId: 1,
        name: 'الباب الأول — الخلية',
        createdAt: t0,
        masteredAt: t0.add(const Duration(days: 3)),
      ),
    ],
    lessons: <Lesson>[
      Lesson(
        id: 20,
        chapterId: 7,
        name: 'تركيب الخلية',
        createdAt: t0,
        lastReviewedAt: t0.add(const Duration(days: 1)),
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
        isReviewExam: false,
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
        ],
      ),
    ],
    homework: <HomeworkEntry>[
      HomeworkEntry(id: 3, lessonId: 20, score: 9, maxScore: 10, createdAt: t0),
    ],
    tasks: <DailyTask>[
      DailyTask(
        id: 2,
        day: DateTime(2025, 8, 4),
        title: 'أذاكر',
        done: true,
        sortOrder: 0,
        createdAt: t0,
      ),
    ],
  );

  const empty = StudyBackup(
    subjects: <Subject>[],
    chapters: <Chapter>[],
    lessons: <Lesson>[],
    exams: <ExamEntry>[],
    homework: <HomeworkEntry>[],
    tasks: <DailyTask>[],
  );

  /// Parses the exported text back the way anything reading the file would --
  /// through `jsonDecode` and [StudyBackup.fromJson], not through the map the
  /// encoder happened to hold in memory.
  StudyBackup reread(String text) =>
      StudyBackup.fromJson(jsonDecode(text) as Map<String, Object?>);

  test('an exported file parses back to the record it came from', () {
    final out = reread(service.encode(populated()));

    expect(out.subjects.single.id, 1);
    expect(out.chapters.single.name, 'الباب الأول — الخلية');
    expect(out.chapters.single.masteredAt, t0.add(const Duration(days: 3)));
    expect(out.lessons.single.name, 'تركيب الخلية');
    expect(out.lessons.single.checklist.readNotes, isFalse);
    expect(out.exams.single.percentage, closeTo(72.7272, 0.001));
    expect(out.exams.single.groups.single.correctCount, 4);
    expect(out.homework.single.score, 9);
    expect(out.tasks.single.title, 'أذاكر');
  });

  test('exporting an empty database produces a parseable empty file', () {
    // The failure this guards against is an export that throws, or writes
    // `null`, on the first run of a fresh install -- which is exactly when a
    // student is most likely to try the button to see what it does.
    final text = service.encode(empty);

    expect(text, isNotEmpty);
    final out = reread(text);
    expect(out.isEmpty, isTrue);
    expect(out.subjects, isEmpty);
    expect(out.tasks, isEmpty);
  });

  test('the payload carries a version marker', () {
    // Without it `fromJson` refuses the file outright, so an export that omits
    // it is an export nothing can ever read back -- including this app.
    final json = jsonDecode(service.encode(empty)) as Map<String, Object?>;
    expect(json['formatVersion'], StudyBackup.formatVersion);
  });

  test('the file is written for a person to read', () {
    // Indented, not minified. A student who opens the file and finds one
    // enormous line has been handed their data in a form they cannot check.
    final text = service.encode(populated());
    expect(text, contains('\n'));
    expect(text, contains('  "chapters"'));
  });

  test('filenames are timestamped and free of characters that break shares', () {
    final name = service.buildFilename(DateTime(2026, 8, 18, 14, 30, 45));

    expect(name, 'ather_export_2026-08-18_14-30-45.json');
    // Colons are legal on Android and rejected by Windows and Drive, so a
    // shared export carrying one fails at the far end rather than here.
    expect(name, isNot(contains(':')));
  });

  test('two exports a second apart do not collide', () {
    expect(
      service.buildFilename(DateTime(2026, 8, 18, 14, 30, 45)),
      isNot(service.buildFilename(DateTime(2026, 8, 18, 14, 30, 46))),
    );
  });
}
