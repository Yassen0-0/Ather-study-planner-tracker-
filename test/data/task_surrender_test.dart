import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_task_repository.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/study_backup.dart';

/// The surrender state -- استسلام -- end to end against real SQLite.
///
/// A surrendered task is one the student gave up on: counted as failure,
/// distinct from deleting the task and distinct from finishing it. Two
/// properties are held here rather than trusted. The first is persistence --
/// the flag survives a watch, a restore and a backup round-trip, because a
/// state that silently reverts is worse than no state at all. The second is
/// exclusivity -- success and surrender cannot both be true on one row, no
/// matter what order the calls arrive in.
void main() {
  late AppDatabase db;
  late DriftTaskRepository tasks;

  final DateTime t0 = DateTime.fromMillisecondsSinceEpoch(1754300000000);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tasks = DriftTaskRepository(db);
  });

  tearDown(() => db.close());

  Future<int> task() => db
      .into(db.dailyTasks)
      .insert(
        DailyTasksCompanion.insert(
          day: dayOf(DateTime(2026, 8, 5)),
          title: 'أذاكر',
          sortOrder: 0,
          createdAt: t0,
        ),
      );

  Future<DailyTaskRow> row(int id) =>
      (db.select(db.dailyTasks)..where((t) => t.id.equals(id))).getSingle();

  Future<List<StudyEventRow>> events() => db.select(db.studyEvents).get();

  group('surrendering', () {
    test('sets the flag and records one event', () async {
      final id = await task();

      await tasks.setTaskSurrendered(taskId: id, surrendered: true);

      final r = await row(id);
      expect(r.surrendered, isTrue);
      // An unticked task was never done, so nothing else had to move.
      expect(r.done, isFalse);

      final rows = await events();
      expect(rows, hasLength(1));
      expect(rows.single.type, StudyEvent.typeTaskSurrendered);
      expect(rows.single.refId, id);
    });

    test('clears a success set before it', () async {
      // The exclusivity rule in its most natural order: ticked by mistake,
      // then given up on. One row may not claim both.
      final id = await task();
      await tasks.setTaskDone(taskId: id, done: true);

      await tasks.setTaskSurrendered(taskId: id, surrendered: true);

      final r = await row(id);
      expect(r.surrendered, isTrue);
      expect(r.done, isFalse);
    });

    test('un-surrendering leaves the done flag alone', () async {
      // Taking back a surrender means "not yet", never "done": only an
      // explicit tick may set success.
      final id = await task();
      await tasks.setTaskSurrendered(taskId: id, surrendered: true);

      await tasks.setTaskSurrendered(taskId: id, surrendered: false);

      final r = await row(id);
      expect(r.surrendered, isFalse);
      expect(r.done, isFalse);
    });

    test('an identical surrender writes nothing new', () async {
      final id = await task();
      await tasks.setTaskSurrendered(taskId: id, surrendered: true);

      await tasks.setTaskSurrendered(taskId: id, surrendered: true);

      expect(await events(), hasLength(1));
    });

    test('a flip on a missing task neither crashes nor records', () async {
      await tasks.setTaskSurrendered(taskId: 999, surrendered: true);
      expect(await events(), isEmpty);
    });
  });

  group('ticking revokes a surrender', () {
    test('done=true clears the flag in the same write', () async {
      final id = await task();
      await tasks.setTaskSurrendered(taskId: id, surrendered: true);

      await tasks.setTaskDone(taskId: id, done: true);

      final r = await row(id);
      expect(r.done, isTrue);
      expect(r.surrendered, isFalse);
      // The history shows what happened: one surrender, then the success.
      // No phantom "untick" event, because the student never performed one.
      expect(
        (await events()).map((e) => e.type),
        <String>[
          StudyEvent.typeTaskSurrendered,
          StudyEvent.typeTaskDone,
        ],
      );
    });

    test('a plain tick on a normal task behaves exactly as before', () async {
      // Guarding the rewrite of setTaskDone: the common path must be
      // indistinguishable from the one that shipped before surrender existed.
      final id = await task();
      await tasks.setTaskDone(taskId: id, done: false);

      expect(await events(), isEmpty);

      await tasks.setTaskDone(taskId: id, done: true);
      final r = await row(id);
      expect(r.done, isTrue);
      expect(r.surrendered, isFalse);
      expect(await events(), hasLength(1));
    });
  });

  group('reading and restoring', () {
    test('watchTasks carries the flag', () async {
      final id = await task();
      await tasks.setTaskSurrendered(taskId: id, surrendered: true);

      final watched = await tasks.watchTasks().first;

      expect(watched.single.id, id);
      expect(watched.single.surrendered, isTrue);
      expect(watched.single.done, isFalse);
    });

    test('restoreTasks puts a surrendered row back as surrendered', () async {
      // What a cloud restore does to every task: deletes the table's contents
      // and writes the backup's rows back with their ids kept. A flag lost
      // here would look to the student like the app quietly forgiving them.
      final restored = DailyTask(
        id: 12,
        day: dayOf(t0),
        title: 'استسلمت منها',
        done: false,
        surrendered: true,
        sortOrder: 3,
        createdAt: t0,
      );

      await tasks.restoreTasks(<DailyTask>[restored]);

      final watched = await tasks.watchTasks().first;
      expect(watched.single.id, 12);
      expect(watched.single.title, 'استسلمت منها');
      expect(watched.single.surrendered, isTrue);
      expect(watched.single.done, isFalse);
    });
  });
}
