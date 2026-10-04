import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';

import '../../support/results.dart';

void main() {
  group('create', () {
    test('should keep the latitude and the longitude when both are valid', () {
      final point = valueOf(
        GeoPoint.create(latitude: 45.987173, longitude: 4.716138),
      );

      expect(point.latitude, 45.987173);
      expect(point.longitude, 4.716138);
    });

    // The edges are valid places (the poles, the antimeridian); one step
    // beyond is not.
    const validPairs = <(double, double)>[
      (90, 0),
      (-90, 0),
      (0, 180),
      (0, -180),
    ];
    for (final (latitude, longitude) in validPairs) {
      test('should accept ($latitude, $longitude) when on the edge', () {
        final point = valueOf(
          GeoPoint.create(latitude: latitude, longitude: longitude),
        );

        expect(point.latitude, latitude);
        expect(point.longitude, longitude);
      });
    }

    const badLatitudes = [90.000001, -90.000001, double.nan, double.infinity];
    for (final latitude in badLatitudes) {
      test('should refuse the latitude $latitude', () {
        expect(
          failureOf(GeoPoint.create(latitude: latitude, longitude: 4.7)),
          GeoPointFailure.latitudeOutOfRange,
        );
      });
    }

    const badLongitudes = [
      180.000001,
      -180.000001,
      double.nan,
      double.negativeInfinity,
    ];
    for (final longitude in badLongitudes) {
      test('should refuse the longitude $longitude', () {
        expect(
          failureOf(GeoPoint.create(latitude: 45.9, longitude: longitude)),
          GeoPointFailure.longitudeOutOfRange,
        );
      });
    }
  });

  group('equality', () {
    GeoPoint point(double latitude, double longitude) =>
        valueOf(GeoPoint.create(latitude: latitude, longitude: longitude));

    test('should be equal when both coordinates are equal', () {
      expect(point(45.98, 4.71), point(45.98, 4.71));
      expect(point(45.98, 4.71).hashCode, point(45.98, 4.71).hashCode);
    });

    test('should differ when the latitudes differ', () {
      expect(point(45.98, 4.71), isNot(point(45.99, 4.71)));
    });

    test('should differ when the longitudes differ', () {
      expect(point(45.98, 4.71), isNot(point(45.98, 4.72)));
    });

    test('should differ from a value of another type', () {
      expect(point(45.98, 4.71), isNot('45.98,4.71'));
    });
  });

  test('should show latitude then longitude when printed', () {
    final point = valueOf(GeoPoint.create(latitude: 45.98, longitude: 4.71));

    expect(point.toString(), 'GeoPoint(45.98, 4.71)');
  });
}
