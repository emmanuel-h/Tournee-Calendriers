import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';

import '../../support/geo_fixtures.dart';

void main() {
  test('should count about 111.195 km in a degree of latitude', () {
    expect(metresPerDegree, closeTo(111195.08, 0.01));
  });

  group('metresFromSegment', () {
    // A segment running east along the latitude 45.99, about 155 m long.
    final west = at(45.99, 4.716);
    final east = at(45.99, 4.718);

    test('should measure straight north when the point is above the '
        'segment', () {
      expect(
        metresFromSegment(at(45.9901, 4.717), west, east),
        closeTo(0.0001 * metresPerDegree, 1e-6),
      );
    });

    test('should be zero when the point is on the segment', () {
      expect(metresFromSegment(at(45.99, 4.7171), west, east), 0);
    });

    test('should measure to the start when the point is before it', () {
      // 0.001° of longitude west of the start, on its latitude.
      final cosine = math.cos(45.99 * math.pi / 180);

      expect(
        metresFromSegment(at(45.99, 4.715), west, east),
        closeTo(0.001 * cosine * metresPerDegree, 1e-6),
      );
    });

    test('should measure to the end when the point is past it', () {
      final cosine = math.cos(45.99 * math.pi / 180);

      expect(
        metresFromSegment(at(45.99, 4.720), west, east),
        closeTo(0.002 * cosine * metresPerDegree, 1e-6),
      );
    });

    test('should measure to the point when the segment has no length', () {
      expect(
        metresFromSegment(at(45.9902, 4.716), west, west),
        closeTo(0.0002 * metresPerDegree, 1e-6),
      );
    });
  });

  group('nearestOnSegment', () {
    // The same segment running east along the latitude 45.99.
    final west = at(45.99, 4.716);
    final east = at(45.99, 4.718);

    test('should give the foot of the perpendicular when the point is '
        'above the segment', () {
      final foot = nearestOnSegment(at(45.9901, 4.7171), west, east);

      expect(foot.latitude, closeTo(45.99, 1e-12));
      expect(foot.longitude, closeTo(4.7171, 1e-12));
    });

    test('should give the start when the point is before it', () {
      expect(nearestOnSegment(at(45.9901, 4.715), west, east), west);
    });

    test('should give the end when the point is past it', () {
      expect(nearestOnSegment(at(45.9899, 4.720), west, east), east);
    });

    test('should give the start when the segment has no length', () {
      expect(nearestOnSegment(at(45.9902, 4.717), west, west), west);
    });

    test('should be as far from the point as metresFromSegment says', () {
      // A slanted segment, so both coordinates of the foot move.
      final north = at(45.991, 4.717);
      final point = at(45.9902, 4.7168);

      expect(
        metresBetween(point, nearestOnSegment(point, west, north)),
        // Measured on planes tangent at two different points: a tenth of
        // a millimetre apart.
        closeTo(metresFromSegment(point, west, north), 1e-3),
      );
    });
  });

  group('metresBetween', () {
    test('should measure straight north between two points', () {
      expect(
        metresBetween(at(45.99, 4.716), at(45.9901, 4.716)),
        closeTo(0.0001 * metresPerDegree, 1e-6),
      );
    });

    test('should measure along the latitude, shorter than a degree of '
        'latitude', () {
      final cosine = math.cos(45.99 * math.pi / 180);

      expect(
        metresBetween(at(45.99, 4.716), at(45.99, 4.717)),
        closeTo(0.001 * cosine * metresPerDegree, 1e-6),
      );
    });

    test('should be zero between a point and itself', () {
      expect(metresBetween(at(45.99, 4.716), at(45.99, 4.716)), 0);
    });
  });
}
