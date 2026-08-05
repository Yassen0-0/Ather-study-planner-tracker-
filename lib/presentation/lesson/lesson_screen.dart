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
import '../../core/widgets/ather_controls.dart';
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/mastery_bar.dart';
import '../../core/widgets/status_chip.dart';
import '../../domain/entities/exam_entry.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/mastery.dart';
import '../../domain/services/summaries.dart';
import '../common/prompts.dart';
import '../common/subject_presentation.dart';
import '../providers/app_providers.dart';
import '../providers/summary_providers.dart';

/// One lesson: what it is worth, what the student has done, and the one button
/// that can change the number.
///
/// The order of the cards is the argument the product makes. Mastery first,
/// because it is the only thing that counts. Study steps next, plainly labelled
/// as steps. Homework third and visually demoted -- a grey card with a standing
/// disclaimer -- because a good homework score is the single most tempting
/// thing to mistake for understanding.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});

  final int lessonId;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    LessonSummary summary,
  ) async {
    final l = L.of(context);
    await showEditSheet(
      context,
      title: summary.lesson.name,
      renameLabel: l.renameLesson,
      deleteLabel: l.deleteLesson,
      onRename: () async {
        final name = await showNamePrompt(
          context,
          title: l.renameLesson,
          hint: l.lessonNameHint,
          initialValue: summary.lesson.name,
        );
        if (name == null) return;
        await ref
            .read(studyRepositoryProvider)
            .renameLesson(lessonId: lessonId, name: name);
      },
      onDelete: () async {
        final confirmed = await confirmDestructive(
          context,
          title: l.deleteLesson,
          message: l.deleteLessonConfirm,
        );
        if (!confirmed) return;
        await ref.read(studyRepositoryProvider).deleteLesson(lessonId);
        if (context.mounted) context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final summary = ref.watch(lessonSummaryProvider(lessonId));

    if (summary == null) {
      return AtherScreen(
        header: AtherHeader(title: '', onBack: () => context.pop()),
        children: const <Widget>[],
      );
    }

    final snapshot = ref.watch(snapshotValueProvider);
    final chapter = snapshot.chapterById(summary.lesson.chapterId);
    final subject = chapter == null
        ? null
        : snapshot.subjectById(chapter.subjectId);
    final exams = snapshot.examsFor(lessonId);

    final subtitle = <String>[
      if (subject != null) subject.code.label(l),
      if (chapter != null) chapter.name,
    ].join(' · ');

    return AtherScreen(
      header: AtherHeader(
        title: summary.lesson.name,
        subtitle: subtitle.isEmpty ? null : subtitle,
        onBack: () => context.pop(),
        actions: <Widget>[
          CircleHeaderButton(
            onTap: () => _edit(context, ref, summary),
            child: const AtherIcon(AtherGlyph.edit, size: 17),
          ),
        ],
      ),
      bottom: _ExamCta(summary: summary),
      children: <Widget>[
        _MasteryCard(summary: summary),
        const SizedBox(height: AppSpacing.md),
        _ChecklistCard(summary: summary),
        const SizedBox(height: AppSpacing.md),
        _HomeworkCard(summary: summary),
        const SizedBox(height: AppSpacing.md),
        _HistoryCard(exams: exams),
      ],
    );
  }
}

/// The pinned action. Its wording and colour are the lesson's state in one
/// control: no exam yet, due a normal exam, or overdue and owed a review exam.
class _ExamCta extends StatelessWidget {
  const _ExamCta({required this.summary});

  final LessonSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.sm,
        AppSpacing.pageMargin,
        AppSpacing.md,
      ),
      child: PrimaryButton(
        label: !summary.hasExam
            ? l.examStart
            : summary.needsReview
            ? l.examRecordReview
            : l.examRecordResult,
        tone: summary.needsReview
            ? PrimaryButtonTone.wrong
            : PrimaryButtonTone.black,
        onTap: () =>
            context.push(Routes.exam(summary.lesson.id, fromLesson: true)),
      ),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard({required this.summary});

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

    final String chip;
    if (!summary.hasExam) {
      chip = l.noExamShort;
    } else if (summary.needsReview) {
      chip = l.overdueByDays(iso(summary.daysOverdue));
    } else {
      chip = l.dueInDays(iso(summary.daysUntilDue ?? 0));
    }

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
                hasData: summary.hasExam,
                color: color,
                style: AppTypography.lessonNumber,
              ),
              const SizedBox(width: AppSpacing.md),
              // Flexible rather than pinned to the end: at large text sizes the
              // chip has to give ground to the number, not push it off the card.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: StatusChip(label: chip, overdue: summary.needsReview),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          MasteryBar(
            fraction: MasteryPalette.barFraction(
              percentage: summary.mastery,
              hasData: summary.hasExam,
            ),
            color: color,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // Spelling out the 70/30 weighting is deliberate: a number the
            // student cannot explain is a number they will not trust.
            summary.hasExam
                ? l.masteryCaptionWithExams(iso('(70%)'), iso('(30%)'))
                : l.masteryCaptionNoExams,
            style: AppTypography.style(
              size: 13.5,
              weight: AppTypography.medium,
              height: 1.55,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends ConsumerWidget {
  const _ChecklistCard({required this.summary});

  final LessonSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final checklist = summary.lesson.checklist;

    final items =
        <({String label, bool checked, LessonChecklist Function() next})>[
          (
            label: l.checklistWatched,
            checked: checklist.watchedLesson,
            next: () =>
                checklist.copyWith(watchedLesson: !checklist.watchedLesson),
          ),
          (
            label: l.checklistReadNotes,
            checked: checklist.readNotes,
            next: () => checklist.copyWith(readNotes: !checklist.readNotes),
          ),
          (
            label: l.checklistDidHomework,
            checked: checklist.didHomework,
            next: () => checklist.copyWith(didHomework: !checklist.didHomework),
          ),
          (
            label: l.checklistDidExam,
            checked: checklist.didExam,
            next: () => checklist.copyWith(didExam: !checklist.didExam),
          ),
          (
            label: l.checklistReviewedNotes,
            checked: checklist.reviewedNotes,
            next: () =>
                checklist.copyWith(reviewedNotes: !checklist.reviewedNotes),
          ),
        ];

    return AtherCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(l.checklistTitle, style: AppTypography.cardTitle),
              ),
              Text(
                fraction(checklist.completedCount, LessonChecklist.totalCount),
                style: AppTypography.style(
                  size: 14,
                  weight: AppTypography.bold,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items) ...<Widget>[
            const CardDivider(),
            AtherCheckbox(
              checked: item.checked,
              label: item.label,
              onTap: () => ref
                  .read(studyRepositoryProvider)
                  .updateChecklist(
                    lessonId: summary.lesson.id,
                    checklist: item.next(),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeworkCard extends ConsumerWidget {
  const _HomeworkCard({required this.summary});

  final LessonSummary summary;

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final saved = await showAtherSheet<bool>(
      context: context,
      builder: (context) => _HomeworkSheet(lessonId: summary.lesson.id),
    );
    if (saved == true && context.mounted) {
      showAtherToast(context, L.of(context).toastHomeworkSaved);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final homework = summary.latestHomeworkPercentage;

    final String line;
    final Color lineColor;
    if (homework == null) {
      line = l.homeworkNone;
      lineColor = context.colors.textSecondary;
    } else if (homework < kHomeworkReadinessThreshold) {
      line = l.homeworkNotReady;
      lineColor = context.colors.wrong;
    } else {
      line = l.homeworkReady;
      lineColor = context.colors.right;
    }

    return AtherCard.muted(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.homeworkTitle,
                  style: AppTypography.style(
                    size: 15,
                    weight: AppTypography.bold,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              Text(
                // Grey even when the score is excellent. Homework is not
                // evidence, so it never earns the green.
                homework == null ? '—' : percent(homework),
                style: AppTypography.style(
                  size: 17,
                  weight: AppTypography.bold,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            line,
            style: AppTypography.style(
              size: 13.5,
              weight: AppTypography.semiBold,
              color: lineColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l.homeworkNote, style: context.text.micro),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: QuietPillButton(
              label: l.homeworkAdd,
              onTap: () => _openSheet(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeworkSheet extends ConsumerStatefulWidget {
  const _HomeworkSheet({required this.lessonId});

  final int lessonId;

  @override
  ConsumerState<_HomeworkSheet> createState() => _HomeworkSheetState();
}

class _HomeworkSheetState extends ConsumerState<_HomeworkSheet> {
  final TextEditingController _score = TextEditingController();
  final TextEditingController _max = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _score.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final score = int.tryParse(_score.text);
    final max = int.tryParse(_max.text);

    // Validated here rather than by disabling the button: a student who typed
    // 12 out of 10 needs to be told why, not left tapping a dead control.
    if (score == null || max == null || max <= 0 || score < 0 || score > max) {
      setState(() => _showError = true);
      return;
    }

    await ref
        .read(studyRepositoryProvider)
        .recordHomework(
          lessonId: widget.lessonId,
          score: score,
          maxScore: max,
          at: ref.read(clockProvider).now(),
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherSheetBody(
      title: l.homeworkAdd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _Field(
                  label: l.homeworkScore,
                  controller: _score,
                  autofocus: true,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Field(label: l.homeworkMax, controller: _max),
              ),
            ],
          ),
          if (_showError) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ErrorBanner(message: l.homeworkInvalid),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(label: l.commonSave, onTap: _save),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.style(
            size: 12.5,
            weight: AppTypography.semiBold,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        NumberField(
          controller: controller,
          height: AppSizes.inputTall,
          autofocus: autofocus,
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.exams});

  final List<ExamEntry> exams;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.examHistory, style: AppTypography.cardTitle),
          if (exams.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l.examNoHistory, style: context.text.secondary),
            )
          else
            for (final exam in exams) ...<Widget>[
              const SizedBox(height: 4),
              const CardDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: MasteryPalette.ofScore(
                          context.colors,
                          exam.percentage,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        dateLabel(exam.createdAt),
                        style: context.text.secondary,
                      ),
                    ),
                    if (exam.isReviewExam) ...<Widget>[
                      MiniBadge(label: l.examReviewBadge),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      percent(exam.percentage),
                      style: AppTypography.style(
                        size: 16,
                        weight: AppTypography.bold,
                        color: MasteryPalette.ofScore(
                          context.colors,
                          exam.percentage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
