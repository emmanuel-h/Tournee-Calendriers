import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/geometry/join_lines.dart';

import '../../support/geo_fixtures.dart';

void main() {
  // Four points along a road of Villefranche-sur-Saône, west to east.
  final a = at(45.98900, 4.71600);
  final b = at(45.98900, 4.71700);
  final c = at(45.98900, 4.71800);
  final d = at(45.98900, 4.71900);

  test('should join a line ending where the other starts', () {
    expect(
      joinLines([
        [a, b],
        [b, c],
      ], toleranceMetres: 1),
      [
        [a, b, c],
      ],
    );
  });

  test('should join a line ending where the other ends, turning it '
      'round', () {
    expect(
      joinLines([
        [a, b],
        [c, b],
      ], toleranceMetres: 1),
      [
        [a, b, c],
      ],
    );
  });

  test('should join a line starting where the other ends', () {
    expect(
      joinLines([
        [b, c],
        [a, b],
      ], toleranceMetres: 1),
      [
        [a, b, c],
      ],
    );
  });

  test('should join a line starting where the other starts, turning it '
      'round', () {
    expect(
      joinLines([
        [b, c],
        [b, a],
      ], toleranceMetres: 1),
      [
        [a, b, c],
      ],
    );
  });

  test('should join pieces given out of order into one line', () {
    expect(
      joinLines([
        [a, b],
        [c, d],
        [b, c],
      ], toleranceMetres: 1),
      [
        [a, b, c, d],
      ],
    );
  });

  test('should join ends exactly the tolerance apart, keeping the first '
      'end', () {
    final nearB = at(45.98901, 4.71700);
    final apart = metresBetween(b, nearB);

    expect(
      joinLines([
        [a, b],
        [nearB, c],
      ], toleranceMetres: apart),
      [
        [a, b, c],
      ],
    );
  });

  test('should not join ends farther apart than the tolerance', () {
    final nearB = at(45.98901, 4.71700);
    final apart = metresBetween(b, nearB);

    expect(
      joinLines([
        [a, b],
        [nearB, c],
      ], toleranceMetres: apart * 0.99),
      [
        [a, b],
        [nearB, c],
      ],
    );
  });

  test('should give back lines that meet no other, in their order', () {
    expect(
      joinLines([
        [c, d],
        [a, b],
      ], toleranceMetres: 1),
      [
        [c, d],
        [a, b],
      ],
    );
  });

  test('should give nothing for no line', () {
    expect(joinLines([], toleranceMetres: 1), isEmpty);
  });
}
