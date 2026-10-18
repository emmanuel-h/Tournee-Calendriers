import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/street_lines.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/vector_tile.dart';

import '../../../support/geo_fixtures.dart';
import '../../../support/street_fixtures.dart';

/// Two zoom-14 tiles of Villefranche-sur-Saône, side by side.
const _west = TileId(zoom: 14, x: 8406, y: 5829);
const _east = TileId(zoom: 14, x: 8407, y: 5829);

GeoPoint _at(TileId tile, int x, int y) =>
    geoPointOf(tile, (x: x, y: y), 4096)!;

TileLayer _layer(List<TileRoad> roads) => TileLayer(extent: 4096, roads: roads);

TileRoad _road(String name, List<List<(int, int)>> lines) => TileRoad(name, [
  for (final line in lines) [for (final (x, y) in line) (x: x, y: y)],
]);

void main() {
  final bothTiles = GeoBounds.around([
    ...tileBounds(_west).corners,
    ...tileBounds(_east).corners,
  ])!;

  test('should keep the lines named like the street, accents or not', () {
    final shape = streetShapeFromTiles(
      [
        (
          _west,
          _layer([
            _road('Rue de la République', [
              [(1000, 1000), (2000, 1000)],
            ]),
            _road('Rue Nationale', [
              [(1000, 2000), (2000, 2000)],
            ]),
          ]),
        ),
      ],
      name: streetName('Rue de la Republique'),
      area: bothTiles,
    );

    expect(
      shape,
      StreetShape([
        [_at(_west, 1000, 1000), _at(_west, 2000, 1000)],
      ]),
    );
  });

  test('should cut a line where it leaves its tile', () {
    final shape = streetShapeFromTiles(
      [
        (
          _west,
          _layer([
            _road('Rue Nationale', [
              [(3000, 1000), (4200, 1000)],
            ]),
          ]),
        ),
      ],
      name: streetName('Rue Nationale'),
      area: bothTiles,
    );

    final line = shape.lines.single;
    expect(line, hasLength(2));
    expect(line.first, _at(_west, 3000, 1000));
    expect(line.last.longitude, tileBounds(_west).east);
    expect(line.last.latitude, closeTo(_at(_west, 3000, 1000).latitude, 1e-9));
  });

  test('should join a road cut at the edge of two tiles', () {
    final shape = streetShapeFromTiles(
      [
        (
          _west,
          _layer([
            _road('Rue Nationale', [
              [(3000, 1000), (4200, 1000)],
            ]),
          ]),
        ),
        (
          _east,
          _layer([
            _road('Rue Nationale', [
              [(-104, 1000), (1000, 1000)],
            ]),
          ]),
        ),
      ],
      name: streetName('Rue Nationale'),
      area: bothTiles,
    );

    final line = shape.lines.single;
    expect(line, hasLength(3));
    expect(line.first, _at(_west, 3000, 1000));
    expect(line[1].longitude, tileBounds(_west).east);
    expect(line.last, _at(_east, 1000, 1000));
  });

  test('should keep only the part of the road inside the area', () {
    final area = GeoBounds.around([
      _at(_west, 500, 500),
      _at(_west, 1500, 1500),
    ])!;

    final shape = streetShapeFromTiles(
      [
        (
          _west,
          _layer([
            _road('Rue Nationale', [
              [(600, 1000), (1400, 1000)],
              [(3000, 3000), (3500, 3000)],
            ]),
          ]),
        ),
      ],
      name: streetName('Rue Nationale'),
      area: area,
    );

    expect(
      shape,
      StreetShape([
        [_at(_west, 600, 1000), _at(_west, 1400, 1000)],
      ]),
    );
  });

  test('should give no shape when no road has the name', () {
    final shape = streetShapeFromTiles(
      [
        (
          _west,
          _layer([
            _road('Rue Nationale', [
              [(600, 1000), (1400, 1000)],
            ]),
          ]),
        ),
      ],
      name: streetName('Rue de la Paix'),
      area: bothTiles,
    );

    expect(shape, StreetShape.none);
  });

  test('should join ends at most a metre apart', () {
    expect(joinToleranceMetres, 1);
  });
}

extension on GeoBounds {
  /// The south-west and north-east corners.
  List<GeoPoint> get corners => [at(south, west), at(north, east)];
}
