import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/core/widgets/ather_controls.dart';

/// The number field's contract with real keyboards.
///
/// A filter that only allowed `[0-9]` silently swallowed every keystroke on
/// devices whose keyboard produces Arabic-Indic digits -- the exam wizard went
/// read-only with no message explaining why. These pin the replacement
/// behaviour: digits are *translated*, never dropped, whatever way they arrive.
void main() {
  Future<void> pump(WidgetTester tester, TextEditingController controller) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(child: NumberField(controller: controller)),
        ),
      ),
    );
  }

  testWidgets('typing Arabic-Indic digits lands as ASCII digits', (
    tester,
  ) async {
    final controller = TextEditingController();
    await pump(tester, controller);
    await tester.enterText(find.byType(TextField), '١٠');

    expect(controller.text, '10');
  });

  testWidgets('pasting a mixed string keeps every digit', (tester) async {
    // Three digits in three scripts, inside the field's four-character
    // budget: every one of them lands, none filtered. The five-character case
    // lives in the length-limit test below, which owns the truncation.
    final controller = TextEditingController();
    await pump(tester, controller);
    await tester.enterText(find.byType(TextField), '١2٣');

    expect(controller.text, '123');
  });

  testWidgets('the extended Persian set is translated too', (tester) async {
    final controller = TextEditingController();
    await pump(tester, controller);
    await tester.enterText(find.byType(TextField), '۷۵');

    expect(controller.text, '75');
  });

  testWidgets('a minus sign and a decimal point are still refused', (
    tester,
  ) async {
    final controller = TextEditingController();
    await pump(tester, controller);
    await tester.enterText(find.byType(TextField), '-5.5');

    expect(controller.text, '55');
  });

  testWidgets('the length limit counts the digits the student sees', (
    tester,
  ) async {
    // NumberField defaults to four characters. Five Arabic-Indic digits must
    // not become five ASCII ones after translation.
    final controller = TextEditingController();
    await pump(tester, controller);
    await tester.enterText(find.byType(TextField), '١٢٣٤٥');

    expect(controller.text, '1234');
  });
}
