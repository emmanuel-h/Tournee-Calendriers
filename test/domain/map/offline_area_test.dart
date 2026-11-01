// The map kept on the phone for a day offline (PLAN §7): which zooms, which
// bounds for a new region, and whether it still covers the streets.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/offline_area.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _area = GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)])!;

/// A street with one house at [house] (latitude, longitude), and a line
/// through the points of [line] when given.
Street _street({_Point? house, List<_Point> line = const []}) => valueOf(
  Street.create(
    id: StreetId('s'),
    name: 'Rue Nationale',
    commune: villefranche,
    shape: line.isEmpty
        ? StreetShape.none
        : StreetShape([
            [for (final (lat, lon) in line) at(lat, lon)],
          ]),
    houses: [
      House(
        number: n('1'),
        position: house == null ? null : at(house.$1, house.$2),
      ),
    ],
  ),
);

/// (latitude, longitude).
typedef _Point = (double, double);

void main() {
  test('should keep zooms 12 to 17', () {
    expect(offlineMapMinZoom, 12);
    expect(offlineMapMaxZoom, 17);
  });

  test('should move a new region 1 m out when its area is taken', () {
    expect(offlineRegionShiftMetres, 1);
  });

  group('offlineRegionBounds', () {
    test('should be the area itself when no region holds it', () {
      final elsewhere = GeoBounds.around([at(45.90, 4.60), at(45.91, 4.61)])!;

      expect(offlineRegionBounds(_area, [elsewhere]), _area);
    });

    test('should be the area itself when there is no region', () {
      expect(offlineRegionBounds(_area, []), _area);
    });

    test('should be the area widened by 1 m when a region holds it', () {
      expect(offlineRegionBounds(_area, [_area]), _area.expandedBy(1));
    });

    // The map library takes two regions for one when their sides are
    // within 1e-9° (and deletes the old one first): a conversion may move
    // a side by that much.
    test('should take a region for the area when its sides are within '
        '1e-7°', () {
      final converted = GeoBounds.around([
        at(45.98 + 5e-8, 4.70),
        at(45.99, 4.72 - 5e-8),
      ])!;

      expect(offlineRegionBounds(_area, [converted]), _area.expandedBy(1));
    });

    test('should widen by 1 m more while the widened area is taken too', () {
      expect(
        offlineRegionBounds(_area, [_area, _area.expandedBy(1)]),
        _area.expandedBy(2),
      );
    });

    // So a region refreshed again and again never grows: the area, then
    // 1 m wider, then the area again.
    test('should be the area again when only the widened one is taken', () {
      expect(offlineRegionBounds(_area, [_area.expandedBy(1)]), _area);
    });
  });

  group('coversStreets', () {
    test('should cover streets inside the area', () {
      expect(
        coversStreets(_area, [
          _street(house: (45.985, 4.71)),
          _street(line: [(45.981, 4.701), (45.989, 4.719)]),
        ]),
        isTrue,
      );
    });

    test('should cover a house on the side of the area', () {
      expect(coversStreets(_area, [_street(house: (45.99, 4.72))]), isTrue);
    });

    test('should not cover a house beyond the area', () {
      expect(
        coversStreets(_area, [
          _street(house: (45.985, 4.71)),
          _street(house: (45.9901, 4.71)),
        ]),
        isFalse,
      );
    });

    test('should not cover a line leaving the area', () {
      expect(
        coversStreets(_area, [
          _street(line: [(45.985, 4.71), (45.985, 4.7201)]),
        ]),
        isFalse,
      );
    });

    test('should cover streets with no place on the map, area or not', () {
      expect(coversStreets(_area, [_street()]), isTrue);
      expect(coversStreets(null, [_street()]), isTrue);
    });

    test('should not cover streets on the map when no map was kept', () {
      expect(coversStreets(null, [_street(house: (45.985, 4.71))]), isFalse);
    });
  });
}
