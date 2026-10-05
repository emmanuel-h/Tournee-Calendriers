/// Sizes and radii of the mockups, in logical pixels (dp).
abstract final class AppSizes {
  /// The small dot on a tile whose house has a note.
  static const noteDot = 8.0;

  /// Space between two tiles of a column of the street screen.
  static const tileGap = 10.0;

  /// Space between the two columns of the street screen.
  static const columnGap = 12.0;

  /// The counts row under the street's name, and the tap hint pill.
  static const streetCountsHeight = 44.0;
  static const hintHeight = 44.0;

  /// Where the counts start, under the street's name (back arrow + gap).
  static const streetCountsIndent = 64.0;

  /// Space left under the last tiles so the hint or the snackbar never
  /// hides them.
  static const streetListBottom = 96.0;

  /// Space between the bottom of the screen and the hint pill or the
  /// snackbar.
  static const floatingBottom = 20.0;

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

  /// The status control of the Fiche maison (« À faire | Fait | Personne »)
  /// and the blue « Repasser » block under it.
  static const segmentHeight = 52.0;
  static const segmentRadius = 14.0;
  static const segmentGlyph = 18.0;
  static const comeBackPadding = 14.0;

  /// The ↻ before « Repasser ».
  static const comeBackGlyph = 20.0;

  /// The Immeuble grid fills the screen but this gap at the top, where the
  /// street stays visible, dimmed (Building mockup).
  static const fullSheetTopGap = 40.0;

  /// A door of the Immeuble grid, four on a row.
  static const doorHeight = 52.0;
  static const doorGap = 8.0;
  static const doorsPerRow = 4;
  static const doorGlyph = 16.0;

  /// The floor label left of its doors (« RdC », « 1er »).
  static const floorLabelWidth = 40.0;

  /// The ◐ before the count of the grid's header.
  static const gridCountGlyph = 20.0;

  /// The buttons under the grid. The staircase control above it is 48 dp
  /// too ([labelStyleHeight]), not the mockup's 44: a tap target is never
  /// smaller.
  static const gridButtonHeight = 48.0;

  /// A row of the « Décrire l'immeuble » sheet: its (−) and (+) buttons
  /// and the value between them.
  static const stepperRowHeight = 60.0;
  static const stepperButton = 48.0;
  static const stepperValueWidth = 96.0;

  /// The « 51, 52… | 5A, 5B… | Libres » choice and the staircase control.
  static const labelStyleHeight = 48.0;
}
