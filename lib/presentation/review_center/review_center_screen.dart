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
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_entrance.dart';
import '../../domain/entities/study_snapshot.dart';
import '../../domain/services/review_cycle_service.dart';
import '../common/settings_button.dart';
import '../common/subject_presentation.dart';
import '../providers/app_providers.dart';

/// Everything that needs attention, in the order it needs it: decayed first
/// (most overdue at the top), then genuinely weak, then quietly declining.
///
/// Tapping a row opens the exam wizard directly rather than the lesson screen.
/// There is only one thing to do about a lesson in this list, and making the
/// student pass through a detail screen to reach it is a step that exists for
/// the app's benefit, not theirs.
class ReviewCenterScreen extends ConsumerWidget {
  const ReviewCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final queue = ref.watch(reviewQueueProvider);
    final snapshot = ref.watch(snapshotValueProvider);

    return AtherScreen(
      // A root screen: no back arrow, because there is nothing above it.
      header: AtherHeader(
        title: l.reviewTitle,
        actions: const <Widget>[SettingsButton()],
      ),
      children: <Widget>[
        if (queue.isEmpty)
          // The success shape: green disc, congratulation, and deliberately no
          // button. An empty review queue is a result, not a task.
          EmptyState.success(title: l.reviewEmptyTitle, body: l.reviewEmptyBody)
        else
          // The same entrance as every other list, and nothing extra. It is
          // tempting to make an overdue row pulse or flash red; it is also the
          // fastest way to teach a student to stop looking at this screen.
          for (final (i, item) in queue.indexed) ...<Widget>[
            ListEntrance(
              index: i,
              id: item.lesson.id,
              child: _ReviewRow(item: item, crumb: _crumb(l, snapshot, item)),
            ),
            const SizedBox(height: AppSpacing.listGap),
          ],
      ],
    );
  }
}

/// "المادة · الباب" — where this lesson lives, so a name like "الوحدة الأولى"
/// is not ambiguous across four subjects.
String _crumb(L l, StudySnapshot snapshot, ReviewItem item) {
  final subject = snapshot.subjectById(item.subjectId);
  final chapter = snapshot.chapterById(item.chapterId);
  return <String>[
    if (subject != null) subject.code.label(l),
    if (chapter != null) chapter.name,
  ].join(' · ');
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item, required this.crumb});

  final ReviewItem item;
  final String crumb;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final overdue = item.reason == ReviewReason.overdue;
    // Everything in this queue has been examined -- an unexamined lesson has no
    // review clock and cannot appear here -- so `hasData` is unconditionally
    // true. It used to be `mastery > 0 || !overdue`, which handed the grey
    // "never measured" colour to a lesson that had genuinely scored 0% and gone
    // overdue, while the number beside it still read "0%". The colour said one
    // thing and the figure said another.
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: item.mastery,
      hasData: true,
      needsReview: overdue,
    );

    final reason = switch (item.reason) {
      ReviewReason.overdue => l.overdueByDays(iso(item.daysOverdue)),
      ReviewReason.lowMastery => l.reviewReasonWeak,
      ReviewReason.declining => l.reviewReasonDeclining,
    };

    return AtherCard(
      onTap: () => context.push(Routes.exam(item.lesson.id, fromLesson: false)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.lesson.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowTitleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  crumb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.small,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.statusLine.copyWith(
                    // Declining is grey: it is a warning, not a failure, and
                    // colouring it red would make three different situations
                    // look like one emergency.
                    color: item.reason == ReviewReason.declining
                        ? context.colors.textSecondary
                        : context.colors.wrong,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AnimatedPercentage(
            value: item.mastery,
            hasData: true,
            color: color,
            style: AppTypography.rowNumberSmall,
          ),
          const SizedBox(width: AppSpacing.md),
          PillButton(
            label: l.actionExam,
            onTap: () =>
                context.push(Routes.exam(item.lesson.id, fromLesson: false)),
          ),
        ],
      ),
    );
  }
}
