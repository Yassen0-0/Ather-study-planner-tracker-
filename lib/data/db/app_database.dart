import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../domain/entities/subject.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Fixed seed order for the four subjects. Ids are stable so the seed is
/// idempotent and chapters never end up pointing at a renumbered subject.
const List<SubjectCode> kSeededSubjects = <SubjectCode>[
  SubjectCode.biology,
  SubjectCode.physics,
  SubjectCode.chemistry,
  SubjectCode.english,
];

@DriftDatabase(
  tables: <Type>[
    Subjects,
    Chapters,
    Lessons,
    HomeworkEntries,
    ExamEntries,
    ExamQuestionGroups,
    DailyTasks,
    StudyEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    // The file keeps its original name through the Ather rebrand on purpose:
    // renaming it would orphan every database already on a student's phone.
    : super(executor ?? driftDatabase(name: 'sahm'));

  /// 2 added `daily_tasks`. 3 added `subjects.name`, `subjects.archived_at` and
  /// `subjects.deleted_at`, which is what made subjects something a student can
  /// add, archive, and delete into a recycle bin.
  ///
  /// **4 added the `study_events` capture log** (1.8.0+14) -- and with it, the
  /// paragraph above stopped being hypothetical: every future column gets its
  /// own step in [migration]'s ladder.
  ///
  /// **5 added `daily_tasks.surrendered`** (the استسلام state) as a plain
  /// `ALTER TABLE ... ADD COLUMN ... NOT NULL DEFAULT 0` -- the one additive
  /// statement SQLite allows on a table with rows in it, so no task a student
  /// has ever written is read, rewritten or dropped on the way up. Its test is
  /// the Rule-1 gate: 1.8.0+15 sits on real phones holding real history.
  ///
  /// Every student on an earlier build already has an older file on disk, so
  /// this number and [migration]'s `onUpgrade` move together -- bumping one
  /// without the other opens the app against a database missing a column it is
  /// about to read.
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedSubjects();
    },
    // `onCreate` does not run for an existing install, so without this a
    // student who has been using the app since v1 opens it to a missing
    // `daily_tasks` and a crash on the first read.
    //
    // Additive only: new tables and new nullable columns, nothing dropped and
    // nothing rewritten. The student's curriculum is the one thing in this
    // file that cannot be regenerated.
    //
    // **Safe against process death between two statements (D3).** drift does
    // not run this callback in a transaction, and it writes `user_version`
    // only after the callback returns. A phone killed between, say, the first
    // and second `addColumn` of step 3 used to reopen at version 2 with
    // `subjects.name` already present -- and every later open failed on
    // "duplicate column name", an app that can never open its own data again.
    // Two independent guards now:
    //
    // * the whole ladder runs in one transaction, with the new version
    //   written *inside* it. SQLite's DDL is transactional and so is
    //   `user_version`: a death anywhere rolls every step back to the
    //   version the file claims;
    // * every step is idempotent anyway -- `createTable` is
    //   `CREATE TABLE IF NOT EXISTS`, columns go through [_addColumnIfMissing],
    //   the seed is insert-or-ignore. That is what heals a file already left
    //   half-migrated by a build without the transaction: a rollback cannot
    //   rescue a step that has already been committed.
    onUpgrade: (Migrator m, int from, int to) async {
      try {
        await transaction(() async {
          await _upgrade(m, from);
          // Inside the transaction, so it commits or rolls back with the
          // steps. drift writes the same value again once this returns.
          await customStatement('PRAGMA user_version = $to');
        });
      } catch (error, stack) {
        // Report non-fatal error to Crashlytics before rethrowing.
        // Migration failures are critical: they prevent the app from opening
        // and can leave a student's database in an inconsistent state.
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
        rethrow;
      }
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite ignores foreign keys unless this is switched on per
      // connection. Without it every ON DELETE CASCADE in tables.dart is
      // silently inert and deleting a chapter orphans its lessons.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The version ladder itself. Each step may find its work already done --
  /// see the D3 note on [migration] -- and must then do nothing.
  Future<void> _upgrade(Migrator m, int from) async {
    if (from < 2) await m.createTable(dailyTasks);
    if (from < 3) {
      await _addColumnIfMissing(m, subjects, subjects.name);
      await _addColumnIfMissing(m, subjects, subjects.archivedAt);
      await _addColumnIfMissing(m, subjects, subjects.deletedAt);
      // The last time the seed is ever allowed to run against an existing
      // database. It covers a file created before a seed change, and it can
      // only add rows the student never had the ability to delete -- because
      // until this very migration, they did not.
      await _seedSubjects();
    }
    if (from < 4) {
      // 4 added the capture-only study event log. Written by nothing
      // before it existed, so the upgrade has exactly one job: make the
      // table exist, and leave every other byte alone.
      await m.createTable(studyEvents);
    }
    if (from < 5 && from >= 2) {
      // 5 added the surrender flag. ADD COLUMN with DEFAULT 0 is the only
      // shape that can run against a table holding rows: SQLite applies
      // the default to every existing row in place -- pre-existing tasks
      // were never surrendered, and they now say so -- while nothing is
      // rewritten and the done flags keep every value they had.
      //
      // Skipped when the climb starts below 2: there `daily_tasks` did
      // not exist yet, and `createTable` above built it straight to the
      // current shape -- column included -- so adding it again would fail
      // on a duplicate column name.
      await _addColumnIfMissing(m, dailyTasks, dailyTasks.surrendered);
    }
  }

  /// `ALTER TABLE ... ADD COLUMN`, unless the column is already there.
  ///
  /// SQLite has no `ADD COLUMN IF NOT EXISTS`, so the table is asked first.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final columns = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    if (columns.any((row) => row.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

  /// Puts the subjects table back to exactly the four Ather ships with.
  ///
  /// For account deletion only. "Everything on this device" has to include the
  /// subjects a student added, but it must not leave the table empty: the seed
  /// runs on create and on the 2 -> 3 migration and nowhere else, so a wiped
  /// table would still be wiped when they signed in again -- an app with no
  /// subjects and no way to get the original four back.
  Future<void> resetSubjectsToSeed() async {
    await transaction(() async {
      await delete(subjects).go();
      await _seedSubjects();
    });
  }

  /// Writes the four Ather ships with, at fixed ids.
  ///
  /// **This must never run on an ordinary open again.** It used to, from
  /// `beforeOpen`, described as making the seed "self-healing if a row is ever
  /// lost" -- which was true and harmless while nothing could remove a subject.
  /// The moment subjects became deletable, the same line became a guarantee
  /// that every subject a student deleted would be back the next time they
  /// opened the app. It now runs exactly twice in a database's life: once on
  /// create, and once during the 2 -> 3 migration.
  Future<void> _seedSubjects() async {
    await batch((Batch batch) {
      for (var i = 0; i < kSeededSubjects.length; i++) {
        batch.insert(
          subjects,
          SubjectsCompanion.insert(
            id: Value(i + 1),
            code: kSeededSubjects[i].name,
            sortOrder: i,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }
}
