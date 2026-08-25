import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout, kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/haptics/app_haptics.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/widgets/ather_icons.dart';
import 'package:ather/core/widgets/pop_in.dart';
import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_task_repository.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/tasks/tasks_screen.dart';
import 'package:ather/presentation/tasks/widgets/task_row.dart';
import 'package:ather/core/widgets/task_strike_marks.dart';
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

  /// The same strings the running app resolves to (Arabic is the app's
  /// fallback locale). Newer keys are asserted through [lookupL] rather than
  /// pasted literals so the test pins the wiring — the right key with the
  /// right arguments — and stays honest wherever the copy itself is tuned.
  final L l = lookupL(const Locale('ar'));

  /// A Wednesday, so the week it falls in has days on both sides of it.
  final DateTime now = DateTime(2026, 8, 5);
  /// The day before [now], which is the neighbour the picker always shows.
  ///
  /// It used to be the Saturday that opened the week, because the strip that
  /// stood here put all seven days on screen at once. The picker shows the days
  /// that *fit* — three on a phone — so a test that reaches four days back is a
  /// test asserting on a cell that is deliberately not rendered.
  final DateTime yesterday = DateTime(2026, 8, 4);

  /// Haptic cues recorded through the class's own dispatch seam (the
  /// `app_haptics_test.dart` recorder pattern). Statics outlive tests, so the
  /// seam is reinstalled and the gate forced open for every test here.
  final List<AppHapticCue> haptics = <AppHapticCue>[];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    haptics.clear();
    AppHaptics.send = haptics.add;
    AppHaptics.configure!(true);
  });

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
        backupRepositoryProvider.overrideWithValue(
          FakeBackupRepository.failing(),
        ),
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

  /// The surrender control on a task row, by its painted slashed-circle face
  /// rather than a test-only key: asserting on the glyph is asserting on what
  /// the student actually sees.
  Finder surrenderButton() => find.descendant(
    of: find.byType(TaskRow),
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is SurrenderMarkIconPainter,
    ),
  );

  /// A strike mark drawn **over** a task title (foregroundPainter, never
  /// TextDecoration), typed so the straight and zigzag marks assert apart.
  Finder strike<T extends CustomPainter>() => find.descendant(
    of: find.byType(TaskRow),
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.foregroundPainter is T,
    ),
  );

  /// The state label the row publishes for screen readers. Found as a widget
  /// property because widget tests run with the semantics tree disabled.
  Finder semantics(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  /// A cell in **this** screen's day picker, by the text a student reads on it.
  ///
  /// Scoped to the screen even though the dashboard no longer carries a picker
  /// of its own: the tasks branch stays mounted behind the tab cross-fade, and
  /// a finder that stops depending on which branch is in front is a finder that
  /// keeps working when one is added back.
  Finder day(WidgetTester tester, String label) => find.descendant(
    of: find.byType(TasksScreen),
    matching: find.text(label),
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

    expect(find.text('مهام اليوم'), findsOneWidget);
    expect(find.text('لا مهام لهذا اليوم'), findsOneWidget);
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
    expect(find.text('أنجزت ${iso(0)} من ${iso(1)}'), findsOneWidget);

    // Tapping the row is the primary act — the whole card, not a small disc.
    await tester.tap(find.text('أذاكر الباب الأول'));
    await tester.pumpAndSettle();

    // One of one used to read in the same grey as zero of one; a finished
    // day closes with the sentence instead of repeating its count.
    expect(find.text(l.tasksDayDone(iso(1), iso(1))), findsOneWidget);
    expect(find.text('أنجزت ${iso(1)} من ${iso(1)}'), findsNothing);
    expect((await tasksOn(tester, now)).single.done, isTrue);

    // And it toggles back off, rather than being a one-way door: the line
    // returns to being a plain count while anything is left.
    await tester.tap(find.text('أذاكر الباب الأول'));
    await tester.pumpAndSettle();
    expect(find.text('أنجزت ${iso(0)} من ${iso(1)}'), findsOneWidget);
    expect((await tasksOn(tester, now)).single.done, isFalse);

    await closeApp(tester);
  });

  testWidgets('a fully ticked day closes with a sentence', (tester) async {
    phoneSized(tester);
    await openTasks(tester);

    await addTask(tester, 'الأولى');
    await addTask(tester, 'التانية');

    // Half done is still the plain count.
    await tester.tap(find.text('الأولى'));
    await tester.pumpAndSettle();
    expect(find.text('أنجزت ${iso(1)} من ${iso(2)}'), findsOneWidget);
    expect(find.text(l.tasksDayDone(iso(1), iso(2))), findsNothing);

    // The last tick swaps the line for the closing sentence — same place,
    // same style, nothing else on the screen moves.
    await tester.tap(find.text('التانية'));
    await tester.pumpAndSettle();
    expect(find.text(l.tasksDayDone(iso(2), iso(2))), findsOneWidget);
    expect(find.text('أنجزت ${iso(2)} من ${iso(2)}'), findsNothing);

    // The closure belongs to the picked day, not to today: yesterday's list
    // earns it on its own once every task there is ticked.
    await tester.tap(day(tester, 'ثلاثاء ${iso(4)}'));
    await tester.pumpAndSettle();
    expect(find.text(l.tasksDayDone(iso(2), iso(2))), findsNothing);

    await addTask(tester, 'مهمة امبارح');
    await tester.tap(find.text('مهمة امبارح'));
    await tester.pumpAndSettle();
    expect(find.text(l.tasksDayDone(iso(1), iso(1))), findsOneWidget);

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
    // The last row left this day, so what replaced the list is the SP-10
    // celebration rather than the plain empty state -- and pumpAndSettle
    // above has already carried it past exit and spring to a standstill.
    expect(find.text(l.tasksQueueClearedTitle), findsOneWidget);
    // PH-04: the heavy weight belongs to the deletion commit. The affirmative
    // confirm fired exactly once -- not for opening the edit sheet, and not
    // for the dialog merely appearing. (The queue-clearing success cue may
    // also be in the recording; only the heavy count is asserted here.)
    expect(
      haptics.where((cue) => cue == AppHapticCue.heavy),
      hasLength(1),
    );

    await closeApp(tester);
  });

  testWidgets('deleting the last row lands the cleared-queue celebration', (
    tester,
  ) async {
    phoneSized(tester);
    await openTasks(tester);
    await addTask(tester, 'آخر مهمة');

    await tester.tap(pencil());
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المهمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').hitTestable());

    // The whole sequence -- row fading out at AppMotion.exit, then
    // EmptyState.success springing in on Springs.celebrate -- runs on finite
    // animations only, so this returning is itself the assertion.
    await tester.pumpAndSettle();

    expect(find.text(l.tasksQueueClearedTitle), findsOneWidget);
    expect(find.byType(SpringPopIn), findsOneWidget);

    // Settled at exactly where the spring was aimed: the overshoot (~1.04)
    // happened in flight; nothing is left mid-bounce. The first Transform is
    // SpringPopIn's own scale (the disc inside carries its own micro pop).
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(SpringPopIn),
            matching: find.byType(Transform),
          )
          .first,
    );
    // Transform.scale stores its uniform factor in storage[0].
    expect(transform.transform.storage[0], closeTo(1.0, 0.01));

    await closeApp(tester);
  });

  testWidgets('under reduced motion the cleared state is settled instantly', (
    tester,
  ) async {
    phoneSized(tester);
    await openTasks(tester, reduced: true);
    await addTask(tester, 'آخر مهمة');

    // The sheet and confirm dialog are navigation chrome, not the motion
    // under test -- they get settles like any other test.
    await tester.tap(pencil());
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المهمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').hitTestable());
    // From here, one frame plus the tick that lets the database notification
    // land: under reduced motion nothing animates, so no settle is wanted.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // Visible now, on this frame -- not after a settle.
    expect(find.text(l.tasksQueueClearedTitle), findsOneWidget);

    // Reduced motion returned the final state outright: no scale, no fade
    // layer exists between SpringPopIn and its child.
    expect(
      find.descendant(
        of: find.byType(SpringPopIn),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );

    await closeApp(tester);
  });

  testWidgets('a long press and drag persists the new order', (tester) async {
    phoneSized(tester);
    await openTasks(tester);

    await addTask(tester, 'الأولى');
    await addTask(tester, 'التانية');

    expect(
      <String>[for (final t in await tasksOn(tester, now)) t.title],
      <String>['الأولى', 'التانية'],
    );

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

    // Tuesday the 4th, the cell directly before today's. Today's own cell says
    // "اليوم" rather than a date, which is what makes the trip back a tap on a
    // word the student can always find.
    await tester.tap(day(tester, 'ثلاثاء ${iso(4)}'));
    await tester.pumpAndSettle();

    expect(find.text('مهمة النهارده'), findsNothing);
    expect(find.text('لا مهام لهذا اليوم'), findsOneWidget);
    // The title stops claiming to be today the moment another day is picked.
    expect(find.text('مهام اليوم'), findsNothing);

    await addTask(tester, 'مهمة امبارح');
    expect(await tasksOn(tester, yesterday), hasLength(1));
    expect(await tasksOn(tester, now), hasLength(1));

    // Back to today, and nothing has leaked either way.
    await tester.tap(day(tester, 'اليوم'));
    await tester.pumpAndSettle();
    expect(find.text('مهمة النهارده'), findsOneWidget);
    expect(find.text('مهمة امبارح'), findsNothing);

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

  testWidgets('ticking a task draws the straight strike and says so', (
    tester,
  ) async {
    phoneSized(tester);
    await openTasks(tester);
    await addTask(tester, 'أذاكر الباب الأول');

    // Untouched: no mark at all. The pen exists for states, not decoration.
    expect(strike<StraightStrikePainter>(), findsNothing);
    expect(strike<ZigzagScribblePainter>(), findsNothing);

    await tester.tap(find.text('أذاكر الباب الأول'));
    await tester.pumpAndSettle();

    // Line through the words, tick in the disc -- one sentence in two marks.
    expect(strike<StraightStrikePainter>(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TaskRow),
        matching: find.byWidgetPredicate(
          (w) => w is AtherIcon && w.glyph == AtherGlyph.check,
        ),
      ),
      findsOneWidget,
    );
    expect(semantics(l.taskCompletedStrike), findsOneWidget);
    expect((await tasksOn(tester, now)).single.done, isTrue);

    await closeApp(tester);
  });

  testWidgets('surrendering is confirmed once, scribbled, and undoable', (
    tester,
  ) async {
    phoneSized(tester);
    await openTasks(tester);
    await addTask(tester, 'مهمة مستسلمة');

    await tester.tap(surrenderButton());
    await tester.pumpAndSettle();
    expect(find.text(l.surrenderConfirmTitle), findsOneWidget);

    // The affirmative answer IS the commit; the confirm seam owns its weight.
    await tester.tap(find.text(l.surrenderTask).hitTestable());
    await tester.pumpAndSettle();

    expect(strike<ZigzagScribblePainter>(), findsOneWidget);
    expect(strike<StraightStrikePainter>(), findsNothing);
    expect(semantics(l.taskMarkedSurrendered), findsOneWidget);
    expect(
      haptics.where((cue) => cue == AppHapticCue.heavy),
      hasLength(1),
      reason: 'exactly one heavy per committed surrender',
    );
    expect((await tasksOn(tester, now)).single.surrendered, isTrue);

    // Undo is a restoration, not a destruction: the same button, no dialog.
    await tester.tap(surrenderButton());
    await tester.pumpAndSettle();
    expect(find.text(l.surrenderConfirmTitle), findsNothing);

    expect(strike<ZigzagScribblePainter>(), findsNothing);
    expect((await tasksOn(tester, now)).single.surrendered, isFalse);
    expect(
      haptics.where((cue) => cue == AppHapticCue.heavy),
      hasLength(1),
      reason: 'undo adds no second heavy',
    );

    await closeApp(tester);
  });

  testWidgets('under reduced motion the marks are there on the first frame', (
    tester,
  ) async {
    phoneSized(tester);
    await openTasks(tester, reduced: true);
    await addTask(tester, 'مهمة');

    await tester.tap(find.text('مهمة'));
    // No settle: one frame plus the tick that lets the database notification
    // land. The marks do not animate into place under any setting, so under
    // reduced motion the final state must already be on screen here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(strike<StraightStrikePainter>(), findsOneWidget);
    expect(semantics(l.taskCompletedStrike), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('crossing midnight re-seeds the selection to today (N8)', (
    tester,
  ) async {
    phoneSized(tester);

    // A clock whose day changes while the screen stays alive: exactly what
    // happens to a keep-alive notifier across midnight or a resume that
    // lands on a new date.
    final DateTime first = now;
    final DateTime nextDay = now.add(const Duration(days: 1));
    final controller = StreamController<DateTime>.broadcast();
    addTearDown(controller.close);
    controller.add(first);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final app = ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(
          FakeBackupRepository.failing(),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(MutableClock(first)),
        nowProvider.overrideWith((ref) => controller.stream),
      ],
      child: const AtherApp(),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مهامك'));
    await tester.pumpAndSettle();

    // The student picks yesterday and leaves the screen on it.
    await tester.tap(day(tester, 'ثلاثاء ${iso(4)}'));
    await tester.pumpAndSettle();
    expect(find.text('مهام اليوم'), findsNothing);

    // The day turns. The sticky selection must follow -- otherwise a fresh
    // "+" quietly writes into a day the student is no longer looking at.
    controller.add(nextDay);
    await tester.pumpAndSettle();
    expect(find.text('مهام اليوم'), findsOneWidget);

    await addTask(tester, 'مهمة جديدة');
    expect(await tasksOn(tester, nextDay), hasLength(1));
    expect(await tasksOn(tester, first), isEmpty);

    await closeApp(tester);
  });
}
