import 'package:flutter/painting.dart';

/// Font families bundled in `assets/fonts/` and declared in `pubspec.yaml`.
abstract final class AppFonts {
  /// Body text: designed for low vision, readable in the street.
  static const text = 'Atkinson Hyperlegible';

  /// Numbers and titles: condensed, so long house numbers fit on a tile.
  static const display = 'Barlow Condensed';
}

/// The text styles of the mockups. Colours are left out on purpose: they come
/// from the palette, so the same style works on any background.
abstract final class AppTextStyles {
  /// Titles of screens (« Rue des Lilas ») and bottom sheets
  /// (« Mes tournées »).
  static const title = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    height: 1.1,
  );

  /// The house number on a tile.
  static const tileNumber = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    height: 1,
  );

  /// The status glyph on a house tile (`✓`, `✗`…).
  static const tileGlyph = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1,
  );

  /// The building glyph and count (`◐ 7/12`), smaller so the count fits.
  static const tileBuildingGlyph = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    height: 1,
  );

  /// Labels of 56 dp buttons.
  static const button = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 17,
  );

  /// Labels of 52 dp (compact) buttons.
  static const compactButton = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 16,
  );

  /// Section headers (« MEMBRES (5) »): small capitals with 0.06 em tracking.
  static const sectionHeader = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    letterSpacing: 13 * 0.06,
  );

  /// Running text.
  static const body = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w400,
    fontSize: 16,
  );

  /// Larger running text (form fields, sheet content).
  static const bodyLarge = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w400,
    fontSize: 17,
  );
}
