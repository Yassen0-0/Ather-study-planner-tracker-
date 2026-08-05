import '../entities/exam_entry.dart';
import '../entities/lesson.dart';
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

  // --- Chapters -------------------------------------------------------------
  Future<int> createChapter({required int subjectId, required String name});
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
  Future<int> createLesson({required int chapterId, required String name});
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

  Future<void> deleteHomework(int homeworkId);
}
