import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/encoded_polyline.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';

void main() {
  // Each row: what it shows, the points, their encoding.
  final table = <(String, List<GeoPoint>, String)>[
    ('no point', [], ''),
    ('the origin', [at(0, 0)], '??'),
    // The example of the format's documentation (Google).
    (
      'the reference example',
      [at(38.5, -120.2), at(40.7, -120.95), at(43.252, -126.453)],
      '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
    ),
    (
      'a street of Villefranche-sur-Saône',
      [at(45.98915, 4.71862), at(45.99210, 4.71705), at(45.99211, 4.71705)],
      'eguwGkrx[mQxHA?',
    ),
    // The largest jump there is: 360° of longitude, six 5-bit chunks.
    ('the antimeridian crossed', [at(0, -180), at(0, 180)], '?~fsia@?_ogtcA'),
    ('the poles', [at(90, 0), at(-90, 0)], '_cidP?~fsia@?'),
  ];

  for (final (what, points, encoded) in table) {
    test('should encode $what', () {
      expect(encodePolyline(points), encoded);
    });

    test('should decode $what', () {
      expect(valueOf(decodePolyline(encoded)), points);
    });
  }

  test('should round to the nearest 0.00001° when encoding', () {
    final encoded = encodePolyline([at(45.989154, 4.718626)]);

    expect(valueOf(decodePolyline(encoded)), [at(45.98915, 4.71863)]);
  });

  test('should give a list that cannot be modified when decoding', () {
    final points = valueOf(decodePolyline('??'));

    expect(() => points.add(at(1, 1)), throwsUnsupportedError);
  });

  group('should refuse as malformed', () {
    final malformed = <(String, String)>[
      ('a latitude without longitude', '?'),
      ('a value cut in the middle', '?_'),
      ('a character below the alphabet', '?>'),
      ('a character above the alphabet', '?\u007f'),
      // `_` is an empty chunk followed by another: a seventh chunk, when no
      // coordinate needs more than six.
      ('a value of seven chunks', '______??'),
    ];
    for (final (what, encoded) in malformed) {
      test(what, () {
        expect(
          failureOf(decodePolyline(encoded)),
          EncodedPolylineFailure.malformed,
        );
      });
    }
  });

  test('should accept a value of six chunks', () {
    // `_____?` is 0 written on six chunks: odd but well formed.
    expect(valueOf(decodePolyline('_____??')), [at(0, 0)]);
  });

  test('should refuse a latitude beyond the pole', () {
    // 90.00001° north, then 0.
    expect(
      failureOf(decodePolyline('acidP?')),
      EncodedPolylineFailure.outOfRange,
    );
  });

  test('should refuse a longitude beyond the antimeridian', () {
    expect(
      failureOf(decodePolyline('?agsia@')),
      EncodedPolylineFailure.outOfRange,
    );
  });
}
