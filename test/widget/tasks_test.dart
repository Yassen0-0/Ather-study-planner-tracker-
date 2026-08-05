import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout, kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/widgets/ather_icons.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_task_repository.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/tasks/tasks_screen.dart';
import 'package:ather/presentation/tasks/widgets/task_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backup.dart';
import '../support/fake_auth.dart';

/// Numbers reach the screen wrapped in Unicode isolates so they read correctly
/// inside an Arabic sentence, and a finder has to look for the same thing the
/// student sees. Written as escapes, not literals: pasted raw, the isolate
/// characters silently reorder this source file in an editor.
String iso(Object value) => '\u2066$value\u2069';

/// The tasks screen, driven through the real UI against real SQLite.
///
/// Written this way for the same reason as `student_flow_test.dart`: the seam
/// between a screen and a database is where a change most reliably breaks
/// something that still compiles. A test against a stubbed repository would
/// have passed the entire time a reorder was renumbering the wrong day's rows.
void main() {
  late AppDatabase db;

  /// A Wednesday, so the week it falls in has days on both sides of it.
  final DateTime now = DateTime(2026, 8, 5);
  final DateTime saturday = DateTime(2026, 8, 1);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  /// Tears the tree down **inside** the test body, then pumps twice.
  ///
  /// Drift schedules a zero-duration timer when a `.watch()` stream is
  /// cancelled, and this screen holds two of those (tasks, and the study
  /// snapshot). The binding checks for pending timers before `tearDown` runs,
  /// so the disposal has to happen inside the body -- and the timers are
  /// created *during* the first pump's `finalizeTree`, which is why one pump is
  /// not enough. Without this every test here fails with "A Timer is still
  /// pending even after the widget tree was disposed".
  ///
  /// The in-memory database is deliberately **not** closed: `close()` on a
  /// connection whose streams are still unwinding does not return under the
  /// fake clock, and it dies with the test process anyway.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // A real elapsed duration, not a bare pump: the timers are zero-duration
    // and are created during the previous frame, so the clock has to move for
    // fake_async to fire them.
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Widget> boot() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(FakeBackupRepository.failing()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(MutableClock(now)),
        // The production clock re-emits every minute; that periodic timer
        // outlives the test binding.
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
      ],
      child: const AtherApp(),
    );
  }

  void phoneSized(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> openTasks(WidgetTester tester, {bool reduced = false}) async {
    final app = await boot();
    await tester.pumpWidget(
      reduced
          ? MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: app,
            )
          : app,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('مهامك'));
    await tester.pumpAndSettle();
  }

  Future<void> addTask(WidgetTester tester, String title) async {
    await tester.tap(find.text('+ إضافة مهمة').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), title);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
  }

  /// The pencil on a task row. Found by glyph rather than by a test-only key:
  /// the row has exactly one edit icon, and asserting on the glyph is asserting
  /// on what the student actually sees.
  Finder pencil() => find.descendant(
    of: find.byType(TaskRow),
    matching: find.byWidgetPredicate(
      (w) => w is AtherIcon && w.glyph == AtherGlyph.edit,
    ),
  );

  /// A weekday letter in **this** screen's strip. The dashboard branch stays
  /// mounted behind the cross-fade and carries an identical strip, so an
  /// unscoped `find.text('س')` matches two widgets.
  Finder day(WidgetTester tester, String letter) => find.descendant(
    of: find.byType(TasksScreen),
    matching: find.text(letter),
  );

  /// Reads what is actually on disk for [day].
  ///
  /// Through `runAsync` because a widget test runs in a fake-async zone: a
  /// database future awaited directly there never completes, since nothing
  /// advances the clock or drains the microtask queue while the body is
  /// suspended. This is the difference between a test that fails and a test
  /// that hangs for ten minutes.
  Future<List<DailyTask>> tasksOn(WidgetTester tester, DateTime day) async {
    final all = await tester.runAsync(
      () => DriftTaskRepository(db).watchTasks().first,
    );
    return <DailyTask>[
      for (final task in all!)
        if (task.day == dayOf(day)) task,
    ];
  }

  testWidgets('an empty day offers the one thing to do', (tester) async {
    phoneSized(tester);
    await openTasks(tester);

    expect(find.text('مهام النهارده'), findsOneWidget);
    expect(find.text('مفيش مهام لليوم ده'), findsOneWidget);
    // Nothing here measures anything: no percentage, no mastery bar.
    expect(find.textContaining('%'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('adding a task, then ticking it', (tester) async {
    phoneSized(tester);
    await openTasks(tester);

    await addTask(tester, 'أذاكر الباب الأول');
    expect(find.text('أذاكر الباب الأول'), findsOneWidget);
    // The count line, in the app's "X من Y" grammar with isolated numbers.
    expect(find.text('${iso(0)} من ${iso(1)} خلصتهم'), findsOneWidget);

    // Tapping the row is the primary act — the whole card, not a small disc.
    await tester.tap(find.text('أذاكر الباب الأول'));
    await tester.pumpAndSettle();

    expect(find.text('${iso(1)} من ${iso(1)} خلصتهم'), findsOneWidget);
    expect((await tasksOn(tester, now)).single.done, isTrue);

    // And it toggles back off, rather than being a one-way door.
    await tester.tap(find.text('أذاكر الباب الأول'));
    await tester.pumpAndSettle();
    expect((await tasksOn(tester, now)).single.done, isFalse);

    await closeApp(tester);
  });

  testWidgets('the pencil renames and deletes', (tester) async {
    phoneSized(tester);
    await openTasks(tester);
    await addTask(tester, 'أحل امتحان');

    await tester.tap(pencil());
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل المهمة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'أحل امتحان الباب الأول');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect((await tasksOn(tester, now)).single.title, 'أحل امتحان الباب الأول');

    await tester.tap(pencil());
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المهمة'));
    await tester.pumpAndSettle();
    // Deletes are confirmed everywhere in this app, and tasks are no exception.
    await tester.tap(find.text('حذف').hitTestable());
    await tester.pumpAndSettle();

    expect(await tasksOn(tester, now), isEmpty);
    expect(find.text('مفيش مهام لليوم ده'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('a long press and drag persists the new order', (tester) async {
    phoneSized(tester);
    await openTasks(tester);

    await addTask(tester, 'الأولى');
    await addTask(tester, 'التانية');

    expect(<String>[
      for (final t in await tasksOn(tester, now)) t.title,
    ], <String>['الأولى', 'التانية']);

    // Captured before the drag starts: once a row is picked up the others move.
    final target = tester.getCenter(find.text('الأولى'));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('التانية')),
    );
    // Long press, which is the gesture ReorderableListView installs on touch
    // platforms and the one the row was designed around — there is no handle.
    await tester.pump(kLongPressTimeout + kPressTimeout);
    await gesture.moveTo(target);
    await tester.pump(kPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      <String>[for (final t in await tasksOn(tester, now)) t.title],
      <String>['التانية', 'الأولى'],
      reason: 'the drag has to reach sortOrder, not just the widget tree',
    );

    await closeApp(tester);
  });

  testWidgets('each day keeps its own list', (tester) async {
    phoneSized(tester);
    await openTasks(tester);
    await addTask(tester, 'مهمة النهارده');

    // The strip is a picker on this screen. "س" is the Saturday that opened the
    // week 2026-08-05 falls in. Scoped to this screen: the dashboard branch
    // stays mounted behind the cross-fade and carries its own week strip.
    await tester.tap(day(tester, 'س'));
    await tester.pumpAndSettle();

    expect(find.text('مهمة النهارده'), findsNothing);
    expect(find.text('مفيش مهام لليوم ده'), findsOneWidget);
    // The title stops claiming to be today the moment another day is picked.
    expect(find.text('مهام النهارده'), findsNothing);

    await addTask(tester, 'مهمة السبت');
    expect(await tasksOn(tester, saturday), hasLength(1));
    expect(await tasksOn(tester, now), hasLength(1));

    // Back to Wednesday, and nothing has leaked either way.
    await tester.tap(day(tester, 'ر'));
    await tester.pumpAndSettle();
    expect(find.text('مهمة النهارده'), findsOneWidget);
    expect(find.text('مهمة السبت'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('reduced motion renders the row with no fade layer at all', (
    tester,
  ) async {
    phoneSized(tester);
    await openTasks(tester, reduced: true);
    await addTask(tester, 'مهمة');

    expect(find.text('مهمة'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TaskRow),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    await closeApp(tester);
  });
}
