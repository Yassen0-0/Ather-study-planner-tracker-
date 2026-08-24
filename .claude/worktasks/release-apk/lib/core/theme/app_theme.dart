import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The app ships a light and a dark theme.
///
/// They are **one theme built twice**, not two themes. [_build] is the only
/// description of what an Ather surface looks like; [light] and [dark] differ
/// only by the [AppColors] handed to it, so a change to a corner radius, a
/// button height or an input border can only ever be made in one place.
///
/// The rule the design rests on survives in both: *the card is the elevation.*
/// There are no shadows anywhere in the app -- they are switched off at the
/// source below rather than per widget -- so depth comes entirely from a card
/// sitting on a page of a different value. That works as well with a dark card
/// on a black page as it does with a white card on a grey one, which is what
/// made restoring the dark theme a re-mapping rather than a redesign.
abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      // Material's "primary" is the accent, not the foreground colour: every
      // framework widget that has not been replaced by an Ather one should tint
      // itself the same blue the hand-built controls do.
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      surface: c.card,
      onSurface: c.textPrimary,
      error: c.wrong,
      onError: c.onPrimary,
      outline: c.dashedBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // The palette travels on the theme itself. Every `context.colors` in the
      // app reads it back out of here, which is what makes a widget rebuild
      // when the theme changes.
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.pageBackground,
      canvasColor: c.pageBackground,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme(c),
      // No shadows anywhere. Material loves to add a tint on scroll and a
      // shadow on elevation; both are switched off at the source rather than
      // per widget, so a stray `Card` cannot reintroduce them.
      shadowColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.pageBackground,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.screenTitle.copyWith(
          color: c.textPrimary,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
        // Dark status-bar glyphs on a light page, light glyphs on a dark one.
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          textStyle: AppTextStyles(c).button,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textPrimary,
          textStyle: AppTextStyles(c).button.copyWith(color: c.textPrimary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.muted,
        hintStyle: AppTypography.body.copyWith(color: c.textTertiary),
        labelStyle: AppTextStyles(c).secondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.wrong),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.wrong, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      // The design hides scrollbars entirely; the white cards already show that
      // a list continues.
      scrollbarTheme: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(false),
        thickness: WidgetStatePropertyAll(0),
      ),
    );
  }
}
