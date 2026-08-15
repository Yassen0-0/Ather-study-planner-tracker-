import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/repositories/auth_repository.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';
import '../support/instants.dart';

/// Account deletion, which Play requires and which is easy to ship as a lie.
///
/// The reason these tests exist rather than a manual check: Firebase's
/// `user.delete()` removes the Auth user and **leaves the backup document
/// behind**, and because the security rules key that document on
/// `request.auth.uid == uid`, deleting the account first makes the student's
/// exam history permanently unreachable — present in Firestore, deletable by
/// nobody. Verified against the live project on 2026-08-15.
///
/// So the ordering is the feature, and an ordering is exactly the kind of thing
/// that survives a refactor only if a test holds it down.
void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 8, 5);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  /// drift schedules a zero-duration timer when a `.watch()` stream is
  /// cancelled, and the binding checks for pending timers before `tearDown`.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Widget> boot(
    FakeBackupRepository backup,
    FakeAuthRepository auth, {
    Map<String, Object> preferences0 = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(preferences0);
    final preferences = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
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

  /// Scrolls the delete button into view and taps it, then confirms.
  Future<void> tapDelete(WidgetTester tester, {required bool confirm}) async {
    final button = find.text('حذف الحساب').last;
    await tester.scrollUntilVisible(button, 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الحساب').last);
    await tester.pumpAndSettle();

    // The confirmation sheet. Its red button is deliberately not "حذف" -- it
    // names the act, because this is the one dialog in the app where a
    // mis-tap costs everything.
    expect(find.text('تحذف الحساب؟'), findsOneWidget);
    await tester.tap(
      find.text(confirm ? 'امسح حسابي نهائيًا' : 'إلغاء'),
    );
    await tester.pumpAndSettle();
  }

  /// A curriculum on the device, so "the local copy went too" is a real
  /// assertion rather than one about an already-empty database.
  Future<void> seedLocalWork() async {
    await DriftStudyRepository(
      db,
    ).createChapter(subjectId: 1, name: 'الباب الأول', at: kSeedInstant);
  }

  testWidgets('the cloud copy is deleted before the account', (tester) async {
    phoneSized(tester);
    await seedLocalWork();

    final auth = FakeAuthRepository.signedIn();
    final backup = FakeBackupRepository()
      ..accountDeleteCount = () => auth.deleteAccountCount;

    await tester.pumpWidget(await boot(backup, auth));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tapDelete(tester, confirm: true);

    expect(backup.deleteCount, 1, reason: 'the cloud copy was deleted');
    expect(auth.deleteAccountCount, 1, reason: 'the account was deleted');
    expect(
      backup.cloudDeletedBeforeAccountDeleted,
      isTrue,
      reason:
          'the cloud copy must go first -- once the account is gone no caller '
          'can ever satisfy the rules for that document again',
    );

    // And the copy the student is holding.
    expect(
      await DriftStudyRepository(db).readSnapshot().then((s) => s.chapters),
      isEmpty,
      reason: 'deleting the account wipes the local record too',
    );

    await closeApp(tester);
  });

  testWidgets('a failed cloud delete leaves the account intact', (
    tester,
  ) async {
    phoneSized(tester);
    await seedLocalWork();

    final auth = FakeAuthRepository.signedIn();
    // Offline: the overwhelmingly common failure, and the one where stopping is
    // obviously right.
    final backup = FakeBackupRepository.failing()
      ..accountDeleteCount = () => auth.deleteAccountCount;

    await tester.pumpWidget(await boot(backup, auth));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tapDelete(tester, confirm: true);

    expect(
      auth.deleteAccountCount,
      0,
      reason:
          'the account must survive a failed cloud delete -- deleting it here '
          'would orphan the backup document permanently',
    );
    expect(
      auth.currentAccount,
      isNotNull,
      reason: 'the student is still signed in and can retry',
    );
    expect(
      await DriftStudyRepository(db).readSnapshot().then((s) => s.chapters),
      hasLength(1),
      reason: 'and their work is untouched, so the failure is recoverable',
    );
    // Named, rather than a generic "something went wrong" that would send the
    // student back to a button that keeps failing for a fixable reason.
    expect(
      find.text(
        'مسح الحساب محتاج نت، عشان النسخة السحابية تتمسح هي كمان. اتصل بالنت وجرّب تاني.',
      ),
      findsOneWidget,
    );

    await closeApp(tester);
  });

  testWidgets('a stale session is told to sign in again, and keeps its data', (
    tester,
  ) async {
    phoneSized(tester);
    await seedLocalWork();

    final auth = FakeAuthRepository.signedIn()
      ..nextFailure = AuthFailure.requiresRecentLogin;
    final backup = FakeBackupRepository()
      ..accountDeleteCount = () => auth.deleteAccountCount;

    await tester.pumpWidget(await boot(backup, auth));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tapDelete(tester, confirm: true);

    expect(
      find.text('لأمان حسابك، سجّل خروج وادخل تاني قبل ما تمسحه.'),
      findsOneWidget,
      reason:
          'requires-recent-login has a remedy, so it must not arrive as the '
          'generic failure -- that would read as "deleting is broken"',
    );
    // The cloud copy is already gone at this point, and that is the harmless
    // half: the backup is a mirror, not a source of truth, and the local
    // database still holds everything.
    expect(
      await DriftStudyRepository(db).readSnapshot().then((s) => s.chapters),
      hasLength(1),
      reason: 'the local record survives, so the next backup rebuilds the cloud',
    );

    await closeApp(tester);
  });

  testWidgets('cancelling the confirmation deletes nothing at all', (
    tester,
  ) async {
    phoneSized(tester);
    await seedLocalWork();

    final auth = FakeAuthRepository.signedIn();
    final backup = FakeBackupRepository()
      ..accountDeleteCount = () => auth.deleteAccountCount;

    await tester.pumpWidget(await boot(backup, auth));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tapDelete(tester, confirm: false);

    expect(backup.deleteCount, 0);
    expect(auth.deleteAccountCount, 0);
    expect(
      await DriftStudyRepository(db).readSnapshot().then((s) => s.chapters),
      hasLength(1),
    );

    await closeApp(tester);
  });

  testWidgets('a student who never backed up can still delete', (tester) async {
    phoneSized(tester);
    await seedLocalWork();

    final auth = FakeAuthRepository.signedIn();
    // Nothing stored and no failure: Firestore's delete succeeds on a document
    // that was never written, and that has to be the path here too -- cloud
    // backup is opt-in, so most students will have nothing there.
    final backup = FakeBackupRepository()
      ..accountDeleteCount = () => auth.deleteAccountCount;

    await tester.pumpWidget(await boot(backup, auth));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tapDelete(tester, confirm: true);

    expect(auth.deleteAccountCount, 1);
    expect(
      await DriftStudyRepository(db).readSnapshot().then((s) => s.chapters),
      isEmpty,
    );

    await closeApp(tester);
  });

  testWidgets('the last-account uid is cleared, not left pointing at a ghost', (
    tester,
  ) async {
    phoneSized(tester);
    await seedLocalWork();

    final auth = FakeAuthRepository.signedIn();
    final backup = FakeBackupRepository()
      ..accountDeleteCount = () => auth.deleteAccountCount;

    await tester.pumpWidget(
      await boot(
        backup,
        auth,
        preferences0: <String, Object>{kLastAccountUidKey: 'test-uid'},
      ),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tapDelete(tester, confirm: true);

    expect(
      (await SharedPreferences.getInstance()).getString(kLastAccountUidKey),
      isNull,
      reason:
          'the next student on this phone must not be compared against a uid '
          'that no longer exists',
    );

    await closeApp(tester);
  });
}
