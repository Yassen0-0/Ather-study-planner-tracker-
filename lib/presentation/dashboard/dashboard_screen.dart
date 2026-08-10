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
import '../../core/widgets/animated_percentage.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/day_header.dart';
import '../../core/widgets/icon_motion.dart';
import '../../core/widgets/list_entrance.dart';
import '../../core/widgets/mastery_bar.dart';
import '../../core/widgets/week_strip.dart';
import '../../domain/services/summaries.dart';
import '../common/settings_button.dart';
import '../common/subject_presentation.dart';
import '../providers/app_providers.dart';
import '../providers/navigation_providers.dart';
import '../providers/summary_providers.dart';

/// The home screen.
///
/// One dominant number (overall mastery), then the same number broken into
/// three counts, then the four subjects, then a single suggested action. The
/// student should be able to answer "where am I and what do I do now" without
/// scrolling.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final dashboard = ref.watch(dashboardProvider);
    final stats = ref.watch(homeStatsProvider);
    final now = ref.watch(nowValueProvider);
    final examDays = ref.watch(examDaysProvider);
    final next = ref.watch(nextTargetProvider);

    return AtherScreen(
      header: DayHeader(
        title: l.dashboardTitle,
        actions: const <Widget>[SettingsButton()],
        // Here a filled circle means an exam was recorded, and the strip is a
        // summary rather than a picker — no selection, no tap.
        strip: WeekStrip(today: now, activeDays: examDays),
      ),
      children: <Widget>[
        _OverallCard(dashboard: dashboard),
        const SizedBox(height: AppSpacing.md),
        _StatsCard(stats: stats),
        const SizedBox(height: AppSpacing.section),
        SectionTitle(l.sectionSubjects),
        const SizedBox(height: AppSpacing.md),
        for (final (i, subject) in dashboard.subjects.indexed) ...<Widget>[
          ListEntrance(
            index: i,
            child: _SubjectRow(summary: subject),
          ),
          const SizedBox(height: AppSpacing.listGap),
        ],
        if (next != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SectionTitle(l.sectionNext),
          const SizedBox(height: AppSpacing.md),
          _NextCard(target: next),
        ],
      ],
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.dashboard});

  final DashboardSummary dashboard;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hasData = dashboard.hasAnyExam;
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: dashboard.overallMastery,
      hasData: hasData,
    );

    return AtherCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.overallMastery, style: AppTypography.cardLabel),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              MasteryNumber(
                value: dashboard.overallMastery,
                hasData: hasData,
                color: color,
                style: AppTypography.cardNumber,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l.chaptersMasteredOf(
                    iso(dashboard.masteredChapters),
                    iso(dashboard.totalChapters),
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.secondaryStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          MasteryBar(
            fraction: MasteryPalette.barFraction(
              percentage: dashboard.overallMastery,
              hasData: hasData,
            ),
            color: color,
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _Stat(
              label: l.statLessonsRemaining,
              value: stats.remaining,
              total: stats.totalLessons,
              fraction: stats.fraction(stats.remaining),
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: _Stat(
              label: l.statNeedsReview,
              value: stats.overdue,
              total: stats.totalLessons,
              fraction: stats.fraction(stats.overdue),
              // Red only once there is something to be red about.
              color: stats.overdue > 0
                  ? context.colors.wrong
                  : context.colors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: _Stat(
              label: l.statMastered,
              value: stats.mastered,
              total: stats.totalLessons,
              fraction: stats.fraction(stats.mastered),
              color: stats.mastered > 0
                  ? context.colors.right
                  : context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.total,
    required this.fraction,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.style(size: 14, weight: AppTypography.semiBold),
        ),
        const SizedBox(height: 5),
        Ltr(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '$value',
                style: AppTypography.style(
                  size: 19,
                  weight: AppTypography.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                '/ $total',
                style: AppTypography.style(
                  size: 13,
                  weight: AppTypography.semiBold,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        MasteryBar(
          fraction: fraction,
          color: color,
          height: AppSizes.barTrackSmall,
        ),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.summary});

  final SubjectSummary summary;

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

    final lessonTotal = <int>[
      for (final chapter in summary.chapters) chapter.lessonCount,
    ].fold<int>(0, (a, b) => a + b);

    final String subtitle;
    if (!summary.hasContent) {
      subtitle = l.notStartedYet;
    } else if (summary.needsReview) {
      subtitle = l.subjectHasOverdueLesson;
    } else {
      subtitle =
          '${l.chaptersOfShort(iso(summary.masteredChapterCount), iso(summary.chapterCount))} · ${l.lessonCount(lessonTotal)}';
    }

    return AtherCard(
      onTap: () => context.push(Routes.subject(summary.subject.id)),
      child: Row(
        children: <Widget>[
          AtherIcon(summary.subject.code.glyph, size: 26),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        summary.subject.code.label(l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowTitle,
                      ),
                    ),
                    // Decay is always an icon *and* a colour. Colour alone
                    // fails for a colour-blind student and in bright sun.
                    //
                    // The mark outlives the state it reports by one animation:
                    // it floods to a tick and then collapses out of the row,
                    // so the student sees the thing they just fixed being
                    // marked done instead of silently vanishing.
                    OverdueMark(needsReview: summary.needsReview),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    size: 14,
                    weight: AppTypography.medium,
                    color: summary.needsReview
                        ? context.colors.wrong
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AnimatedPercentage(
            value: summary.mastery,
            hasData: hasData,
            color: color,
            style: AppTypography.rowNumber,
          ),
        ],
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.target});

  final NextTarget target;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colors.fill,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AtherIcon(AtherGlyph.edit, size: 19),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  target.lesson.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  target.isOverdue
                      ? l.overdueByDays(iso(target.daysOverdue))
                      : l.lessonNoExamYet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    size: 14,
                    weight: AppTypography.medium,
                    color: target.isOverdue
                        ? context.colors.wrong
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PillButton(
            label: l.actionExam,
            onTap: () =>
                context.push(Routes.exam(target.lesson.id, fromLesson: false)),
          ),
        ],
      ),
    );
  }
}
