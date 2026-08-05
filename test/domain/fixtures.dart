import 'package:drift/native.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/study_snapshot.dart';

/// A bare [ExamEntry] for tests that only exercise the percentage maths.
///
/// Point totals are back-filled from [percentage] so the row stays internally
/// consistent even though these tests never read them.
ExamEntry exam({
  required int id,
  required double percentage,
  int? day,
  DateTime? at,
  bool isReview = false,
  int lessonId = 1,
}) {
  assert(day != null || at != null, 'provide either day or at');
  return ExamEntry(
    id: id,
    lessonId: lessonId,
    isReviewExam: isReview,
    totalPossiblePoints: 100,
    correctPoints: percentage.round(),
    percentage: percentage,
    createdAt: at ?? DateTime(2026, 1, day!),
    groups: const <ExamQuestionGroup>[],
  );
}

/// Builds a snapshot from a real in-memory database.
///
/// Tests run against genuine SQLite rather than hand-assembled objects, so the
/// snapshot's indexing, sorting and cascade behaviour are exercised alongside
/// the logic under test.
Future<StudySnapshot> buildSnapshot(
  Future<void> Function(DriftStudyRepository repo) setup,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  final repo = DriftStudyRepository(db);
  try {
    await setup(repo);
    return await repo.readSnapshot();
  } finally {
    await db.close();
  }
}

/// Records an exam that lands on exactly [percentage].
///
/// Uses a 100-question, 1-point-each paper so any whole percentage is
/// expressible without floating-point drift.
Future<int> recordPercentage(
  DriftStudyRepository repo,
  int lessonId,
  int percentage,
  DateTime at, {
  bool isReview = false,
}) {
  return repo.recordExam(
    lessonId: lessonId,
    groups: <DraftQuestionGroup>[
      DraftQuestionGroup(
        pointsPerQuestion: 1,
        questionCount: 100,
        correctCount: percentage,
      ),
    ],
    isReviewExam: isReview,
    at: at,
  );
}
