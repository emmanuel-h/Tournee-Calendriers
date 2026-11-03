import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

// The street card of « Ajouter des rues » and Accueil (PLAN §5.4, Pick
// mockup): what a street tapped on the map, or found by the search, is to
// the secteur, and what the member can do with it.

/// What the street card shows. `sealed`: the card has a layout for each
/// case, and the compiler checks that none is forgotten.
sealed class StreetCard {
  const StreetCard();
}

/// The street under the finger is being looked up (the BAN needs a
/// moment).
final class StreetCardLoading extends StreetCard {
  const StreetCardLoading();

  @override
  bool operator ==(Object other) => other is StreetCardLoading;

  @override
  int get hashCode => (StreetCardLoading).hashCode;
}

/// Why no street could be shown; the card says so and offers « Saisir une
/// rue à la main », which needs no network.
enum LookUpProblem {
  /// Offline: « Connexion nécessaire pour ajouter une rue ».
  noNetwork,

  /// The BAN knows no street there (a private road, a new estate).
  noStreetHere,

  /// The address service answered with an error.
  serviceError,
}

/// No street could be shown, for [problem].
final class StreetCardFailed extends StreetCard {
  const StreetCardFailed(this.problem);

  final LookUpProblem problem;

  @override
  bool operator ==(Object other) =>
      other is StreetCardFailed && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
}

/// A street the secteur does not have: « 19 numéros · Pas encore dans le
/// secteur », « Ajouter au secteur ».
final class StreetCardToAdd extends StreetCard {
  const StreetCardToAdd({
    required this.name,
    required this.commune,
    required this.numberCount,
    this.adding = false,
    this.addFailed = false,
  });

  final String name;
  final String commune;

  /// How many numbers the street would bring.
  final int numberCount;

  /// The street is being added (its road may take a while): the button
  /// waits.
  final bool adding;

  /// The address service gave numbers the street cannot take: nothing was
  /// added.
  final bool addFailed;

  @override
  bool operator ==(Object other) =>
      other is StreetCardToAdd &&
      other.name == name &&
      other.commune == commune &&
      other.numberCount == numberCount &&
      other.adding == adding &&
      other.addFailed == addFailed;

  @override
  int get hashCode =>
      Object.hash(name, commune, numberCount, adding, addFailed);
}

/// A street of the secteur: its progress and « Ouvrir » (PLAN §5.14). Every
/// member covers every street, so the card names nobody.
final class StreetCardInSector extends StreetCard {
  const StreetCardInSector({
    required this.id,
    required this.name,
    required this.commune,
    required this.done,
    required this.total,
  });

  /// The card of [street].
  factory StreetCardInSector.of(Street street) {
    final progress = street.progress;
    return StreetCardInSector(
      id: street.id,
      name: street.name.text,
      commune: street.commune.name,
      done: progress.visited,
      total: progress.total,
    );
  }

  /// The street « Ouvrir » opens.
  final StreetId id;
  final String name;
  final String commune;

  /// Doors visited (done or refused), out of [total].
  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is StreetCardInSector &&
      other.id == id &&
      other.name == name &&
      other.commune == commune &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(id, name, commune, done, total);

  @override
  String toString() =>
      'StreetCardInSector(${id.value}, $name, $commune, $done/$total)';
}
