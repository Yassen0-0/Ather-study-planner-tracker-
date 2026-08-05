import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/mastery_palette.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/mastery_bar.dart';
import '../../core/widgets/status_chip.dart';
import '../../domain/entities/exam_entry.dart';
import '../../domain/services/summaries.dart';
import '../providers/app_providers.dart';
import '../providers/summary_providers.dart';

/// What the chapter actually looks like now that it is closed.
///
/// The trend line here used to say "you improved" whatever happened. It now
/// tells the truth in three states — up, down, or not enough evidence — because
/// a report that only ever congratulates is not a report.
class ChapterReportScreen extends ConsumerWidget {
  const ChapterReportScreen({super.key, required this.chapterId});

  final int chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final summary = ref.watch(chapterSummaryProvider(chapterId));

    if (summary == null) {
      return AtherScreen(
        header: AtherHeader(title: '', onBack: () => context.pop()),
        children: const <Widget>[],
      );
    }

    final snapshot = ref.watch(snapshotValueProvider);
    final exams = <ExamEntry>[
      for (final lesson in summary.lessons)
        ...snapshot.examsFor(lesson.lesson.id),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final ranked = List<LessonSummary>.of(summary.lessons)
      ..sort((a, b) => a.mastery.compareTo(b.mastery));

    return AtherScreen(
      header: AtherHeader(
        title: l.chapterReportTitle,
        onBack: () => context.pop(),
      ),
      children: <Widget>[
        _ReportCard(summary: summary, exams: exams),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(l.sectionLessons),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < ranked.length; i++) ...<Widget>[
          _LessonRow(
            summary: ranked[i],
            // Only meaningful when there is something to be weakest *of*.
            weakest: i == 0 && ranked.length > 1,
          ),
          const SizedBox(height: AppSpacing.listGap),
        ],
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.summary, required this.exams});

  final ChapterSummary summary;
  final List<ExamEntry> exams;

  /// Compares where the chapter started against where it is now.
  ///
  /// Under one percentage point of movement counts as flat: reporting "up 0.4%"
  /// as improvement is the same flattery the honest-trend fix removed.
  (String, Color) _trend(L l, AppColors colors) {
    if (exams.length < 2) return (l.trendFlat, colors.textSecondary);

    final first = exams.first.percentage;
    final delta = summary.mastery - first;
    if (delta.abs() < 1) return (l.trendFlat, colors.textSecondary);

    final from = percent(first);
    final to = percent(summary.mastery);
    return delta > 0
        ? (l.trendUp(from, to), colors.right)
        : (l.trendDown(from, to), colors.wrong);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hasData = summary.hasAnyExam;
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: summary.mastery,
      hasData: hasData,
      needsReview: summary.needsReview,
    );
    final (trendLine, trendColor) = _trend(l, context.colors);

    return AtherCard(
      padding: AppSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            summary.chapter.name,
            textAlign: TextAlign.center,
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              percentLabel(summary.mastery, hasData: hasData),
              style: AppTypography.resultNumber.copyWith(color: color),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          MasteryBar(
            fraction: MasteryPalette.barFraction(
              percentage: summary.mastery,
              hasData: hasData,
            ),
            color: color,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${l.averageExamScore}: '
            '${hasData ? percent(summary.averageExamScore) : '—'}',
            textAlign: TextAlign.center,
            style: context.text.secondaryStrong,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            trendLine,
            textAlign: TextAlign.center,
            style: AppTypography.style(
              size: 14,
              weight: AppTypography.bold,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.summary, required this.weakest});

  final LessonSummary summary;
  final bool weakest;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: summary.mastery,
      hasData: summary.hasExam,
      needsReview: summary.needsReview,
    );

    return AtherCard(
      onTap: () => context.push(Routes.lesson(summary.lesson.id)),
      child: Row(
        children: <Widget>[
          if (weakest) ...<Widget>[
            MiniBadge(label: l.weakestLessonBadge, wrong: true),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              summary.lesson.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            percentLabel(summary.mastery, hasData: summary.hasExam),
            style: AppTypography.style(
              size: 17,
              weight: AppTypography.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
