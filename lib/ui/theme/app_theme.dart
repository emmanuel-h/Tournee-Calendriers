import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Builds the Material 3 theme from a palette.
///
/// Material widgets (app bar, buttons, sheets, snackbars) read their colours
/// and shapes from `ThemeData`, so mapping the tokens here makes stock widgets
/// look like the mockups without styling each one. The palette itself is
/// registered as an extension for our own components (`AppColors.of`).
ThemeData buildAppTheme(AppColors colors) {
  final scheme = ColorScheme(
    brightness: colors.brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    secondary: colors.ink,
    onSecondary: colors.surface,
    error: colors.accent,
    onError: colors.onAccent,
    surface: colors.surface,
    onSurface: colors.ink,
    onSurfaceVariant: colors.muted,
    outline: colors.line,
    outlineVariant: colors.divider,
    scrim: colors.scrim,
  );
  const pill = WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder());

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.ground,
    fontFamily: AppFonts.text,
    textTheme: TextTheme(
      titleLarge: AppTextStyles.title.copyWith(color: colors.ink),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
      bodyMedium: AppTextStyles.body.copyWith(color: colors.ink),
      labelLarge: AppTextStyles.button.copyWith(color: colors.ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.ground,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTextStyles.title.copyWith(color: colors.ink),
    ),
    // Primary buttons: filled, accent, pill-shaped.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabled
              : colors.accent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.onDisabled
              : colors.onAccent,
        ),
      ),
    ),
    // Secondary buttons: white pill with a thin outline.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.onDisabled
              : colors.ink,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: colors.line, width: AppSizes.borderWidth),
        ),
      ),
    ),
    // Text fields: white, a thin outline, darker once focused.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: AppTextStyles.bodyLarge.copyWith(color: colors.muted),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.fieldPadding,
        vertical: (AppSizes.fieldHeight - 24) / 2,
      ),
      enabledBorder: _fieldBorder(colors.line),
      focusedBorder: _fieldBorder(colors.ink),
      border: _fieldBorder(colors.line),
    ),
    // Ticked boxes in ink, as in the import mockup; a box that cannot be
    // changed (« déjà importée ») in the muted grey.
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => !states.contains(WidgetState.selected)
            ? Colors.transparent
            : states.contains(WidgetState.disabled)
            ? colors.muted
            : colors.ink,
      ),
      checkColor: WidgetStatePropertyAll(colors.surface),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? colors.muted
              : colors.ink,
          width: 2,
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.done,
      linearTrackColor: colors.divider,
      circularTrackColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: colors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.sheetRadius),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.snackBar,
      contentTextStyle: AppTextStyles.body.copyWith(color: colors.onSnackBar),
      actionTextColor: colors.snackBarAction,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppSizes.snackBarRadius),
        ),
      ),
    ),
    extensions: [colors],
  );
}

OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
  borderRadius: const BorderRadius.all(Radius.circular(AppSizes.fieldRadius)),
  borderSide: BorderSide(color: color, width: AppSizes.borderWidth),
);
