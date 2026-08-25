import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/auth/app_passcode.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/widgets/buttons.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';
import '../support/fake_local_auth.dart';

/// T4: the lock method -- fingerprint, password, or both.
///
/// What these protect:
///
/// * **The upgrade path.** An install that has never heard of `lock_methods`
///   must behave exactly as it did before T4: sensor prompt, auto-fired,
///   nothing to type into. The default answers that.
/// * **Each way in actually opens**, and each alone leaves the other
///   unnecessary: the password needs no sensor attempt, the sensor needs no
///   typing.
/// * **A wrong password says so** and moves nothing else.
void main() {
  final DateTime now = DateTime(2026, 8, 5);

  group('AppPasscode', () {
    test('a hashed password verifies, a wrong one does not', () {
      final stored = AppPasscode.hash('1357');
      expect(AppPasscode.verify('1357', stored), isTrue);
      expect(AppPasscode.verify('1358', stored), isFalse);
      expect(AppPasscode.verify('', stored), isFalse);
    });

    test('every hash carries its own salt', () {
      // Same input twice must not store the same bytes, or the salt is
      // decoration and two students choosing "1234" store identical rows.
      expect(AppPasscode.hash('1234'), isNot(AppPasscode.hash('1234')));
    });

    test('malformed stored values fail closed', () {
      expect(AppPasscode.verify('1234', ''), isFalse);
      expect(AppPasscode.verify('1234', 'garbage'), isFalse);
      expect(AppPasscode.verify('1234', 'zz:nothex'), isFalse);
      expect(AppPasscode.verify('1234', 'abcd'), isFalse);
    });

    test('digits are recognised for the keyboard, nothing more', () {
      expect(AppPasscode.looksNumeric('2468'), isTrue);
      expect(AppPasscode.looksNumeric('24a8'), isFalse);
      // Arabic-Indic digits are not ASCII digits; such a password simply
      // keeps the text keyboard, which types them fine.
      expect(AppPasscode.looksNumeric('٢٤٦٨'), isFalse);
    });
  });

  late SharedPreferences prefs;

  Future<Widget> boot(
    FakeLocalAuth localAuth, {
    bool lockOn = true,
    Map<String, Object> stored = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_lock_enabled': lockOn,
      ...stored,
    });
    prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(
          FakeBackupRepository.failing(),
        ),
        localAuthProvider.overrideWithValue(localAuth),
        sharedPreferencesProvider.overrideWithValue(prefs),
        snapshotProvider.overrideWith(
          (ref) => Stream<StudySnapshot>.value(const StudySnapshot.empty()),
        ),
        tasksProvider.overrideWith(
          (ref) => Stream<List<DailyTask>>.value(const <DailyTask>[]),
        ),
        clockProvider.overrideWithValue(MutableClock(now)),
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
      ],
      child: const AtherApp(),
    );
  }

  bool locked(WidgetTester tester) => find.text('أثر').evaluate().isNotEmpty;

  /// The submit button, not the field hint carrying the same words.
  Finder submit(String label) => find.widgetWithText(PrimaryButton, label);

  testWidgets('no stored method keeps the old pure-biometric lock', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: false);

    await tester.pumpWidget(await boot(localAuth));
    await tester.pumpAndSettle();

    // Nothing to type into, and the prompt fired itself exactly as before.
    expect(find.byType(TextField), findsNothing);
    expect(localAuth.attempts, 1);
    expect(locked(tester), isTrue);
  });

  testWidgets('the right password unlocks without touching the sensor', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: false);

    await tester.pumpWidget(
      await boot(
        localAuth,
        stored: <String, Object>{
          'lock_methods': 'password',
          'lock_password_hash': AppPasscode.hash('1357'),
          'lock_password_digits': true,
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // Numeric password -> numeric keyboard, matching what was set.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.numberWithOptions());
    expect(localAuth.attempts, 0, reason: 'no sensor prompt over a live field');

    await tester.enterText(find.byType(TextField), '1357');
    await tester.tap(submit('افتح بكلمة السر'));
    await tester.pumpAndSettle();

    expect(locked(tester), isFalse);
    expect(find.text('اليوم'), findsOneWidget);
    expect(localAuth.attempts, 0);
  });

  testWidgets('a wrong password says so and keeps the lock', (tester) async {
    final localAuth = FakeLocalAuth(result: false);

    await tester.pumpWidget(
      await boot(
        localAuth,
        stored: <String, Object>{
          'lock_methods': 'password',
          'lock_password_hash': AppPasscode.hash('1357'),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(submit('افتح بكلمة السر'));
    await tester.pumpAndSettle();

    expect(find.text('كلمة السر غير صحيحة.'), findsOneWidget);
    expect(locked(tester), isTrue);
    expect(find.text('اليوم'), findsNothing);
    // And the failed answer did not linger in the field.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('both ways in: the password side alone can open', (tester) async {
    final localAuth = FakeLocalAuth(result: false);

    await tester.pumpWidget(
      await boot(
        localAuth,
        stored: <String, Object>{
          'lock_methods': 'both',
          'lock_password_hash': AppPasscode.hash('open sesame'),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Field AND sensor button stand together; nothing fires on its own.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('افتح'), findsOneWidget);
    expect(localAuth.attempts, 0);

    await tester.enterText(find.byType(TextField), 'open sesame');
    await tester.tap(submit('افتح بكلمة السر'));
    await tester.pumpAndSettle();

    expect(locked(tester), isFalse);
    expect(localAuth.attempts, 0);
  });

  testWidgets('both ways in: the sensor button still works', (tester) async {
    final localAuth = FakeLocalAuth(result: false);

    await tester.pumpWidget(
      await boot(
        localAuth,
        stored: <String, Object>{
          'lock_methods': 'both',
          'lock_password_hash': AppPasscode.hash('1357'),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);

    localAuth.result = true;
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    expect(locked(tester), isFalse);
    expect(localAuth.attempts, 1);
  });

  testWidgets('settings: picking password-only walks through choosing one', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: true);

    await tester.pumpWidget(await boot(localAuth, lockOn: false));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();

    final switchRow = find.text('قفل بالبصمة');
    await tester.scrollUntilVisible(
      switchRow,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(switchRow);
    await tester.pumpAndSettle();

    // Sensor present: the master switch simply turns on, method untouched.
    final methodRow = find.text('طريقة الفتح');
    await tester.scrollUntilVisible(
      methodRow,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(methodRow, findsOneWidget);

    await tester.tap(methodRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('كلمة سر فقط'));
    await tester.pumpAndSettle();

    // No password exists yet, so the setup sheet stands in the way first.
    expect(find.text('تعيين كلمة السر'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '24');
    await tester.enterText(find.byType(TextField).at(1), '24');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 أحرف على الأقل'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '2468');
    await tester.enterText(find.byType(TextField).at(1), '2468');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    // Stored: the method moved, and what was written verifies -- hashed, so
    // the plaintext exists nowhere on disk.
    expect(prefs.getString('lock_methods'), 'password');
    final storedHash = prefs.getString('lock_password_hash');
    expect(storedHash, isNotNull);
    expect(AppPasscode.verify('2468', storedHash!), isTrue);
    expect(AppPasscode.verify('0000', storedHash), isFalse);
    expect(prefs.getBool('lock_password_digits'), isTrue);
  });

  testWidgets('settings: a password already set switches methods directly', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: true);

    await tester.pumpWidget(
      await boot(
        localAuth,
        lockOn: false,
        stored: <String, Object>{
          'lock_password_hash': AppPasscode.hash('2468'),
          'lock_password_digits': true,
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();

    final switchRow = find.text('قفل بالبصمة');
    await tester.scrollUntilVisible(
      switchRow,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(switchRow);
    await tester.pumpAndSettle();

    final methodRow = find.text('طريقة الفتح');
    await tester.scrollUntilVisible(
      methodRow,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(methodRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('كلمة سر فقط'));
    await tester.pumpAndSettle();

    // A password already stands -- no setup sheet stands in the way. The
    // words "تعيين كلمة السر" do appear once, as the NEW settings row's
    // label; what must not exist is the sheet's input field.
    expect(find.byType(TextField), findsNothing);
    expect(prefs.getString('lock_methods'), 'password');
  });

  testWidgets('settings: backing out of the password sheet enables nothing', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(
      result: true,
      // No sensor on this device: enabling has to stand on a password, so the
      // setup sheet must come before the switch can mean anything.
      supported: false,
      enrolled: const <BiometricType>[],
    );

    await tester.pumpWidget(await boot(localAuth, lockOn: false));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();

    final switchRow = find.text('قفل بالبصمة');
    await tester.scrollUntilVisible(
      switchRow,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(switchRow);
    await tester.pumpAndSettle();

    // The setup sheet is up before anything was turned on; leaving it stores
    // nothing and enables nothing.
    expect(find.text('تعيين كلمة السر'), findsOneWidget);
    await tester.tap(find.byType(ModalBarrier).last);
    await tester.pumpAndSettle();

    expect(prefs.getString('lock_methods'), isNull);
    expect(prefs.getString('lock_password_hash'), isNull);
    expect(prefs.getBool('app_lock_enabled'), isFalse);
  });
}
