/// Understanding classification derived from a mastery percentage.
///
/// This is the single source of truth for the four bands. Every colour, label
/// and threshold check in the app goes through here -- no screen re-implements
/// `if (mastery < 50)`.
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
    if (percentage < 50) return MasteryBand.weak;
    if (percentage < 70) return MasteryBand.medium;
    if (percentage < 90) return MasteryBand.good;
    return MasteryBand.excellent;
  }
}

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
