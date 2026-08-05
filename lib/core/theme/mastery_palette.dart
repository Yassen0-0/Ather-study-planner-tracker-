import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The one rule that decides what colour a mastery number is.
///
/// Evaluated strictly in this order:
///
/// 1. **No exam yet -> `#C6C6CB`**, and the value renders as "—", not "0%".
///    Unproven and weak are different states. A student who just installed the
///    app is not failing four subjects.
/// 2. **Overdue -> red.** Decay outranks score: the app's claim is about
///    *current* understanding, so an expired lesson is red however well it was
///    once learned. Overdue is always accompanied by an icon as well, never
///    signalled by colour alone.
/// 3. **Below 50 -> red.**
/// 4. **90 or above -> green.**
/// 5. Otherwise **black**.
///
/// There is no "medium" or "good" colour. A score in the middle is simply a
/// number; inventing a colour for it would dilute the two that mean something.
/// The rule takes a palette rather than reading constants, so the same five
/// branches serve both themes. Red and green are identical in each -- only the
/// "no data" grey and the neutral text colour move.
abstract final class MasteryPalette {
  static Color resolve({
    required AppColors colors,
    required double percentage,
    required bool hasData,
    bool needsReview = false,
  }) {
    if (!hasData) return colors.textNoData;
    if (needsReview) return colors.wrong;
    if (percentage < 50) return colors.wrong;
    if (percentage >= 90) return colors.right;
    return colors.textPrimary;
  }

  /// Colour for a single exam result, which can never be "overdue" or absent.
  static Color ofScore(AppColors colors, double percentage) =>
      resolve(colors: colors, percentage: percentage, hasData: true);

  /// The fraction a progress bar should fill: 0 with no data, and never less
  /// than 2% once there is, so a real-but-tiny score is still visible.
  static double barFraction({
    required double percentage,
    required bool hasData,
  }) {
    if (!hasData) return 0;
    return (percentage.clamp(0, 100) / 100).clamp(0.02, 1).toDouble();
  }
}
