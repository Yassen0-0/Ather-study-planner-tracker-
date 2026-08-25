import 'package:flutter/material.dart';

import '../../domain/entities/mastery.dart';
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
/// The one exception is [fill]: a *bar* in the middle of the range is the brand
/// accent, because a bar has to be filled with something and black reads as
/// switched off. That is a fill, not a fifth verdict — the number beside it is
/// still plain text.
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
    // Branches 3-5 read the band, not their own literals: the edges are
    // domain policy (M2), and a palette that re-implemented them could
    // disagree with every verdict and label drawn beside it.
    final band = MasteryBand.fromPercentage(percentage);
    if (band == MasteryBand.weak) return colors.wrong;
    // `rightText`, not `right`: what this function colours is a *number* and the
    // bar beneath it, and the brand green is 2.2:1 on white. In the dark palette
    // the two tokens are the same value, so nothing changes there.
    if (band == MasteryBand.excellent) return colors.rightText;
    return colors.textPrimary;
  }

  /// Colour for a single exam result, which can never be "overdue" or absent.
  static Color ofScore(AppColors colors, double percentage) =>
      resolve(colors: colors, percentage: percentage, hasData: true);

  /// The same colour, for anything **filled** rather than written: a progress
  /// bar, a chart column, a sliver under a count.
  ///
  /// One substitution, in one direction: **the neutral branch becomes the
  /// accent.** A number in the middle of the range is simply text, but the bar
  /// under it is a filled shape, and an unfilled-looking black bar is the one
  /// thing in this interface that could be mistaken for a disabled control.
  ///
  /// Red and green pass straight through — a bar for an overdue or a weak
  /// lesson is red whatever colour the brand is — and so does the no-data grey,
  /// which is the empty state the design deliberately keeps colourless.
  ///
  /// Written as a mapping over an already-resolved colour rather than a second
  /// copy of the five branches: the number and the bar are read one line apart
  /// at every call site, and two rules that have to agree are one rule.
  static Color fill(AppColors colors, Color resolved) =>
      resolved == colors.textPrimary ? colors.accent : resolved;

  /// [resolve] and [fill] in one call, for a bar with no number beside it.
  static Color bar({
    required AppColors colors,
    required double percentage,
    required bool hasData,
    bool needsReview = false,
  }) => fill(
    colors,
    resolve(
      colors: colors,
      percentage: percentage,
      hasData: hasData,
      needsReview: needsReview,
    ),
  );

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
