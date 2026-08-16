import 'package:flutter/animation.dart';

/// The spacing ladder: 4 · 8 · 12 · 16 · 20 · 24.
///
/// Every rung is a multiple of 4, and the standing rule — anything off this
/// ladder is a sign the layout is wrong, not that the ladder is missing a rung
/// — is now true of the whole of it.
///
/// It used to carry 10, 14, 18 and 22 as well, which made it *two* ladders laid
/// over each other: a 4-grid and a 4+2 grid, with no written rule for which one
/// a given gap belonged to. The rule could therefore only ever be half-applied,
/// and half a rule is what let raw 9s, 11s, 13s and 15s accumulate at call
/// sites — if the ladder already has a value two off the grid, one more is not
/// obviously wrong.
///
/// The names skip `sm` and `lg` on purpose. Those two rungs *were* 10 and 14;
/// deleting the values deleted the names with them, and nothing sits between 8
/// and 12 or between 12 and 16 any more. The gap in the alphabet is the record
/// of the cleanup, not an oversight.
///
/// Every call site that held one of the four removed rungs moved to the nearest
/// surviving one, which is never further than 2 away.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double md = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 24;

  // --- The two values below the ladder --------------------------------------
  // Both are optical rather than structural, and both are here so that they are
  // written once with a reason instead of retyped at thirty call sites. What
  // the eye measures between two lines of type is the space between the *ink*,
  // and the line-height either side has already contributed 3-4 of its own; a
  // gap that is correct on the grid is too open once the leading is counted.

  /// The inset that makes a heading line up with the card content beside it
  /// rather than with the card's edge, and the top nudge under a header.
  ///
  /// Optical alignment: the section title's glyphs start a hair inside its
  /// text box, so matching the box to the card edge leaves the *letters*
  /// looking indented.
  static const double opticalInset = 2;

  /// Between a heading and the sentence it introduces, and the vertical padding
  /// inside a pill whose label already carries its own leading.
  ///
  /// [xxs] closes this up until the two lines read as one block; [xs] opens it
  /// until the sentence stops belonging to the heading.
  static const double textGap = 6;

  // --- Named jobs -----------------------------------------------------------

  /// Horizontal page margin on every screen, and the horizontal padding of both
  /// headers, so a screen title starts on the same vertical as the cards under
  /// it.
  static const double pageMargin = 16;

  /// Card padding. One value: the scale used to carry a second at 18 for
  /// summary cards, and a 2 difference between two cards on the same screen is
  /// not a distinction anyone can see.
  static const double cardPadding = 16;

  /// Vertical gap between consecutive cards in a list.
  static const double listGap = 12;
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

  /// Inner input fields and the segmented control's own box.
  static const double input = 12;

  /// The selected segment inside the segmented control.
  ///
  /// The concentric rule, applied: [input] minus the control's 4 padding. It
  /// was a raw 9 at the call site, which is the rule missed by one.
  static const double segment = 8;

  /// Top corners of a bottom sheet.
  static const double sheet = 22;

  /// Chips, pills, day circles, the switch.
  static const double pill = 999;
}

/// Fixed control sizes, so a button is never 51px on one screen and 53 on
/// another.
abstract final class AppSizes {
  static const double primaryButton = 52;
  static const double headerButton = 36;

  // --- The floating tab bar -------------------------------------------------
  // Two numbers with one relationship between them. They are written once and
  // derived from each other rather than typed at each call site, because the
  // toast's position and the body's bottom padding both depend on where the top
  // of this bar actually lands.

  /// How far the pill sits clear of the bottom of the screen, on top of
  /// whatever system inset is already there. Applied above the pill as well, so
  /// the bar's reserved height is symmetric around it.
  static const double barLift = 12;

  /// The pill's own height: a ~47px tab (25 icon + 4 gap + label) with room
  /// around it.
  static const double barHeight = 64;

  /// Where the black confirmation toast is pinned, **above the system inset**.
  ///
  /// Load-bearing rather than a taste decision. The toast is the one black
  /// surface in the app, and under the bar's 0.72 white tint it would drop the
  /// inactive tab label to 1.5:1. So it clears the whole assembly. The 16 is
  /// breathing room: the toast must not kiss the bar.
  static const double toastBottom = barLift * 2 + barHeight + 16;

  static const double input = 46;
  static const double inputTall = 50;
  static const double bigNumberField = 72;

  /// The grab handle at the top of a bottom sheet. A drawn control, so it is a
  /// size rather than a spacing value; it is here so the stadium's radius is
  /// derived from its height instead of typed as a separate 3.
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 5;

  static const double barTrack = 8;
  static const double barTrackSmall = 6;

  /// The tasks screen's day picker: the whole row, and each cell inside it.
  ///
  /// `kMinTarget` exactly, and that is the point rather than a coincidence. The
  /// week strip this replaced drew a 34px day and grew a 48px hit box around
  /// it, which is how seven cells came to demand 336px on a screen that could
  /// be 288 wide. Here the cell *is* the target: the artwork fills the square a
  /// finger has to find, so the row can drop a pair of days to fit instead of
  /// overflowing.
  static const double dayPicker = 48;

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

  // Gone with the week strip: `weekSnap`/`weekSnapCurve`, which eased a
  // released drag back to a week boundary, and `weekGlowPulse`, one half-cycle
  // of the "come back to today" glow. The day picker commits a drag to a whole
  // day instead of settling a partial offset, so there is nothing to snap; and
  // its glow is a standing sign rather than a pulsing one, which is also how it
  // stopped being a ticker that never lets `pumpAndSettle` return.

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

  /// A ring closing to a solid disc, before the tick lands on it. Shorter than
  /// [tick] because it is the first half of one gesture, not an event of its
  /// own — the two run in sequence and total 340ms.
  static const Duration flood = Duration(milliseconds: 120);

  /// The wizard's before → arrow → after card, read as a sentence rather than
  /// three numbers landing at once. The "before" value starts at 0.
  static const Duration beforeAfterArrowDelay = Duration(milliseconds: 60);
  static const Duration beforeAfterValueDelay = Duration(milliseconds: 120);

  /// The one [BackdropFilter] in the app, on the tab bar. See PROJECT.md
  /// §3.19: the sigma is never animated, and the tint is a floor, not a
  /// starting point.
  static const double glassSigma = 24;

  /// Raised from 0.72 on 2026-08-13, together with a darker `textTertiary`.
  ///
  /// 0.72 was chosen as the floor at which the inactive label still read
  /// against *surfaces*, which is what §3.19 measured. Content drawn on those
  /// surfaces — an analytics column, a mastery fill — is far darker than the
  /// tint, and through the pill those landed at 1.90:1 and 1.91:1.
  ///
  /// Neither lever fixes it alone: at 0.72 the label would have to darken to
  /// #636369, which is `textSecondary` and erases the gap between a tab label
  /// and body text; at 0.90 the glass is opaque enough that the blur stops
  /// carrying the depth §3.19 justified it for. 0.85 is the pair that moves
  /// both least and still clears 3:1 everywhere.
  static const double glassTint = 0.85;
}
