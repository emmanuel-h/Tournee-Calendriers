// What the map draws of a street: the whole road, or for a street held in
// part only the stretch between its first and last held number (PLAN
// §5.15 « Map »).
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/map/held_stretch.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// A road running east along the 45.98° parallel, 0.001° (about 77 m).
final _road = StreetShape([
  [at(45.98, 4.7200), at(45.98, 4.7210)],
]);

/// Where the house of [longitude] stands: odd numbers a little north of
/// the road, even ones a little south.
GeoPoint _door(String label, double longitude) => at(
  int.parse(label.replaceAll(RegExp('[^0-9]'), '')).isOdd ? 45.98002 : 45.97998,
  longitude,
);

House _house(String label, double longitude) =>
    House(number: n(label), position: _door(label, longitude));

/// Rue Nationale of [held], holding [houses] on [_road].
Street _street(List<House> houses, {StreetPart held = StreetPart.whole}) =>
    valueOf(
      Street.create(
        id: StreetId('rue-nationale'),
        name: 'Rue Nationale',
        commune: villefranche,
        shape: _road,
        part: held,
        houses: houses,
      ),
    );

/// Houses 3 (at 4.7202), 5 (4.7204), 7 (4.7206) on the odd side and 4
/// (4.7203), 6 (4.7207) on the even side.
final _houses = [
  _house('3', 4.7202),
  _house('5', 4.7204),
  _house('7', 4.7206),
  _house('4', 4.7203),
  _house('6', 4.7207),
];

/// The stretch of [_road] from [from] to [to] (longitudes), 3 m beyond.
StreetShape _stretch(double from, double to) =>
    _road.stretchOver([at(45.98, from), at(45.98, to)], beyondMetres: 3);

void main() {
  test('should draw the whole road of a whole street', () {
    expect(heldStretchOf(_street(_houses)), same(_road));
  });

  test('should draw the stretch between the first and the last number of '
      'a range, 3 m beyond', () {
    final street = _street([
      _house('5', 4.7204),
      _house('7', 4.7206),
    ], held: part(odd: range(5, 7), even: SidePart.none));

    expect(heldStretchOf(street), _stretch(4.7204, 4.7206));
  });

  test('should draw the stretch of a range of the even side', () {
    final street = _street([
      _house('4', 4.7203),
      _house('6', 4.7207),
    ], held: part(odd: SidePart.none, even: range(4, 6)));

    expect(heldStretchOf(street), _stretch(4.7203, 4.7207));
  });

  test('should draw the stretch over the numbers of both ranges', () {
    final street = _street(
      _houses,
      held: part(odd: range(3, 7), even: range(4, 6)),
    );

    expect(heldStretchOf(street), _stretch(4.7202, 4.7207));
  });

  test('should leave out a number added outside the part', () {
    final street = _street([
      _house('5', 4.7204),
      _house('7', 4.7206),
      _house('9', 4.7209),
    ], held: part(odd: range(5, 7), even: SidePart.none));

    expect(heldStretchOf(street), _stretch(4.7204, 4.7206));
  });

  test('should leave out a number held without a position', () {
    final street = _street([
      _house('5', 4.7204),
      _house('7', 4.7206),
      House(number: n('6')),
    ], held: part(odd: range(5, 7), even: range(6, 6)));

    expect(heldStretchOf(street), _stretch(4.7204, 4.7206));
  });

  test('should draw the whole road of a part by side alone', () {
    final odd = _street(
      _houses,
      held: part(odd: SidePart.all, even: SidePart.none),
    );
    final even = _street(
      _houses,
      held: part(odd: SidePart.none, even: SidePart.all),
    );

    expect(heldStretchOf(odd), same(_road));
    expect(heldStretchOf(even), same(_road));
  });

  test('should draw the whole road when a side whole goes with a range', () {
    final oddWhole = _street(
      _houses,
      held: part(odd: SidePart.all, even: range(4, 4)),
    );
    final evenWhole = _street(
      _houses,
      held: part(odd: range(5, 5), even: SidePart.all),
    );

    expect(heldStretchOf(oddWhole), same(_road));
    expect(heldStretchOf(evenWhole), same(_road));
  });

  test('should draw the whole road of a part holding nothing', () {
    final street = _street([
      _house('5', 4.7204),
    ], held: part(odd: SidePart.none, even: SidePart.none));

    expect(heldStretchOf(street), same(_road));
  });

  test('should draw the whole road when no number held has a position', () {
    final street = _street([
      House(number: n('5')),
    ], held: part(odd: range(5, 7), even: SidePart.none));

    expect(heldStretchOf(street), same(_road));
  });

  test('should draw no line for a street without shape', () {
    final manual = Street.manual(
      id: StreetId('chemin-neuf'),
      name: streetName('Chemin Neuf'),
      commune: villefranche,
      numbers: [n('5')],
    );

    expect(heldStretchOf(manual), StreetShape.none);
  });
}
