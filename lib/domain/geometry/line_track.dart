import 'dart:math' as math;

import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/geometry/join_lines.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// A road as one line to measure along, in metres from its start: where a
/// house brought onto the road sits along it, and the point a given
/// distance along (« Partie de la rue », PLAN §5.15, where two marks slide
/// along the road).
final class LineTrack {
  LineTrack._(this.points, this._distances);

  /// The track along [lines], the pieces of a road: pieces whose ends meet
  /// are joined first (`joinLines`); those that still do not meet are put
  /// end to end, each turned so it starts at its end nearer to where the
  /// previous one ended, the gap between them crossed in a straight line.
  /// Null when there is no line.
  static LineTrack? through(Iterable<List<GeoPoint>> lines) {
    final pieces = joinLines(lines, toleranceMetres: _joinToleranceMetres);
    if (pieces.isEmpty) return null;
    final points = [...pieces.first];
    for (final piece in pieces.skip(1)) {
      final end = points.last;
      final turned =
          metresBetween(end, piece.last) < metresBetween(end, piece.first);
      points.addAll(turned ? piece.reversed : piece);
    }
    return LineTrack._of(points);
  }

  /// The straight track from [start] to [end]: a road whose line is not
  /// known, drawn between the two houses farthest apart.
  factory LineTrack.straight(GeoPoint start, GeoPoint end) =>
      LineTrack._of([start, end]);

  factory LineTrack._of(List<GeoPoint> points) {
    final distances = <double>[0];
    for (var i = 1; i < points.length; i++) {
      distances.add(distances.last + metresBetween(points[i - 1], points[i]));
    }
    return LineTrack._(List.unmodifiable(points), distances);
  }

  /// Two pieces of road from the map tiles whose ends are this close are
  /// one road.
  static const _joinToleranceMetres = 5.0;

  /// The points of the track, from its start; it cannot be modified.
  final List<GeoPoint> points;

  /// How far along the track each of [points] is.
  final List<double> _distances;

  /// The length of the track, in metres.
  double get length => _distances.last;

  /// How far along the track [point] is, once brought onto it (its nearest
  /// point of the track): 0 at the start, [length] at the end.
  double alongOf(GeoPoint point) {
    var nearest = double.infinity;
    var along = 0.0;
    for (var i = 1; i < points.length; i++) {
      final metres = metresFromSegment(point, points[i - 1], points[i]);
      if (metres < nearest) {
        nearest = metres;
        final onRoad = nearestOnSegment(point, points[i - 1], points[i]);
        along = _distances[i - 1] + metresBetween(points[i - 1], onRoad);
      }
    }
    return along;
  }

  /// Whether [point] is on the left of the track, looking along it from its
  /// start, against its nearest piece: which side of a road a house stands
  /// (« Partie de la rue » draws another secteur's stretch on the side it
  /// holds, PLAN §5.15). A point on the track is not on its left.
  bool hasOnLeft(GeoPoint point) {
    var nearest = double.infinity;
    var piece = 1;
    for (var i = 1; i < points.length; i++) {
      final metres = metresFromSegment(point, points[i - 1], points[i]);
      if (metres < nearest) {
        nearest = metres;
        piece = i;
      }
    }
    final start = points[piece - 1];
    final end = points[piece];
    // Degrees of longitude shrink towards the poles: scaled by the cosine
    // of the latitude, both axes measure about the same on the ground.
    final scale = math.cos(start.latitude * math.pi / 180);
    final roadEast = (end.longitude - start.longitude) * scale;
    final roadNorth = end.latitude - start.latitude;
    final pointEast = (point.longitude - start.longitude) * scale;
    final pointNorth = point.latitude - start.latitude;
    // The cross product of the road's direction and the point's: positive
    // when the point is turned anticlockwise from the road, on its left.
    return roadEast * pointNorth - roadNorth * pointEast > 0;
  }

  /// The point [along] metres from the start, kept within the track: the
  /// start before it, the end beyond it.
  GeoPoint pointAt(double along) {
    if (along <= 0) return points.first;
    for (var i = 1; i < points.length; i++) {
      if (along <= _distances[i]) {
        // Not 0: `along` is past the previous point, or it would have been
        // found on the segment before.
        final span = _distances[i] - _distances[i - 1];
        return _between(
          points[i - 1],
          points[i],
          (along - _distances[i - 1]) / span,
        );
      }
    }
    return points.last;
  }

  /// The stretch of the track from [from] to [to] metres along it, its
  /// corners included: what « Partie de la rue » draws as the road kept.
  List<GeoPoint> between(double from, double to) => [
    pointAt(from),
    for (var i = 0; i < points.length; i++)
      if (from < _distances[i] && _distances[i] < to) points[i],
    pointAt(to),
  ];

  /// The point [fraction] of the way from [start] to [end], in degrees as
  /// `nearestOnSegment` does: a point between two points of the Earth is on
  /// the Earth, so it cannot fail.
  static GeoPoint _between(GeoPoint start, GeoPoint end, double fraction) =>
      (GeoPoint.create(
        latitude: start.latitude + fraction * (end.latitude - start.latitude),
        longitude:
            start.longitude + fraction * (end.longitude - start.longitude),
      ) as Ok<GeoPoint, GeoPointFailure>).value;
}
