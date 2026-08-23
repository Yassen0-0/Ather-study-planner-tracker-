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
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_entrance.dart';
import '../../core/widgets/status_chip.dart';
import '../../domain/entities/study_snapshot.dart';
import '../../domain/entities/subject.dart';
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
///
/// One action, one target: because the whole card is that route, no row also
/// carries an "امتحن" button repeating it (06-design #10) -- the dashboard's
/// silent "التالي" card is this same rule honoured from the other side.
class ReviewCenterScreen extends ConsumerStatefulWidget {
  const ReviewCenterScreen({super.key});

  @override
  ConsumerState<ReviewCenterScreen> createState() =>
      _ReviewCenterScreenState();
}

class _ReviewCenterScreenState extends ConsumerState<ReviewCenterScreen> {
  /// Null means "كل المواد", read exactly as the analytics filter reads it.
  int? _subjectFilter;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final queue = ref.watch(reviewQueueProvider);
    final snapshot = ref.watch(snapshotValueProvider);

    // Narrowing happens here, not in the provider: the tab badge, the
    // notifications and every other reader of the queue must keep seeing all
    // of it. A filter the student chose for one evening is not data.
    final visible = _subjectFilter == null
        ? queue
        : <ReviewItem>[
            for (final item in queue)
              if (item.subjectId == _subjectFilter) item,
          ];

    return AtherScreen(
      // A root screen: no back arrow, because there is nothing above it.
      header: AtherHeader(
        title: l.reviewTitle,
        actions: const <Widget>[SettingsButton()],
      ),
      children: <Widget>[
        if (queue.isEmpty)
          // The success shape: green disc, congratulation, and deliberately no
          // button. An empty review queue is a result, not a task -- and a
          // "0 درس" counter above it would be counting a victory.
          EmptyState.success(title: l.reviewEmptyTitle, body: l.reviewEmptyBody)
        else ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.opticalInset,
            ),
            child: Text(
              l.reviewWaitingHeader(iso(queue.length)),
              style: context.text.groupHeading,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SubjectChips(
            queue: queue,
            snapshot: snapshot,
            selected: _subjectFilter,
            onSelect: (id) => setState(() => _subjectFilter = id),
          ),
          const SizedBox(height: AppSpacing.xl),
          // The same entrance as every other list, and nothing extra. It is
          // tempting to make an overdue row pulse or flash red; it is also the
          // fastest way to teach a student to stop looking at this screen.
          for (final (i, item) in visible.indexed) ...<Widget>[
            ListEntrance(
              index: i,
              id: item.lesson.id,
              child: _ReviewRow(item: item, crumb: _crumb(l, snapshot, item)),
            ),
            const SizedBox(height: AppSpacing.listGap),
          ],
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
    if (subject != null) subject.label(l),
    if (chapter != null) chapter.name,
  ].join(' · ');
}

/// The analytics screen's filter row, given one job here: on the night before
/// a subject's exam, cut twelve red rows down to that subject.
///
/// A chip exists only for a subject that actually has something waiting --
/// names come from the snapshot via the `subjectId` each [ReviewItem] carries
/// -- so picking one can never leave an empty list behind, and a subject with
/// nothing to review never advertises itself.
class _SubjectChips extends StatelessWidget {
  const _SubjectChips({
    required this.queue,
    required this.snapshot,
    required this.selected,
    required this.onSelect,
  });

  final List<ReviewItem> queue;
  final StudySnapshot snapshot;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    final waitingIds = <int>{for (final item in queue) item.subjectId};
    final subjects = <Subject>[
      // Dashboard order, not queue order: the chips should not reshuffle as
      // lessons clear, for the same reason the tabs never do.
      for (final subject in snapshot.activeSubjects)
        if (waitingIds.contains(subject.id)) subject,
    ];

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
              label: subject.label(l),
              selected: selected == subject.id,
              onTap: () => onSelect(subject.id),
            ),
          ],
        ],
      ),
    );
  }
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
        ],
      ),
    );
  }
}
