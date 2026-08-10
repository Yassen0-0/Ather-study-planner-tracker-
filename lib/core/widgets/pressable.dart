import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';
import 'reduced_motion.dart';

/// The smallest square a finger can be expected to hit.
///
/// 48dp is both Material's and the WCAG 2.2 target-size floor. Several of
/// Ather's controls are drawn well below it — the 36px header circle used for
/// back, settings and edit on every screen; the 34px day in the week strip; the
/// 17px pencil on a task row — and the drawn size stays exactly as designed.
/// Only the hit area changes.
const double kMinTarget = 48;

/// Press feedback for every tappable surface in the app.
///
/// The design specifies one gesture response and only one: `scale(.97)` over
/// 140ms. There are no ripples, no highlight fills and no colour shifts --
/// Material's ink splash is switched off at the theme level, and this replaces
/// it, so a card, a row, a chip and a button all answer a finger identically.
///
/// Honours the platform's reduce-motion setting by dropping straight to the
/// resting state instead of animating.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    this.minTarget = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;

  /// Required in practice for anything whose only content is an icon.
  ///
  /// Every icon in Ather is a `CustomPaint` (§3.12), which carries no text and
  /// therefore no accessible name at all. Back, the settings cog, the edit
  /// pencil, the wizard's × and — worst of all — the black "+" that is the
  /// app's primary action were each announced by a screen reader as an unnamed
  /// tappable region. A row or a card with real text in it needs nothing here;
  /// its own contents are the label.
  final String? semanticLabel;

  /// The minimum tappable square, whatever the artwork inside measures.
  ///
  /// The design's controls are drawn small on purpose — a 36px header circle, a
  /// 34px day, a 17px pencil — and that is a *visual* decision the touch target
  /// does not have to inherit. Set this to [kMinTarget] on anything small and
  /// the hit area grows around the artwork without moving it.
  ///
  /// **Zero by default, deliberately.** Growing the box shrink-wraps it, which
  /// is exactly wrong for the surfaces that are already big — a full-width card
  /// or primary button would stop filling its row. Those are comfortably over
  /// 48 already, so the opt-in is only ever needed where it actually helps.
  final double minTarget;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool value) {
    if (!_enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);
    final scale = _down && !reduced ? AppMotion.pressScale : 1.0;

    Widget result = GestureDetector(
      behavior: widget.behavior,
      // `GestureDetector` already exposes the tap itself to the semantics tree;
      // what it does not do is say the thing is a *button*. Without the flag a
      // screen reader reads the label and stops, so a student hears the name of
      // a control with no hint that it can be activated.
      excludeFromSemantics: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: scale,
        duration: reduced ? Duration.zero : AppMotion.press,
        curve: AppMotion.pressCurve,
        child: widget.child,
      ),
    );

    // The hit area grows around the artwork without moving it: the child keeps
    // its drawn size and is centred inside a square that a finger can find.
    if (widget.minTarget > 0) {
      result = Center(
        widthFactor: 1,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minTarget,
            minHeight: widget.minTarget,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: result),
        ),
      );
    }

    return Semantics(
      button: _enabled,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: result,
    );
  }
}
