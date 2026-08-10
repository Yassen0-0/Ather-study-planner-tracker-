import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/domain/repositories/auth_repository.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backup.dart';
import '../support/fake_auth.dart';

/// The account gate.
///
/// The rule these tests protect is the one that made adding accounts to an
/// offline-first app defensible: **the gate is asked once, and it answers from
/// a cached session.** If it ever starts depending on a live check, a student
/// on the bus loses access to work that is sitting on their own phone.
final DateTime kNow = DateTime(2026, 8, 3);

StudySnapshot emptySnapshot() => StudySnapshot(
  subjects: const <Subject>[
    Subject(id: 1, code: SubjectCode.biology, sortOrder: 0),
    Subject(id: 2, code: SubjectCode.physics, sortOrder: 1),
    Subject(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
    Subject(id: 4, code: SubjectCode.english, sortOrder: 3),
  ],
  chapters: const <dynamic>[].cast(),
  lessons: const <dynamic>[].cast(),
  exams: const <dynamic>[].cast(),
  homework: const <dynamic>[].cast(),
);

Future<Widget> boot(FakeAuthRepository auth, {bool lockOn = false}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_lock_enabled': lockOn,
  });
  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      backupRepositoryProvider.overrideWithValue(
        FakeBackupRepository.failing(),
      ),
      sharedPreferencesProvider.overrideWithValue(preferences),
      snapshotProvider.overrideWith(
        (ref) => Stream<StudySnapshot>.value(emptySnapshot()),
      ),
      // Same reason as the snapshot override: these tests keep drift out, and
      // the backup gate reads tasks -- which would otherwise build a real
      // database and leave its stream timers pending past the test.
      tasksProvider.overrideWith(
        (ref) => Stream<List<DailyTask>>.value(const <DailyTask>[]),
      ),
      clockProvider.overrideWithValue(MutableClock(kNow)),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
    ],
    child: const AtherApp(),
  );
}

void main() {
  testWidgets('a signed-out student lands on the login screen', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(
      find.text('سجّل دخولك مرة واحدة بس — بعد كده التطبيق هيشتغل من غير نت'),
      findsOneWidget,
      reason: 'the screen has to state the deal: one sign-in, then offline',
    );
    // Nothing of the study app leaks past the gate.
    expect(find.text('النهارده'), findsNothing);
  });

  testWidgets('a cached session opens straight into the app', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    // No network was available to this test at any point -- the gate answered
    // from the session alone.
    expect(find.text('النهارده'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });

  testWidgets('signing in moves the student through the gate', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'student@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('النهارده'), findsOneWidget);
  });

  testWidgets('a bad password is explained, not swallowed', (tester) async {
    final auth = FakeAuthRepository()
      ..nextFailure = AuthFailure.wrongCredentials;
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'student@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrongpassword');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('الإيميل أو الباسورد غلط'), findsOneWidget);
    expect(find.text('النهارده'), findsNothing);
  });

  testWidgets('being offline says exactly that, and why it matters', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..nextFailure = AuthFailure.network;
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'student@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('مفيش اتصال بالنت'),
      findsOneWidget,
      reason: 'the one moment this app needs a network must be named plainly',
    );
  });

  testWidgets('local validation refuses before the network is touched', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.text('الإيميل مش مظبوط'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'student@example.com');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.text('الباسورد لازم 6 حروف على الأقل'), findsOneWidget);
  });

  testWidgets('signing out returns to the gate', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    // The cog in the dashboard header, scoped to that screen: the "المزيد" tab
    // is gone and every root screen carries a cog now.
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();

    // Settings is a scrolling list and the cloud-backup card now sits above the
    // account card, so sign-out starts below the fold on this surface. Scrolling
    // to it is the same thing a student does.
    await tester.scrollUntilVisible(
      find.text('تسجيل الخروج'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    // The confirmation says the data survives, because a student reading
    // "sign out" on a study app will assume the opposite.
    expect(find.textContaining('بياناتك محفوظة على الجهاز'), findsOneWidget);

    await tester.tap(find.text('حذف').hitTestable());
    await tester.pumpAndSettle();

    expect(auth.signOutCount, 1);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });

  testWidgets('the lock covers the app when it is switched on', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth, lockOn: true));
    await tester.pump();

    // The very first frame is the lock, never a glimpse of the dashboard.
    expect(find.text('أثر'), findsOneWidget);
    expect(find.text('النهارده'), findsNothing);
  });
}
