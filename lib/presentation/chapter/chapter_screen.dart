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
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/celebration_overlay.dart';
import '../../core/widgets/collapsing_removal.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/mastery_bar.dart';
import '../../core/widgets/pressable.dart';
import '../../domain/entities/mastery.dart';
import '../../domain/services/review_cycle_service.dart';
import '../../domain/services/summaries.dart';
import '../common/prompts.dart';
import '../common/subject_presentation.dart';
import '../common/write_guard.dart';
import '../providers/app_providers.dart';
import '../providers/summary_providers.dart';

/// One chapter: its figure, the mastery gate, and its lessons.
///
/// The gate button is the screen's reason to exist. It is **always tappable**,
/// in all three of its states -- a grey button that does nothing when pressed
/// teaches the student nothing, so the un-earned state opens a sheet naming
/// exactly which lessons are holding the chapter back.
class ChapterScreen extends ConsumerWidget {
  const ChapterScreen({super.key, required this.chapterId});

  final int chapterId;

  Future<void> _addLesson(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final name = await showNamePrompt(
      context,
      title: l.addLesson,
      hint: l.lessonNameHint,
    );
    if (name == null || !context.mounted) return;
    await runWrite(
      context,
      () => ref
          .read(studyRepositoryProvider)
          .createLesson(
            chapterId: chapterId,
            name: name,
            at: ref.read(clockProvider).now(),
          ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ChapterSummary summary,
  ) async {
    final l = L.of(context);
    await showEditSheet(
      context,
      title: summary.chapter.name,
      renameLabel: l.renameChapter,
      deleteLabel: l.deleteChapter,
      onRename: () async {
        final name = await showNamePrompt(
          context,
          title: l.renameChapter,
          hint: l.chapterNameHint,
          initialValue: summary.chapter.name,
        );
        if (name == null || !context.mounted) return;
        await runWrite(
          context,
          () => ref
              .read(studyRepositoryProvider)
              .renameChapter(chapterId: chapterId, name: name),
        );
      },
      onDelete: () async {
        final confirmed = await confirmDestructive(
          context,
          title: l.deleteChapter,
          message: l.deleteChapterConfirm,
        );
        if (!confirmed || !context.mounted) return;
        final ok = await runWrite(
          context,
          () => ref.read(studyRepositoryProvider).deleteChapter(chapterId),
        );
        if (ok && context.mounted) context.pop();
      },
    );
  }

  Future<void> _onGateTap(
    BuildContext context,
    WidgetRef ref,
    ChapterSummary summary,
  ) async {
    if (summary.isMastered) {
      context.push(Routes.chapterReport(chapterId));
      return;
    }

    if (!summary.canMaster) {
      await _showNotReadySheet(context, ref);
      return;
    }

    // Persisted before the celebration, not after: if the app is killed while
    // the overlay is up, the student still mastered the chapter. And if the
    // write fails there is nothing to celebrate -- a green screen over a chapter
    // the database never closed out is the worst possible lie to tell here.
    final ok = await runWrite(
      context,
      () => ref
          .read(studyRepositoryProvider)
          .markChapterMastered(
            chapterId: chapterId,
            at: ref.read(clockProvider).now(),
          ),
    );
    if (!ok || !context.mounted) return;
    await _celebrate(context, summary.mastery);
    if (!context.mounted) return;
    context.push(Routes.chapterReport(chapterId));
  }

  Future<void> _celebrate(BuildContext context, double percentage) {
    final l = L.of(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: context.colors.card,
      pageBuilder: (dialogContext, _, _) => CelebrationOverlay(
        title: l.celebrationTitle,
        body: l.celebrationBody,
        hint: l.celebrationHint,
        percentage: percentage,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _showNotReadySheet(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final blockers = ReviewCycleService.chapterBlockers(
      ref.read(snapshotValueProvider),
      chapterId,
    );

    return showAtherSheet<void>(
      context: context,
      builder: (sheetContext) => AtherSheetBody(
        title: l.notReadyTitle,
        // The threshold is passed in rather than baked into the sentence:
        // a bare "70%" inside an Arabic string renders as "%70".
        body: l.notReadyBody(percent(kChapterMasteryThreshold)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // A chapter with no lessons at all has no blocking lesson to
              // name, so the sheet says the real reason instead of showing an
              // empty list under an explanation that does not apply.
              if (blockers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(l.noLessonsYet, style: context.text.secondary),
                ),
              for (final blocker in blockers)
                Pressable(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push(Routes.lesson(blocker.lesson.id));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.colors.divider),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            blocker.lesson.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.listTitle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          blocker.hasExam
                              ? percent(blocker.mastery)
                              : l.noExamShort,
                          style: AppTypography.controlLabel.copyWith(
                            color: blocker.hasExam
                                ? MasteryPalette.ofScore(
                                    context.colors,
                                    blocker.mastery,
                                  )
                                : context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AtherIcon(
                          AtherGlyph.chevron,
                          size: 16,
                          color: context.colors.textNoData,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
    final subject = snapshot.subjectById(summary.chapter.subjectId);

    return AtherScreen(
      header: AtherHeader(
        title: summary.chapter.name,
        subtitle: subject?.code.label(l),
        onBack: () => context.pop(),
        actions: <Widget>[
          CircleHeaderButton(
            onTap: () => _edit(context, ref, summary),
            semanticLabel: l.commonEdit,
            child: const AtherIcon(AtherGlyph.edit, size: 17),
          ),
        ],
      ),
      children: <Widget>[
        _ChapterSummaryCard(summary: summary),
        const SizedBox(height: AppSpacing.md),
        _GateButton(
          summary: summary,
          onTap: () => _onGateTap(context, ref, summary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (summary.lessons.isEmpty)
          EmptyState(
            title: l.noLessonsYet,
            action: DashedAddButton(
              label: l.addLesson,
              onTap: () => _addLesson(context, ref),
            ),
          )
        else ...<Widget>[
          SectionTitle(l.sectionLessons),
          const SizedBox(height: AppSpacing.md),
          CollapsingList<LessonSummary>(
            items: summary.lessons,
            idOf: (l) => l.lesson.id,
            itemBuilder: (context, l) => _LessonRow(summary: l),
          ),
          DashedAddButton(
            label: l.addLesson,
            onTap: () => _addLesson(context, ref),
          ),
        ],
      ],
    );
  }
}

class _ChapterSummaryCard extends StatelessWidget {
  const _ChapterSummaryCard({required this.summary});

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
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Baseline rather than bottom, for the reason given on the dashboard's
          // overall card: the sentence beside the number wraps, and bottom
          // alignment lines up the wrong one of its two lines.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
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
                  l.lessonsExaminedOf(
                    iso(summary.examinedLessonCount),
                    iso(summary.lessonCount),
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
              percentage: summary.mastery,
              hasData: hasData,
            ),
            color: MasteryPalette.fill(context.colors, color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text.rich(
            TextSpan(
              text: '${l.averageExamScore}: ',
              children: <InlineSpan>[
                TextSpan(
                  text: hasData ? percent(summary.averageExamScore) : '—',
                ),
              ],
            ),
            style: context.text.secondary,
          ),
          if (summary.chapter.masteredAt != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                const CheckDisc(size: 15, checkSize: 10, strokeWidth: 2.8),
                const SizedBox(width: AppSpacing.textGap),
                Expanded(
                  child: Text(
                    l.chapterMasteredAt(dateLabel(summary.chapter.masteredAt!)),
                    style: AppTypography.statusLine.copyWith(
                      color: context.colors.rightText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GateButton extends StatelessWidget {
  const _GateButton({required this.summary, required this.onTap});

  final ChapterSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    final (String label, PrimaryButtonTone tone) = switch (summary) {
      _ when summary.isMastered => (
        l.viewChapterReport,
        PrimaryButtonTone.secondary,
      ),
      _ when summary.canMaster => (l.masterChapter, PrimaryButtonTone.right),
      _ => (l.notReadyGate, PrimaryButtonTone.unearned),
    };

    return PrimaryButton(label: label, tone: tone, onTap: onTap);
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.summary});

  final LessonSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: summary.mastery,
      hasData: summary.hasExam,
      needsReview: summary.needsReview,
    );

    final String status;
    if (!summary.hasExam) {
      status = l.lessonNoExamYet;
    } else if (summary.needsReview) {
      status = l.overdueByDays(iso(summary.daysOverdue));
    } else {
      status = l.dueInDaysLong(iso(summary.daysUntilDue ?? 0));
    }

    return AtherCard(
      onTap: () => context.push(Routes.lesson(summary.lesson.id)),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  summary.lesson.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowTitleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  status,
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
          const SizedBox(width: AppSpacing.xs),
          AnimatedPercentage(
            value: summary.mastery,
            hasData: summary.hasExam,
            color: color,
            style: AppTypography.rowNumberSmall,
          ),
        ],
      ),
    );
  }
}
