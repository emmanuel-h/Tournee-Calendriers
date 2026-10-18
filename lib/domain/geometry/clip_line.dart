import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// The pieces of [line] that run inside [bounds], in the order the line
/// runs: a line leaving the bounds and coming back gives two pieces. Where
/// a piece crosses a side, it ends on that side. Nothing when the line
/// stays outside.
///
/// Used to keep only the part of a road near a street's houses (a road of
/// the same name in the next commune is cut off), and to cut a road taken
/// from a map tile to the tile itself (each tile repeats a strip of its
/// neighbours, PLAN §9).
///
/// Latitude and longitude are treated as flat coordinates: over a few
/// hundred metres the bend of a straight segment is far below a metre.
List<List<GeoPoint>> clipLine(List<GeoPoint> line, GeoBounds bounds) {
  final pieces = <List<GeoPoint>>[];
  List<GeoPoint>? current;
  for (var i = 1; i < line.length; i++) {
    final start = line[i - 1];
    final end = line[i];
    final inside = _clipSegment(start, end, bounds);
    if (inside == null) {
      // The segment is outside; the piece before it, if any, ended on a
      // side already (see below).
      continue;
    }
    final (from, to) = inside;
    // The previous segment ended inside, at this segment's start: the piece
    // goes on. Otherwise a new piece starts where the segment comes in.
    (current ??= [from]).add(to);
    if (!identical(to, end)) {
      // The segment leaves the bounds: its piece ends on the side.
      pieces.add(current);
      current = null;
    }
  }
  if (current != null) pieces.add(current);
  return pieces;
}

/// The part of the segment [start]–[end] inside [bounds], or null when it
/// has none (or only touches a corner). An end inside comes back as the
/// very same object, so the caller can tell the segment did not leave.
///
/// The Liang–Barsky method: the segment is `start + t × (end − start)` for
/// `t` from 0 to 1; each side of the bounds narrows the range of `t` that
/// stays on its inner side.
(GeoPoint, GeoPoint)? _clipSegment(
  GeoPoint start,
  GeoPoint end,
  GeoBounds bounds,
) {
  final dx = end.longitude - start.longitude;
  final dy = end.latitude - start.latitude;
  var enter = 0.0;
  var leave = 1.0;
  // Each side as (p, q): the segment is inside that side while
  // `t × p ≤ q`.
  final sides = [
    (-dx, start.longitude - bounds.west),
    (dx, bounds.east - start.longitude),
    (-dy, start.latitude - bounds.south),
    (dy, bounds.north - start.latitude),
  ];
  for (final (p, q) in sides) {
    if (p == 0) {
      // Parallel to that side: wholly inside it or wholly outside.
      if (q < 0) return null;
    } else if (p < 0) {
      // Coming in through that side.
      final t = q / p;
      if (t > enter) enter = t;
    } else {
      // Going out through that side.
      final t = q / p;
      if (t < leave) leave = t;
    }
  }
  // `>=`: a segment touching the bounds by one point only (a corner) has
  // nothing inside.
  if (enter >= leave) return null;
  return (
    enter == 0 ? start : _along(start, dx, dy, enter),
    leave == 1 ? end : _along(start, dx, dy, leave),
  );
}

/// The point at [t] along the segment from [start] by ([dx], [dy]).
GeoPoint _along(GeoPoint start, double dx, double dy, double t) {
  // Between two points on Earth, so on Earth too: the cast cannot fail.
  final point = GeoPoint.create(
    latitude: start.latitude + t * dy,
    longitude: start.longitude + t * dx,
  );
  return (point as Ok<GeoPoint, GeoPointFailure>).value;
}
