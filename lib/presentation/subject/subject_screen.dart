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
import '../../core/widgets/collapsing_removal.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/mastery_bar.dart';
import '../../domain/services/summaries.dart';
import '../common/prompts.dart';
import '../common/subject_presentation.dart';
import '../common/write_guard.dart';
import '../providers/app_providers.dart';
import '../providers/summary_providers.dart';

/// One subject: its overall figure, then the chapters the student built inside
/// it. Subjects are fixed and cannot be added, renamed or deleted, so this
/// screen has no subject-level actions at all.
class SubjectScreen extends ConsumerWidget {
  const SubjectScreen({super.key, required this.subjectId});

  final int subjectId;

  Future<void> _addChapter(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final name = await showNamePrompt(
      context,
      title: l.addChapter,
      hint: l.chapterNameHint,
    );
    if (name == null || !context.mounted) return;
    await runWrite(
      context,
      () => ref
          .read(studyRepositoryProvider)
          .createChapter(
            subjectId: subjectId,
            name: name,
            at: ref.read(clockProvider).now(),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final summary = ref.watch(subjectSummaryProvider(subjectId));

    if (summary == null) {
      return AtherScreen(
        header: AtherHeader(title: '', onBack: () => context.pop()),
        children: const <Widget>[],
      );
    }

    return AtherScreen(
      header: AtherHeader(
        title: summary.subject.code.label(l),
        onBack: () => context.pop(),
      ),
      children: <Widget>[
        _SubjectSummaryCard(summary: summary),
        const SizedBox(height: AppSpacing.xl),
        if (summary.chapters.isEmpty)
          EmptyState(
            title: l.noChaptersYet,
            action: DashedAddButton(
              label: l.addChapter,
              onTap: () => _addChapter(context, ref),
            ),
          )
        else ...<Widget>[
          SectionTitle(l.sectionChapters),
          const SizedBox(height: AppSpacing.md),
          CollapsingList<ChapterSummary>(
            items: summary.chapters,
            idOf: (c) => c.chapter.id,
            itemBuilder: (context, c) => _ChapterCard(summary: c),
          ),
          DashedAddButton(
            label: l.addChapter,
            onTap: () => _addChapter(context, ref),
          ),
        ],
      ],
    );
  }
}

class _SubjectSummaryCard extends StatelessWidget {
  const _SubjectSummaryCard({required this.summary});

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

    return AtherCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              MasteryNumber(
                value: summary.mastery,
                hasData: hasData,
                color: color,
                style: AppTypography.cardNumber,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l.chaptersMasteredOf(
                    iso(summary.masteredChapterCount),
                    iso(summary.chapterCount),
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
              percentage: summary.mastery,
              hasData: hasData,
            ),
            color: MasteryPalette.fill(context.colors, color),
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.summary});

  final ChapterSummary summary;

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

    return AtherCard(
      onTap: () => context.push(Routes.chapter(summary.chapter.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (summary.isMastered) ...<Widget>[
                const CheckDisc(size: 17, checkSize: 11, strokeWidth: 2.6),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  summary.chapter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AnimatedPercentage(
                value: summary.mastery,
                hasData: hasData,
                color: color,
                style: AppTypography.rowNumberSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MasteryBar(
            fraction: MasteryPalette.barFraction(
              percentage: summary.mastery,
              hasData: hasData,
            ),
            color: MasteryPalette.fill(context.colors, color),
            height: AppSizes.barTrackSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.needsReview
                ? l.chapterNeedsReview
                : l.lessonsExaminedOf(
                    iso(summary.examinedLessonCount),
                    iso(summary.lessonCount),
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(
              size: 13.5,
              weight: AppTypography.medium,
              color: summary.needsReview
                  ? context.colors.wrong
                  : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
