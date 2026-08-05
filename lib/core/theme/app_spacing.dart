import 'package:flutter/animation.dart';

/// The spacing scale: 4 · 8 · 10 · 12 · 14 · 16 · 18 · 22 · 24.
///
/// Anything that needs a value off this ladder is a sign the layout is wrong,
/// not that the ladder is missing a rung.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 18;

  /// Gap between two sections on the same screen.
  static const double section = 22;
  static const double xxxl = 24;

  /// Horizontal page margin on every screen.
  static const double pageMargin = 16;

  /// Card padding: 16 in lists, 18 on dashboard and detail summaries.
  static const double cardPadding = 16;
  static const double cardPaddingLarge = 18;

  /// Vertical gap between consecutive cards in a list.
  static const double listGap = 10;
}

/// Corner radii.
///
/// Concentric rule: an inner element's radius is its container's radius minus
/// the padding between them -- a 16 card with 16 padding holds a ~10 inner
/// shape, not another 16.
abstract final class AppRadius {
  /// Cards and list rows.
  static const double card = 16;

  /// Primary buttons, the toast, the big result field.
  static const double button = 14;

  /// Inner input fields and the segmented control.
  static const double input = 12;

  /// Inner icon squares inside a padded card.
  static const double inner = 10;

  /// Top corners of a bottom sheet.
  static const double sheet = 22;

  /// A 36x36 circular header button.
  static const double headerButton = 18;

  /// The 56x56 floating action button.
  static const double fab = 28;

  /// Chips, pills, day circles, the switch.
  static const double pill = 999;
}

/// Fixed control sizes, so a button is never 51px on one screen and 53 on
/// another.
abstract final class AppSizes {
  static const double primaryButton = 52;
  static const double headerButton = 36;
  static const double fab = 56;

  // --- The floating tab bar -------------------------------------------------
  // Four numbers with one relationship between them. They are written once and
  // derived from each other rather than typed at each call site, because the
  // toast's position and the body's bottom padding both depend on where the top
  // of this bar actually lands.

  /// How far the pill sits clear of the bottom of the screen, on top of
  /// whatever system inset is already there.
  static const double barLift = 12;

  /// The pill's own height: a ~47px tab (25 icon + 4 gap + label) with room
  /// around it.
  static const double barHeight = 64;

  /// How far the "+" rises above the pill's top edge. Enough to read as raised;
  /// not so much that the pill stops looking like it is holding it.
  static const double fabOverhang = 20;

  /// The FAB's offset above the pill's bottom edge — derived, so the overhang
  /// above is what is actually being chosen.
  static const double fabLift = barHeight + fabOverhang - fab;

  /// Where the black confirmation toast is pinned, **above the system inset**.
  ///
  /// Load-bearing rather than a taste decision. The toast is the one black
  /// surface in the app; under the bar's 0.72 white tint it would drop the
  /// inactive tab label to 1.5:1, and against the opaque black FAB it would be
  /// black on black. So it clears the whole assembly. The 16 is breathing room:
  /// the toast must not kiss the FAB.
  static const double toastBottom = barLift + barHeight + fabOverhang + 16;

  static const double input = 46;
  static const double inputTall = 50;
  static const double bigNumberField = 72;

  static const double barTrack = 8;
  static const double barTrackSmall = 6;

  static const double weekCircle = 34;
  static const double checkbox = 24;
}

/// Motion. Every duration and curve in the app comes from here.
abstract final class AppMotion {
  /// Press feedback on any tappable element: `scale(.97)`.
  static const double pressScale = 0.97;
  static const Duration press = Duration(milliseconds: 140);
  static const Curve pressCurve = Cubic(0.34, 1.4, 0.64, 1);

  /// A bottom sheet sliding up.
  static const Duration sheet = Duration(milliseconds: 280);
  static const Curve sheetCurve = Cubic(0.22, 1, 0.36, 1);

  /// The single celebration pop, with a small overshoot.
  static const Duration celebration = Duration(milliseconds: 500);
  static const Curve celebrationCurve = Cubic(0.34, 1.56, 0.64, 1);

  /// Bars and numbers settling into place.
  static const Duration value = Duration(milliseconds: 600);
  static const Curve valueCurve = Curves.easeOutCubic;

  /// How long the confirmation toast stays on screen.
  static const Duration toast = Duration(milliseconds: 2200);

  // ---------------------------------------------------------------------------
  // Motion system v1.1. Everything below is one ease-out and a set of durations
  // under 300ms, because 180ms reads as more responsive than 400ms and this app
  // is opened twenty times a day.
  // ---------------------------------------------------------------------------

  /// The one ease-out every animation added by the motion spec uses.
  ///
  /// Never `ease-in` on interface motion: it starts slow and delays the exact
  /// moment the student is watching.
  static const Curve standard = Cubic(0.23, 1, 0.32, 1);

  /// Route push/pop. The incoming page fades in and rises [pageRise].
  ///
  /// Vertical, so Arabic and English are byte-identical -- a horizontal slide
  /// is the one thing that can go the wrong way in an RTL app.
  static const Duration page = Duration(milliseconds: 220);
  static const double pageRise = 8;

  /// Tab cross-fade and the tab-bar colour tween. The shortest duration in the
  /// app, because it is the interaction that happens most.
  static const Duration nav = Duration(milliseconds: 150);

  /// A row entering a list, and the delay between consecutive rows.
  ///
  /// [staggerCap] exists because a student with forty lessons must not wait
  /// through forty delays.
  static const Duration enter = Duration(milliseconds: 260);
  static const double enterRise = 12;
  static const Duration stagger = Duration(milliseconds: 40);
  static const int staggerCap = 6;

  /// A row leaving. Exits are shorter than entrances.
  static const Duration exit = Duration(milliseconds: 200);

  /// Wizard step change, and its progress segment.
  static const Duration step = Duration(milliseconds: 200);
  static const double stepRise = 10;
  static const Duration segment = Duration(milliseconds: 250);

  /// Small in-place changes: toast in, error banner, checkbox.
  static const Duration micro = Duration(milliseconds: 180);
  static const double microRise = 6;
  static const double toastRise = 12;

  /// Anything leaving in place. The eye has already moved on.
  static const Duration microOut = Duration(milliseconds: 150);

  /// A badge or tick appearing. Never overshoots past 1.0 -- a badge that
  /// bounces reads as a notification begging to be tapped.
  static const Duration pop = Duration(milliseconds: 200);
  static const Duration tick = Duration(milliseconds: 220);

  /// The wizard's before → arrow → after card, read as a sentence rather than
  /// three numbers landing at once. The "before" value starts at 0.
  static const Duration beforeAfterArrowDelay = Duration(milliseconds: 60);
  static const Duration beforeAfterValueDelay = Duration(milliseconds: 120);

  /// The one [BackdropFilter] in the app, on the tab bar. See PROJECT.md
  /// §3.19: the sigma is never animated, and the tint is a floor, not a
  /// starting point.
  static const double glassSigma = 24;
  static const double glassTint = 0.72;
}
