import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/geometry/line_track.dart';

import '../../support/geo_fixtures.dart';

/// 1e-4° of longitude at Villefranche's latitude, in metres (about 7.7 m).
final _step = metresBetween(at(45.98, 4.7200), at(45.98, 4.7201));

void main() {
  // A road running east along the 45.98° parallel, 0.0002° (two steps)
  // long, then turning north for one step.
  final west = at(45.98, 4.7200);
  final middle = at(45.98, 4.7201);
  final corner = at(45.98, 4.7202);
  final north = at(45.9801, 4.7202);

  group('through', () {
    test('should be null when there is no line', () {
      expect(LineTrack.through(const []), isNull);
    });

    test('should measure the length of the line', () {
      final track = LineTrack.through([
        [west, corner],
      ])!;

      expect(track.length, closeTo(2 * _step, 1e-6));
    });

    test('should join two pieces meeting end to end into one track', () {
      final track = LineTrack.through([
        [corner, north],
        [west, corner],
      ])!;

      expect(track.points, [west, corner, north]);
    });

    test('should put pieces that do not meet end to end, turning the next '
        'one to start where the previous ended', () {
      final farEast = at(45.98, 4.7210);
      final fartherEast = at(45.98, 4.7212);
      final track = LineTrack.through([
        [west, middle],
        [fartherEast, farEast],
      ])!;

      expect(track.points, [west, middle, farEast, fartherEast]);
    });

    test('should keep the next piece as it is when its start is nearest', () {
      final farEast = at(45.98, 4.7210);
      final fartherEast = at(45.98, 4.7212);
      final track = LineTrack.through([
        [west, middle],
        [farEast, fartherEast],
      ])!;

      expect(track.points, [west, middle, farEast, fartherEast]);
    });
  });

  group('straight', () {
    test('should run from one point to the other', () {
      final track = LineTrack.straight(west, corner);

      expect(track.points, [west, corner]);
      expect(track.length, closeTo(2 * _step, 1e-6));
    });
  });

  group('alongOf', () {
    final track = LineTrack.through([
      [west, corner, north],
    ])!;

    test('should be 0 at the start', () {
      expect(track.alongOf(west), 0);
    });

    test('should count the distance from the start to the point brought '
        'onto the line', () {
      // Beside the middle of the first segment, a little south.
      expect(track.alongOf(at(45.97995, 4.7201)), closeTo(_step, 1e-3));
    });

    test('should count the whole first segment for a point on the second', () {
      final halfNorth = metresBetween(corner, north) / 2;

      expect(
        track.alongOf(at(45.98005, 4.72025)),
        closeTo(2 * _step + halfNorth, 1e-3),
      );
    });

    test('should be the length beyond the end', () {
      expect(track.alongOf(at(45.9805, 4.7202)), closeTo(track.length, 1e-6));
    });
  });

  group('pointAt', () {
    final track = LineTrack.through([
      [west, corner, north],
    ])!;

    test('should be the start at 0 and before it', () {
      expect(track.pointAt(0), west);
      expect(track.pointAt(-5), west);
    });

    test('should be the end at the length and beyond it', () {
      expect(track.pointAt(track.length), north);
      expect(track.pointAt(track.length + 5), north);
    });

    test('should walk along the line', () {
      final point = track.pointAt(_step);

      expect(point.latitude, closeTo(45.98, 1e-9));
      expect(point.longitude, closeTo(4.7201, 1e-9));
    });

    test('should walk into the second segment past the corner', () {
      final halfNorth = metresBetween(corner, north) / 2;
      final point = track.pointAt(2 * _step + halfNorth);

      expect(point.latitude, closeTo(45.98005, 1e-9));
      expect(point.longitude, closeTo(4.7202, 1e-9));
    });
  });

  group('between', () {
    final track = LineTrack.through([
      [west, corner, north],
    ])!;

    test('should be the stretch between two distances, its corners kept', () {
      final halfNorth = metresBetween(corner, north) / 2;
      final stretch = track.between(_step, 2 * _step + halfNorth);

      expect(stretch, hasLength(3));
      expect(stretch[0].longitude, closeTo(4.7201, 1e-9));
      expect(stretch[1], corner);
      expect(stretch[2].latitude, closeTo(45.98005, 1e-9));
    });

    test('should leave out a corner at either end of the stretch', () {
      final stretch = track.between(0, metresBetween(west, corner));

      expect(stretch, [west, corner]);
    });
  });
}
