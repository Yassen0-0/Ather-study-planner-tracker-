/// Understanding classification derived from a mastery percentage.
///
/// This is the single source of truth for the four bands. Classification runs
/// through [MasteryBand.fromPercentage] and its edge constants below -- the
/// wizard's verdicts and the palette's colours included -- so the numbers that
/// decide what a student is told live in exactly one place.
enum MasteryBand {
  /// < 50 -- ضعيف
  weak,

  /// 50..69 -- متوسط
  medium,

  /// 70..89 -- كويس
  good,

  /// >= 90 -- متفوق
  excellent;

  /// Boundaries are inclusive-lower: 50.0 is [medium], 49.999 is [weak],
  /// 70.0 is [good], 90.0 is [excellent].
  static MasteryBand fromPercentage(double percentage) {
    if (percentage < kWeakBandUpperEdge) return MasteryBand.weak;
    if (percentage < kGoodBandLowerEdge) return MasteryBand.medium;
    if (percentage < kExcellentBandLowerEdge) return MasteryBand.good;
    return MasteryBand.excellent;
  }

  /// Below the [good] band -- the range for which the wizard still has
  /// something to ask ("what do I need next time") and a verdict to give.
  bool get belowGood => index < MasteryBand.good.index;
}

/// The band edges, as named constants rather than bare literals: these three
/// numbers are product policy (what counts as ضعيف, كويس, متفوق), and every
/// threshold check in the app reads them from here.
///
/// Inclusive-lower bands: a value equal to an edge belongs to the band above
/// it, so `weak` is `< kWeakBandUpperEdge`, never `<=`.
const double kWeakBandUpperEdge = 50;
const double kGoodBandLowerEdge = 70;
const double kExcellentBandLowerEdge = 90;

/// Mastery percentage at or above which a chapter may be marked "أتقنت الباب".
const double kChapterMasteryThreshold = 70;

/// Days after which a lesson's mastery is treated as decayed and must be
/// re-proven with a fresh exam.
const int kReviewCycleDays = 30;

/// Homework percentage below which the student is told to study more before
/// sitting the exam. Homework never affects mastery -- this threshold only
/// drives an advisory message.
const double kHomeworkReadinessThreshold = 60;

/// Mastery below which a lesson is surfaced in the Review Center even if it is
/// not yet overdue.
const double kLowMasteryFlagThreshold = 50;
