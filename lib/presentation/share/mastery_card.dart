import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/branding/ather_brand.dart';
import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/mastery_palette.dart';
import '../../domain/entities/mastery.dart';
import '../../domain/services/summaries.dart';
import '../common/subject_presentation.dart';
import 'widget_raster.dart';

/// One subject's line on the card.
final class MasteryCardRow {
  const MasteryCardRow({required this.label, required this.mastery});

  final String label;
  final double mastery;
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
    final color = MasteryPalette.resolve(
      colors: colors,
      percentage: row.mastery,
      hasData: true,
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
              value: (row.mastery / 100).clamp(0, 1),
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
          percent(row.mastery),
          style: AppTypography.rowTitle.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Lessons the student has actually proved, by the app's own definition.
///
/// `hasExam` first, and it is the whole point: a lesson with no exam has a
/// mastery of 0, so counting on the percentage alone would be counting
/// untouched lessons as failed ones rather than as unmeasured. The threshold is
/// [kChapterMasteryThreshold] -- the same 70 that decides whether a chapter can
/// be marked mastered -- rather than a second number invented for this card.
int lessonsAboveThreshold(DashboardSummary dashboard) => dashboard.subjects
    .expand((subject) => subject.chapters)
    .expand((chapter) => chapter.lessons)
    .where(
      (lesson) => lesson.hasExam && lesson.mastery >= kChapterMasteryThreshold,
    )
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
                ),
            ],
            colors: colors,
            brand: brand,
          ),
        ),
      ),
    ),
  );

  final images = await rasterizeBlocks(
    widget: card,
    width: MasteryCard.width,
    // 3x: a 1080-pixel-wide image, which is what the messaging apps this will
    // be sent through re-encode to anyway.
    pixelRatio: 3,
    view: view,
  );

  final Uint8List png;
  try {
    png = await encodePng(images.single);
  } finally {
    for (final image in images) {
      image.dispose();
    }
  }

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/ather_progress.png');
  await file.writeAsBytes(png);
  await Share.shareXFiles(<XFile>[XFile(file.path)]);
}
