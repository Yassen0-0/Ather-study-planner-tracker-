import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_spacing.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/core/widgets/ather_controls.dart';
import 'package:ather/core/widgets/settings_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The switch keeps its 50x30 look but answers a 48-point target, and the
/// settings row it lives in stays exactly as tall as its neighbours.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('the target is 48 tall around an unchanged 50x30 track', (
    tester,
  ) async {
    var value = false;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => AtherSwitch(
          value: value,
          onChanged: (next) => setState(() => value = next),
        ),
      ),
    );

    final target = tester.getRect(find.byType(AtherSwitch));
    expect(target.size, const Size(50, 48));
    final track = tester.getSize(
      find.descendant(
        of: find.byType(AtherSwitch),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(track, const Size(50, 30));

    // 4 points from the top: outside the drawn track, inside the target.
    await tester.tapAt(Offset(target.center.dx, target.top + 4));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('a toggle row keeps the height it had before', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 360,
        child: SettingsRow.toggle(
          label: 'مفتاح',
          toggle: true,
          onToggle: (_) {},
        ),
      ),
    );

    // The drawn track plus the row's usual padding either side -- what the
    // row measured when the switch was only 30 tall. The extra target height
    // comes out of the padding, not out of the page.
    expect(
      tester.getSize(find.byType(SettingsRow)).height,
      AtherSwitch.trackHeight + 2 * AppSpacing.xl,
    );
  });
}
