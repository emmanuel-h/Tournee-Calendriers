import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/clip_line.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';

import '../../support/geo_fixtures.dart';

void main() {
  // Around Villefranche-sur-Saône. The sides are written with fractions a
  // computer holds exactly (.25, .5, .75), so the points where a line
  // crosses a side compare equal.
  final bounds = GeoBounds.around([at(45.75, 4.5), at(46.0, 4.75)])!;

  test('should keep a line that stays inside whole', () {
    final line = [at(45.875, 4.625), at(45.875, 4.6875), at(45.9375, 4.6875)];

    expect(clipLine(line, bounds), [line]);
  });

  test('should keep nothing of a line that stays outside', () {
    expect(clipLine([at(46.25, 4.625), at(46.25, 4.6875)], bounds), isEmpty);
  });

  test('should cut a line coming in from the west on that side', () {
    expect(clipLine([at(45.875, 4.25), at(45.875, 4.625)], bounds), [
      [at(45.875, 4.5), at(45.875, 4.625)],
    ]);
  });

  test('should cut a line going out to the east on that side', () {
    expect(clipLine([at(45.875, 4.625), at(45.875, 5.0)], bounds), [
      [at(45.875, 4.625), at(45.875, 4.75)],
    ]);
  });

  test('should cut a line crossing from south to north on both sides', () {
    expect(clipLine([at(45.5, 4.625), at(46.5, 4.625)], bounds), [
      [at(45.75, 4.625), at(46.0, 4.625)],
    ]);
  });

  test('should cut a line crossing from north to south on both sides', () {
    expect(clipLine([at(46.5, 4.625), at(45.5, 4.625)], bounds), [
      [at(46.0, 4.625), at(45.75, 4.625)],
    ]);
  });

  test('should give two pieces when the line goes out and comes back', () {
    final line = [
      at(45.875, 4.625),
      at(45.875, 5.0),
      at(45.9375, 5.0),
      at(45.9375, 4.625),
    ];

    expect(clipLine(line, bounds), [
      [at(45.875, 4.625), at(45.875, 4.75)],
      [at(45.9375, 4.75), at(45.9375, 4.625)],
    ]);
  });

  test('should keep a line that runs along a side', () {
    final line = [at(46.0, 4.5), at(46.0, 4.75)];

    expect(clipLine(line, bounds), [line]);
  });

  test('should keep nothing of a line that only touches a corner', () {
    // It crosses the south-east corner (45.75, 4.75) from outside to
    // outside.
    expect(clipLine([at(45.5, 4.5), at(46.0, 5.0)], bounds), isEmpty);
  });

  test('should keep nothing of a line of one point', () {
    expect(clipLine([at(45.875, 4.625)], bounds), isEmpty);
  });
}
