import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// What the « Carte » tab of « Ajouter des rues » shows (PLAN §5.14, Pick
/// mockup): the secteur's streets and houses, the area the map shows, the
/// streets ticked (on the map and in the selection sheet), the point being
/// looked up, the search box's results and how adding goes.
/// Immutable: the notifier replaces it as a whole.
final class AddStreetsMapState {
  AddStreetsMapState({
    required this.layers,
    required this.area,
    List<PickedStreetRow> picked = const [],
    List<PickedRoad> pickedRoads = const [],
    this.lookingAt,
    this.search = const NoStreetSearch(),
    this.run = const AddIdle(),
  }) : picked = List.unmodifiable(picked),
       pickedRoads = List.unmodifiable(pickedRoads);

  /// The streets and house dots, as the domain decides them.
  final MapLayers layers;

  /// Where the map is: the secteur's communes, else its streets, until a
  /// street is picked among the search results, then around it; null (all
  /// of France) when nothing has a place on the map.
  final GeoBounds? area;

  /// The streets ticked, in the order they were: one row each in the
  /// selection sheet. Read-only.
  final List<PickedStreetRow> picked;

  /// The same streets as the map draws them: each road with a ✓ disc.
  /// Read-only.
  final List<PickedRoad> pickedRoads;

  /// Where the finger last tapped while the street there is looked up
  /// (the BAN needs a moment): marked by a dot, and the sheet says
  /// « Recherche de la rue… ». Null when nothing is looked up.
  final GeoPoint? lookingAt;

  /// The search box's results.
  final StreetSearch search;

  /// How adding the ticked streets goes.
  final AddRun run;

  /// Whether the ticked streets are being added: the map, the ticks and
  /// the way back wait.
  bool get adding => run is AddRunning;
}

/// A street ticked, as its row of the selection sheet shows it: « Rue
/// Pierre Morin » over « Villefranche-sur-Saône · 19 numéros », and its ✕.
final class PickedStreetRow {
  const PickedStreetRow({
    required this.id,
    required this.name,
    required this.commune,
    required this.numberCount,
  });

  /// The street ✕ unticks.
  final BanStreetId id;
  final String name;
  final String commune;

  /// How many numbers the street brings.
  final int numberCount;

  @override
  bool operator ==(Object other) =>
      other is PickedStreetRow &&
      other.id == id &&
      other.name == name &&
      other.commune == commune &&
      other.numberCount == numberCount;

  @override
  int get hashCode => Object.hash(id, name, commune, numberCount);

  @override
  String toString() => 'PickedStreetRow(${id.value}, $name, $numberCount)';
}

/// Why a street could not be looked up, or searched; the screen says so
/// and offers « Saisir à la main », which needs no network.
enum LookUpProblem {
  /// Offline: « Connexion nécessaire pour ajouter une rue ».
  noNetwork,

  /// The BAN knows no street there (a private road, a new estate).
  noStreetHere,

  /// The address service answered with an error.
  serviceError,
}

/// What a tap on the map, or a street picked in the search, has to say.
/// The ticks themselves show in the state; only what does not show there
/// comes back, for the screen's snackbar. `sealed`: the screen handles each
/// case.
sealed class TapAnswer {
  const TapAnswer();
}

/// Nothing to say: a street was ticked or unticked, or the tap was dropped
/// (a newer « Tout décocher », the streets being added, the screen gone).
final class NothingToSay extends TapAnswer {
  const NothingToSay();

  @override
  bool operator ==(Object other) => other is NothingToSay;

  @override
  int get hashCode => (NothingToSay).hashCode;
}

/// The secteur has the street [name] already: nothing ticked, « Rue des
/// Lilas est déjà dans le secteur. ».
final class AlreadyInSector extends TapAnswer {
  const AlreadyInSector(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is AlreadyInSector && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'AlreadyInSector($name)';
}

/// No street could be looked up, for [problem]: nothing ticked.
final class LookUpFailed extends TapAnswer {
  const LookUpFailed(this.problem);

  final LookUpProblem problem;

  @override
  bool operator ==(Object other) =>
      other is LookUpFailed && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;

  @override
  String toString() => 'LookUpFailed(${problem.name})';
}

/// How adding the ticked streets goes. `sealed`: the sheet shows each case.
sealed class AddRun {
  const AddRun();
}

/// Nothing being added, nothing failed: « Ajouter 2 rues ».
final class AddIdle extends AddRun {
  const AddIdle();

  @override
  bool operator ==(Object other) => other is AddIdle;

  @override
  int get hashCode => (AddIdle).hashCode;
}

/// [done] of [total] streets stored: « Ajout en cours… 2/3 ».
final class AddRunning extends AddRun {
  const AddRunning(this.done, this.total);

  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is AddRunning && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'AddRunning($done/$total)';
}

/// [failed] streets could not be added: the numbers the BAN gave cannot
/// make a street (a number twice). They stay ticked, the others are in the
/// secteur; the sheet says why above the button.
final class AddFailed extends AddRun {
  const AddFailed(this.failed);

  final int failed;

  @override
  bool operator ==(Object other) =>
      other is AddFailed && other.failed == failed;

  @override
  int get hashCode => failed.hashCode;

  @override
  String toString() => 'AddFailed($failed)';
}

/// Where the search box is. `sealed`: the results list has a look for
/// each case.
sealed class StreetSearch {
  const StreetSearch();
}

/// Nothing searched, or the search was closed: no list.
final class NoStreetSearch extends StreetSearch {
  const NoStreetSearch();

  @override
  bool operator ==(Object other) => other is NoStreetSearch;

  @override
  int get hashCode => (NoStreetSearch).hashCode;
}

/// The address service is asked.
final class SearchingStreets extends StreetSearch {
  const SearchingStreets();

  @override
  bool operator ==(Object other) => other is SearchingStreets;

  @override
  int get hashCode => (SearchingStreets).hashCode;
}

/// The streets found, best first; none says « Aucune rue trouvée ».
final class StreetsFound extends StreetSearch {
  StreetsFound(List<FoundStreetRow> streets)
    : streets = List.unmodifiable(streets);

  /// Read-only.
  final List<FoundStreetRow> streets;

  @override
  bool operator ==(Object other) =>
      other is StreetsFound && sameItems(other.streets, streets);

  @override
  int get hashCode => Object.hashAll(streets);
}

/// The search could not be made, for [problem]
/// ([LookUpProblem.noNetwork] or [LookUpProblem.serviceError]).
final class StreetSearchFailed extends StreetSearch {
  const StreetSearchFailed(this.problem);

  final LookUpProblem problem;

  @override
  bool operator ==(Object other) =>
      other is StreetSearchFailed && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
}

/// A street found by the search: « Rue Pierre Morin · Villefranche-sur-
/// Saône ». Picking it sends its [id] back.
final class FoundStreetRow {
  const FoundStreetRow({
    required this.id,
    required this.name,
    required this.commune,
  });

  final BanStreetId id;
  final String name;
  final String commune;

  @override
  bool operator ==(Object other) =>
      other is FoundStreetRow &&
      other.id == id &&
      other.name == name &&
      other.commune == commune;

  @override
  int get hashCode => Object.hash(id, name, commune);

  @override
  String toString() => 'FoundStreetRow(${id.value}, $name, $commune)';
}
