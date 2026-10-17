import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

/// What the « Carte » tab of « Ajouter des rues » shows (PLAN §5.4, Pick
/// mockup): the tournée's streets and houses, the area the map shows, the
/// road picked and its street card, and the search box's results.
/// Immutable: the notifier replaces it as a whole.
final class AddStreetsMapState {
  const AddStreetsMapState({
    required this.layers,
    required this.area,
    this.selectedRoad = StreetShape.none,
    this.selectedPoint,
    this.card,
    this.search = const NoStreetSearch(),
  });

  /// The streets and house dots, as the domain decides them.
  final MapLayers layers;

  /// Where the map is: the tournée's communes, else its streets, until a
  /// street is picked among the search results, then around it; null (all
  /// of France) when nothing has a place on the map.
  final GeoBounds? area;

  /// The road of the street the card shows, highlighted; none while it is
  /// not known (OpenStreetMap is slow to tell, or does not know it).
  final StreetShape selectedRoad;

  /// Where the finger tapped, or where the street found by the search is:
  /// marked until the road shows; null when no card shows, or for a street
  /// of the tournée picked by its line.
  final GeoPoint? selectedPoint;

  /// The street card at the bottom; null when none shows.
  final StreetCard? card;

  /// The search box's results.
  final StreetSearch search;
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
