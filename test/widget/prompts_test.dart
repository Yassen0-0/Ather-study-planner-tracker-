import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/widgets/buttons.dart';
import 'package:ather/core/widgets/error_banner.dart';
import 'package:ather/presentation/common/prompts.dart';

/// N17 -- a name made only of invisible characters must fail the blank check.
///
/// ZWSP, RLM and the tatweel are real code points with no ink; `trim()` saw
/// them as content, so a "name" of them was saved and later rendered as an
/// apparently-blank lesson header. The prompt's error path is the same one a
/// genuinely empty name takes (`nameRequired`), because from the student's
/// side there is nothing to tell apart.
void main() {
  Future<Completer<String?>> open(WidgetTester tester) async {
    final result = Completer<String?>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        locale: const Locale('ar'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showNamePrompt(context, title: 'عنوان', hint: 'اسم').then(
                    result.complete,
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> typeAndSave(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    // The save button stays tappable while invalid -- no greyed-out control,
    // no tap swallowed without the student learning why -- so the sheet, not
    // the button's tone, owns the refusal.
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
  }

  testWidgets('a zero-width space is not a name', (tester) async {
    final result = await open(tester);

    await typeAndSave(tester, '\u200B');

    expect(find.byType(ErrorBanner), findsOneWidget);
    final l = await L.delegate.load(const Locale('ar'));
    expect(find.text(l.nameRequired), findsOneWidget);
    expect(result.isCompleted, isFalse);
  });

  testWidgets('an RTL mark alone is not a name', (tester) async {
    final result = await open(tester);

    await typeAndSave(tester, '\u200F');

    expect(find.byType(ErrorBanner), findsOneWidget);
    expect(result.isCompleted, isFalse);
  });

  testWidgets('a bare tatweel is not a name', (tester) async {
    final result = await open(tester);

    await typeAndSave(tester, '\u0640');

    expect(find.byType(ErrorBanner), findsOneWidget);
    expect(result.isCompleted, isFalse);
  });

  testWidgets('invisibles wrapped around whitespace are still not a name', (
    tester,
  ) async {
    final result = await open(tester);

    await typeAndSave(tester, '\u200B \u200F \u0640 ');

    expect(find.byType(ErrorBanner), findsOneWidget);
    expect(result.isCompleted, isFalse);
  });

  testWidgets('a real Arabic name still saves', (tester) async {
    final result = await open(tester);

    await typeAndSave(tester, 'الفصل الأول');

    expect(await result.future, 'الفصل الأول');
  });

  testWidgets('invisibles around a real name do not block the save', (
    tester,
  ) async {
    final result = await open(tester);

    await typeAndSave(tester, '\u200Bالدرس\u200F');

    // Saved exactly as typed: the gate decides validity only.
    expect(await result.future, '\u200Bالدرس\u200F');
  });
}
