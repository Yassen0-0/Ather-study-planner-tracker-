import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The privacy screen is a promise. It said "no crash reporting" while
/// release builds sent Crashlytics reports; it now names the one thing that
/// leaves unasked, in both languages, and what that thing never contains --
/// the same account the published policy (public/privacy.html) gives.
void main() {
  for (final locale in const <Locale>[Locale('ar'), Locale('en')]) {
    test('${locale.languageCode}: the no-collect copy discloses crash reports',
        () {
      final body = lookupL(locale).privacyNoCollectBody;
      expect(body, contains('Firebase Crashlytics'));
      expect(body, isNot(contains('crash reporting.')));
      expect(body, isNot(contains('ولا تقارير أخطاء')));
    });
  }
}
