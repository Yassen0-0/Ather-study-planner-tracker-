import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    // The file keeps its original name through the Ather rebrand on purpose:
    // renaming it would orphan every database already on a student's phone.
    : super(executor ?? driftDatabase(name: 'sahm'));

  /// 2 added `daily_tasks`. Every student on an earlier build already has a v1
  /// file on disk, so this number and [migration]'s `onUpgrade` move together --
  /// bumping one without the other opens the app against a database missing a
  /// table it is about to read.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedSubjects();
    },
    // The app's first migration. `onCreate` does not run for an existing
    // install, so without this a student who has been using the app since v1
    // opens it to a missing `daily_tasks` and a crash on the first read.
    //
    // Additive only: a new table, nothing dropped, nothing rewritten. The
    // student's curriculum is the one thing in this file that cannot be
    // regenerated.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) await m.createTable(dailyTasks);
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite ignores foreign keys unless this is switched on per
      // connection. Without it every ON DELETE CASCADE in tables.dart is
      // silently inert and deleting a chapter orphans its lessons.
      await customStatement('PRAGMA foreign_keys = ON');

      // Covers databases created before a seed change, and makes the seed
      // self-healing if a row is ever lost.
      await _seedSubjects();
    },
  );

  /// Inserts any missing subject rows. Safe to run on every open.
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
