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
/// whether the secteur has it (PLAN §5.4, §5.14). Changes nothing.
///
/// Needs the network: the geocoder and the map's tiles for a tap, the BAN
/// for the numbers of a street the secteur does not have. A street of the
/// secteur needs no numbers: they are in the street already.
///
/// **A tap names the road under the finger, not the nearest BAN street.**
/// The geocoder measures the distance to one point of each street (about
/// its middle), so near a crossing, or on a long road far from its middle,
/// it answers another street (#134: a ✓ put on a road whose street was
/// another, drawn elsewhere or not at all). The map's tiles tell which
/// named road runs under the finger; the BAN street of that name, in the
/// commune of the geocoder's answer, is the one tapped.
final class LookUpStreet {
  const LookUpStreet(this._directory, this._streets, this._shapes);

  /// How far from the finger a road of the map may run to be the one
  /// tapped: about a fingertip at street zoom, a road and its pavements.
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
    final StreetMatch match;
    GeoPoint? mark;
    switch (lookup) {
      case FoundStreet(match: final found):
        match = found;
      case StreetAtPoint(:final point):
        // Both asked at once: a tap waits for the slower one only. A record
        // of futures has `wait`, which gives back a record of their values.
        // The road tells which street was tapped, and where on it the ✓
        // goes.
        final (nearest, road) = await (
          _directory.streetAt(point),
          _roadAt(point),
        ).wait;
        switch (await _streetAt(nearest, road?.name)) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            match = value;
            mark = road?.shape.nearestPointTo(point);
        }
    }
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
  Future<NamedRoad?> _roadAt(GeoPoint point) async {
    final area = GeoBounds.around([point])!.expandedBy(tapReachMetres);
    final roads = switch (await _shapes.roadsIn(area)) {
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
}
