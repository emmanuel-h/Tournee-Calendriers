import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// Where the street to show on the card of « Ajouter des rues » comes from
/// (PLAN §5.4). `sealed`: [LookUpStreet] handles each one.
sealed class StreetLookup {
  const StreetLookup();
}

/// A tap on a road of the map, at [point].
final class StreetAtPoint extends StreetLookup {
  const StreetAtPoint(this.point);

  final GeoPoint point;
}

/// A street chosen among the results of the search box (`SearchStreet`).
final class FoundStreet extends StreetLookup {
  const FoundStreet(this.match);

  final StreetMatch match;
}

/// The street the card is about. `sealed`: the card adapts to each case.
sealed class LookedUpStreet {
  const LookedUpStreet(this.match);

  /// The BAN street: its name and commune for the card, its point to
  /// centre the map on.
  final StreetMatch match;
}

/// The secteur does not have the street (or only in its Corbeille): the
/// card offers « Ajouter et me l'attribuer » and « Ajouter sans
/// m'attribuer », which give [numbers] to `AddStreetFromMap`.
final class StreetToAdd extends LookedUpStreet {
  const StreetToAdd(
    super.match,
    this.numbers, {
    this.mark,
    this.fromCorbeille = false,
  });

  /// The numbers of the street, each with its position when the BAN has
  /// one.
  final StreetNumbers numbers;

  /// Where its ✓ sits on the map of « Ajouter des rues » (#132): the point
  /// of the road under the finger nearest to it, so the ✓ is on the road
  /// rather than beside it. Null when the map has no named road within
  /// reach of the tap, and for a street found by the search.
  final GeoPoint? mark;

  /// The secteur has the street in its Corbeille: adding it brings it back
  /// as it went, its own part included (PLAN §5.15), so no part is chosen
  /// for it.
  final bool fromCorbeille;

  /// « 19 numéros » on the card.
  int get numberCount => numbers.numbers.length;
}

/// The secteur has the street already, out of the Corbeille: the card shows
/// its progress and offers to open it.
final class StreetOfTheSector extends LookedUpStreet {
  const StreetOfTheSector(super.match, this.street);

  final Street street;
}

/// Finds the BAN street of a tap on the map or of a search result, and
/// whether the secteur has it (PLAN §5.4, §5.14, §5.18). Changes nothing.
///
/// Needs the network: IGN BD TOPO (else the geocoder and the map's tiles)
/// for a tap, the BAN for the numbers of a street the secteur does not
/// have. A street of the secteur needs no numbers: they are in the street
/// already.
///
/// **A tap names the road under the finger, by its BAN id** (#166). IGN BD
/// TOPO gives each stretch of road the BAN street of each side: the
/// nearest stretch carrying one within [tapReachMetres] is the street
/// tapped, the side under the finger when its two sides differ (a hamlet
/// road along a street of almost its name). Its name, commune and numbers
/// come from the BAN by that id.
///
/// Where BD TOPO has no such stretch (or cannot answer), the older path
/// stands (#134): the geocoder measures the distance to one point of each
/// street (about its middle), so near a crossing, or on a long road far
/// from its middle, it answers another street; the map's tiles tell which
/// named road runs under the finger, and the BAN street of that name, in
/// the commune of the geocoder's answer, is the one tapped.
final class LookUpStreet {
  const LookUpStreet(this._directory, this._streets, this._shapes);

  /// How far from the finger a road may run to be the one tapped: about a
  /// fingertip at street zoom, a road and its pavements.
  static const tapReachMetres = 30.0;

  final AddressDirectory _directory;
  final StreetRepository _streets;
  final StreetShapes _shapes;

  /// The street of [lookup], or why the BAN could not tell:
  /// [AddressDirectoryFailure.notFound] when no street is near a tap, or
  /// none of the name of the road tapped,
  /// [AddressDirectoryFailure.noNetwork] offline.
  Future<Result<LookedUpStreet, AddressDirectoryFailure>> call(
    StreetLookup lookup,
  ) async {
    switch (lookup) {
      case FoundStreet(:final match):
        return _lookedUp(match);
      case StreetAtPoint(:final point):
        if (await _banRoadAt(point) case final road?) {
          switch (await _byId(road, point)) {
            // A BAN id the BAN no longer has (BD TOPO lags behind it): as
            // if BD TOPO had nothing there.
            case Err(failure: AddressDirectoryFailure.notFound):
              break;
            case final byId:
              return byId;
          }
        }
        return _byGeocoder(point);
    }
  }

  /// The street of [match], with its numbers when the secteur does not
  /// have it; its ✓ at [mark].
  Future<Result<LookedUpStreet, AddressDirectoryFailure>> _lookedUp(
    StreetMatch match, {
    GeoPoint? mark,
  }) async {
    final known = await _streets.findByBanId(match.id);
    // A street of the Corbeille is offered to add again: adding it brings
    // it back with its marks (`AddStreetFromMap`).
    if (known != null && !known.isDeleted) {
      return Ok(StreetOfTheSector(match, known));
    }
    return (await _directory.numbersOf(match.id)).map(
      (numbers) =>
          StreetToAdd(match, numbers, mark: mark, fromCorbeille: known != null),
    );
  }

  /// The BAN street of [road], tapped at [point]: its name and commune from
  /// the secteur's street when it has it, else from the BAN's numbers.
  /// Its point, and its ✓, on [road] under the finger.
  Future<Result<LookedUpStreet, AddressDirectoryFailure>> _byId(
    BanRoad road,
    GeoPoint point,
  ) async {
    final id = road.banId!;
    final mark = road.shape.nearestPointTo(point)!;
    final known = await _streets.findByBanId(id);
    if (known != null && !known.isDeleted) {
      final match = StreetMatch(
        id: id,
        name: known.name,
        commune: known.commune,
        position: mark,
      );
      return Ok(StreetOfTheSector(match, known));
    }
    return (await _directory.numbersOf(id)).map(
      (numbers) => StreetToAdd(
        StreetMatch(
          id: id,
          name: numbers.name,
          commune: numbers.commune,
          position: mark,
        ),
        numbers,
        mark: mark,
        fromCorbeille: known != null,
      ),
    );
  }

  /// The stretch of BD TOPO with a BAN street nearest to [point], within
  /// [tapReachMetres]; of a stretch whose two sides differ, the side under
  /// the finger. Null when there is none, or BD TOPO cannot answer.
  Future<BanRoad?> _banRoadAt(GeoPoint point) async {
    final roads = switch (await _shapes.roadsIn(_tapArea(point))) {
      Ok(:final value) => value,
      Err() => const <BanRoad>[],
    };
    BanRoad? nearestRoad;
    var nearest = tapReachMetres;
    var nearestFacing = false;
    for (final road in roads) {
      final metres = road.shape.metresFrom(point);
      if (road.banId == null || metres == null) continue;
      // The two sides of a stretch are one line, as far from the finger:
      // the side the finger is on wins.
      final facing = road.side == null || road.side == road.shape.sideOf(point);
      final better = nearestRoad == null
          ? metres <= nearest
          : metres < nearest || (metres == nearest && facing && !nearestFacing);
      if (better) {
        nearestRoad = road;
        nearest = metres;
        nearestFacing = facing;
      }
    }
    return nearestRoad;
  }

  /// The street of a tap at [point] by the geocoder and the map's road
  /// names (#134): what stands where BD TOPO has no BAN street.
  Future<Result<LookedUpStreet, AddressDirectoryFailure>> _byGeocoder(
    GeoPoint point,
  ) async {
    // Both asked at once: a tap waits for the slower one only. A record of
    // futures has `wait`, which gives back a record of their values. The
    // road tells which street was tapped, and where on it the ✓ goes.
    final (nearest, road) = await (
      _directory.streetAt(point),
      _namedRoadAt(point),
    ).wait;
    return switch (await _streetAt(nearest, road?.name)) {
      Err(:final failure) => Err(failure),
      Ok(value: final match) => _lookedUp(
        match,
        mark: road?.shape.nearestPointTo(point),
      ),
    };
  }

  /// The BAN street of the road [road] under the finger, given the
  /// geocoder's [nearest] street: that street when it is the road, or when
  /// the map has no named road within [tapReachMetres] (or cannot answer);
  /// otherwise the street of the road's name in the nearest street's
  /// commune, or of a name close enough to be the road's misspelt (#134).
  Future<Result<StreetMatch, AddressDirectoryFailure>> _streetAt(
    Result<StreetMatch, AddressDirectoryFailure> nearest,
    String? road,
  ) async {
    switch (nearest) {
      case Err():
        return nearest;
      case Ok(value: final street):
        if (road == null || street.name.matches(road)) return nearest;
        return switch (await _directory.searchStreets(
          road,
          commune: street.commune.inseeCode,
        )) {
          Err(:final failure) => Err(failure),
          // The map may misspell the road (« Rue de le Paix » for the
          // BAN's « Rue de la Paix »): the street named exactly is taken,
          // else the closest to the road's name, the geocoder's own street
          // included, which the search may not list (`closestNamed`).
          Ok(value: final found) => switch (closestNamed(road, [
            ...found,
            street,
          ], (each) => each.name)) {
            final named? => Ok(named),
            // The road has a name the BAN does not give a street there (a
            // path, a road of the next commune), or two streets are as
            // close to it: better nothing than a street the finger was not
            // on.
            null => const Err(AddressDirectoryFailure.notFound),
          },
        };
    }
  }

  /// The named road of the map nearest to [point], within
  /// [tapReachMetres]; null when there is none, or the map's tiles could
  /// not be read (the geocoder's answer then stands alone, as it did
  /// before #134).
  Future<NamedRoad?> _namedRoadAt(GeoPoint point) async {
    final roads = switch (await _shapes.namedRoadsIn(_tapArea(point))) {
      Ok(:final value) => value,
      Err() => const <NamedRoad>[],
    };
    NamedRoad? nearestRoad;
    var nearest = tapReachMetres;
    for (final road in roads) {
      final metres = road.shape.metresFrom(point);
      if (metres != null && metres <= nearest) {
        nearestRoad = road;
        nearest = metres;
      }
    }
    return nearestRoad;
  }

  /// Where the roads under a tap at [point] are looked for.
  static GeoBounds _tapArea(GeoPoint point) =>
      GeoBounds.around([point])!.expandedBy(tapReachMetres);
}
