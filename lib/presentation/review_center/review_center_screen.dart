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
    // N7/C6: the success empty state below is a claim ("you are on top of
    // it") the screen may only make once the read has settled and not failed;
    // otherwise a failing disk congratulated the student over an intact
    // record.
    final read = ref.watch(snapshotReadProvider);
    // Watched, not read once: the radar shifts a column every midnight the
    // moment `nowProvider` emits, without waiting for the student to reopen
    // the screen.
    final now = ref.watch(nowValueProvider);

    // Narrowing happens here, not in the provider: the tab badge, the
    // notifications and every other reader of the queue must keep seeing all
    // of it. A filter the student chose for one evening is not data.
    final visible = _subjectFilter == null
        ? queue
        : <ReviewItem>[
            for (final item in queue)
              if (item.subjectId == _subjectFilter) item,
          ];

    // Whole-horizon by construction -- the same unfiltered view as the counter
    // above it. Narrowing the columns to a chip would redraw the future to fit
    // a filter that exists for one evening's list.
    final dueByDay = ReviewCycleService.upcomingDueDistribution(snapshot, now);

    return AtherScreen(
      // A root screen: no back arrow, because there is nothing above it.
      header: AtherHeader(
        title: l.reviewTitle,
        actions: const <Widget>[SettingsButton()],
      ),
      children: <Widget>[
        if (read is SnapshotFailed)
          // Text only, reusing the app's existing generic failure string --
          // same restraint as the dashboard's failed-read card (N7/C6).
          EmptyState(title: l.commonSomethingWentWrong)
        else if (read is SnapshotLoading)
          // Settle-gating: no emission yet, so neither the queue's rows nor
          // its celebration may speak for a record not read.
          const SizedBox.shrink()
        else if (queue.isEmpty)
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
          // The collapse radar (audit P5-03): the queue's next two weeks as
          // fourteen columns, nearest day leading. Silent when there is
          // nothing ahead to plot -- a chart of empty days would be noise
          // standing where information was promised.
          if (dueByDay.isNotEmpty) ...<Widget>[
            _DueRadar(counts: dueByDay),
            const SizedBox(height: AppSpacing.md),
          ],
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

/// The collapse radar's fourteen thin columns (audit P5-03): one per day, the
/// count of lessons falling due above each, the day number below -- numbers
/// only, because a legend would be one more sentence this screen does not
/// need.
///
/// The nearest day leads, which in RTL reading order is the right edge; that
/// is pinned here rather than inherited so the shape cannot silently flip if
/// the ambient direction ever changes.
class _DueRadar extends StatelessWidget {
  const _DueRadar({required this.counts});

  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    var maxCount = 0;
    for (final count in counts.values) {
      if (count > maxCount) maxCount = count;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.opticalInset,
      ),
      child: SizedBox(
        height: 80,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: <Widget>[
              for (
                var day = 1;
                day <= ReviewCycleService.kRadarWindowDays;
                day++
              )
                Expanded(
                  child: _DueRadarColumn(
                    day: day,
                    count: counts[day] ?? 0,
                    maxCount: maxCount,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The analytics column's anatomy, miniaturised: number over a fill over an
/// axis label, with [MasteryPalette.barFraction] as the single visibility
/// floor so a lonely 1 stays findable next to a 4-lesson Thursday without
/// this chart growing its own clamping rule (06-design #2).
class _DueRadarColumn extends StatelessWidget {
  const _DueRadarColumn({
    required this.day,
    required this.count,
    required this.maxCount,
  });

  final int day;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    // Relative fill, expressed as a percentage of the tallest day.
    final fraction = MasteryPalette.barFraction(
      percentage: count * 100 / maxCount,
      hasData: count > 0,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // An empty string holds the line open so every bar starts at the same
        // height; days with nothing due say nothing rather than printing 0.
        Text(count > 0 ? iso(count) : '', style: AppTypography.chartValue),
        const SizedBox(height: AppSpacing.xxs),
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: context.colors.fill,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.accent,
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(iso(day), style: context.text.chartLabel),
      ],
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
      ReviewReason.overdue => l.overdueByDays(item.daysOverdue),
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
