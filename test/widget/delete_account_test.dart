import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/domain/repositories/auth_repository.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/auth/login_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

/// Account deletion, end to end through the real app.
///
/// Google Play requires in-app account deletion, and the deletion path is the
/// one place where every layer meets: the auth repository, the backup mirror,
/// both local repositories, and the router's sign-in gate. These tests drive
/// the whole path through the Settings screen exactly the way a student does.
void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 8, 16);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Widget> boot(FakeAuthRepository auth, FakeBackupRepository backup) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

  Future<void> addChapter(WidgetTester tester) async {
    // One chapter with one lesson, so "everything on this device" is a real
    // thing that can be verified as gone.
    await tester.tap(find.text('أحياء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ إضافة باب'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'باب سيتم حذفه مع الحساب',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    // The header's back control, by its semantic label (رجوع) — the app draws
    // its own chevron rather than a platform back button.
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'رجوع',
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The delete button sits at the very bottom of Settings — past every
  /// setting, by design. Scrolling to it is what a student does too.
  Future<void> reachDeleteButton(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('حذف الحساب'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deleting the account wipes the device, the cloud and the account', (tester) async {
    phoneSized(tester);
    final auth = FakeAuthRepository.signedIn();
    final backup = FakeBackupRepository();
    await tester.pumpWidget(await boot(auth, backup));
    await tester.pumpAndSettle();

    await addChapter(tester);
    await openSettings(tester);

    await reachDeleteButton(tester);
    await tester.tap(find.text('حذف الحساب'));
    await tester.pumpAndSettle();
    // The confirmation names what goes, in words.
    expect(find.textContaining('لا يمكن التراجع'), findsOneWidget);
    await tester.tap(find.text('حذف الحساب').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(auth.deleteCount, 1);
    expect(backup.deleteCloudCount, 1);
    // The device is empty again: the seeded subjects remain, the student's
    // chapters do not.
    final chapters = await db.customSelect('SELECT COUNT(*) AS c FROM chapters').get();
    expect(chapters.first.read<int>('c'), 0);
    // And the router's gate has done its job: the login screen is back.
    expect(find.byType(LoginScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('a stale session asks for the password, then deletes', (tester) async {
    phoneSized(tester);
    final auth = FakeAuthRepository.signedIn();
    auth.nextDeleteFailure = AuthFailure.requiresRecentLogin;
    await tester.pumpWidget(await boot(auth, FakeBackupRepository()));
    await tester.pumpAndSettle();

    await openSettings(tester);
    await reachDeleteButton(tester);
    await tester.tap(find.text('حذف الحساب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الحساب').last);
    await tester.pumpAndSettle();

    // The re-auth sheet, not a failure toast.
    expect(find.textContaining('أكّد أنه حسابك'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'the-password');
    await tester.tap(find.text('احذف الحساب'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(auth.deleteCount, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('declining the confirmation deletes nothing', (tester) async {
    phoneSized(tester);
    final auth = FakeAuthRepository.signedIn();
    await tester.pumpWidget(await boot(auth, FakeBackupRepository()));
    await tester.pumpAndSettle();

    await openSettings(tester);
    await reachDeleteButton(tester);
    await tester.tap(find.text('حذف الحساب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(auth.deleteCount, 0);
    expect(find.byType(LoginScreen), findsNothing);
    await closeApp(tester);
  });
}
