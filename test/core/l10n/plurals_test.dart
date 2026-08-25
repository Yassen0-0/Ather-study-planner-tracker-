import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/core/l10n/generated/app_localizations.dart';

/// Pins the ICU plural branches the copy audit retyped from String to int
/// (docs/audit/phase2/arabic-copy-review.md F-01..F-05, G-1..G-4).
///
/// The screen tests assert whole rendered strings for the flows they boot,
/// but they only ever sample the counts those flows happen to produce. This
/// file samples every branch the grammar depends on — singular, dual, few
/// (3–10), many (11–99), other (100) and the =0 patches — directly against
/// the generated localisations, in both locales.
void main() {
  group('ar plurals', () {
    late L l;
    setUpAll(() async {
      l = await L.delegate.load(const Locale('ar'));
    });

    test('overdueByDays covers every Arabic number class', () {
      expect(l.overdueByDays(0), 'متأخّر أقل من يوم');
      expect(l.overdueByDays(1), 'متأخّر يوم واحد');
      expect(l.overdueByDays(2), 'متأخّر يومين');
      expect(l.overdueByDays(3), 'متأخّر 3 أيام');
      expect(l.overdueByDays(11), 'متأخّر 11 يوماً');
      expect(l.overdueByDays(100), 'متأخّر 100 يوم');
    });

    test('dueInDays says «أقل من يوم» at zero, never «بقي 0 يوم»', () {
      expect(l.dueInDays(0), 'أقل من يوم');
      expect(l.dueInDays(1), 'بقي يوم واحد');
      expect(l.dueInDays(2), 'بقي يومان');
      expect(l.dueInDaysLong(0), 'أقل من يوم على المراجعة');
    });

    test('comebackLine zero-count no longer states a positive fact', () {
      expect(
        l.comebackLine(8, 0),
        contains('ما حدش عبر معاده'),
      );
      expect(l.comebackLine(1, 1), contains('درس واحد عبر معاده'));
      expect(l.comebackLine(2, 2), contains('درسان عبرا معادهما'));
      expect(l.comebackLine(5, 3), contains('3 دروس'));
      expect(l.comebackLine(30, 15), contains('15 درساً'));
    });

    test('count nouns take dual/few/many/other correctly', () {
      expect(l.chaptersMasteredOf(3, 5), 'أتقنت 3 من 5 أبواب');
      expect(l.chaptersOfShort(1, 1), '1 من باب واحد');
      expect(l.lessonsOnTimeOf(2, 6), '2 من 6 دروس في موعده');
      expect(l.analyticsVelocity(3), '3 نقاط لكل دورة مراجعة');
      expect(l.analyticsVelocity(1), 'نقطة واحدة لكل دورة مراجعة');
      // dart intl computes CLDR operands on the signed value (Dart % keeps
      // its sign), so a negative velocity lands in `other` and takes the
      // singular. Accepted: the row's verdict colour and the chart beneath
      // carry the direction; the minus itself still renders.
      expect(l.analyticsVelocity(-3), '-3 نقطة لكل دورة مراجعة');
    });

    test('purge and restore lines reuse the healthy count bodies', () {
      expect(l.purgeCountsLine(1, 2, 3, 11), 'مادة واحدة · بابان · 3 دروس · 11 امتحاناً');
      expect(l.restoreCopyCounts(4, 1), 'النسخة السحابية: 4 أبواب، امتحان واحد');
    });

    test('exam groups agree while recording', () {
      expect(l.examGroupLabel(1, 2), 'سؤال واحد × درجتان');
      expect(l.examGroupLabel(10, 1), '10 أسئلة × درجة واحدة');
      expect(l.examGroupLabel(25, 3), '25 سؤالاً × 3 درجات');
    });
  });

  group('en plurals', () {
    late L l;
    setUpAll(() async {
      l = await L.delegate.load(const Locale('en'));
    });

    test('count == 1 is singular, not "1 days"', () {
      expect(l.dueInDays(1), '1 day left');
      expect(l.dueInDays(3), '3 days left');
      expect(l.dueInDaysLong(1), '1 day until review');
      expect(l.overdueByDays(1), '1 day overdue');
      expect(l.comebackLine(1, 1),
          'Back after 1 day — 1 lesson came due meanwhile.');
      expect(l.analyticsVelocity(1), '1 point per review cycle');
      expect(l.chaptersMasteredOf(2, 1), '2 of 1 chapter mastered');
      expect(l.purgeCountsLine(1, 1, 1, 1),
          '1 subject · 1 chapter · 1 lesson · 1 exam');
      expect(l.restoreCopyCounts(1, 0), 'Cloud copy: 1 chapter, 0 exams');
      expect(l.examGroupLabel(1, 2), '1 question × 2 marks');
    });
  });
}
