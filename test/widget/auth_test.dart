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
    Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
    Subject.seeded(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
    Subject.seeded(id: 4, code: SubjectCode.english, sortOrder: 3),
  ],
  chapters: const <dynamic>[].cast(),
  lessons: const <dynamic>[].cast(),
  exams: const <dynamic>[].cast(),
  homework: const <dynamic>[].cast(),
);

Future<Widget> boot(
  FakeAuthRepository auth, {
  bool lockOn = false,
  String profileName = '',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_lock_enabled': lockOn,
    if (profileName.isNotEmpty) 'profile_name': profileName,
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

/// Waits out a toast's 2.2s dwell and its fade.
///
/// The dwell is a real `Timer`, not an animation, so `pumpAndSettle` does not
/// reach it and the binding fails the test for leaving it pending.
Future<void> retireToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// Walks from the dashboard into the profile screen.
Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(DashboardScreen),
      matching: find.byType(SettingsButton),
    ),
  );
  await tester.pumpAndSettle();
  // The account header is labelled with the student's name, or their email
  // until they have set one. These tests set no name, and the address differs
  // between the email/password and Google fixtures.
  await tester.tap(find.textContaining('@').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a signed-out student lands on the login screen', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(
      find.text('تسجيل دخول واحد، ثم يعمل التطبيق دون اتصال'),
      findsOneWidget,
      reason: 'the screen has to state the deal: one sign-in, then offline',
    );
    // Nothing of the study app leaks past the gate.
    expect(find.text('اليوم'), findsNothing);
  });

  testWidgets('a cached session opens straight into the app', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    // No network was available to this test at any point -- the gate answered
    // from the session alone.
    expect(find.text('اليوم'), findsOneWidget);
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

    expect(find.text('اليوم'), findsOneWidget);
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

    expect(
      find.text('البريد الإلكتروني أو كلمة السر غير صحيحة'),
      findsOneWidget,
    );
    expect(find.text('اليوم'), findsNothing);
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
      find.textContaining('لا يوجد اتصال'),
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
    expect(find.text('البريد الإلكتروني غير صحيح'), findsOneWidget);

    // A short password on **sign-in** is not refused here, and that is
    // deliberate. The minimum used to apply to both paths; raising it to 8 with
    // that shape would have locked out every student who already has a 6- or
    // 7-character password, because sign-in does not care how long a password
    // is -- only whether it is right. A local floor there rejects a *correct*
    // password and blames the student for an account they own.
    await tester.enterText(find.byType(TextField).at(0), 'student@example.com');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(
      find.text('كلمة السر ٨ أحرف على الأقل'),
      findsNothing,
      reason: 'the server decides whether an existing password is right',
    );
  });

  testWidgets('a new password must reach 8 characters', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    // The mode toggle sits at the bottom of a scrolling form, below the fold on
    // the default test viewport, so it has to be brought into view the same way
    // a student would.
    final toggle = find.text('لا حساب لديك؟ أنشئ واحداً');
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'student@example.com');
    // Six characters: Firebase's own default floor, and what this app accepted
    // until the audit on 2026-08-15 found '123456' being taken by the live
    // project.
    await tester.enterText(find.byType(TextField).at(1), '123456');
    final submit = find.text('إنشاء حساب');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('كلمة السر ٨ أحرف على الأقل'), findsOneWidget);

    // And nothing was sent: validation refuses before the network is touched.
    expect(auth.currentAccount, isNull);

    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(auth.currentAccount, isNotNull);

    // Registering now raises the "we sent you a link" toast, whose 2.2s dwell
    // is a real timer the binding checks for before tearDown.
    await retireToast(tester);
  });

  testWidgets('the profile names the student and never leaves the device', (
    tester,
  ) async {
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth, profileName: 'ياسين'));
    await tester.pumpAndSettle();

    // The dashboard greets by name instead of naming the day. Not both: two
    // headings would push the first number further down for a greeting nobody
    // opens the app to read.
    expect(find.text('أهلاً، ياسين'), findsOneWidget);
    expect(find.text('اليوم'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();

    // The header carries the name over the email, and opens the profile.
    expect(find.text('ياسين'), findsOneWidget);
    await tester.tap(find.text('ياسين'));
    await tester.pumpAndSettle();

    expect(find.text('ملفك'), findsOneWidget);
    // The claim that decided where this is stored, stated on the screen that
    // stores it. If this line ever stops being true, this test fails first.
    expect(find.textContaining('محفوظة على هذا الجهاز وحده'), findsOneWidget);
  });

  testWidgets('a student with no name still gets a heading', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    expect(find.text('اليوم'), findsOneWidget);
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

    // The confirm button names the act ("تسجيل الخروج"), not a generic "حذف"
    // — sign-out deletes nothing, and a red button called Delete would say it
    // does.
    expect(find.text('حذف').hitTestable(), findsNothing);
    await tester.tap(find.text('تسجيل الخروج').hitTestable().last);
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
    expect(find.text('اليوم'), findsNothing);
  });

  // --- Email verification ----------------------------------------------------
  //
  // The rule these protect: **verification is asked for, never enforced.** The
  // gate already stands in front of the app, the database is local, and a
  // student locked out because they cannot reach an inbox loses their exam
  // history to enforce something nothing depends on.

  testWidgets('registering sends a verification link and says so', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('لا حساب لديك؟ أنشئ واحداً'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'student@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('إنشاء حساب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(auth.verificationsSent, 1);
    expect(find.text('بعتنالك رابط تأكيد على بريدك'), findsOneWidget);

    await retireToast(tester);
  });

  testWidgets('an unverified student still gets the whole app', (tester) async {
    final auth = FakeAuthRepository.signedInUnverified();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    // The one assertion that matters here. Nothing is withheld.
    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });

  testWidgets('the profile offers a resend while the address is unconfirmed', (
    tester,
  ) async {
    final auth = FakeAuthRepository.signedInUnverified();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();
    await openProfile(tester);

    expect(find.text('لم يتم تأكيده'), findsOneWidget);
    expect(
      find.textContaining('التطبيق شغال عادي من غيره'),
      findsOneWidget,
      reason: 'a prompt with no stated consequence reads as a threat',
    );

    await tester.tap(find.text('إعادة إرسال رابط التأكيد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(auth.verificationsSent, 1);
    expect(find.text('بعتنالك رابط تأكيد على بريدك'), findsOneWidget);

    await retireToast(tester);
  });

  testWidgets('a rate-limited resend says "wait", not "something broke"', (
    tester,
  ) async {
    final auth = FakeAuthRepository.signedInUnverified()
      ..nextVerificationFailure = AuthFailure.tooManyRequests;
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.tap(find.text('إعادة إرسال رابط التأكيد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.textContaining('استنى شوية'),
      findsOneWidget,
      reason: 'tapping twice is not a broken account',
    );
    expect(find.text('تعذّر إتمام العملية. حاول مرة أخرى.'), findsNothing);

    await retireToast(tester);
  });

  testWidgets('a verified account is never asked', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();
    await openProfile(tester);

    expect(find.text('لم يتم تأكيده'), findsNothing);
    expect(find.text('إعادة إرسال رابط التأكيد'), findsNothing);
  });

  testWidgets('a Google account arrives verified and is never asked', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المتابعة بحساب Google'));
    await tester.pumpAndSettle();

    expect(find.text('اليوم'), findsOneWidget);
    await openProfile(tester);

    expect(
      find.text('إعادة إرسال رابط التأكيد'),
      findsNothing,
      reason:
          'Google has already checked the address; asking again asks for '
          'a proof already given',
    );
  });

  testWidgets('opening the profile notices a link tapped in the inbox', (
    tester,
  ) async {
    final auth = FakeAuthRepository.signedInUnverified()
      ..verifyOnNextReload = true;
    addTearDown(auth.dispose);

    await tester.pumpWidget(await boot(auth));
    await tester.pumpAndSettle();
    await openProfile(tester);

    expect(auth.reloadCount, greaterThan(0));
    expect(
      find.text('إعادة إرسال رابط التأكيد'),
      findsNothing,
      reason:
          'the student verified while away; the screen must not still be '
          'telling them to',
    );
  });
}
