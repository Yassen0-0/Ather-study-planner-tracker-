import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
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

  /// The longest name this prompt will accept.
  ///
  /// **It must not exceed the column the value is written to.** The default of
  /// 80 suits chapters (120), lessons (160) and task titles (200), all of which
  /// sit above it. `subjects.name` is 60, and for the life of this prompt the
  /// three subject call sites used the default -- so a name of 61 to 80
  /// characters was accepted here, refused by drift, and surfaced to the student
  /// as the generic write-failure toast with nothing naming the length. Callers
  /// writing to a shorter column pass its limit; see [kSubjectNameMaxLength].
  int maxLength = 80,
}) {
  return showAtherSheet<String>(
    context: context,
    builder: (context) => _NamePromptSheet(
      title: title,
      hint: hint,
      initialValue: initialValue,
      maxLength: maxLength,
    ),
  );
}

class _NamePromptSheet extends StatefulWidget {
  const _NamePromptSheet({
    required this.title,
    required this.hint,
    required this.maxLength,
    this.initialValue,
  });

  final String title;
  final String hint;
  final int maxLength;
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
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.opticalInset,
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
              maxLength: widget.maxLength,
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
                // `md`, not `xl`: this padding plus the 2 above it plus the
                // line box is the field's whole height, and 12 lands it on
                // AppSizes.input -- the height every other input in the app is
                // drawn at. The old 14 was a number that matched nothing.
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
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
          const SizedBox(height: AppSpacing.md),
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
///
/// PH-04 appendix: an affirmative answer here **is** the destructive commit,
/// so it fires [AppHaptics.heavy] once — after the sheet resolves, before any
/// write runs, never on dismiss or cancel. Wiring every confirm through this
/// one seam (rather than at each call site) guarantees exactly one heavy per
/// committed action and covers flows whose screens are owned elsewhere; a
/// caller whose confirmed act deletes nothing passes `heavyOnConfirm: false`.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool heavyOnConfirm = true,
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
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: cancelLabel ?? l.commonCancel,
            tone: PrimaryButtonTone.secondary,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
  final bool confirmed = result ?? false;
  if (confirmed && heavyOnConfirm) AppHaptics.heavy();
  return confirmed;
}
