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
import '../../core/widgets/pressable.dart';
import '../../core/widgets/status_chip.dart';
import '../../domain/entities/exam_entry.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/mastery.dart';
import '../../domain/services/summaries.dart';
import '../common/prompts.dart';
import '../common/subject_presentation.dart';
import '../common/write_guard.dart';
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
        if (name == null || !context.mounted) return;
        await runWrite(
          context,
          () => ref
              .read(studyRepositoryProvider)
              .renameLesson(lessonId: lessonId, name: name),
        );
      },
      onDelete: () async {
        final confirmed = await confirmDestructive(
          context,
          title: l.deleteLesson,
          message: l.deleteLessonConfirm,
        );
        if (!confirmed || !context.mounted) return;
        final ok = await runWrite(
          context,
          () => ref.read(studyRepositoryProvider).deleteLesson(lessonId),
        );
        // Only leave if the lesson actually went. Popping on a failed delete
        // lands the student on a list that still contains it.
        if (ok && context.mounted) context.pop();
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
      if (subject != null) subject.label(l),
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
            semanticLabel: l.commonEdit,
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
        AppSpacing.md,
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
            : PrimaryButtonTone.primary,
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
      chip = l.overdueByDays(summary.daysOverdue);
    } else {
      chip = l.dueInDays(summary.daysUntilDue ?? 0);
    }

    return AtherCard(
      padding: AppSpacing.cardPadding,
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
          const SizedBox(height: AppSpacing.xl),
          MasteryBar(
            fraction: MasteryPalette.barFraction(
              percentage: summary.mastery,
              hasData: summary.hasExam,
            ),
            color: MasteryPalette.fill(context.colors, color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            // Spelling out the 70/30 weighting is deliberate: a number the
            // student cannot explain is a number they will not trust.
            summary.hasExam
                ? l.masteryCaptionWithExams(iso('(70%)'), iso('(30%)'))
                : l.masteryCaptionNoExams,
            style: context.text.sublabel,
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
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(l.checklistTitle, style: AppTypography.cardTitle),
              ),
              // Five of five on an unexamined lesson swaps the counter for the
              // one sentence the moment earns, pointing at the exam CTA pinned
              // below. With exam evidence the count stays a count.
              if (checklist.isComplete && !summary.hasExam)
                Flexible(
                  child: Text(
                    l.checklistAllDone,
                    textAlign: TextAlign.end,
                    style: AppTypography.controlLabel.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                )
              else
                Text(
                  fraction(
                    checklist.completedCount,
                    LessonChecklist.totalCount,
                  ),
                  style: AppTypography.controlLabel.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.textGap),
          for (final item in items) ...<Widget>[
            const CardDivider(),
            AtherCheckbox(
              checked: item.checked,
              label: item.label,
              onTap: () => runWrite(
                context,
                () => ref
                    .read(studyRepositoryProvider)
                    .updateChecklist(
                      lessonId: summary.lesson.id,
                      checklist: item.next(),
                    ),
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

    // The verdict is the domain's, not a raw threshold here: when the newest
    // homework predates the lesson's first exam it has been outvoted by newer
    // evidence and issues no verdict at all -- silence, not a green claim from
    // the same stale document. The dated percentage in the header stays as the
    // factual record either way.
    Widget? verdict;
    if (homework == null) {
      verdict = Text(
        l.homeworkNone,
        style: AppTypography.statusLine.copyWith(
          color: context.colors.textSecondary,
        ),
      );
    } else if (summary.homeworkSuggestsMoreStudy) {
      verdict = Text(
        l.homeworkNotReady,
        style: AppTypography.statusLine.copyWith(color: context.colors.wrong),
      );
    } else if (homework >= kHomeworkReadinessThreshold) {
      verdict = Text(
        l.homeworkReady,
        style: AppTypography.statusLine.copyWith(
          color: context.colors.rightText,
        ),
      );
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
                  style: AppTypography.cardTitle.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              Text(
                // Grey even when the score is excellent. Homework is not
                // evidence, so it never earns the green.
                homework == null ? '—' : percent(homework),
                style: AppTypography.rowTitle.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              // The score's own date, so a month-old number reads as one.
              if (summary.latestHomeworkAt != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    l.lastHomeworkDated(dateLabel(summary.latestHomeworkAt!)),
                    style: context.text.secondary,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.textGap),
          if (verdict != null) ...<Widget>[
            verdict,
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(l.homeworkNote, style: context.text.micro),
          const SizedBox(height: AppSpacing.md),
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
  bool _saving = false;

  @override
  void dispose() {
    _score.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final score = int.tryParse(_score.text);
    final max = int.tryParse(_max.text);

    // Validated here rather than by disabling the button: a student who typed
    // 12 out of 10 needs to be told why, not left tapping a dead control.
    if (score == null || max == null || max <= 0 || score < 0 || score > max) {
      setState(() => _showError = true);
      return;
    }

    setState(() => _saving = true);
    final ok = await runWrite(
      context,
      () => ref
          .read(studyRepositoryProvider)
          .recordHomework(
            lessonId: widget.lessonId,
            score: score,
            maxScore: max,
            at: ref.read(clockProvider).now(),
          ),
    );
    if (!mounted) return;
    // Staying open on a failure keeps the two numbers the student typed, which
    // is the only place they exist.
    if (!ok) {
      setState(() => _saving = false);
      return;
    }
    Navigator.of(context).pop(true);
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
          PrimaryButton(label: l.commonSave, busy: _saving, onTap: _save),
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
        Text(label, style: context.text.fieldLabel),
        const SizedBox(height: AppSpacing.textGap),
        NumberField(
          controller: controller,
          height: AppSizes.inputTall,
          autofocus: autofocus,
        ),
      ],
    );
  }
}

/// The lesson's evidence, and the only place it can be taken back.
///
/// A mistyped exam used to be permanent: `deleteExam` existed in the repository
/// and no screen ever called it, so a student who entered 3 out of 30 as 30 out
/// of 3 carried a wrong mastery figure — and a review clock they had not earned
/// — for the rest of the year. In an app whose entire claim is that the number
/// is trustworthy, an uncorrectable number is the worst possible defect.
///
/// A tap opens the same `confirmDestructive` sheet as every other deletion in
/// the app rather than putting a control on the row: the design's rows are
/// information (see `showEditSheet`), so the row keeps its shape and the
/// confirmation carries the weight.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.exams});

  final List<ExamEntry> exams;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ExamEntry exam,
  ) async {
    final l = L.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final direction = Directionality.of(context);
    final message = l.toastExamDeleted;

    final confirmed = await confirmDestructive(
      context,
      title: l.examDelete,
      message: l.examDeleteConfirm,
    );
    if (!confirmed) return;

    if (!context.mounted) return;
    final ok = await runWrite(
      context,
      () => ref.read(studyRepositoryProvider).deleteExam(exam.id),
    );
    if (ok && overlay != null) showAtherToastOn(overlay, direction, message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.examHistory, style: AppTypography.cardTitle),
          if (exams.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l.examNoHistory, style: context.text.secondary),
            )
          else ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            for (final exam in exams) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              const CardDivider(),
              Pressable(
                onTap: () => _delete(context, ref, exam),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          dateLabel(exam.createdAt),
                          style: context.text.secondary,
                        ),
                      ),
                      if (exam.isReviewExam) ...<Widget>[
                        MiniBadge(label: l.examReviewBadge),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Text(
                        percent(exam.percentage),
                        style: AppTypography.rowNumberCompact.copyWith(
                          color: MasteryPalette.ofScore(
                            context.colors,
                            exam.percentage,
                          ),
                        ),
                      ),
                      // Carries what a line of prose used to carry: the row
                      // removes the exam. A sentence reading "tap an exam to
                      // remove it" explained a control to a student looking
                      // straight at it; the mark on the row is the control
                      // saying so itself.
                      const SizedBox(width: AppSpacing.md),
                      AtherIcon(
                        AtherGlyph.close,
                        size: 14,
                        color: context.colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
