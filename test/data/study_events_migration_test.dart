import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/data/db/app_database.dart';

/// The 3 -> 4 migration, against a real file on disk.
///
/// Same method as [task_migration_test] and for the same reason: every student
/// already carries an older database file, `onCreate` does not run for them,
/// and the one thing this migration must never do is touch what is already
/// there. Version 4 adds only the `study_events` capture table -- written by
/// nothing before it existed, so the upgrade has exactly one job: make the
/// table exist, and leave every other byte alone.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ather_migration');
    file = File('${dir.path}/sahm.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  AppDatabase open() => AppDatabase(NativeDatabase(file));

  /// Writes a genuine v3 image: let drift build the current schema, then take
  /// away exactly what version 4 added and put the version marker back.
  ///
  /// Hand-writing the v3 DDL would be writing drift's own column naming and
  /// type mapping from memory, and a single mismatch would make this test pass
  /// against a schema no student has ever had.
  Future<void> seedV3Database() async {
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
    // A lesson with ticks on it, to prove the flags survive the upgrade
    // untouched -- they are the values whose history the new table exists to
    // start capturing.
    await db
        .into(db.lessons)
        .insert(
          LessonsCompanion.insert(
            chapterId: 1,
            name: 'تركيب الخلية',
            createdAt: DateTime(2026, 7, 1),
            watchedLesson: const Value(true),
            didExam: const Value(true),
          ),
        );
    await db.customStatement('DROP TABLE study_events');
    await db.customStatement(
      'ALTER TABLE daily_tasks DROP COLUMN surrendered',
    );
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();
  }

  test('upgrading from v3 creates study_events and keeps everything', () async {
    await seedV3Database();

    final db = open();
    addTearDown(db.close);

    // The upgrade ran: the table exists and is writable, not merely declared.
    await db
        .into(db.studyEvents)
        .insert(
          StudyEventsCompanion.insert(
            type: 'checklist',
            refId: 1,
            at: DateTime(2026, 8, 5),
          ),
        );
    final events = await db.select(db.studyEvents).get();
    expect(events, hasLength(1));
    expect(events.single.type, 'checklist');
    expect(events.single.refId, 1);
    expect(events.single.at, DateTime(2026, 8, 5));

    // And nothing the student built was touched on the way -- including the
    // checklist flags whose overwrite is the reason the table exists.
    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(1));
    expect(chapters.single.name, 'الباب الأول — الخلية');

    final lesson = await (db.select(
      db.lessons,
    )..where((t) => t.id.equals(1))).getSingle();
    expect(lesson.name, 'تركيب الخلية');
    expect(lesson.watchedLesson, isTrue);
    expect(lesson.didExam, isTrue);
    expect(lesson.readNotes, isFalse);

    expect(await db.select(db.subjects).get(), hasLength(4));

    expect(db.schemaVersion, 5); // 5 = study_events capture table, then surrender
  });

  test('upgrading from v2 passes through and still adds everything', () async {
    // The cumulative ladder in one go: a phone that skipped version 3 entirely
    // (it never shipped) walks both steps on first launch of this build.
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
    await db.customStatement(
      'ALTER TABLE daily_tasks DROP COLUMN surrendered',
    );
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    final upgraded = open();
    addTearDown(upgraded.close);

    await upgraded
        .into(upgraded.studyEvents)
        .insert(
          StudyEventsCompanion.insert(
            type: 'task_done',
            refId: 3,
            at: DateTime(2026, 8, 5),
          ),
        );
    expect(await upgraded.select(upgraded.studyEvents).get(), hasLength(1));
    expect(await upgraded.select(upgraded.subjects).get(), hasLength(4));
    expect((await upgraded.select(upgraded.chapters).get()).single.name,
        'الباب الأول');
  });

  test('a fresh install creates the table outright', () async {
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.studyEvents).get(), isEmpty);
    expect(await db.select(db.dailyTasks).get(), isEmpty);
    expect(await db.select(db.subjects).get(), hasLength(4));
    expect(db.schemaVersion, 5);
  });
}
