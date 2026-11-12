import 'package:flutter/painting.dart';

/// Font families bundled in `assets/fonts/` and declared in `pubspec.yaml`.
abstract final class AppFonts {
  /// Body text: designed for low vision, readable in the street.
  static const text = 'Atkinson Hyperlegible';

  /// Numbers and titles: condensed, so long house numbers fit on a tile.
  static const display = 'Barlow Condensed';

  /// The phone's own monospace font (not bundled): only for the device
  /// identifier, where telling `l` from `1` and `O` from `0` matters.
  static const mono = 'monospace';
}

/// The text styles of the mockups. Colours are left out on purpose: they come
/// from the palette, so the same style works on any background.
abstract final class AppTextStyles {
  /// Titles of screens (« Rue des Lilas ») and bottom sheets
  /// (« Mes secteurs »).
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

  /// The hour in the come-back-blue square of « À repasser » (« 19 h »).
  static const comeBackHour = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.1,
  );

  /// The header of a list (« Rues · 31/50 »).
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

  /// The words of the map's legend (« en partie »).
  static const legend = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 13,
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

  /// The words of the status buttons of the status picker (« Fait »,
  /// « De nouveau personne »).
  static const statusChoice = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 18,
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

  /// The device identifier in full (« r2iKq8ZtW3hLmN0pXvB7cYd5Jgx1 »).
  static const identifier = TextStyle(
    fontFamily: AppFonts.mono,
    fontWeight: FontWeight.w400,
    fontSize: 14,
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

  /// The open secteur as the title of the start screen (« Secteur 49 ·
  /// 2026 », Home mockup): larger than a screen title, as it names the
  /// whole app's content.
  static const sectorTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 1.05,
  );

  /// A secteur in « Mes secteurs » (« Secteur 12 · 2026 »), and a street
  /// or number of the Corbeille (« 14ter Rue des Lilas »).
  static const sectorRowTitle = TextStyle(
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

  /// The app's name on « Bienvenue » (Welcome mockup).
  static const welcomeTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 44,
    height: 1,
  );

  /// « Demande envoyée », the title of the waiting screen (JoinPending
  /// mockup).
  static const pendingTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 40,
    height: 1,
  );

  /// The secteur under it (« Secteur 49 · CS Villefranche »).
  static const pendingSector = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.1,
  );

  /// The secteur a join code shows (« Secteur 49 · CS Villefranche », Join
  /// mockup).
  static const previewTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.1,
  );

  /// The number in the red square beside it (« 49 »).
  static const previewBadge = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1,
  );

  /// A box of the join code on « Rejoindre » (« K7P »), spaced so each
  /// character reads alone.
  static const codeBox = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    letterSpacing: 32 * 0.08,
    height: 1.1,
  );

  /// The code of a secteur just created (« K7P-2QX », Create mockup).
  static const createdCode = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 34,
    letterSpacing: 34 * 0.04,
    height: 1.1,
  );

  /// The amount typed in « Montant » (« 7,50 »), and its « € ».
  static const amountInput = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 34,
  );

  /// The amount of a don in « Dons de la tournée » (« 10 € ») and of a
  /// method in the « Bilan ».
  static const donationAmount = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 24,
  );

  /// The dons and money of the tournée in the « En tournée » band (« 19
  /// dons · 280 € › »).
  static const roundTotals = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.1,
  );

  /// A figure of the « Bilan » (« 23 »).
  static const recapFigure = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 34,
    height: 1.1,
  );

  /// The total of « ARGENT RÉCOLTÉ » (« 280 € »).
  static const recapTotal = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 28,
  );

  /// « 2 calendriers » in the status picker of a house done (RunStreet
  /// mockup, #114).
  static const calendarCount = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 16,
  );

  /// The number in the round badge of a tile that took two calendars or
  /// more (« 2 », #114).
  static const calendarBadge = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    height: 1,
  );

  /// The amount of a method under an unfolded tournée of the Collecte
  /// screen (« 210 € »).
  static const collecteDetailAmount = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 19,
  );

  /// The label of a mark of « Partie de la rue » (« entre 5 et 7 »).
  static const partMarkLabel = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w700,
    fontSize: 13,
  );

  /// The part on « Partie de la rue » (« Impairs 7–21 · pairs 2–30 »).
  static const partResult = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.1,
  );
}
