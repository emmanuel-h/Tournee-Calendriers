import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/tile_grid.dart';

import '../../../support/geo_fixtures.dart';

/// The zoom-14 tile of the town hall of Villefranche-sur-Saône.
const _townHall = TileId(zoom: 14, x: 8406, y: 5829);

void main() {
  group('TileId', () {
    test('should be equal when every field is equal', () {
      const same = TileId(zoom: 14, x: 8406, y: 5829);

      expect(_townHall, same);
      expect(_townHall.hashCode, same.hashCode);
    });

    test('should differ when one field differs', () {
      expect(_townHall, isNot(const TileId(zoom: 13, x: 8406, y: 5829)));
      expect(_townHall, isNot(const TileId(zoom: 14, x: 8407, y: 5829)));
      expect(_townHall, isNot(const TileId(zoom: 14, x: 8406, y: 5830)));
    });

    test('should show its zoom, column and row when printed', () {
      expect(_townHall.toString(), 'TileId(14/8406/5829)');
    });
  });

  group('tilesCovering', () {
    test('should give the one tile of a small area', () {
      final area = GeoBounds.around([at(45.98915, 4.71862)])!;

      expect(tilesCovering(area, zoom: 14), [_townHall]);
    });

    test('should give every tile touched, row after row from the north', () {
      final area = GeoBounds.around([
        at(45.98000, 4.71000),
        at(45.99000, 4.73000),
      ])!;

      expect(tilesCovering(area, zoom: 14), const [
        TileId(zoom: 14, x: 8406, y: 5829),
        TileId(zoom: 14, x: 8407, y: 5829),
        TileId(zoom: 14, x: 8406, y: 5830),
        TileId(zoom: 14, x: 8407, y: 5830),
      ]);
    });

    test('should keep to the grid at its edges', () {
      // At zoom 1, two by two tiles; beyond 85° the map stops.
      expect(tilesCovering(GeoBounds.around([at(89, 180)])!, zoom: 1), const [
        TileId(zoom: 1, x: 1, y: 0),
      ]);
      expect(tilesCovering(GeoBounds.around([at(-89, -180)])!, zoom: 1), const [
        TileId(zoom: 1, x: 0, y: 1),
      ]);
    });
  });

  test('should give the area of a tile', () {
    final bounds = tileBounds(_townHall);

    expect(bounds.west, 4.7021484375);
    expect(bounds.east, 4.72412109375);
    expect(bounds.north, closeTo(45.99696161820381, 1e-12));
    expect(bounds.south, closeTo(45.98169518512228, 1e-12));
  });

  group('geoPointOf', () {
    test('should put the corners of the tile at its corners', () {
      final bounds = tileBounds(_townHall);

      final northWest = geoPointOf(_townHall, (x: 0, y: 0), 4096)!;
      final southEast = geoPointOf(_townHall, (x: 4096, y: 4096), 4096)!;

      expect(northWest.latitude, closeTo(bounds.north, 1e-12));
      expect(northWest.longitude, closeTo(bounds.west, 1e-12));
      expect(southEast.latitude, closeTo(bounds.south, 1e-12));
      expect(southEast.longitude, closeTo(bounds.east, 1e-12));
    });

    test('should put the middle of the tile at its middle, in Mercator', () {
      final middle = geoPointOf(_townHall, (x: 256, y: 256), 512)!;

      expect(middle.latitude, closeTo(45.98932892799954, 1e-12));
      expect(middle.longitude, closeTo(4.713134765625, 1e-12));
    });

    test('should leave out a point of the buffer beyond the '
        'antimeridian', () {
      expect(
        geoPointOf(const TileId(zoom: 14, x: 0, y: 5829), (x: -10, y: 0), 4096),
        isNull,
      );
    });
  });
}
