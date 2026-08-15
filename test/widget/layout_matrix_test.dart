import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/core/l10n/generated/app_localizations.dart';

import '../widget_test.dart';

/// Every screen, at every width the design claims to support, in both scripts
/// and both themes.
///
/// ## Why this file exists
///
/// The spacing ladder was rebuilt: the four rungs that sat off the 4-grid (10,
/// 14, 18, 22) were removed and their call sites moved to the nearest surviving
/// rung. That is a two-pixel change repeated a hundred and twenty times, and
/// two pixels a hundred and twenty times is not a two-pixel change — it is
/// every row, gap and card padding in the app moving at once. The failure mode
/// is not ugliness, which a person would notice; it is a `RenderFlex overflowed`
/// on the one width nobody opened.
///
/// So the check is mechanical and it is a matrix. `takeException` is the whole
/// assertion: a Flutter overflow is a thrown error in a test binding, and this
/// walks the app until one is thrown or the tree is exhausted.
///
/// **320 is deliberate.** The suite already covered 360, which is the narrowest
/// phone most people have held. 320 is an iPhone SE 1 and the low end of the
/// Android devices this app's students actually own, and it is where the
/// dashboard's three-up stat row — a label, a count, a denominator and a bar in
/// a third of the content width — runs out of room first.
void main() {
  /// Widths the design has an opinion about: the narrowest phone, a normal
  /// phone, the 600 breakpoint itself, and a window past it where content is
  /// capped at 520 and centred.
  const List<(String, Size)> viewports = <(String, Size)>[
    ('320 (small phone)', Size(320, 568)),
    ('360 (common phone)', Size(360, 640)),
    ('600 (breakpoint)', Size(600, 900)),
    ('840 (tablet)', Size(840, 1120)),
  ];

  for (final (name, size) in viewports) {
    testWidgets('the whole app lays out at $name', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await bootApp(snapshot: overdueSnapshot()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'dashboard at $name');

      // Every tab, because the tab bar is the one piece of chrome that does not
      // scroll and the analytics screen is the widest thing in the app.
      //
      // The tasks tab is excluded below 400 and the exclusion is a **known
      // defect, not a tolerance** — see `the tasks week strip does not fit a
      // narrow phone` below for the measurement and the reason it is not fixed
      // here.
      final L l = L.of(tester.element(find.byType(Scaffold).first));
      final tabs = <String>[
        l.navReview,
        l.navProgress,
        if (size.width >= 400) l.navTasks,
      ];
      for (final tab in tabs) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab at $name');
      }

      // Settings carries the two segmented controls and the longest sublabels,
      // and it is reached from the home tab's header.
      await tester.tap(find.text(l.navHome));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l.settingsTitle).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'settings at $name');
    });
  }

  /// A standing note, in the form of arithmetic, about a defect this file found
  /// and deliberately did **not** fix.
  ///
  /// The week strip is a summary on the dashboard and a *picker* on the tasks
  /// screen. As a picker each of its seven day cells is a [Pressable] carrying
  /// `minTarget: kMinTarget` — the 48 floor the whole app honours — so the row
  /// demands 7 x 48 = 336 no matter how narrow the window is. The header gives
  /// it the page margin on each side, so it fits only from 336 + 32 = 368 up:
  /// a 360 phone, which is the commonest Android width there is, clips it by 8,
  /// and a 320 phone by 48. The dashboard's copy escapes because an inert cell
  /// gets no [Pressable] at all and therefore no floor.
  ///
  /// This is not a spacing-system fault and it predates the ladder rebuild
  /// (which improved it by 4, via the header margin). Fixing it means choosing
  /// between two things the app has already committed to: distribute the cells
  /// with `Expanded` and let the target fall to 41 on a 320 screen, or let the
  /// strip scroll and give up "the whole week at a glance". Seven 48 targets
  /// cannot be laid in 288 — no arrangement of them exists — so that choice is
  /// the product's, not a refactor's.
  test('the tasks week strip does not fit a narrow phone', () {
    const double cells = 7 * 48; // kMinTarget, per day
    const double narrowestContent = 320 - 2 * 16; // page margin either side
    expect(
      cells,
      greaterThan(narrowestContent),
      reason:
          'If this ever stops being true the defect above has been fixed and '
          'the tasks tab should go back into the width matrix unconditionally.',
    );
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    for (final locale in <Locale>[Locale('ar'), Locale('en')]) {
      testWidgets('lays out in ${locale.languageCode} / ${mode.name}', (
        tester,
      ) async {
        // The narrow end, where a longer English string is most likely to
        // overrun a row sized against the Arabic it was designed for.
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              platformBrightness: mode == ThemeMode.dark
                  ? Brightness.dark
                  : Brightness.light,
            ),
            child: await bootApp(snapshot: overdueSnapshot(), locale: locale),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // The direction actually took effect -- otherwise an English run is an
        // Arabic run with a different assertion label.
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
      });
    }
  }
}
