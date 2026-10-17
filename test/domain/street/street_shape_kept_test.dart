// A street keeps where it runs on the map whatever command changes it: its
// line must not vanish after a tap (PLAN §6.1).
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _shape = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);

final _street = valueOf(
  Street.create(
    id: StreetId('rue-nationale'),
    name: 'Rue Nationale',
    commune: villefranche,
    shape: _shape,
    houses: [House(number: n('5'))],
  ),
);

void main() {
  test('should keep the shape it is created with', () {
    expect(_street.shape, _shape);
  });

  test('should have no shape when created without one', () {
    final street = valueOf(
      Street.create(
        id: StreetId('rue-nationale'),
        name: 'Rue Nationale',
        commune: villefranche,
      ),
    );

    expect(street.shape, StreetShape.none);
  });

  test('should have no shape when typed in by hand', () {
    final street = Street.manual(
      id: StreetId('chemin-neuf'),
      name: streetName('Chemin Neuf'),
      commune: villefranche,
      numbers: [n('1')],
    );

    expect(street.shape, StreetShape.none);
  });

  test('should keep the shape when a house is marked', () {
    final (street, _) = valueOf(
      _street.markHouse(n('5'), VisitStatus.done, by: lea, at: twoPm),
    );

    expect(street.shape, _shape);
  });

  test('should keep the shape when the street is renamed', () {
    final (street, _) = _street.renameStreet(streetName('Rue de la Paix'));

    expect(street.shape, _shape);
  });

  test('should keep the shape when the street is deleted', () {
    final (street, _) = _street.delete(by: lea, at: twoPm);

    expect(street.shape, _shape);
  });

  test('should keep the shape when the street is restamped', () {
    expect(_street.restampedBy(paul).shape, _shape);
  });
}
