import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

/// The one container in the app.
///
/// A flat white rectangle with a 16 radius, **no border and no shadow**. The
/// white against the `#EFEFF2` page *is* the elevation -- that is the entire
/// depth system, which is why nothing here accepts an elevation or a border
/// colour. The old glass treatment (blur + translucent fill + hairline) is
/// gone.
class AtherCard extends StatelessWidget {
  const AtherCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.onLongPress,
    this.color,
  }) : _muted = false;

  /// The quieter variant used by the homework card, which is deliberately the
  /// least important thing on the lesson screen.
  const AtherCard.muted({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.onLongPress,
  }) : color = null,
       _muted = true;

  final Widget child;
  final double padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// An explicit override. Null means "whichever surface this variant is",
  /// resolved from the theme at build time -- a card colour cannot be a
  /// constant now that there are two of them.
  final Color? color;

  /// Set by [AtherCard.muted]. Carried as a flag rather than as a baked colour
  /// so the quieter surface still follows the theme.
  final bool _muted;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final card = Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color ?? (_muted ? c.muted : c.card),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}

/// "المواد" · "الأبواب" · "الدروس" — 22/700 with a 2px optical inset so the
/// text lines up with the card content beside it rather than the card edge.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(text, style: AppTypography.sectionTitle)),
          ?trailing,
        ],
      ),
    );
  }
}

/// A hairline between rows inside a single card.
class CardDivider extends StatelessWidget {
  const CardDivider({super.key, this.strong = false});

  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: strong ? context.colors.dividerStrong : context.colors.divider,
  );
}
