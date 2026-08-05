import 'chapter.dart';
import 'daily_task.dart';
import 'exam_entry.dart';
import 'homework_entry.dart';
import 'lesson.dart';
import 'study_snapshot.dart';

/// Everything a student has recorded, in a form that can leave the device.
///
/// Pure Dart with no Firebase and no drift: this is the shape of the backup, not
/// the transport. That is what makes the round-trip unit-testable without a
/// network or a database, which matters because a serialisation bug here loses
/// a student's whole record silently.
///
/// **The four subjects are deliberately not included.** They are seeded
/// identically on every install with fixed ids 1-4 (`kSeededSubjects`), so
/// carrying them would be carrying four rows that the receiving device has
/// already created for itself -- and would introduce a way for a restore to
/// disagree with the seed.
final class StudyBackup {
  const StudyBackup({
    required this.chapters,
    required this.lessons,
    required this.exams,
    required this.homework,
    required this.tasks,
  });

  /// Bumped only when the shape changes in a way an older app cannot read.
  ///
  /// A backup written by a *newer* version is refused outright rather than
  /// half-read: reading four of six fields and silently dropping the rest is
  /// how a restore quietly deletes two years of exams.
  static const int formatVersion = 1;

  final List<Chapter> chapters;
  final List<Lesson> lessons;
  final List<ExamEntry> exams;
  final List<HomeworkEntry> homework;
  final List<DailyTask> tasks;

  bool get isEmpty =>
      chapters.isEmpty && lessons.isEmpty && exams.isEmpty && tasks.isEmpty;

  /// What the student sees when asked to choose between two copies. Chapters and
  /// exams, because those are the two numbers that mean something to them.
  int get chapterCount => chapters.length;
  int get examCount => exams.length;

  static StudyBackup fromSnapshot(
    StudySnapshot snapshot,
    List<DailyTask> tasks,
  ) {
    return StudyBackup(
      chapters: snapshot.chapters,
      lessons: snapshot.lessons,
      exams: snapshot.exams,
      homework: snapshot.homework,
      tasks: tasks,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'formatVersion': formatVersion,
    'chapters': <Object?>[
      for (final c in chapters)
        <String, Object?>{
          'id': c.id,
          'subjectId': c.subjectId,
          'name': c.name,
          'createdAt': _epoch(c.createdAt),
          'masteredAt': _epochOrNull(c.masteredAt),
        },
    ],
    'lessons': <Object?>[
      for (final l in lessons)
        <String, Object?>{
          'id': l.id,
          'chapterId': l.chapterId,
          'name': l.name,
          'createdAt': _epoch(l.createdAt),
          'lastReviewedAt': _epochOrNull(l.lastReviewedAt),
          'lastNotifiedAt': _epochOrNull(l.lastNotifiedAt),
          'watchedLesson': l.checklist.watchedLesson,
          'readNotes': l.checklist.readNotes,
          'didHomework': l.checklist.didHomework,
          'didExam': l.checklist.didExam,
          'reviewedNotes': l.checklist.reviewedNotes,
        },
    ],
    'exams': <Object?>[
      for (final e in exams)
        <String, Object?>{
          'id': e.id,
          'lessonId': e.lessonId,
          'isReviewExam': e.isReviewExam,
          'totalPossiblePoints': e.totalPossiblePoints,
          'correctPoints': e.correctPoints,
          // Denormalised on the row and carried as-is: a past exam's score has
          // to stay historically stable, so it is never recomputed on restore.
          'percentage': e.percentage,
          'createdAt': _epoch(e.createdAt),
          'groups': <Object?>[
            for (final g in e.groups)
              <String, Object?>{
                'id': g.id,
                'pointsPerQuestion': g.pointsPerQuestion,
                'questionCount': g.questionCount,
                'correctCount': g.correctCount,
              },
          ],
        },
    ],
    'homework': <Object?>[
      for (final h in homework)
        <String, Object?>{
          'id': h.id,
          'lessonId': h.lessonId,
          'score': h.score,
          'maxScore': h.maxScore,
          'createdAt': _epoch(h.createdAt),
        },
    ],
    'tasks': <Object?>[
      for (final t in tasks)
        <String, Object?>{
          'id': t.id,
          'day': _epoch(t.day),
          'title': t.title,
          'done': t.done,
          'sortOrder': t.sortOrder,
          'createdAt': _epoch(t.createdAt),
        },
    ],
  };

  /// Throws [BackupFormatException] rather than returning a partial result.
  static StudyBackup fromJson(Map<String, Object?> json) {
    final version = json['formatVersion'];
    if (version is! int) {
      throw const BackupFormatException('missing formatVersion');
    }
    if (version > formatVersion) {
      throw BackupFormatException(
        'backup format $version is newer than this app understands '
        '($formatVersion)',
      );
    }

    final exams = <ExamEntry>[];
    for (final raw in _list(json['exams'])) {
      final id = raw['id']! as int;
      exams.add(
        ExamEntry(
          id: id,
          lessonId: raw['lessonId']! as int,
          isReviewExam: raw['isReviewExam']! as bool,
          totalPossiblePoints: raw['totalPossiblePoints']! as int,
          correctPoints: raw['correctPoints']! as int,
          percentage: (raw['percentage']! as num).toDouble(),
          createdAt: _date(raw['createdAt']),
          groups: <ExamQuestionGroup>[
            for (final g in _list(raw['groups']))
              ExamQuestionGroup(
                id: g['id']! as int,
                examId: id,
                pointsPerQuestion: g['pointsPerQuestion']! as int,
                questionCount: g['questionCount']! as int,
                correctCount: g['correctCount']! as int,
              ),
          ],
        ),
      );
    }

    return StudyBackup(
      chapters: <Chapter>[
        for (final c in _list(json['chapters']))
          Chapter(
            id: c['id']! as int,
            subjectId: c['subjectId']! as int,
            name: c['name']! as String,
            createdAt: _date(c['createdAt']),
            masteredAt: _dateOrNull(c['masteredAt']),
          ),
      ],
      lessons: <Lesson>[
        for (final l in _list(json['lessons']))
          Lesson(
            id: l['id']! as int,
            chapterId: l['chapterId']! as int,
            name: l['name']! as String,
            createdAt: _date(l['createdAt']),
            lastReviewedAt: _dateOrNull(l['lastReviewedAt']),
            lastNotifiedAt: _dateOrNull(l['lastNotifiedAt']),
            checklist: LessonChecklist(
              watchedLesson: l['watchedLesson']! as bool,
              readNotes: l['readNotes']! as bool,
              didHomework: l['didHomework']! as bool,
              didExam: l['didExam']! as bool,
              reviewedNotes: l['reviewedNotes']! as bool,
            ),
          ),
      ],
      exams: exams,
      homework: <HomeworkEntry>[
        for (final h in _list(json['homework']))
          HomeworkEntry(
            id: h['id']! as int,
            lessonId: h['lessonId']! as int,
            score: h['score']! as int,
            maxScore: h['maxScore']! as int,
            createdAt: _date(h['createdAt']),
          ),
      ],
      tasks: <DailyTask>[
        for (final t in _list(json['tasks']))
          DailyTask(
            id: t['id']! as int,
            day: _date(t['day']),
            title: t['title']! as String,
            done: t['done']! as bool,
            sortOrder: t['sortOrder']! as int,
            createdAt: _date(t['createdAt']),
          ),
      ],
    );
  }

  /// Epoch milliseconds, UTC. Not an ISO string: it is shorter, it cannot be
  /// misparsed under a different locale, and it carries no timezone to get
  /// wrong when a student restores onto a phone set to another zone.
  static int _epoch(DateTime value) => value.millisecondsSinceEpoch;
  static int? _epochOrNull(DateTime? value) => value?.millisecondsSinceEpoch;

  static DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value! as int);

  static DateTime? _dateOrNull(Object? value) =>
      value == null ? null : DateTime.fromMillisecondsSinceEpoch(value as int);

  static List<Map<String, Object?>> _list(Object? value) => <Map<String, Object?>>[
    for (final item in (value as List<Object?>? ?? const <Object?>[]))
      (item as Map<Object?, Object?>).cast<String, Object?>(),
  ];
}

/// A backup that cannot be read. Separate from [BackupFailure] because this one
/// is about the *contents* rather than the transport, and it is the only case
/// where the right answer is to leave the local database completely alone.
class BackupFormatException implements Exception {
  const BackupFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'BackupFormatException: $reason';
}
