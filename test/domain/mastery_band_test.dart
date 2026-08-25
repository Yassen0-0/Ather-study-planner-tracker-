import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/core/theme/app_colors.dart';
import 'package:ather/core/theme/mastery_palette.dart';
import 'package:ather/domain/entities/mastery.dart';

/// Pins the band policy to its one source of truth (M2).
///
/// Before this file existed, the wizard's verdict switches and the palette's
/// colour branches re-implemented `<50 / <70 / >=90` as bare literals while
/// `mastery.dart` claimed to be the single source -- a claim nothing tested.
void main() {
  group('the band edges are the declared constants', () {
    test('the constants hold the product values', () {
      // If these ever move, every verdict and colour in the app moves with
      // them -- this pin makes that a conscious act.
      expect(kWeakBandUpperEdge, 50);
      expect(kGoodBandLowerEdge, 70);
      expect(kExcellentBandLowerEdge, 90);
    });

    test('bands classify inclusively-lower at every edge', () {
      final cases = <double, MasteryBand>{
        0: MasteryBand.weak,
        49.999: MasteryBand.weak,
        50: MasteryBand.medium,
        69.999: MasteryBand.medium,
        70: MasteryBand.good,
        89.999: MasteryBand.good,
        90: MasteryBand.excellent,
        100: MasteryBand.excellent,
      };
      cases.forEach((percentage, band) {
        expect(
          MasteryBand.fromPercentage(percentage),
          band,
          reason: '$percentage must sit in ${band.name}',
        );
      });
    });

    test('belowGood is true exactly below the good band', () {
      expect(MasteryBand.weak.belowGood, isTrue);
      expect(MasteryBand.medium.belowGood, isTrue);
      expect(MasteryBand.good.belowGood, isFalse);
      expect(MasteryBand.excellent.belowGood, isFalse);
    });
  });

  group('the palette colours by the band', () {
    // Sampled densely around the edges so a literal re-implemented on either
    // side of a boundary shows up as a disagreement.
    const percentages = <double>[
      -1, 0, 25, 49.9, 49.999, 50, 50.001, 65, 69.999, 70, 70.001, //
      80, 89.999, 90, 90.001, 100, 101,
    ];

    for (final colors in <String, AppColors>{
      'light': AppColors.light,
      'dark': AppColors.dark,
    }.entries) {
      test('${colors.key} theme agrees with the band mapping', () {
        for (final percentage in percentages) {
          final resolved = MasteryPalette.resolve(
            colors: colors.value,
            percentage: percentage,
            hasData: true,
          );
          final band = MasteryBand.fromPercentage(percentage);
          final expected = switch (band) {
            MasteryBand.weak => colors.value.wrong,
            MasteryBand.excellent => colors.value.rightText,
            _ => colors.value.textPrimary,
          };
          expect(resolved, expected, reason: 'at $percentage%');
        }
      });
    }

    test('no-data and review outrank the score, as documented', () {
      expect(
        MasteryPalette.resolve(
          colors: AppColors.light,
          percentage: 100,
          hasData: false,
        ),
        AppColors.light.textNoData,
      );
      // An overdue lesson is red however high it once scored.
      expect(
        MasteryPalette.resolve(
          colors: AppColors.light,
          percentage: 95,
          hasData: true,
          needsReview: true,
        ),
        AppColors.light.wrong,
      );
    });
  });
}
