import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';
import 'reduced_motion.dart';

/// Why: three things in this app *appear* rather than change -- an overdue
/// badge, a completed day, a ticked step. They all enter identically and none
/// of them overshoots: a badge that bounces reads as a notification begging to
/// be tapped, and this app does not beg.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.duration = AppMotion.pop});

  final Widget child;
  final Duration duration;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    // Started here, not lazily in the field: under reduced motion `build`
    // returns the child untouched and never reads the controller, so a lazy
    // one would first come into existence inside dispose() -- on an element
    // that has already been deactivated.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) return widget.child;

    // 0.6 -> 1, never 0 -> 1: scaling from nothing draws the eye to the motion
    // rather than to the thing that appeared.
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.standard),
      ),
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}
