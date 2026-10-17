import 'dart:math' as math;

import 'package:tournee_calendriers/domain/shared/geo_point.dart';

/// The mean radius of the Earth, in metres (IUGG).
const earthRadiusMetres = 6371008.8;

/// How many metres a degree of latitude spans (about 111 km). A degree of
/// longitude spans this times the cosine of the latitude: the meridians
/// draw closer towards the poles.
const metresPerDegree = earthRadiusMetres * math.pi / 180;

/// How far [point] is from the segment [start]–[end], in metres: from the
/// closest point of the segment, which may be one of its ends.
///
/// The three points are laid flat on a plane tangent at [start]
/// (equirectangular projection). Over a street, a few hundred metres, the
/// error is far below a metre, and the sums stay simple.
double metresFromSegment(GeoPoint point, GeoPoint start, GeoPoint end) {
  final scale = math.cos(start.latitude * math.pi / 180) * metresPerDegree;
  // Local function: x and y of a point, in metres east and north of start.
  double x(GeoPoint p) => (p.longitude - start.longitude) * scale;
  double y(GeoPoint p) => (p.latitude - start.latitude) * metresPerDegree;

  final (px, py) = (x(point), y(point));
  final (ex, ey) = (x(end), y(end));
  final lengthSquared = ex * ex + ey * ey;
  // Where the point projects on the segment, as a fraction of it: 0 at
  // start, 1 at end, clamped so a point beyond an end measures to that end.
  final fraction = lengthSquared == 0
      ? 0.0
      : ((px * ex + py * ey) / lengthSquared).clamp(0.0, 1.0);
  final dx = px - fraction * ex;
  final dy = py - fraction * ey;
  return math.sqrt(dx * dx + dy * dy);
}
