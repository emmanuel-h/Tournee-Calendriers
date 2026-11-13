import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// The roads of the map itself (OpenStreetMap), found by their name: what
/// `IgnStreetShapes` falls back on when IGN BD TOPO has no road for a BAN
/// street (PLAN §5.18). An interface so its tests give a fake.
abstract interface class RoadsByName {
  /// The roads named [name] inside [area], cut where they leave it;
  /// [StreetShape.none] when none matches.
  Future<Result<StreetShape, StreetShapesFailure>> shapeOf({
    required StreetName name,
    required GeoBounds area,
  });

  /// The named roads running through [area], one per name, whole as far
  /// as the map's tiles go.
  Future<Result<List<NamedRoad>, StreetShapesFailure>> roadsIn(GeoBounds area);
}
