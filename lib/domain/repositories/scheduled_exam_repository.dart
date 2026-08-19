import '../entities/scheduled_exam.dart';

/// Repository for managing scheduled exam events.
///
/// Students use scheduled exams to plan exam preparation: the calendar shows
/// which exams are approaching, and for each one, which associated lessons have
/// decayed and need re-proof before the exam date. Scheduled exams are
/// forward-looking intent -- they do not affect mastery until an actual
/// ExamEntry is recorded.
///
/// Reads are served as a stream for reactive UI updates, while writes stay
/// explicit and entity-shaped so intent is visible at the call site.
abstract interface class ScheduledExamRepository {
  /// Emits the full list of scheduled exams on every write.
  ///
  /// Backed by drift's `.watch()`, so the calendar view never needs manual
  /// cache invalidation -- any create/update/delete automatically refreshes
  /// every listening screen.
  Stream<List<ScheduledExam>> watchScheduledExams();

  /// One-shot read, for logic that runs outside the widget tree (notification
  /// scheduling, lifecycle reconciliation).
  Future<List<ScheduledExam>> readScheduledExams();

  // --- Scheduled Exams ------------------------------------------------------
  /// Creates a scheduled exam event. Returns its new id.
  ///
  /// [chapterIds] associates this exam with specific chapters, so the app can
  /// highlight decayed lessons in those chapters as the exam approaches.
  /// [notes] is optional student context ("Covers units 1-3", "Final exam").
  /// [at] comes from the injectable Clock, like every other timestamp the app
  /// writes -- this keeps `createdAt` in scope for debug time-travel and tests.
  Future<int> createScheduledExam({
    required int subjectId,
    required DateTime date,
    required String title,
    required List<int> chapterIds,
    String? notes,
    required DateTime at,
  });

  /// Updates an existing scheduled exam.
  ///
  /// The exam date, title, associated chapters, or notes can change -- a
  /// student might move an exam forward a week, or add more chapters to the
  /// scope. This reschedules notifications (3 days before) and updates the
  /// calendar view.
  Future<void> updateScheduledExam({
    required int id,
    required int subjectId,
    required DateTime date,
    required String title,
    required List<int> chapterIds,
    String? notes,
  });

  /// Deletes a scheduled exam.
  ///
  /// The exam is gone for real -- no recycle bin for scheduled events. Removes
  /// the exam from the calendar and cancels its preparation reminder
  /// notification.
  Future<void> deleteScheduledExam(int id);
}
