import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/instants.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_backup.dart';
import 'package:ather/domain/repositories/backup_repository.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

/// Cloud sync, through the real app.
///
/// The test that matters most here is the first one: **the whole app works when
/// the backup layer fails on every call.** That is the offline-first promise in
/// PROJECT.md §3.17, and cloud sync is exactly the change most likely to break
/// it -- so it is asserted rather than argued.
void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 8, 5);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  /// drift schedules a zero-duration timer when a `.watch()` stream is
  /// cancelled, and the binding checks for pending timers before `tearDown`.
  /// See tasks_test.dart, where this was first worked out.
  Future<void> closeApp(WidgetTester tester) async {
    // Past the confirmation toast's 2.2s dwell and its fade-out first: those are
    // real timers, and the restore raises one.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Widget> boot(
    FakeBackupRepository backup, {
    Map<String, Object> preferences0 = const <String, Object>{},
    FakeAuthRepository? auth,
  }) async {
    SharedPreferences.setMockInitialValues(preferences0);
    final preferences = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth ?? FakeAuthRepository.signedIn(),
        ),
        backupRepositoryProvider.overrideWithValue(backup),
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(MutableClock(now)),
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
      ],
      child: const AtherApp(),
    );
  }

  void phoneSized(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
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

  StudyBackup cloudCopy() => StudyBackup(
    chapters: <Chapter>[
      Chapter(id: 1, subjectId: 1, name: 'باب من السحابة', createdAt: now),
    ],
    lessons: <Lesson>[
      Lesson(
        id: 1,
        chapterId: 1,
        name: 'درس من السحابة',
        createdAt: now,
        checklist: const LessonChecklist(
          watchedLesson: false,
          readNotes: false,
          didHomework: false,
          didExam: false,
          reviewedNotes: false,
        ),
      ),
    ],
    exams: const <ExamEntry>[],
    homework: const <HomeworkEntry>[],
    tasks: const <DailyTask>[],
  );

  testWidgets('the app is fully usable while every backup call fails', (
    tester,
  ) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.failing();

    await tester.pumpWidget(await boot(backup));
    await tester.pumpAndSettle();

    // The dashboard is there, not an error screen and not a spinner.
    expect(find.text('النهارده'), findsOneWidget);

    // And the student can still build their curriculum, which is the part that
    // has to keep working when the network does not.
    await tester.tap(find.text('أحياء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ إضافة باب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'الباب الأول');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('الباب الأول'), findsWidgets);
    expect(
      await DriftStudyRepository(db).readSnapshot().then((s) => s.chapters),
      hasLength(1),
      reason: 'the write lands locally regardless of the cloud',
    );

    await closeApp(tester);
  });

  testWidgets('a failing sync says why, and offline is not an error', (
    tester,
  ) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.failing(BackupFailure.permissionDenied);
    // Something to back up: an upload with nothing to send is skipped on
    // purpose, so an empty local database can never overwrite a good cloud copy.
    await DriftStudyRepository(
      db,
    ).createChapter(subjectId: 1, name: 'باب', at: kSeedInstant);

    await tester.pumpWidget(await boot(backup));
    await tester.pumpAndSettle();
    await openSettings(tester);

    expect(find.text('النسخة السحابية'), findsOneWidget);

    await tester.tap(find.text('احفظ دلوقتي'));
    await tester.pumpAndSettle();

    // Rules never published looks exactly like "sync quietly does nothing"
    // unless it is named, which is why BackupFailure distinguishes it.
    expect(find.text('الصلاحيات مظبوطتش على السيرفر'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('an empty install pulls the cloud copy down by itself', (
    tester,
  ) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.holding(cloudCopy());

    await tester.pumpWidget(await boot(backup));
    await tester.pumpAndSettle();

    // Nothing was asked, because there was nothing to lose.
    expect(backup.downloadCount, greaterThan(0));
    final snapshot = await DriftStudyRepository(db).readSnapshot();
    expect(snapshot.chapters, hasLength(1));
    expect(snapshot.chapters.single.name, 'باب من السحابة');

    await closeApp(tester);
  });

  testWidgets('a populated install is never overwritten without being asked', (
    tester,
  ) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.holding(cloudCopy());

    // The student already has work on this device before signing in.
    await DriftStudyRepository(
      db,
    ).createChapter(subjectId: 1, name: 'شغلي أنا', at: kSeedInstant);

    await tester.pumpWidget(await boot(backup));
    await tester.pumpAndSettle();

    final snapshot = await DriftStudyRepository(db).readSnapshot();
    expect(snapshot.chapters, hasLength(1));
    expect(
      snapshot.chapters.single.name,
      'شغلي أنا',
      reason: 'an automatic restore must never replace existing work',
    );

    await closeApp(tester);
  });

  // The device belonged to somebody else. Nothing used to notice, so the second
  // student opened the app to the first one's curriculum -- and the sync then
  // mirrored it into the second student's cloud document.
  testWidgets('a different account wipes the previous student off the device', (
    tester,
  ) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.holding(cloudCopy());

    await DriftStudyRepository(
      db,
    ).createChapter(subjectId: 1, name: 'مش بتاعي', at: kSeedInstant);

    await tester.pumpWidget(
      await boot(
        backup,
        // The device still claims to belong to another uid; the fake signs in
        // as `test-uid`.
        preferences0: const <String, Object>{
          'last_account_uid': 'a-different-student',
        },
      ),
    );
    await tester.pumpAndSettle();

    final snapshot = await DriftStudyRepository(db).readSnapshot();
    expect(
      snapshot.chapters.map((c) => c.name),
      isNot(contains('مش بتاعي')),
      reason: "a student must never see the previous account's curriculum",
    );
    // And the device now being genuinely empty, the ordinary auto-restore does
    // its normal job: this student gets their own cloud copy, no second path.
    expect(snapshot.chapters.single.name, 'باب من السحابة');

    await closeApp(tester);
  });

  testWidgets('a second account arriving without a sign-out still wipes', (
    tester,
  ) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.holding(cloudCopy());
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await DriftStudyRepository(
      db,
    ).createChapter(subjectId: 1, name: 'مش بتاعي', at: kSeedInstant);

    await tester.pumpWidget(
      await boot(
        backup,
        auth: auth,
        preferences0: const <String, Object>{'last_account_uid': 'test-uid'},
      ),
    );
    await tester.pumpAndSettle();

    // The device is this student's, so nothing was touched on the way in.
    expect(
      (await DriftStudyRepository(db).readSnapshot()).chapters.map((c) => c.name),
      contains('مش بتاعي'),
    );

    // Now a *different* uid arrives with no null in between. The guard used to
    // ask "did somebody sign in where nobody was", which is only the same
    // question if every account change passes through signed-out first -- and
    // nothing guarantees that. Missing it leaves one student looking at
    // another's curriculum, and uploads it into their cloud document.
    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    final snapshot = await DriftStudyRepository(db).readSnapshot();
    expect(
      snapshot.chapters.map((c) => c.name),
      isNot(contains('مش بتاعي')),
      reason: "the previous student's curriculum survived a direct uid switch",
    );

    await closeApp(tester);
  });

  testWidgets('the same account signing back in keeps everything', (
    tester,
  ) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.holding(cloudCopy());

    await DriftStudyRepository(
      db,
    ).createChapter(subjectId: 1, name: 'شغلي أنا', at: kSeedInstant);

    await tester.pumpWidget(
      await boot(
        backup,
        // Signing out is not a statement that the work is finished with, and
        // the phone may hold edits that never reached the cloud.
        preferences0: const <String, Object>{'last_account_uid': 'test-uid'},
      ),
    );
    await tester.pumpAndSettle();

    final snapshot = await DriftStudyRepository(db).readSnapshot();
    expect(snapshot.chapters.single.name, 'شغلي أنا');

    await closeApp(tester);
  });

  testWidgets('the manual restore confirms first, then replaces', (
    tester,
  ) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.holding(cloudCopy());
    await DriftStudyRepository(
      db,
    ).createChapter(subjectId: 1, name: 'شغلي أنا', at: kSeedInstant);

    await tester.pumpWidget(await boot(backup));
    await tester.pumpAndSettle();
    await openSettings(tester);

    await tester.tap(find.text('استرجع النسخة السحابية'));
    await tester.pumpAndSettle();

    // The destructive confirmation the rest of the app uses, saying what goes.
    expect(find.textContaining('هيتمسح ويتحط مكانه'), findsOneWidget);

    await tester.tap(find.text('حذف').hitTestable());
    await tester.pumpAndSettle();

    final snapshot = await DriftStudyRepository(db).readSnapshot();
    expect(snapshot.chapters.single.name, 'باب من السحابة');

    await closeApp(tester);
  });

  testWidgets('backing out of the restore changes nothing', (tester) async {
    phoneSized(tester);
    final backup = FakeBackupRepository.holding(cloudCopy());
    await DriftStudyRepository(
      db,
    ).createChapter(subjectId: 1, name: 'شغلي أنا', at: kSeedInstant);

    await tester.pumpWidget(await boot(backup));
    await tester.pumpAndSettle();
    await openSettings(tester);

    await tester.tap(find.text('استرجع النسخة السحابية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء').hitTestable());
    await tester.pumpAndSettle();

    final snapshot = await DriftStudyRepository(db).readSnapshot();
    expect(snapshot.chapters.single.name, 'شغلي أنا');

    await closeApp(tester);
  });
}
