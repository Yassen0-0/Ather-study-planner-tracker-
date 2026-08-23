import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ather/core/branding/ather_brand.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/presentation/auth/login_screen.dart';
import 'package:ather/presentation/auth/lock_screen.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';

import '../support/fake_auth.dart';
import '../support/fake_local_auth.dart';

/// The brand mark's draw-on opening beat (§SP-09 · IA-06).
///
/// The beat belongs to the *appearance* of the lock and login screens: the
/// ring draws on over 350ms, then the 27% accent run sweeps over the next
/// 250ms, then everything stops. These tests pin the sequencing on the shared
/// controller, the stillness afterwards, the reduce-motion shortcut, and the
/// fact that both gate screens actually carry the animated mark.
void main() {
  /// Same shape as motion_test's harness: the reduced-motion flag is injected
  /// above the MaterialApp so `prefersReducedMotion` sees it.
  Widget harness(Widget child, {bool reduced = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      ),
    );
  }

  AtherMarkPainter mark(WidgetTester tester) => tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(AtherMarkDrawOn),
          matching: find.byType(CustomPaint),
        ),
      )
      .painter! as AtherMarkPainter;

  group('AtherMarkPainter', () {
    test('defaults sit at full progress, keeping old callers at rest', () {
      // The share card and the branding export construct the painter with a
      // palette and nothing else; their output must be the pre-SP-09 drawing.
      const painter = AtherMarkPainter(palette: AtherBrandPalette.glyph);
      expect(painter.ringProgress, 1.0);
      expect(painter.accentProgress, 1.0);
    });

    test('repaints only when a progress actually moves', () {
      const painter = AtherMarkPainter(palette: AtherBrandPalette.glyph);
      const same = AtherMarkPainter(palette: AtherBrandPalette.glyph);
      expect(painter.shouldRepaint(same), isFalse);

      expect(
        painter.shouldRepaint(
          const AtherMarkPainter(
            palette: AtherBrandPalette.glyph,
            ringProgress: 0.5,
          ),
        ),
        isTrue,
        reason: 'the ring phase must repaint while it draws on',
      );
      expect(
        painter.shouldRepaint(
          const AtherMarkPainter(
            palette: AtherBrandPalette.glyph,
            accentProgress: 0.5,
          ),
        ),
        isTrue,
        reason: 'the accent phase must repaint while it sweeps',
      );
    });
  });

  group('AtherMarkDrawOn', () {
    testWidgets('the ring finishes before the accent begins', (tester) async {
      await tester.pumpWidget(
        harness(const AtherMarkDrawOn(label: 'أثر', size: 108)),
      );
      await tester.pump();

      // Mid-ring -- some of the ring, none of the accent. The accent must not
      // race the ring: SP-09 sequences them, one controller, two intervals.
      await tester.pump(const Duration(milliseconds: 175));
      expect(mark(tester).ringProgress, greaterThan(0));
      expect(mark(tester).ringProgress, lessThan(1));
      expect(mark(tester).accentProgress, 0.0);

      // Past the 350ms handover: the ring is done and pinned there while the
      // accent is somewhere inside its own sweep.
      await tester.pump(const Duration(milliseconds: 275));
      expect(mark(tester).ringProgress, 1.0);
      expect(mark(tester).accentProgress, greaterThan(0));
      expect(mark(tester).accentProgress, lessThan(1));

      await tester.pumpAndSettle();
      expect(mark(tester).ringProgress, 1.0);
      expect(mark(tester).accentProgress, 1.0);
    });

    testWidgets('after the beat the screen is perfectly still', (tester) async {
      await tester.pumpWidget(
        harness(const AtherMarkDrawOn(label: 'أثر', size: 44)),
      );

      // If any ticker survived past completion this would time out rather
      // than return -- that is the whole assertion.
      await tester.pumpAndSettle();

      final painter = mark(tester);
      expect(painter.ringProgress, 1.0);
      expect(painter.accentProgress, 1.0);

      // And a second later nothing has moved: the controller completed, it
      // did not loop or hold.
      await tester.pump(const Duration(seconds: 1));
      expect(mark(tester).ringProgress, 1.0);
      expect(mark(tester).accentProgress, 1.0);
    });

    testWidgets(
      'reduce-motion shows the finished mark on the first frame and never '
      'starts the controller',
      (tester) async {
        await tester.pumpWidget(
          harness(const AtherMarkDrawOn(label: 'أثر', size: 108), reduced: true),
        );
        await tester.pump();

        // Complete immediately -- not "complete once a skipped animation
        // would have finished".
        expect(mark(tester).ringProgress, 1.0);
        expect(mark(tester).accentProgress, 1.0);

        // Returns instantly: no ticker was ever started to settle.
        await tester.pumpAndSettle();
        expect(mark(tester).ringProgress, 1.0);
        expect(mark(tester).accentProgress, 1.0);
      },
    );

    testWidgets('every appearance replays the beat', (tester) async {
      Widget screen() =>
          harness(const AtherMarkDrawOn(label: 'أثر', size: 44));

      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(mark(tester).ringProgress, 1.0);

      // The gate unmounts its screen and mounts a fresh one each appearance;
      // a fresh State means a fresh controller starting from zero, not a
      // remembered "already played".
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pumpWidget(screen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mark(tester).ringProgress,
        lessThan(1.0),
        reason: 'the second appearance must draw on again',
      );

      await tester.pumpAndSettle();
      expect(mark(tester).ringProgress, 1.0);
    });
  });

  group('the gate screens carry the mark', () {
    Widget loginHarness() {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const LoginScreen(),
        ),
      );
    }

    Widget lockHarness(FakeLocalAuth localAuth, SharedPreferences preferences) {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository.signedIn(),
          ),
          localAuthProvider.overrideWithValue(localAuth),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const LockScreen(),
        ),
      );
    }

    testWidgets('the login screen opens with the draw-on mark', (
      tester,
    ) async {
      await tester.pumpWidget(loginHarness());
      await tester.pump();

      expect(find.byType(AtherMarkDrawOn), findsOneWidget);

      // The screen settles -- the beat ends, it does not run forever behind
      // whatever the student types next.
      await tester.pumpAndSettle();
      expect(find.byType(AtherMarkDrawOn), findsOneWidget);
    });

    testWidgets('the lock screen opens with the draw-on mark and still locks', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      // The prompt refuses, as a cancelled fingerprint does; the screen stays.
      final localAuth = FakeLocalAuth(result: false);

      await tester.pumpWidget(lockHarness(localAuth, preferences));
      await tester.pump();

      expect(find.byType(AtherMarkDrawOn), findsOneWidget);
      await tester.pumpAndSettle();

      // The beat replaced none of the lock's behaviour: refused prompt, lock
      // still up, unlock button still offered.
      expect(find.text('افتح'), findsOneWidget);
      expect(find.byType(AtherMarkDrawOn), findsOneWidget);
    });
  });
}
