import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_controls.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/pressable.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/scheduled_exam.dart';
import '../../domain/entities/subject.dart';
import '../common/write_guard.dart';
import '../providers/app_providers.dart';

/// Shows a form for creating or editing a scheduled exam.
///
/// The form collects:
/// - Subject (required)
/// - Title (required)
/// - Date (required)
/// - Chapters (optional, but recommended)
/// - Notes (optional)
Future<void> showScheduledExamForm(
  BuildContext context, {
  ScheduledExam? existing,
}) {
  return showAtherSheet<void>(
    context: context,
    builder: (context) => _ScheduledExamFormSheet(existing: existing),
  );
}

class _ScheduledExamFormSheet extends ConsumerStatefulWidget {
  const _ScheduledExamFormSheet({this.existing});

  final ScheduledExam? existing;

  @override
  ConsumerState<_ScheduledExamFormSheet> createState() =>
      _ScheduledExamFormSheetState();
}

class _ScheduledExamFormSheetState
    extends ConsumerState<_ScheduledExamFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  int? _selectedSubjectId;
  DateTime? _selectedDate;
  Set<int> _selectedChapterIds = <int>{};
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title);
    _notesController = TextEditingController(text: existing?.notes);

    if (existing != null) {
      _selectedSubjectId = existing.subjectId;
      _selectedDate = existing.date;
      _selectedChapterIds = existing.chapterIds.toSet();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _selectedSubjectId != null &&
      _titleController.text.trim().isNotEmpty &&
      _selectedDate != null;

  List<String> get _errors {
    final errors = <String>[];
    if (_selectedSubjectId == null) errors.add('Subject is required');
    if (_titleController.text.trim().isEmpty) errors.add('Title is required');
    if (_selectedDate == null) errors.add('Date is required');
    return errors;
  }

  Future<void> _pickDate() async {
    final now = ref.read(nowValueProvider);
    final initialDate = _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.colors.accent,
              onPrimary: context.colors.onAccent,
              surface: context.colors.card,
              onSurface: context.colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _submit() async {
    if (!_isValid) {
      setState(() => _showErrors = true);
      return;
    }

    final repository = ref.read(scheduledExamRepositoryProvider);
    final clock = ref.read(clockProvider);
    final navigator = Navigator.of(context);

    try {
      if (widget.existing != null) {
        await runWrite(
          context,
          () => repository.updateScheduledExam(
            id: widget.existing!.id,
            subjectId: _selectedSubjectId!,
            date: _selectedDate!,
            title: _titleController.text.trim(),
            chapterIds: _selectedChapterIds.toList(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        );
      } else {
        await runWrite(
          context,
          () => repository.createScheduledExam(
            subjectId: _selectedSubjectId!,
            date: _selectedDate!,
            title: _titleController.text.trim(),
            chapterIds: _selectedChapterIds.toList(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            at: clock.now(),
          ),
        );
      }
      navigator.pop();
    } catch (e) {
      // runWrite handles error display
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final snapshot = ref.watch(snapshotValueProvider);
    final activeSubjects = snapshot.activeSubjects;

    final selectedSubject = _selectedSubjectId == null
        ? null
        : activeSubjects.cast<Subject?>().firstWhere(
              (s) => s?.id == _selectedSubjectId,
              orElse: () => null,
            );

    final availableChapters = selectedSubject == null
        ? <Chapter>[]
        : (snapshot.chaptersBySubject[selectedSubject.id] ?? <Chapter>[]);

    return AtherSheetBody(
      title: widget.existing == null ? 'Schedule Exam' : 'Edit Scheduled Exam',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Subject picker
          Text('Subject', style: context.text.fieldLabel),
          const SizedBox(height: AppSpacing.textGap),
          _SubjectPicker(
            subjects: activeSubjects,
            selected: selectedSubject,
            onSelect: (subject) {
              setState(() {
                _selectedSubjectId = subject.id;
                // Clear chapter selection when subject changes
                _selectedChapterIds.clear();
              });
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Title field
          AtherTextField(
            controller: _titleController,
            label: 'Title',
            hint: 'e.g. Biology Midterm',
            autofocus: widget.existing == null,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Date picker
          Text('Date', style: context.text.fieldLabel),
          const SizedBox(height: AppSpacing.textGap),
          Pressable(
            onTap: _pickDate,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.muted,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _selectedDate == null
                        ? 'Select exam date'
                        : _formatDate(_selectedDate!),
                    style: AppTypography.body.copyWith(
                      color: _selectedDate == null
                          ? context.colors.textNoData
                          : context.colors.textPrimary,
                    ),
                  ),
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: context.colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Chapter multi-select
          if (availableChapters.isNotEmpty) ...<Widget>[
            Text('Chapters (optional)', style: context.text.fieldLabel),
            const SizedBox(height: AppSpacing.textGap),
            Container(
              decoration: BoxDecoration(
                color: context.colors.muted,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (final chapter in availableChapters)
                      AtherCheckbox(
                        checked: _selectedChapterIds.contains(chapter.id),
                        label: chapter.name,
                        onTap: () {
                          setState(() {
                            if (_selectedChapterIds.contains(chapter.id)) {
                              _selectedChapterIds.remove(chapter.id);
                            } else {
                              _selectedChapterIds.add(chapter.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Notes field
          AtherTextField(
            controller: _notesController,
            label: 'Notes (optional)',
            hint: 'e.g. Covers chapters 1-3',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),

          // Error display
          if (_showErrors && !_isValid) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            for (final error in _errors) ErrorBanner(message: error),
          ],

          const SizedBox(height: AppSpacing.xxl),

          // Save button
          PrimaryButton(
            label: l.commonSave,
            tone: _isValid
                ? PrimaryButtonTone.primary
                : PrimaryButtonTone.unearned,
            onTap: _submit,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = ref.read(nowValueProvider);
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == tomorrow) return 'Tomorrow';

    // Format as "Sat, 21 Aug 2026"
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, ${date.day} $month ${date.year}';
  }
}

/// Subject picker dropdown/selector.
class _SubjectPicker extends StatelessWidget {
  const _SubjectPicker({
    required this.subjects,
    required this.selected,
    required this.onSelect,
  });

  final List<Subject> subjects;
  final Subject? selected;
  final ValueChanged<Subject> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.muted,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: <Widget>[
          for (final subject in subjects)
            Pressable(
              onTap: () => onSelect(subject),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected?.id == subject.id
                            ? context.colors.accent
                            : Colors.transparent,
                        border: Border.all(
                          color: selected?.id == subject.id
                              ? context.colors.accent
                              : context.colors.checkboxBorder,
                          width: 2,
                        ),
                      ),
                      child: selected?.id == subject.id
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: context.colors.onAccent,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _SubjectLabel(subject: subject),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Subject label widget that uses L.of(context) to get localized subject names.
class _SubjectLabel extends StatelessWidget {
  const _SubjectLabel({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final label = subject.code != null
        ? _getSeededLabel(l, subject.code!)
        : subject.name ?? '';
    return Text(label, style: AppTypography.body);
  }

  String _getSeededLabel(L l, SubjectCode code) {
    return switch (code) {
      SubjectCode.biology => l.subjectBiology,
      SubjectCode.physics => l.subjectPhysics,
      SubjectCode.chemistry => l.subjectChemistry,
      SubjectCode.english => l.subjectEnglish,
    };
  }
}
