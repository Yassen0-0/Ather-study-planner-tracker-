import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../../core/widgets/day_header.dart';
import '../../core/widgets/icon_motion.dart';
import '../../core/widgets/list_entrance.dart';
import '../../core/widgets/mastery_bar.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/pressable.dart';
import '../../domain/entities/mastery.dart';
import '../../domain/entities/study_snapshot.dart';
import '../../domain/services/review_cycle_service.dart';
import '../../domain/entities/subject.dart';
import '../../domain/services/summaries.dart';
import '../common/prompts.dart';
import '../common/settings_button.dart';
import '../common/subject_presentation.dart';
import '../common/write_guard.dart';
import '../share/mastery_card.dart';
import '../providers/navigation_providers.dart';
import '../providers/app_providers.dart';
import '../providers/summary_providers.dart';

/// The home screen.
///
/// One dominant number (overall mastery), then the same number broken into
/// three counts, then the four subjects, then a single suggested action. The
/// student should be able to answer "where am I and what do I do now" without
/// scrolling.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const String _kLastOpenDayKey = 'last_open_day';

  ProviderSubscription<AsyncValue<StudySnapshot>>? _snapshotSub;
  late final SharedPreferences _preferences;

  /// The stored day is read once here; the decision waits for the snapshot,
  /// which may still be loading when the first frame builds.
  String? _storedOpenDay;
  bool _comebackResolved = false;
  int? _comebackDays;
  int? _comebackCount;

  @override
  void initState() {
    super.initState();
    _preferences = ref.read(sharedPreferencesProvider);
    _storedOpenDay = _preferences.getString(_kLastOpenDayKey);
    // The snapshot may still be loading on this first frame; the decision
    // waits for real data rather than counting against an empty curriculum.
    _snapshotSub = ref.listenManual(
      snapshotProvider,
      (AsyncValue<StudySnapshot>? _, AsyncValue<StudySnapshot> next) {
        if (next.isLoading || _comebackResolved) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _resolveComeback(next.value);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    // Idempotent in riverpod 3.4.2 (`if (_closed) return`), and the element
    // closes whatever remains on unmount.
    _snapshotSub?.close();
    super.dispose();
  }

  void _resolveComeback(StudySnapshot? snapshot) {
    if (_comebackResolved || !mounted) return;
    _comebackResolved = true;

    final now = ref.read(nowValueProvider);
    final today = DateTime(now.year, now.month, now.day);

    // Rewritten on every open, shown or not: the next gap is measured from
    // the day before this one.
    unawaited(_preferences.setString(_kLastOpenDayKey, today.toIso8601String()));

    final storedDay = DateTime.tryParse(_storedOpenDay ?? '');
    if (snapshot == null || storedDay == null) return;

    final gap = ReviewCycleService.calendarDaysBetween(storedDay, today);
    if (gap < 2) return;

    var cameDue = 0;
    for (final lesson in snapshot.lessons) {
      final last = lesson.lastReviewedAt;
      if (last == null) continue;
      // Overdue now, but still inside its cycle on the day the app was last
      // opened -- so the proof expired during the absence itself, and the
      // red the student is looking at accumulated while they were away.
      if (!ReviewCycleService.needsReview(lesson, now)) continue;
      if (ReviewCycleService.calendarDaysBetween(last, storedDay) >=
          kReviewCycleDays) {
        continue;
      }
      cameDue++;
    }

    setState(() {
      _comebackDays = gap;
      _comebackCount = cameDue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dashboard = ref.watch(dashboardProvider);
    final stats = ref.watch(homeStatsProvider);
    final next = ref.watch(nextTargetProvider);
    final profileName = ref.watch(profileNameProvider);
    // N7/C6: branch on how the read stands, not just what it last held --
    // otherwise a failing disk renders as the first-run card over an intact
    // record.
    final read = ref.watch(snapshotReadProvider);

    return AtherScreen(
      // No week strip. The dashboard's copy was inert -- nothing to select and
      // nothing to tap -- and the only thing it reported, "an exam happened on
      // this day", is already stated in full by the cards directly beneath it.
      // Seven circles that answer no question are seven circles between the
      // student and the screen. The tasks screen keeps its strip, because there
      // it picks the day the list belongs to.
      header: DayHeader(
        // The student's own name once they have given one, and the date's own
        // word until then. Not both: two headings stacked would push the first
        // number -- which is the reason this screen exists -- further down for
        // a greeting nobody opens the app to read.
        title: profileName.isEmpty
            ? l.dashboardTitle
            : l.profileGreeting(profileName),
        actions: <Widget>[
          // Only once there is a number worth showing. A card reading "0%"
          // over four empty subjects is not something a student shares, and a
          // button that produces one teaches them the feature is pointless.
          if (!dashboard.isEmpty) _ShareProgressButton(dashboard: dashboard),
          const SettingsButton(),
        ],
      ),
      children: <Widget>[
        // One line of fact under the title, once per absence. It explains the
        // red the student is about to scroll into rather than greeting or
        // scolding them, and it is gone the next time the app opens.
        if (_comebackDays != null && !dashboard.isEmpty) ...<Widget>[
          Text(
            l.comebackLine(_comebackDays!, _comebackCount ?? 0),
            style: context.text.secondary,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // A failed read is the one state allowed to say so; loading shows
        // nothing yet -- emptiness is a claim about the record and the first
        // emission has not landed to back it (N7/C6 settle-gating).
        if (read is SnapshotFailed)
          const _ReadFailedCard()
        else if (read is! SnapshotLoading) ...<Widget>[
          // A brand-new student used to land on "—", three zeroes and four
          // subject rows, with the actual first step -- open a subject, add a
          // chapter, add a lesson, sit an exam -- written down nowhere. It is the
          // longest path in the app and it was the only one with no signposting.
          //
          // The card **replaces** the two summary cards rather than sitting above
          // them: with nothing recorded they show "—" and "0 / 0" three times, so
          // they occupy the top of the screen to say nothing. Stacking a third
          // card on top of them pushed the four subjects -- the only things worth
          // tapping -- below the fold.
          if (dashboard.isEmpty)
            _FirstRunCard(subjects: dashboard.subjects)
          else ...<Widget>[
            _OverallCard(dashboard: dashboard),
            const SizedBox(height: AppSpacing.md),
            _StatsCard(stats: stats),
          ],
        ],
        const SizedBox(height: AppSpacing.xxxl),
        SectionTitle(l.sectionSubjects, trailing: const _AddSubjectButton()),
        const SizedBox(height: AppSpacing.md),
        for (final (i, subject) in dashboard.subjects.indexed) ...<Widget>[
          ListEntrance(
            index: i,
            id: subject.subject.id,
            child: _SubjectRow(summary: subject),
          ),
          const SizedBox(height: AppSpacing.listGap),
        ],
        if (next != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SectionTitle(l.sectionNext),
          const SizedBox(height: AppSpacing.md),
          _NextCard(target: next),
        ],
      ],
    );
  }
}

/// Puts the student's progress on the share sheet as a picture.
///
/// On the dashboard rather than on the analytics screen, deliberately: the
/// dashboard is where the overall number already lives, and the card shows that
/// number rather than the analytics screen's breakdowns.
class _ShareProgressButton extends StatefulWidget {
  const _ShareProgressButton({required this.dashboard});

  final DashboardSummary dashboard;

  @override
  State<_ShareProgressButton> createState() => _ShareProgressButtonState();
}

class _ShareProgressButtonState extends State<_ShareProgressButton> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;

    final l = L.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final direction = Directionality.of(context);

    setState(() => _sharing = true);
    try {
      await shareMasteryCard(
        context: context,
        l: l,
        dashboard: widget.dashboard,
      );
    } on Object catch (error, stack) {
      debugPrint('Ather: progress card failed -- $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        showAtherToastOn(
          overlay,
          direction,
          l.shareCardError,
          tone: ToastTone.failed,
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Directional: the gap belongs after the button in reading order, which
      // is the left in Arabic and the right in English (PROJECT.md: never
      // left/right).
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
      child: CircleHeaderButton(
        // `_share` returns early while one is already running, which is what
        // stops a second tap from starting a second render.
        onTap: _share,
        semanticLabel: L.of(context).shareCardAction,
        child: AtherIcon(
          AtherGlyph.share,
          size: 18,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

/// Shown only while the student has built nothing at all.
///
/// It disappears the moment a first chapter exists, so it is a starting point
/// rather than a tutorial to dismiss — there is no "got it" button, because a
/// card that has to be got rid of is a card that will be got rid of unread.
///
/// The copy also states the product's one claim up front. A student arriving
/// from any other study app expects ticking things off to move a number, and
/// finding out otherwise three screens in is finding out too late.
class _FirstRunCard extends StatelessWidget {
  const _FirstRunCard({required this.subjects});

  final List<SubjectSummary> subjects;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.firstRunTitle, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.textGap),
          Text(l.firstRunBody, style: context.text.secondary),
          if (subjects.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l.firstRunAction,
              onTap: () =>
                  context.push(Routes.subject(subjects.first.subject.id)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown only when the snapshot read itself failed.
///
/// The one honest thing the dashboard can say from here: not the first-run
/// card over an intact record, and not silence. Text only, reusing the app's
/// existing generic failure string -- a read error needs no new copy of its
/// own (N7/C6).
class _ReadFailedCard extends StatelessWidget {
  const _ReadFailedCard();

  @override
  Widget build(BuildContext context) {
    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Text(
        L.of(context).commonSomethingWentWrong,
        style: context.text.secondary,
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.dashboard});

  final DashboardSummary dashboard;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hasData = dashboard.hasAnyExam;
    final color = MasteryPalette.resolve(
      colors: context.colors,
      percentage: dashboard.overallMastery,
      hasData: hasData,
    );

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.overallMastery, style: AppTypography.cardLabel),
          const SizedBox(height: AppSpacing.textGap),
          // Baseline, not bottom. The sentence beside the number wraps to two
          // lines on a narrow screen or at a large text scale, and bottom
          // alignment lines its *last* line up with the number — which lifts
          // "١ من ٤ باب" clear above the number's cap height and leaves
          // "اتقنتها" stranded beside it. On one baseline the sentence starts
          // level with the figure and runs on underneath it, which is the order
          // it is read in.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              MasteryNumber(
                value: dashboard.overallMastery,
                hasData: hasData,
                color: color,
                style: AppTypography.cardNumber,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l.chaptersMasteredOf(
                    dashboard.masteredChapters,
                    dashboard.totalChapters,
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
              percentage: dashboard.overallMastery,
              hasData: hasData,
            ),
            color: MasteryPalette.fill(context.colors, color),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _Stat(
              label: l.statLessonsRemaining,
              value: stats.remaining,
              total: stats.totalLessons,
              fraction: stats.fraction(stats.remaining),
              // Red elsewhere means decay -- an overdue lesson, a failed exam.
              // This stat borrows it on purpose: owner decision 2026-08-23
              // renamed the backlog «متراكمة» ("owed", not "left") and asked
              // for the alarm colour so the student clears it early. The name
              // itself is always red, in [wrongText] -- the text-safe grade,
              // because 14px fails AA in the fill-grade red -- and the count
              // joins it on exactly the overdue sibling's terms below.
              labelColor: context.colors.wrongText,
              color: stats.remaining > 0
                  ? context.colors.wrong
                  : context.colors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: _Stat(
              label: l.statNeedsReview,
              value: stats.overdue,
              total: stats.totalLessons,
              fraction: stats.fraction(stats.overdue),
              // Red only once there is something to be red about.
              color: stats.overdue > 0
                  ? context.colors.wrong
                  : context.colors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: _Stat(
              label: l.statMastered,
              value: stats.excellent,
              total: stats.totalLessons,
              fraction: stats.fraction(stats.excellent),
              color: stats.excellent > 0
                  ? context.colors.rightText
                  : context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.total,
    required this.fraction,
    required this.color,
    this.labelColor,
  });

  final String label;
  final int value;
  final int total;
  final double fraction;
  final Color color;

  /// The label's own colour, when a stat's *name* carries the verdict.
  ///
  /// Null keeps [AppTypography.statLabel]'s neutral ink; the only caller that
  /// sets it paints the backlog stat red (owner decision 2026-08-23).
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelColor == null
              ? AppTypography.statLabel
              : AppTypography.statLabel.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Ltr(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '$value',
                style: AppTypography.statValue.copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text('/ $total', style: context.text.statDenominator),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        MasteryBar(
          // The sliver is a fill, so a stat with nothing to be red or green
          // about gets the accent rather than the black its count is written
          // in. See MasteryPalette.fill.
          fraction: fraction,
          color: MasteryPalette.fill(context.colors, color),
          height: AppSizes.barTrackSmall,
        ),
      ],
    );
  }
}

/// "+", beside the subjects heading.
///
/// Adding a subject lived only in Settings, which is the wrong place for it:
/// the student is looking at their subjects when they notice one is missing,
/// and Settings is three taps and a different mental mode away. `SectionTitle`
/// already takes a `trailing` widget and places it after an `Expanded`, so in
/// Arabic this lands on the left -- the far end of the heading, which is where
/// an "add" control belongs in either direction.
///
/// Deliberately small and quiet. It sits above a list of subjects a student
/// reads every day and adds to perhaps five times ever, so it must not compete
/// with the rows under it.
class _AddSubjectButton extends ConsumerWidget {
  const _AddSubjectButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    return Pressable(
      onTap: () => _add(context, ref),
      semanticLabel: l.subjectAdd,
      // Drawn small, hit at the full target: the artwork is 20px inside a 48px
      // finger, the same arrangement CircleHeaderButton uses.
      minTarget: kMinTarget,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.muted,
          shape: BoxShape.circle,
        ),
        child: AtherIcon(
          AtherGlyph.plus,
          size: 16,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final name = await showNamePrompt(
      context,
      title: l.subjectAdd,
      hint: l.subjectNameHint,
      maxLength: kSubjectNameMaxLength,
    );
    if (name == null || !context.mounted) return;
    var newId = 0;
    final ok = await runWrite(context, () async {
      newId = await ref
          .read(studyRepositoryProvider)
          .createSubject(name: name);
    });
    if (ok && context.mounted) {
      context.push(Routes.subject(newId));
    }
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.summary});

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

    final lessonTotal = <int>[
      for (final chapter in summary.chapters) chapter.lessonCount,
    ].fold<int>(0, (a, b) => a + b);

    final String subtitle;
    if (!summary.hasContent) {
      subtitle = l.notStartedYet;
    } else if (summary.needsReview) {
      subtitle = l.subjectHasOverdueLesson;
    } else {
      subtitle =
          '${l.chaptersOfShort(summary.masteredChapterCount, summary.chapterCount)} · ${l.lessonCount(lessonTotal)}';
    }

    return AtherCard(
      onTap: () => context.push(Routes.subject(summary.subject.id)),
      child: Row(
        children: <Widget>[
          // No leading subject mark. The owner had the icons beside the
          // subjects removed outright -- "الأيقونات اللي بجانب المواد تتشال
          // خالص" (2026-08-23) -- so the title starts flush at the card's own
          // padding, level with the status line beneath it. Do not re-add one
          // to balance the row: `SubjectMark` still exists for the settings
          // lists, which is exactly why its absence here can read as an
          // oversight rather than a decision. The dashboard test suite fails
          // if the mark comes back.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        summary.subject.label(l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowTitle,
                      ),
                    ),
                    // Decay is always an icon *and* a colour. Colour alone
                    // fails for a colour-blind student and in bright sun.
                    //
                    // The mark outlives the state it reports by one animation:
                    // it floods to a tick and then collapses out of the row,
                    // so the student sees the thing they just fixed being
                    // marked done instead of silently vanishing.
                    OverdueMark(needsReview: summary.needsReview),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
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
          const SizedBox(width: AppSpacing.md),
          AnimatedPercentage(
            value: summary.mastery,
            hasData: hasData,
            color: color,
            style: AppTypography.rowNumber,
          ),
        ],
      ),
    );
  }
}

class _NextCard extends ConsumerWidget {
  const _NextCard({required this.target});

  final NextTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final snapshot = ref.watch(snapshotValueProvider);
    // "{subject} · {chapter}" -- a name like "الوحدة الأولى" exists in more
    // than one subject, so the card names where this lesson lives before it
    // asks for an exam. Same words the review centre puts under its rows.
    final subject = snapshot.subjectById(target.subjectId);
    final chapter = snapshot.chapterById(target.chapterId);
    final crumb = <String>[
      if (subject != null) subject.label(l),
      if (chapter != null) chapter.name,
    ].join(' · ');

    return AtherCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colors.fill,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AtherIcon(AtherGlyph.edit, size: 19),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  target.lesson.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowTitle,
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
                  target.isOverdue
                      ? l.overdueByDays(target.daysOverdue)
                      : l.lessonNoExamYet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowStatus.copyWith(
                    color: target.isOverdue
                        ? context.colors.wrong
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          PillButton(
            label: l.actionExam,
            onTap: () =>
                context.push(Routes.exam(target.lesson.id, fromLesson: false)),
          ),
        ],
      ),
    );
  }
}
