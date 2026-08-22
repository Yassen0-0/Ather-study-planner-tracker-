import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/subject.dart';

/// Homework fields are clamped on restore, exactly as exam fields are.
///
/// `fromJson` parses a blob fetched from Firestore, and a document under a
/// student's own uid can be written by anything holding that student's token
/// -- including a hand-crafted REST call. The exams have been clamped against
/// that since the threat model was written; the homework row beside them was
/// not, so `score = 9999 / maxScore = 10` restored intact and rendered as
/// 99990% -- and a negative score read as "below the readiness threshold"
/// forever, with no way in through the UI to correct it.
void main() {
  final DateTime t0 = DateTime.fromMillisecondsSinceEpoch(1754300000000);

  StudyBackup backupWith(HomeworkEntry homework) => StudyBackup(
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
        name: 'درس',
        createdAt: t0,
        checklist: const LessonChecklist(),
      ),
    ],
    exams: const <ExamEntry>[],
    homework: <HomeworkEntry>[homework],
    tasks: const <DailyTask>[],
  );

  /// A map shaped like one a modified build or a REST call would PUT: the
  /// honest blob from [backupWith], with the homework numbers replaced by
  /// whatever the test plants. Through real JSON text, as the wire carries it.
  Map<String, Object?> planted({
    required Object? score,
    required Object? maxScore,
  }) {
    final json =
        jsonDecode(jsonEncode(backupWith(
              HomeworkEntry(id: 3, lessonId: 20, score: 8, maxScore: 10,
                  createdAt: t0),
            ).toJson()))
            as Map<String, Object?>;
    final raw = (json['homework']! as List<Object?>).single
        as Map<String, Object?>;
    raw['score'] = score;
    raw['maxScore'] = maxScore;
    return json;
  }

  test('a planted 99990% restores clamped to 100%', () {
    final out = StudyBackup.fromJson(planted(score: 9999, maxScore: 10));

    final homework = out.homework.single;
    expect(homework.maxScore, 10);
    expect(homework.score, 10);
    // The number the lesson screen actually renders.
    expect(homework.percentage, 100);
  });

  test('a negative score restores as zero, not an eternal failure', () {
    final out = StudyBackup.fromJson(planted(score: -5, maxScore: 10));

    final homework = out.homework.single;
    expect(homework.score, 0);
    expect(homework.percentage, 0);
  });

  test('a maxScore below 1 is lifted to 1 rather than dividing by zero', () {
    final out = StudyBackup.fromJson(planted(score: 3, maxScore: 0));

    final homework = out.homework.single;
    expect(homework.maxScore, 1);
    expect(homework.score, 1);
  });

  test('a negative maxScore is lifted too, and drags its score with it', () {
    final out = StudyBackup.fromJson(planted(score: 9999, maxScore: -4));

    final homework = out.homework.single;
    expect(homework.maxScore, 1);
    expect(homework.score, 1);
  });

  test('honest values pass through untouched', () {
    final out = StudyBackup.fromJson(planted(score: 7, maxScore: 10));

    final homework = out.homework.single;
    expect(homework.score, 7);
    expect(homework.maxScore, 10);
    expect(homework.percentage, 70);
  });

  test('homework survives a round trip unchanged', () {
    final entry = HomeworkEntry(id: 3, lessonId: 20, score: 8, maxScore: 10,
        createdAt: t0);

    final json = jsonEncode(backupWith(entry).toJson());
    final out = StudyBackup.fromJson(
      jsonDecode(json) as Map<String, Object?>,
    );

    expect(out.homework.single, entry);
    expect(out.homework.single.percentage, closeTo(80, 0.001));
  });
}
