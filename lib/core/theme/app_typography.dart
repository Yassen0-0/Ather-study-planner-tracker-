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
/// Two rules the design is strict about:
/// * **Never go above 700.** The axis stops there; asking for 800 makes Flutter
///   fake a weight, which looks coarse next to real 700.
/// * **Every number is tabular.** Digits must not jitter as a percentage
///   animates or a counter ticks.
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

  // --- Body -----------------------------------------------------------------

  static TextStyle get body => style(size: 15, weight: medium, height: 1.5);

  /// Tab-bar labels.
  static TextStyle get tabLabel => style(size: 11, weight: bold, height: 1.2);

  // --- Controls -------------------------------------------------------------

  static TextStyle get chipLabel =>
      style(size: 13.5, weight: bold, height: 1.2);

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
    height: 1.45,
    color: colors.textSecondary,
  );

  TextStyle get secondaryStrong => AppTypography.style(
    size: 14,
    weight: AppTypography.semiBold,
    height: 1.45,
    color: colors.textSecondary,
  );

  /// A status or reason line under a row title.
  TextStyle get status => AppTypography.style(
    size: 13.5,
    weight: AppTypography.semiBold,
    height: 1.4,
    color: colors.textSecondary,
  );

  /// Breadcrumbs and chart labels.
  TextStyle get small => AppTypography.style(
    size: 12.5,
    weight: AppTypography.medium,
    height: 1.4,
    color: colors.textSecondary,
  );

  TextStyle get smallStrong => AppTypography.style(
    size: 12.5,
    weight: AppTypography.bold,
    height: 1.35,
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
    size: 11.5,
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

  TextStyle get pillLabel => AppTypography.style(
    size: 14.5,
    weight: AppTypography.bold,
    height: 1.2,
    color: colors.onPrimary,
  );
}

/// `context.text` — the coloured half of the type scale.
extension AtherTextAccess on BuildContext {
  AppTextStyles get text => AppTextStyles.of(this);
}
