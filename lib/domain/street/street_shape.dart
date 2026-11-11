import 'dart:math' as math;

import 'package:tournee_calendriers/domain/geometry/encoded_polyline.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/geometry/line_track.dart';
import 'package:tournee_calendriers/domain/geometry/simplify_line.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';

/// Where a street runs on the map: one or more [lines], one per piece of
/// road OpenStreetMap gives (a street is often cut in several « ways »).
///
/// A street typed in by hand, or one OpenStreetMap does not know, has no
/// shape ([none]): its houses still show as dots where the BAN puts them
/// (PLAN §5.3, §9).
final class StreetShape {
  const StreetShape._(this.lines);

  /// The shape drawn by [lines], each a list of points in the order the
  /// road runs. A line of fewer than two points draws nothing and is left
  /// out.
  factory StreetShape(Iterable<Iterable<GeoPoint>> lines) => StreetShape._(
    List.unmodifiable([
      for (final line in lines)
        if (line.length >= 2) List<GeoPoint>.unmodifiable(line),
    ]),
  );

  /// No line at all.
  static const none = StreetShape._([]);

  /// Under this, a point of a road from OpenStreetMap is dropped by
  /// [simplified]: 2 m, about a road's half-width and two pixels at the
  /// closest zoom of the offline map.
  static const defaultToleranceMetres = 2.0;

  /// Reads back the [encoded] lines written by [encode], or fails with an
  /// [EncodedPolylineFailure] when one of them is not an encoded polyline.
  static Result<StreetShape, EncodedPolylineFailure> decode(
    Iterable<String> encoded,
  ) {
    final lines = <List<GeoPoint>>[];
    for (final text in encoded) {
      switch (decodePolyline(text)) {
        case Ok(:final value):
          lines.add(value);
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(StreetShape(lines));
  }

  /// The lines, each of two points or more. Neither the list nor the lines
  /// can be modified.
  final List<List<GeoPoint>> lines;

  /// Whether there is nothing to draw.
  bool get isEmpty => lines.isEmpty;

  /// Every point of every line, line after line: what the street adds to
  /// the area of its secteur.
  Iterable<GeoPoint> get points => lines.expand((line) => line);

  /// How far [point] is from the nearest point of any line, in metres
  /// (see `metresFromSegment`); null when there is no line. Tells which
  /// road a finger tapped (PLAN §5.14).
  double? metresFrom(GeoPoint point) {
    double? nearest;
    for (final line in lines) {
      for (var i = 1; i < line.length; i++) {
        final metres = metresFromSegment(point, line[i - 1], line[i]);
        if (nearest == null || metres < nearest) nearest = metres;
      }
    }
    return nearest;
  }

  /// The point of its lines nearest to [point] (see `nearestOnSegment`);
  /// null when there is no line. Where the ✓ of a road tapped sits on it
  /// (PLAN §5.14).
  GeoPoint? nearestPointTo(GeoPoint point) {
    GeoPoint? nearest;
    var shortest = double.infinity;
    for (final line in lines) {
      for (var i = 1; i < line.length; i++) {
        final metres = metresFromSegment(point, line[i - 1], line[i]);
        if (metres < shortest) {
          shortest = metres;
          nearest = nearestOnSegment(point, line[i - 1], line[i]);
        }
      }
    }
    return nearest;
  }

  /// The stretch of its lines over [points]: from the one nearest the
  /// start of the road to the one farthest along it, each brought onto
  /// the road, and [beyondMetres] further at each end (kept within the
  /// road). What the map draws of a street held in part (PLAN §5.15).
  ///
  /// The lines are measured as one road (`LineTrack.through`); where two
  /// pieces do not meet, the straight gap the track crosses between them
  /// is not drawn, so the stretch may be several lines. No line when there
  /// is no point, or no line to cut.
  StreetShape stretchOver(
    Iterable<GeoPoint> points, {
    required double beyondMetres,
  }) {
    final track = LineTrack.through(lines);
    if (track == null || points.isEmpty) return none;
    final alongs = points.map(track.alongOf);
    // Clamped: `between` past an end would repeat the end point.
    final stretch = track.between(
      math.max(alongs.reduce(math.min) - beyondMetres, 0),
      math.min(alongs.reduce(math.max) + beyondMetres, track.length),
    );
    // Cut the stretch at each gap: a segment whose middle is off every
    // line is the track crossing between two pieces, not a road.
    final drawn = <List<GeoPoint>>[
      [stretch.first],
    ];
    for (var i = 1; i < stretch.length; i++) {
      if (_isOnLines(_middleOf(stretch[i - 1], stretch[i]))) {
        drawn.last.add(stretch[i]);
      } else {
        drawn.add([stretch[i]]);
      }
    }
    return StreetShape(drawn);
  }

  /// Closer than this to a line, a point is on it: the middle of a
  /// segment of a line is on it, up to the rounding of the sums.
  static const _onLineMetres = 0.5;

  bool _isOnLines(GeoPoint point) => metresFrom(point)! < _onLineMetres;

  /// The point halfway between [start] and [end], in degrees as
  /// `nearestOnSegment` does: it is between two points of the Earth, so it
  /// cannot fail.
  static GeoPoint _middleOf(GeoPoint start, GeoPoint end) => (GeoPoint.create(
    latitude: (start.latitude + end.latitude) / 2,
    longitude: (start.longitude + end.longitude) / 2,
  ) as Ok<GeoPoint, GeoPointFailure>).value;

  /// This shape with each line simplified (see `simplifyLine`): the points
  /// closer than [toleranceMetres] to the simplified line are dropped.
  StreetShape simplified({double toleranceMetres = defaultToleranceMetres}) =>
      StreetShape([
        for (final line in lines)
          simplifyLine(line, toleranceMetres: toleranceMetres),
      ]);

  /// Each line as an encoded polyline (see `encodePolyline`): the shape as
  /// the street document stores it (PLAN §6.2).
  List<String> encode() => [for (final line in lines) encodePolyline(line)];

  @override
  bool operator ==(Object other) {
    if (other is! StreetShape || other.lines.length != lines.length) {
      return false;
    }
    for (var i = 0; i < lines.length; i++) {
      if (!sameItems(lines[i], other.lines[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(lines.map(Object.hashAll));

  @override
  String toString() => 'StreetShape($lines)';
}
