/// Sizes and radii of the mockups, in logical pixels (dp).
abstract final class AppSizes {
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

  /// Space left and right of a main button's label, whatever the font size.
  static const buttonPadding = 24.0;

  /// The same for any other filled or outlined button (the theme's).
  static const themeButtonPadding = 16.0;

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

  /// The ink outline of the tile whose status picker shows (PLAN §5.6).
  static const selectedTileOutline = 3.0;

  static const tilePadding = 14.0;

  /// A building tile's side padding. Smaller than [tilePadding] because its
  /// building icon and chevron have empty room of their own (about 4 and
  /// 2 dp): drawn, they still start and end 14 dp from the edges, and the
  /// number keeps the width they give back.
  static const buildingTileStartPadding = 10.0;
  static const buildingTileEndPadding = 12.0;

  /// The width a tile's number always keeps (one digit and the ellipsis):
  /// when a building's count would leave less, the count shrinks instead.
  static const tileNumberMinWidth = 24.0;
  static const sheetRadius = 24.0;
  static const snackBarRadius = 14.0;

  /// Width of every outline (tiles, secondary buttons).
  static const borderWidth = 1.5;

  /// Side margin of a screen's content.
  static const gutter = 16.0;

  /// The grabber at the top of a bottom sheet.
  static const dragHandleWidth = 40.0;
  static const dragHandleHeight = 4.0;

  /// The street card's ✕ (Pick mockup): a 48 dp button this far from the
  /// card's top and right edges, level with the grabber; the street's name
  /// keeps this much room on its right so it never runs under it.
  static const sheetCloseTop = 6.0;
  static const sheetCloseRight = 8.0;
  static const sheetCloseClearance = 40.0;

  /// Text fields (« Commune », « Filtrer les rues… »).
  static const fieldHeight = 52.0;
  static const fieldRadius = 12.0;
  static const fieldPadding = 14.0;

  /// A street of Accueil's panel (name over its progress bar).
  static const streetRowHeight = 64.0;

  /// A street of the import checklist.
  static const choiceRowHeight = 56.0;

  /// The progress bar of a street row.
  static const progressBarHeight = 6.0;

  /// Small pill buttons inside a screen (« Tout cocher »). Their tap target
  /// still grows to [minTapTarget].
  static const pillHeight = 40.0;

  /// Icons inside buttons, the chevron of a row, and the building icon and
  /// the « › » of a building tile.
  static const smallIcon = 20.0;

  /// A row of options (« Esc. A | Esc. B »…) and the blue « Repasser »
  /// block of a building's own sheet.
  static const segmentHeight = 52.0;

  /// The status buttons of the status picker (PLAN §5.6): 72 dp at least,
  /// two a row, the current one ringed in ink a gap away.
  static const statusChoiceHeight = 72.0;
  static const statusChoiceRadius = 16.0;
  static const statusChoiceGlyph = 24.0;
  static const statusChoiceGap = 10.0;
  static const statusChoiceRing = 2.0;
  static const statusChoiceRingGap = 3.0;
  static const segmentRadius = 14.0;
  static const segmentGlyph = 18.0;
  static const comeBackPadding = 14.0;

  /// The ↻ before « Repasser ».
  static const comeBackGlyph = 20.0;

  /// The Immeuble grid fills the screen but this gap at the top, where the
  /// street stays visible, dimmed (Building mockup).
  static const fullSheetTopGap = 40.0;

  /// The round badge of a tile or door that took two calendars or more
  /// (#114): 24 dp, its 2 dp ring in the ground colour, its centre this far
  /// out of the tile's top right corner. The gaps between tiles and doors
  /// are wider than [calendarBadgeOverhang], so it never covers a
  /// neighbour; the lists start that much lower, so the first row's badge
  /// is not cut.
  static const calendarBadge = 24.0;
  static const calendarBadgeRing = 2.0;
  static const calendarBadgeOverhang = 7.0;

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

  /// The ▾ of « Gérer l'immeuble ▾ » (Material's own button icon size).
  static const gridButtonIcon = 18.0;

  /// A row of the « Décrire l'immeuble » sheet: its (−) and (+) buttons
  /// and the value between them.
  static const stepperRowHeight = 60.0;
  static const stepperButton = 48.0;
  static const stepperValueWidth = 96.0;

  /// The « 51, 52… | 5A, 5B… | Libres » choice and the staircase control.
  static const labelStyleHeight = 48.0;

  /// A number of the edit mode (Edit mockup): 56 dp, the least PLAN §5
  /// allows for a street tile, so the ✕ fits beside it.
  static const editTileHeight = 56.0;

  /// The dark « OK » pill of the edit mode's top bar; its tap target still
  /// grows to [minTapTarget].
  static const okButtonHeight = 44.0;
  static const okButtonPadding = 20.0;

  /// A top bar whose title has a line under it (« Modifier les portes »
  /// over « 8 Rue des Lilas »), and the gap between the two lines.
  static const titleBarWithSubtitleHeight = 72.0;
  static const titleSubtitleGap = 6.0;

  /// A door of « Modifier les portes »: its label zone (tap to rename) ends
  /// with [doorLabelEnd] of empty room, then the ✕ zone. The ✕ zone is
  /// narrower than [minTapTarget] so a tap just right of the label still
  /// renames; it stays [doorHeight] tall, so it is still 52 dp to aim at.
  static const doorLabelStart = 14.0;
  static const doorLabelEnd = 18.0;
  static const doorRemoveWidth = 36.0;
  static const doorRemoveGlyph = 20.0;

  /// A row of Paramètres (« Prénom    Manu › »).
  static const settingRowHeight = 56.0;

  /// A tournée of « Mes secteurs »: its name over its centre.
  static const sectorRowHeight = 68.0;

  /// The round mark before a tournée of « Mes secteurs » (● open, ○ another,
  /// dashed while the request waits), and the dot inside it.
  static const sectorMark = 22.0;
  static const sectorMarkDot = 10.0;

  /// The ▾ after the open tournée's name in the title.
  static const titleChevron = 22.0;

  /// The red dot on Accueil's title while a join request waits (Home
  /// mockup, #135), and on a row of « Mes secteurs ».
  static const waitingDot = 12.0;

  /// The card of Équipe holding the QR code and the join code, and the QR
  /// code in it.
  static const codeCardRadius = 20.0;
  static const qrCode = 100.0;

  /// A join request's card in Équipe.
  static const requestCardRadius = 16.0;

  /// The banner « Administrateur · pas membre » on Accueil (HomeAdmin
  /// mockup): 14 radius, a 22 dp shield, a 40 dp-high « Rejoindre » pill
  /// kept 48 dp tall to the finger.
  static const adminBannerRadius = 14.0;
  static const adminBannerIcon = 22.0;

  /// The round initial before a member or a request (« M », « J »).
  static const avatar = 36.0;

  /// A member of Équipe, and its « Corbeille » row.
  static const memberRowHeight = 56.0;

  /// The trash icon in the avatar of the « Corbeille » row.
  static const avatarIcon = 18.0;

  /// A deleted street or number of the Corbeille: its name over who
  /// deleted it, and « Restaurer ».
  static const corbeilleRowHeight = 72.0;

  /// The cloud of « ☁ Modifications de 3 rues en attente d'envoi », and
  /// the gap between it and the text.
  static const pendingSyncGlyph = 18.0;
  static const pendingSyncGap = 8.0;

  /// The red square holding the calendar on « Bienvenue », its corner and
  /// the calendar in it (Welcome mockup).
  static const welcomeLogo = 64.0;
  static const welcomeLogoRadius = 18.0;
  static const welcomeLogoIcon = 34.0;

  /// A tall field: « Votre prénom » on « Bienvenue ».
  static const tallFieldHeight = 56.0;

  /// « Scanner le QR code » on « Rejoindre », and its icon (Join mockup).
  static const scanButtonHeight = 120.0;
  static const scanButtonRadius = 20.0;
  static const scanIcon = 36.0;

  /// A box of the join code.
  static const codeBoxHeight = 64.0;

  /// The card of the tournée a code shows, and the number square in it.
  static const previewCardRadius = 16.0;
  static const previewBadge = 52.0;
  static const previewBadgeRadius = 14.0;

  /// The round clock of « Demande envoyée » and the clock in it
  /// (JoinPending mockup).
  static const pendingBadge = 72.0;
  static const pendingIcon = 34.0;

  /// The QR code of a tournée just created (Create mockup).
  static const createdQrCode = 176.0;

  /// A warning framed in red (« … existe déjà »), and its ⚠.
  static const alertRadius = 14.0;
  static const alertGlyph = 20.0;

  /// A row of the list of centres de secours.
  static const optionRowHeight = 48.0;

  /// A house dot on the map at street zoom 18 (HomeZoom mockup), and the
  /// status glyph in it; drawn smaller further out (see `map_style.dart`).
  static const houseDot = 30.0;
  static const houseDotGlyph = 16.0;

  /// The round buttons over the map (« Me localiser »), their icon, and
  /// their distance from the map's edges.
  static const mapButton = 48.0;
  static const mapButtonIcon = 22.0;
  static const mapControlsMargin = 12.0;

  /// The map's legend (Home and HomeZoom mockups): a white card of this
  /// radius; each entry a 22 dp line sample or an 18 dp house dot before
  /// its word.
  static const legendRadius = 12.0;
  static const legendLineSample = 22.0;
  static const legendDot = 18.0;

  /// Accueil's « Rues » panel (RunStart mockup): folded down, only its
  /// handle and its totals show, in this height; at rest it takes this
  /// share of the room under the top bar.
  static const homePanelFolded = 76.0;
  static const homePanelRestShare = 0.5;

  /// The street card (Pick mockup): its facts in grey chips of this radius,
  /// this far apart from the blocks around them.
  static const chipRadius = 10.0;
  static const cardGap = 12.0;

  /// The search box of « Ajouter des rues »: a white pill (Pick mockup).
  static const searchRadius = 24.0;

  /// The tallest the search results may grow over the map, as a share of
  /// its height.
  static const searchResultsShare = 0.6;

  /// A street ticked in the selection sheet of « Ajouter des rues » (Pick
  /// mockup): its name over its commune, and its ✕.
  static const pickedRowHeight = 52.0;

  /// The selection sheet shows this many rows of streets ticked, then
  /// scrolls (PLAN §5.14)...
  static const pickedRowsShown = 4;

  /// ... and never more than this share of the map's height, so the map
  /// still shows with a large font.
  static const selectionListShare = 0.35;

  /// A zone drawn on « Ajouter des rues » (PickZone mockup): the map
  /// outside it dimmed by the ink at this opacity, its edge a dashed line
  /// of this width (dashes and gaps of these lengths), and a round handle
  /// of this radius at its south-east corner.
  static const zoneShadeOpacity = 0.18;
  static const zoneEdgeWidth = 2.5;
  static const zoneDash = 8.0;
  static const zoneGap = 6.0;
  static const zoneHandleRadius = 9.0;

  /// A finger down this close to the zone's handle resizes the zone
  /// rather than drawing a new one: half a tap target around it.
  static const zoneHandleReach = 24.0;

  /// A drag shorter than this on either side draws no zone: a tap that
  /// slid a little.
  static const zoneMinSide = 16.0;

  /// The checkbox of a street in the zone's list, and its corners.
  static const zoneCheckBox = 24.0;
  static const zoneCheckRadius = 6.0;

  /// The dashed square of the « Zone » pill.
  static const zoneIcon = 20.0;

  /// The dot of « ● En tournée » (PLAN §5.14).
  static const roundDot = 10.0;

  /// The corners of the « Bilan »'s figures.
  static const roundCardRadius = 16.0;

  /// The « En tournée » band (PLAN §5.14): its Accent edge on the left, the
  /// room between the edge and the words, and the sides of « ■ Terminer ».
  static const roundBandEdge = 6.0;
  static const roundBandIndent = 20.0;
  static const roundFinishPadding = 18.0;

  /// The column of the amounts in « Dons de la tournée », so the methods
  /// line up.
  static const donationAmountWidth = 72.0;

  /// The field « Montant ».
  static const amountFieldHeight = 64.0;

  /// A line of « ARGENT RÉCOLTÉ » in the « Bilan », and its amount column.
  static const recapLineHeight = 60.0;
  static const recapAmountWidth = 84.0;

  /// A validated tournée in « TOURNÉES » of the Collecte screen, and, once
  /// unfolded, each of its methods under it, indented; the column of its
  /// ▸ / ▾, which the methods leave empty so the amounts line up.
  static const collecteRoundHeight = 60.0;
  static const collecteDetailLineHeight = 44.0;
  static const collecteDetailIndent = 36.0;
  static const collecteChevronWidth = 18.0;
}
