// Lives outside `test/` so `flutter test` skips it, like the render tool.
// ignore_for_file: invalid_use_of_visible_for_testing_member
@Tags(<String>['render'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';

import '../../test/support/fake_backup.dart';
import '../../test/support/fake_auth.dart';
import 'ather_render_test.dart' show loadFont, seeded, kNow;

/// Captures a screen *mid-animation* rather than settled.
///
/// The rest of the render tool calls `pumpAndSettle` before every shot, which
/// by construction can only ever photograph the finished state -- so it proves
/// the layout is right and says nothing about whether anything moved. This
/// exists to answer exactly one question: does the motion actually run in the
/// real app, or only in the unit tests?
///
/// Frames land in `tool/render/motion/`.
Future<Widget> boot() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      backupRepositoryProvider.overrideWithValue(FakeBackupRepository.failing()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      snapshotProvider
          .overrideWith((ref) => Stream<StudySnapshot>.value(seeded())),
      clockProvider.overrideWithValue(MutableClock(kNow)),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
    ],
    child: const AtherApp(),
  );
}

void main() {
  setUpAll(loadFont);

  testWidgets('dashboard entrance, frame by frame', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await boot());

    // Deliberately NOT pumpAndSettle. Each step advances the clock by 60ms and
    // photographs whatever is on screen at that instant.
    const step = Duration(milliseconds: 60);
    for (var i = 0; i < 8; i++) {
      await tester.pump(i == 0 ? Duration.zero : step);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('motion/entrance-${(i * 60).toString().padLeft(3, '0')}ms.png'),
      );
    }

    await tester.pumpAndSettle();
  });

  testWidgets('the same entrance with animations disabled', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // What a device with "Transition animation scale: off" (Developer options)
    // or "Remove animations" (Accessibility) reports to the app. Every frame
    // below should be identical to the settled state -- which is the motion
    // system behaving correctly, not the build being wrong.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: await boot(),
      ),
    );

    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('motion/reduced-000ms.png'),
    );

    await tester.pump(const Duration(milliseconds: 120));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('motion/reduced-120ms.png'),
    );

    await tester.pumpAndSettle();
  });
}
