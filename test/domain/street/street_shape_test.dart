import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/encoded_polyline.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/geometry/road_side.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';

void main() {
  // Two ways of one street, as OpenStreetMap cuts it: one running east,
  // one running north from where the first ends.
  final a = at(45.99, 4.7160);
  final b = at(45.99, 4.7170);
  final c = at(45.99, 4.7180);
  final d = at(45.9905, 4.7180);
  final e = at(45.9910, 4.7180);

  group('create', () {
    test('should keep each line and its points in order', () {
      final shape = StreetShape([
        [a, b, c],
        [c, d, e],
      ]);

      expect(shape.lines, [
        [a, b, c],
        [c, d, e],
      ]);
      expect(shape.isEmpty, isFalse);
    });

    test('should drop a line of fewer than two points', () {
      final shape = StreetShape([
        [a],
        [c, e],
        [],
      ]);

      expect(shape.lines, [
        [c, e],
      ]);
    });

    test('should be empty when no line has two points', () {
      expect(
        StreetShape([
          [a],
          [],
        ]).isEmpty,
        isTrue,
      );
    });

    test('should give lists that cannot be modified', () {
      final shape = StreetShape([
        [a, b],
      ]);

      expect(() => shape.lines.add([c, d]), throwsUnsupportedError);
      expect(() => shape.lines.first.add(c), throwsUnsupportedError);
    });
  });

  test('should have no line when none', () {
    expect(StreetShape.none.lines, isEmpty);
    expect(StreetShape.none.isEmpty, isTrue);
  });

  test('should list the points of every line', () {
    final shape = StreetShape([
      [a, b],
      [d, e],
    ]);

    expect(shape.points, [a, b, d, e]);
  });

  group('metresFrom', () {
    // Two roads of Villefranche-sur-Saône running north: the first at
    // 4.7170 E, the second 0.001° east of it.
    final shape = StreetShape([
      [at(45.9900, 4.7170), at(45.9910, 4.7170)],
      [at(45.9900, 4.7180), at(45.9910, 4.7180)],
    ]);

    test('should measure to the nearest line', () {
      // 0.0002° east of the first road, 0.0008° west of the second.
      final point = at(45.9905, 4.7172);

      expect(
        shape.metresFrom(point),
        closeTo(
          metresFromSegment(point, shape.lines[0][0], shape.lines[0][1]),
          1e-9,
        ),
      );
      expect(shape.metresFrom(point), greaterThan(10));
    });

    test('should measure to the second line when it is the nearest', () {
      final point = at(45.9905, 4.7179);

      expect(
        shape.metresFrom(point),
        closeTo(
          metresFromSegment(point, shape.lines[1][0], shape.lines[1][1]),
          1e-9,
        ),
      );
    });

    test('should measure to the nearest segment of a line', () {
      final bent = StreetShape([
        [at(45.9900, 4.7170), at(45.9910, 4.7170), at(45.9910, 4.7190)],
      ]);
      // Just south of the second segment, far from the first.
      final point = at(45.9909, 4.7185);

      expect(bent.metresFrom(point), closeTo(0.0001 * metresPerDegree, 1e-6));
    });

    test('should be on a line for a point of it', () {
      expect(shape.metresFrom(at(45.9905, 4.7170)), closeTo(0, 1e-9));
    });

    test('should have no distance without a line', () {
      expect(StreetShape.none.metresFrom(at(45.9905, 4.7170)), isNull);
    });
  });

  group('nearestPointTo', () {
    // The same two roads running north, 0.001° apart.
    final shape = StreetShape([
      [at(45.9900, 4.7170), at(45.9910, 4.7170)],
      [at(45.9900, 4.7180), at(45.9910, 4.7180)],
    ]);

    test('should give the point of the nearest line facing the point', () {
      final nearest = shape.nearestPointTo(at(45.9905, 4.7172))!;

      expect(nearest.latitude, closeTo(45.9905, 1e-12));
      expect(nearest.longitude, closeTo(4.7170, 1e-12));
    });

    test('should give the point of the second line when it is the '
        'nearest', () {
      final nearest = shape.nearestPointTo(at(45.9903, 4.7179))!;

      expect(nearest.latitude, closeTo(45.9903, 1e-12));
      expect(nearest.longitude, closeTo(4.7180, 1e-12));
    });

    test('should give the point of the nearest segment of a line', () {
      final bent = StreetShape([
        [at(45.9900, 4.7170), at(45.9910, 4.7170), at(45.9910, 4.7190)],
      ]);

      final nearest = bent.nearestPointTo(at(45.9909, 4.7185))!;

      expect(nearest.latitude, closeTo(45.9910, 1e-12));
      expect(nearest.longitude, closeTo(4.7185, 1e-12));
    });

    test('should keep the first line when two are as near', () {
      // Whole degrees, so both distances are computed exactly alike.
      final apart = StreetShape([
        [at(45.9900, 4), at(45.9910, 4)],
        [at(45.9900, 6), at(45.9910, 6)],
      ]);

      final nearest = apart.nearestPointTo(at(45.9905, 5))!;

      expect(nearest.longitude, 4);
    });

    test('should give nothing without a line', () {
      expect(StreetShape.none.nearestPointTo(at(45.9905, 4.7170)), isNull);
    });
  });

  group('sideOf', () {
    // Two roads running north, 0.001° apart: walking north, east is on the
    // right.
    final shape = StreetShape([
      [at(45.9900, 4.7170), at(45.9910, 4.7170)],
      [at(45.9900, 4.7180), at(45.9910, 4.7180)],
    ]);

    test('should say right when the point is east of the nearest line', () {
      expect(shape.sideOf(at(45.9905, 4.7172)), RoadSide.right);
    });

    test('should say left when the point is west of the nearest line', () {
      expect(shape.sideOf(at(45.9905, 4.7168)), RoadSide.left);
    });

    test('should read the side of the nearest line, not the first', () {
      // East of the first line, but west of the second, which is nearer.
      expect(shape.sideOf(at(45.9905, 4.7178)), RoadSide.left);
    });

    test('should read the side of the nearest segment of a line', () {
      // Running north, then east: the point is north of the second
      // segment, on its left.
      final bent = StreetShape([
        [at(45.9900, 4.7170), at(45.9910, 4.7170), at(45.9910, 4.7190)],
      ]);

      expect(bent.sideOf(at(45.9911, 4.7185)), RoadSide.left);
    });

    test('should say nothing for a point on the line', () {
      expect(shape.sideOf(at(45.9905, 4.7170)), isNull);
    });

    test('should say nothing without a line', () {
      expect(StreetShape.none.sideOf(at(45.9905, 4.7170)), isNull);
    });
  });

  group('simplified', () {
    // 1 m off the straight line: under the default 2 m tolerance.
    final wobble = at(45.99001, 4.7170);
    // 3.3 m off: over it.
    final bump = at(45.99003, 4.7170);

    test('should simplify each line with a 2 m tolerance', () {
      final shape = StreetShape([
        [a, wobble, c],
        [c, at(45.9905, 4.71803), e],
        [a, bump, c],
      ]);

      expect(
        shape.simplified(),
        StreetShape([
          [a, c],
          [c, at(45.9905, 4.71803), e],
          [a, bump, c],
        ]),
      );
    });

    test('should simplify with the tolerance given', () {
      final shape = StreetShape([
        [a, bump, c],
      ]);

      expect(
        shape.simplified(toleranceMetres: 4),
        StreetShape([
          [a, c],
        ]),
      );
    });
  });

  group('encoded', () {
    final shape = StreetShape([
      [at(45.98915, 4.71862), at(45.99210, 4.71705), at(45.99211, 4.71705)],
      [at(38.5, -120.2), at(40.7, -120.95), at(43.252, -126.453)],
    ]);
    const texts = ['eguwGkrx[mQxHA?', '_p~iF~ps|U_ulLnnqC_mqNvxq`@'];

    test('should give one text per line', () {
      expect(shape.encode(), texts);
    });

    test('should read the lines back from their texts', () {
      expect(valueOf(StreetShape.decode(texts)), shape);
    });

    test('should read no text as no shape', () {
      expect(valueOf(StreetShape.decode([])), StreetShape.none);
    });

    test('should refuse a text that is not an encoded polyline', () {
      expect(
        failureOf(StreetShape.decode([texts.first, '?'])),
        EncodedPolylineFailure.malformed,
      );
    });

    test('should refuse a point beyond the pole', () {
      expect(
        failureOf(StreetShape.decode(['acidP?'])),
        EncodedPolylineFailure.outOfRange,
      );
    });
  });

  group('equality', () {
    StreetShape twoLines() => StreetShape([
      [a, b],
      [d, e],
    ]);

    test('should be equal to a shape with the same lines', () {
      expect(twoLines(), twoLines());
      expect(twoLines().hashCode, twoLines().hashCode);
    });

    test('should differ from a shape with a point elsewhere', () {
      expect(
        twoLines(),
        isNot(
          StreetShape([
            [a, b],
            [d, c],
          ]),
        ),
      );
    });

    test('should differ from a shape with fewer lines', () {
      expect(
        twoLines(),
        isNot(
          StreetShape([
            [a, b],
          ]),
        ),
      );
    });

    test('should differ from a shape with the lines in another order', () {
      expect(
        twoLines(),
        isNot(
          StreetShape([
            [d, e],
            [a, b],
          ]),
        ),
      );
    });

    test('should differ from something else than a shape', () {
      expect(StreetShape.none, isNot(<Object>[]));
    });
  });

  test('should print its lines', () {
    expect(
      StreetShape([
        [a, b],
      ]).toString(),
      'StreetShape([[GeoPoint(45.99, 4.716), GeoPoint(45.99, 4.717)]])',
    );
  });
}
