import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_theme.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

void main() {
  test(
    'should map the mockup tokens onto Material 3 when the palette is light',
    () {
      final theme = buildAppTheme(AppColors.light);

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF3F1EC));
      expect(theme.colorScheme.primary, const Color(0xFFB3261E));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFF1B1F24));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF4A5058));
      expect(theme.colorScheme.outline, const Color(0xFFCFC9BD));
      expect(theme.textTheme.bodyMedium!.fontFamily, AppFonts.text);
      expect(theme.appBarTheme.titleTextStyle!.fontFamily, AppFonts.display);
      expect(theme.snackBarTheme.backgroundColor, const Color(0xFF1B1F24));
      expect(theme.snackBarTheme.actionTextColor, const Color(0xFFF2B33D));
      expect(theme.bottomSheetTheme.modalBarrierColor, const Color(0x801B1F24));
    },
  );

  test('should expose the palette to our own components as an extension', () {
    final theme = buildAppTheme(AppColors.light);

    expect(theme.extension<AppColors>(), same(AppColors.light));
  });

  test('should build a dark theme when given the dark palette', () {
    final theme = buildAppTheme(AppColors.dark);

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.dark.ground);
    expect(theme.extension<AppColors>(), same(AppColors.dark));
  });

  test('should grey out disabled primary buttons as in the mockups', () {
    final style = buildAppTheme(AppColors.light).filledButtonTheme.style!;

    expect(
      style.backgroundColor!.resolve({WidgetState.disabled}),
      const Color(0xFFE2DED5),
    );
    expect(style.backgroundColor!.resolve({}), const Color(0xFFB3261E));
    expect(
      style.foregroundColor!.resolve({WidgetState.disabled}),
      const Color(0xFF4A5058),
    );
    expect(style.foregroundColor!.resolve({}), const Color(0xFFFFFFFF));
  });

  test('should keep the palette when interpolated with nothing or itself', () {
    expect(AppColors.light.lerp(null, 0.7), same(AppColors.light));
    expect(AppColors.light.lerp(AppColors.dark, 0.4), same(AppColors.light));
    expect(AppColors.light.lerp(AppColors.dark, 0.5), same(AppColors.dark));
    expect(AppColors.light.copyWith(), same(AppColors.light));
  });
}
