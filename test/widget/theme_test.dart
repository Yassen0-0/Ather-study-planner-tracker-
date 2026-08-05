import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/theme/app_colors.dart';
import 'package:ather/core/widgets/ather_scaffold.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/presentation/common/settings_button.dart';
import 'package:ather/presentation/dashboard/dashboard_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';

/// The theme switch, end to end.
///
/// Three things are worth a test rather than an eyeball, because all three
/// failed silently in an earlier attempt at this feature:
///
/// 1. A theme change reaches a screen that is **already on the Navigator**.
///    This is the one that caught the original design out: reading colours from
///    static constants compiled and looked right on a fresh launch, but a screen
///    already built was never rebuilt by a `MaterialApp` theme change, so it
///    kept painting the old palette until something else happened to rebuild it.
/// 2. The choice survives a relaunch.
/// 3. "Follow system" actually follows the platform, rather than pinning light.
void main() {
  final DateTime now = DateTime(2026, 8, 3);

  Future<Widget> boot([
    Map<String, Object> prefs = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        snapshotProvider.overrideWith(
          (ref) => Stream<StudySnapshot>.value(const StudySnapshot.empty()),
        ),
        clockProvider.overrideWithValue(MutableClock(now)),
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(now)),
      ],
      child: const AtherApp(),
    );
  }

  /// The palette the dashboard is actually painting with — read from a widget
  /// deep in the tree, not from the app's theme, so a stale subtree fails.
  AppColors paletteOnScreen(WidgetTester tester) {
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    return AppColors.of(context);
  }

  /// The cog in the dashboard header. Scoped to that screen because every root
  /// screen carries one now that the "المزيد" tab is gone.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SettingsButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('switching to dark repaints without a relaunch', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();

    expect(paletteOnScreen(tester), AppColors.light);

    await openSettings(tester);
    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();

    expect(paletteOnScreen(tester), AppColors.dark);

    // Settings is pushed *over* the shell, so popping it reveals the dashboard
    // that was built under the light theme and has been sitting on the
    // Navigator ever since. It must have repainted too -- this is the
    // assertion the static-constant design failed.
    await tester.tap(find.byType(BackChevron));
    await tester.pumpAndSettle();
    expect(paletteOnScreen(tester), AppColors.dark);

    await openSettings(tester);
    await tester.tap(find.text('فاتح'));
    await tester.pumpAndSettle();
    expect(paletteOnScreen(tester), AppColors.light);
  });

  testWidgets('the choice is written to disk and read back on launch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    // Stored by name, not index -- reordering ThemeMode must not reinterpret
    // anyone's saved choice.
    expect(preferences.getString('theme_mode'), 'dark');

    // A fresh launch reading the same store opens dark on the first frame,
    // rather than flashing light and correcting itself.
    await tester.pumpWidget(await boot(<String, Object>{'theme_mode': 'dark'}));
    await tester.pump();
    expect(paletteOnScreen(tester), AppColors.dark);
  });

  testWidgets('the default follows the platform', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    // Nothing saved: the student has never opened the setting.
    await tester.pumpWidget(await boot());
    await tester.pumpAndSettle();
    expect(paletteOnScreen(tester), AppColors.dark);

    // The OS flipping to light moves the app with it, still with no preference.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(paletteOnScreen(tester), AppColors.light);

    // But an explicit choice outranks the OS.
    await openSettings(tester);
    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();
    expect(paletteOnScreen(tester), AppColors.dark);
  });
}
