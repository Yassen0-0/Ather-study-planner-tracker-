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

/// The name prompt's one validity rule: after trimming whitespace and
/// stripping every character with no visible form, something must remain.
///
/// `trim().isNotEmpty` -- what this sheet used to ask -- answers "does the
/// string contain code points", not "does it contain content". The zero-width
/// space (U+200B), the LRM/RLM marks (U+200E/U+200F), the directional
/// isolates this app's own number formatting emits (U+2066-U+2069) and the
/// tatweel (ـ U+0640) are all real characters with no ink, and each of them
/// sailed past a trim. A name built only from those was saved as non-empty,
/// then rendered in a lesson header as an apparently-blank row.
///
/// What is *saved* is still exactly what the student typed -- see
/// `DriftStudyRepository._matchKey` for why normalising stored names rewrites
/// a choice the student made. This gate decides validity only.
///
/// Composition order matters: strip first, **then** trim. Trimming first lets
/// plain spaces hide between the invisibles and pass for content.
bool _nameHasVisibleContent(String raw) {
  final visible = StringBuffer();
  for (final rune in raw.runes) {
    if (!_isFormattingOrTatweel(rune)) visible.writeCharCode(rune);
  }
  // The sheet's original blank rule, now applied to what can actually be seen.
  return visible.toString().trim().isNotEmpty;
}

/// Unicode category Cf -- format characters, invisible by definition -- plus
/// the tatweel, which is category Lo but invisible for a name's purposes:
/// it stretches neighbouring letters and carries no content of its own.
bool _isFormattingOrTatweel(int rune) {
  if (rune == 0x0640) return true; // ـ tatweel
  return switch (rune) {
    0x00AD || // soft hyphen
    0x061C || // Arabic letter mark
    0x180E || // Mongolian vowel separator
    0xFEFF || // zero-width no-break space / BOM
    >= 0x200B && <= 0x200F || // ZWSP ZWNJ ZWJ LRM RLM
    >= 0x202A && <= 0x202E || // LRE RLE PDF LRO RLO
    >= 0x2060 && <= 0x2064 || // word joiner, invisible operators
    >= 0x2066 && <= 0x2069 || // LRI RLI FSI PDI
    >= 0xFFF9 && <= 0xFFFB // interlinear annotation anchors
    => true,
    _ => false,
  };
}

class _NamePromptSheetState extends State<_NamePromptSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late bool _valid = _nameHasVisibleContent(_controller.text);

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
    //
    // The gate is [_nameHasVisibleContent], not isEmpty: a string of zero-width
    // and direction-mark characters trims to non-empty and used to pass here,
    // reach drift, and come back out of the database looking blank.
    if (!_nameHasVisibleContent(value)) {
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
                final valid = _nameHasVisibleContent(value);
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
