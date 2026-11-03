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

  group('of', () {
    test('should be the bounds of the four sides', () {
      final bounds = GeoBounds.of(
        south: 45.98,
        west: 4.70,
        north: 45.99,
        east: 4.72,
      )!;

      expect(bounds.south, 45.98);
      expect(bounds.west, 4.70);
      expect(bounds.north, 45.99);
      expect(bounds.east, 4.72);
    });

    test('should accept the edges of the map and a single point', () {
      expect(
        GeoBounds.of(south: -90, west: -180, north: 90, east: 180),
        isNotNull,
      );
      expect(GeoBounds.of(south: 45, west: 4, north: 45, east: 4), isNotNull);
    });

    final refused = <(String, List<double>)>[
      ('a south below -90', [-90.001, 4.70, 45.99, 4.72]),
      ('a north above 90', [45.98, 4.70, 90.001, 4.72]),
      ('a west below -180', [45.98, -180.001, 45.99, 4.72]),
      ('an east above 180', [45.98, 4.70, 45.99, 180.001]),
      ('a south above the north', [45.991, 4.70, 45.99, 4.72]),
      ('a west east of the east', [45.98, 4.721, 45.99, 4.72]),
      ('a latitude not a number', [double.nan, 4.70, 45.99, 4.72]),
      ('a longitude not a number', [45.98, 4.70, 45.99, double.nan]),
    ];
    for (final (what, [south, west, north, east]) in refused) {
      test('should refuse $what', () {
        expect(
          GeoBounds.of(south: south, west: west, north: north, east: east),
          isNull,
        );
      });
    }
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

  group('contains', () {
    final box = GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)])!;

    test('should contain bounds inside it', () {
      expect(
        box.contains(GeoBounds.around([at(45.985, 4.71), at(45.986, 4.715)])!),
        isTrue,
      );
    });

    test('should contain itself, its sides included', () {
      expect(box.contains(box), isTrue);
    });

    final overflows = <(String, List<double>)>[
      ('south', [45.9799, 4.70, 45.99, 4.72]),
      ('west', [45.98, 4.6999, 45.99, 4.72]),
      ('north', [45.98, 4.70, 45.9901, 4.72]),
      ('east', [45.98, 4.70, 45.99, 4.7201]),
    ];
    for (final (side, [south, west, north, east]) in overflows) {
      test('should not contain bounds reaching past its $side side', () {
        expect(
          box.contains(GeoBounds.around([at(south, west), at(north, east)])!),
          isFalse,
        );
      });
    }
  });

  group('isCloseTo', () {
    final box = GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)])!;

    test('should be close to bounds whose sides are all within the '
        'tolerance', () {
      final near = GeoBounds.around([
        at(45.98 + 4e-8, 4.70 - 4e-8),
        at(45.99 - 4e-8, 4.72 + 4e-8),
      ])!;

      expect(box.isCloseTo(near, 1e-7), isTrue);
    });

    final shifted = <(String, List<double>)>[
      ('south', [45.98 + 2e-7, 4.70, 45.99, 4.72]),
      ('west', [45.98, 4.70 + 2e-7, 45.99, 4.72]),
      ('north', [45.98, 4.70, 45.99 + 2e-7, 4.72]),
      ('east', [45.98, 4.70, 45.99, 4.72 + 2e-7]),
    ];
    for (final (side, [south, west, north, east]) in shifted) {
      test('should not be close when its $side side is beyond the '
          'tolerance', () {
        expect(
          box.isCloseTo(
            GeoBounds.around([at(south, west), at(north, east)])!,
            1e-7,
          ),
          isFalse,
        );
      });
    }
  });

  test('should print its four sides', () {
    expect(
      GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)]).toString(),
      'GeoBounds(south: 45.98, west: 4.7, north: 45.99, east: 4.72)',
    );
  });
}
