import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/formatting.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'icon_motion.dart';
import 'pressable.dart';
import 'reduced_motion.dart';

/// A 24px round checkbox: white with a grey ring when off, solid black with a
/// white tick when on. The label fades to grey once ticked, so a completed
/// list reads as quieter rather than louder.
class AtherCheckbox extends StatelessWidget {
  const AtherCheckbox({
    super.key,
    required this.checked,
    required this.label,
    required this.onTap,
  });

  final bool checked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: <Widget>[
            // The disc closes inward from the rim, then takes the tick. What
            // would read as a step half-done is a fill that *rises*; this one
            // never shows a level.
            DecoratedBox(
              // The empty box's own background. The accent fill is painted by
              // the disc itself, as it closes.
              decoration: BoxDecoration(
                color: context.colors.card,
                shape: BoxShape.circle,
              ),
              child: CompletionDisc(
                done: checked,
                size: AppSizes.checkbox,
                fill: context.colors.accent,
                ring: context.colors.checkboxBorder,
                ringWidth: 1.8,
                tickSize: 14,
                tickColor: context.colors.onAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              // The label's colour is a tween, not a swap: the same text before
              // and after, only less loud.
              child: AnimatedDefaultTextStyle(
                duration: prefersReducedMotion(context)
                    ? Duration.zero
                    : AppMotion.micro,
                curve: AppMotion.standard,
                style: AppTypography.style(
                  size: 15.5,
                  weight: AppTypography.medium,
                  color: checked
                      ? context.colors.textSecondary
                      : context.colors.textPrimary,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 50x30 switch. Green when on with the knob at the **end** of the track —
/// which under RTL is the physical left, so the control is forced LTR: a
/// switch is a physical metaphor, and mirroring it makes "on" look like "off".
class AtherSwitch extends StatelessWidget {
  const AtherSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);

    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Ltr(
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : AppMotion.press,
            curve: Curves.easeOut,
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              color: value ? context.colors.right : context.colors.switchOff,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: AnimatedAlign(
              duration: reduced ? Duration.zero : AppMotion.press,
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: context.colors.switchKnob,
                  shape: BoxShape.circle,
                  // The one shadow the design allows anywhere in the app: a
                  // knob with no lift reads as a painted dot, not a control.
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The two-option language control on the settings screen.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: context.colors.fill,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? context.colors.accent
                        : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: AppTypography.style(
                      size: 14,
                      weight: AppTypography.bold,
                      color: i == selectedIndex
                          ? context.colors.onAccent
                          : context.colors.textSecondary,
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

/// A plain text field in the app's one input shape: a muted rounded box with
/// no border, no underline and no floating label.
///
/// The label sits above the box rather than inside it — a Material floating
/// label animates over the text and reads as noise in an interface that has no
/// other moving chrome.
class AtherTextField extends StatelessWidget {
  const AtherTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.style(
            size: 12.5,
            weight: AppTypography.semiBold,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: context.colors.muted,
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.lg,
            end: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  autofillHints: autofillHints,
                  autofocus: autofocus,
                  onSubmitted: onSubmitted,
                  onChanged: onChanged,
                  style: AppTypography.body,
                  cursorColor: context.colors.textPrimary,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: hint,
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
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// A digits-only field.
///
/// Forced LTR with centred text and filtered to `[0-9]`, so a student typing a
/// score cannot produce Arabic-Indic digits, a minus sign or a decimal point
/// that the parser would then have to guess at.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    this.height = AppSizes.input,
    this.fill,
    this.textStyle,
    this.radius = AppRadius.input,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.maxLength = 4,
    this.hint,
  });

  final TextEditingController controller;
  final double height;

  /// Null means the theme's muted fill.
  final Color? fill;
  final TextStyle? textStyle;
  final double radius;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLength;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Ltr(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: fill ?? context.colors.muted,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: _BareNumberInput(
          controller: controller,
          style: textStyle ?? AppTypography.input,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          maxLength: maxLength,
          hint: hint,
        ),
      ),
    );
  }
}

/// The bare text field used inside [NumberField] — no Material decoration, no
/// underline, no counter.
class _BareNumberInput extends StatelessWidget {
  const _BareNumberInput({
    required this.controller,
    required this.style,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.maxLength = 4,
    this.hint,
  });

  final TextEditingController controller;
  final TextStyle style;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLength;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(signed: false),
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.center,
      style: style,
      cursorColor: context.colors.textPrimary,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        hintText: hint,
        hintStyle: style.copyWith(color: context.colors.textNoData),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        counterText: '',
      ),
    );
  }
}
