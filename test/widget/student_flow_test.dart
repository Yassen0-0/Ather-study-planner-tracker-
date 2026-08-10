import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';

import '../support/fake_backup.dart';
import '../support/fake_auth.dart';

/// Numbers are rendered wrapped in Unicode isolates so they read correctly
/// inside Arabic sentences; a finder has to look for the same thing the user
/// sees, isolates and all.
String iso(String value) => '\u2066$value\u2069';

/// The journey a real student actually takes on day one, against a real
/// database: empty app -> first chapter -> first lesson -> first exam ->
/// a mastery number that came from the paper they sat.
///
/// Every earlier test either exercised the calculators without a UI or the UI
/// without a database. This one is the seam between them, which is where a
/// redesign is most likely to break something that still compiles.
void main() {
  late AppDatabase db;
  final DateTime now = DateTime(2026, 8, 3);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<Widget> boot() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(
          FakeBackupRepository.failing(),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(MutableClock(now)),
        // The production clock re-emits every minute to keep "days overdue"
        // honest; that periodic timer outlives the test binding.
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
      ],
      child: const AtherApp(),
    );
  }

  testWidgets('empty app to a first recorded exam', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();

    // Nothing has been proven, so nothing claims a score.
    expect(find.text('—'), findsWidgets);

    // --- Build the curriculum ------------------------------------------------
    await tester.tap(find.text('أحياء'));
    await tester.pumpAndSettle();
    expect(find.text('مفيش أبواب لسه'), findsOneWidget);

    await tester.tap(find.text('+ إضافة باب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'الباب الأول');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('الباب الأول'), findsWidgets);

    await tester.tap(find.text('الباب الأول').first);
    await tester.pumpAndSettle();
    expect(find.text('مفيش دروس لسه'), findsOneWidget);

    await tester.tap(find.text('+ إضافة درس'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'تركيب الخلية');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    // A chapter with an unexamined lesson can never be mastered, and the gate
    // says so instead of going quiet.
    expect(find.text('لسه مش جاهز — اعرف ليه'), findsOneWidget);

    // --- Record the exam -----------------------------------------------------
    await tester.tap(find.text('تركيب الخلية').first);
    await tester.pumpAndSettle();
    expect(find.text('ابدأ الامتحان'), findsOneWidget);

    await tester.tap(find.text('ابدأ الامتحان'));
    await tester.pumpAndSettle();

    // Step 1: total questions. An empty total is refused with a reason.
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('لازم سؤال واحد على الأقل'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '4');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    // Step 2: four questions worth one mark each.
    await tester.enterText(find.byType(TextField).at(0), '4');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    // Step 3: three of them right. More right than asked is refused.
    await tester.enterText(find.byType(TextField).first, '9');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('عدد الصح مينفعش يزيد عن عدد الأسئلة'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '3');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    // Step 4: the student never typed a percentage; the app derived it.
    expect(find.text(iso('75%')), findsWidgets);

    await tester.tap(find.text('احفظ النتيجة'));
    await tester.pumpAndSettle();

    // Back on the lesson, with the score and the confirmation.
    expect(
      find.text('اتسجّل الامتحان — عداد المراجعة بدأ من جديد'),
      findsOneWidget,
    );
    expect(find.text(iso('75%')), findsWidgets);
    expect(
      find.text('باقي ${iso('30')} يوم'),
      findsOneWidget,
      reason: 'recording an exam restarts the 30-day review clock',
    );

    // Recording an exam ticks "حليت الامتحان" and nothing else.
    expect(find.text(iso('1 / 5')), findsOneWidget);

    // Let the toast retire itself; its 2.2s timer outlives the test otherwise.
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.text('اتسجّل الامتحان — عداد المراجعة بدأ من جديد'),
      findsNothing,
    );

    // Drift keeps stream-query timers alive; closing here rather than in
    // tearDown lets them drain before the binding checks for pending timers.
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });
}
