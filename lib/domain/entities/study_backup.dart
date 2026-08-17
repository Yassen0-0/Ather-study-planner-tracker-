import 'chapter.dart';
import 'daily_task.dart';
import 'exam_entry.dart';
import 'homework_entry.dart';
import 'lesson.dart';
import 'study_snapshot.dart';
import 'subject.dart';

/// Everything a student has recorded, in a form that can leave the device.
///
/// Pure Dart with no Firebase and no drift: this is the shape of the backup, not
/// the transport. That is what makes the round-trip unit-testable without a
/// network or a database, which matters because a serialisation bug here loses
/// a student's whole record silently.
///
/// **Subjects are carried now, and were not before.** While the only subjects
/// were the four seeded identically on every install at fixed ids 1-4, sending
/// them would have been sending four rows the receiving device had already
/// created for itself. Once a student can add their own, the opposite is true:
/// every chapter names a `subjectId`, so a restore onto a new phone that did
/// not carry the subjects would land chapters pointing at rows that do not
/// exist -- a foreign key failure at best, and a silently emptied subject at
/// worst.
final class StudyBackup {
  const StudyBackup({
    required this.subjects,
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
  ///
  /// 2 added `subjects`. The bump is what stops an older build from accepting
  /// this file: it would ignore the key it does not know, then try to insert
  /// chapters under subject ids that only exist on the phone that wrote them.
  /// A refusal a student can read beats a restore that half-lands.
  static const int formatVersion = 2;

  /// Empty in a version 1 backup, which is not a loss: every subject that could
  /// exist when those were written is seeded on the receiving device already.
  final List<Subject> subjects;

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
      subjects: snapshot.subjects,
      chapters: snapshot.chapters,
      lessons: snapshot.lessons,
      exams: snapshot.exams,
      homework: snapshot.homework,
      tasks: tasks,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'formatVersion': formatVersion,
    'subjects': <Object?>[
      for (final s in subjects)
        <String, Object?>{
          'id': s.id,
          // The enum's name, or the custom sentinel. Written as a string so a
          // build that does not know a future code can still read the row and
          // treat it as custom rather than failing.
          'code': s.code?.name ?? kCustomSubjectCode,
          'name': s.name,
          'sortOrder': s.sortOrder,
          'archivedAt': _epochOrNull(s.archivedAt),
          'deletedAt': _epochOrNull(s.deletedAt),
        },
    ],
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

    final subjects = <Subject>[
      for (final raw in _list(json['subjects']))
        Subject(
          id: raw['id']! as int,
          code: SubjectCode.tryFromName((raw['code'] ?? '') as String),
          name: raw['name'] as String?,
          sortOrder: (raw['sortOrder'] ?? 0) as int,
          archivedAt: _dateOrNull(raw['archivedAt']),
          // Absent in anything written before the recycle bin existed, which
          // reads back as null -- an active subject, which is what it was.
          deletedAt: _dateOrNull(raw['deletedAt']),
        ),
    ];

    final exams = <ExamEntry>[];
    for (final raw in _list(json['exams'])) {
      final id = raw['id']! as int;
      final possible = raw['totalPossiblePoints']! as int;
      exams.add(
        ExamEntry(
          id: id,
          lessonId: raw['lessonId']! as int,
          isReviewExam: raw['isReviewExam']! as bool,
          totalPossiblePoints: possible < 0 ? 0 : possible,
          correctPoints: _clampInt(raw['correctPoints']! as int, 0, possible),
          percentage: _clampPercent((raw['percentage']! as num).toDouble()),
          createdAt: _date(raw['createdAt']),
          groups: <ExamQuestionGroup>[
            for (final g in _list(raw['groups']))
              // Same repair, one level down: `percentageOf` divides earned by
              // possible, so a group claiming more correct answers than it has
              // questions is what produces a percentage above 100 in the first
              // place.
              ExamQuestionGroup(
                id: g['id']! as int,
                examId: id,
                pointsPerQuestion: _clampInt(
                  g['pointsPerQuestion']! as int,
                  0,
                  1 << 31,
                ),
                questionCount: _clampInt(
                  g['questionCount']! as int,
                  0,
                  1 << 31,
                ),
                correctCount: _clampInt(
                  g['correctCount']! as int,
                  0,
                  _clampInt(g['questionCount']! as int, 0, 1 << 31),
                ),
              ),
          ],
        ),
      );
    }

    return StudyBackup(
      subjects: subjects,
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

  /// Brings a restored score back inside the range the app's own arithmetic can
  /// produce.
  ///
  /// Nothing in the wizard can write a score above 100 or below 0 -- step 3
  /// refuses `correct > count` -- so a value outside that range did not come
  /// from Ather. It can still arrive here: this method parses a blob fetched
  /// from Firestore, and a document under a student's own uid can be written by
  /// anything holding that student's token, including a modified build of this
  /// app or a hand-crafted REST call.
  ///
  /// Verified on an emulator on 2026-08-15 by writing `correct_points = 9999`
  /// against `total_possible_points = 10` with `percentage = 999` straight into
  /// the SQLite file: the app did not crash, and the dashboard rendered the
  /// subject at **333%** and overall mastery at 83%. There is no privilege
  /// behind that number -- no leaderboard, no unlock, nothing a student gains
  /// by inflating it -- which is why this is repair rather than rejection.
  ///
  /// **Clamped, never dropped.** Refusing the exam would delete a row from a
  /// restore, and a restore that quietly loses exams is the one failure this
  /// feature must not have (see the note on `formatVersion` above). A clamped
  /// score is wrong by a few points; a missing one is wrong by a whole exam.
  static double _clampPercent(double value) {
    if (value.isNaN) return 0;
    return value < 0
        ? 0
        : value > 100
        ? 100
        : value;
  }

  static int _clampInt(int value, int low, int high) {
    if (high < low) return low;
    return value < low ? low : (value > high ? high : value);
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

  static List<Map<String, Object?>> _list(Object? value) =>
      <Map<String, Object?>>[
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
