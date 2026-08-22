import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/core/clock/clock.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_task_repository.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';

/// The day key a task is stored and compared under, against real SQLite.
///
/// The column holds an instant, and an instant only means "this day" under the
/// UTC offset it was written with. Egypt moves between +3 and +2 every year, so
/// keys that were local midnights came back reading 23:00 the previous evening
/// once the offset changed -- a task written in July fell off its own day every
/// winter, and back on again in summer, twice a year, silently.
///
/// The contract now is one canonical key per calendar day (midnight UTC,
/// produced by `dayOf`), normalised at every door it crosses: written through
/// it, read back through it, restored through it, and compared as day numbers.
///
/// Nothing here asks the host for its timezone: the values that go in and the
/// values asserted on are built explicitly, so the suite means the same thing
/// in July as it does in December.
void main() {
  late AppDatabase db;
  late DriftTaskRepository tasks;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tasks = DriftTaskRepository(db);
  });

  tearDown(() => db.close());

  group('the write path', () {
    test('stores midnight UTC, not local midnight', () async {
      await tasks.addTask(
        day: DateTime(2026, 7, 10),
        title: 'صيف',
        at: DateTime(2026, 7, 10, 18),
      );

      final rows = await db.select(db.dailyTasks).get();

      // Compared as instants, not DateTime equality: drift hands the stored
      // value back in the *reader's* zone, and `==` between DateTimes demands
      // matching UTC flags as well as matching moments. The instant is what
      // the key means -- and this instant is the same one a writer on +3, on
      // +2 or on UTC would have left, which is what makes the key survive the
      // yearly move between them.
      expect(
        rows.single.day.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 10).millisecondsSinceEpoch,
      );
      // And it is genuinely a midnight, not somebody's 23:00.
      expect(rows.single.day.toUtc().hour, 0);
    });

    test('midnight, noon and 23:59 of one day all land on one key', () async {
      await tasks.addTask(
        day: DateTime(2026, 12, 20, 23, 59),
        title: 'قبل منتصف الليل',
        at: DateTime(2026, 12, 20, 23, 59),
      );
      await tasks.addTask(
        day: DateTime(2026, 12, 20, 0, 0),
        title: 'بعد منتصف الليل',
        at: DateTime(2026, 12, 20, 0, 1),
      );
      await tasks.addTask(
        day: DateTime(2026, 12, 20, 12),
        title: 'الظهر',
        at: DateTime(2026, 12, 20, 12),
      );

      final keys = <int>{
        for (final r in await db.select(db.dailyTasks).get())
          r.day.millisecondsSinceEpoch,
      };
      expect(
        keys.single,
        DateTime.utc(2026, 12, 20).millisecondsSinceEpoch,
      );
    });
  });

  group('the read path', () {
    test('hands back exactly the key the write left', () async {
      await tasks.addTask(
        day: DateTime(2026, 7, 10),
        title: 'عادية',
        at: DateTime(2026, 7, 10, 9),
      );

      final task = await tasks.watchTasks().first;
      expect(task.single.day, DateTime.utc(2026, 7, 10));
    });

    test('normalises whatever the column held into a UTC midnight', () async {
      // Planted straight into the table rather than written through addTask:
      // this is a row from an older build, whose key was a local midnight and
      // which a shifted offset now serves back at 23:00 or 01:00. The read
      // re-truncates onto a midnight before any caller sees it -- screens and
      // providers never meet a raw column value again.
      await db
          .into(db.dailyTasks)
          .insert(
            DailyTasksCompanion.insert(
              day: DateTime.parse('2026-07-09T23:00:00.000Z'),
              title: 'مكتوبة على توقيت قديم',
              sortOrder: 0,
              createdAt: DateTime.parse('2026-07-09T21:00:00.000Z'),
            ),
          );

      final task = await tasks.watchTasks().first;
      // Whatever day the reader's zone puts that instant in, the entity carries
      // a midnight, not somebody's 23:00.
      expect(task.single.day.isUtc, isTrue);
      expect(task.single.day.hour, 0);
      expect(task.single.day.minute, 0);
      expect(task.single.day.second, 0);
    });
  });

  group('restore', () {
    test('re-truncates a foreign instant onto the day its fields name',
        () async {
      // A blob written on another phone can hand over any instant for `day`.
      // This one says "the 19th, late evening" in its own calendar fields; the
      // restored row is keyed to the 19th rather than carrying 23:30 around to
      // be re-interpreted by whoever reads it next.
      await tasks.restoreTasks(<DailyTask>[
        DailyTask(
          id: 1,
          day: DateTime.utc(2026, 12, 19, 23, 30),
          title: 'مهمة مستوردة',
          done: false,
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 12, 19, 22),
        ),
      ]);

      final task = await tasks.watchTasks().first;
      expect(task.single.day, DateTime.utc(2026, 12, 19));
    });

    test('a backup round trip keeps the calendar day', () async {
      final original = DailyTask(
        id: 4,
        day: DateTime.utc(2026, 8, 5),
        title: 'مراجعة',
        done: true,
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 8, 5, 14),
      );

      final json = StudyBackup(
        subjects: const <Subject>[
          Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
        ],
        chapters: const <Chapter>[],
        lessons: const <Lesson>[],
        exams: const <ExamEntry>[],
        homework: const <HomeworkEntry>[],
        tasks: <DailyTask>[original],
      ).toJson();

      // Through real JSON text, as the wire carries it.
      final parsed = StudyBackup.fromJson(json);
      await tasks.restoreTasks(parsed.tasks);

      final task = await tasks.watchTasks().first;
      expect(task.single.id, 4);
      expect(task.single.done, isTrue);
      // Symmetric by construction, not pinned to a calendar date: the wire
      // carries an instant, and the reader re-truncates it with its own
      // offset -- so the guarantee is "the same day the reader's dayOf
      // assigns", which holds under any host timezone. (Egypt sits east of
      // UTC, where that day is August 5th itself.)
      expect(task.single.day, dayOf(original.day));
    });
  });

  group('comparison in the providers', () {
    /// The task list is handed to `tasksValueProvider` directly rather than
    /// through its upstream stream provider: a plain value needs no listener
    /// bookkeeping, and these tests are about the *comparison*, not the
    /// plumbing above it.
    ProviderContainer containerWith(List<DailyTask> tasks) =>
        ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(MutableClock(DateTime(2026, 8, 5))),
            tasksValueProvider.overrideWithValue(tasks),
          ],
        );

    bool hasTitle(List<DailyTask> tasks, String title) =>
        tasks.any((t) => t.title == title);

    test('a day owns every task whose day number matches it, whatever '
        'instant the row carries', () {
      final container = containerWith(<DailyTask>[
        DailyTask(
          id: 1,
          // The canonical form the repository writes.
          day: DateTime.utc(2026, 8, 5),
          title: 'عادية',
          done: false,
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 8, 5, 9),
        ),
        DailyTask(
          id: 2,
          // Built as a *local* midnight rather than the canonical one: one
          // calendar day, two different instants -- and on anything but a UTC
          // machine, two different `==`. Raw equality against the selected day
          // split rows like this from their own day twice a year; the day
          // number must not.
          day: DateTime(2026, 8, 5),
          title: 'من توقيت آخر',
          done: false,
          sortOrder: 1,
          createdAt: DateTime.utc(2026, 8, 4, 21),
        ),
        DailyTask(
          id: 3,
          day: DateTime.utc(2026, 8, 4),
          title: 'أمس',
          done: true,
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 8, 4, 10),
        ),
      ]);
      addTearDown(container.dispose);

      final onScreen = container.read(tasksForSelectedDayProvider);
      expect(hasTitle(onScreen, 'عادية'), isTrue);
      expect(hasTitle(onScreen, 'من توقيت آخر'), isTrue);
      expect(hasTitle(onScreen, 'أمس'), isFalse);

      // And the selection itself is canonical, so the same comparison holds
      // when the student picks another day and comes back.
      expect(container.read(selectedTaskDayProvider), DateTime.utc(2026, 8, 5));
    });

    test('selecting a day normalises the moment handed over', () {
      final container = containerWith(<DailyTask>[
        DailyTask(
          id: 3,
          day: DateTime.utc(2026, 8, 4),
          title: 'أمس',
          done: true,
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 8, 4, 10),
        ),
        DailyTask(
          id: 1,
          day: DateTime.utc(2026, 8, 5),
          title: 'عادية',
          done: false,
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 8, 5, 9),
        ),
      ]);
      addTearDown(container.dispose);

      container
          .read(selectedTaskDayProvider.notifier)
          .select(DateTime(2026, 8, 4, 23, 59));

      final onScreen = container.read(tasksForSelectedDayProvider);
      expect(hasTitle(onScreen, 'أمس'), isTrue);
      expect(hasTitle(onScreen, 'عادية'), isFalse);
      expect(container.read(selectedTaskDayProvider), DateTime.utc(2026, 8, 4));
    });

    test('completion groups by canonical day rather than raw instant', () {
      final container = containerWith(<DailyTask>[
        DailyTask(
          id: 3,
          day: DateTime.utc(2026, 8, 4),
          title: 'أمس',
          done: true,
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 8, 4, 10),
        ),
        DailyTask(
          id: 1,
          day: DateTime.utc(2026, 8, 5),
          title: 'عادية',
          done: false,
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 8, 5, 9),
        ),
        DailyTask(
          id: 2,
          day: DateTime(2026, 8, 5),
          title: 'من توقيت آخر',
          done: false,
          sortOrder: 1,
          createdAt: DateTime.utc(2026, 8, 4, 21),
        ),
      ]);
      addTearDown(container.dispose);

      final complete = container.read(taskCompleteDaysProvider);

      // Aug 4 has one task, done -> complete. Aug 5 has two, neither done ->
      // not. The two same-day rows built from different instants must count
      // once, under one key, or the circle would flicker between days twice
      // a year.
      expect(complete, <DateTime>{DateTime.utc(2026, 8, 4)});
    });

    test('a day is not complete while any of its tasks is open', () {
      final container = containerWith(<DailyTask>[
        DailyTask(
          id: 1,
          day: DateTime.utc(2026, 8, 5),
          title: 'عادية',
          done: false,
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 8, 5, 9),
        ),
      ]);
      addTearDown(container.dispose);

      container
          .read(selectedTaskDayProvider.notifier)
          .select(DateTime(2026, 8, 5));

      final complete = container.read(taskCompleteDaysProvider);
      expect(complete.contains(DateTime.utc(2026, 8, 5)), isFalse);
    });
  });
}
