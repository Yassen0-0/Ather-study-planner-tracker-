import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ather/app/app.dart' show kSupportedLocales;
import 'package:ather/app/router.dart' show rootNavigatorKey;
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/domain/entities/account.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/data/repositories/drift_task_repository.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_gate.dart';
import 'package:ather/presentation/providers/backup_providers.dart'
    show SyncStatus, backupRepositoryProvider, backupSyncProvider;
import 'package:ather/domain/repositories/backup_repository.dart'
    show BackupFailure;

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

/// Signing into a different account, when this phone already holds data.
///
/// This wipe is the one destructive act in the app with no undo, and it used
/// to be its only unconfirmed one -- reachable by mis-tapping "create account"
/// beside "sign in" on the shared form. Everything below drives the real gate,
/// over a real SQLite file, through the real sheet, in Arabic, because the
/// copy on those buttons is part of the contract.
///
/// The gate presents against the root navigator's context rather than a
/// screen's, so the harness mounts the same key the router uses.
void main() {
  late AppDatabase db;
  late FakeAuthRepository auth;
  late FakeBackupRepository backup;
  late SharedPreferences preferences;

  final DateTime now = DateTime(2026, 8, 5);

  /// Boots the gate alone under a MaterialApp whose navigator **is** the root
  /// navigator, with [seeded] deciding whether the device holds a record.
  Future<Widget> boot({required bool seeded}) async {
    if (seeded) {
      final study = DriftStudyRepository(db);
      final chapterId = await study.createChapter(
        subjectId: 1,
        name: 'شغل الطالب',
        at: now,
      );
      await DriftTaskRepository(db).addTask(
        day: DateTime(2026, 8, 5),
        title: 'مهمة',
        at: now,
      );
      await study.createLesson(chapterId: chapterId, name: 'درس', at: now);
    }

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        backupRepositoryProvider.overrideWithValue(backup),
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(MutableClock(now)),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // The app's own theme, not the bare default: the sheet and its buttons
        // read the theme extensions (`context.colors`), and without them the
        // confirmation would fail into its no-wipe fallback instead of being
        // shown -- testing the fallback rather than the question.
        theme: AppTheme.light,
        navigatorKey: rootNavigatorKey,
        home: BackupSyncGate(
          child: Consumer(
            builder: (context, ref, _) {
              // Stands in for every screen the real app runs beneath the gate:
              // they all watch this stream, which is what keeps its provider
              // element alive and fed. Without a watcher here the gate's read
              // of `snapshotProvider.future` initialises it alone, nothing
              // holds the element through its first emission, and the wipe
              // decision waits forever on an answer that was never delivered.
              ref.watch(snapshotProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  /// Tears the tree down inside the test body, then lets drift's cancellation
  /// bookkeeping finish.
  ///
  /// The snapshot stream is a six-way combine whose unsubscribe cascades
  /// through several async hops before each underlying query schedules its
  /// zero-duration close timer -- and whichever hops land back inside the fake
  /// async zone register timers the binding refuses to see left pending. The
  /// real-time window below lets the whole cascade settle outside it; the
  /// final pump sweeps up whatever straggled back.
  Future<void> closeGate(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    auth = FakeAuthRepository.signedIn();
    backup = FakeBackupRepository();
    SharedPreferences.setMockInitialValues(<String, Object>{
      // The device already belongs to the signed-in student -- the state after
      // any normal session, and the state that makes the next sign-in a
      // decision rather than an event nobody notices.
      kLastAccountUidKey: 'test-uid',
    });
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() => auth.dispose());

  testWidgets('a different uid on a populated device asks before wiping',
      (tester) async {
    await tester.pumpWidget(await boot(seeded: true));
    await tester.pumpAndSettle();

    // A second student arrives -- by Google, by a second email, or by the
    // "create account" button sitting beside "sign in". All three land here.
    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    expect(find.text('حساب مختلف'), findsOneWidget);
    expect(find.text('امسح بيانات الجهاز'), findsOneWidget);

    // Refused.
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await closeGate(tester);

    final kept = await tester.runAsync(
      () => DriftStudyRepository(db).readSnapshot(),
    );
    // Not one byte moved.
    expect(kept!.chapters.map((c) => c.name), contains('شغل الطالب'));
    expect(
      await tester.runAsync(() => DriftTaskRepository(db).watchTasks().first),
      hasLength(1),
    );
    // Still claiming the old uid: the next launch asks again rather than
    // inheriting a consent nobody gave.
    expect(preferences.getString(kLastAccountUidKey), 'test-uid');
    // And nothing was pulled down onto a device we were told not to touch --
    // skipping the wipe skips this session's auto-restore with it.
    expect(backup.downloadCount, 0);
  });

  testWidgets('confirming wipes the device and resumes the ordinary restore',
      (tester) async {
    await tester.pumpWidget(await boot(seeded: true));
    await tester.pumpAndSettle();

    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    await tester.tap(find.text('امسح بيانات الجهاز'));
    await tester.pumpAndSettle();

    await closeGate(tester);

    final wiped = await tester.runAsync(
      () => DriftStudyRepository(db).readSnapshot(),
    );
    expect(wiped!.chapters, isEmpty);
    expect(
      await tester.runAsync(() => DriftTaskRepository(db).watchTasks().first),
      isEmpty,
    );
    expect(preferences.getString(kLastAccountUidKey), 'google-uid');
    // The device is genuinely empty now, so the normal auto-restore ran --
    // found nothing in this new account's cloud, and left it empty.
    expect(backup.downloadCount, 1);
  });

  testWidgets('an empty device changes hands without asking', (tester) async {
    await tester.pumpWidget(await boot(seeded: false));
    await tester.pumpAndSettle();

    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    // Nothing on the phone, nothing to mourn -- the current UX stays.
    expect(find.text('حساب مختلف'), findsNothing);
    expect(find.text('امسح بيانات الجهاز'), findsNothing);

    await closeGate(tester);

    expect(preferences.getString(kLastAccountUidKey), 'google-uid');
  });

  testWidgets('a legacy device with no recorded uid asks before wiping too',
      (tester) async {
    // The C1 upgrade path: this phone ran Ather all year before logins
    // existed -- no `kLastAccountUidKey`, no session -- yet it holds student
    // A's whole record. The first account this gate ever sees is therefore
    // student B signing in, and "no recorded account" must decide exactly the
    // way "a different account" does, from the data actually present.
    // Otherwise backgrounding once uploads A's curriculum into B's cloud
    // document.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    auth = FakeAuthRepository();
    expect(preferences.getString(kLastAccountUidKey), isNull);

    await tester.pumpWidget(await boot(seeded: true));
    await tester.pumpAndSettle();

    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    expect(find.text('حساب مختلف'), findsOneWidget);
    expect(find.text('امسح بيانات الجهاز'), findsOneWidget);

    // Confirming hands the device over exactly like any other switch.
    await tester.tap(find.text('امسح بيانات الجهاز'));
    await tester.pumpAndSettle();

    await closeGate(tester);

    final wiped = await tester.runAsync(
      () => DriftStudyRepository(db).readSnapshot(),
    );
    expect(wiped!.chapters, isEmpty);
    expect(preferences.getString(kLastAccountUidKey), 'google-uid');
  });

  testWidgets('the same student signing back in asks nothing', (tester) async {
    await tester.pumpWidget(await boot(seeded: true));
    await tester.pumpAndSettle();

    // A token refresh re-emits the very same account; so does signing out and
    // back in as yourself. Neither is somebody else arriving.
    auth.verifyOnNextReload = true;
    await tester.runAsync(() => auth.reloadAccount());
    await tester.pumpAndSettle();

    expect(find.text('حساب مختلف'), findsNothing);

    await closeGate(tester);

    final kept = await tester.runAsync(
      () => DriftStudyRepository(db).readSnapshot(),
    );
    expect(kept!.chapters, hasLength(1));
    expect(preferences.getString(kLastAccountUidKey), 'test-uid');
  });

  testWidgets('dismissing the sheet from outside refuses the wipe too',
      (tester) async {
    await tester.pumpWidget(await boot(seeded: true));
    await tester.pumpAndSettle();

    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    expect(find.text('حساب مختلف'), findsOneWidget);

    // Neither button pressed: the student escapes the question with no
    // answer at all -- a stray swipe or a tap on the dimmed area closes the
    // sheet, and `confirmDestructive` reads that null result as "no". Popping
    // the sheet route directly exercises the same contract without betting
    // the assertion on barrier hit-testing inside the nested go_router tree.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await tester.pumpAndSettle();

    expect(find.text('حساب مختلف'), findsNothing);

    await closeGate(tester);

    final kept = await tester.runAsync(
      () => DriftStudyRepository(db).readSnapshot(),
    );
    // Not one byte moved.
    expect(kept!.chapters.map((c) => c.name), contains('شغل الطالب'));
    expect(
      await tester.runAsync(() => DriftTaskRepository(db).watchTasks().first),
      hasLength(1),
    );
    // Still claiming the old uid.
    expect(preferences.getString(kLastAccountUidKey), 'test-uid');
    // And nothing was pulled down either.
    expect(backup.downloadCount, 0);
  });

  testWidgets('the switch wipe clears every student preference too',
      (tester) async {
    // D-01 + SEC-04: the database was only half of what student A leaves on
    // the phone. Drafts keyed by lesson id would resurface under B once ids
    // restart at 1; the name, year and lock configuration are A's as well.
    // Device-level choices -- locale here -- are nobody's student record and
    // stay.
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLastAccountUidKey: 'test-uid',
      'profile_name': 'أحمد',
      'profile_year': 2,
      kLockEnabledKey: true,
      kLockMethodKey: 'password',
      kPasscodeHashKey: 'salt:digest',
      kPasscodeDigitsKey: false,
      kLastCloudDownloadKey: 1754300000000,
      // The wizard writes one per lesson, so two shapes of stale draft.
      'exam_draft_5': '[["12","1","9"]]',
      'exam_draft_12': 'not json at all',
      'locale_code': 'en',
    });
    preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(await boot(seeded: true));
    await tester.pumpAndSettle();

    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    await tester.tap(find.text('امسح بيانات الجهاز'));
    await tester.pumpAndSettle();

    await closeGate(tester);

    final surviving = preferences.getKeys();
    expect(
      surviving.where((key) => key.startsWith('exam_draft_')),
      isEmpty,
      reason: "student A's drafts must not be here for student B",
    );
    for (final key in <String>[
      'profile_name',
      'profile_year',
      kLockEnabledKey,
      kLockMethodKey,
      kPasscodeHashKey,
      kPasscodeDigitsKey,
      kLastCloudDownloadKey,
    ]) {
      expect(surviving, isNot(contains(key)), reason: '$key survived');
    }
    expect(preferences.getString(kLastAccountUidKey), 'google-uid');
    expect(preferences.getString('locale_code'), 'en');
  });

  testWidgets('a failed offline auto-restore reaches the sync card (N14)',
      (tester) async {
    // The swallow used to make the download's failure invisible: offline at
    // sign-in looked identical to "checked, nothing there", and nothing said
    // why the cloud copy had not arrived. It must land on the card as a
    // failure, same as a failed upload does.
    backup = FakeBackupRepository.failing();

    await tester.pumpWidget(await boot(seeded: false));
    await tester.pumpAndSettle();

    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupSyncGate)),
    );
    final sync = container.read(backupSyncProvider);
    expect(sync.status, SyncStatus.failed);
    expect(sync.failure, BackupFailure.offline);

    // The sync notifier now holds the tasks stream, whose first query lands
    // across zone timers -- give it frames rather than leaving the provider
    // to be disposed mid-load when the tree comes down.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    await closeGate(tester);
  });

  testWidgets('a third account is asked again within the same session',
      (tester) async {
    // The session opens owned by an account neither of the two uids the fake
    // can mint ever equals: the fake signs in only as 'test-uid' (email form)
    // or 'google-uid' (Google), so the original owner takes that third seat
    // and both arrivals below are genuinely different students.
    await preferences.setString(kLastAccountUidKey, 'owner-uid');
    auth = FakeAuthRepository(
      const Account(id: 'owner-uid', email: 'owner@example.com'),
    );

    await tester.pumpWidget(await boot(seeded: true));
    await tester.pumpAndSettle();

    // First arrival refuses.
    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    expect(find.text('حساب مختلف'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(preferences.getString(kLastAccountUidKey), 'owner-uid');

    // Second arrival, same session, nobody signed out in between. B's refusal
    // must not be inherited as C's consent: every new account resets the
    // once-per-session guard, so the question stands in front of this one too.
    await auth.signIn(email: 'third@example.com', password: 'secret');
    await tester.pumpAndSettle();

    expect(find.text('حساب مختلف'), findsOneWidget);

    // And this time the hand-over goes through.
    await tester.tap(find.text('امسح بيانات الجهاز'));
    await tester.pumpAndSettle();

    await closeGate(tester);

    final wiped = await tester.runAsync(
      () => DriftStudyRepository(db).readSnapshot(),
    );
    expect(wiped!.chapters, isEmpty);
    expect(
      await tester.runAsync(() => DriftTaskRepository(db).watchTasks().first),
      isEmpty,
    );
    expect(preferences.getString(kLastAccountUidKey), 'test-uid');
    // The ordinary auto-restore ran for the account that said yes.
    expect(backup.downloadCount, 1);
  });

  testWidgets('backgrounding after a refusal uploads nothing',
      (tester) async {
    await tester.pumpWidget(await boot(seeded: true));
    await tester.pumpAndSettle();

    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    // Pausing is the last moment before the app may be killed, so this is
    // exactly when the flush runs -- with 'google-uid' signed in over a device
    // that still claims 'test-uid'. That mismatch is the same guard the wipe
    // refused to cross: uploading here would push one student's record into
    // another student's cloud document.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(backup.uploadCount, 0);

    // Back to the foreground changes nothing: resume is not a flush trigger,
    // and the unanswered question stays unanswered.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(backup.uploadCount, 0);

    expect(preferences.getString(kLastAccountUidKey), 'test-uid');
    expect(backup.downloadCount, 0);

    await closeGate(tester);

    final kept = await tester.runAsync(
      () => DriftStudyRepository(db).readSnapshot(),
    );
    expect(kept!.chapters.map((c) => c.name), contains('شغل الطالب'));
  });
}
