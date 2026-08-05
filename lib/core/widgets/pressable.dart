import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';
import 'reduced_motion.dart';

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
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;

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

    return GestureDetector(
      behavior: widget.behavior,
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
  }
}
