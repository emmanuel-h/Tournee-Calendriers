import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/street_zone.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// A street found in a zone drawn on « Ajouter des rues » (PLAN §5.14,
/// PickZone mockup): its road as the map draws it, and where its ✓ disc
/// sits, inside the zone. `sealed`: the zone's list shows each case.
sealed class ZoneStreet {
  const ZoneStreet({required this.road, required this.mark});

  /// Its road, whole as far as the map's tiles go: drawn on the map, never
  /// stored (it may be cut where the tiles end; Accueil fills the street's
  /// road from its houses, PLAN §5.3).
  final StreetShape road;

  /// A point of [road] inside the zone (`markInZone`).
  final GeoPoint mark;

  /// The name the list shows.
  String get name;
}

/// A BAN street the secteur does not have (or only in its Corbeille):
/// ticked when the zone is drawn. Its numbers are read when it is added.
final class ZoneStreetToAdd extends ZoneStreet {
  const ZoneStreetToAdd({
    required this.match,
    required this.numberCount,
    required super.road,
    required super.mark,
    this.fromCorbeille = false,
  });

  /// The BAN street, its position at [mark].
  final StreetMatch match;

  /// « 19 numéros »: what the BAN lists for the street.
  final int numberCount;

  /// The secteur has the street in its Corbeille: adding it brings it back
  /// as it went, so no part is chosen for it (PLAN §5.15).
  final bool fromCorbeille;

  @override
  String get name => match.name.text;

  @override
  bool operator ==(Object other) =>
      other is ZoneStreetToAdd &&
      other.match == match &&
      other.numberCount == numberCount &&
      other.road == road &&
      other.mark == mark &&
      other.fromCorbeille == fromCorbeille;

  @override
  int get hashCode =>
      Object.hash(match, numberCount, road, mark, fromCorbeille);

  @override
  String toString() => 'ZoneStreetToAdd(${match.id.value}, $name)';
}

/// A BAN street the secteur has already: greyed, « Déjà dans le
/// secteur ».
final class ZoneStreetInSector extends ZoneStreet {
  const ZoneStreetInSector({
    required this.match,
    required super.road,
    required super.mark,
  });

  final StreetMatch match;

  @override
  String get name => match.name.text;

  @override
  bool operator ==(Object other) =>
      other is ZoneStreetInSector &&
      other.match == match &&
      other.road == road &&
      other.mark == mark;

  @override
  int get hashCode => Object.hash(match, road, mark);

  @override
  String toString() => 'ZoneStreetInSector(${match.id.value}, $name)';
}

/// A road of the map that no BAN street of the secteur's communes is named
/// after (a path, a private road): greyed, « Aucune adresse connue ».
final class ZoneRoadWithoutAddress extends ZoneStreet {
  const ZoneRoadWithoutAddress({
    required this.name,
    required super.road,
    required super.mark,
  });

  /// The name as the map writes it.
  @override
  final String name;

  @override
  bool operator ==(Object other) =>
      other is ZoneRoadWithoutAddress &&
      other.name == name &&
      other.road == road &&
      other.mark == mark;

  @override
  int get hashCode => Object.hash(name, road, mark);

  @override
  String toString() => 'ZoneRoadWithoutAddress($name)';
}

/// Why [FindZoneStreets] listed nothing.
enum FindZoneFailure {
  /// The map's tiles or the BAN could not be reached.
  noNetwork,

  /// The map's tiles or the BAN answered with an error.
  serviceError,

  /// More than [zoneMaxStreets] named roads in the zone, or a zone too
  /// large to read its roads.
  tooManyStreets,
}

/// The streets of a zone drawn on « Ajouter des rues » (PLAN §5.14): the
/// named roads of the map's tiles in it (as #92 reads shapes), each matched
/// to its BAN street by name in the secteur's communes (the exact name,
/// else the name the road misspells, `closestNamed`). Changes nothing.
/// Needs the network.
///
/// Only the commune lists are read (one request per commune), not the
/// numbers of each street: those come when a street is added.
final class FindZoneStreets {
  const FindZoneStreets(this._shapes, this._directory, this._streets);

  /// The most communes whose streets are read for one zone. A zone of a
  /// few streets touches one to three communes; a secteur may have fifty,
  /// and a road no BAN street is named after must not read them all.
  static const communesAsked = 3;

  final StreetShapes _shapes;
  final AddressDirectory _directory;
  final StreetRepository _streets;

  /// The streets of [zone]: those to add first, then those the secteur
  /// has, then the roads without address, each group in French order.
  ///
  /// [communes] are the secteur's, the likeliest first (the nearest to the
  /// zone): a name found in two of them is taken in the first, and only the
  /// first [communesAsked] are read, each only while a road is still
  /// unmatched. A commune the BAN does not know has no street.
  Future<Result<List<ZoneStreet>, FindZoneFailure>> call(
    GeoBounds zone, {
    required List<InseeCode> communes,
  }) async {
    final List<NamedRoad> roads;
    switch (await _shapes.roadsIn(zone)) {
      case Err(:final failure):
        return Err(switch (failure) {
          StreetShapesFailure.noNetwork => FindZoneFailure.noNetwork,
          StreetShapesFailure.serviceError => FindZoneFailure.serviceError,
          // Too many tiles: certainly too many streets, unread.
          StreetShapesFailure.tooLarge => FindZoneFailure.tooManyStreets,
        });
      case Ok(:final value):
        roads = [
          for (final road in value)
            if (markInZone(road.shape, zone) != null) road,
        ];
    }
    if (roads.length > zoneMaxStreets) {
      return const Err(FindZoneFailure.tooManyStreets);
    }

    // The BAN street of each road, by its index in `roads`.
    final matches = <int, StreetMatch>{};
    final numberCounts = <BanStreetId, int>{};
    void take(int i, CommuneStreets listed, DirectoryStreet street) {
      final match = StreetMatch(
        id: street.id,
        name: street.name,
        commune: listed.commune,
        position: markInZone(roads[i].shape, zone)!,
      );
      matches[i] = match;
      numberCounts[match.id] = street.numberCount;
    }

    // First the names as they are, commune by commune.
    final read = <CommuneStreets>[];
    for (final insee in communes.take(communesAsked)) {
      if (matches.length == roads.length) break;
      final CommuneStreets listed;
      switch (await _directory.streetsOf(insee)) {
        case Err(failure: AddressDirectoryFailure.notFound):
          continue;
        case Err(failure: AddressDirectoryFailure.noNetwork):
          return const Err(FindZoneFailure.noNetwork);
        case Err(failure: AddressDirectoryFailure.serviceError):
          return const Err(FindZoneFailure.serviceError);
        case Ok(:final value):
          listed = value;
      }
      read.add(listed);
      for (var i = 0; i < roads.length; i++) {
        if (matches.containsKey(i)) continue;
        final street = listed.streets
            .where((street) => street.name.matches(roads[i].name))
            .firstOrNull;
        if (street != null) take(i, listed, street);
      }
    }
    // Then a road still unmatched may be a BAN street misspelt by the map
    // (« Rue de le Paix », #134): the closest name, in the nearest commune
    // that has one. Only after every commune read, so that a name exact in
    // a farther commune wins over a near one in the first.
    for (var i = 0; i < roads.length; i++) {
      if (matches.containsKey(i)) continue;
      for (final listed in read) {
        final street = closestNamed(
          roads[i].name,
          listed.streets,
          (street) => street.name,
        );
        if (street == null) continue;
        take(i, listed, street);
        break;
      }
    }

    // Two roads may name one BAN street (« Rue du Musée » and « Rue du
    // Musee »): one row, with both roads. A Dart map keeps the order its
    // keys were added in.
    final byStreet = <BanStreetId, (StreetMatch, List<List<GeoPoint>>)>{};
    final found = <ZoneStreet>[];
    for (var i = 0; i < roads.length; i++) {
      final road = roads[i];
      switch (matches[i]) {
        case null:
          found.add(
            ZoneRoadWithoutAddress(
              name: road.name,
              road: road.shape,
              mark: markInZone(road.shape, zone)!,
            ),
          );
        case final match:
          final (first, lines) =
              byStreet[match.id] ?? (match, const <List<GeoPoint>>[]);
          byStreet[match.id] = (first, [...lines, ...road.shape.lines]);
      }
    }
    for (final (match, lines) in byStreet.values) {
      found.add(
        await _streetOf(match, numberCounts[match.id]!, StreetShape(lines)),
      );
    }
    found.sort(_listOrder);
    return Ok(found);
  }

  /// [match] as the list shows it: to add, or in the secteur already.
  Future<ZoneStreet> _streetOf(
    StreetMatch match,
    int numberCount,
    StreetShape road,
  ) async {
    final known = await _streets.findByBanId(match.id);
    // A street of the Corbeille is offered to add again: adding it brings
    // it back with its marks (`AddStreetFromMap`).
    if (known != null && !known.isDeleted) {
      return ZoneStreetInSector(match: match, road: road, mark: match.position);
    }
    return ZoneStreetToAdd(
      match: match,
      numberCount: numberCount,
      road: road,
      mark: match.position,
      fromCorbeille: known != null,
    );
  }

  static int _listOrder(ZoneStreet a, ZoneStreet b) {
    final byKind = _rank(a).compareTo(_rank(b));
    return byKind != 0 ? byKind : compareFrench(a.name, b.name);
  }

  static int _rank(ZoneStreet street) => switch (street) {
    ZoneStreetToAdd() => 0,
    ZoneStreetInSector() => 1,
    ZoneRoadWithoutAddress() => 2,
  };
}
