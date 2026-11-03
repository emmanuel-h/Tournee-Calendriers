import 'dart:math' as math;

import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';

/// A rectangle on the map, between two latitudes and two longitudes (WGS 84
/// degrees): the area to download for offline use, or to show when the map
/// opens on a tournée.
///
/// It never crosses the antimeridian: [west] ≤ [east]. France is far from
/// it.
final class GeoBounds {
  const GeoBounds._({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// The smallest bounds holding every one of [points]; null when there is
  /// none.
  static GeoBounds? around(Iterable<GeoPoint> points) {
    GeoBounds? bounds;
    for (final point in points) {
      bounds = GeoBounds._(
        south: math.min(bounds?.south ?? point.latitude, point.latitude),
        west: math.min(bounds?.west ?? point.longitude, point.longitude),
        north: math.max(bounds?.north ?? point.latitude, point.latitude),
        east: math.max(bounds?.east ?? point.longitude, point.longitude),
      );
    }
    return bounds;
  }

  /// The bounds with these four sides, as a storage or a map library
  /// gives them; null when a side is out of range (latitudes -90 to 90,
  /// longitudes -180 to 180, bounds included), not a number, or the
  /// sides are the wrong way round (south above north, west east of east).
  static GeoBounds? of({
    required double south,
    required double west,
    required double north,
    required double east,
  }) {
    // Written as « not inside » so that NaN, which fails every comparison,
    // is refused too.
    if (!(-90 <= south && south <= north && north <= 90)) return null;
    if (!(-180 <= west && west <= east && east <= 180)) return null;
    return GeoBounds._(south: south, west: west, north: north, east: east);
  }

  /// The latitude of the southern side.
  final double south;

  /// The longitude of the western side.
  final double west;

  /// The latitude of the northern side.
  final double north;

  /// The longitude of the eastern side.
  final double east;

  /// These bounds with [metres] more on each side, stopping at the poles
  /// and at the antimeridian.
  ///
  /// The margin in longitude is counted at the latitude of the side
  /// farthest from the equator, where a degree of longitude is shortest: so
  /// the margin is at least [metres] all along.
  GeoBounds expandedBy(double metres) {
    final latitudeMargin = metres / metresPerDegree;
    final newSouth = math.max(-90.0, south - latitudeMargin);
    final newNorth = math.min(90.0, north + latitudeMargin);
    final widest = math.max(newSouth.abs(), newNorth.abs());
    // At a pole the cosine is 0 and the margin infinite: the clamp below
    // then gives the whole width of the map, which is right.
    final longitudeMargin = latitudeMargin / math.cos(widest * math.pi / 180);
    return GeoBounds._(
      south: newSouth,
      west: math.max(-180.0, west - longitudeMargin),
      north: newNorth,
      east: math.min(180.0, east + longitudeMargin),
    );
  }

  /// Whether [other] lies wholly inside these bounds, on a side included:
  /// the map downloaded for offline use still covers the streets.
  bool contains(GeoBounds other) =>
      other.south >= south &&
      other.west >= west &&
      other.north <= north &&
      other.east <= east;

  /// Whether each side of [other] is less than [degrees] away from the
  /// same side of these bounds: two areas a map library would take for
  /// the same one, its coordinates having been through a conversion.
  bool isCloseTo(GeoBounds other, double degrees) =>
      (other.south - south).abs() < degrees &&
      (other.west - west).abs() < degrees &&
      (other.north - north).abs() < degrees &&
      (other.east - east).abs() < degrees;

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);

  @override
  String toString() =>
      'GeoBounds(south: $south, west: $west, north: $north, east: $east)';
}
