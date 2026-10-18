// The shape of a street from the roads of the map's tiles: the lines named
// like the street, cut to each tile (each repeats a strip of its
// neighbours) and to the area around the street's houses, then joined
// again across the tiles. Pure function, tested alone.
import 'package:tournee_calendriers/domain/geometry/clip_line.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/join_lines.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/vector_tile.dart';

/// How close two ends of road must be to be joined, in metres: a road cut
/// at a tile's edge ends at the same place in both tiles, give or take the
/// rounding of tile coordinates (about 0.4 m at zoom 14).
const joinToleranceMetres = 1.0;

/// The roads of [tiles] named [name] (see [StreetName.matches]) inside
/// [area], joined where they meet; [StreetShape.none] when there is none.
StreetShape streetShapeFromTiles(
  Iterable<(TileId, TileLayer)> tiles, {
  required StreetName name,
  required GeoBounds area,
}) {
  final pieces = <List<GeoPoint>>[];
  for (final (tile, layer) in tiles) {
    final inTile = tileBounds(tile);
    for (final road in layer.roads) {
      if (!name.matches(road.name)) continue;
      for (final line in road.lines) {
        final points = [
          for (final point in line) ?geoPointOf(tile, point, layer.extent),
        ];
        for (final piece in clipLine(points, inTile)) {
          pieces.addAll(clipLine(piece, area));
        }
      }
    }
  }
  return StreetShape(joinLines(pieces, toleranceMetres: joinToleranceMetres));
}
