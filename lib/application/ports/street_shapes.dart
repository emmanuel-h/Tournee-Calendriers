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
}

/// Why the [StreetShapes] could not answer.
enum StreetShapesFailure {
  /// The phone could not reach the service, or it did not answer in time.
  /// Trying again with a better signal may work.
  noNetwork,

  /// The service answered with an error or with something unreadable.
  /// Trying again later may work.
  serviceError,
}
