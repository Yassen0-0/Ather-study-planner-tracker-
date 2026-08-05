import 'package:flutter/widgets.dart';

/// Number and date formatting for a right-to-left interface.
///
/// This is the single most error-prone area of the app, so all of it lives in
/// one file with one rule: **a number is always Western digits, always laid out
/// left-to-right, and always isolated from the Arabic sentence around it.**
///
/// Without isolation the bidi algorithm reorders a run of digits and
/// punctuation against the surrounding RTL paragraph, and "1 من 4" renders as
/// "من 4 1". The fix is the Unicode isolate pair U+2066 (LRI) … U+2069 (PDI).

/// Left-to-right isolate opener. Written as an escape rather than the literal
/// character: pasted raw, it silently reorders this source file in an editor.
const String kLri = '\u2066';

/// Pop directional isolate.
const String kPdi = '\u2069';

/// Wraps a number so it keeps its own direction inside an Arabic sentence.
///
/// **Isolate the number alone, never a phrase containing Arabic words.**
/// ```dart
/// '${iso('1')} من ${iso('4')} باب اتقنتها'   // correct
/// '${iso('1 من 4')} باب اتقنتها'             // renders as "من 4 1"
/// ```
String iso(Object value) => '$kLri$value$kPdi';

/// Formats a mastery or score percentage.
///
/// Returns "—" rather than "0%" when there is no evidence: a lesson with no
/// exam has not scored zero, it has not been measured. Isolated so the `%` sits
/// after the digits in both languages.
String percentLabel(double value, {required bool hasData}) =>
    hasData ? iso('${value.round()}%') : '—';

/// A bare percentage, for values that always exist (a saved exam's result).
String percent(double value) => iso('${value.round()}%');

/// "12 / 16" — value, slash, target, in that order in both languages.
String fraction(Object value, Object total) => iso('$value / $total');

/// `yyyy/mm/dd`, Western digits, isolated.
String dateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return iso('${date.year}/$month/$day');
}

/// Forces its child to lay out left-to-right.
///
/// Used for progress bars, fractions and any row where the visual order of
/// numbers must not flip with the locale. Bars in particular must always fill
/// from the physical left, or a 20% bar in Arabic looks like an 80% one.
class Ltr extends StatelessWidget {
  const Ltr({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}
