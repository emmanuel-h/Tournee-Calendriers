import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/geometry/simplify_line.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';

import '../../support/geo_fixtures.dart';

void main() {
  // A road running east along the latitude 45.99. 0.00001° of latitude is
  // about 1.1 m, 0.0001° about 11 m.
  final a = at(45.99, 4.7160);
  final b = at(45.99, 4.7165);
  final c = at(45.99, 4.7170);
  final d = at(45.99, 4.7175);
  final e = at(45.99, 4.7180);

  // Each row: what it shows, the line, the tolerance in metres, the line
  // simplified.
  final table = <(String, List<GeoPoint>, double, List<GeoPoint>)>[
    ('an empty line', [], 2, []),
    ('a single point', [a], 2, [a]),
    ('two points', [a, e], 2, [a, e]),
    ('points in a straight line', [a, b, c, d, e], 2, [a, e]),
    (
      'a wobble of 1 m under a 2 m tolerance',
      [a, at(45.99001, 4.7165), c, at(45.98999, 4.7175), e],
      2,
      [a, e],
    ),
    (
      // c is right between the two bumps, on the line joining them.
      'a wobble of 5.6 m over a 2 m tolerance',
      [a, at(45.99005, 4.7165), c, at(45.98995, 4.7175), e],
      2,
      [a, at(45.99005, 4.7165), at(45.98995, 4.7175), e],
    ),
    (
      'a corner: the road turns north',
      [a, b, c, at(45.9905, 4.7170), at(45.9910, 4.7170)],
      2,
      [a, c, at(45.9910, 4.7170)],
    ),
    (
      'a loop back to its start, measured from the start',
      [a, c, at(45.9905, 4.7170), at(45.9905, 4.7160), a],
      2,
      [a, c, at(45.9905, 4.7170), at(45.9905, 4.7160), a],
    ),
    (
      // Bumps of 2.2 m, 7.8 m and 6.7 m off a–e. The farthest (7.8 m) is
      // kept first; seen from the new segment a–7.8, the 2.2 m bump is only
      // 1.7 m off and goes, seen from 7.8–e the 6.7 m bump is 2.8 m off and
      // stays. Splitting at the first point over the tolerance instead of
      // the farthest one would keep the 2.2 m bump.
      'the farthest point first, then each half',
      [a, at(45.99002, 4.7165), at(45.99007, 4.7170), at(45.99006, 4.7175), e],
      2,
      [a, at(45.99007, 4.7170), at(45.99006, 4.7175), e],
    ),
  ];
  for (final (what, line, tolerance, expected) in table) {
    test('should simplify $what', () {
      expect(simplifyLine(line, toleranceMetres: tolerance), expected);
    });
  }

  group('the tolerance', () {
    final bump = at(45.9901, 4.7170);
    final line = [a, bump, e];
    final distance = metresFromSegment(bump, a, e);

    test('should keep a point just over the tolerance', () {
      expect(simplifyLine(line, toleranceMetres: distance - 0.001), [
        a,
        bump,
        e,
      ]);
    });

    test('should drop a point exactly at the tolerance', () {
      expect(simplifyLine(line, toleranceMetres: distance), [a, e]);
    });

    test('should drop a point under the tolerance', () {
      expect(simplifyLine(line, toleranceMetres: distance + 0.001), [a, e]);
    });
  });

  test('should give a list that cannot be modified', () {
    final simplified = simplifyLine([a, b, e], toleranceMetres: 2);

    expect(() => simplified.add(c), throwsUnsupportedError);
  });
}
