import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/entities/chapter.dart';
import '../../domain/entities/exam_entry.dart';
import '../../domain/entities/homework_entry.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/study_snapshot.dart';
import '../../domain/entities/subject.dart';
import '../../domain/repositories/study_repository.dart';
import '../db/app_database.dart';

/// Drift-backed [StudyRepository].
class DriftStudyRepository implements StudyRepository {
  DriftStudyRepository(this._db);

  final AppDatabase _db;

  // --- Reads ----------------------------------------------------------------

  @override
  Stream<StudySnapshot> watchSnapshot() {
    // Every table is combined rather than watched individually, because a
    // snapshot is only coherent if all six agree. combineLatest waits for the
    // first event from each, then re-emits whenever any one changes -- so a new
    // exam updates the lesson screen, the chapter bar and the dashboard from a
    // single write.
    return _combineLatest6(
      _db.select(_db.subjects).watch(),
      _db.select(_db.chapters).watch(),
      _db.select(_db.lessons).watch(),
      _db.select(_db.examEntries).watch(),
      _db.select(_db.examQuestionGroups).watch(),
      _db.select(_db.homeworkEntries).watch(),
      _buildSnapshot,
    );
  }

  @override
  Future<StudySnapshot> readSnapshot() async {
    final results = await Future.wait(<Future<List<Object>>>[
      _db.select(_db.subjects).get(),
      _db.select(_db.chapters).get(),
      _db.select(_db.lessons).get(),
      _db.select(_db.examEntries).get(),
      _db.select(_db.examQuestionGroups).get(),
      _db.select(_db.homeworkEntries).get(),
    ]);

    return _buildSnapshot(
      results[0].cast<SubjectRow>(),
      results[1].cast<ChapterRow>(),
      results[2].cast<LessonRow>(),
      results[3].cast<ExamEntryRow>(),
      results[4].cast<ExamQuestionGroupRow>(),
      results[5].cast<HomeworkEntryRow>(),
    );
  }

  StudySnapshot _buildSnapshot(
    List<SubjectRow> subjectRows,
    List<ChapterRow> chapterRows,
    List<LessonRow> lessonRows,
    List<ExamEntryRow> examRows,
    List<ExamQuestionGroupRow> groupRows,
    List<HomeworkEntryRow> homeworkRows,
  ) {
    final groupsByExam = <int, List<ExamQuestionGroup>>{};
    for (final row in groupRows) {
      (groupsByExam[row.examId] ??= <ExamQuestionGroup>[]).add(_toGroup(row));
    }

    final subjects = subjectRows.map(_toSubject).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return StudySnapshot(
      subjects: subjects,
      chapters: chapterRows.map(_toChapter).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      lessons: lessonRows.map(_toLesson).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      exams: <ExamEntry>[
        for (final row in examRows)
          _toExam(row, groupsByExam[row.id] ?? const <ExamQuestionGroup>[]),
      ],
      homework: homeworkRows.map(_toHomework).toList(),
    );
  }

  // --- Chapters -------------------------------------------------------------

  @override
  Future<int> createChapter({required int subjectId, required String name}) {
    return _db
        .into(_db.chapters)
        .insert(
          ChaptersCompanion.insert(
            subjectId: subjectId,
            name: name.trim(),
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> renameChapter({
    required int chapterId,
    required String name,
  }) async {
    await (_db.update(_db.chapters)..where((t) => t.id.equals(chapterId)))
        .write(ChaptersCompanion(name: Value(name.trim())));
  }

  @override
  Future<void> deleteChapter(int chapterId) async {
    // Lessons, exams, groups and homework go with it via ON DELETE CASCADE --
    // which only works because `PRAGMA foreign_keys = ON` is set in beforeOpen.
    await (_db.delete(_db.chapters)..where((t) => t.id.equals(chapterId))).go();
  }

  @override
  Future<void> markChapterMastered({
    required int chapterId,
    required DateTime at,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.chapters)..where((t) => t.id.equals(chapterId)))
          .write(ChaptersCompanion(masteredAt: Value(at)));

      // Mastering a chapter restarts the 30-day clock on everything inside it.
      await (_db.update(
        _db.lessons,
      )..where((t) => t.chapterId.equals(chapterId))).write(
        LessonsCompanion(
          lastReviewedAt: Value(at),
          // Clear notification bookkeeping: a new cycle deserves a new reminder.
          lastNotifiedAt: const Value<DateTime?>(null),
        ),
      );
    });
  }

  // --- Lessons --------------------------------------------------------------

  @override
  Future<int> createLesson({required int chapterId, required String name}) {
    return _db
        .into(_db.lessons)
        .insert(
          LessonsCompanion.insert(
            chapterId: chapterId,
            name: name.trim(),
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> renameLesson({
    required int lessonId,
    required String name,
  }) async {
    await (_db.update(_db.lessons)..where((t) => t.id.equals(lessonId))).write(
      LessonsCompanion(name: Value(name.trim())),
    );
  }

  @override
  Future<void> deleteLesson(int lessonId) async {
    await (_db.delete(_db.lessons)..where((t) => t.id.equals(lessonId))).go();
  }

  @override
  Future<void> updateChecklist({
    required int lessonId,
    required LessonChecklist checklist,
  }) async {
    await (_db.update(_db.lessons)..where((t) => t.id.equals(lessonId))).write(
      LessonsCompanion(
        watchedLesson: Value(checklist.watchedLesson),
        readNotes: Value(checklist.readNotes),
        didHomework: Value(checklist.didHomework),
        didExam: Value(checklist.didExam),
        reviewedNotes: Value(checklist.reviewedNotes),
      ),
    );
  }

  @override
  Future<void> markLessonNotified({
    required int lessonId,
    required DateTime at,
  }) async {
    await (_db.update(_db.lessons)..where((t) => t.id.equals(lessonId))).write(
      LessonsCompanion(lastNotifiedAt: Value(at)),
    );
  }

  // --- Exams ----------------------------------------------------------------

  @override
  Future<int> recordExam({
    required int lessonId,
    required List<DraftQuestionGroup> groups,
    required bool isReviewExam,
    required DateTime at,
  }) {
    return _db.transaction(() async {
      // Totals are derived here, never accepted from the caller, so a stored
      // percentage can never contradict the groups it came from.
      var possible = 0;
      var earned = 0;
      for (final g in groups) {
        possible += g.possiblePoints;
        earned += g.earnedPoints;
      }
      final percentage = possible <= 0 ? 0.0 : (earned / possible) * 100;

      final examId = await _db
          .into(_db.examEntries)
          .insert(
            ExamEntriesCompanion.insert(
              lessonId: lessonId,
              totalPossiblePoints: possible,
              correctPoints: earned,
              percentage: percentage,
              createdAt: at,
              isReviewExam: Value(isReviewExam),
            ),
          );

      await _db.batch((Batch batch) {
        batch.insertAll(_db.examQuestionGroups, <ExamQuestionGroupsCompanion>[
          for (final g in groups)
            ExamQuestionGroupsCompanion.insert(
              examId: examId,
              pointsPerQuestion: g.pointsPerQuestion,
              questionCount: g.questionCount,
              correctCount: g.correctCount,
            ),
        ]);
      });

      // Recording an exam is the *only* way to prove a lesson, so it always
      // restarts the review clock -- first exam or review exam alike.
      await (_db.update(
        _db.lessons,
      )..where((t) => t.id.equals(lessonId))).write(
        LessonsCompanion(
          lastReviewedAt: Value(at),
          lastNotifiedAt: const Value<DateTime?>(null),
          didExam: const Value(true),
        ),
      );

      return examId;
    });
  }

  @override
  Future<void> deleteExam(int examId) async {
    await (_db.delete(_db.examEntries)..where((t) => t.id.equals(examId))).go();
  }

  // --- Homework -------------------------------------------------------------

  @override
  Future<int> recordHomework({
    required int lessonId,
    required int score,
    required int maxScore,
    required DateTime at,
  }) {
    return _db
        .into(_db.homeworkEntries)
        .insert(
          HomeworkEntriesCompanion.insert(
            lessonId: lessonId,
            score: score,
            maxScore: maxScore,
            createdAt: at,
          ),
        );
  }

  @override
  Future<void> deleteHomework(int homeworkId) async {
    await (_db.delete(
      _db.homeworkEntries,
    )..where((t) => t.id.equals(homeworkId))).go();
  }

  // --- Mappers --------------------------------------------------------------

  Subject _toSubject(SubjectRow r) => Subject(
    id: r.id,
    code: SubjectCode.fromName(r.code),
    sortOrder: r.sortOrder,
  );

  Chapter _toChapter(ChapterRow r) => Chapter(
    id: r.id,
    subjectId: r.subjectId,
    name: r.name,
    createdAt: r.createdAt,
    masteredAt: r.masteredAt,
  );

  Lesson _toLesson(LessonRow r) => Lesson(
    id: r.id,
    chapterId: r.chapterId,
    name: r.name,
    createdAt: r.createdAt,
    lastReviewedAt: r.lastReviewedAt,
    lastNotifiedAt: r.lastNotifiedAt,
    checklist: LessonChecklist(
      watchedLesson: r.watchedLesson,
      readNotes: r.readNotes,
      didHomework: r.didHomework,
      didExam: r.didExam,
      reviewedNotes: r.reviewedNotes,
    ),
  );

  ExamEntry _toExam(ExamEntryRow r, List<ExamQuestionGroup> groups) =>
      ExamEntry(
        id: r.id,
        lessonId: r.lessonId,
        isReviewExam: r.isReviewExam,
        totalPossiblePoints: r.totalPossiblePoints,
        correctPoints: r.correctPoints,
        percentage: r.percentage,
        createdAt: r.createdAt,
        groups: groups,
      );

  HomeworkEntry _toHomework(HomeworkEntryRow r) => HomeworkEntry(
    id: r.id,
    lessonId: r.lessonId,
    score: r.score,
    maxScore: r.maxScore,
    createdAt: r.createdAt,
  );

  ExamQuestionGroup _toGroup(ExamQuestionGroupRow r) => ExamQuestionGroup(
    id: r.id,
    examId: r.examId,
    pointsPerQuestion: r.pointsPerQuestion,
    questionCount: r.questionCount,
    correctCount: r.correctCount,
  );
}

/// Minimal combineLatest for exactly six streams.
///
/// Hand-rolled rather than pulling in rxdart for one operator. Emits nothing
/// until every source has produced a value, then emits on each subsequent
/// change -- which is what makes a snapshot internally consistent.
Stream<R> _combineLatest6<A, B, C, D, E, F, R>(
  Stream<A> sa,
  Stream<B> sb,
  Stream<C> sc,
  Stream<D> sd,
  Stream<E> se,
  Stream<F> sf,
  R Function(A, B, C, D, E, F) combine,
) {
  late StreamController<R> controller;
  final subscriptions = <StreamSubscription<Object?>>[];

  A? a;
  B? b;
  C? c;
  D? d;
  E? e;
  F? f;
  final seen = List<bool>.filled(6, false);

  void emit() {
    if (seen.every((s) => s)) {
      controller.add(combine(a as A, b as B, c as C, d as D, e as E, f as F));
    }
  }

  void start() {
    void listen<T>(Stream<T> source, int index, void Function(T) assign) {
      subscriptions.add(
        source.listen((value) {
          assign(value);
          seen[index] = true;
          emit();
        }, onError: controller.addError),
      );
    }

    listen<A>(sa, 0, (v) => a = v);
    listen<B>(sb, 1, (v) => b = v);
    listen<C>(sc, 2, (v) => c = v);
    listen<D>(sd, 3, (v) => d = v);
    listen<E>(se, 4, (v) => e = v);
    listen<F>(sf, 5, (v) => f = v);
  }

  controller = StreamController<R>(
    onListen: start,
    onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
      subscriptions.clear();
    },
  );

  return controller.stream;
}
