// Material, for the same one thing buttons.dart imports it for: the ring on a
// busy row.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'ather_card.dart';
import 'ather_controls.dart';
import 'ather_icons.dart';
import 'pressable.dart';

/// A titled block of settings rows, drawn as one surface.
///
/// Settings used to be nine free-standing [AtherCard]s in a column, each with
/// its own height, its own internal layout and its own idea of what a control
/// looks like. Nothing grouped, so the page read as a pile: a student scanning
/// for "notifications" had to read every card to find out none of them was a
/// list.
///
/// This is the shape every large app converges on for the same reason — a
/// heading, then rows of one height, with the differences between rows carried
/// by what sits at their trailing edge rather than by the shape of the card
/// around them. It is deliberately **not** [AtherCard]: a card owns its own
/// padding, and rows need to reach the full width so their dividers can be
/// inset from the text rather than from the surface.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  /// Omitted for the first group on a page, where the screen title is already
  /// doing the work, and for the closing block of destructive rows, which is
  /// named by its position and its colour instead.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(
              right: AppSpacing.xl,
              left: AppSpacing.xl,
              bottom: AppSpacing.xs,
            ),
            child: Text(title!, style: context.text.groupHeading),
          ),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < children.length; i++) ...<Widget>[
                // Inset to the row's text, not to the surface. A hairline that
                // runs the full width cuts the block into separate cards again,
                // which is the look this replaced.
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.cardPadding,
                    ),
                    child: CardDivider(),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// What sits at the end of a [SettingsRow].
enum SettingsRowTrailing {
  /// Opens something: a screen, or a sheet that asks a question.
  chevron,

  /// The row is the action. Nothing to point at.
  none,
}

/// One row inside a [SettingsGroup].
///
/// A label, an optional current value, and one trailing element. The value is
/// what lets the top level stay short: a row reading "المظهر · فاتح" answers
/// the question without spending a segmented control on it, and the control
/// itself lives one tap away where there is room for it.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.onTap,
    this.trailing = SettingsRowTrailing.chevron,
    this.destructive = false,
    this.busy = false,
  }) : toggle = null,
       onToggle = null;

  /// A row whose whole purpose is a boolean. The switch is the control and the
  /// row is its label, so tapping anywhere on the row flips it.
  const SettingsRow.toggle({
    super.key,
    required this.label,
    required bool this.toggle,
    required ValueChanged<bool> this.onToggle,
  }) : value = null,
       onTap = null,
       trailing = SettingsRowTrailing.none,
       destructive = false,
       busy = false;

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final SettingsRowTrailing trailing;

  /// Red label. Defined here rather than per call site so that "destructive"
  /// is one decision in one file — the app has had a big red slab standing in
  /// for it, which is a different and much louder thing.
  final bool destructive;

  /// A write is in flight. Same meaning and the same ring as a busy
  /// [PrimaryButton]: deleting an account runs five awaits against two
  /// services, and a row that swallows the tap and then sits there for four
  /// seconds is indistinguishable from one that is broken.
  final bool busy;

  final bool? toggle;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isToggle = toggle != null;

    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        // A toggle's switch occupies a full 48-point target around its
        // 30-point track (see AtherSwitch); the padding gives back the
        // difference so the row keeps the height every other row has.
        vertical: isToggle
            ? AppSpacing.xl - (kMinTarget - AtherSwitch.trackHeight) / 2
            : AppSpacing.xl,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppTypography.cardLabel.copyWith(
                color: destructive ? colors.wrong : colors.textPrimary,
              ),
            ),
          ),
          if (value != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                value!,
                style: context.text.secondary,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (busy) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: destructive ? colors.wrong : colors.textSecondary,
              ),
            ),
          ] else if (isToggle) ...<Widget>[
            const SizedBox(width: AppSpacing.xl),
            AtherSwitch(
              value: toggle!,
              semanticLabel: label,
              onChanged: onToggle!,
            ),
          ] else if (trailing == SettingsRowTrailing.chevron) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            AtherIcon(
              AtherGlyph.chevron,
              size: 18,
              color: colors.textTertiary,
            ),
          ],
        ],
      ),
    );

    if (isToggle) {
      return Pressable(onTap: () => onToggle!(!toggle!), child: row);
    }
    if (onTap == null || busy) return row;
    return Pressable(onTap: onTap, child: row);
  }
}

/// The quiet line that closes a settings page — the version, and anything else
/// that is a fact rather than a control.
class SettingsFootnote extends StatelessWidget {
  const SettingsFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Text(
        text,
        style: context.text.micro,
        textAlign: TextAlign.center,
      ),
    );
  }
}
