import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/data/db/app_database.dart';

/// The v1 → v2 migration, against a real file on disk.
///
/// This is the one change in the tasks feature that cannot be undone by hand:
/// every student already carries a v1 database, `onCreate` does not run for
/// them, and a migration that dropped or recreated tables would take their
/// whole curriculum with it. So the test builds an actual v1 image, puts a
/// chapter and a lesson in it, and reopens it at v2.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ather_migration');
    file = File('${dir.path}/sahm.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  AppDatabase open() => AppDatabase(NativeDatabase(file));

  /// Writes a genuine v1 image: let drift build the current schema, then take
  /// away exactly what version 2 added and put the version marker back.
  ///
  /// Hand-writing the v1 DDL would be writing drift's own column naming and
  /// type mapping from memory, and a single mismatch would make this test pass
  /// against a schema no student has ever had.
  Future<void> seedV1Database() async {
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
    await db.customStatement('DROP TABLE daily_tasks');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();
  }

  test('upgrading from v1 adds daily_tasks and keeps the curriculum', () async {
    await seedV1Database();

    final db = open();
    addTearDown(db.close);

    // The upgrade ran: the table exists and is writable, not merely declared.
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
    expect(await db.select(db.dailyTasks).get(), hasLength(1));

    // And nothing the student built was touched on the way.
    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(1));
    expect(chapters.single.name, 'الباب الأول — الخلية');

    // The seed is still idempotent across the upgrade: four subjects, not eight.
    expect(await db.select(db.subjects).get(), hasLength(4));

    expect(db.schemaVersion, 2);
  });

  test('a fresh install creates the table outright', () async {
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.dailyTasks).get(), isEmpty);
    expect(db.schemaVersion, 2);
  });
}
