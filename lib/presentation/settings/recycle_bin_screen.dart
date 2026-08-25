import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/formatting.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_scaffold.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/settings_list.dart';
import '../../domain/entities/study_snapshot.dart';
import '../../domain/entities/subject.dart';
import '../common/prompts.dart';
import '../common/subject_mark.dart';
import '../common/subject_presentation.dart';
import '../common/write_guard.dart';
import '../providers/app_providers.dart';

/// Subjects the student deleted, kept whole until they say otherwise.
///
/// Deleting a subject sets a flag. Nothing beneath it is touched, so what sits
/// here is the entire subject — its chapters, its lessons, every exam ever
/// recorded in it — and restoring puts all of it back exactly as it was.
///
/// **Nothing here expires.** A recycle bin that empties itself after thirty
/// days is a bin that destroys a student's exam history while they are not
/// looking, and the one promise this app makes about their record is that it
/// does not do that. It empties when they empty it.
///
/// This screen holds the only irreversible operation in the subjects feature.
/// `Chapters.subjectId` cascades, so a permanent delete takes everything
/// underneath — which is why both destructive controls here name what goes,
/// with counts, before they run.
class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final snapshot = ref.watch(snapshotValueProvider);
    final deleted = snapshot.deletedSubjects;

    if (deleted.isEmpty) {
      return AtherScreen(
        header: AtherHeader(title: l.binTitle, onBack: () => context.pop()),
        children: <Widget>[EmptyState(title: l.binEmpty)],
      );
    }

    return AtherScreen(
      header: AtherHeader(title: l.binTitle, onBack: () => context.pop()),
      children: <Widget>[
        SettingsGroup(
          children: <Widget>[
            for (final subject in deleted)
              _DeletedRow(subject: subject, snapshot: snapshot),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsFootnote(l.binNote),
        const SizedBox(height: AppSpacing.xxxl),
        SettingsGroup(
          children: <Widget>[
            SettingsRow(
              label: l.binEmptyAll,
              destructive: true,
              trailing: SettingsRowTrailing.none,
              onTap: () => _emptyAll(context, ref, snapshot),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _emptyAll(
    BuildContext context,
    WidgetRef ref,
    StudySnapshot snapshot,
  ) async {
    final l = L.of(context);
    // Counted at tap time from the snapshot this very build rendered from, so
    // the numbers cannot drift from what is on screen.
    final counts = _purgeCounts(snapshot, snapshot.deletedSubjects);
    final confirmed = await confirmDestructive(
      context,
      title: l.binEmptyAll,
      // "كل ما في السلة" named no sizes; a student confirming an empty-all
      // deserves the same counted sentence the single purge always had.
      message:
          '${l.binEmptyAllConfirm}\n'
          '${l.purgeCountsLine(counts.subjects, counts.chapters, counts.lessons, counts.exams)}',
      confirmLabel: l.binEmptyAll,
    );
    if (!confirmed || !context.mounted) return;

    final repository = ref.read(studyRepositoryProvider);
    await runWrite(context, () async {
      for (final subject in snapshot.deletedSubjects) {
        await repository.purgeSubject(subject.id);
      }
    });
  }
}

/// What purging [subjects] takes with it, counted from [snapshot].
///
/// The purge confirmations are the last thing a student reads before the
/// cascade fires, so they carry the whole size of the decision — chapters,
/// lessons, exams — rather than gesturing at "everything underneath".
({int subjects, int chapters, int lessons, int exams}) _purgeCounts(
  StudySnapshot snapshot,
  Iterable<Subject> subjects,
) {
  var chapters = 0;
  var lessons = 0;
  var exams = 0;
  for (final subject in subjects) {
    final subjectChapters = snapshot.chaptersIn(subject.id);
    chapters += subjectChapters.length;
    for (final chapter in subjectChapters) {
      final chapterLessons = snapshot.lessonsIn(chapter.id);
      lessons += chapterLessons.length;
      for (final lesson in chapterLessons) {
        exams += snapshot.examsFor(lesson.id).length;
      }
    }
  }
  return (
    subjects: subjects.length,
    chapters: chapters,
    lessons: lessons,
    exams: exams,
  );
}

/// One deleted subject: what it is, when it went, and how much is inside it.
///
/// The counts are the point. "استرجاع" is safe and needs no explanation, but
/// "حذف نهائي" is the cascade firing, and a student cannot weigh that without
/// being told that this row is standing in for three chapters and eleven exams.
class _DeletedRow extends ConsumerWidget {
  const _DeletedRow({required this.subject, required this.snapshot});

  final Subject subject;
  final StudySnapshot snapshot;

  ({int subjects, int chapters, int lessons, int exams}) get _counts =>
      _purgeCounts(snapshot, <Subject>[subject]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final counts = _counts;

    return Pressable(
      onTap: () => _open(context, ref, counts),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    subject.label(l),
                    style: AppTypography.cardLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${l.binDeletedAt(dateLabel(subject.deletedAt!))} · '
                    '${l.chapterCount(counts.chapters)}',
                    style: context.text.sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ({int subjects, int chapters, int lessons, int exams}) counts,
  ) async {
    final l = L.of(context);
    final repository = ref.read(studyRepositoryProvider);

    await showAtherSheet<void>(
      context: context,
      builder: (sheetContext) => AtherSheetBody(
        title: subject.label(l),
        child: SettingsGroup(
          children: <Widget>[
            SettingsRow(
              label: l.binRestore,
              trailing: SettingsRowTrailing.none,
              onTap: () {
                Navigator.of(sheetContext).pop();
                runWrite(
                  context,
                  () => repository.setSubjectDeleted(
                    subjectId: subject.id,
                    at: null,
                  ),
                );
              },
            ),
            SettingsRow(
              label: l.binPurge,
              destructive: true,
              trailing: SettingsRowTrailing.none,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (!context.mounted) return;
                final confirmed = await confirmDestructive(
                  context,
                  title: l.binPurge,
                  // Counted, not gestured at. "This cannot be undone" is a
                  // sentence a student has read a hundred times; the counts
                  // are the thing they are actually deciding about. The
                  // counted line carries all four sizes — including the
                  // lessons and exams the row above only hints at.
                  message:
                      '${l.binPurgeConfirm(subject.label(l), l.chapterCount(counts.chapters), l.examCountLabel(counts.exams))}\n'
                      '${l.purgeCountsLine(counts.subjects, counts.chapters, counts.lessons, counts.exams)}',
                  confirmLabel: l.binPurge,
                );
                if (!confirmed || !context.mounted) return;
                await runWrite(
                  context,
                  () => repository.purgeSubject(subject.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
