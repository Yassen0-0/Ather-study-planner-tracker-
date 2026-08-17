import 'chapter.dart';
import 'exam_entry.dart';
import 'homework_entry.dart';
import 'lesson.dart';
import 'subject.dart';

/// A consistent, fully-indexed view of everything the student has recorded.
///
/// **Why one snapshot instead of per-entity queries:** every headline screen in
/// Ather is cross-cutting. The dashboard averages mastery across all four
/// subjects, the Review Center scans every lesson in the app, and analytics
/// charts span subjects and time. Serving those from separate repositories
/// would mean hand-written joins in the presentation layer and a real risk of
/// two screens disagreeing because they read at different moments.
///
/// The data volume makes this cheap: even a maximal student -- 4 subjects, ~15
/// chapters each, ~10 lessons per chapter -- is a few hundred lessons and a few
/// thousand exams. Loading that and computing in Dart costs microseconds, and
/// buys pure, database-free testability for every calculation in the app.
final class StudySnapshot {
  StudySnapshot({
    required this.subjects,
    required this.chapters,
    required this.lessons,
    required this.exams,
    required this.homework,
  }) : chaptersBySubject = _groupBy(chapters, (Chapter c) => c.subjectId),
       lessonsByChapter = _groupBy(lessons, (Lesson l) => l.chapterId),
       _examsByLesson = _groupBy(exams, (ExamEntry e) => e.lessonId),
       homeworkByLesson = _groupBy(homework, (HomeworkEntry h) => h.lessonId) {
    // Exams are sorted newest-first once, here, so the mastery formula never
    // has to re-sort and can never disagree with the history list about which
    // exam is "the last one".
    for (final list in _examsByLesson.values) {
      list.sort(compareExamsNewestFirst);
    }
  }

  const StudySnapshot.empty()
    : subjects = const <Subject>[],
      chapters = const <Chapter>[],
      lessons = const <Lesson>[],
      exams = const <ExamEntry>[],
      homework = const <HomeworkEntry>[],
      chaptersBySubject = const <int, List<Chapter>>{},
      lessonsByChapter = const <int, List<Lesson>>{},
      _examsByLesson = const <int, List<ExamEntry>>{},
      homeworkByLesson = const <int, List<HomeworkEntry>>{};

  final List<Subject> subjects;
  final List<Chapter> chapters;
  final List<Lesson> lessons;
  final List<ExamEntry> exams;
  final List<HomeworkEntry> homework;

  final Map<int, List<Chapter>> chaptersBySubject;
  final Map<int, List<Lesson>> lessonsByChapter;
  final Map<int, List<ExamEntry>> _examsByLesson;
  final Map<int, List<HomeworkEntry>> homeworkByLesson;

  /// Newest first. Ties on [ExamEntry.createdAt] break by descending id, so two
  /// exams saved in the same millisecond still have a deterministic "last one"
  /// -- otherwise mastery could flip between rebuilds.
  static int compareExamsNewestFirst(ExamEntry a, ExamEntry b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  bool get isEmpty => chapters.isEmpty && lessons.isEmpty;

  /// Every subject that is neither archived nor deleted, in sort order.
  ///
  /// **This, not [subjects], is what the app should be reading almost
  /// everywhere.** [subjects] is the whole table, and it exists for the three
  /// jobs that genuinely need the rest: writing the backup, the screen that
  /// manages subjects, and the recycle bin. Every figure a student reads --
  /// overall mastery, the insights, the next lesson to sit -- has to skip
  /// them, or putting a subject away would remove it from the list while still
  /// counting it as a 0 in the mean, which is the opposite of what both
  /// controls promise.
  List<Subject> get activeSubjects =>
      <Subject>[for (final s in subjects) if (s.isActive) s];

  /// Subjects sitting in the recycle bin, most recently deleted first.
  List<Subject> get deletedSubjects =>
      <Subject>[for (final s in subjects) if (s.isDeleted) s]
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  /// Every lesson under a subject that is neither archived nor deleted.
  ///
  /// **[activeSubjects] alone was not enough, and this is the hole it left.**
  /// Three things walk the flat [lessons] list rather than descending from
  /// subjects -- the notification scheduler, the review queue, and the
  /// insights generator -- so a subject put away kept sending its reminders,
  /// kept appearing in the review list, and kept producing insights about
  /// itself. Archiving a subject silenced its numbers and nothing else.
  ///
  /// That was already wrong. With a recycle bin it would be indefensible: a
  /// *deleted* subject would go on posting its lesson names to the lock screen
  /// of a phone whose owner had deleted it.
  ///
  /// Computed rather than cached because the sets involved are small -- a
  /// maximal student has a few hundred lessons -- and a cached copy is one more
  /// thing that can disagree with the table it came from.
  List<Lesson> get activeLessons {
    final live = <int>{for (final s in subjects) if (s.isActive) s.id};
    if (live.length == subjects.length) return lessons;

    final liveChapters = <int>{
      for (final c in chapters) if (live.contains(c.subjectId)) c.id,
    };
    return <Lesson>[
      for (final l in lessons) if (liveChapters.contains(l.chapterId)) l,
    ];
  }

  /// Exams for a lesson, newest first. Never null -- an unexamined lesson
  /// yields an empty list, which the mastery formula reads as 0.
  List<ExamEntry> examsFor(int lessonId) =>
      _examsByLesson[lessonId] ?? const <ExamEntry>[];

  List<HomeworkEntry> homeworkFor(int lessonId) =>
      homeworkByLesson[lessonId] ?? const <HomeworkEntry>[];

  List<Lesson> lessonsIn(int chapterId) =>
      lessonsByChapter[chapterId] ?? const <Lesson>[];

  List<Chapter> chaptersIn(int subjectId) =>
      chaptersBySubject[subjectId] ?? const <Chapter>[];

  Subject? subjectById(int id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  Chapter? chapterById(int id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }

  Lesson? lessonById(int id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// All lessons belonging to a subject, across all its chapters.
  List<Lesson> lessonsInSubject(int subjectId) => <Lesson>[
    for (final chapter in chaptersIn(subjectId)) ...lessonsIn(chapter.id),
  ];

  static Map<int, List<T>> _groupBy<T>(List<T> items, int Function(T) key) {
    final map = <int, List<T>>{};
    for (final item in items) {
      (map[key(item)] ??= <T>[]).add(item);
    }
    return map;
  }
}
