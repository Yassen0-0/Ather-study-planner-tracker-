import 'dart:async';
import 'dart:convert';

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
import '../../core/widgets/ather_controls.dart';
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/list_entrance.dart';
import '../../core/widgets/mastery_bar.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reduced_motion.dart';
import '../../domain/entities/exam_entry.dart';
import '../../domain/services/mastery_calculator.dart';
import '../common/prompts.dart';
import '../providers/app_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/summary_providers.dart';

/// The exam wizard — the heart of the product.
///
/// The student never types a percentage. They describe the paper the way a
/// Thanaweya paper is actually built ("5 questions worth 1, 3 worth 2"), say
/// how many they got right in each group, and the app does the arithmetic. That
/// is what makes the number trustworthy: it is derived from what happened, not
/// from what the student felt about it.
///
/// Four steps, one question each, on a full screen with no tab bar — there is
/// nowhere to wander off to mid-entry.
class ExamEntryScreen extends ConsumerStatefulWidget {
  const ExamEntryScreen({
    super.key,
    required this.lessonId,
    required this.openedFromLesson,
  });

  final int lessonId;

  /// True when the wizard was pushed from the lesson screen, so popping lands
  /// back on it. False from the review list and the dashboard's "Exam" pill,
  /// where the wizard has to navigate to the lesson itself on save.
  final bool openedFromLesson;

  @override
  ConsumerState<ExamEntryScreen> createState() => _ExamEntryScreenState();
}

class _GroupDraft {
  _GroupDraft();

  final TextEditingController count = TextEditingController();
  final TextEditingController points = TextEditingController();
  final TextEditingController correct = TextEditingController();

  int get countValue => int.tryParse(count.text) ?? 0;
  int get pointsValue => int.tryParse(points.text) ?? 0;
  int get correctValue => int.tryParse(correct.text) ?? 0;

  void dispose() {
    count.dispose();
    points.dispose();
    correct.dispose();
  }
}

class _ExamEntryScreenState extends ConsumerState<ExamEntryScreen> {
  static const int _stepCount = 4;

  final TextEditingController _total = TextEditingController();
  final List<_GroupDraft> _groups = <_GroupDraft>[_GroupDraft()];

  int _step = 1;
  String? _error;
  bool _saving = false;

  /// Whether step 4's result number has already counted up in this flow. State
  /// on the wizard, not on the widget: the count-up is a one-time event, and
  /// stepping back to 3 must not re-arm it.
  bool _resultCounted = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void dispose() {
    _total.dispose();
    for (final group in _groups) {
      group.dispose();
    }
    super.dispose();
  }

  // --- The draft that survives process death ---------------------------------
  //
  // The wizard is the one screen holding data that exists nowhere else yet: a
  // student halfway through describing a paper can lose it to Android killing
  // the app for memory. The confirmation dialog guards deliberate exits; these
  // four methods guard the involuntary ones. Raw field text under a per-lesson
  // key -- numbers only, no dates, no step position -- written on every change
  // and read back quietly on open.

  static String _draftKeyFor(int lessonId) => 'exam_draft_$lessonId';

  String get _draftKey => _draftKeyFor(widget.lessonId);

  /// Refills the fields from a previous session's draft, silently.
  ///
  /// No toast and no error state: from the student's side nothing happened --
  /// the numbers are simply still there, as if the wizard had never closed.
  /// Anything unreadable (a shape an older build wrote, truncated JSON) is
  /// ignored wholesale rather than half-applied.
  void _restoreDraft() {
    final String? raw = ref
        .read(sharedPreferencesProvider)
        .getString(_draftKey);
    if (raw == null) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final Object? total = decoded['total'];
    final Object? groups = decoded['groups'];
    if (total is! String || groups is! List) return;

    final drafts = <_GroupDraft>[];
    for (final entry in groups) {
      if (entry is! List || entry.length != 3) continue;
      final Object? count = entry[0];
      final Object? points = entry[1];
      final Object? correct = entry[2];
      if (count is! String || points is! String || correct is! String) continue;
      drafts.add(
        _GroupDraft()
          ..count.text = count
          ..points.text = points
          ..correct.text = correct,
      );
    }
    // A draft whose groups all failed to read back has nothing worth showing;
    // leave the wizard's own empty first group rather than an empty paper.
    if (drafts.isEmpty) return;

    _total.text = total;
    for (final group in _groups) {
      group.dispose();
    }
    _groups
      ..clear()
      ..addAll(drafts);
  }

  /// Writes the current raw field text to [SharedPreferences].
  ///
  /// Fired from every numeric-field change, so it runs once per keystroke --
  /// deliberately. The write is an in-memory set plus an async flush, and the
  /// one event it must not miss is the keystroke right before the process
  /// dies. Same persistence pattern as the language toggle.
  void _persistDraft() {
    // Keystrokes while an exam is submitting must not clobber the saved draft.
    if (_saving) return;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(
            _draftKey,
            jsonEncode(<String, Object?>{
              'total': _total.text,
              'groups': <Object?>[
                for (final group in _groups)
                  <String>[
                    group.count.text,
                    group.points.text,
                    group.correct.text,
                  ],
              ],
            }),
          ),
    );
  }

  /// The draft has become either a saved exam or a confirmed discard; either
  /// way its job is done.
  void _clearDraft() {
    unawaited(ref.read(sharedPreferencesProvider).remove(_draftKey));
  }

  /// Every numeric-field change funnels through here: clear any standing
  /// validation error and keep the draft current.
  void _fieldChanged() {
    _persistDraft();
    setState(() => _error = null);
  }

  int get _totalValue => int.tryParse(_total.text) ?? 0;

  int get _assigned =>
      _groups.fold<int>(0, (sum, group) => sum + group.countValue);

  int get _possiblePoints => _groups.fold<int>(
    0,
    (sum, group) => sum + group.countValue * group.pointsValue,
  );

  int get _earnedPoints => _groups.fold<int>(
    0,
    (sum, group) => sum + group.correctValue * group.pointsValue,
  );

  double get _resultPercentage =>
      _possiblePoints <= 0 ? 0 : (_earnedPoints / _possiblePoints) * 100;

  /// Whether the student has typed anything at all.
  ///
  /// Read from the controllers rather than tracked with a flag, so clearing a
  /// field back to empty correctly counts as nothing entered.
  bool get _hasInput =>
      _total.text.isNotEmpty ||
      _groups.any(
        (g) =>
            g.count.text.isNotEmpty ||
            g.points.text.isNotEmpty ||
            g.correct.text.isNotEmpty,
      );

  /// The one exit path, shared by the on-screen Back button, the × and the
  /// system back gesture.
  ///
  /// Those three used to disagree: Back stepped back through the wizard while ×
  /// and the system gesture threw the whole entry away without asking. A student
  /// halfway through describing a paper, reaching for "go back one question",
  /// lost the lot to a stray swipe — and the wizard is the one screen in the app
  /// holding data that exists nowhere else yet.
  Future<void> _back() async {
    // The save is in flight: stepping back would decrement the step out from
    // under it, landing the student on an earlier question while the write
    // lands -- or does not. The on-screen button is already disabled while
    // busy; this closes the same hole for the system gesture.
    if (_saving) return;
    if (_step > 1) {
      setState(() {
        _step--;
        _error = null;
      });
      return;
    }
    await _leave();
  }

  /// Closes the wizard, asking first if there is anything to lose.
  Future<void> _leave() async {
    if (_saving) return;

    if (!_hasInput) {
      context.pop();
      return;
    }

    final l = L.of(context);
    final router = GoRouter.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l.examDiscardTitle,
      message: l.examDiscardBody,
      // Nothing is being deleted, so the red button does not say "delete".
      confirmLabel: l.examDiscardLeave,
      cancelLabel: l.examDiscardStay,
    );
    if (confirmed) {
      // An explicit discard is the one voluntary way a draft may die.
      _clearDraft();
      router.pop();
    }
  }

  void _next() {
    final l = L.of(context);

    switch (_step) {
      case 1:
        if (_totalValue < 1) {
          setState(() => _error = l.examErrorNeedAtLeastOneQuestion);
          return;
        }
      case 2:
        if (_groups.any((g) => g.countValue <= 0 || g.pointsValue <= 0)) {
          setState(() => _error = l.examErrorGroupInvalid);
          return;
        }
        if (_assigned != _totalValue) {
          setState(
            () => _error = l.examErrorSumMismatch(
              iso(_assigned),
              iso(_totalValue),
            ),
          );
          return;
        }
      case 3:
        if (_groups.any((g) => g.correctValue > g.countValue)) {
          setState(() => _error = l.examErrorCorrectExceeds);
          return;
        }
      default:
        _save();
        return;
    }

    setState(() {
      _step++;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    // Everything that needs a BuildContext is resolved *before* the write, so
    // nothing reaches into a possibly-unmounted tree once it completes.
    final l = L.of(context);
    final message = l.toastExamSaved;
    final router = GoRouter.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final direction = Directionality.of(context);
    final summary = ref.read(lessonSummaryProvider(widget.lessonId));

    // Whether any review clock was running *before* this write. Used below to
    // decide whether this is the exam that starts the first one.
    final hadReviews = ref.read(hasScheduledReviewsProvider);

    try {
      await ref
          .read(studyRepositoryProvider)
          .recordExam(
            lessonId: widget.lessonId,
            groups: <DraftQuestionGroup>[
              for (final group in _groups)
                DraftQuestionGroup(
                  pointsPerQuestion: group.pointsValue,
                  questionCount: group.countValue,
                  correctCount: group.correctValue,
                ),
            ],
            // Classified from the lesson's state at submit time: an exam sat to
            // clear a decayed lesson is a review exam, and the student never has
            // to say so.
            isReviewExam: summary?.needsReview ?? false,
            at: ref.read(clockProvider).now(),
          );
    } on Object catch (error, stack) {
      // The wizard used to have no catch at all, and `_saving` was never
      // cleared: one failed write left the student holding a fully entered
      // paper behind a Save button that silently ignored every further tap.
      // Staying on step 4 with the numbers intact is the whole point -- there
      // is nowhere else for this data to live.
      debugPrint('Ather: recording exam failed -- $error\n$stack');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l.examSaveFailed;
      });
      return;
    }

    // The paper is now a real exam; the draft has nothing left to hold.
    _clearDraft();

    // The first recorded exam is the moment the first 30-day clock starts, and
    // therefore the first moment a reminder means anything. Asking here rather
    // than on cold start is the rule the manifest already described; what was
    // missing was any call site at all.
    if (!hadReviews) {
      try {
        await ref.read(notificationServiceProvider).requestPermission();
      } catch (_) {
        // A refused or unavailable permission never blocks a save.
      }
    }

    if (!mounted) return;
    router.pop();
    if (!widget.openedFromLesson) {
      router.go(Routes.lesson(widget.lessonId));
    }

    if (overlay != null) showAtherToastOn(overlay, direction, message);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final summary = ref.watch(lessonSummaryProvider(widget.lessonId));
    final isReview = summary?.needsReview ?? false;

    return PopScope(
      // The system back press is routed through the same [_back] as the button
      // on screen, so the two can no longer mean different things. This is the
      // one route in the app that holds unsaved data, which is why it is also
      // the one route that refuses to pop on its own.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: context.colors.pageBackground,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: <Widget>[
                  _WizardHeader(
                    title: summary?.lesson.name ?? '',
                    step: _step,
                    stepCount: _stepCount,
                    onClose: _leave,
                  ),
                  // Only the body changes between steps. The header, the
                  // progress bar and the bottom bar persist -- animating them
                  // would make four steps feel like four screens.
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: prefersReducedMotion(context)
                          ? Duration.zero
                          : AppMotion.step,
                      switchInCurve: AppMotion.standard,
                      switchOutCurve: AppMotion.standard,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: AnimatedBuilder(
                          animation: animation,
                          builder: (context, inner) => Transform.translate(
                            offset: Offset(
                              0,
                              AppMotion.stepRise * (1 - animation.value),
                            ),
                            child: inner,
                          ),
                          child: child,
                        ),
                      ),
                      // Keyed on the step, so the switcher swaps on a step
                      // change and NOT on every keystroke inside a step -- a
                      // student enters numbers fast, and the fields must not
                      // flicker.
                      child: KeyedSubtree(
                        key: ValueKey<int>(_step),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageMargin,
                            2,
                            AppSpacing.pageMargin,
                            AppSpacing.xxxl,
                          ),
                          children: <Widget>[
                            ..._buildStep(l),
                            if (_error != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.xl),
                              ErrorBanner(message: _error!),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  _BottomBar(
                    backLabel: l.commonBack,
                    nextLabel: _step < _stepCount
                        ? l.commonNext
                        : isReview
                        ? l.examSaveReview
                        : l.examSave,
                    nextTone: _step == _stepCount && isReview
                        ? PrimaryButtonTone.wrong
                        : PrimaryButtonTone.primary,
                    busy: _saving,
                    onBack: _back,
                    onNext: _next,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep(L l) => switch (_step) {
    1 => _step1(l),
    2 => _step2(l),
    3 => _step3(l),
    _ => _step4(l),
  };

  List<Widget> _step1(L l) => <Widget>[
    _StepHeading(title: l.examStep1Title, hint: l.examStep1Hint),
    const SizedBox(height: AppSpacing.md),
    NumberField(
      controller: _total,
      autofocus: true,
      height: AppSizes.bigNumberField,
      radius: AppRadius.card,
      fill: context.colors.card,
      textStyle: AppTypography.inputLarge,
      hint: '0',
      onChanged: (_) => _fieldChanged(),
    ),
  ];

  List<Widget> _step2(L l) {
    final matched = _assigned == _totalValue && _totalValue > 0;

    return <Widget>[
      _StepHeading(title: l.examStep2Title, hint: l.examStep2Hint),
      const SizedBox(height: AppSpacing.md),
      // A live tally that turns green the moment the groups add up. It answers
      // "have I described the whole paper yet" without the student having to
      // press Next to find out.
      Text(
        fraction(_assigned, _totalValue),
        style: AppTypography.cardTitle.copyWith(
          color: matched
              ? context.colors.rightText
              : context.colors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      for (var i = 0; i < _groups.length; i++) ...<Widget>[
        _GroupCard(
          group: _groups[i],
          questionsLabel: l.examGroupQuestions,
          pointsLabel: l.examGroupPoints,
          removeLabel: l.examRemoveGroup,
          canRemove: _groups.length > 1,
          onChanged: _fieldChanged,
          onRemove: () => setState(() {
            _groups.removeAt(i).dispose();
            _error = null;
            _persistDraft();
          }),
        ),
        const SizedBox(height: AppSpacing.listGap),
      ],
      DashedAddButton(
        label: l.examAddGroup,
        radius: AppRadius.button,
        padding: 13,
        onTap: () => setState(() {
          _groups.add(_GroupDraft());
          _error = null;
          _persistDraft();
        }),
      ),
    ];
  }

  List<Widget> _step3(L l) => <Widget>[
    _StepHeading(title: l.examStep3Title, hint: l.examStep3Hint),
    const SizedBox(height: AppSpacing.xl),
    for (final group in _groups) ...<Widget>[
      AtherCard(
        padding: AppSpacing.xl,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.examGroupLabel(iso(group.countValue), iso(group.pointsValue)),
                style: AppTypography.listTitle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 80,
              child: NumberField(
                controller: group.correct,
                height: AppSizes.input,
                textStyle: AppTypography.rowNumberSmall,
                onChanged: (_) => _fieldChanged(),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.listGap),
    ],
  ];

  List<Widget> _step4(L l) {
    final snapshot = ref.read(snapshotValueProvider);
    final existing = snapshot.examsFor(widget.lessonId);
    final before = MasteryCalculator.lessonMastery(existing);
    final after = MasteryCalculator.lessonMastery(<ExamEntry>[
      ...existing,
      ExamEntry(
        id: -1,
        lessonId: widget.lessonId,
        isReviewExam: false,
        totalPossiblePoints: _possiblePoints,
        correctPoints: _earnedPoints,
        percentage: _resultPercentage,
        createdAt: ref.read(clockProvider).now(),
      ),
    ]);
    final resultColor = MasteryPalette.ofScore(
      context.colors,
      _resultPercentage,
    );

    // The verdict and the "what do I need next" line are derived from the
    // *resulting* mastery -- the state the lesson is actually in once this
    // paper is counted -- not from the raw score alone.
    final String? verdict = switch (after) {
      < 50 => l.examVerdictWeak,
      < 70 => l.examVerdictPassed,
      _ => null,
    };
    final Color? verdictColor = switch (after) {
      // Red, like the number it explains.
      < 50 => context.colors.wrong,
      // Deliberately not green: "passed" is not a success the product counts,
      // only the absence of failure. Neutral grey keeps that honest.
      < 70 => context.colors.textSecondary,
      _ => null,
    };

    // The required score reads from the recorded exams' plain mean (never from
    // the displayed figure: no inverse of it exists at n > 1), and only asks a
    // question while the line still stands ahead.
    var existingSum = 0.0;
    for (final exam in existing) {
      existingSum += exam.percentage;
    }
    final double meanExisting =
        existing.isEmpty ? 0 : existingSum / existing.length;
    final int? neededScore = after < 70
        ? MasteryCalculator.scoreNeededToCross(meanOfExisting: meanExisting)
        : null;

    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.textGap,
          bottom: AppSpacing.xl,
        ),
        child: Text(l.examStep4Title, style: AppTypography.stepTitle),
      ),
      AtherCard(
        padding: AppSpacing.cardPadding,
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.textGap),
            // The one place in the app that counts from zero, and it does it
            // once. Stepping back to 3 and forward again shows a fact, not
            // news, so the flag lives on the wizard rather than the widget.
            CountUpFromZero(
              value: _resultPercentage,
              already: _resultCounted,
              onDone: () => _resultCounted = true,
              color: resultColor,
              style: AppTypography.resultNumber,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.examPointsLine(fraction(_earnedPoints, _possiblePoints)),
              style: context.text.secondaryStrong,
            ),
            const SizedBox(height: AppSpacing.xl),
            MasteryBar(
              fraction: MasteryPalette.barFraction(
                percentage: _resultPercentage,
                hasData: true,
              ),
              // The bar is a fill, so a mid-range result is the accent even
              // though the number above it is plain text. See
              // MasteryPalette.fill.
              color: MasteryPalette.fill(context.colors, resultColor),
            ),
            const SizedBox(height: AppSpacing.textGap),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      AtherCard(
        padding: AppSpacing.cardPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Before and after side by side: the point of the wizard is not the
            // exam's score, it is what the exam did to the lesson.
            //
            // Both sides are flexible so a long label or a wide font never
            // pushes the arrow off the card.
            //
            // The three parts arrive in reading order -- before, arrow, after
            // -- so the student reads a sentence rather than seeing three
            // numbers land at once. Fades only: nothing here moves.
            Flexible(
              child: RiseIn(
                rise: 0,
                duration: AppMotion.page,
                child: _BeforeAfter(
                  label: l.examMasteryBefore,
                  value: percentLabel(before, hasData: existing.isNotEmpty),
                  color: MasteryPalette.resolve(
                    colors: context.colors,
                    percentage: before,
                    hasData: existing.isNotEmpty,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: RiseIn(
                rise: 0,
                duration: AppMotion.page,
                delay: AppMotion.beforeAfterArrowDelay,
                // The arrow points *along the reading direction*, so it always
                // runs from "before" towards "after". The glyph is drawn
                // pointing left, which is correct in Arabic and backwards in
                // English -- so it is mirrored there. This is not one of the
                // three forced-LTR elements: those are numbers and bars, where
                // a mirrored fill would misstate the score. An arrow is a
                // direction, and direction is what flips.
                child: Transform.scale(
                  scaleX: Directionality.of(context) == TextDirection.ltr
                      ? -1
                      : 1,
                  child: AtherIcon(
                    AtherGlyph.beforeAfterArrow,
                    size: 26,
                    color: context.colors.textTertiary,
                  ),
                ),
              ),
            ),
            Flexible(
              child: RiseIn(
                rise: 0,
                duration: AppMotion.page,
                delay: AppMotion.beforeAfterValueDelay,
                child: _BeforeAfter(
                  label: l.examMasteryAfter,
                  value: percent(after),
                  color: MasteryPalette.ofScore(context.colors, after),
                ),
              ),
            ),
          ],
        ),
      ),
      // The worst moment in the product's loop used to end in silence: a weak
      // or mid-range paper vanished into the 30-day gap with not one word.
      // Two derived sentences close it -- what happened, and exactly what the
      // next paper must do. Both stay quiet once mastery has crossed 70:
      // nothing to report, nothing to ask.
      if (verdict != null || (after < 70 && neededScore != null)) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (verdict != null)
                Text(
                  verdict,
                  style: AppTypography.statusLine.copyWith(color: verdictColor),
                ),
              if (verdict != null && neededScore != null && after < 70)
                const SizedBox(height: AppSpacing.textGap),
              if (after < 70 && neededScore != null)
                Text(
                  l.examNeedToCross(iso('$neededScore%')),
                  style: AppTypography.statusLine.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.title,
    required this.step,
    required this.stepCount,
    required this.onClose,
  });

  final String title;
  final int step;
  final int stepCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        2,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleHeaderButton(
                onTap: onClose,
                semanticLabel: L.of(context).commonClose,
                child: const AtherIcon(AtherGlyph.close, size: 17),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
              ),
              // Balances the close button so the title stays optically centred.
              const SizedBox(width: AppSizes.headerButton),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Ltr(
            child: Row(
              children: <Widget>[
                for (var i = 1; i <= stepCount; i++) ...<Widget>[
                  Expanded(
                    // scaleX, never width: a segment that animates its layout
                    // makes the four beside it re-measure on every frame. The
                    // header is already inside Ltr, so centerLeft is the
                    // leading edge by construction rather than by accident --
                    // and going back empties the segment the same way.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 4,
                        color: context.colors.switchOff,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: i <= step ? 1 : 0,
                          ),
                          duration: prefersReducedMotion(context)
                              ? Duration.zero
                              : AppMotion.segment,
                          curve: AppMotion.standard,
                          builder: (context, t, _) => Align(
                            alignment: Alignment.centerLeft,
                            child: Transform.scale(
                              scaleX: t,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 4,
                                // A step bar is a progress fill like any other.
                                color: context.colors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (i < stepCount) const SizedBox(width: AppSpacing.textGap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.textGap),
        Text(title, style: AppTypography.stepTitle),
        const SizedBox(height: AppSpacing.textGap),
        Text(
          hint,
          style: AppTypography.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.questionsLabel,
    required this.pointsLabel,
    required this.removeLabel,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _GroupDraft group;
  final String questionsLabel;
  final String pointsLabel;
  final String removeLabel;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AtherCard(
      padding: AppSpacing.xl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: _LabelledField(
              label: questionsLabel,
              controller: group.count,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Text(
                '×',
                style: AppTypography.itemLabel.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
            ),
          ),
          Expanded(
            child: _LabelledField(
              label: pointsLabel,
              controller: group.points,
              onChanged: onChanged,
            ),
          ),
          Opacity(
            opacity: canRemove ? 1 : 0.25,
            child: Pressable(
              onTap: canRemove ? onRemove : null,
              semanticLabel: removeLabel,
              // Was 32 x 46. The × keeps its 16px, the card keeps its layout.
              minTarget: kMinTarget,
              child: SizedBox(
                width: 32,
                height: AppSizes.input,
                child: Center(
                  child: AtherIcon(
                    AtherGlyph.close,
                    size: 16,
                    color: context.colors.textSecondary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.fieldLabel,
        ),
        const SizedBox(height: AppSpacing.textGap),
        NumberField(controller: controller, onChanged: (_) => onChanged()),
      ],
    );
  }
}

class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.fieldLabel,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(value, style: AppTypography.sectionTitle.copyWith(color: color)),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.backLabel,
    required this.nextLabel,
    required this.nextTone,
    required this.onBack,
    required this.onNext,
    this.busy = false,
  });

  final String backLabel;
  final String nextLabel;
  final PrimaryButtonTone nextTone;
  final VoidCallback onBack;
  final VoidCallback onNext;

  /// The save is in flight. Back is disabled too: stepping out from under a
  /// write in progress is the one way to end up unsure whether it landed.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.md,
          AppSpacing.pageMargin,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: PrimaryButton(
                label: backLabel,
                tone: PrimaryButtonTone.secondary,
                onTap: busy ? null : onBack,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: nextLabel,
                tone: nextTone,
                busy: busy,
                onTap: onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
