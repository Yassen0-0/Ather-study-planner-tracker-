import 'package:flutter/material.dart';

import '../../core/branding/ather_brand.dart';
import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/mastery_palette.dart';
import '../../domain/services/summaries.dart';
import '../common/subject_presentation.dart';
import 'widget_raster.dart';

/// One subject's line on the card.
final class MasteryCardRow {
  const MasteryCardRow({
    required this.label,
    required this.mastery,
    required this.hasData,
  });

  final String label;
  final double mastery;

  /// Whether any exam stands behind [mastery]. False draws "—" in the
  /// no-data grey rather than a red 0%: an untouched subject has not scored
  /// zero, it has not been measured — and this card is the one image built to
  /// leave the phone, so it least of all may fail a subject the student never
  /// took an exam in (audit ح13/P3-12).
  final bool hasData;
}

/// A picture of where a student is, made to leave the phone.
///
/// **Nothing on it identifies the student.** No name, no email, no uid, no
/// avatar -- not because they are secret, but because this image is built to be
/// posted, and a student sharing a score has not agreed to share who they are.
/// The greeting on the dashboard carries their name; this deliberately does
/// not.
///
/// It takes plain strings and numbers rather than reading them from the
/// context, because it is drawn off-screen in a render tree with no
/// `Localizations` above it. See [rasterizeBlocks].
class MasteryCard extends StatelessWidget {
  const MasteryCard({
    super.key,
    required this.title,
    required this.overallLabel,
    required this.overall,
    required this.lessonsAboveLabel,
    required this.rows,
    required this.colors,
    required this.brand,
  });

  /// The card's own width in logical pixels. Fixed rather than fluid: this is
  /// an image with an aspect ratio, not a screen, and letting it inherit the
  /// phone's width would make the same student's card a different shape on
  /// every device.
  static const double width = 360;

  final String title;
  final String overallLabel;
  final double overall;
  final String lessonsAboveLabel;
  final List<MasteryCardRow> rows;
  final AppColors colors;
  final AtherBrandPalette brand;

  @override
  Widget build(BuildContext context) {
    final accent = MasteryPalette.resolve(
      colors: colors,
      percentage: overall,
      hasData: true,
      needsReview: false,
    );

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 22,
                    child: CustomPaint(
                      painter: AtherMarkPainter(palette: brand),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.cardLabel.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                percent(overall),
                textAlign: TextAlign.center,
                style: AppTypography.resultNumber.copyWith(color: accent),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                overallLabel,
                textAlign: TextAlign.center,
                style: AppTypography.cardLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final row in rows) ...<Widget>[
                _Row(row: row, colors: colors),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                lessonsAboveLabel,
                textAlign: TextAlign.center,
                style: AppTypography.controlLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.colors});

  final MasteryCardRow row;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    // hasData rides along from the row: the palette's first rule — no exam
    // means grey and a dash, never red — applies here exactly as it does on
    // the screens, so the shared picture cannot disagree with the app.
    final color = MasteryPalette.resolve(
      colors: colors,
      percentage: row.mastery,
      hasData: row.hasData,
      needsReview: false,
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            row.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.rowTitle.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 96,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: MasteryPalette.barFraction(
                percentage: row.mastery,
                hasData: row.hasData,
              ),
              minHeight: 6,
              backgroundColor: colors.muted,
              valueColor: AlwaysStoppedAnimation<Color>(
                MasteryPalette.fill(colors, color),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          percentLabel(row.mastery, hasData: row.hasData),
          style: AppTypography.rowTitle.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Lessons the student has actually proven, by the app's one definition.
///
/// The policy lives on [LessonSummary.isProven] and this card only counts it:
/// an exam behind the lesson, the evidence still fresh, at or above
/// [kChapterMasteryThreshold]. Freshness is not optional here — before it was
/// added, a lesson scored 75% two months ago was shared to a group chat as
/// "proven" while the dashboard below called the same lesson overdue.
int lessonsAboveThreshold(DashboardSummary dashboard) => dashboard.subjects
    .expand((subject) => subject.chapters)
    .expand((chapter) => chapter.lessons)
    .where((lesson) => lesson.isProven)
    .length;

/// Builds the card, photographs it, and hands the PNG to the share sheet.
///
/// Everything the card needs is resolved here, where a `BuildContext` still
/// exists, and passed down as values -- see [MasteryCard] for why.
///
/// Throws on failure. The caller decides what to say about it.
Future<void> shareMasteryCard({
  required BuildContext context,
  required L l,
  required DashboardSummary dashboard,
}) async {
  final colors = context.colors;
  final brand = AtherBrandPalette.of(context).withoutPlate;
  final direction = Directionality.of(context);
  final view = View.of(context);

  final lessonsAbove = lessonsAboveThreshold(dashboard);

  final card = Directionality(
    textDirection: direction,
    child: MediaQuery(
      // Not the student's text scale: this is an image with a fixed frame, and
      // a 2x scale would push its own rows out of it.
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: DefaultTextStyle(
        style: TextStyle(fontFamily: 'ReadexPro', color: colors.textPrimary),
        child: RepaintBoundary(
          child: MasteryCard(
            title: l.shareCardTitle,
            overallLabel: l.shareCardOverall,
            overall: dashboard.overallMastery,
            lessonsAboveLabel: l.shareCardLessonsAbove(lessonsAbove),
            rows: <MasteryCardRow>[
              for (final subject in dashboard.subjects)
                MasteryCardRow(
                  label: subject.subject.label(l),
                  mastery: subject.mastery,
                  hasData: subject.hasAnyExam,
                ),
            ],
            colors: colors,
            brand: brand,
          ),
        ),
      ),
    ),
  );

  await captureAndShare(
    widget: card,
    width: MasteryCard.width,
    // Fixed, not derived from anything the student typed: sharing twice
    // overwrites this file rather than collecting them (see [captureAndShare]).
    fileNameBase: 'ather_progress',
    view: view,
  );
}

/// A closed chapter's certificate: the chapter's name, the day it closed, how
/// many exams stand behind that, and where mastery ended.
///
/// Same rules as [MasteryCard]: **nothing on it identifies the student** --
/// the chapter's name is content, like a subject's is, but no profile name,
/// email or uid rides along. It takes plain strings and numbers because it is
/// drawn off-screen with no `Localizations` above it; see [rasterizeBlocks].
class ChapterCertificateCard extends StatelessWidget {
  const ChapterCertificateCard({
    super.key,
    required this.chapterName,
    required this.closureLabel,
    required this.examsLabel,
    required this.masteryLabel,
    required this.mastery,
    required this.hasData,
    required this.needsReview,
    required this.colors,
    required this.brand,
  });

  /// The same frame as [MasteryCard.width]: one card shape in the app's
  /// share sheet, not two.
  static const double width = MasteryCard.width;

  final String chapterName;

  /// «أُغلِق {date}» -- a date, phrased as an event. The certificate claims a
  /// past fact, never a present standing: whether the closure still holds is
  /// the screen's green badge to say, not the picture's.
  final String closureLabel;

  final String examsLabel;
  final String masteryLabel;
  final double mastery;

  /// Rides along so an unmeasured number would draw "—" in grey rather than
  /// red 0% -- unreachable for a mastered chapter today, but the palette's
  /// rule is passed, not assumed (audit ح13).
  final bool hasData;
  final bool needsReview;
  final AppColors colors;
  final AtherBrandPalette brand;

  @override
  Widget build(BuildContext context) {
    final accent = MasteryPalette.resolve(
      colors: colors,
      percentage: mastery,
      hasData: hasData,
      needsReview: needsReview,
    );

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 22,
                    child: CustomPaint(
                      painter: AtherMarkPainter(palette: brand),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      chapterName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardLabel.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                percentLabel(mastery, hasData: hasData),
                textAlign: TextAlign.center,
                style: AppTypography.resultNumber.copyWith(color: accent),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                masteryLabel,
                textAlign: TextAlign.center,
                style: AppTypography.cardLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                examsLabel,
                textAlign: TextAlign.center,
                style: AppTypography.controlLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                closureLabel,
                textAlign: TextAlign.center,
                style: AppTypography.statusLine.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds the closed chapter's certificate and shares it through
/// [captureAndShare]. [summary] must be a mastered chapter (`masteredAt` set)
/// -- only then does its caller show the button.
///
/// Throws on failure. The caller decides what to say about it.
Future<void> shareChapterCertificate({
  required BuildContext context,
  required L l,
  required ChapterSummary summary,
}) async {
  assert(summary.chapter.masteredAt != null);
  final colors = context.colors;
  final brand = AtherBrandPalette.of(context).withoutPlate;
  final direction = Directionality.of(context);
  final view = View.of(context);

  // One count of every exam behind the closure, lesson by lesson -- derived
  // from the summaries the screen already shows, never recounted here.
  final exams = summary.lessons.fold<int>(
    0,
    (total, lesson) => total + lesson.examCount,
  );

  final card = Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: DefaultTextStyle(
        style: TextStyle(fontFamily: 'ReadexPro', color: colors.textPrimary),
        child: RepaintBoundary(
          child: ChapterCertificateCard(
            chapterName: summary.chapter.name,
            closureLabel: l.chapterClosureDated(
              dateLabel(summary.chapter.masteredAt!),
            ),
            examsLabel: l.examCountLabel(exams),
            masteryLabel: l.chapterReportMasteryLabel,
            mastery: summary.mastery,
            hasData: summary.hasAnyExam,
            needsReview: summary.needsReview,
            colors: colors,
            brand: brand,
          ),
        ),
      ),
    ),
  );

  await captureAndShare(
    widget: card,
    width: ChapterCertificateCard.width,
    fileNameBase: 'ather_chapter_certificate',
    view: view,
  );
}
