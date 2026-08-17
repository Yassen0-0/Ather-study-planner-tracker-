import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

/// Deleting a subject and getting it back, through the real app.
///
/// The repository tests prove the flags behave. These prove the thing a student
/// actually experiences: that "حذف" removes a subject from the screen without
/// destroying anything, that the bin holds it whole, and that restoring returns
/// every exam that was under it.
///
/// The design this replaced refused to delete a subject with chapters at all,
/// which protected the data and left a dead end — a subject the student did not
/// take could never be removed. These tests are the evidence that the safety
/// survived the change.
void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 8, 17);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Widget> boot() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(
          FakeBackupRepository.failing(),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(MutableClock(now)),
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
      ],
      child: const AtherApp(),
    );
  }

  void phoneSized(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRow(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(label).hitTestable().first);
    await tester.pumpAndSettle();
  }

  /// A subject with a chapter, a lesson and an exam under it — the case the old
  /// design refused to delete.
  Future<void> seed() async {
    final repository = DriftStudyRepository(db);
    final subjectId = await repository.createSubject(name: 'رياضيات');
    final chapterId = await repository.createChapter(
      subjectId: subjectId,
      name: 'الجبر',
      at: now,
    );
    final lessonId = await repository.createLesson(
      chapterId: chapterId,
      name: 'المصفوفات',
      at: now,
    );
    await repository.recordExam(
      lessonId: lessonId,
      groups: const <DraftQuestionGroup>[
        DraftQuestionGroup(
          pointsPerQuestion: 1,
          questionCount: 4,
          correctCount: 3,
        ),
      ],
      isReviewExam: false,
      at: now,
    );
  }

  testWidgets('a deleted subject leaves the app whole and comes back', (
    tester,
  ) async {
    phoneSized(tester);
    await seed();

    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();

    expect(find.text('رياضيات'), findsWidgets, reason: 'on the dashboard');

    await openSettings(tester);
    await openRow(tester, 'المواد');
    await tester.tap(find.text('رياضيات').hitTestable().first);
    await tester.pumpAndSettle();

    // No guard and no confirmation: nothing is being destroyed.
    await tester.tap(find.text('حذف المادة').hitTestable().last);
    await tester.pumpAndSettle();

    expect(
      find.text('رياضيات'),
      findsNothing,
      reason: 'gone from the subjects screen',
    );

    // The record underneath is untouched — which is the whole claim.
    final afterDelete = await DriftStudyRepository(db).readSnapshot();
    expect(afterDelete.chapters, hasLength(1));
    expect(afterDelete.exams, hasLength(1));
    expect(afterDelete.deletedSubjects, hasLength(1));
    expect(
      afterDelete.activeLessons,
      isEmpty,
      reason: 'and it stops feeding reminders and the review queue',
    );

    // Back out to Settings, into the bin, and restore it. By the semantic
    // label, because the app draws its own chevron rather than a platform back
    // button.
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'رجوع',
      ),
    );
    await tester.pumpAndSettle();
    await openRow(tester, 'سلة المحذوفات');

    expect(find.text('رياضيات'), findsOneWidget);
    await tester.tap(find.text('رياضيات').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('استرجاع').hitTestable().last);
    await tester.pumpAndSettle();

    final afterRestore = await DriftStudyRepository(db).readSnapshot();
    expect(afterRestore.deletedSubjects, isEmpty);
    expect(afterRestore.activeSubjects.map((s) => s.name), contains('رياضيات'));
    expect(
      afterRestore.exams,
      hasLength(1),
      reason: 'the exam survived the whole round trip',
    );

    await closeApp(tester);
  });

  testWidgets('the bin row is not offered when the bin is empty', (
    tester,
  ) async {
    // A row reading "0" is a row that teaches a student to ignore it.
    phoneSized(tester);
    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();
    await openSettings(tester);

    expect(find.text('سلة المحذوفات'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('the permanent delete counts what it is about to destroy', (
    tester,
  ) async {
    phoneSized(tester);
    await seed();
    final repository = DriftStudyRepository(db);
    final subject = (await repository.readSnapshot()).activeSubjects.last;
    await repository.setSubjectDeleted(subjectId: subject.id, at: now);

    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();
    await openSettings(tester);
    await openRow(tester, 'سلة المحذوفات');

    await tester.tap(find.text('رياضيات').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف نهائي').hitTestable().last);
    await tester.pumpAndSettle();

    // "This cannot be undone" is a sentence a student has read a hundred
    // times. The counts are the thing they are actually deciding about.
    // `hitTestable` scopes this to the sheet: the row underneath also names
    // the chapter count, and the modal barrier is what tells them apart.
    expect(find.textContaining('باب واحد').hitTestable(), findsOneWidget);
    expect(find.textContaining('امتحان واحد').hitTestable(), findsOneWidget);

    await tester.tap(find.text('حذف نهائي').hitTestable().last);
    await tester.pumpAndSettle();

    final after = await DriftStudyRepository(db).readSnapshot();
    expect(after.subjects, hasLength(4), reason: 'only the seeded four remain');
    expect(after.chapters, isEmpty, reason: 'the cascade finally fired');
    expect(after.exams, isEmpty);

    await closeApp(tester);
  });
}
