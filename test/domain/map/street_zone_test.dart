import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/street_zone.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';

void main() {
  /// A zone of Villefranche-sur-Saône, 45.98–45.99 N, 4.71–4.73 E.
  final zone = GeoBounds.of(
    south: 45.98,
    west: 4.71,
    north: 45.99,
    east: 4.73,
  )!;

  test('should limit a zone to 50 streets', () {
    expect(zoneMaxStreets, 50);
  });

  group('markInZone', () {
    test('should put the mark half-way along a road of two points', () {
      final road = StreetShape([
        [at(45.982, 4.712), at(45.986, 4.720)],
      ]);

      final mark = markInZone(road, zone)!;

      expect(mark.latitude, closeTo(45.984, 1e-9));
      expect(mark.longitude, closeTo(4.716, 1e-9));
    });

    test('should put the mark on the part of the road inside the zone', () {
      // From 4.70 (outside, west) to 4.72: inside from 4.71.
      final road = StreetShape([
        [at(45.985, 4.70), at(45.985, 4.72)],
      ]);

      final mark = markInZone(road, zone)!;

      expect(mark.latitude, closeTo(45.985, 1e-9));
      expect(mark.longitude, closeTo(4.715, 1e-9));
    });

    test('should take the first segment of a piece of three points', () {
      final road = StreetShape([
        [at(45.981, 4.711), at(45.983, 4.713), at(45.989, 4.729)],
      ]);

      final mark = markInZone(road, zone)!;

      expect(mark.latitude, closeTo(45.982, 1e-9));
      expect(mark.longitude, closeTo(4.712, 1e-9));
    });

    test('should take the middle segment of a piece of four points', () {
      final road = StreetShape([
        [
          at(45.981, 4.711),
          at(45.983, 4.713),
          at(45.985, 4.717),
          at(45.989, 4.729),
        ],
      ]);

      final mark = markInZone(road, zone)!;

      expect(mark.latitude, closeTo(45.984, 1e-9));
      expect(mark.longitude, closeTo(4.715, 1e-9));
    });

    test('should skip a line outside the zone for the next one', () {
      final road = StreetShape([
        [at(45.995, 4.712), at(45.996, 4.716)],
        [at(45.982, 4.712), at(45.986, 4.720)],
      ]);

      final mark = markInZone(road, zone)!;

      expect(mark.latitude, closeTo(45.984, 1e-9));
      expect(mark.longitude, closeTo(4.716, 1e-9));
    });

    test('should give no mark when the road stays outside the zone', () {
      final road = StreetShape([
        [at(45.995, 4.712), at(45.996, 4.716)],
      ]);

      expect(markInZone(road, zone), isNull);
      expect(markInZone(StreetShape.none, zone), isNull);
    });
  });
}
