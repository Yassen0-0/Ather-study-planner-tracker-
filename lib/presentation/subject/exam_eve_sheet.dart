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
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/pressable.dart';
import '../../domain/services/exam_eve_service.dart';
import '../providers/app_providers.dart';

/// Opens the exam-eve sheet for one subject.
///
/// The plan is computed once at open time and handed to the sheet as data:
/// the sheet closes before any navigation, so nothing behind it can change
/// while it is up, and the sheet widget itself stays a pure view a test can
/// pump without providers.
Future<void> showExamEveSheet(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
) {
  final l = L.of(context);
  final plan = ExamEveService.plan(
    ref.read(snapshotValueProvider),
    subjectId,
    ref.read(nowValueProvider),
  );

  return showAtherSheet<void>(
    context: context,
    builder: (sheetContext) => AtherSheetBody(
      title: l.examEveTitle,
      body: l.examEveBody,
      child: ExamEveSheet(
        plan: plan,
        // The push uses the screen's context, not the sheet's -- same
        // arrangement as the chapter gate's blocker sheet, which pushes with
        // the context that owns the router and pops with the sheet's own.
        onOpenLesson: (lessonId) {
          Navigator.of(sheetContext).pop();
          // `fromLesson: false`: there is no lesson screen underneath this
          // sheet for the wizard to land back on, so on save it must return
          // to wherever the subject screen is.
          context.push(Routes.exam(lessonId, fromLesson: false));
        },
      ),
    ),
  );
}

/// The three tiered lists of [ExamEvePlan]. A tier with nothing in it is not
/// drawn at all -- an empty section header over no rows reads like something
/// broke, not like there is nothing of that kind tonight.
class ExamEveSheet extends StatelessWidget {
  const ExamEveSheet({super.key, required this.plan, required this.onOpenLesson});

  final ExamEvePlan plan;
  final ValueChanged<int> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    if (plan.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(l.noLessonsYet, style: context.text.secondary),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget?>[
          _tier(l.examEveTierUnsettled, plan.unsettled, context),
          _tier(l.examEveTierWeakest, plan.weakest, context),
          _tier(l.examEveTierNearestDue, plan.nearestDue, context),
        ].nonNulls.toList(),
      ),
    );
  }

  /// Null when the tier has no rows -- folded away by [build].
  Widget? _tier(String title, List<ExamEveEntry> entries, BuildContext context) {
    if (entries.isEmpty) return null;

    final rows = <Widget>[
      for (final entry in entries)
        _EntryRow(
          entry: entry,
          statusText: switch (entry.tier) {
            ExamEveTier.unsettled => L.of(context).noExamShort,
            ExamEveTier.weakest => percent(entry.mastery),
            ExamEveTier.nearestDue => entry.daysUntilDue == null
                ? L.of(context).overdueByDays(entry.daysOverdue)
                : L.of(context).dueInDays(entry.daysUntilDue!),
          },
          statusColor: switch (entry.tier) {
            ExamEveTier.unsettled => context.colors.textSecondary,
            ExamEveTier.weakest => MasteryPalette.ofScore(
              context.colors,
              entry.mastery,
            ),
            ExamEveTier.nearestDue =>
              entry.daysUntilDue == null
                  ? context.colors.wrongText
                  : context.colors.textSecondary,
          },
          onTap: () => onOpenLesson(entry.lesson.id),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: AppTypography.controlLabel.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        ...rows,
      ],
    );
  }
}

/// Same row anatomy as the chapter gate's blocker list: name, trailing
/// evidence, chevron -- one visual grammar for "a lesson you could go prove".
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.statusText,
    required this.statusColor,
    required this.onTap,
  });

  final ExamEveEntry entry;
  final String statusText;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.divider)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.lesson.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.listTitle,
                  ),
                  if (entry.chapterName.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      entry.chapterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.rowStatus.copyWith(
                        color: context.colors.textNoData,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(statusText, style: AppTypography.controlLabel.copyWith(color: statusColor)),
            const SizedBox(width: AppSpacing.md),
            AtherIcon(
              AtherGlyph.chevron,
              size: 16,
              color: context.colors.textNoData,
            ),
          ],
        ),
      ),
    );
  }
}
