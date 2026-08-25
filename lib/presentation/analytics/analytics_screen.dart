import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show listEquals;
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
import '../../core/widgets/pop_in.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reduced_motion.dart';
import '../../core/widgets/status_chip.dart';
import '../../domain/services/insights_generator.dart';
import '../../domain/services/summaries.dart';
import '../common/settings_button.dart';
import '../common/subject_presentation.dart';
import '../providers/app_providers.dart';
import '../providers/summary_providers.dart';

/// "تقدمك" — the screen that answers "am I getting better".
///
/// Deliberately plain geometry: plain rectangles, one colour rule, no chart
/// library. Every bar here is the same mastery number shown elsewhere, so a
/// student can check the chart against the subject screen and find they agree.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  /// Null means "كل المواد".
  int? _subjectFilter;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dashboard = ref.watch(dashboardProvider);
    final insights = ref.watch(insightsProvider);
    // Computed once per snapshot by the provider, not here: this build runs
    // again on every filter tap below, and the series does not care which
    // filter is showing.
    final trajectories = ref.watch(trajectoriesProvider);

    final subjects = dashboard.subjects;
    final filtered = _subjectFilter == null
        ? subjects
        : subjects.where((s) => s.subject.id == _subjectFilter).toList();

    // Filtered like everything else below: picking one subject must not leave a
    // chart still answering a question about the other three.
    final visibleIds = <int>{for (final s in filtered) s.subject.id};
    final visibleTrajectories = <SubjectTrajectory>[
      for (final t in trajectories)
        if (visibleIds.contains(t.subjectId)) t,
    ];

    final chapters = <ChapterSummary>[
      for (final subject in filtered) ...subject.chapters,
    ];
    final lessons = <({LessonSummary lesson, SubjectSummary subject})>[
      for (final subject in filtered)
        for (final chapter in subject.chapters)
          for (final lesson in chapter.lessons)
            if (lesson.hasExam) (lesson: lesson, subject: subject),
    ]..sort((a, b) => a.lesson.mastery.compareTo(b.lesson.mastery));

    // Discipline figures come straight from the same counters the insights
    // generator certifies against, so the bar here and any certificate above
    // can never disagree about the same student. Scoped to `visibleIds` like
    // everything else below -- the filter must still reach this card -- while
    // the insight itself always counts every active subject; see
    // [InsightsGenerator.disciplineCounts] for the rule both read.
    final (:examined, :onTime) = InsightsGenerator.disciplineCounts(
      ref.watch(snapshotValueProvider),
      ref.watch(nowValueProvider),
      subjectIds: visibleIds,
    );
    final disciplineRate = examined == 0 ? 0.0 : onTime / examined * 100;

    return AtherScreen(
      header: AtherHeader(
        title: l.analyticsTitle,
        actions: const <Widget>[SettingsButton()],
      ),
      children: <Widget>[
        if (insights.isNotEmpty) ...<Widget>[
          _InsightsCard(insights: insights),
          const SizedBox(height: AppSpacing.xl),
        ],
        _FilterRow(
          subjects: subjects,
          selected: _subjectFilter,
          onSelect: (id) => setState(() => _subjectFilter = id),
        ),
        const SizedBox(height: AppSpacing.xl),
        // The one card that deliberately ignores the filter: it exists to
        // compare the subjects against each other, and a comparison of one
        // subject with itself is not a chart.
        //
        // The KEY still carries the filter: SP-05 (AN-01) pins the column
        // growth to "first draw + every filter change", so a new filter value
        // remounts the card and its animator restarts cleanly from zero. The
        // data inside is unchanged by design — only the clock replays.
        _SubjectBarsCard(key: ValueKey(_subjectFilter), subjects: subjects),
        const SizedBox(height: AppSpacing.xl),
        // Only when at least one subject on screen has a line to draw. A card
        // of empty axes is worse than no card: it reads as a measurement that
        // came back flat rather than one not taken yet.
        //
        // Same keying rule as the bars card above, per SP-06 (AN-02): the
        // trajectory draws on screen entry and filter change only — never on
        // scroll, never on unrelated rebuilds. A data-only change re-measures
        // the cached geometry without replaying the draw (see
        // [_TrajectoryChart.didUpdateWidget]).
        if (visibleTrajectories.any((t) => t.hasTrend)) ...<Widget>[
          _TrajectoryCard(
            key: ValueKey(_subjectFilter),
            trajectories: visibleTrajectories,
            subjects: filtered,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (chapters.isNotEmpty) ...<Widget>[
          _ChapterBarsCard(chapters: chapters),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (lessons.isNotEmpty) ...<Widget>[
          _WeakestCard(lessons: lessons.take(5).toList()),
          const SizedBox(height: AppSpacing.xl),
        ],
        _DisciplineCard(
          line: l.lessonsOnTimeOf(onTime, examined),
          rate: disciplineRate,
          hasData: examined > 0,
        ),
        if (chapters.isEmpty && lessons.isEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              l.analyticsNotEnoughData,
              style: context.text.secondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// The text-safe form of a mastery verdict, for printed figures.
///
/// [MasteryPalette.resolve] already returns [AppColors.rightText] for green
/// because what it colours is a *number*; red needed the same treatment, and
/// [AppColors.wrongText] exists for exactly that. Everything this screen
/// prints in a verdict colour is `chartValue` (12px bold) — body-text rules
/// apply, not the large-text 3:1 the big mastery figures are held to.
Color _verdictText(AppColors colors, Color resolved) =>
    resolved == colors.wrong ? colors.wrongText : resolved;

class _InsightsCard extends ConsumerWidget {
  const _InsightsCard({required this.insights});

  final List<Insight> insights;

  /// Insights arrive from the domain as structured variants, never as
  /// pre-rendered sentences, so they translate with the language toggle instead
  /// of being frozen in whichever language was active when they were computed.
  (String, Color) _render(
    L l,
    AppColors colors,
    WidgetRef ref,
    Insight insight,
  ) {
    final snapshot = ref.read(snapshotValueProvider);

    String subjectName(int id) => snapshot.subjectById(id)?.label(l) ?? '';

    return switch (insight) {
      StrongestSubjectInsight(:final subjectId, :final mastery) => (
        l.insightStrongestSubject(subjectName(subjectId), percent(mastery)),
        colors.right,
      ),
      SubjectImprovedInsight(:final subjectId, :final deltaPercentagePoints) =>
        (
          l.insightSubjectImproved(
            subjectName(subjectId),
            percent(deltaPercentagePoints),
          ),
          colors.right,
        ),
      ChapterNeedsAttentionInsight(:final chapterName, :final mastery) => (
        l.insightChapterWeak(chapterName, percent(mastery)),
        colors.wrong,
      ),
      LessonNotReviewedInsight(:final lessonName, :final days) => (
        l.insightLessonNotReviewed(lessonName, iso(days)),
        colors.wrong,
      ),
      DisciplineInsight(:final onTimeCount, :final examinedCount) => (
        l.insightDiscipline(iso(onTimeCount), iso(examinedCount)),
        // `rightText`, the text-safe green: this dot sits beside body copy, and
        // the fill-grade [AppColors.right] is for surfaces, not sentences.
        colors.rightText,
      ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.analyticsInsights, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          for (final insight in insights) ...<Widget>[
            const CardDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Builder(
                builder: (context) {
                  final (text, color) = _render(
                    l,
                    context.colors,
                    ref,
                    insight,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.only(top: AppSpacing.textGap),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(text, style: AppTypography.body)),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.subjects,
    required this.selected,
    required this.onSelect,
  });

  final List<SubjectSummary> subjects;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          AtherFilterChip(
            label: l.analyticsAllSubjects,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final subject in subjects) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            AtherFilterChip(
              label: subject.subject.label(l),
              selected: selected == subject.subject.id,
              onTap: () => onSelect(subject.subject.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// "اتقانك حسب المادة" — the four vertical columns, grown in (AN-01).
///
/// **DOCUMENTED LAYOUT EXCEPTION** (animation/06_motion_specs.md SP-05, against
/// the standing "no layout animation" rule): the growth animates
/// `heightFactor`, which is layout. It is allowed here exactly where the spec
/// allows it — the columns grow inside ONE fixed-size card (the 150px-tall box
/// below never changes height), outside any synchronized scroll (this screen is
/// a plain column of cards; nothing scrolls in lockstep with this one), and no
/// row is added, removed or re-measured: the fill grows into space already
/// reserved by its `Expanded`. The cost of every frame is confined to a relayout
/// of this subtree. Same class of exception as the collapse-row page.
class _SubjectBarsCard extends StatefulWidget {
  const _SubjectBarsCard({super.key, required this.subjects});

  final List<SubjectSummary> subjects;

  @override
  State<_SubjectBarsCard> createState() => _SubjectBarsCardState();
}

class _SubjectBarsCardState extends State<_SubjectBarsCard>
    with SingleTickerProviderStateMixin {
  // -- SP-05 numbers, pinned for THIS screen ---------------------------------
  //
  // A spec-pinned override of the motion tokens, declared here as documented
  // local constants rather than added to [AppMotion]: the register's stagger
  // token is 40ms capped at 6 rows and its value tween is 600ms, but SP-05
  // pins this chart to a tighter choreography — 450ms easeOutCubic growth,
  // stagger 30ms capped at the first 4 columns (columns past the cap start
  // settled), and each column's percentage counting over the same 450ms span,
  // starting 60ms after its own column begins.
  static const double _growMs = 450;
  static const double _staggerMs = 30;
  static const int _staggerCap = 4;
  static const double _countDelayMs = 60;

  late final AnimationController _controller;

  /// Whether the clock has been started. Held back until there is at least one
  /// column to draw: an empty dashboard snapshot must not burn the timeline
  /// before the real data lands (the chart's first draw is the trigger).
  bool _launched = false;

  /// Columns that actually animate: at most [_staggerCap]; anything past the
  /// cap starts settled, per the spec.
  static int _animCount(int n) => math.min(n, _staggerCap);

  /// Total timeline for [n] columns: last stagger slot + one growth window +
  /// the count's 60ms tail past its own column.
  static double _totalMs(int n) {
    final k = _animCount(n);
    if (k == 0) return 0;
    return _growMs + _staggerMs * (k - 1) + _countDelayMs;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs(subjects.length).round()),
    );
  }

  List<SubjectSummary> get subjects => widget.subjects;

  @override
  void didUpdateWidget(_SubjectBarsCard old) {
    super.didUpdateWidget(old);
    // The card always receives ALL subjects regardless of filter (that is its
    // point), so a length change means the underlying data changed. Re-time the
    // controller; replaying remains the parent key's job (entry + filter only).
    _controller.duration = Duration(milliseconds: _totalMs(subjects.length).round());
  }

  void _launchOnce() {
    if (_launched || subjects.isEmpty) return;
    _launched = true;
    // Reduce-motion ⇒ final frames instantly; nothing ever runs.
    if (prefersReducedMotion(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  /// Growth and count progress `(grow, count)` for column [i] at the current
  /// controller position, or null when the column is settled (before its
  /// stagger slot it has not started but renders settled-at-zero anyway via
  /// pulse 0 — null means *fully settled*: past-cap columns, reduce-motion,
  /// finished timeline).
  ///
  /// Windows are mapped by hand off the one controller instead of per-column
  /// `CurvedAnimation`s: one clock guarantees the number cannot drift from its
  /// bar, and `pumpAndSettle` settles the whole card together.
  (double, double)? _pulsesAt(int i, bool reduced) {
    if (reduced || i >= _staggerCap) return null;
    if (_controller.status == AnimationStatus.completed) return null;
    final totalMs = _totalMs(subjects.length);
    final tMs = _controller.value * totalMs;

    double window(double beginMs, double endMs) {
      if (tMs <= beginMs) return 0;
      if (tMs >= endMs) return 1;
      return Curves.easeOutCubic.transform((tMs - beginMs) / (endMs - beginMs));
    }

    final begin = i * _staggerMs;
    return (
      window(begin, begin + _growMs),
      window(begin + _countDelayMs, begin + _countDelayMs + _growMs),
    );
  }

  /// One column of the row: its data plus its own windows on the card clock.
  Widget _column(L l, int i, SubjectSummary subject, bool reduced) {
    final pulses = _pulsesAt(i, reduced);
    return Expanded(
      child: _VerticalBar(
        label: subject.subject.label(l),
        mastery: subject.mastery,
        hasData: subject.hasAnyExam,
        needsReview: subject.needsReview,
        growPulse: pulses?.$1,
        countPulse: pulses?.$2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _launchOnce();
    final l = L.of(context);
    final reduced = prefersReducedMotion(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.analyticsMasteryBySubject, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xl),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // Forced LTR so the four subjects keep the same left-to-right order
              // as every other chart, and a comparison never silently mirrors.
              return Ltr(
                child: SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (final (i, subject) in subjects.indexed) ...<Widget>[
                        _column(l, i, subject, reduced),
                        if (i != subjects.length - 1)
                          const SizedBox(width: AppSpacing.xl),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One column of [_SubjectBarsCard].
///
/// [growPulse]/[countPulse] are that column's own windows on the card's single
/// clock (SP-05), 0..1; null means settled — the fraction stands exactly where
/// it stood before this animation existed, so the end state is unchanged.
class _VerticalBar extends StatelessWidget {
  const _VerticalBar({
    required this.label,
    required this.mastery,
    required this.hasData,
    required this.needsReview,
    this.growPulse,
    this.countPulse,
  });

  final String label;
  final double mastery;
  final bool hasData;
  final bool needsReview;

  final double? growPulse;
  final double? countPulse;

  @override
  Widget build(BuildContext context) {
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: mastery,
      hasData: hasData,
      needsReview: needsReview,
    );
    // The column is a fill, so its neutral case is the accent while the number
    // printed above it stays plain text. See MasteryPalette.fill.
    final fill = MasteryPalette.fill(context.colors, color);

    final fraction =
        MasteryPalette.barFraction(percentage: mastery, hasData: hasData) *
        (growPulse ?? 1);

    // The number counts up inside its own column's window (+60ms, same 450ms
    // span — SP-05), reusing `percentLabel` so the settled string is
    // byte-identical to the raw Text this replaces. Colour is applied, never
    // tweened (the AnimatedPercentage rule); "—" is not a number and is never
    // counted to or from.
    final String percentText;
    if (!hasData) {
      percentText = percentLabel(mastery, hasData: false);
    } else if (countPulse != null && countPulse! < 1) {
      percentText = percentLabel(mastery * countPulse!, hasData: true);
    } else {
      percentText = percentLabel(mastery, hasData: true);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          percentText,
          style: AppTypography.chartValue.copyWith(color: _verdictText(context.colors, color)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 36),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.colors.fill,
                borderRadius: BorderRadius.circular(AppRadius.segment),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                // One minimum-visibility rule for every bar in the app, not a
                // private clamp: see [MasteryPalette.barFraction]. Multiplied
                // here by the growth pulse only — at settle the product is the
                // exact fraction every other screen shows.
                child: FractionallySizedBox(
                  heightFactor: fraction,
                  child: Container(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(AppRadius.segment),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.chartLabel,
        ),
      ],
    );
  }
}

class _ChapterBarsCard extends StatelessWidget {
  const _ChapterBarsCard({required this.chapters});

  final List<ChapterSummary> chapters;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.analyticsMasteryByChapter, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xl),
          for (final chapter in chapters)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 104,
                    child: Text(
                      chapter.chapter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.small,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MasteryBar(
                      fraction: MasteryPalette.barFraction(
                        percentage: chapter.mastery,
                        hasData: chapter.hasAnyExam,
                      ),
                      color: MasteryPalette.bar(
                        colors: context.colors,
                        percentage: chapter.mastery,
                        hasData: chapter.hasAnyExam,
                        needsReview: chapter.needsReview,
                      ),
                      height: AppSizes.barTrack,
                      trackColor: context.colors.fill,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 42,
                    child: Text(
                      percentLabel(
                        chapter.mastery,
                        hasData: chapter.hasAnyExam,
                      ),
                      textAlign: TextAlign.end,
                      style: AppTypography.chartValue.copyWith(
                        color: _verdictText(
                          context.colors,
                          MasteryPalette.resolve(
                            colors: context.colors,
                            percentage: chapter.mastery,
                            hasData: chapter.hasAnyExam,
                            needsReview: chapter.needsReview,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeakestCard extends StatelessWidget {
  const _WeakestCard({required this.lessons});

  final List<({LessonSummary lesson, SubjectSummary subject})> lessons;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.analyticsWeakestLessons, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          for (final entry in lessons) ...<Widget>[
            const CardDivider(),
            Pressable(
              onTap: () => context.push(Routes.lesson(entry.lesson.lesson.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            entry.lesson.lesson.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.listTitle,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            entry.subject.subject.label(l),
                            style: context.text.small,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      percent(entry.lesson.mastery),
                      style: AppTypography.rowNumberCompact.copyWith(
                        color: MasteryPalette.resolve(
                          colors: context.colors,
                          percentage: entry.lesson.mastery,
                          hasData: true,
                          needsReview: entry.lesson.needsReview,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({
    required this.line,
    required this.rate,
    required this.hasData,
  });

  final String line;
  final double rate;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.analyticsReviewDiscipline, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(child: Text(line, style: context.text.secondaryStrong)),
              Text(
                percentLabel(rate, hasData: hasData),
                style: AppTypography.rowNumberSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          MasteryBar(
            // The accent, not the mastery colour: this measures habit, not
            // understanding, and colouring it green would let a student read
            // "on time" as "mastered". Blue says only "this much of it".
            fraction: hasData ? (rate / 100).clamp(0, 1).toDouble() : 0,
            color: context.colors.accent,
          ),
        ],
      ),
    );
  }
}

/// Score over time, one line per subject.
///
/// Hand-drawn geometry, like every other chart on this screen: a plain polyline
/// over a plain track. `pubspec.yaml` records that `fl_chart` was removed on
/// purpose, and a chart package would come back for one screen worth of line.
///
/// Each line is the same subject mastery figure as the bars above, sampled on
/// the days the student sat exams -- so the right-hand end of a line and that
/// subject bar are the same number, and a student who checks finds they agree.
class _TrajectoryCard extends StatelessWidget {
  const _TrajectoryCard({
    super.key,
    required this.trajectories,
    required this.subjects,
  });

  final List<SubjectTrajectory> trajectories;
  final List<SubjectSummary> subjects;

  String? _nameOf(L l, int subjectId) {
    for (final summary in subjects) {
      if (summary.subject.id == subjectId) return summary.subject.label(l);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.analyticsTrajectory, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          for (final trajectory in trajectories)
            if (_nameOf(l, trajectory.subjectId) case final name?) ...<Widget>[
              const CardDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: _TrajectoryRow(name: name, trajectory: trajectory),
              ),
            ],
        ],
      ),
    );
  }
}

class _TrajectoryRow extends StatelessWidget {
  const _TrajectoryRow({required this.name, required this.trajectory});

  final String name;
  final SubjectTrajectory trajectory;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final colors = context.colors;

    // Rounded before the sign is chosen, so a +0.4 cannot print as "+0" beside
    // a line the student can see has not moved.
    final rounded = trajectory.velocityPerCycle.round();
    final isFlat = rounded == 0;
    // The text-safe verdict grades ([rightText]/[wrongText]): this is a 12px
    // figure on a white card, and both fill colours fail body-text AA here.
    final velocityColor = isFlat
        ? colors.textSecondary
        : _verdictText(colors, rounded > 0 ? colors.right : colors.wrong);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(name, style: AppTypography.listTitle)),
            const SizedBox(width: AppSpacing.md),
            Text(
              trajectory.hasTrend
                  ? (isFlat
                        ? l.analyticsVelocityFlat
                        : l.analyticsVelocity(rounded))
                  : l.analyticsNotEnoughData,
              style: AppTypography.chartValue.copyWith(
                color: trajectory.hasTrend ? velocityColor : colors.textNoData,
              ),
            ),
          ],
        ),
        if (trajectory.hasTrend) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _TrajectoryChart(
            points: <double>[
              for (final p in trajectory.points) p.mastery,
            ],
            line: colors.accent,
            track: colors.fill,
          ),
        ],
      ],
    );
  }
}

/// One trajectory line, drawn on (SP-06 / AN-02).
///
/// **Documented scope of movement:** the line draws on screen entry and on
/// filter change only — the whole trajectory card is keyed by the filter
/// upstream, and nothing here is scroll-linked. A data-only change re-measures
/// the cached geometry so the shape stays true, but does not replay the draw.
///
/// The LTR pin and the fixed 0..100 axis live with [_geometryFor]; the reveal
/// timeline lives in the state: 400ms easeOutCubic `PathMetric.extractPath`,
/// then the endpoint dot enters with [PopIn] once its line exists.
class _TrajectoryChart extends StatefulWidget {
  const _TrajectoryChart({
    required this.points,
    required this.line,
    required this.track,
  });

  final List<double> points;
  final Color line;
  final Color track;

  @override
  State<_TrajectoryChart> createState() => _TrajectoryChartState();
}

class _TrajectoryChartState extends State<_TrajectoryChart>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // -- SP-06 numbers, pinned for THIS chart ----------------------------------
  //
  // A spec-pinned override declared as a documented local constant: the draw-on
  // runs 400ms easeOutCubic — between [AppMotion.segment] (250ms) and
  // [AppMotion.value] (600ms), deliberately its own beat — then the endpoint
  // dot pops for the standard [AppMotion.pop] through [PopIn].
  static const Duration _draw = Duration(milliseconds: 400);

  /// Test handle for the endpoint dot: its presence is what proves the
  /// sequence (line first, dot after) completed in either direction.
  static const ValueKey<String> _endpointKey = ValueKey('trajectory-endpoint');

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _draw,
  )
    ..addStatusListener((status) {
      // The dot mounts only once its line is fully drawn: it enters, it does
      // not ride the line's tail. One-shot — `completed` fires exactly once.
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _dotShown = true);
      }
    });

  bool _launched = false;
  bool _dotShown = false;

  /// The measured path and its contour length — computed outside paint and
  /// cached (SP-06). Invalidated by [didChangeMetrics], a data change, or a
  /// size change; rebuilt lazily at layout time.
  _TrajectoryGeometry? _geometry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Rotation, split-screen, window resize: the cached geometry was measured
    // against the old canvas. Drop it and re-measure on the next layout (SP-06:
    // metrics recomputed on didChangeMetrics).
    setState(() => _geometry = null);
  }

  @override
  void didUpdateWidget(_TrajectoryChart old) {
    super.didUpdateWidget(old);
    // Data change: re-measure so the shape stays honest — but do NOT restart
    // the clock. The draw belongs to entry and filter change only; if the line
    // had already finished, the new shape appears fully drawn.
    if (!listEquals(old.points, widget.points)) _geometry = null;
  }

  void _launchOnce() {
    if (_launched || widget.points.length < 2) return;
    _launched = true;
    // Reduce-motion ⇒ final frames instantly: full line, dot standing.
    if (prefersReducedMotion(context)) {
      _controller.value = 1;
      _dotShown = true;
      return;
    }
    _controller.forward();
  }

  /// Builds the line over a fixed 0..100 range, measuring once per canvas.
  ///
  /// **Fixed, not fitted to the data.** An axis scaled to the values makes a
  /// wobble between 74% and 76% look like a cliff, which is the commonest way a
  /// chart lies. On a 0..100 axis those two readings look like what they are:
  /// almost no change at all.
  _TrajectoryGeometry? _geometryFor(Size size) {
    final cached = _geometry;
    if (cached != null && cached.size == size) return cached;
    if (widget.points.length < 2 || size.width <= 0 || size.height <= 0) {
      return null;
    }

    const strokeWidth = 2.0;
    // Inset by half the stroke, so a reading of 0 or 100 is not sliced in half
    // by the edge of the box.
    final top = strokeWidth / 2;
    final usableHeight = size.height - strokeWidth;

    double y(double mastery) =>
        top + (1 - mastery.clamp(0, 100) / 100) * usableHeight;

    final step = size.width / (widget.points.length - 1);
    final path = Path()..moveTo(0, y(widget.points.first));
    for (var i = 1; i < widget.points.length; i++) {
      path.lineTo(i * step, y(widget.points[i]));
    }

    final metric = path.computeMetrics().single;
    return _geometry = _TrajectoryGeometry(
      size: size,
      metric: metric,
      // Same endpoint the old painter circled: centre at
      // `(size.width - strokeWidth, y(points.last))`, radius 3 — pixel-identical.
      lastPoint: Offset(size.width - strokeWidth, y(widget.points.last)),
      dotRadius: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    _launchOnce();
    final reduced = prefersReducedMotion(context);

    // Forced LTR: time runs left to right in both languages, and a mirrored
    // trajectory would show a rising student falling. The surrounding text
    // above stays RTL-correct; only this canvas is pinned.
    return Ltr(
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final geometry = _geometryFor(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );
                final showDot =
                    geometry != null && (reduced || _dotShown);

                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TrajectoryRevealPainter(
                          geometry: geometry,
                          t: reduced
                              ? 1.0
                              : Curves.easeOutCubic.transform(_controller.value),
                          line: widget.line,
                          track: widget.track,
                        ),
                      ),
                    ),
                    // The newest reading, marked: it is the one the subject bar
                    // above agrees with, and the one the student is actually
                    // being told about. It enters with [PopIn]'s standard
                    // scale+fade once the line has finished drawing (or
                    // instantly under reduced motion); positioned so the
                    // settled pixels match the painted circle this replaced
                    // exactly.
                    if (showDot)
                      Positioned(
                        left: geometry.lastPoint.dx - geometry.dotRadius,
                        top: geometry.lastPoint.dy - geometry.dotRadius,
                        width: geometry.dotRadius * 2,
                        height: geometry.dotRadius * 2,
                        child: PopIn(
                          child: Container(
                            key: _endpointKey,
                            decoration: BoxDecoration(
                              color: widget.line,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The measured line, cached outside paint (SP-06): the [PathMetric] is taken
/// once per canvas size and data change; paint only extracts the visible span.
class _TrajectoryGeometry {
  const _TrajectoryGeometry({
    required this.size,
    required this.metric,
    required this.lastPoint,
    required this.dotRadius,
  });

  final Size size;
  final PathMetric metric;

  /// Where the newest reading lands — the pop-in dot's centre, in chart space.
  final Offset lastPoint;
  final double dotRadius;
}

/// Draws the baseline track plus the revealed fraction of the line:
/// `metric.extractPath(0, length · t)` over the controller's eased progress.
///
/// At `t == 1` the extracted sub-path is the whole contour, stroked with the
/// same cap/join/width as before — the settled frame is golden-equivalent to
/// the always-drawn painter this replaced.
class _TrajectoryRevealPainter extends CustomPainter {
  const _TrajectoryRevealPainter({
    required this.geometry,
    required this.t,
    required this.line,
    required this.track,
  });

  final _TrajectoryGeometry? geometry;
  final double t;
  final Color line;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = geometry;
    if (geo == null) return;

    const strokeWidth = 2.0;

    // The baseline the eye reads the line against.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = track,
    );

    canvas.drawPath(
      geo.metric.extractPath(0, geo.metric.length * t.clamp(0.0, 1.0)),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrajectoryRevealPainter old) =>
      old.geometry != geometry ||
      old.t != t ||
      old.line != line ||
      old.track != track;
}
