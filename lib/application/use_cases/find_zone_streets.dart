import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/street_zone.dart';
import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// A street found in a zone drawn on « Ajouter des rues » (PLAN §5.14,
/// §5.18, PickZone mockup): its road as IGN BD TOPO draws it, and where its
/// ✓ disc sits, inside the zone. `sealed`: the zone's list shows each case.
sealed class ZoneStreet {
  const ZoneStreet({required this.road, required this.mark});

  /// Its stretches that run through the zone, each whole: drawn on the
  /// map. A street ticked has its whole line looked up by its id
  /// (`LookUpStreetShape`), which is the one stored.
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

/// A named road that has no BAN street (a path, a private road), or whose
/// BAN street the BAN no longer lists: greyed, « Aucune adresse connue ».
final class ZoneRoadWithoutAddress extends ZoneStreet {
  const ZoneRoadWithoutAddress({
    required this.name,
    required super.road,
    required super.mark,
  });

  /// The road's own name, as IGN writes it (« ESP PAUL BERT »).
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
  /// IGN BD TOPO or the BAN could not be reached.
  noNetwork,

  /// IGN BD TOPO or the BAN answered with an error.
  serviceError,

  /// More than [zoneMaxStreets] BAN streets in the zone, or too many
  /// stretches of road to read them.
  tooManyStreets,
}

/// The streets of a zone drawn on « Ajouter des rues » (PLAN §5.14,
/// §5.18): the stretches of road of IGN BD TOPO in it, grouped by the BAN
/// id they carry, one row per BAN street, whatever its name and commune.
/// Changes nothing. Needs the network.
///
/// The BAN street of each row is read in its commune's list (one request
/// per commune of the zone, by id, not by name): its name as the BAN writes
/// it, its commune's name and how many numbers it has. Its numbers come
/// when the street is added.
final class FindZoneStreets {
  const FindZoneStreets(this._shapes, this._directory, this._streets);

  final StreetShapes _shapes;
  final AddressDirectory _directory;
  final StreetRepository _streets;

  /// The streets of [zone]: those to add first, then those the secteur
  /// has, then the roads without address, each group in French order.
  Future<Result<List<ZoneStreet>, FindZoneFailure>> call(GeoBounds zone) async {
    final List<BanRoad> roads;
    switch (await _shapes.roadsIn(zone)) {
      case Err(:final failure):
        return Err(switch (failure) {
          StreetShapesFailure.noNetwork => FindZoneFailure.noNetwork,
          StreetShapesFailure.serviceError => FindZoneFailure.serviceError,
          // Too many stretches: certainly too many streets, unread.
          StreetShapesFailure.tooLarge => FindZoneFailure.tooManyStreets,
        });
      case Ok(:final value):
        // The service gives every stretch touching the zone's box; one
        // that only grazes a corner has no piece inside.
        roads = [
          for (final road in value)
            if (markInZone(road.shape, zone) != null) road,
        ];
    }

    // The stretches of each BAN street, and of each road without one, by
    // name. A Dart map keeps the order its keys were added in.
    final byStreet = <BanStreetId, _Stretches>{};
    final byName = <String, _Stretches>{};
    for (final road in roads) {
      final group = switch (road.banId) {
        final id? => byStreet[id] ??= _Stretches(road),
        null => byName[road.name] ??= _Stretches(road),
      };
      group.lines.addAll(road.shape.lines);
    }
    if (byStreet.length > zoneMaxStreets) {
      return const Err(FindZoneFailure.tooManyStreets);
    }

    // The lists of the communes of the zone's streets, each read once.
    final listings = <InseeCode, CommuneStreets>{};
    for (final insee in {for (final group in byStreet.values) ?group.commune}) {
      switch (await _directory.streetsOf(insee)) {
        case Err(failure: AddressDirectoryFailure.notFound):
          continue;
        case Err(failure: AddressDirectoryFailure.noNetwork):
          return const Err(FindZoneFailure.noNetwork);
        case Err(failure: AddressDirectoryFailure.serviceError):
          return const Err(FindZoneFailure.serviceError);
        case Ok(:final value):
          listings[insee] = value;
      }
    }

    final found = <ZoneStreet>[];
    for (final MapEntry(key: id, value: group) in byStreet.entries) {
      final road = StreetShape(group.lines);
      final mark = markInZone(road, zone)!;
      final listing = listings[group.commune];
      final street = listing?.streets
          .where((street) => street.id == id)
          .firstOrNull;
      if (street == null) {
        // BD TOPO knows a BAN street the BAN no longer lists.
        found.add(
          ZoneRoadWithoutAddress(name: group.name, road: road, mark: mark),
        );
        continue;
      }
      final match = StreetMatch(
        id: id,
        name: street.name,
        commune: listing!.commune,
        position: mark,
      );
      found.add(await _streetOf(match, street.numberCount, road));
    }
    for (final group in byName.values) {
      final road = StreetShape(group.lines);
      found.add(
        ZoneRoadWithoutAddress(
          name: group.name,
          road: road,
          mark: markInZone(road, zone)!,
        ),
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

/// The stretches of one street (or one road without BAN street) in a zone,
/// named and placed by the first of them.
final class _Stretches {
  _Stretches(BanRoad first) : name = first.name, commune = first.commune;

  final String name;
  final InseeCode? commune;
  final lines = <List<GeoPoint>>[];
}
