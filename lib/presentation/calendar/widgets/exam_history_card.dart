import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/l10n/formatting.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/mastery_palette.dart';
import '../../../core/widgets/ather_card.dart';
import '../../../core/widgets/mastery_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../domain/entities/exam_entry.dart';
import '../../../domain/entities/study_snapshot.dart';
import '../../common/subject_presentation.dart';

/// Displays detailed information about a past exam entry.
///
/// Shows the lesson name, subject/chapter breadcrumb, exam percentage with
/// mastery color-coding, review exam badge if applicable, and a breakdown
/// of question groups. Tapping the card navigates to the lesson screen.
///
/// This is the full-detail version used in the calendar timeline, as opposed
/// to the compact exam list in [LessonScreen._HistoryCard].
class ExamHistoryCard extends StatelessWidget {
  const ExamHistoryCard({
    super.key,
    required this.exam,
    required this.snapshot,
  });

  final ExamEntry exam;
  final StudySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    // Get lesson details for breadcrumb
    final lesson = snapshot.lessonById(exam.lessonId);
    if (lesson == null) return const SizedBox.shrink();

    final chapter = snapshot.chapterById(lesson.chapterId);
    final subject = chapter == null ? null : snapshot.subjectById(chapter.subjectId);

    final breadcrumb = <String>[
      if (subject != null) subject.label(l),
      if (chapter != null) chapter.name,
    ].join(' · ');

    final color = MasteryPalette.ofScore(context.colors, exam.percentage);

    return Pressable(
      onTap: () => context.push(Routes.lesson(exam.lessonId)),
      child: AtherCard(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header: lesson name and percentage
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        lesson.name,
                        style: AppTypography.cardTitle,
                      ),
                      if (breadcrumb.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          breadcrumb,
                          style: context.text.sublabel,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      percent(exam.percentage),
                      style: AppTypography.style(
                        size: 24,
                        weight: AppTypography.semiBold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      dateLabel(exam.createdAt),
                      style: context.text.micro,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Mastery bar
            MasteryBar(
              fraction: exam.percentage / 100,
              color: MasteryPalette.fill(context.colors, color),
            ),

            const SizedBox(height: AppSpacing.md),

            // Review badge and total points
            Row(
              children: <Widget>[
                if (exam.isReviewExam) ...<Widget>[
                  StatusChip(label: l.examReviewBadge, overdue: false),
                  const SizedBox(width: AppSpacing.md),
                ],
                Text(
                  '${exam.correctPoints} / ${exam.totalPossiblePoints} ${l.examPoints}',
                  style: context.text.secondary,
                ),
              ],
            ),

            // Question groups breakdown
            if (exam.groups.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              CardDivider(),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.examQuestionGroups,
                style: AppTypography.controlLabel.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final group in exam.groups) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                _QuestionGroupRow(group: group),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A single question group row showing points per question, count, and correct count.
class _QuestionGroupRow extends StatelessWidget {
  const _QuestionGroupRow({required this.group});

  final ExamQuestionGroup group;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    // Format: "5 questions × 2 pts = 10 pts (8 correct)"
    final label = l.examGroupFormat(
      group.questionCount.toString(),
      group.pointsPerQuestion.toString(),
      group.possiblePoints.toString(),
      group.correctCount.toString(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: context.text.secondary.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
