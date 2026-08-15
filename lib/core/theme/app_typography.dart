import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The Ather type scale, built on Readex Pro.
///
/// Readex Pro ships as a **variable** font (weight axis 200-700) in a single
/// TTF. Flutter will not synthesise a variable font's weights from
/// [TextStyle.fontWeight] alone -- the `wght` axis has to be driven explicitly
/// through [TextStyle.fontVariations], otherwise every weight renders at the
/// font's default and the whole hierarchy silently collapses to one weight.
/// [_font] sets both: `fontVariations` does the real work, `fontWeight` keeps
/// fallback fonts and Flutter's own text diffing behaving.
///
/// Three rules the design is strict about:
/// * **Never go above 700.** The axis stops there; asking for 800 makes Flutter
///   fake a weight, which looks coarse next to real 700.
/// * **Every number is tabular.** Digits must not jitter as a percentage
///   animates or a counter ticks.
/// * **No size is invented at a call site.** Every role below has a name, and
///   the name is what a screen asks for. Call sites used to hard-code 11, 12,
///   13, 14, 15, 15.5, 16, 17, 18, 19, 22 and 26 directly, which is how the
///   scale grew half-steps nobody chose: a screen needing "a bit smaller than
///   the token" typed a number rather than asking whether the role already
///   existed. Fifty-odd of those are now tokens, and with them went the
///   half-steps below 16 — 11.5, 12.5, 13.5, 14.5 and 15.5 are gone, folded
///   into the whole number they were within half a point of. Below 20 the ramp
///   is integers only, one named role per rung.
///
/// The one half-step that remains is [rowTitleSmall] at 16.5, kept because
/// collapsing it to 16 would give three names to one size — see the note on the
/// row pair below.
///
/// ## Colour
///
/// The scale is split in two by whether a style carries a colour of its own:
///
/// * **Here, static** — every style whose colour is just "the primary text
///   colour". These leave [TextStyle.color] null and inherit it, which is what
///   lets them stay static across both themes. `Text` merges its style over the
///   ambient [DefaultTextStyle], and [AppTheme] seeds that from the palette's
///   `textPrimary`, so an uncoloured style is black in light and white in dark
///   with nothing at the call site.
/// * **[AppTextStyles], via `context.text`** — the handful that deliberately
///   sit at a *different* colour from the body: the secondary greys, the
///   weekday label, the fine print, and the two that print onto a filled
///   button. Those cannot be resolved without a theme.
abstract final class AppTypography {
  static const String fontFamily = 'ReadexPro';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The one function every style in the app passes through.
  ///
  /// [color] left null means "inherit" -- see the class comment. It is not a
  /// missing value: it is how a style stays correct in both themes.
  static TextStyle style({
    required double size,
    required FontWeight weight,
    double? height,
    double letterSpacing = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
      ],
      fontFeatures: _tabular,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // --- Headlines ------------------------------------------------------------

  /// Dashboard title -- "النهارده".
  static TextStyle get today =>
      style(size: 32, weight: bold, letterSpacing: -0.5, height: 1.2);

  /// The wordmark on the lock and splash screen. Bigger than any title in the
  /// app, because it is the only thing on the screen besides the mark.
  static TextStyle get lockWordmark =>
      style(size: 38, weight: bold, letterSpacing: -0.6, height: 1.1);

  /// The dominant number on the wizard result and the chapter report.
  static TextStyle get resultNumber =>
      style(size: 56, weight: bold, letterSpacing: -2, height: 1);

  /// The celebration percentage.
  static TextStyle get celebrationNumber =>
      style(size: 44, weight: bold, letterSpacing: -1.5, height: 1.1);

  /// Lesson mastery number.
  static TextStyle get lessonNumber =>
      style(size: 34, weight: bold, letterSpacing: -0.5, height: 1.1);

  /// Summary-card mastery number (dashboard, subject, chapter).
  static TextStyle get cardNumber =>
      style(size: 30, weight: bold, letterSpacing: -0.5, height: 1.1);

  /// Wizard step heading.
  static TextStyle get stepTitle =>
      style(size: 26, weight: bold, letterSpacing: -0.4, height: 1.25);

  /// "المواد" / "الأبواب" / "الدروس" section headings.
  static TextStyle get sectionTitle =>
      style(size: 22, weight: bold, letterSpacing: -0.3, height: 1.3);

  /// Inner-screen title in the nav header.
  static TextStyle get screenTitle =>
      style(size: 20, weight: bold, letterSpacing: -0.3, height: 1.3);

  // --- Rows and cards -------------------------------------------------------
  //
  // Rows come in two densities, and the pair moves together: a subject row is
  // 17/19, a lesson row is 16.5/18. The title and the number are sized as one
  // decision, which is why neither pair is collapsed into the other -- the
  // number is the row's answer, and it has to stay a fixed step above its own
  // title rather than above some other row's.

  /// Title of a row in a list.
  static TextStyle get rowTitle => style(size: 17, weight: bold, height: 1.3);

  /// Lesson rows sit a touch smaller than subject rows.
  static TextStyle get rowTitleSmall =>
      style(size: 16.5, weight: bold, height: 1.3);

  /// Card heading.
  static TextStyle get cardTitle => style(size: 16, weight: bold, height: 1.3);

  /// Label inside a card ("الإتقان العام").
  static TextStyle get cardLabel =>
      style(size: 16, weight: semiBold, height: 1.3);

  /// A row's trailing percentage.
  static TextStyle get rowNumber => style(size: 19, weight: bold, height: 1.2);

  /// Slightly smaller trailing percentage (chapter and lesson rows).
  static TextStyle get rowNumberSmall =>
      style(size: 18, weight: bold, height: 1.2);

  /// The trailing figure on a row *inside* a card — exam history, the weakest
  /// list, the not-ready sheet. Those rows are divided hairlines rather than
  /// cards of their own, so their number sits a step below [rowNumberSmall].
  static TextStyle get rowNumberCompact =>
      style(size: 16, weight: bold, height: 1.2);

  /// The title of a row inside a card, matching [rowNumberCompact].
  static TextStyle get listTitle =>
      style(size: 15, weight: semiBold, height: 1.3);

  /// The heading of an empty state — the one line on an otherwise blank screen.
  /// Larger than [cardTitle] because there is nothing beside it to be larger
  /// than, smaller than [screenTitle] because the screen already has one.
  static TextStyle get emptyTitle => style(size: 18, weight: bold, height: 1.3);

  /// The label on a control that is not a button: a segment of the segmented
  /// control, a tally, a trend figure, the quiet second action under a form.
  static TextStyle get controlLabel =>
      style(size: 14, weight: bold, height: 1.2);

  /// The status or context line under a row title — "متأخر 16 يوم", "3 أبواب ·
  /// 12 درس". Uncoloured: the caller decides between `wrong` and
  /// `textSecondary`, and that choice is the whole point of the line.
  static TextStyle get rowStatus =>
      style(size: 14, weight: medium, height: 1.4);

  /// A short verdict line that has earned emphasis — "تمام، جاهز تدخل
  /// الامتحان", "اتقنت الباب في...". Uncoloured for the same reason as
  /// [rowStatus]; [AppTextStyles.status] is this style at the quiet grey.
  static TextStyle get statusLine =>
      style(size: 13, weight: semiBold, height: 1.4);

  /// The label a tappable item carries beside a control — a checklist item, a
  /// task. Sits at [body]'s size with a tighter leading, because it is one
  /// line beside a 24 disc rather than a paragraph.
  static TextStyle get itemLabel =>
      style(size: 15, weight: medium, height: 1.3);

  // --- The dashboard's three-up stat row -------------------------------------
  //
  // Three tokens for one component, because the row is three sizes stacked in
  // 72dp on a small phone and the relationship between them is the design. It
  // was written at the call site as 14 / 19 / 13, which is the same thing
  // stated in a place nobody would think to look for it.

  /// "الباقي" — what the count below it is counting.
  static TextStyle get statLabel =>
      style(size: 14, weight: semiBold, height: 1.3);

  /// The count itself. Deliberately identical to [rowNumber]: a stat is a
  /// number that answers a label, which is exactly what a row's trailing
  /// figure is, and the two sit on the same screen.
  static TextStyle get statValue => rowNumber;

  // --- Body -----------------------------------------------------------------

  static TextStyle get body => style(size: 15, weight: medium, height: 1.5);

  /// Tab-bar labels.
  static TextStyle get tabLabel => style(size: 11, weight: bold, height: 1.2);

  // --- Controls -------------------------------------------------------------

  static TextStyle get chipLabel => style(size: 13, weight: bold, height: 1.2);

  /// The label on a [MiniBadge] — "مراجعة", "أضعف درس".
  static TextStyle get badgeLabel => style(size: 11, weight: bold, height: 1.2);

  /// The overdue count inside the tab bar's 16px disc. The one size below 11
  /// in the app, and it is set by the disc rather than by the scale: two digits
  /// have to fit inside a circle that must not grow into the icon above it.
  static TextStyle get badgeCount => style(size: 10, weight: bold, height: 1.2);

  /// The figure printed above an analytics column, and beside a chapter bar.
  static TextStyle get chartValue => style(size: 12, weight: bold, height: 1.2);

  /// Text typed into a numeric field.
  static TextStyle get input => style(size: 17, weight: bold, height: 1.2);

  static TextStyle get inputLarge => style(size: 28, weight: bold, height: 1.2);

  /// Material's [TextTheme], so any framework widget that has not been replaced
  /// still renders in the right family and weight.
  ///
  /// This is also what gives the uncoloured styles above their colour:
  /// `bodyMedium` seeds the [DefaultTextStyle] under every [Material], and an
  /// uncoloured style merged over it inherits `textPrimary`.
  static TextTheme textTheme(AppColors colors) {
    final AppTextStyles text = AppTextStyles(colors);
    final Color primary = colors.textPrimary;
    return TextTheme(
      displayLarge: today.copyWith(color: primary),
      displayMedium: sectionTitle.copyWith(color: primary),
      titleLarge: screenTitle.copyWith(color: primary),
      titleMedium: cardTitle.copyWith(color: primary),
      titleSmall: rowTitle.copyWith(color: primary),
      bodyLarge: body.copyWith(color: primary),
      bodyMedium: body.copyWith(color: primary),
      bodySmall: text.secondary,
      labelLarge: text.button.copyWith(color: primary),
      labelMedium: chipLabel.copyWith(color: primary),
      labelSmall: text.micro,
    );
  }
}

/// The styles that carry a colour of their own, resolved against a palette.
///
/// Reached through `context.text`. Constructing one is as cheap as reading a
/// getter on the old static class was -- every style here already built a fresh
/// [TextStyle] per access.
@immutable
class AppTextStyles {
  const AppTextStyles(this.colors);

  final AppColors colors;

  static AppTextStyles of(BuildContext context) =>
      AppTextStyles(AppColors.of(context));

  TextStyle get secondary => AppTypography.style(
    size: 14,
    weight: AppTypography.medium,
    height: 1.5,
    color: colors.textSecondary,
  );

  TextStyle get secondaryStrong => AppTypography.style(
    size: 14,
    weight: AppTypography.semiBold,
    height: 1.5,
    color: colors.textSecondary,
  );

  /// A status or reason line under a row title.
  TextStyle get status =>
      AppTypography.statusLine.copyWith(color: colors.textSecondary);

  /// The explanatory line under a card's heading — what a setting does, what a
  /// screen's subtitle is naming. One step quieter than [secondary], which is
  /// content; this is the label's own small print.
  TextStyle get sublabel => AppTypography.style(
    size: 13,
    weight: AppTypography.medium,
    height: 1.5,
    color: colors.textSecondary,
  );

  /// Breadcrumbs and chart labels.
  TextStyle get small => AppTypography.style(
    size: 12,
    weight: AppTypography.medium,
    height: 1.4,
    color: colors.textSecondary,
  );

  TextStyle get smallStrong => AppTypography.style(
    size: 12,
    weight: AppTypography.bold,
    height: 1.35,
    color: colors.textSecondary,
  );

  /// The name above an input box. The label sits outside the field rather than
  /// floating inside it, so it is small print rather than a heading.
  TextStyle get fieldLabel => AppTypography.style(
    size: 12,
    weight: AppTypography.semiBold,
    height: 1.3,
    color: colors.textSecondary,
  );

  /// The "/ 24" under a stat count. Two steps below [AppTypography.statValue]
  /// and quiet, because the denominator is context for the figure beside it,
  /// not a second figure.
  TextStyle get statDenominator => AppTypography.style(
    size: 13,
    weight: AppTypography.semiBold,
    height: 1.2,
    color: colors.textSecondary,
  );

  /// The subject name under an analytics column.
  TextStyle get chartLabel => AppTypography.style(
    size: 11,
    weight: AppTypography.semiBold,
    height: 1.2,
    color: colors.textSecondary,
  );

  /// Weekday letters.
  TextStyle get dayLabel => AppTypography.style(
    size: 13,
    weight: AppTypography.semiBold,
    height: 1.2,
    color: colors.weekLabel,
  );

  /// Fine print, e.g. the homework disclaimer.
  TextStyle get micro => AppTypography.style(
    size: 11,
    weight: AppTypography.regular,
    height: 1.5,
    color: colors.textMicro,
  );

  TextStyle get button => AppTypography.style(
    size: 16,
    weight: AppTypography.bold,
    height: 1.2,
    color: colors.onPrimary,
  );

  /// The message on the toast's plate — the one black (or, in dark, white)
  /// surface in the app, which is why it needs its own `on` colour rather than
  /// any of the greys.
  TextStyle get toastMessage => AppTypography.style(
    size: 14,
    weight: AppTypography.semiBold,
    height: 1.35,
    color: colors.onPrimary,
  );

  /// The label on an accent pill — the "Exam" button. Coloured for the accent
  /// fill it always sits on, not for the page.
  TextStyle get pillLabel => AppTypography.style(
    size: 14,
    weight: AppTypography.bold,
    height: 1.2,
    color: colors.onAccent,
  );
}

/// `context.text` — the coloured half of the type scale.
extension AtherTextAccess on BuildContext {
  AppTextStyles get text => AppTextStyles.of(this);
}
