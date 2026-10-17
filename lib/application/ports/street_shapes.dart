import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// Where a street runs, as OpenStreetMap draws it: the line of the street
/// on the map, asked once when the street is added from the map (PLAN §5.4,
/// §9).
///
/// An outbound port: an adapter in `infrastructure/overpass/` implements it
/// over HTTP, tests use a fake. Every call needs the network; a failure
/// comes back as an [Err] holding a [StreetShapesFailure], never as an
/// exception.
abstract interface class StreetShapes {
  /// The roads named [name] in the commune [commune], one line a road
  /// (OpenStreetMap often cuts a street in several), each with every point
  /// it has: [StreetShape.simplified] makes it small enough to store.
  ///
  /// The name is matched ignoring case, accents, the kind of apostrophe and
  /// hyphens against spaces, because the BAN often writes it without its
  /// accents (« Rue du Musee » for « Rue du Musée »). [StreetShape.none]
  /// when no road matches: the street then shows as its house dots only.
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required StreetName name,
    required InseeCode commune,
  });
}

/// Why the [StreetShapes] could not answer.
enum StreetShapesFailure {
  /// The phone could not reach the service, or it did not answer in time.
  /// Trying again with a better signal may work.
  noNetwork,

  /// The service answered with an error (it is often busy) or with
  /// something unreadable. Trying again later may work.
  serviceError,
}
