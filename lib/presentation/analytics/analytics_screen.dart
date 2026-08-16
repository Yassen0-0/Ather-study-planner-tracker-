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
import '../../core/widgets/pressable.dart';
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

    final subjects = dashboard.subjects;
    final filtered = _subjectFilter == null
        ? subjects
        : subjects.where((s) => s.subject.id == _subjectFilter).toList();

    final chapters = <ChapterSummary>[
      for (final subject in filtered) ...subject.chapters,
    ];
    final lessons = <({LessonSummary lesson, SubjectSummary subject})>[
      for (final subject in filtered)
        for (final chapter in subject.chapters)
          for (final lesson in chapter.lessons)
            if (lesson.hasExam) (lesson: lesson, subject: subject),
    ]..sort((a, b) => a.lesson.mastery.compareTo(b.lesson.mastery));

    // Discipline counts only lessons that have been examined: a lesson never
    // sat is not "late", it simply has no clock running yet.
    //
    // Counted over `filtered`, not `subjects`. The filter used to reach the
    // chapter bars and the weakest list and nothing else, so picking a subject
    // left this card and the bar chart above it showing figures for all four --
    // two cards silently answering a question the student had not asked.
    var examined = 0;
    var overdue = 0;
    for (final subject in filtered) {
      for (final chapter in subject.chapters) {
        for (final lesson in chapter.lessons) {
          if (!lesson.hasExam) continue;
          examined++;
          if (lesson.needsReview) overdue++;
        }
      }
    }
    final onTime = examined - overdue;
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
        _SubjectBarsCard(subjects: subjects),
        const SizedBox(height: AppSpacing.xl),
        if (chapters.isNotEmpty) ...<Widget>[
          _ChapterBarsCard(chapters: chapters),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (lessons.isNotEmpty) ...<Widget>[
          _WeakestCard(lessons: lessons.take(5).toList()),
          const SizedBox(height: AppSpacing.xl),
        ],
        _DisciplineCard(
          line: l.lessonsOnTimeOf(iso(onTime), iso(examined)),
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

    String subjectName(int id) => snapshot.subjectById(id)?.code.label(l) ?? '';

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
              label: subject.subject.code.label(l),
              selected: selected == subject.subject.id,
              onTap: () => onSelect(subject.subject.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectBarsCard extends StatelessWidget {
  const _SubjectBarsCard({required this.subjects});

  final List<SubjectSummary> subjects;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.analyticsMasteryBySubject, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xl),
          // Forced LTR so the four subjects keep the same left-to-right order
          // as every other chart, and a comparison never silently mirrors.
          Ltr(
            child: SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (final subject in subjects) ...<Widget>[
                    Expanded(
                      child: _VerticalBar(
                        label: subject.subject.code.label(l),
                        mastery: subject.mastery,
                        hasData: subject.hasAnyExam,
                        needsReview: subject.needsReview,
                      ),
                    ),
                    if (subject != subjects.last)
                      const SizedBox(width: AppSpacing.xl),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalBar extends StatelessWidget {
  const _VerticalBar({
    required this.label,
    required this.mastery,
    required this.hasData,
    required this.needsReview,
  });

  final String label;
  final double mastery;
  final bool hasData;
  final bool needsReview;

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

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          percentLabel(mastery, hasData: hasData),
          style: AppTypography.chartValue.copyWith(color: color),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 36),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.colors.fill,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: hasData
                      ? (mastery.clamp(0, 100) / 100).clamp(0.03, 1).toDouble()
                      : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
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
                      height: 10,
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
                        color: MasteryPalette.resolve(
                          colors: context.colors,
                          percentage: chapter.mastery,
                          hasData: chapter.hasAnyExam,
                          needsReview: chapter.needsReview,
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
                            entry.subject.subject.code.label(l),
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
