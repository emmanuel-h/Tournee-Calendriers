import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// The road of a street the tournée does not have yet, to highlight it on
/// the map of « Ajouter des rues » while its card shows (PLAN §5.4).
/// Changes nothing. Needs the network.
///
/// The shape comes simplified, as the street stores it: the card hands it
/// over when the street is added, so the map is not asked twice.
final class LookUpStreetShape {
  const LookUpStreetShape(this._shapes);

  final StreetShapes _shapes;

  /// The road of [street], looked for around its numbers and the point
  /// the BAN gives for it (`shapeSearchArea`); [StreetShape.none] when the
  /// map has no road of that name there, a [StreetShapesFailure] when the
  /// map's service could not answer.
  Future<Result<StreetShape, StreetShapesFailure>> call(
    StreetToAdd street,
  ) async {
    final area = shapeSearchArea([
      street.match.position,
      for (final number in street.numbers.numbers) ?number.position,
    ])!;
    return (await _shapes.shapeOf(
      name: street.match.name,
      area: area,
    )).map((shape) => shape.simplified());
  }
}
