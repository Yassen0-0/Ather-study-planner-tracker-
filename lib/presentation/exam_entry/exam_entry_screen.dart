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
import '../providers/app_providers.dart';
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
  /// back on it. False from the review list or the tab-bar "+", where the
  /// wizard has to navigate to the lesson itself on save.
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
  void dispose() {
    _total.dispose();
    for (final group in _groups) {
      group.dispose();
    }
    super.dispose();
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

  void _back() {
    if (_step == 1) {
      context.pop();
      return;
    }
    setState(() {
      _step--;
      _error = null;
    });
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
    setState(() => _saving = true);

    // Everything that needs a BuildContext is resolved *before* the write, so
    // nothing reaches into a possibly-unmounted tree once it completes.
    final l = L.of(context);
    final message = l.toastExamSaved;
    final router = GoRouter.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final direction = Directionality.of(context);
    final summary = ref.read(lessonSummaryProvider(widget.lessonId));

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

    return Scaffold(
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
                  onClose: () => context.pop(),
                ),
                // Only the body changes between steps. The header, the progress
                // bar and the bottom bar persist -- animating them would make
                // four steps feel like four screens.
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
                    // Keyed on the step, so the switcher swaps on a step change
                    // and NOT on every keystroke inside a step -- a student
                    // enters numbers fast, and the fields must not flicker.
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
                            const SizedBox(height: AppSpacing.lg),
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
                      : PrimaryButtonTone.black,
                  onBack: _back,
                  onNext: _next,
                ),
              ],
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
      onChanged: (_) => setState(() => _error = null),
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
        style: AppTypography.style(
          size: 16,
          weight: AppTypography.bold,
          color: matched ? context.colors.right : context.colors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      for (var i = 0; i < _groups.length; i++) ...<Widget>[
        _GroupCard(
          group: _groups[i],
          questionsLabel: l.examGroupQuestions,
          pointsLabel: l.examGroupPoints,
          canRemove: _groups.length > 1,
          onChanged: () => setState(() => _error = null),
          onRemove: () => setState(() {
            _groups.removeAt(i).dispose();
            _error = null;
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
        }),
      ),
    ];
  }

  List<Widget> _step3(L l) => <Widget>[
    _StepHeading(title: l.examStep3Title, hint: l.examStep3Hint),
    const SizedBox(height: AppSpacing.xl),
    for (final group in _groups) ...<Widget>[
      AtherCard(
        padding: AppSpacing.lg,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.examGroupLabel(iso(group.countValue), iso(group.pointsValue)),
                style: AppTypography.style(
                  size: 15,
                  weight: AppTypography.semiBold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 80,
              child: NumberField(
                controller: group.correct,
                height: 48,
                textStyle: AppTypography.style(
                  size: 18,
                  weight: AppTypography.bold,
                ),
                onChanged: (_) => setState(() => _error = null),
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

    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: AppSpacing.xl),
        child: Text(l.examStep4Title, style: AppTypography.stepTitle),
      ),
      AtherCard(
        padding: AppSpacing.cardPaddingLarge,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 6),
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
              color: resultColor,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      AtherCard(
        padding: AppSpacing.cardPaddingLarge,
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
        AppSpacing.lg,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleHeaderButton(
                onTap: onClose,
                child: const AtherIcon(AtherGlyph.close, size: 17),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    size: 15,
                    weight: AppTypography.bold,
                  ),
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
                                color: context.colors.actionPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (i < stepCount) const SizedBox(width: 6),
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
        const SizedBox(height: 6),
        Text(title, style: AppTypography.stepTitle),
        const SizedBox(height: 6),
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
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _GroupDraft group;
  final String questionsLabel;
  final String pointsLabel;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AtherCard(
      padding: AppSpacing.lg,
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                '×',
                style: AppTypography.style(
                  size: 15,
                  weight: AppTypography.medium,
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
          style: AppTypography.style(
            size: 12,
            weight: AppTypography.semiBold,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
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
          style: AppTypography.style(
            size: 12.5,
            weight: AppTypography.semiBold,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.style(
            size: 22,
            weight: AppTypography.bold,
            color: color,
          ),
        ),
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
  });

  final String backLabel;
  final String nextLabel;
  final PrimaryButtonTone nextTone;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.sm,
          AppSpacing.pageMargin,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: PrimaryButton(
                label: backLabel,
                tone: PrimaryButtonTone.secondary,
                onTap: onBack,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: nextLabel,
                tone: nextTone,
                onTap: onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
