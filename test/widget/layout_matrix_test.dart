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
      // The tasks tab used to be excluded below 400, as a known defect rather
      // than a tolerance: its week strip laid seven cells at the 48px target
      // floor and so demanded 336px on a screen that can be 288 wide. The
      // `DayPicker` that replaced it measures its labels and drops a pair of
      // days rather than overflow, so there is no width left to exclude.
      final L l = L.of(tester.element(find.byType(Scaffold).first));
      final tabs = <String>[l.navReview, l.navProgress, l.navTasks];
      for (final tab in tabs) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab at $name');
      }

      // Settings carries the longest labels in the app, and it is reached from
      // the home tab's header.
      await tester.tap(find.text(l.navHome));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l.settingsTitle).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'settings at $name');

      // And the screens it opens onto. A settings row is one line by
      // construction, so the page that used to hold everything cannot overflow
      // -- but the detail screens it pushed the content down to now can, and
      // they are exactly where nobody would think to look.
      for (final screen in <String>[
        l.subjectsTitle,
        l.settingsPrivacy,
        l.settingsAbout,
      ]) {
        await tester.scrollUntilVisible(
          find.text(screen),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text(screen).hitTestable().first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$screen at $name');

        await tester.tap(find.bySemanticsLabel(l.commonBack).first);
        await tester.pumpAndSettle();
      }
    });
  }

  // The arithmetic that used to sit here recorded the defect this file found
  // and deliberately did not fix: seven day cells at the app's 48px target
  // floor demand 336, the narrowest screen offers 288 between the page margins,
  // and no arrangement of seven 48s fits in 288. The fix was not a refactor and
  // could not be — it was the product decision to stop showing seven days. See
  // `day_picker_test.dart`, which asserts the replacement's side of it: three
  // cells at 320, more when there is room, and never a scaled-down label.

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
