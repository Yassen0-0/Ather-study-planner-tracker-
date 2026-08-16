import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/notification_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';
import '../support/fake_notifications.dart';

/// Regressions for findings from the security audit of 2026-08-15.
///
/// Each test is named after the thing that was wrong, not the code that fixed
/// it, so a future change that reintroduces the behaviour fails on a sentence
/// that says what the student loses.
void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 8, 5);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Widget> boot({
    required FakeAuthRepository auth,
    required FakeNotificationService notifications,
    Map<String, Object> preferences0 = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(preferences0);
    final preferences = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        backupRepositoryProvider.overrideWithValue(
          FakeBackupRepository.failing(),
        ),
        notificationServiceProvider.overrideWithValue(notifications),
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

  // --- SEC: review reminders outlived the student they belonged to ----------

  testWidgets(
    'signing out empties the reminder queue instead of leaving the previous '
    'student\'s lesson names to arrive on the lock screen',
    (tester) async {
      phoneSized(tester);
      final auth = FakeAuthRepository.signedIn();
      addTearDown(auth.dispose);
      final notifications = FakeNotificationService();

      await tester.pumpWidget(
        await boot(auth: auth, notifications: notifications),
      );
      await tester.pumpAndSettle();

      // Signed in: the scheduler is allowed to post reminders.
      expect(
        notifications.lastPassScheduled,
        isTrue,
        reason: 'a signed-in student with reminders on should be scheduled for',
      );

      await openSettings(tester);
      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();
      // The red button on the confirmation sheet.
      await tester.tap(find.text('تسجيل الخروج').last);
      await tester.pumpAndSettle();

      // Signing out deliberately leaves the database in place, so the schedule
      // has to be emptied by the sign-out itself -- nothing else will notice.
      expect(
        notifications.lastPassScheduled,
        isFalse,
        reason:
            'a reminder body is a lesson name and its chapter; after sign-out '
            'those must stop arriving on a phone the student handed on',
      );
      expect(notifications.cancelAllCount, greaterThan(0));

      await closeApp(tester);
    },
  );

  // --- SEC: the sign-out sheet's confirm button said "حذف" ------------------

  testWidgets('the sign-out confirmation never offers a button labelled "حذف"', (
    tester,
  ) async {
    phoneSized(tester);
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      await boot(auth: auth, notifications: FakeNotificationService()),
    );
    await tester.pumpAndSettle();

    await openSettings(tester);
    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();

    // The sheet says, in words, that nothing is deleted. A button reading
    // "حذف" underneath that sentence contradicts it -- and teaches the student
    // that Ather's red buttons cannot be read literally, which is exactly the
    // lesson they must not learn before the next one really does erase a
    // chapter.
    expect(find.text('حذف'), findsNothing);
    expect(find.text('بياناتك محفوظة على الجهاز ومش هتتمسح.'), findsNothing);
    expect(find.textContaining('مش هتتمسح'), findsOneWidget);

    await closeApp(tester);
  });
}
