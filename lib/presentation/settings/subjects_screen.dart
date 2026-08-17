import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/settings_list.dart';
import '../../domain/entities/subject.dart';
import '../common/prompts.dart';
import '../common/subject_mark.dart';
import '../common/subject_presentation.dart';
import '../common/write_guard.dart';
import '../providers/app_providers.dart';

/// Where a student adds the subjects they actually take.
///
/// Ather shipped with four because it was built for one student sitting علمي
/// علوم. They are still seeded on a fresh install — an app that opens onto an
/// empty screen is worse than one that opens onto four subjects you can hide —
/// but they are no longer the list.
///
/// ## Why hiding comes first and deleting barely appears
///
/// `Chapters.subjectId` cascades. Deleting a subject takes every chapter,
/// lesson and exam under it, which for a student two years into their record is
/// the largest single act of destruction this app is capable of — and there is
/// no undo anywhere in it. Meanwhile the thing a student almost always means by
/// "remove إنجليزي" is *stop showing it to me*, not *destroy the eleven exams I
/// recorded in it*.
///
/// So the row offers **hiding**, which touches nothing and is reversible from
/// this same screen, and the repository refuses to delete a subject that has
/// any chapters at all. Deleting is left for the case where nothing can be
/// lost: a subject added by mistake, five seconds ago, still empty.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final snapshot = ref.watch(snapshotValueProvider);

    final active = snapshot.activeSubjects;
    final archived = <Subject>[
      for (final s in snapshot.subjects)
        if (s.isArchived) s,
    ];

    return AtherScreen(
      header: AtherHeader(title: l.subjectsTitle, onBack: () => context.pop()),
      children: <Widget>[
        SettingsGroup(
          children: <Widget>[
            for (final subject in active)
              _SubjectRow(subject: subject, chapterCount: _count(ref, subject)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: l.subjectAdd,
          tone: PrimaryButtonTone.secondary,
          onTap: () => _add(context, ref),
        ),
        if (archived.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xxxl),
          SettingsGroup(
            title: l.subjectsHidden,
            children: <Widget>[
              for (final subject in archived)
                _SubjectRow(
                  subject: subject,
                  chapterCount: _count(ref, subject),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SettingsFootnote(l.subjectsHiddenNote),
        ],
      ],
    );
  }

  int _count(WidgetRef ref, Subject subject) =>
      ref.read(snapshotValueProvider).chaptersIn(subject.id).length;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final name = await showNamePrompt(
      context,
      title: l.subjectAdd,
      hint: l.subjectNameHint,
    );
    if (name == null || !context.mounted) return;
    await runWrite(
      context,
      () => ref.read(studyRepositoryProvider).createSubject(name: name),
    );
  }
}

/// One subject, and the sheet behind it.
class _SubjectRow extends ConsumerWidget {
  const _SubjectRow({required this.subject, required this.chapterCount});

  final Subject subject;
  final int chapterCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    return Pressable(
      onTap: () => _edit(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            SubjectMark(subject: subject, size: 22),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Text(
                subject.label(l),
                style: AppTypography.cardLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(l.chapterCount(chapterCount), style: context.text.secondary),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final repository = ref.read(studyRepositoryProvider);
    final clock = ref.read(clockProvider);

    await showAtherSheet<void>(
      context: context,
      builder: (sheetContext) => AtherSheetBody(
        title: subject.label(l),
        child: SettingsGroup(
          children: <Widget>[
            // The seeded four take their names from the ARB files so the
            // language toggle can reach them; renaming one here would freeze
            // whichever language was on at the time.
            if (!subject.isSeeded)
              SettingsRow(
                label: l.subjectRename,
                trailing: SettingsRowTrailing.none,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _rename(context, ref);
                },
              ),
            SettingsRow(
              label: subject.isArchived ? l.subjectUnhide : l.subjectHide,
              trailing: SettingsRowTrailing.none,
              onTap: () {
                Navigator.of(sheetContext).pop();
                runWrite(
                  context,
                  () => repository.setSubjectArchived(
                    subjectId: subject.id,
                    at: subject.isArchived ? null : clock.now(),
                  ),
                );
              },
            ),
            // Offered only when there is provably nothing to lose. The
            // repository refuses either way -- this is the screen agreeing with
            // it rather than presenting a control that answers "no".
            if (chapterCount == 0)
              SettingsRow(
                label: l.subjectDelete,
                destructive: true,
                trailing: SettingsRowTrailing.none,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  runWrite(
                    context,
                    () => repository.deleteEmptySubject(subject.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final name = await showNamePrompt(
      context,
      title: l.subjectRename,
      hint: l.subjectNameHint,
      initialValue: subject.name,
    );
    if (name == null || !context.mounted) return;
    await runWrite(
      context,
      () => ref
          .read(studyRepositoryProvider)
          .renameSubject(subjectId: subject.id, name: name),
    );
  }
}
