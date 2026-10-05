import 'package:flutter/material.dart';

/// The colour tokens of `docs/mockups/README.md`, as one immutable palette.
///
/// Widgets never write a colour literal: they read the palette of the current
/// theme with `AppColors.of(context)`. Because the palette is a
/// [ThemeExtension] stored in `ThemeData.extensions`, switching to the dark
/// palette (T5.1) is a matter of building a second `ThemeData`, with no change
/// in the widgets.
@immutable
final class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.divider,
    required this.accent,
    required this.onAccent,
    required this.disabled,
    required this.onDisabled,
    required this.scrim,
    required this.toDo,
    required this.onToDo,
    required this.toDoBorder,
    required this.done,
    required this.onDone,
    required this.doneBorder,
    required this.nobodyHome,
    required this.onNobodyHome,
    required this.nobodyHomeBorder,
    required this.comeBack,
    required this.onComeBack,
    required this.comeBackBorder,
    required this.buildingPartial,
    required this.onBuildingPartial,
    required this.buildingPartialBorder,
    required this.editTileBorder,
    required this.snackBar,
    required this.onSnackBar,
    required this.snackBarAction,
    required this.mapStreetDone,
    required this.mapStreetPartial,
    required this.mapStreetToDo,
    required this.mapStreetFree,
    required this.mapSelectedCasing,
    required this.mapSelectedCore,
  });

  /// The approved palette (mockups README). Values the README leaves implicit
  /// (status borders, disabled button, scrim) are copied from the mockups.
  static const light = AppColors(
    brightness: Brightness.light,
    ground: Color(0xFFF3F1EC),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF1B1F24),
    muted: Color(0xFF4A5058),
    line: Color(0xFFCFC9BD),
    divider: Color(0xFFE2DED5),
    accent: Color(0xFFB3261E),
    onAccent: Color(0xFFFFFFFF),
    disabled: Color(0xFFE2DED5),
    onDisabled: Color(0xFF4A5058),
    scrim: Color(0x801B1F24),
    toDo: Color(0xFFFFFFFF),
    onToDo: Color(0xFF1B1F24),
    toDoBorder: Color(0xFFCFC9BD),
    done: Color(0xFF1E6B47),
    onDone: Color(0xFFFFFFFF),
    doneBorder: Color(0xFF1E6B47),
    nobodyHome: Color(0xFFF2B33D),
    onNobodyHome: Color(0xFF1B1F24),
    nobodyHomeBorder: Color(0xFFD99A22),
    comeBack: Color(0xFFD6E6F5),
    onComeBack: Color(0xFF1D4E7A),
    comeBackBorder: Color(0xFFA9C8E6),
    buildingPartial: Color(0xFFEFE9DD),
    onBuildingPartial: Color(0xFF1B1F24),
    buildingPartialBorder: Color(0xFFCFC9BD),
    editTileBorder: Color(0xFF8A8F96),
    snackBar: Color(0xFF1B1F24),
    onSnackBar: Color(0xFFFFFFFF),
    snackBarAction: Color(0xFFF2B33D),
    mapStreetDone: Color(0xFF1E6B47),
    mapStreetPartial: Color(0xFFE0A21B),
    mapStreetToDo: Color(0xFF2F5DA8),
    mapStreetFree: Color(0xFF6B7078),
    mapSelectedCasing: Color(0xFF1B1F24),
    mapSelectedCore: Color(0xFFFFFFFF),
  );

  /// A first proposal for dark mode, not used yet: T5.1 reviews it on a phone
  /// and wires it. Status tints stay recognisable (same hues), with
  /// backgrounds darkened where white text or a dark ground would lose
  /// contrast.
  static const dark = AppColors(
    brightness: Brightness.dark,
    ground: Color(0xFF15181C),
    surface: Color(0xFF1F2328),
    ink: Color(0xFFECEAE5),
    muted: Color(0xFFA9AFB7),
    line: Color(0xFF4A5058),
    divider: Color(0xFF2E3238),
    accent: Color(0xFFD9473E),
    onAccent: Color(0xFFFFFFFF),
    disabled: Color(0xFF2E3238),
    onDisabled: Color(0xFFA9AFB7),
    scrim: Color(0xB3000000),
    toDo: Color(0xFF1F2328),
    onToDo: Color(0xFFECEAE5),
    toDoBorder: Color(0xFF4A5058),
    done: Color(0xFF237A51),
    onDone: Color(0xFFFFFFFF),
    doneBorder: Color(0xFF2E9463),
    nobodyHome: Color(0xFFF2B33D),
    onNobodyHome: Color(0xFF1B1F24),
    nobodyHomeBorder: Color(0xFFD99A22),
    comeBack: Color(0xFF1D3B57),
    onComeBack: Color(0xFFD6E6F5),
    comeBackBorder: Color(0xFF3A6A96),
    buildingPartial: Color(0xFF2B2822),
    onBuildingPartial: Color(0xFFECEAE5),
    buildingPartialBorder: Color(0xFF6B6558),
    editTileBorder: Color(0xFF8A8F96),
    snackBar: Color(0xFFECEAE5),
    onSnackBar: Color(0xFF1B1F24),
    snackBarAction: Color(0xFF9A3412),
    mapStreetDone: Color(0xFF2E9463),
    mapStreetPartial: Color(0xFFE0A21B),
    mapStreetToDo: Color(0xFF5B8BD9),
    mapStreetFree: Color(0xFF8A9099),
    mapSelectedCasing: Color(0xFFFFFFFF),
    mapSelectedCore: Color(0xFF1B1F24),
  );

  /// The palette of the nearest `Theme`. Every `ThemeData` of the app is
  /// built by `buildAppTheme`, which always registers one.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  final Brightness brightness;

  /// Screen background.
  final Color ground;

  /// Cards, sheets.
  final Color surface;

  /// Text.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Borders.
  final Color line;

  /// Dividers, progress tracks.
  final Color divider;

  /// Primary buttons.
  final Color accent;
  final Color onAccent;

  /// Disabled buttons.
  final Color disabled;
  final Color onDisabled;

  /// Dims the screen behind a bottom sheet.
  final Color scrim;

  // Tile tints, one background / text / border triple per status.
  final Color toDo;
  final Color onToDo;
  final Color toDoBorder;
  final Color done;
  final Color onDone;
  final Color doneBorder;
  final Color nobodyHome;
  final Color onNobodyHome;
  final Color nobodyHomeBorder;
  final Color comeBack;
  final Color onComeBack;
  final Color comeBackBorder;
  final Color buildingPartial;
  final Color onBuildingPartial;
  final Color buildingPartialBorder;

  /// The dashed outline of a number in edit mode (Edit mockup): grey, so
  /// the tiles read as « being edited », not as a status.
  final Color editTileBorder;

  /// The undo snackbar: dark bar, yellow action.
  final Color snackBar;
  final Color onSnackBar;
  final Color snackBarAction;

  // Map lines, used from T0.4 / M3.
  final Color mapStreetDone;
  final Color mapStreetPartial;
  final Color mapStreetToDo;
  final Color mapStreetFree;
  final Color mapSelectedCasing;
  final Color mapSelectedCore;

  // `copyWith` and `lerp` are required by ThemeExtension. The app never
  // animates between palettes, so `lerp` switches at the half-way point
  // instead of blending 36 colours.
  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
