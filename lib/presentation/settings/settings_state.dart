import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// The themes Paramètres offers (PLAN §5.9). The screens' own copy of the
/// application's `ThemeChoice`: `ui/` may not name the application layer.
enum AppTheme {
  /// « Système »: light or dark as the phone is set.
  system,

  /// « Clair ».
  light,

  /// « Sombre ».
  dark,
}

/// One line of « VOS NOMS PAR SECTEUR » (PLAN §5.16): « Secteur 49 · CS
/// Villefranche » and the name the member goes by there.
final class SectorNameLine {
  const SectorNameLine({
    required this.id,
    required this.number,
    required this.centre,
    required this.name,
  });

  final SectorId id;
  final int number;

  /// The centre de secours, as it was written.
  final String centre;

  /// The member's name there; null when the phone knows none (no prénom
  /// yet, and none kept for that secteur).
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is SectorNameLine &&
      other.id == id &&
      other.number == number &&
      other.centre == centre &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, number, centre, name);

  @override
  String toString() => 'SectorNameLine(${id.value}, $number, $name)';
}

/// What Paramètres shows of the member's settings (PLAN §5.9), and the
/// theme the whole app is drawn in. Immutable: the notifier replaces it.
final class SettingsState {
  const SettingsState({
    required this.name,
    required this.theme,
    this.sectorNames = const [],
  });

  /// The member's first name; null until they give one.
  final String? name;
  final AppTheme theme;

  /// The member's secteurs (requests included, visits left out) with the
  /// name they go by in each, in the order of « Mes secteurs ».
  final List<SectorNameLine> sectorNames;

  /// « VOS NOMS PAR SECTEUR » shows only when a secteur knows the member
  /// under another name than [name] (#148).
  bool get showsSectorNames => sectorNames.any((line) => line.name != name);

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      other.name == name &&
      other.theme == theme &&
      sameItems(other.sectorNames, sectorNames);

  @override
  int get hashCode => Object.hash(name, theme, Object.hashAll(sectorNames));
}

/// What became of a name typed in « Votre prénom » or « Votre nom dans le
/// secteur 49 » (PLAN §5.9, §5.16). `sealed`: the sheet handles each case.
sealed class NameOutcome {
  const NameOutcome();
}

/// The name is kept everywhere it was asked for: the sheet closes.
final class NameSaved extends NameOutcome {
  const NameSaved();
}

/// The text typed cannot be a name: said under the field.
final class NameNotValid extends NameOutcome {
  const NameNotValid(this.reason);

  final MemberNameFailure reason;

  @override
  bool operator ==(Object other) =>
      other is NameNotValid && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// The server could not be reached: nothing was changed (« Pas de
/// réseau »).
final class NameOffline extends NameOutcome {
  const NameOffline();
}

/// The prénom is kept, but in [kept] another member holds it: the member
/// keeps their old name there (« « Paul » est déjà pris dans le secteur 49
/// : vous y gardez « Paul D. ». »).
final class NameKeptIn extends NameOutcome {
  const NameKeptIn(this.kept);

  final List<SectorNameLine> kept;

  @override
  bool operator ==(Object other) =>
      other is NameKeptIn && sameItems(other.kept, kept);

  @override
  int get hashCode => Object.hashAll(kept);
}

/// The name typed for one secteur is held there by another member.
final class NameTakenThere extends NameOutcome {
  const NameTakenThere();
}

/// The member is no longer in that secteur: nothing was changed.
final class NameSectorGone extends NameOutcome {
  const NameSectorGone();
}
