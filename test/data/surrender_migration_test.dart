import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/data/db/app_database.dart';

/// The 4 -> 5 migration, against a real file on disk.
///
/// Same method as [study_events_migration_test] and for the same reason: every
/// student already carries an older database file, `onCreate` does not run for
/// them, and a migration that dropped or recreated `daily_tasks` would take
/// every task they ever wrote with it. Version 5 adds only one column --
/// `daily_tasks.surrendered` -- so the upgrade has exactly one job: put the
/// column on with `DEFAULT 0`, leave every existing row exactly as it was,
/// and let the default read back as false rather than null.
///
/// This is the Rule-1 gate: 1.8.0+15 is on real phones holding real task
/// history, and this file is what proves the next APK opens its database.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ather_migration');
    file = File('${dir.path}/sahm.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  AppDatabase open() => AppDatabase(NativeDatabase(file));

  /// Writes a genuine v4 image: let drift build the current schema, then take
  /// away exactly what version 5 adds and put the version marker back.
  ///
  /// Hand-writing the v4 DDL would be writing drift's own column naming and
  /// type mapping from memory, and a single mismatch would make this test pass
  /// against a schema no student has ever had.
  Future<void> seedV4Database() async {
    final db = open();
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            subjectId: 1,
            name: 'الباب الأول — الخلية',
            createdAt: DateTime(2026, 7, 1),
          ),
        );
    // Two tasks, one of them ticked done: precisely the state the upgrade must
    // carry through untouched. Success survives as success, and the new column
    // arrives false for both -- never null, never an exception.
    await db
        .into(db.dailyTasks)
        .insert(
          DailyTasksCompanion.insert(
            day: DateTime(2026, 8, 5),
            title: 'أذاكر',
            sortOrder: 0,
            createdAt: DateTime(2026, 8, 5),
          ),
        );
    await db
        .into(db.dailyTasks)
        .insert(
          DailyTasksCompanion.insert(
            day: DateTime(2026, 8, 5),
            title: 'أراجع',
            sortOrder: 1,
            createdAt: DateTime(2026, 8, 5),
          ),
        );
    await (db.update(db.dailyTasks)..where((t) => t.id.equals(1))).write(
      const DailyTasksCompanion(done: Value(true)),
    );

    await db.customStatement('ALTER TABLE daily_tasks DROP COLUMN surrendered');
    await db.customStatement('PRAGMA user_version = 4');
    await db.close();
  }

  test('upgrading from v4 adds surrendered as false and keeps every row', () async {
    await seedV4Database();

    final db = open();
    addTearDown(db.close);

    // Every pre-existing row survived field for field -- including the done
    // flag whose meaning the new column sits beside without touching.
    final rows = await db.select(db.dailyTasks).get();
    expect(rows.map((r) => r.title), <String>['أذاكر', 'أراجع']);
    expect(rows.map((r) => r.sortOrder), <int>[0, 1]);
    final doneRow = rows.firstWhere((r) => r.id == 1);
    expect(doneRow.done, isTrue);
    // The upgrade's whole promise: the column exists on rows that predate it,
    // reading false rather than null or a missing-column error.
    expect(rows.every((r) => r.surrendered == false), isTrue);

    // And the table is writable in both new directions: a row inserted without
    // naming the column lands on the SQL DEFAULT...
    await db
        .into(db.dailyTasks)
        .insert(
          DailyTasksCompanion.insert(
            day: DateTime(2026, 8, 6),
            title: 'جديدة',
            sortOrder: 0,
            createdAt: DateTime(2026, 8, 6),
          ),
        );
    // ...and a surrendered write lands too.
    await (db.update(db.dailyTasks)..where((t) => t.title.equals('جديدة'))).write(
      const DailyTasksCompanion(surrendered: Value(true)),
    );
    final surrenderedRow =
        await (db.select(db.dailyTasks)..where((t) => t.title.equals('جديدة')))
            .getSingle();
    expect(surrenderedRow.surrendered, isTrue);
    expect(surrenderedRow.done, isFalse);

    // Nothing the student built was touched on the way.
    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(1));
    expect(chapters.single.name, 'الباب الأول — الخلية');

    expect(db.schemaVersion, 5); // 5 = tasks.surrendered
  });

  test('upgrading from v2 passes through every step and still adds everything', () async {
    // A phone that skipped versions 3 and 4 entirely walks all three steps on
    // first launch of this build.
    final db = open();
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            subjectId: 1,
            name: 'الباب الأول',
            createdAt: DateTime(2026, 7, 1),
          ),
        );
    await db.customStatement('ALTER TABLE subjects DROP COLUMN name');
    await db.customStatement('ALTER TABLE subjects DROP COLUMN archived_at');
    await db.customStatement('ALTER TABLE subjects DROP COLUMN deleted_at');
    await db.customStatement('DROP TABLE study_events');
    await db.customStatement('ALTER TABLE daily_tasks DROP COLUMN surrendered');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    final upgraded = open();
    addTearDown(upgraded.close);

    // The ladder's newest rung works after the longest climb.
    await upgraded
        .into(upgraded.dailyTasks)
        .insert(
          DailyTasksCompanion.insert(
            day: DateTime(2026, 8, 5),
            title: 'أذاكر',
            sortOrder: 0,
            createdAt: DateTime(2026, 8, 5),
          ),
        );
    final tasks = await upgraded.select(upgraded.dailyTasks).get();
    expect(tasks.single.surrendered, isFalse);
    expect(await upgraded.select(upgraded.subjects).get(), hasLength(4));
    expect(
      (await upgraded.select(upgraded.chapters).get()).single.name,
      'الباب الأول',
    );
    expect(upgraded.schemaVersion, 5);
  });

  test('a fresh install creates the column outright', () async {
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.dailyTasks).get(), isEmpty);
    expect(db.schemaVersion, 5); // 5 = tasks.surrendered

    // On create there was never an older row to protect; the column simply
    // exists, defaults false, and accepts true like any other write.
    final id = await db
        .into(db.dailyTasks)
        .insert(
          DailyTasksCompanion.insert(
            day: DateTime(2026, 8, 5),
            title: 'أذاكر',
            sortOrder: 0,
            createdAt: DateTime(2026, 8, 5),
          ),
        );
    final row = await (db.select(
      db.dailyTasks,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.surrendered, isFalse);
  });
}
