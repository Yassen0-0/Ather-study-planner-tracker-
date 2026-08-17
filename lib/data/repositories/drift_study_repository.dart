import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/entities/chapter.dart';
import '../../domain/entities/exam_entry.dart';
import '../../domain/entities/homework_entry.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/study_backup.dart';
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

  // --- Subjects -------------------------------------------------------------

  @override
  Future<int> createSubject({required String name}) async {
    // `max(id) + 1` rather than an autoincrement: the column was declared as a
    // plain integer primary key so the seed could write fixed ids, and
    // changing that now would mean rewriting the table the whole curriculum
    // hangs off. Inside a transaction, so two quick taps cannot both read the
    // same maximum.
    return _db.transaction(() async {
      final rows = await _db.select(_db.subjects).get();
      final nextId = rows.fold<int>(0, (m, r) => r.id > m ? r.id : m) + 1;
      final nextOrder =
          rows.fold<int>(-1, (m, r) => r.sortOrder > m ? r.sortOrder : m) + 1;

      await _db
          .into(_db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: Value(nextId),
              code: kCustomSubjectCode,
              name: Value(name.trim()),
              sortOrder: nextOrder,
            ),
          );
      return nextId;
    });
  }

  @override
  Future<void> renameSubject({
    required int subjectId,
    required String name,
  }) async {
    // Scoped to custom subjects in SQL, not just in the screen: a seeded
    // subject's name lives in the ARB files, and a row that disagreed with
    // them would show one language's name under the other language's toggle.
    await (_db.update(_db.subjects)..where(
          (t) => t.id.equals(subjectId) & t.code.equals(kCustomSubjectCode),
        ))
        .write(SubjectsCompanion(name: Value(name.trim())));
  }

  @override
  Future<void> setSubjectArchived({
    required int subjectId,
    required DateTime? at,
  }) async {
    await (_db.update(_db.subjects)..where((t) => t.id.equals(subjectId)))
        .write(SubjectsCompanion(archivedAt: Value(at)));
  }

  @override
  Future<void> setSubjectDeleted({
    required int subjectId,
    required DateTime? at,
  }) async {
    // A flag, not a delete. The row and everything hanging off it stay exactly
    // where they are; only its visibility changes. That is what lets the
    // screen offer "delete" without a guard -- there is nothing yet to guard.
    await (_db.update(_db.subjects)..where((t) => t.id.equals(subjectId)))
        .write(SubjectsCompanion(deletedAt: Value(at)));
  }

  @override
  Future<void> purgeSubject(int subjectId) async {
    // The cascade finally firing: chapters go, and lessons, exams, groups and
    // homework go with them. The only irreversible operation in the feature,
    // and the reason the recycle bin exists between it and the student.
    await (_db.delete(_db.subjects)..where((t) => t.id.equals(subjectId))).go();
  }

  // --- Chapters -------------------------------------------------------------

  @override
  Future<int> createChapter({
    required int subjectId,
    required String name,
    required DateTime at,
  }) {
    return _db
        .into(_db.chapters)
        .insert(
          ChaptersCompanion.insert(
            subjectId: subjectId,
            name: name.trim(),
            createdAt: at,
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
  Future<int> createLesson({
    required int chapterId,
    required String name,
    required DateTime at,
  }) {
    return _db
        .into(_db.lessons)
        .insert(
          LessonsCompanion.insert(
            chapterId: chapterId,
            name: name.trim(),
            createdAt: at,
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
  Future<void> deleteExam(int examId) {
    // Deleting the evidence has to move the clock that evidence started.
    //
    // `recordExam` stamps `lastReviewedAt` from the exam it just wrote. Removing
    // that exam without touching the stamp leaves a lesson counting down from a
    // date nothing in the database supports any more -- so a student who deletes
    // a mistyped entry keeps a review clock they never earned, and mastery (which
    // *is* derived) and the clock (which is not) start telling different stories.
    return _db.transaction(() async {
      final exam = await (_db.select(
        _db.examEntries,
      )..where((t) => t.id.equals(examId))).getSingleOrNull();
      if (exam == null) return;

      final lessonId = exam.lessonId;
      await (_db.delete(
        _db.examEntries,
      )..where((t) => t.id.equals(examId))).go();

      // The newest exam still standing, if any.
      final remaining =
          await (_db.select(_db.examEntries)
                ..where((t) => t.lessonId.equals(lessonId))
                ..orderBy(<OrderClauseGenerator<$ExamEntriesTable>>[
                  (t) => OrderingTerm(
                    expression: t.createdAt,
                    mode: OrderingMode.desc,
                  ),
                  (t) =>
                      OrderingTerm(expression: t.id, mode: OrderingMode.desc),
                ])
                ..limit(1))
              .getSingleOrNull();

      // "أتقنت الباب" also restarts the clock (see markChapterMastered), and it
      // is not an exam -- so it has to be considered here too, or deleting one
      // exam would quietly undo a chapter the student legitimately closed out.
      final lesson = await (_db.select(
        _db.lessons,
      )..where((t) => t.id.equals(lessonId))).getSingleOrNull();
      final chapter = lesson == null
          ? null
          : await (_db.select(
              _db.chapters,
            )..where((t) => t.id.equals(lesson.chapterId))).getSingleOrNull();

      final DateTime? fromExam = remaining?.createdAt;
      final DateTime? fromMastery = chapter?.masteredAt;
      final DateTime? proven = switch ((fromExam, fromMastery)) {
        (null, null) => null,
        (final DateTime e, null) => e,
        (null, final DateTime m) => m,
        (final DateTime e, final DateTime m) => e.isAfter(m) ? e : m,
      };

      await (_db.update(
        _db.lessons,
      )..where((t) => t.id.equals(lessonId))).write(
        LessonsCompanion(
          lastReviewedAt: Value<DateTime?>(proven),
          // The remaining cycle is a different one from the cancelled reminder's.
          lastNotifiedAt: const Value<DateTime?>(null),
        ),
      );
    });
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

  // --- Restore --------------------------------------------------------------

  @override
  Future<void> restore(StudyBackup backup) {
    // One transaction around the delete and every insert. drift rolls the whole
    // thing back if any statement throws, which is the only reason it is safe to
    // delete the student's data before knowing the inserts will succeed.
    return _db.transaction(() async {
      // Chapters cascade to lessons, exams, groups and homework, so this one
      // delete empties everything a backup owns. Daily tasks have no foreign
      // key and are handled by DriftTaskRepository.restore.
      await _db.delete(_db.chapters).go();

      // Subjects are replaced wholesale, and only when the backup carries them
      // -- a version 1 file has none, and wiping the seeded four on its behalf
      // would leave every chapter it is about to insert pointing at nothing.
      //
      // Safe to delete first because the chapters that referenced them are
      // already gone in this same transaction; doing it in the other order
      // would trip the foreign key or cascade the incoming chapters away.
      if (backup.subjects.isNotEmpty) {
        await _db.delete(_db.subjects).go();
      }

      await _db.batch((Batch batch) {
        batch.insertAll(_db.subjects, <SubjectsCompanion>[
          for (final s in backup.subjects)
            SubjectsCompanion.insert(
              id: Value(s.id),
              code: s.code?.name ?? kCustomSubjectCode,
              name: Value(s.name),
              archivedAt: Value(s.archivedAt),
              deletedAt: Value(s.deletedAt),
              sortOrder: s.sortOrder,
            ),
        ]);

        batch.insertAll(_db.chapters, <ChaptersCompanion>[
          for (final c in backup.chapters)
            ChaptersCompanion.insert(
              // Explicit id on an autoincrement column: the relationships in the
              // rows below are made of these numbers.
              id: Value(c.id),
              subjectId: c.subjectId,
              name: c.name,
              createdAt: c.createdAt,
              masteredAt: Value(c.masteredAt),
            ),
        ]);

        batch.insertAll(_db.lessons, <LessonsCompanion>[
          for (final l in backup.lessons)
            LessonsCompanion.insert(
              id: Value(l.id),
              chapterId: l.chapterId,
              name: l.name,
              createdAt: l.createdAt,
              lastReviewedAt: Value(l.lastReviewedAt),
              lastNotifiedAt: Value(l.lastNotifiedAt),
              watchedLesson: Value(l.checklist.watchedLesson),
              readNotes: Value(l.checklist.readNotes),
              didHomework: Value(l.checklist.didHomework),
              didExam: Value(l.checklist.didExam),
              reviewedNotes: Value(l.checklist.reviewedNotes),
            ),
        ]);

        batch
          ..insertAll(_db.examEntries, <ExamEntriesCompanion>[
            for (final e in backup.exams)
              ExamEntriesCompanion.insert(
                id: Value(e.id),
                lessonId: e.lessonId,
                isReviewExam: Value(e.isReviewExam),
                totalPossiblePoints: e.totalPossiblePoints,
                correctPoints: e.correctPoints,
                // Carried, never recomputed: a past exam's score must stay
                // historically stable.
                percentage: e.percentage,
                createdAt: e.createdAt,
              ),
          ])
          ..insertAll(_db.examQuestionGroups, <ExamQuestionGroupsCompanion>[
            for (final e in backup.exams)
              for (final g in e.groups)
                ExamQuestionGroupsCompanion.insert(
                  id: Value(g.id),
                  examId: e.id,
                  pointsPerQuestion: g.pointsPerQuestion,
                  questionCount: g.questionCount,
                  correctCount: g.correctCount,
                ),
          ])
          ..insertAll(_db.homeworkEntries, <HomeworkEntriesCompanion>[
            for (final h in backup.homework)
              HomeworkEntriesCompanion.insert(
                id: Value(h.id),
                lessonId: h.lessonId,
                score: h.score,
                maxScore: h.maxScore,
                createdAt: h.createdAt,
              ),
          ]);
      });
    });
  }

  @override
  Future<void> clear() {
    // Account deletion. Chapters cascade to lessons, exams, groups and
    // homework, and the subjects go back to the four Ather ships with --
    // including any the student added, which are as much "everything on this
    // device" as a chapter is.
    //
    // Reset rather than delete: the seed only runs on create and on the 2 -> 3
    // migration, so an emptied table stays empty, and the student would sign in
    // again to an app with no subjects at all.
    return _db.transaction(() async {
      await _db.delete(_db.chapters).go();
      await _db.resetSubjectsToSeed();
    });
  }

  // --- Mappers --------------------------------------------------------------

  /// An unrecognised code is a subject the student added, not an error. It has
  /// to stay that way: a row written by a newer build must never crash an
  /// older one on read.
  Subject _toSubject(SubjectRow r) => Subject(
    id: r.id,
    code: SubjectCode.tryFromName(r.code),
    name: r.name,
    sortOrder: r.sortOrder,
    archivedAt: r.archivedAt,
    deletedAt: r.deletedAt,
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
/// How long the combined snapshot stream waits for a burst of table events to
/// finish before emitting.
///
/// One frame. Named rather than inlined because it is a real [Timer], so tests
/// have to outwait it -- `pumpEventQueue` drains microtasks and will not move
/// a timer -- and a test hardcoding `16` would silently stop covering this the
/// day the window changed.
const Duration kSnapshotCoalesceWindow = Duration(milliseconds: 16);

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
  Timer? coalesce;

  void publish() {
    coalesce = null;
    if (controller.isClosed) return;
    if (!seen.every((s) => s)) return;
    controller.add(combine(a as A, b as B, c as C, d as D, e as E, f as F));
  }

  /// Emits **once** per burst rather than once per contributing table.
  ///
  /// Six drift streams feed this, and one write usually touches several of
  /// them: saving an exam writes `exam_entries`, `exam_question_groups` and
  /// `lessons`, so three streams fire and this combined once per stream --
  /// three identical rebuilds of the entire snapshot for one action.
  ///
  /// That is not a cheap thing to do three times. Each emission rebuilds every
  /// entity in the record, reruns `Summaries.dashboard` over the whole
  /// curriculum, and rebuilds `AppShell` -- the widget holding the app's only
  /// `BackdropFilter`, which is the most expensive thing it draws.
  ///
  /// One frame is the right window: long enough to swallow a whole
  /// transaction's worth of table events, short enough that no student can
  /// perceive it. Every emission still arrives; they are merely not repeated.
  void emit() {
    coalesce?.cancel();
    coalesce = Timer(kSnapshotCoalesceWindow, publish);
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
      // Cancelled before the subscriptions: a coalescing timer that fires
      // after the controller closes would add to a closed stream.
      coalesce?.cancel();
      coalesce = null;
      for (final s in subscriptions) {
        await s.cancel();
      }
      subscriptions.clear();
    },
  );

  return controller.stream;
}
