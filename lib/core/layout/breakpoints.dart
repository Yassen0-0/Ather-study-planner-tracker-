import 'package:flutter/widgets.dart';

/// Window size classes.
///
/// Ather is a phone design. It also builds for Windows, and the honest answer
/// there is the same single-column layout with room around it — not a second
/// layout the design never specified. So this file is deliberately small: one
/// question, "is this window phone-width", asked in exactly one place
/// (`AtherScreen`, to decide whether to cap the content width).
///
/// The previous build branched here into a side rail, dialogs and a two-pane
/// master/detail. All three contradicted the tab bar and the single modal
/// shape, so they were removed rather than kept switched off.
enum WindowSize {
  /// Phones. The design's native size.
  compact,

  /// Anything wider: tablets, foldables, desktop windows.
  roomy;

  bool get isCompact => this == WindowSize.compact;
}

abstract final class Breakpoints {
  static const double roomy = 600;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) =>
      width < roomy ? WindowSize.compact : WindowSize.roomy;
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize => Breakpoints.of(this);
}
