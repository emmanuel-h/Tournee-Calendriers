import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/encoded_polyline.dart';
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
