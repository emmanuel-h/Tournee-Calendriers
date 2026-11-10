// The shape of a street from the roads of the map's tiles: the lines named
// like the street, cut to each tile (each repeats a strip of its
// neighbours) and to the area around the street's houses, then joined
// again across the tiles; and the named roads of an area drawn on the map
// (« Zone »). Pure functions, tested alone.
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
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

/// The roads of [tiles] that run through [area], one per name in the
/// order the tiles give them first, each joined across the tiles but not
/// cut to [area] (« Zone », PLAN §5.14). A blank name is no street.
List<NamedRoad> namedRoadsFromTiles(
  Iterable<(TileId, TileLayer)> tiles, {
  required GeoBounds area,
}) {
  // A Dart map keeps the order its keys were added in.
  final piecesByName = <String, List<List<GeoPoint>>>{};
  final inArea = <String>{};
  for (final (tile, layer) in tiles) {
    final inTile = tileBounds(tile);
    for (final road in layer.roads) {
      final name = road.name.trim();
      if (name.isEmpty) continue;
      final pieces = piecesByName.putIfAbsent(name, () => []);
      for (final line in road.lines) {
        final points = [
          for (final point in line) ?geoPointOf(tile, point, layer.extent),
        ];
        for (final piece in clipLine(points, inTile)) {
          pieces.add(piece);
          if (clipLine(piece, area).isNotEmpty) inArea.add(name);
        }
      }
    }
  }
  return [
    for (final MapEntry(key: name, value: pieces) in piecesByName.entries)
      if (inArea.contains(name))
        NamedRoad(
          name: name,
          shape: StreetShape(
            joinLines(pieces, toleranceMetres: joinToleranceMetres),
          ),
        ),
  ];
}
