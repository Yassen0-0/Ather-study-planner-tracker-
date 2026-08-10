import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_sheet.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_banner.dart';

/// Asks for a single line of text — a chapter or lesson name.
///
/// Always a bottom sheet, on every window size. The old build switched to a
/// dialog on desktop; the redesign has exactly one modal shape, and a second
/// one that only some students ever see is a second thing to keep consistent
/// for no gain.
Future<String?> showNamePrompt(
  BuildContext context, {
  required String title,
  required String hint,
  String? initialValue,
}) {
  return showAtherSheet<String>(
    context: context,
    builder: (context) =>
        _NamePromptSheet(title: title, hint: hint, initialValue: initialValue),
  );
}

class _NamePromptSheet extends StatefulWidget {
  const _NamePromptSheet({
    required this.title,
    required this.hint,
    this.initialValue,
  });

  final String title;
  final String hint;
  final String? initialValue;

  @override
  State<_NamePromptSheet> createState() => _NamePromptSheetState();
}

class _NamePromptSheetState extends State<_NamePromptSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late bool _valid = _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _showError = false;

  void _submit() {
    final value = _controller.text.trim();
    // Was a bare `return`, which swallowed the tap in silence -- the exact thing
    // the comment on the button below says this app never does, and the
    // opposite of what the homework sheet does with the same problem.
    if (value.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AtherSheetBody(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: context.colors.muted,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 2,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (value) {
                final valid = value.trim().isNotEmpty;
                if (valid != _valid) setState(() => _valid = valid);
              },
              style: AppTypography.body,
              cursorColor: context.colors.textPrimary,
              maxLength: 80,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                counterText: '',
                hintText: widget.hint,
                hintStyle: AppTypography.body.copyWith(
                  color: context.colors.textNoData,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                ),
              ),
            ),
          ),
          if (_showError && !_valid) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ErrorBanner(message: l.nameRequired),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: l.commonSave,
            // Stays tappable while empty, matching the rest of the app: no
            // greyed-out control, and no tap swallowed without the student
            // learning why.
            tone: _valid
                ? PrimaryButtonTone.primary
                : PrimaryButtonTone.unearned,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

/// The pencil in a chapter or lesson header.
///
/// Rename and delete live here rather than on every row in the list above:
/// the design's rows are information, and hanging an edit affordance off each
/// one turns a scannable list into a control panel.
Future<void> showEditSheet(
  BuildContext context, {
  required String title,
  required String renameLabel,
  required String deleteLabel,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) {
  return showAtherSheet<void>(
    context: context,
    builder: (sheetContext) => AtherSheetBody(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrimaryButton(
            label: renameLabel,
            tone: PrimaryButtonTone.secondary,
            onTap: () {
              Navigator.of(sheetContext).pop();
              onRename();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: deleteLabel,
            tone: PrimaryButtonTone.wrong,
            onTap: () {
              Navigator.of(sheetContext).pop();
              onDelete();
            },
          ),
        ],
      ),
    ),
  );
}

/// Destructive confirmation. Deletes cascade, so the copy says exactly what
/// goes with it rather than a bare "are you sure?".
///
/// [confirmLabel] and [cancelLabel] default to "delete" and "cancel" because
/// that is what almost every caller means. The exam wizard's discard prompt is
/// the exception: nothing is being deleted there, so calling the red button
/// "حذف" would describe the wrong act.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final l = L.of(context);
  final result = await showAtherSheet<bool>(
    context: context,
    builder: (context) => AtherSheetBody(
      title: title,
      body: message,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrimaryButton(
            label: confirmLabel ?? l.commonDelete,
            tone: PrimaryButtonTone.wrong,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: cancelLabel ?? l.commonCancel,
            tone: PrimaryButtonTone.secondary,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
