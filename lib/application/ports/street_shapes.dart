import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// Where a street runs, as OpenStreetMap draws it on the map: the line of
/// the street, asked for a street to add on « Ajouter des rues », and for a
/// street of the tournée that has none yet (PLAN §5.3, §5.4, §9).
///
/// An outbound port: an adapter in `infrastructure/map_tiles/` implements
/// it over HTTP, tests use a fake. A call may need the network; a failure
/// comes back as an [Err] holding a [StreetShapesFailure], never as an
/// exception.
abstract interface class StreetShapes {
  /// The roads named [name] inside [area] (around the street's houses, see
  /// `shapeSearchArea`), cut where they leave it, each with every point it
  /// has: [StreetShape.simplified] makes it small enough to store.
  ///
  /// The area keeps out a road of the same name in the next commune. The
  /// name is matched as [StreetName.matches] says (case, accents,
  /// apostrophes, hyphens), because the BAN often writes it without its
  /// accents. [StreetShape.none] when no road matches: the street then
  /// shows as its house dots only.
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required StreetName name,
    required GeoBounds area,
  });

  /// The named roads that run through [area] (« Zone » on « Ajouter des
  /// rues », and the road under a tap, PLAN §5.14), one per name, in the
  /// order the map gives them. Each is drawn whole as far as the map's
  /// tiles under [area] go, not cut to [area]: it shows where the street
  /// runs. Read at street level (where small roads exist) however far out
  /// the map is; [StreetShapesFailure.tooLarge] when [area] needs too many
  /// tiles to read.
  Future<Result<List<NamedRoad>, StreetShapesFailure>> roadsIn(GeoBounds area);
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

  /// The area asked of [StreetShapes.roadsIn] spans too many of the map's
  /// tiles to read them all: a smaller one may work.
  tooLarge,
}
