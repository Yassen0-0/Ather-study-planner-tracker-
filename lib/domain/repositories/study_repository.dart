import '../entities/exam_entry.dart';
import '../entities/lesson.dart';
import '../entities/study_backup.dart';
import '../entities/study_snapshot.dart';

/// Everything the app can read or change.
///
/// Reads are served as a single [StudySnapshot] stream (see that class for why),
/// while writes stay explicit and entity-shaped so intent is visible at the call
/// site -- `markChapterMastered` rather than a generic `update`.
abstract interface class StudyRepository {
  /// Emits a fresh snapshot on every write, anywhere. Backed by drift's
  /// `.watch()`, so no screen ever needs manual cache invalidation.
  Stream<StudySnapshot> watchSnapshot();

  /// One-shot read, for logic that runs outside the widget tree (notification
  /// scheduling, the lifecycle reconciliation pass).
  Future<StudySnapshot> readSnapshot();

  // --- Subjects -------------------------------------------------------------
  /// Adds a subject the student named. Returns its new id.
  ///
  /// The id is `max(id) + 1` rather than an autoincrement, because the seeded
  /// four hold fixed ids 1-4 and the column was never declared as one.
  Future<int> createSubject({required String name});

  /// Only a subject the student created can be renamed. The seeded four take
  /// their names from the ARB files, so a name written here would freeze one
  /// language into a database the toggle cannot reach.
  Future<void> renameSubject({required int subjectId, required String name});

  /// Archives a subject, or brings it back. Touches nothing beneath it.
  ///
  /// "I am done with this, put it away" — a deliberate act on a subject the
  /// student is keeping.
  Future<void> setSubjectArchived({
    required int subjectId,
    required DateTime? at,
  });

  /// Moves a subject to the recycle bin, or restores it. Touches nothing
  /// beneath it either.
  ///
  /// "I did not mean to have this" — the other intention, and the reason these
  /// are two operations rather than one. `Chapters.subjectId` cascades, so a
  /// real delete here would take every chapter, lesson and exam beneath it and
  /// there is no undo anywhere in this app. Deferring the cascade to
  /// [purgeSubject] is what makes offering "delete" honest.
  Future<void> setSubjectDeleted({
    required int subjectId,
    required DateTime? at,
  });

  /// Destroys a subject and everything beneath it, for real.
  ///
  /// The single irreversible operation in the whole feature, reachable only
  /// from inside the recycle bin. Everything else is a flag.
  Future<void> purgeSubject(int subjectId);

  // --- Chapters -------------------------------------------------------------
  /// [at] comes from the injectable [Clock], like every other timestamp the app
  /// writes. `createChapter` and `createLesson` used to call `DateTime.now()`
  /// directly — the only two writes in the repository that did — which quietly
  /// exempted `createdAt` from the debug time-travel tool and from any test
  /// pinning the date. `createdAt` is not decoration: it is the sort order of
  /// every list, and it is what "most recent activity" is read from.
  Future<int> createChapter({
    required int subjectId,
    required String name,
    required DateTime at,
  });
  Future<void> renameChapter({required int chapterId, required String name});
  Future<void> deleteChapter(int chapterId);

  /// Closes out a chapter: stamps `masteredAt` and resets `lastReviewedAt` on
  /// every lesson inside it.
  ///
  /// Implementations must do both in **one transaction** -- a half-applied
  /// mastery would leave a chapter marked done while its lessons immediately
  /// start counting toward the next decay cycle from the wrong date.
  Future<void> markChapterMastered({
    required int chapterId,
    required DateTime at,
  });

  // --- Lessons --------------------------------------------------------------
  Future<int> createLesson({
    required int chapterId,
    required String name,
    required DateTime at,
  });
  Future<void> renameLesson({required int lessonId, required String name});
  Future<void> deleteLesson(int lessonId);
  Future<void> updateChecklist({
    required int lessonId,
    required LessonChecklist checklist,
  });

  /// Records that a review reminder was posted, so the same overdue lesson does
  /// not notify again on the next reconciliation pass.
  Future<void> markLessonNotified({
    required int lessonId,
    required DateTime at,
  });

  // --- Exams ----------------------------------------------------------------
  /// Saves an exam and resets the lesson's review clock in one transaction.
  ///
  /// [isReviewExam] is decided by the caller from the lesson's state at submit
  /// time, and the totals are derived from [groups] -- never passed in -- so a
  /// stored percentage can never disagree with the groups behind it.
  Future<int> recordExam({
    required int lessonId,
    required List<DraftQuestionGroup> groups,
    required bool isReviewExam,
    required DateTime at,
  });

  Future<void> deleteExam(int examId);

  // --- Homework -------------------------------------------------------------
  Future<int> recordHomework({
    required int lessonId,
    required int score,
    required int maxScore,
    required DateTime at,
  });

  // There is deliberately no `deleteHomework`. One existed, unreachable from any
  // screen, for the whole life of the app. Unlike an exam, a homework score
  // needs no correction path: only the most recent entry is ever read
  // (`latestHomeworkPercentage`), so recording a new one supersedes a mistyped
  // one, and homework never touches mastery in the first place. If a homework
  // history is ever shown, the delete comes back with the UI that needs it.

  // --- Restore ---------------------------------------------------------------
  /// Replaces every chapter, lesson, exam and homework entry with [backup].
  ///
  /// **Must be one transaction, and must preserve the original ids.** Ids are
  /// what every `chapterId`/`lessonId`/`examId` relationship is made of, so
  /// letting autoincrement reassign them would silently reattach exams to the
  /// wrong lessons -- a corruption no error message would ever report.
  ///
  /// A half-applied restore is the most destructive thing in this app, so it is
  /// all-or-nothing: on any failure the student's existing database is left
  /// exactly as it was.
  ///
  /// The four seeded subjects are untouched: they are not part of a backup, and
  /// the receiving install has already created them.
  Future<void> restore(StudyBackup backup);

  /// Empties the student's record from this device, leaving the seeded subjects.
  ///
  /// Called in exactly one situation: a **different** account has just signed in
  /// on a device that still holds the previous student's curriculum. Nothing
  /// cleared local data before, so the second student opened the app to the
  /// first one's chapters -- and the backup sync then mirrored those chapters
  /// into the second student's cloud document.
  ///
  /// Deliberately **not** called on sign-out. Signing out is not a statement
  /// that the data is finished with, the phone may be offline with unsynced
  /// work, and the same student signing back in must find everything where they
  /// left it. The data only becomes wrong when somebody else's account arrives.
  Future<void> clear();
}
