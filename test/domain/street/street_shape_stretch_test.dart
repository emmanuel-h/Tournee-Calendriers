// The stretch of a street's road over some houses: what the map draws of a
// street held in part (PLAN §5.15 « Map »).
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';

/// 1e-4° of longitude at Villefranche's latitude, in metres (about 7.7 m).
final _step = metresBetween(at(45.98, 4.7200), at(45.98, 4.7201));

void main() {
  // A road running east along the 45.98° parallel for four steps, then
  // turning north for one step.
  final west = at(45.98, 4.7200);
  final corner = at(45.98, 4.7204);
  final north = at(45.9801, 4.7204);
  final road = StreetShape([
    [west, corner, north],
  ]);

  // Houses a little north of the road, one and three steps from its start.
  final atOne = at(45.98002, 4.7201);
  final atThree = at(45.98002, 4.7203);

  group('stretchOver', () {
    test('should run from the first point to the last, each brought onto '
        'the road', () {
      final stretch = road.stretchOver([atOne, atThree], beyondMetres: 0);

      expect(stretch.lines, hasLength(1));
      final line = stretch.lines.single;
      expect(line, hasLength(2));
      expect(line.first.latitude, closeTo(45.98, 1e-9));
      expect(line.first.longitude, closeTo(4.7201, 1e-9));
      expect(line.last.latitude, closeTo(45.98, 1e-9));
      expect(line.last.longitude, closeTo(4.7203, 1e-9));
    });

    test('should find the first and the last along the road, whatever '
        'their order', () {
      final middle = at(45.98002, 4.7202);

      expect(
        road.stretchOver([middle, atThree, atOne], beyondMetres: 0),
        road.stretchOver([atOne, atThree], beyondMetres: 0),
      );
    });

    test('should go on round a corner of the road', () {
      final nearNorth = at(45.98005, 4.72042);

      final line = road
          .stretchOver([atThree, nearNorth], beyondMetres: 0)
          .lines
          .single;

      expect(line, hasLength(3));
      expect(line[1], corner);
      expect(line.last.latitude, closeTo(45.98005, 1e-9));
      expect(line.last.longitude, closeTo(4.7204, 1e-9));
    });

    test('should go [beyondMetres] past the first and the last point', () {
      final line = road
          .stretchOver([atOne, atThree], beyondMetres: 3)
          .lines
          .single;

      expect(metresBetween(west, line.first), closeTo(_step - 3, 1e-3));
      expect(metresBetween(west, line.last), closeTo(3 * _step + 3, 1e-3));
    });

    test('should give a single point a stretch of twice [beyondMetres]', () {
      final line = road.stretchOver([atOne], beyondMetres: 3).lines.single;

      expect(metresBetween(line.first, line.last), closeTo(6, 1e-3));
    });

    test('should stop at the ends of the road', () {
      final line = road
          .stretchOver([atOne, atThree], beyondMetres: 1000)
          .lines
          .single;

      expect(line, [west, corner, north]);
    });

    test('should not cross the gap between two pieces of road that do not '
        'meet', () {
      final farEast = at(45.98, 4.7210);
      final fartherEast = at(45.98, 4.7214);
      final pieces = StreetShape([
        [west, corner],
        [farEast, fartherEast],
      ]);

      final stretch = pieces.stretchOver([
        atThree,
        at(45.98002, 4.7212),
      ], beyondMetres: 0);

      expect(stretch.lines, hasLength(2));
      expect(stretch.lines.first.last, corner);
      expect(stretch.lines.last.first, farEast);
      expect(stretch.lines.last.last.longitude, closeTo(4.7212, 1e-9));
    });

    test('should join two pieces of road meeting end to end', () {
      final pieces = StreetShape([
        [corner, north],
        [west, corner],
      ]);

      final stretch = pieces.stretchOver([
        atOne,
        at(45.98005, 4.72042),
      ], beyondMetres: 0);

      expect(stretch.lines, hasLength(1));
      expect(stretch.lines.single[1], corner);
    });

    test('should be no line when there is no point', () {
      expect(road.stretchOver(const [], beyondMetres: 3), StreetShape.none);
    });

    test('should be no line when the road has none', () {
      expect(
        StreetShape.none.stretchOver([atOne], beyondMetres: 3),
        StreetShape.none,
      );
    });
  });
}
