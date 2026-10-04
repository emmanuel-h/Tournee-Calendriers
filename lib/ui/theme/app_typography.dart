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

  /// The count after a building's glyph (`◐ 7/12`).
  static const tileCount = TextStyle(
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

  /// A street name in the start list.
  static const streetName = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 1.1,
  );

  /// The header of a list (« Mes rues · 3 »).
  static const listHeader = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 24,
  );

  /// A count at the end of a row (« 31/403 »).
  static const rowCount = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 15,
  );

  /// The label above a form field (« Commune »).
  static const fieldLabel = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 15,
  );

  /// Small secondary text (a commune name, « 403 n° », notes).
  static const small = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w400,
    fontSize: 14,
  );

  /// Labels of pill buttons (« Tout cocher »).
  static const pill = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 14,
  );
}
