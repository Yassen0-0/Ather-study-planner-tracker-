// Outside `test/` for the same reason as ather_render_test.dart: these are
// visual references, not assertions.
// ignore_for_file: invalid_use_of_visible_for_testing_member
@Tags(<String>['render'])
library;

import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/tasks/tasks_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_backup.dart';
import '../../test/support/fake_auth.dart';
import 'ather_render_test.dart' show kNow, loadFont, seeded, seededTasks;

/// The same screens as `ather_render_test.dart`, in the dark theme.
///
/// Regenerate with:
///
/// ```
/// flutter test tool/render/ather_dark_render_test.dart --update-goldens
/// ```
///
/// The theme is not forced through an override: the app is booted with
/// `theme_mode: dark` already in SharedPreferences, exactly as it would be for
/// a student who picked Dark and relaunched. So this doubles as proof that the
/// preference survives a cold start and is applied on the first frame.
Future<Widget> bootDark() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'theme_mode': ThemeMode.dark.name,
  });
  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      backupRepositoryProvider.overrideWithValue(FakeBackupRepository.failing()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      snapshotProvider.overrideWith(
        (ref) => Stream<StudySnapshot>.value(seeded()),
      ),
      tasksProvider.overrideWith(
        (ref) => Stream<List<DailyTask>>.value(seededTasks()),
      ),
      clockProvider.overrideWithValue(MutableClock(kNow)),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
    ],
    child: const AtherApp(),
  );
}

void main() {
  setUpAll(loadFont);

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('render-dark/$name.png'),
    );
  }

  testWidgets('renders every screen in the dark theme', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await bootDark());
    await shot(tester, '01-dashboard');

    await tester.tap(find.text('أحياء'));
    await shot(tester, '02-subject');

    await tester.tap(find.text('الباب الثاني — الوراثة'));
    await shot(tester, '03-chapter');

    await tester.tap(find.text('قوانين مندل'));
    await shot(tester, '04-lesson');

    await tester.tap(find.text('سجّل نتيجة امتحان'));
    await shot(tester, '05-exam-step1');

    await tester.enterText(find.byType(TextField).first, '8');
    await tester.tap(find.text('التالي'));
    await shot(tester, '06-exam-step2');

    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
    // Back on step 1, "رجوع" leaves the wizard -- and now that there is typed
    // input to lose, leaving asks first. Answering it is part of the script.
    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اترك'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مراجعة'));
    await shot(tester, '07-review');

    await tester.tap(find.text('تقدمك'));
    await shot(tester, '08-progress');

    await tester.tap(find.text('مهامك'));
    await shot(tester, '09-tasks');

    await tester.tap(
      find.descendant(
        of: find.byType(TasksScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await shot(tester, '10-settings');
  });
}
