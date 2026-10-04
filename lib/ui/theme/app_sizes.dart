/// Sizes and radii of the mockups, in logical pixels (dp).
abstract final class AppSizes {
  /// Smallest tap target anywhere (PLAN §5).
  static const minTapTarget = 48.0;

  /// Main buttons: « Créer », « Rejoindre », « Ajouter des rues ».
  static const buttonHeight = 56.0;

  /// Buttons inside sheets and side-by-side pairs.
  static const compactButtonHeight = 52.0;

  /// House and building tiles: the mockups draw 60 dp, PLAN §5 requires at
  /// least 56 dp.
  static const tileHeight = 60.0;

  /// The status glyph on a house tile (`✓`, `✗`…).
  static const tileGlyph = 22.0;

  /// The glyph before a building's count (`◐ 7/12`), smaller so the count
  /// fits.
  static const tileBuildingGlyph = 17.0;

  /// Space between a glyph and the text next to it.
  static const glyphGap = 4.0;

  static const tileRadius = 12.0;
  static const tilePadding = 14.0;
  static const sheetRadius = 24.0;
  static const snackBarRadius = 14.0;

  /// Width of every outline (tiles, secondary buttons).
  static const borderWidth = 1.5;

  /// Side margin of a screen's content.
  static const gutter = 16.0;

  /// The grabber at the top of a bottom sheet.
  static const dragHandleWidth = 40.0;
  static const dragHandleHeight = 4.0;

  /// Text fields (« Commune », « Filtrer les rues… »).
  static const fieldHeight = 52.0;
  static const fieldRadius = 12.0;
  static const fieldPadding = 14.0;

  /// A street of the start list (name over its progress bar).
  static const streetRowHeight = 64.0;

  /// A street of the import checklist.
  static const choiceRowHeight = 56.0;

  /// The progress bar of a street row.
  static const progressBarHeight = 6.0;

  /// Small pill buttons inside a screen (« Tout cocher »). Their tap target
  /// still grows to [minTapTarget].
  static const pillHeight = 40.0;

  /// Icons inside buttons and the chevron of a row.
  static const smallIcon = 20.0;
}
