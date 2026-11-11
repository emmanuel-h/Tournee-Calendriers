import 'package:tournee_calendriers/presentation/street_part/street_part_state.dart';

// What the red link « Toute la rue › » of a row of « Ajouter des rues »
// (selection sheet, zone's list, « Liste ») found when tapped (PLAN §5.15
// « When adding »). Shared by the « Carte » and « Liste » tabs.

/// Why the numbers of a street could not be read to choose its part.
enum PartReadProblem {
  /// Offline: « Connexion nécessaire pour lire les numéros de la rue. ».
  noNetwork,

  /// The address service did not answer as it should: « Impossible de lire
  /// les numéros de la rue pour l'instant. Réessayez plus tard. ».
  unavailable,
}

/// What a tap on the part link of a row found. `sealed`: the screen
/// handles each case.
sealed class PartOpening {
  const PartOpening();
}

/// « Partie de la rue » opens on [request]; the part chosen comes back to
/// the notifier with `choosePart`.
final class PartToChoose extends PartOpening {
  const PartToChoose(this.request);

  final StreetPartRequest request;
}

/// The street's numbers could not be read, for [problem]: nothing opens.
final class PartUnreadable extends PartOpening {
  const PartUnreadable(this.problem);

  final PartReadProblem problem;

  @override
  bool operator ==(Object other) =>
      other is PartUnreadable && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;

  @override
  String toString() => 'PartUnreadable(${problem.name})';
}

/// A teammate added the street [name] meanwhile: « Rue des Lilas est déjà
/// dans le secteur. », its part is chosen in edit mode.
final class PartOfStreetInSector extends PartOpening {
  const PartOfStreetInSector(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is PartOfStreetInSector && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'PartOfStreetInSector($name)';
}

/// Nothing opens and nothing is said: the street is no longer ticked, its
/// numbers are already being read, or the streets are being added.
final class PartNotOpened extends PartOpening {
  const PartNotOpened();

  @override
  bool operator ==(Object other) => other is PartNotOpened;

  @override
  int get hashCode => (PartNotOpened).hashCode;

  @override
  String toString() => 'PartNotOpened';
}
