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

  /// The counts under a street's name (« 31/42 · ✗ 3 · ↻ 1 »).
  static const streetCounts = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w400,
    fontSize: 15,
  );

  /// The label above a form field (« Commune »).
  static const fieldLabel = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 15,
  );

  /// Small secondary text (a commune name, « 403 n° »).
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

  /// The house number at the top of the Fiche maison (« 5 »).
  static const sheetNumber = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 34,
    height: 1.1,
  );

  /// The street name next to it (« Rue des Lilas »).
  static const sheetStreetName = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.1,
  );

  /// The hint under a field (« N'écrivez ni nom… », « 12/200 »).
  static const helper = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w400,
    fontSize: 13,
  );

  /// The count of the grid's header (« ◐ 15/24 »).
  static const gridCount = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.1,
  );

  /// The label of a door of the grid (« 51 »).
  static const doorLabel = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 21,
    height: 1,
  );

  /// A segment of a choice (« Esc. A · 7/12 », « 51, 52… ») and the floor
  /// labels of the grid.
  static const segment = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 15,
  );

  /// The value of a stepper (« RdC–5e »).
  static const stepperValue = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 24,
  );

  /// The sign of a stepper button (« − », « + »).
  static const stepperSign = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1,
  );

  /// The line of the setup preview (« RdC 01–04, 1er 11–14 … »).
  static const previewLine = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w600,
    fontSize: 19,
    height: 1.2,
  );

  /// A number of the edit mode (« 3bis », « 8 · immeuble »): a little
  /// smaller than on the street screen, to leave room for the ✕.
  static const editTileNumber = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1,
  );

  /// The open tournée as the title of the start screen (« Tournée 49 ·
  /// 2026 », Home mockup): larger than a screen title, as it names the
  /// whole app's content.
  static const tourneeTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 1.05,
  );

  /// A tournée in « Mes tournées » (« Tournée 12 · 2026 »), and a street
  /// or number of the Corbeille (« 14ter Rue des Lilas »).
  static const tourneeRowTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 21,
    height: 1.1,
  );

  /// The join code in Équipe (« K7P-2QX »), spaced a little so each
  /// character reads alone.
  static const joinCode = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    letterSpacing: 28 * 0.04,
    height: 1.1,
  );

  /// The initial in a member's round avatar (« M »).
  static const avatarInitial = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1,
  );
}
