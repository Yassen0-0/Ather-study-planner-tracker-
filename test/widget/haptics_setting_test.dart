import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/haptics/app_haptics.dart';
import 'package:ather/domain/entities/daily_task.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/task_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

/// The haptics switch, end to end.
///
/// The unit tests in `test/core/haptics/` prove the vocabulary and the gate;
/// this one proves the student-visible half of the contract: the row exists
/// under its Arabic label, tapping it persists the choice, and the static gate
/// that every Pressable and tab reads closes without a relaunch.
void main() {
  final DateTime now = DateTime(2026, 8, 23);
  final List<AppHapticCue> sent = <AppHapticCue>[];

  setUp(() {
    sent.clear();
    AppHaptics.send = sent.add;
    AppHaptics.configure!(true);
  });

  Future<(Widget, SharedPreferences)> boot([
    Map<String, Object> initial = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final preferences = await SharedPreferences.getInstance();

    final widget = ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        backupRepositoryProvider.overrideWithValue(
          FakeBackupRepository.failing(),
        ),
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
    return (widget, preferences);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the row shows, flips off, and silences haptics live', (
    tester,
  ) async {
    await tester.pumpWidget((await boot()).$1);
    await tester.pumpAndSettle();
    await openSettings(tester);

    expect(find.text('الاهتزاز'), findsOneWidget);

    await tester.tap(find.text('الاهتزاز'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('الاهتزاز'));
    expect(ProviderScope.containerOf(context).read(hapticsEnabledProvider),
        isFalse);

    // The press-down itself legitimately buzzed while the gate was still
    // open; what this proves is that nothing fires AFTER the flip.
    sent.clear();
    AppHaptics.light();
    expect(sent, isEmpty);
  });

  testWidgets('tapping it again turns haptics back on', (tester) async {
    final (widget, preferences) = await boot(<String, Object>{
      kHapticsEnabledKey: false,
    });
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await openSettings(tester);

    // Opening Settings built the row, which watches the provider; its build
    // pushed the stored "off" through configure. The navigation press-down
    // itself buzzed while the gate was still open — discarded so what's
    // asserted below is purely the closed-gate behavior.
    sent.clear();
    AppHaptics.select();
    expect(sent, isEmpty);

    await tester.tap(find.text('الاهتزاز'));
    await tester.pumpAndSettle();

    expect(preferences.getBool(kHapticsEnabledKey), isTrue);
    sent.clear();
    AppHaptics.select();
    expect(sent, <AppHapticCue>[AppHapticCue.select]);
  });
}
