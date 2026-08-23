import 'package:flutter/material.dart';

/// Colour tokens for the Ather design system, in a light and a dark set.
///
/// The palette is white + grey + black, **one** brand blue ([accent]), **one**
/// red for wrong/overdue and **one** green for right/mastered. There are
/// deliberately no subject colours, no four-step mastery spectrum, no gradients
/// and no glows.
///
/// [wrong] and [right] are *state* colours borrowed from a real exam paper — the
/// red pen and the green tick — and the visual refresh did not touch them. What
/// it added is [accent]: the one brand colour, used wherever something is
/// **active** rather than *correct* (selected tab, progress fill, ticked
/// checkbox, primary button, the mark's arc). The two vocabularies never mix:
/// blue never means "right", green never means "selected".
///
/// Nothing anywhere else in the app writes `Color(0x...)` inline.
///
/// ## Reading a colour
///
/// This is a [ThemeExtension], not a bag of constants, so a colour is read from
/// the ambient theme:
///
/// ```dart
/// final c = context.colors;
/// ... color: c.textSecondary
/// ```
///
/// That indirection is the whole mechanism behind the theme switch. Reading
/// through the context registers the widget as a dependent of [Theme], so it
/// rebuilds the moment the theme changes. A static constant could not: screens
/// parked in the [Navigator] are not rebuilt when [MaterialApp] rebuilds, and
/// they would keep painting yesterday's colours.
///
/// ## The two sets
///
/// [dark] is a re-mapping of [light], not a redesign. Every token means the same
/// thing in both, and the two semantic colours — [wrong] and [right] — are
/// *identical* across them, exactly as the brand mark keeps the same green on
/// its light and dark plates.
///
/// The relationship the design depends on is preserved: **the card is the
/// elevation.** There are no shadows anywhere in the app, so depth comes only
/// from a card sitting on a page of a different value. In light, the card is
/// lighter than the page. In dark, the same: the page goes to black and the
/// card lifts off it.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.pageBackground,
    required this.card,
    required this.muted,
    required this.fill,
    required this.track,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMicro,
    required this.textNoData,
    required this.weekLabel,
    required this.actionPrimary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.actionDisabled,
    required this.wrong,
    required this.wrongTint,
    required this.wrongText,
    required this.right,
    required this.rightText,
    required this.onState,
    required this.divider,
    required this.glassBorder,
    required this.switchOff,
    required this.switchKnob,
    required this.checkboxBorder,
    required this.dashedBorder,
    required this.scrim,
  });

  // --- Surfaces -------------------------------------------------------------
  /// Every screen background.
  final Color pageBackground;

  /// Every card and list row.
  final Color card;

  /// The homework card and text-field fills. Deliberately quieter than [card] --
  /// homework is an advisory signal, not evidence.
  final Color muted;

  /// Icon circles, unselected chips, small tracks.
  final Color fill;

  /// The 8px progress-bar track.
  final Color track;

  // --- Text -----------------------------------------------------------------
  final Color textPrimary;

  /// Passes WCAG AA on the card. The old palette's lighter grey did not.
  final Color textSecondary;

  /// Inactive tab-bar labels.
  final Color textTertiary;

  /// Fine print.
  final Color textMicro;

  /// The "—" shown for a lesson with no exam yet, and week-circle borders.
  ///
  /// Grey, never red: "not examined yet" is not "weak", and that distinction is
  /// a product rule rather than a styling detail.
  final Color textNoData;

  /// Weekday letters above the week strip.
  final Color weekLabel;

  // --- Actions --------------------------------------------------------------
  final Color actionPrimary;
  final Color onPrimary;

  /// The brand blue. Everything "active" is this colour: the selected tab icon
  /// and label, every progress fill that is not already red or green, the ticked
  /// checkbox and task disc, the selected filter chip, the "Exam" pill, the
  /// primary button, the lock screen's unlock button and the mark's arc.
  ///
  /// It is a *brand* colour, not a state colour — see the class doc. Never use
  /// it to say something is correct, mastered or on time; that is [right]'s job.
  final Color accent;

  /// Text and icons printed **onto** [accent].
  ///
  /// Unlike [onState] this does flip with the theme, because [accent] itself
  /// does: the dark accent is a light blue that needs near-black on it, the
  /// light accent a saturated blue that needs white.
  final Color onAccent;

  /// A wash of [accent] for tints — today's ring on the week strip, a chip's
  /// resting background. Low enough to sit under body text.
  final Color accentSoft;

  /// Fill of a button whose action is not yet earned. The button stays tappable
  /// -- it explains why instead of doing nothing.
  final Color actionDisabled;

  // --- The only two states --------------------------------------------------
  /// Wrong, weak (< 50%), overdue, and delete.
  final Color wrong;

  /// The one wash red is allowed: behind an error message, an overdue status
  /// chip, a review badge.
  ///
    /// There used to be a second at 12% called `wrongChip`, for the overdue chip
    /// specifically. Two reds two percent apart, on the same screen and often in
    /// the same card, is not a distinction — it is a decision nobody made twice
    /// on purpose. One wash, one name.
    final Color wrongTint;

    /// [wrong], darkened enough to be read as small text on light surfaces.
    ///
    /// `#FF3B30` measures **3.55 : 1** on the white card and less on the tint
    /// washes red sits on — fine for the big mastery figures, which clear the
    /// 3 : 1 large-text bar, but every *small* red sentence fails the 4.5 : 1
    /// that body text owes WCAG AA: the error banner, the overdue chip, the
    /// chart labels. This is the red pen's own text grade, on exactly the
    /// precedent of [rightText]: the fill stays the brand red, only the pen
    /// darkens.
    ///
    /// In dark the fill already measures 5.9 : 1 on black, so as with
    /// [rightText] the two themes differ on purpose: dark keeps the brand red
    /// exactly, and only light darkens it.
    final Color wrongText;

  /// Right, mastered (>= 90%), mastered chapter, switch on.
  ///
  /// A **fill**, not a text colour. See [rightText].
  final Color right;

  /// [right], darkened enough to be read as text on a light surface.
  ///
  /// `#34C759` measures **2.2 : 1** on white — under every WCAG threshold there
  /// is, including the 3 : 1 allowed for large text — and it was being used for
  /// the mastery figure on every card at 90% and above, for "تمام، جاهز تدخل
  /// الامتحان", and for the tally that turns green when the wizard's groups add
  /// up. The green tick on a filled disc was never the problem; green *words* on
  /// white were.
  ///
  /// In dark the same green already measures 7.7 : 1 on the card, so this is the
  /// one token whose two values differ for a reason other than inversion: the
  /// dark theme keeps the brand green exactly, and only light darkens it.
  final Color rightText;

  /// Text and icons printed **onto** [wrong] or [right].
  ///
  /// White in both themes, and deliberately not [onPrimary]. Those two fills are
  /// the same colour in light and dark, so what sits on them has to be too --
  /// [onPrimary] inverts with the theme and would turn a sign-out button's label
  /// black on red, and the tick inside a green disc black on green.
  final Color onState;

  // --- Lines and controls ---------------------------------------------------
  /// Hairline between rows inside one card, and between rows in a sheet.
  final Color divider;

  /// The tab bar's own edge.
  ///
  /// Not "a slightly stronger [divider]", which is what it was called when it
  /// was two percent away from one and used for both jobs. This line is drawn
  /// on a translucent surface with a 24-sigma blur behind it, over whatever the
  /// student happens to be scrolling; a 6% hairline that reads cleanly inside a
  /// white card disappears there. The extra weight is the blur's, not the
  /// design's, which is why it belongs to the bar and to nothing else.
  final Color glassBorder;

  final Color switchOff;

  /// The switch's knob. Light in both themes, for the same reason as
  /// [onState]: it rides on the green [right] track when on, and it has to stay
  /// legible against [switchOff] when off -- a knob the colour of the card is
  /// nearly invisible on a dark track.
  final Color switchKnob;
  final Color checkboxBorder;
  final Color dashedBorder;

  /// Scrim behind a bottom sheet.
  final Color scrim;

  /// The original palette, unchanged.
  static const AppColors light = AppColors(
    pageBackground: Color(0xFFEFEFF2),
    card: Color(0xFFFFFFFF),
    muted: Color(0xFFF4F4F6),
    fill: Color(0xFFF1F1F4),
    track: Color(0xFFE9E9EC),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF63636A),
    // Was #9A9AA0. Through the tab bar's glass that measured 1.90:1 over an
    // analytics column and 1.91:1 over a mastery fill -- §3.19 assumed only
    // *surfaces* passed underneath, and content does too. #7A7A80 clears 3:1
    // against every solid area that can scroll under the pill, and is a plain
    // improvement on the four non-glass uses as well, where #9A9AA0 was 2.7:1.
    textTertiary: Color(0xFF7A7A80),
    textMicro: Color(0xFF7C7C82),
    // Was #C6C6CB, which is 1.7:1 on white -- effectively invisible in daylight,
    // and it carries the "—" that means "never examined" plus every field hint.
    // #70707A is 4.9:1, still a clear step quieter than textSecondary (5.9:1),
    // so the ramp's ordering is untouched.
    textNoData: Color(0xFF70707A),
    // Was #8A8A8E, which is 3.0:1 on the page grey -- under AA for the small
    // weekday letters it prints. Moved into textNoData's family (#70707A,
    // 4.3:1) so it stays a clear step quieter than textSecondary and the grey
    // ramp keeps its ordering; see §3.10's light-mode wave.
    weekLabel: Color(0xFF70707A),
    actionPrimary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF1B6EF3),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x1F1B6EF3), // 12%
    actionDisabled: Color(0xFFE9E9EC),
    wrong: Color(0xFFFF3B30),
    wrongTint: Color(0x1AFF3B30), // 10%
    // #C93229 measures 5.3:1 on the card, 4.8:1 on muted, and clears 4.5:1 on
    // both the page grey (4.6) and the red tint wash itself (4.6) -- which is
    // where its text actually sits: the error banner and the overdue chip
    // print onto wrongTint. Still unmistakably the same red as the fill.
    wrongText: Color(0xFFC93229),
    right: Color(0xFF34C759),
    // 5.1:1 on white, 4.4:1 on the page grey -- AA for body text, and still
    // unmistakably the same green as the fill beside it.
    rightText: Color(0xFF1B7F3B),
    onState: Color(0xFFFFFFFF),
    divider: Color(0x0F000000), // black @ 6%
    glassBorder: Color(0x12000000), // black @ 7%
    switchOff: Color(0xFFDCDCE0),
    switchKnob: Color(0xFFFFFFFF),
    checkboxBorder: Color(0xFFD5D5DA),
    dashedBorder: Color(0xFFC6C6CB),
    scrim: Color(0x59000000), // black @ 35%
  );

  /// The same design with the value scale inverted.
  ///
  /// Two things deliberately do **not** move:
  ///
  /// * [wrong] and [right] keep their exact light-theme values. They are the red
  ///   pen and the green tick — the two colours in the app that carry meaning
  ///   rather than surface — and the brand mark itself keeps the same green on
  ///   both its plates. Only their translucent washes are opened up, because 10%
  ///   red over black is not visible.
  /// * The grey ramp keeps its *ordering*, so every "quieter than" relationship
  ///   the design relies on survives: page < muted < card, and each text tier
  ///   stays a step quieter than the one above it.
  static const AppColors dark = AppColors(
    pageBackground: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    muted: Color(0xFF161618),
    fill: Color(0xFF2A2A2E),
    track: Color(0xFF2C2C2E),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1A8),
    // Was #78787E. Dark gains contrast by going *lighter*: #88888E clears 3:1
    // through the same glass. See the light note above and §3.19.
    textTertiary: Color(0xFF88888E),
    textMicro: Color(0xFF8E8E94),
    textNoData: Color(0xFF5A5A60),
    weekLabel: Color(0xFF8E8E94),
    actionPrimary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    accent: Color(0xFF4D9BFF),
    onAccent: Color(0xFF04203F),
    accentSoft: Color(0x2E4D9BFF), // 18%
    actionDisabled: Color(0xFF2C2C2E),
    wrong: Color(0xFFFF3B30),
    wrongTint: Color(0x26FF3B30), // 15%
    // Unchanged from [wrong]: 5.9:1 on black already. Darkening it here would
    // only make it harder to read.
    wrongText: Color(0xFFFF3B30),
    right: Color(0xFF34C759),
    // Unchanged from [right]: 7.7:1 on the dark card already. Darkening it here
    // would only make it harder to read.
    rightText: Color(0xFF34C759),
    onState: Color(0xFFFFFFFF),
    divider: Color(0x14FFFFFF), // white @ 8%
    glassBorder: Color(0x1AFFFFFF), // white @ 10%
    switchOff: Color(0xFF3A3A3E),
    switchKnob: Color(0xFFF2F2F5),
    checkboxBorder: Color(0xFF48484C),
    dashedBorder: Color(0xFF48484C),
    scrim: Color(0x8C000000), // black @ 55%
  );

  /// The palette for the ambient theme.
  ///
  /// Falls back to [light] rather than throwing: a widget pumped outside an
  /// Ather theme in a test should render, not crash.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? pageBackground,
    Color? card,
    Color? muted,
    Color? fill,
    Color? track,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMicro,
    Color? textNoData,
    Color? weekLabel,
    Color? actionPrimary,
    Color? onPrimary,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? actionDisabled,
    Color? wrong,
    Color? wrongTint,
    Color? wrongText,
    Color? right,
    Color? rightText,
    Color? onState,
    Color? divider,
    Color? glassBorder,
    Color? switchOff,
    Color? switchKnob,
    Color? checkboxBorder,
    Color? dashedBorder,
    Color? scrim,
  }) {
    return AppColors(
      pageBackground: pageBackground ?? this.pageBackground,
      card: card ?? this.card,
      muted: muted ?? this.muted,
      fill: fill ?? this.fill,
      track: track ?? this.track,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMicro: textMicro ?? this.textMicro,
      textNoData: textNoData ?? this.textNoData,
      weekLabel: weekLabel ?? this.weekLabel,
      actionPrimary: actionPrimary ?? this.actionPrimary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      actionDisabled: actionDisabled ?? this.actionDisabled,
      wrong: wrong ?? this.wrong,
      wrongTint: wrongTint ?? this.wrongTint,
      wrongText: wrongText ?? this.wrongText,
      right: right ?? this.right,
      rightText: rightText ?? this.rightText,
      onState: onState ?? this.onState,
      divider: divider ?? this.divider,
      glassBorder: glassBorder ?? this.glassBorder,
      switchOff: switchOff ?? this.switchOff,
      switchKnob: switchKnob ?? this.switchKnob,
      checkboxBorder: checkboxBorder ?? this.checkboxBorder,
      dashedBorder: dashedBorder ?? this.dashedBorder,
      scrim: scrim ?? this.scrim,
    );
  }

  /// Interpolates the whole palette, so a theme change cross-fades rather than
  /// snapping. [MaterialApp] drives this through `themeAnimationDuration`.
  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      pageBackground: mix(pageBackground, other.pageBackground),
      card: mix(card, other.card),
      muted: mix(muted, other.muted),
      fill: mix(fill, other.fill),
      track: mix(track, other.track),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      textMicro: mix(textMicro, other.textMicro),
      textNoData: mix(textNoData, other.textNoData),
      weekLabel: mix(weekLabel, other.weekLabel),
      actionPrimary: mix(actionPrimary, other.actionPrimary),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      actionDisabled: mix(actionDisabled, other.actionDisabled),
      wrong: mix(wrong, other.wrong),
      wrongTint: mix(wrongTint, other.wrongTint),
      wrongText: mix(wrongText, other.wrongText),
      right: mix(right, other.right),
      rightText: mix(rightText, other.rightText),
      onState: mix(onState, other.onState),
      divider: mix(divider, other.divider),
      glassBorder: mix(glassBorder, other.glassBorder),
      switchOff: mix(switchOff, other.switchOff),
      switchKnob: mix(switchKnob, other.switchKnob),
      checkboxBorder: mix(checkboxBorder, other.checkboxBorder),
      dashedBorder: mix(dashedBorder, other.dashedBorder),
      scrim: mix(scrim, other.scrim),
    );
  }
}

/// `context.colors` and `context.text` — the only two ways the app reads a
/// colour or a coloured text style.
///
/// Kept deliberately terse. These appear on nearly every line that paints
/// something, and `AppColors.of(context).textSecondary` at 190 call sites would
/// bury the token name that actually matters.
extension AtherThemeAccess on BuildContext {
  /// The palette for the ambient theme.
  AppColors get colors => AppColors.of(this);
}
