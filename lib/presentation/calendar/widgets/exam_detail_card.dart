import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ather_card.dart';
import '../../../domain/entities/scheduled_exam.dart';
import '../../../domain/services/review_cycle_service.dart';
import '../../providers/app_providers.dart';

/// Detail card for a scheduled exam, showing chapters and decay status.
///
/// When a student taps a scheduled exam on the calendar, this card displays
/// which chapters are included and highlights those with decayed lessons in
/// red. This connects exam preparation directly to the 30-day review cycle:
/// the student sees exactly what needs re-proof before the exam date.
class ExamDetailCard extends ConsumerWidget {
  const ExamDetailCard({
    super.key,
    required this.exam,
  });

  final ScheduledExam exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final snapshot = ref.watch(snapshotValueProvider);
    final now = ref.watch(nowValueProvider);

    final subject = snapshot.subjectById(exam.subjectId);
    if (subject == null) {
      return const SizedBox.shrink();
    }

    final dateFormat = DateFormat.yMMMd(Localizations.localeOf(context).toString());

    return AtherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Exam title
          Text(
            exam.title,
            style: AppTypography.style(
              size: 18,
              weight: AppTypography.semiBold,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),

          // Subject and date
          Row(
            children: <Widget>[
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: context.colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                subject.name ?? '',
                style: AppTypography.style(
                  size: 15,
                  weight: AppTypography.medium,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '•',
                style: AppTypography.style(
                  size: 15,
                  weight: AppTypography.medium,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                dateFormat.format(exam.date),
                style: AppTypography.style(
                  size: 14,
                  weight: AppTypography.medium,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),

          if (exam.notes != null && exam.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              exam.notes!,
              style: AppTypography.style(
                size: 14,
                weight: AppTypography.regular,
                color: context.colors.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          const CardDivider(),
          const SizedBox(height: AppSpacing.md),

          // Chapters section
          Text(
            l.sectionChapters,
            style: AppTypography.style(
              size: 14,
              weight: AppTypography.semiBold,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Chapter list with decay status
          ...exam.chapterIds.map((chapterId) {
            final chapter = snapshot.chapterById(chapterId);
            if (chapter == null) return const SizedBox.shrink();

            final needsReview = ReviewCycleService.chapterNeedsReview(
              snapshot,
              chapterId,
              now,
            );

            // Count decayed lessons in this chapter
            final lessons = snapshot.lessonsIn(chapterId);
            final decayedCount = lessons
                .where((lesson) => ReviewCycleService.needsReview(lesson, now))
                .length;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  // Decay indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: needsReview
                          ? context.colors.wrong
                          : context.colors.right,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      chapter.name,
                      style: AppTypography.style(
                        size: 15,
                        weight: AppTypography.medium,
                        color: needsReview
                            ? context.colors.wrong
                            : context.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (needsReview && decayedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.wrongTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$decayedCount ${l.statNeedsReview.toLowerCase()}',
                        style: AppTypography.style(
                          size: 12,
                          weight: AppTypography.medium,
                          color: context.colors.wrong,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
