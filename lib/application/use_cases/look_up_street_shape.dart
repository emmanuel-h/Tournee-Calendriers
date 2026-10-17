import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// The road of a street the tournée does not have yet, to highlight it on
/// the map of « Ajouter des rues » while its card shows (PLAN §5.4).
/// Changes nothing. Needs the network.
///
/// The shape comes simplified, as `AddStreetFromMap` stores it: the card
/// hands it over when the street is added, so Overpass (slow, often busy)
/// is asked once per street.
final class LookUpStreetShape {
  const LookUpStreetShape(this._shapes);

  final StreetShapes _shapes;

  /// The road of [street]; [StreetShape.none] when OpenStreetMap does not
  /// know it, a [StreetShapesFailure] when Overpass could not answer.
  Future<Result<StreetShape, StreetShapesFailure>> call(
    StreetMatch street,
  ) async => (await _shapes.shapeOf(
    name: street.name,
    commune: street.commune.inseeCode,
  )).map((shape) => shape.simplified());
}
