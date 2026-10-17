import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';

import '../../support/geo_fixtures.dart';

/// The cosine of [degrees].
double _cos(double degrees) => math.cos(degrees * math.pi / 180);

void main() {
  group('around', () {
    test('should be null when there is no point', () {
      expect(GeoBounds.around([]), isNull);
    });

    test('should be the point itself when there is one', () {
      final bounds = GeoBounds.around([at(45.98915, 4.71862)])!;

      expect(bounds.south, 45.98915);
      expect(bounds.west, 4.71862);
      expect(bounds.north, 45.98915);
      expect(bounds.east, 4.71862);
    });

    test('should take the extreme of each side when there are several', () {
      final bounds = GeoBounds.around([
        at(45.99210, 4.71705),
        at(45.98200, 4.73000),
        at(45.98915, 4.70100),
        at(45.98500, 4.72000),
      ])!;

      expect(bounds.south, 45.98200);
      expect(bounds.west, 4.70100);
      expect(bounds.north, 45.99210);
      expect(bounds.east, 4.73000);
    });
  });

  group('expandedBy', () {
    // East and west, the margin is counted on the widened box: 1° from the
    // equator a degree of longitude is already a little shorter.
    test('should widen each side by the margin at the equator', () {
      final bounds = GeoBounds.around([at(0, 0)])!.expandedBy(metresPerDegree);

      expect(bounds.south, closeTo(-1, 1e-9));
      expect(bounds.west, closeTo(-1 / _cos(1), 1e-9));
      expect(bounds.north, closeTo(1, 1e-9));
      expect(bounds.east, closeTo(1 / _cos(1), 1e-9));
    });

    // Away from the equator a degree of longitude is shorter: more degrees
    // make the margin, counted where the box is widest from the equator so
    // that the margin is never short.
    test('should widen east and west by more degrees in the north', () {
      final bounds = GeoBounds.around([at(59, 10), at(60, 11)])!
          .expandedBy(metresPerDegree / 2);

      expect(bounds.south, closeTo(58.5, 1e-9));
      expect(bounds.north, closeTo(60.5, 1e-9));
      expect(bounds.west, closeTo(10 - 0.5 / _cos(60.5), 1e-9));
      expect(bounds.east, closeTo(11 + 0.5 / _cos(60.5), 1e-9));
    });

    test('should measure the longitude where the box is farthest south when '
        'it is south of the equator', () {
      final bounds = GeoBounds.around([at(-60, 10), at(-59, 11)])!
          .expandedBy(metresPerDegree / 2);

      expect(bounds.west, closeTo(10 - 0.5 / _cos(60.5), 1e-9));
      expect(bounds.east, closeTo(11 + 0.5 / _cos(60.5), 1e-9));
    });

    test('should stop at the poles and the antimeridian', () {
      final bounds = GeoBounds.around([at(-89.9, -179.9), at(89.9, 179.9)])!
          .expandedBy(20000);

      expect(bounds.south, -90);
      expect(bounds.west, -180);
      expect(bounds.north, 90);
      expect(bounds.east, 180);
    });

    test('should stay inside the poles when it reaches one exactly', () {
      final bounds = GeoBounds.around([at(89, 0)])!.expandedBy(metresPerDegree);

      expect(bounds.north, closeTo(90, 1e-9));
    });
  });

  test('should be equal to another bounds with the same sides', () {
    final bounds = GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)]);

    expect(bounds, GeoBounds.around([at(45.99, 4.70), at(45.98, 4.72)]));
    expect(
      bounds.hashCode,
      GeoBounds.around([at(45.99, 4.70), at(45.98, 4.72)]).hashCode,
    );
  });

  final other = <(String, List<double>)>[
    ('south', [45.97, 4.70, 45.99, 4.72]),
    ('west', [45.98, 4.69, 45.99, 4.72]),
    ('north', [45.98, 4.70, 46.00, 4.72]),
    ('east', [45.98, 4.70, 45.99, 4.73]),
  ];
  for (final (side, [south, west, north, east]) in other) {
    test('should differ from bounds with another $side side', () {
      expect(
        GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)]),
        isNot(GeoBounds.around([at(south, west), at(north, east)])),
      );
    });
  }

  test('should print its four sides', () {
    expect(
      GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)]).toString(),
      'GeoBounds(south: 45.98, west: 4.7, north: 45.99, east: 4.72)',
    );
  });
}
