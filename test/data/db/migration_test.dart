import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/data/db/app_database.dart';

/// Migration tests for schema version 4: scheduled exams and chapters.
///
/// Version 4 adds two new tables for the exam calendar feature:
/// - `scheduled_exams`: upcoming exam events with subject, date, title, notes
/// - `scheduled_exam_chapters`: junction table linking exams to chapters
///
/// These tests verify that the migration from v3 -> v4 is additive-only and
/// preserves all existing student data (curriculum, tasks, exams).
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
    await db.customStatement('DROP TABLE scheduled_exams');
    await db.customStatement('DROP TABLE scheduled_exam_chapters');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();
  }

  test('upgrading from v3 adds scheduled exams tables and keeps the curriculum',
      () async {
    await seedV3Database();

    final db = open();
    addTearDown(db.close);

    // The upgrade ran: both tables exist and are writable, not merely declared.
    await db
        .into(db.scheduledExams)
        .insert(
          ScheduledExamsCompanion.insert(
            subjectId: 1,
            date: DateTime(2026, 9, 1, 9, 0),
            title: 'Biology Midterm',
            createdAt: DateTime(2026, 8, 15),
          ),
        );
    final exams = await db.select(db.scheduledExams).get();
    expect(exams, hasLength(1));
    expect(exams.single.title, 'Biology Midterm');

    // Junction table is also writable.
    await db
        .into(db.scheduledExamChapters)
        .insert(
          ScheduledExamChaptersCompanion.insert(
            scheduledExamId: exams.single.id,
            chapterId: 1,
          ),
        );
    expect(await db.select(db.scheduledExamChapters).get(), hasLength(1));

    // And nothing the student built was touched on the way.
    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(1));
    expect(chapters.single.name, 'الباب الأول — الخلية');

    // The seed is still idempotent across the upgrade: four subjects, not eight.
    expect(await db.select(db.subjects).get(), hasLength(4));

    expect(db.schemaVersion, 4);
  });

  test('a fresh install creates all tables including scheduled exams',
      () async {
    final db = open();
    addTearDown(db.close);

    expect(await db.select(db.scheduledExams).get(), isEmpty);
    expect(await db.select(db.scheduledExamChapters).get(), isEmpty);
    expect(await db.select(db.dailyTasks).get(), isEmpty);
    expect(await db.select(db.subjects).get(), hasLength(4));
    expect(db.schemaVersion, 4);
  });

  test('scheduled exams cascade delete with their subject', () async {
    final db = open();
    addTearDown(db.close);

    // Create a custom subject (id 5, since 1-4 are seeded).
    await db.customStatement(
      "INSERT INTO subjects (id, code, name, sort_order) "
      "VALUES (5, 'custom', 'رياضيات', 4)",
    );

    // Create a chapter under the custom subject.
    await db.into(db.chapters).insert(
          ChaptersCompanion.insert(
            subjectId: 5,
            name: 'الجبر',
            createdAt: DateTime(2026, 8, 1),
          ),
        );
    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(1));

    // Schedule an exam for this subject.
    await db.into(db.scheduledExams).insert(
          ScheduledExamsCompanion.insert(
            subjectId: 5,
            date: DateTime(2026, 9, 10),
            title: 'Math Final',
            createdAt: DateTime(2026, 8, 15),
          ),
        );
    final exams = await db.select(db.scheduledExams).get();
    expect(exams, hasLength(1));

    // Link the exam to the chapter.
    await db.into(db.scheduledExamChapters).insert(
          ScheduledExamChaptersCompanion.insert(
            scheduledExamId: exams.single.id,
            chapterId: chapters.single.id,
          ),
        );
    expect(await db.select(db.scheduledExamChapters).get(), hasLength(1));

    // Delete the subject. ON DELETE CASCADE should remove the exam and junction.
    await (db.delete(db.subjects)..where((t) => t.id.equals(5))).go();

    expect(
      await db.select(db.scheduledExams).get(),
      isEmpty,
      reason: 'scheduled exam must be deleted with its subject',
    );
    expect(
      await db.select(db.scheduledExamChapters).get(),
      isEmpty,
      reason: 'junction rows must be deleted with the scheduled exam',
    );
    expect(
      await db.select(db.chapters).get(),
      isEmpty,
      reason: 'chapter must be deleted with its subject',
    );
  });

  test('scheduled exam chapters cascade delete with their exam', () async {
    final db = open();
    addTearDown(db.close);

    // Create a chapter (required for foreign key constraint).
    await db.into(db.chapters).insert(
          ChaptersCompanion.insert(
            subjectId: 1,
            name: 'الخلية',
            createdAt: DateTime(2026, 8, 1),
          ),
        );
    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(1));

    // Create an exam.
    await db.into(db.scheduledExams).insert(
          ScheduledExamsCompanion.insert(
            subjectId: 1,
            date: DateTime(2026, 9, 1),
            title: 'Biology Quiz',
            createdAt: DateTime(2026, 8, 15),
          ),
        );
    final exams = await db.select(db.scheduledExams).get();
    expect(exams, hasLength(1));

    // Link it to the chapter.
    await db.into(db.scheduledExamChapters).insert(
          ScheduledExamChaptersCompanion.insert(
            scheduledExamId: exams.single.id,
            chapterId: chapters.single.id,
          ),
        );
    expect(await db.select(db.scheduledExamChapters).get(), hasLength(1));

    // Delete the exam. The junction row should cascade.
    await (db.delete(db.scheduledExams)..where((t) => t.id.equals(exams.single.id))).go();

    expect(
      await db.select(db.scheduledExamChapters).get(),
      isEmpty,
      reason: 'junction rows must be deleted with the scheduled exam',
    );
  });
}
