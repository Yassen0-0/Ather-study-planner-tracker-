import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';
import '../support/fake_local_auth.dart';

/// The biometric lock, and specifically the ways it used to be skippable.
///
/// The lock shipped decorative: **every** failure path ran the same
/// `unlocked = true` branch, so a cancelled prompt, a back press or a
/// too-many-attempts lockout all opened the app. And because the lock is a gate
/// rather than a route, a system back press fell straight through to the router
/// underneath. Both are asserted here, because neither is visible from the code
/// and neither was catchable without a fake authenticator.
void main() {
  final DateTime now = DateTime(2026, 8, 5);

  Future<Widget> boot(FakeLocalAuth localAuth) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_lock_enabled': true,
    });
    final preferences = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(FakeBackupRepository.failing()),
        localAuthProvider.overrideWithValue(localAuth),
        sharedPreferencesProvider.overrideWithValue(preferences),
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

  /// A system back press, delivered the way Android delivers it — through the
  /// navigation channel to the Router's back-button dispatcher.
  Future<void> pressSystemBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('popRoute'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  bool locked(WidgetTester tester) => find.text('التطبيق مقفول').evaluate().isNotEmpty;

  testWidgets('the back button does not get past the lock', (tester) async {
    // The prompt refuses, as it does when a student cancels it.
    final localAuth = FakeLocalAuth(result: false);

    await tester.pumpWidget(await boot(localAuth));
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);

    await pressSystemBack(tester);
    await pressSystemBack(tester);

    expect(
      locked(tester),
      isTrue,
      reason: 'back must not reach the router underneath the gate',
    );
    expect(find.text('النهارده'), findsNothing);
  });

  testWidgets('a refused prompt keeps the lock on and says so', (tester) async {
    final localAuth = FakeLocalAuth(result: false);

    await tester.pumpWidget(await boot(localAuth));
    await tester.pumpAndSettle();

    expect(locked(tester), isTrue);
    expect(find.text('مفتحش — جرّب تاني'), findsOneWidget);
    expect(find.text('النهارده'), findsNothing);
  });

  testWidgets('being locked out does not unlock the app', (tester) async {
    // The worst of the old bypasses: fail enough times that the OS locks the
    // sensor, and the catch-all opened the app.
    final localAuth = FakeLocalAuth(throwCode: LocalAuthExceptionCode.temporaryLockout);

    await tester.pumpWidget(await boot(localAuth));
    await tester.pumpAndSettle();

    expect(locked(tester), isTrue);
    expect(find.textContaining('حاولت كتير'), findsOneWidget);
    expect(find.text('النهارده'), findsNothing);
  });

  testWidgets('an unrecognised platform failure keeps the lock on', (
    tester,
  ) async {
    // uiUnavailable is the modern spelling of the no_fragment_activity
    // misconfiguration. Releasing on it is how it stayed hidden once before.
    final localAuth = FakeLocalAuth(throwCode: LocalAuthExceptionCode.uiUnavailable);

    await tester.pumpWidget(await boot(localAuth));
    await tester.pumpAndSettle();

    expect(locked(tester), isTrue);
    expect(find.text('النهارده'), findsNothing);
  });

  testWidgets('a device with nothing enrolled releases the lock', (
    tester,
  ) async {
    // The one case that must still release: the sensor can never say yes, and
    // holding a student's own study record hostage behind it is worse than not
    // locking at all.
    final localAuth = FakeLocalAuth(throwCode: LocalAuthExceptionCode.noBiometricsEnrolled);

    await tester.pumpWidget(await boot(localAuth));
    await tester.pumpAndSettle();

    expect(locked(tester), isFalse);
    expect(find.text('النهارده'), findsOneWidget);
  });

  testWidgets('a successful prompt opens the app', (tester) async {
    final localAuth = FakeLocalAuth(result: true);

    await tester.pumpWidget(await boot(localAuth));
    await tester.pumpAndSettle();

    expect(locked(tester), isFalse);
    expect(find.text('النهارده'), findsOneWidget);
    expect(localAuth.attempts, 1);
  });

  testWidgets('retrying after a refusal can still succeed', (tester) async {
    final localAuth = FakeLocalAuth(result: false);

    await tester.pumpWidget(await boot(localAuth));
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);

    localAuth.result = true;
    await tester.tap(find.text('افتح بالبصمة'));
    await tester.pumpAndSettle();

    expect(locked(tester), isFalse);
    expect(find.text('النهارده'), findsOneWidget);
  });
}
