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
import '../../domain/services/summaries.dart';
import '../common/settings_button.dart';
import '../common/subject_mark.dart';
import '../common/subject_presentation.dart';
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
    final next = ref.watch(nextTargetProvider);

    return AtherScreen(
      // No week strip. The dashboard's copy was inert -- nothing to select and
      // nothing to tap -- and the only thing it reported, "an exam happened on
      // this day", is already stated in full by the cards directly beneath it.
      // Seven circles that answer no question are seven circles between the
      // student and the screen. The tasks screen keeps its strip, because there
      // it picks the day the list belongs to.
      header: DayHeader(
        title: l.dashboardTitle,
        actions: const <Widget>[SettingsButton()],
      ),
      children: <Widget>[
        // A brand-new student used to land on "—", three zeroes and four
        // subject rows, with the actual first step -- open a subject, add a
        // chapter, add a lesson, sit an exam -- written down nowhere. It is the
        // longest path in the app and it was the only one with no signposting.
        //
        // The card **replaces** the two summary cards rather than sitting above
        // them: with nothing recorded they show "—" and "0 / 0" three times, so
        // they occupy the top of the screen to say nothing. Stacking a third
        // card on top of them pushed the four subjects -- the only things worth
        // tapping -- below the fold.
        if (dashboard.isEmpty)
          _FirstRunCard(subjects: dashboard.subjects)
        else ...<Widget>[
          _OverallCard(dashboard: dashboard),
          const SizedBox(height: AppSpacing.md),
          _StatsCard(stats: stats),
        ],
        const SizedBox(height: AppSpacing.xxxl),
        SectionTitle(l.sectionSubjects),
        const SizedBox(height: AppSpacing.md),
        for (final (i, subject) in dashboard.subjects.indexed) ...<Widget>[
          ListEntrance(
            index: i,
            id: subject.subject.id,
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

/// Shown only while the student has built nothing at all.
///
/// It disappears the moment a first chapter exists, so it is a starting point
/// rather than a tutorial to dismiss — there is no "got it" button, because a
/// card that has to be got rid of is a card that will be got rid of unread.
///
/// The copy also states the product's one claim up front. A student arriving
/// from any other study app expects ticking things off to move a number, and
/// finding out otherwise three screens in is finding out too late.
class _FirstRunCard extends StatelessWidget {
  const _FirstRunCard({required this.subjects});

  final List<SubjectSummary> subjects;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.firstRunTitle, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.textGap),
          Text(l.firstRunBody, style: context.text.secondary),
          if (subjects.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l.firstRunAction,
              onTap: () =>
                  context.push(Routes.subject(subjects.first.subject.id)),
            ),
          ],
        ],
      ),
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
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.overallMastery, style: AppTypography.cardLabel),
          const SizedBox(height: AppSpacing.textGap),
          // Baseline, not bottom. The sentence beside the number wraps to two
          // lines on a narrow screen or at a large text scale, and bottom
          // alignment lines its *last* line up with the number — which lifts
          // "١ من ٤ باب" clear above the number's cap height and leaves
          // "اتقنتها" stranded beside it. On one baseline the sentence starts
          // level with the figure and runs on underneath it, which is the order
          // it is read in.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
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
          const SizedBox(height: AppSpacing.xl),
          MasteryBar(
            fraction: MasteryPalette.barFraction(
              percentage: dashboard.overallMastery,
              hasData: hasData,
            ),
            color: MasteryPalette.fill(context.colors, color),
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
      padding: AppSpacing.cardPadding,
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
          const SizedBox(width: AppSpacing.xl),
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
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: _Stat(
              label: l.statMastered,
              value: stats.mastered,
              total: stats.totalLessons,
              fraction: stats.fraction(stats.mastered),
              color: stats.mastered > 0
                  ? context.colors.rightText
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
          style: AppTypography.statLabel,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Ltr(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '$value',
                style: AppTypography.statValue.copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text('/ $total', style: context.text.statDenominator),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        MasteryBar(
          // The sliver is a fill, so a stat with nothing to be red or green
          // about gets the accent rather than the black its count is written
          // in. See MasteryPalette.fill.
          fraction: fraction,
          color: MasteryPalette.fill(context.colors, color),
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
          SubjectMark(subject: summary.subject),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        summary.subject.label(l),
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
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowStatus.copyWith(
                    color: summary.needsReview
                        ? context.colors.wrong
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
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
          const SizedBox(width: AppSpacing.xl),
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
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  target.isOverdue
                      ? l.overdueByDays(iso(target.daysOverdue))
                      : l.lessonNoExamYet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowStatus.copyWith(
                    color: target.isOverdue
                        ? context.colors.wrong
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
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
