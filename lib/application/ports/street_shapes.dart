import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/road_side.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// Where streets run: the line of a street, asked for a street to add on
/// « Ajouter des rues » and for a street of the secteur that has none yet,
/// and the roads of an area with the BAN street of each (PLAN §5.3, §5.14,
/// §5.18, §9).
///
/// The roads come from IGN BD TOPO, which gives each stretch of road the
/// BAN id of the street on each side, so a street is found by its id, never
/// by its name. The map's own roads (OpenStreetMap), matched by name, are
/// only the fallback.
///
/// An outbound port: an adapter in `infrastructure/geopf/` implements it
/// over HTTP, tests use a fake. A call may need the network; a failure
/// comes back as an [Err] holding a [StreetShapesFailure], never as an
/// exception.
abstract interface class StreetShapes {
  /// The line of the BAN street [banId]: every stretch of road carrying
  /// that id on either side, joined where they meet, each with every point
  /// it has ([StreetShape.simplified] makes it small enough to store).
  ///
  /// [name] and [area] (around the street's houses, see `shapeSearchArea`)
  /// serve when no road carries the id (a new estate not mapped yet, a
  /// street with no BAN id): then the map's roads named [name] inside
  /// [area] are taken, matched as [StreetName.matches] says.
  /// [StreetShape.none] when neither has the street: it then shows as its
  /// house dots only.
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required BanStreetId? banId,
    required StreetName name,
    required GeoBounds area,
  });

  /// The stretches of road running through [area] (« Zone » on « Ajouter
  /// des rues », and the road under a tap), each with the BAN street of
  /// one side or of both ([BanRoad]), in the order the service gives them.
  /// Each stretch is whole, not cut to [area]. A road with no name and no
  /// BAN street is left out.
  ///
  /// [StreetShapesFailure.tooLarge] when [area] holds too many stretches
  /// to read them all.
  Future<Result<List<BanRoad>, StreetShapesFailure>> roadsIn(GeoBounds area);

  /// The named roads of the map itself (OpenStreetMap) that run through
  /// [area], one per name, in the order the map gives them, each drawn
  /// whole as far as the map's tiles under [area] go: the fallback for a
  /// tap where [roadsIn] gives no BAN street (PLAN §5.14, #134).
  /// [StreetShapesFailure.tooLarge] when [area] needs too many tiles.
  Future<Result<List<NamedRoad>, StreetShapesFailure>> namedRoadsIn(
    GeoBounds area,
  );
}

/// A stretch of road and the BAN street on one of its sides, or on both
/// (PLAN §5.18): « Rue Nationale » on both sides, or « Rue de Gleteins »
/// on the left and « Gleteins » on the right.
final class BanRoad {
  const BanRoad({
    required this.banId,
    required this.name,
    required this.commune,
    required this.shape,
    this.side,
  });

  /// The BAN street of that side; null for a named road the BAN has no
  /// street for (a path, a private road): « Aucune adresse connue ».
  final BanStreetId? banId;

  /// The BAN's name of the street, or the road's own name when it has no
  /// BAN street.
  final String name;

  /// The commune of that side; null when the service gives none.
  final InseeCode? commune;

  /// The stretch, every point it has, in the order it runs: [side] is
  /// read walking it that way.
  final StreetShape shape;

  /// The side of [shape] this street is on; null when it is on both.
  final RoadSide? side;

  @override
  bool operator ==(Object other) =>
      other is BanRoad &&
      other.banId == banId &&
      other.name == name &&
      other.commune == commune &&
      other.shape == shape &&
      other.side == side;

  @override
  int get hashCode => Object.hash(banId, name, commune, shape, side);

  @override
  String toString() => 'BanRoad(${banId?.value}, $name, ${side?.name})';
}

/// A road of the map with its name, as OpenStreetMap writes it (« Rue du
/// Musée », where the BAN may write « Rue du Musee »).
final class NamedRoad {
  const NamedRoad({required this.name, required this.shape});

  final String name;

  /// Its pieces, each with every point the map has.
  final StreetShape shape;

  @override
  bool operator ==(Object other) =>
      other is NamedRoad && other.name == name && other.shape == shape;

  @override
  int get hashCode => Object.hash(name, shape);

  @override
  String toString() => 'NamedRoad($name)';
}

/// Why the [StreetShapes] could not answer.
enum StreetShapesFailure {
  /// The phone has no way out (no route, the name of the service not
  /// found), or the service did not answer in time. Trying again with a
  /// better signal may work.
  noNetwork,

  /// The phone has a connection, but the service refused or cut it, or
  /// answered with an error or with something unreadable. Trying again
  /// later may work.
  serviceError,

  /// The area asked of [StreetShapes.roadsIn] or
  /// [StreetShapes.namedRoadsIn] holds too many roads to read them all: a
  /// smaller one may work.
  tooLarge,
}
