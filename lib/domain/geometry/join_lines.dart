import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';

/// [lines] with every two lines whose ends meet joined into one, until no
/// two ends meet: a road cut at the edges of map tiles, or in several
/// pieces by OpenStreetMap, becomes one line again.
///
/// Two ends meet when they are at most [toleranceMetres] apart; the joined
/// line keeps one of the two points. A line may be turned round to be
/// joined (its end meeting the other's end). Lines that meet no other come
/// back as they are, in their order.
List<List<GeoPoint>> joinLines(
  Iterable<List<GeoPoint>> lines, {
  required double toleranceMetres,
}) {
  final waiting = [for (final line in lines) line];
  final joined = <List<GeoPoint>>[];
  while (waiting.isNotEmpty) {
    var line = waiting.removeAt(0);
    // Each pass adds one line at either end; it stops when none meets.
    var grew = true;
    while (grew) {
      grew = false;
      for (var i = 0; i < waiting.length; i++) {
        final longer = _joined(line, waiting[i], toleranceMetres);
        if (longer != null) {
          line = longer;
          waiting.removeAt(i);
          grew = true;
          break;
        }
      }
    }
    joined.add(line);
  }
  return joined;
}

/// [line] and [other] as one line when an end of each meets, null when
/// they do not touch.
List<GeoPoint>? _joined(
  List<GeoPoint> line,
  List<GeoPoint> other,
  double toleranceMetres,
) {
  bool meet(GeoPoint a, GeoPoint b) => metresBetween(a, b) <= toleranceMetres;

  // `skip(1)`: the point where they meet is kept once.
  if (meet(line.last, other.first)) return [...line, ...other.skip(1)];
  if (meet(line.last, other.last)) {
    return [...line, ...other.reversed.skip(1)];
  }
  if (meet(line.first, other.last)) return [...other, ...line.skip(1)];
  if (meet(line.first, other.first)) {
    return [...other.reversed, ...line.skip(1)];
  }
  return null;
}
