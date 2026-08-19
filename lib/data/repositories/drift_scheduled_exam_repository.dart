import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/entities/scheduled_exam.dart';
import '../../domain/repositories/scheduled_exam_repository.dart';
import '../db/app_database.dart';

/// Drift-backed [ScheduledExamRepository].
class DriftScheduledExamRepository implements ScheduledExamRepository {
  DriftScheduledExamRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ScheduledExam>> watchScheduledExams() {
    // Watch both tables together: scheduled exams and their chapter associations.
    // combineLatest ensures the UI sees a coherent snapshot when either table
    // changes -- adding a chapter association updates the calendar view from a
    // single write.
    return _combineLatest2(
      _db.select(_db.scheduledExams).watch(),
      _db.select(_db.scheduledExamChapters).watch(),
      _buildScheduledExamList,
    );
  }

  @override
  Future<List<ScheduledExam>> readScheduledExams() async {
    final results = await Future.wait(<Future<List<Object>>>[
      _db.select(_db.scheduledExams).get(),
      _db.select(_db.scheduledExamChapters).get(),
    ]);

    return _buildScheduledExamList(
      results[0].cast<ScheduledExamRow>(),
      results[1].cast<ScheduledExamChapterRow>(),
    );
  }

  List<ScheduledExam> _buildScheduledExamList(
    List<ScheduledExamRow> examRows,
    List<ScheduledExamChapterRow> chapterRows,
  ) {
    // Group chapter associations by exam ID
    final chaptersByExam = <int, List<int>>{};
    for (final row in chapterRows) {
      (chaptersByExam[row.scheduledExamId] ??= <int>[]).add(row.chapterId);
    }

    return <ScheduledExam>[
      for (final row in examRows)
        _toScheduledExam(row, chaptersByExam[row.id] ?? const <int>[]),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<int> createScheduledExam({
    required int subjectId,
    required DateTime date,
    required String title,
    required List<int> chapterIds,
    String? notes,
    required DateTime at,
  }) {
    return _db.transaction(() async {
      final examId = await _db
          .into(_db.scheduledExams)
          .insert(
            ScheduledExamsCompanion.insert(
              subjectId: subjectId,
              date: date,
              title: title.trim(),
              notes: Value(notes?.trim()),
              createdAt: at,
            ),
          );

      // Insert chapter associations in a batch
      if (chapterIds.isNotEmpty) {
        await _db.batch((Batch batch) {
          for (final chapterId in chapterIds) {
            batch.insert(
              _db.scheduledExamChapters,
              ScheduledExamChaptersCompanion.insert(
                scheduledExamId: examId,
                chapterId: chapterId,
              ),
            );
          }
        });
      }

      return examId;
    });
  }

  @override
  Future<void> updateScheduledExam({
    required int id,
    required int subjectId,
    required DateTime date,
    required String title,
    required List<int> chapterIds,
    String? notes,
  }) {
    return _db.transaction(() async {
      // Update the exam record
      await (_db.update(_db.scheduledExams)..where((t) => t.id.equals(id)))
          .write(
        ScheduledExamsCompanion(
          subjectId: Value(subjectId),
          date: Value(date),
          title: Value(title.trim()),
          notes: Value(notes?.trim()),
        ),
      );

      // Replace chapter associations: delete all existing ones, then insert the
      // new set. Simpler than diffing old vs new, and a scheduled exam holds a
      // handful of chapters at most.
      await (_db.delete(_db.scheduledExamChapters)
            ..where((t) => t.scheduledExamId.equals(id)))
          .go();

      if (chapterIds.isNotEmpty) {
        await _db.batch((Batch batch) {
          for (final chapterId in chapterIds) {
            batch.insert(
              _db.scheduledExamChapters,
              ScheduledExamChaptersCompanion.insert(
                scheduledExamId: id,
                chapterId: chapterId,
              ),
            );
          }
        });
      }
    });
  }

  @override
  Future<void> deleteScheduledExam(int id) async {
    // ON DELETE CASCADE handles the chapter associations automatically
    await (_db.delete(_db.scheduledExams)..where((t) => t.id.equals(id))).go();
  }

  ScheduledExam _toScheduledExam(ScheduledExamRow r, List<int> chapterIds) =>
      ScheduledExam(
        id: r.id,
        subjectId: r.subjectId,
        date: r.date,
        title: r.title,
        chapterIds: chapterIds,
        notes: r.notes,
        createdAt: r.createdAt,
      );

  /// Combines two streams into a single stream that emits whenever either
  /// source emits. Waits for the first event from both before emitting.
  Stream<R> _combineLatest2<A, B, R>(
    Stream<A> streamA,
    Stream<B> streamB,
    R Function(A, B) combiner,
  ) {
    A? latestA;
    B? latestB;
    var hasA = false;
    var hasB = false;

    final controller = StreamController<R>.broadcast(
      onCancel: () {
        // Clean up subscriptions when all listeners cancel
      },
    );

    streamA.listen((a) {
      latestA = a;
      hasA = true;
      if (hasB) controller.add(combiner(a, latestB as B));
    });

    streamB.listen((b) {
      latestB = b;
      hasB = true;
      if (hasA) controller.add(combiner(latestA as A, b));
    });

    return controller.stream;
  }
}
