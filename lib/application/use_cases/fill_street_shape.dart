import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// What [FillStreetShape] did, when nothing went wrong.
enum ShapeFillOutcome {
  /// The street got its line on the map.
  filled,

  /// The map has no road of that name around the street's houses: the
  /// street keeps showing as its house dots.
  noRoad,

  /// The street needs no shape (it has one, is in the Corbeille, has no
  /// house on the map, or is gone): nothing was asked.
  notNeeded,
}

/// Gives a street of the tournée without a line on the map the road the
/// map draws for it (PLAN §5.3): a street imported from a list, or added
/// from the map before its road was known. Needs the network, unless
/// [call] is given the road already.
///
/// Through `Street.fillShape`, which sets a shape only while there is
/// none: a teammate's phone filling it first wins, and this changes
/// nothing.
final class FillStreetShape {
  const FillStreetShape(this._shapes, this._streets);

  final StreetShapes _shapes;
  final StreetRepository _streets;

  /// Fills the shape of the street [id], with [road] when the caller knows
  /// it already (« Ajouter des rues » found it for the card, simplified),
  /// otherwise with the roads named like the street around its houses
  /// (`shapeSearchArea`), simplified.
  ///
  /// A [StreetShapesFailure] when the map's service could not answer: the
  /// street can be tried again later.
  Future<Result<ShapeFillOutcome, StreetShapesFailure>> call(
    StreetId id, {
    StreetShape? road,
  }) async {
    final street = await _streets.find(id);
    if (street == null) return const Ok(ShapeFillOutcome.notNeeded);
    if (road != null) return _fill(street, road);
    if (!street.needsShape) return const Ok(ShapeFillOutcome.notNeeded);
    final area = shapeSearchArea([
      for (final house in street.houses) ?house.position,
    ])!;
    switch (await _shapes.shapeOf(name: street.name, area: area)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        // Read again: the map may have taken a few seconds, and a
        // teammate's phone may have filled the shape meanwhile.
        final now = await _streets.find(id);
        if (now == null) return const Ok(ShapeFillOutcome.notNeeded);
        return _fill(now, value.simplified());
    }
  }

  Future<Result<ShapeFillOutcome, StreetShapesFailure>> _fill(
    Street street,
    StreetShape shape,
  ) async {
    switch (street.fillShape(shape)) {
      case Err(failure: ShapeFillFailure.alreadyShaped):
        return const Ok(ShapeFillOutcome.notNeeded);
      case Err(failure: ShapeFillFailure.noLine):
        return const Ok(ShapeFillOutcome.noRoad);
      case Ok(value: (final filled, final change)):
        await _streets.save(filled, change);
        return const Ok(ShapeFillOutcome.filled);
    }
  }
}
