import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/auth/app_passcode.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/widgets/buttons.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/repositories/auth_repository.dart';
import 'package:ather/presentation/auth/lock_screen.dart' show formatLockWait;
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

  // D2: guessing is slowed, persistently, rather than free and unlimited.
  group('LockAttemptStore', () {
    test('five misses are free, then 30s doubling to a 15-minute cap', () {
      expect(LockAttemptStore.lockoutAfter(4), Duration.zero);
      expect(LockAttemptStore.lockoutAfter(5), const Duration(seconds: 30));
      expect(LockAttemptStore.lockoutAfter(6), const Duration(seconds: 60));
      expect(LockAttemptStore.lockoutAfter(9), const Duration(seconds: 480));
      // 30s * 2^5 = 16 min: past the cap.
      expect(LockAttemptStore.lockoutAfter(10), const Duration(minutes: 15));
      // No overflow into a negative duration on an absurd count.
      expect(LockAttemptStore.lockoutAfter(1000), const Duration(minutes: 15));
    });

    test('the refusal is on disk: a new store (a restarted app) sees it', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final t = DateTime(2026, 8, 5, 10);

      final before = LockAttemptStore(preferences);
      for (var i = 0; i < 5; i++) {
        await before.recordFailure(t);
      }

      final after = LockAttemptStore(preferences);
      expect(after.failures, 5);
      expect(after.lockedUntil(t), t.add(const Duration(seconds: 30)));
      expect(after.lockedUntil(t.add(const Duration(seconds: 30))), isNull);

      await after.reset();
      expect(preferences.getInt(kLockFailedAttemptsKey), isNull);
      expect(preferences.getInt(kLockLockedUntilKey), isNull);
    });

    test('wiping the account preferences takes the backoff with it', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kLockFailedAttemptsKey: 7,
        kLockLockedUntilKey: 1,
      });
      final preferences = await SharedPreferences.getInstance();
      await wipeAccountPreferences(preferences);
      expect(preferences.getInt(kLockFailedAttemptsKey), isNull);
      expect(preferences.getInt(kLockLockedUntilKey), isNull);
    });
  });

  test('the wait reads m:ss, rounded up, never 0:00 while still refusing', () {
    expect(formatLockWait(const Duration(seconds: 30)), '0:30');
    expect(formatLockWait(const Duration(milliseconds: 29001)), '0:30');
    expect(formatLockWait(const Duration(milliseconds: 1)), '0:01');
    expect(formatLockWait(const Duration(minutes: 15)), '15:00');
    expect(formatLockWait(const Duration(seconds: -3)), '0:00');
  });

  late SharedPreferences prefs;

  Future<Widget> boot(
    FakeLocalAuth localAuth, {
    bool lockOn = true,
    Map<String, Object> stored = const <String, Object>{},
    FakeAuthRepository? auth,
    MutableClock? clock,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_lock_enabled': lockOn,
      ...stored,
    });
    prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth ?? FakeAuthRepository.signedIn(),
        ),
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
        clockProvider.overrideWithValue(clock ?? MutableClock(now)),
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

  // The wait itself is named (m:ss, isolated): 30 s after the fifth miss.
  String tooMany(String wait) => 'محاولات كثيرة. حاول مرة أخرى بعد \u2066$wait\u2069.';
  const passwordLock = <String, Object>{'lock_methods': 'password'};

  testWidgets('five wrong passwords stop the gate listening, across a restart', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: false);
    final clock = MutableClock(now);
    final hash = AppPasscode.hash('1357');

    await tester.pumpWidget(
      await boot(
        localAuth,
        clock: clock,
        stored: <String, Object>{...passwordLock, 'lock_password_hash': hash},
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(submit('افتح بكلمة السر'));
      await tester.pumpAndSettle();
    }
    expect(find.text(tooMany('0:30')), findsOneWidget);

    // Even the right answer is not checked while the refusal runs.
    await tester.enterText(find.byType(TextField), '1357');
    await tester.tap(submit('افتح بكلمة السر'));
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);

    final failures = prefs.getInt('lock_failed_attempts');
    final until = prefs.getInt('lock_locked_until');
    expect(failures, 5);
    expect(until, now.add(const Duration(seconds: 30)).millisecondsSinceEpoch);

    // Killed and reopened on the same disk: the refusal is still there, and
    // says so before anyone types.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      await boot(
        localAuth,
        clock: clock,
        stored: <String, Object>{
          ...passwordLock,
          'lock_password_hash': hash,
          'lock_failed_attempts': failures!,
          'lock_locked_until': until!,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(tooMany('0:30')), findsOneWidget);
    // And it counts down with the clock.
    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(tooMany('0:20')), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1357');
    await tester.tap(submit('افتح بكلمة السر'));
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);

    // Once it has run out the message goes by itself, the right answer
    // opens, and the count starts over.
    clock.advance(const Duration(seconds: 21));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('محاولات كثيرة'), findsNothing);
    await tester.enterText(find.byType(TextField), '1357');
    await tester.tap(submit('افتح بكلمة السر'));
    await tester.pumpAndSettle();
    expect(locked(tester), isFalse);
    expect(prefs.getInt('lock_failed_attempts'), isNull);
    expect(prefs.getInt('lock_locked_until'), isNull);
  });

  testWidgets('a forgotten password: the account password removes the lock', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: false);
    final auth = FakeAuthRepository.signedIn();

    await tester.pumpWidget(
      await boot(
        localAuth,
        auth: auth,
        stored: <String, Object>{
          ...passwordLock,
          'lock_password_hash': AppPasscode.hash('1357'),
          'lock_password_digits': true,
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('نسيت كلمة سر التطبيق؟'));
    await tester.pumpAndSettle();
    // The field now asks for the account's password, in words.
    expect(find.textContaining('كلمة سر حسابك'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'account-password');
    await tester.tap(submit('افتح'));
    await tester.pumpAndSettle();

    expect(auth.reauthPasswords, <String>['account-password']);
    expect(locked(tester), isFalse);
    expect(find.text('اليوم'), findsOneWidget);
    // The whole lock went, not just this one opening.
    expect(prefs.getBool('app_lock_enabled'), isFalse);
    expect(prefs.getString('lock_methods'), isNull);
    expect(prefs.getString('lock_password_hash'), isNull);
    expect(prefs.getBool('lock_password_digits'), isNull);
  });

  testWidgets('a forgotten password on a Google account uses the Google sheet', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: false);
    final auth = FakeAuthRepository.signedIn()
      ..reauthMethodValue = ReauthMethod.google;

    await tester.pumpWidget(
      await boot(
        localAuth,
        auth: auth,
        stored: <String, Object>{
          ...passwordLock,
          'lock_password_hash': AppPasscode.hash('1357'),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('نسيت كلمة سر التطبيق؟'));
    await tester.pumpAndSettle();

    expect(auth.googleReauthCount, 1);
    expect(auth.reauthPasswords, isEmpty);
    expect(locked(tester), isFalse);
    expect(prefs.getString('lock_password_hash'), isNull);
  });

  testWidgets('a failed account check offline clears nothing and says why', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: false);
    final auth = FakeAuthRepository.signedIn()
      ..nextReauthFailure = AuthFailure.network;
    final hash = AppPasscode.hash('1357');

    await tester.pumpWidget(
      await boot(
        localAuth,
        auth: auth,
        stored: <String, Object>{...passwordLock, 'lock_password_hash': hash},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('نسيت كلمة سر التطبيق؟'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'account-password');
    await tester.tap(submit('افتح'));
    await tester.pumpAndSettle();

    expect(find.textContaining('اتصالك بالإنترنت'), findsOneWidget);
    expect(locked(tester), isTrue);
    expect(prefs.getBool('app_lock_enabled'), isTrue);
    expect(prefs.getString('lock_password_hash'), hash);
  });

  testWidgets('turning the lock off in Settings forgets the guessing count', (
    tester,
  ) async {
    final localAuth = FakeLocalAuth(result: true);

    // The lock is on and a backoff is still counting from earlier misses.
    await tester.pumpWidget(
      await boot(
        localAuth,
        stored: <String, Object>{
          'lock_failed_attempts': 7,
          'lock_locked_until': now
              .add(const Duration(minutes: 2))
              .millisecondsSinceEpoch,
        },
      ),
    );
    // The sensor answers: in, and a sensor success resets the count too --
    // so plant the stale count again to isolate the switch.
    await tester.pumpAndSettle();
    expect(locked(tester), isFalse);
    await prefs.setInt('lock_failed_attempts', 7);
    await prefs.setInt(
      'lock_locked_until',
      now.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
    );

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

    expect(prefs.getBool('app_lock_enabled'), isFalse);
    expect(prefs.getInt('lock_failed_attempts'), isNull);
    expect(prefs.getInt('lock_locked_until'), isNull);
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
