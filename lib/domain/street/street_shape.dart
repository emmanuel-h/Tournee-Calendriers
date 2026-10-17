import 'package:tournee_calendriers/domain/geometry/encoded_polyline.dart';
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
  /// the area of its tournée.
  Iterable<GeoPoint> get points => lines.expand((line) => line);

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
