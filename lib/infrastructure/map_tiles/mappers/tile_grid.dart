// The grid of map tiles (the « slippy map » scheme of OpenStreetMap, Web
// Mercator): at zoom z the world is 2^z × 2^z square tiles, x from the
// antimeridian eastwards, y from the north (about 85° N) southwards. Pure
// functions, tested alone.
import 'dart:math' as math;

import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/vector_tile.dart';

/// Web Mercator stops here, north and south: the world is square.
const _maxLatitude = 85.0511287798066;

/// One tile of the grid.
final class TileId {
  const TileId({required this.zoom, required this.x, required this.y});

  final int zoom;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileId && other.zoom == zoom && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(zoom, x, y);

  @override
  String toString() => 'TileId($zoom/$x/$y)';
}

/// Every tile of [zoom] that [area] touches, row after row from the north.
List<TileId> tilesCovering(GeoBounds area, {required int zoom}) {
  final westX = _tileX(area.west, zoom);
  final eastX = _tileX(area.east, zoom);
  final northY = _tileY(area.north, zoom);
  final southY = _tileY(area.south, zoom);
  return [
    for (var y = northY; y <= southY; y++)
      for (var x = westX; x <= eastX; x++) TileId(zoom: zoom, x: x, y: y),
  ];
}

/// The area the tile [tile] covers, without its buffer.
GeoBounds tileBounds(TileId tile) {
  final size = 1 << tile.zoom;
  // A tile's corners are on Earth: the casts cannot fail.
  GeoPoint corner(int x, int y) => (GeoPoint.create(
    latitude: _latitudeAt(y / size),
    longitude: _longitudeAt(x / size),
  ) as Ok<GeoPoint, GeoPointFailure>).value;
  return GeoBounds.around([
    corner(tile.x, tile.y),
    corner(tile.x + 1, tile.y + 1),
  ])!;
}

/// Where the [point] of [tile], in coordinates of 0 to [extent] across it,
/// is on Earth; null for a point of the buffer beyond the antimeridian.
GeoPoint? geoPointOf(TileId tile, TilePoint point, int extent) {
  final size = 1 << tile.zoom;
  return switch (GeoPoint.create(
    latitude: _latitudeAt((tile.y + point.y / extent) / size),
    longitude: _longitudeAt((tile.x + point.x / extent) / size),
  )) {
    Ok(:final value) => value,
    Err() => null,
  };
}

/// The column of the tile holding [longitude].
int _tileX(double longitude, int zoom) {
  final size = 1 << zoom;
  return ((longitude + 180) / 360 * size).floor().clamp(0, size - 1);
}

/// The row of the tile holding [latitude].
int _tileY(double latitude, int zoom) {
  final size = 1 << zoom;
  final radians = latitude.clamp(-_maxLatitude, _maxLatitude) * math.pi / 180;
  // The Mercator projection: ln(tan φ + sec φ), from π at the top to -π
  // at the bottom.
  final mercator = math.log(math.tan(radians) + 1 / math.cos(radians));
  return ((1 - mercator / math.pi) / 2 * size).floor().clamp(0, size - 1);
}

/// The longitude at [fraction] of the world's width from the antimeridian.
double _longitudeAt(double fraction) => fraction * 360 - 180;

/// The latitude at [fraction] of the world's height from its top.
double _latitudeAt(double fraction) {
  final mercator = math.pi * (1 - 2 * fraction);
  // atan(sinh(m)); `dart:math` has no sinh: (eᵐ − e⁻ᵐ) / 2.
  final sinh = (math.exp(mercator) - math.exp(-mercator)) / 2;
  return math.atan(sinh) * 180 / math.pi;
}
