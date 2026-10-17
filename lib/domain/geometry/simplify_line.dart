import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';

/// [line] with fewer points but the same look on the map: every point
/// closer than [toleranceMetres] to the simplified line is dropped
/// (Douglas–Peucker). The first and last points always stay.
///
/// A road from OpenStreetMap can have a point every few metres; a street's
/// shape is stored in its document and downloaded by every member, so it is
/// kept small (≈ 1 KB a street, PLAN §6.2).
///
/// How it works: keep the two ends; find the point farthest from the
/// segment joining them; if it is farther than the tolerance, keep it and
/// do the same on each half, otherwise drop every point in between.
List<GeoPoint> simplifyLine(
  List<GeoPoint> line, {
  required double toleranceMetres,
}) {
  if (line.length <= 2) return List.unmodifiable(line);
  final kept = List.filled(line.length, false);
  kept[0] = true;
  kept[line.length - 1] = true;
  _keepFarthest(line, 0, line.length - 1, toleranceMetres, kept);
  return List.unmodifiable([
    for (var i = 0; i < line.length; i++)
      if (kept[i]) line[i],
  ]);
}

/// Marks in [kept] the points between [first] and [last] (both kept
/// already) that the simplified line needs. Recursive: each call splits
/// its stretch in two at the farthest point.
void _keepFarthest(
  List<GeoPoint> line,
  int first,
  int last,
  double toleranceMetres,
  List<bool> kept,
) {
  var farthest = -1;
  // Starting at the tolerance means a point exactly at it is dropped: only
  // a point strictly farther counts.
  var farthestMetres = toleranceMetres;
  for (var i = first + 1; i < last; i++) {
    final metres = metresFromSegment(line[i], line[first], line[last]);
    if (metres > farthestMetres) {
      farthest = i;
      farthestMetres = metres;
    }
  }
  if (farthest < 0) return;
  kept[farthest] = true;
  _keepFarthest(line, first, farthest, toleranceMetres, kept);
  _keepFarthest(line, farthest, last, toleranceMetres, kept);
}
