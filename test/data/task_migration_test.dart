import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/data/db/app_database.dart';

/// Every migration this database has, against a real file on disk.
///
/// These are the changes that cannot be undone by hand: every student already
/// carries an older database, `onCreate` does not run for them, and a migration
/// that dropped or recreated tables would take their whole curriculum with it.
/// So each test builds an actual older image, puts a chapter in it, and reopens
/// it at the current version.
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
    await db.customStatement('ALTER TABLE subjects DROP COLUMN name');
    await db.customStatement('ALTER TABLE subjects DROP COLUMN archived_at');
    await db.customStatement('ALTER TABLE subjects DROP COLUMN deleted_at');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();
  }

  /// A v2 image: everything the tasks release shipped, without the two columns
  /// version 3 added -- and without the column version 5 added to
  /// `daily_tasks`, which this image must not carry any more than a phone
  /// updated straight from v2 would.
  Future<void> seedV2Database() async {
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
    await db.customStatement('ALTER TABLE subjects DROP COLUMN name');
    await db.customStatement('ALTER TABLE subjects DROP COLUMN archived_at');
    await db.customStatement('ALTER TABLE subjects DROP COLUMN deleted_at');
    await db.customStatement('ALTER TABLE daily_tasks DROP COLUMN surrendered');
    await db.customStatement('PRAGMA user_version = 2');
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

    expect(db.schemaVersion, 5); // 5 = study_events capture table, then surrender
  });

  test('upgrading from v2 adds the subject columns and keeps everything', () async {
    await seedV2Database();

    final db = open();
    addTearDown(db.close);

    // The columns exist and are writable, not merely declared.
    await db.customStatement(
      "INSERT INTO subjects (id, code, name, sort_order) "
      "VALUES (99, 'custom', 'رياضيات', 4)",
    );
    final subjects = await db.select(db.subjects).get();
    expect(subjects, hasLength(5));
    expect(subjects.firstWhere((s) => s.id == 99).name, 'رياضيات');
    // The four that were already there kept their null name rather than being
    // rewritten with one -- their names come from the ARB files.
    expect(subjects.firstWhere((s) => s.id == 1).name, isNull);
    expect(subjects.every((s) => s.archivedAt == null), isTrue);
    // Nothing arrives in the recycle bin as a side effect of upgrading.
    expect(subjects.every((s) => s.deletedAt == null), isTrue);

    // And nothing the student built was touched on the way.
    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(1));
    expect(chapters.single.name, 'الباب الأول — الخلية');

    expect(db.schemaVersion, 5); // 5 = study_events capture table, then surrender
  });

  test('the seed never runs again once a subject can be deleted', () async {
    // The trap this whole feature had to walk around. `_seedSubjects` used to
    // run from `beforeOpen`, on every launch, described as self-healing -- true
    // and harmless while nothing could remove a subject. The moment subjects
    // became deletable, that same line became a guarantee that every subject a
    // student deleted would be back the next time they opened the app.
    final first = open();
    expect(await first.select(first.subjects).get(), hasLength(4));
    await (first.delete(first.subjects)..where((t) => t.id.equals(4))).go();
    await first.close();

    final second = open();
    addTearDown(second.close);
    final subjects = await second.select(second.subjects).get();
    expect(
      subjects.map((s) => s.id),
      isNot(contains(4)),
      reason: 'a deleted subject must stay deleted across a restart',
    );
    expect(subjects, hasLength(3));
  });

  test('a fresh install creates the table outright', () async {
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.dailyTasks).get(), isEmpty);
    expect(await db.select(db.subjects).get(), hasLength(4));
    expect(db.schemaVersion, 5); // 5 = study_events capture table, then surrender
  });
}
