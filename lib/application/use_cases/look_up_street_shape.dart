import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// The line of a street the secteur does not have yet, to draw it on the
/// map of « Ajouter des rues » while it is ticked, and to store it when it
/// is added (PLAN §5.4, §5.18). Changes nothing. Needs the network.
///
/// The shape comes simplified, as the street stores it: the tick hands it
/// over when the street is added, so nothing is asked twice.
final class LookUpStreetShape {
  const LookUpStreetShape(this._shapes);

  final StreetShapes _shapes;

  /// The line of the BAN street [match]: by its id, else (the map's roads
  /// by name) around [numbers] and the point of [match]
  /// (`shapeSearchArea`); [numbers] are not known yet for a street ticked
  /// in a zone. [StreetShape.none] when no road is found, a
  /// [StreetShapesFailure] when the service could not answer.
  Future<Result<StreetShape, StreetShapesFailure>> call(
    StreetMatch match, {
    StreetNumbers? numbers,
  }) async {
    final area = shapeSearchArea([
      match.position,
      for (final number in numbers?.numbers ?? const <DirectoryNumber>[])
        ?number.position,
    ])!;
    return (await _shapes.shapeOf(
      banId: match.id,
      name: match.name,
      area: area,
    )).map((shape) => shape.simplified());
  }
}
