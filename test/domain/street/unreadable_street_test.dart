import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/unreadable_street.dart';

import '../../support/results.dart';

void main() {
  final pasteur = valueOf(StreetName.create('Rue Pasteur'));

  test('should keep the id and the name it was given', () {
    final street = UnreadableStreet(id: StreetId('pasteur'), name: pasteur);

    expect(street.id, StreetId('pasteur'));
    expect(street.name, pasteur);
  });

  test('should have no name when the name could not be read either', () {
    expect(UnreadableStreet(id: StreetId('pasteur')).name, isNull);
  });

  test('should be equal by id and name', () {
    final street = UnreadableStreet(id: StreetId('pasteur'), name: pasteur);

    expect(street, UnreadableStreet(id: StreetId('pasteur'), name: pasteur));
    expect(
      street.hashCode,
      UnreadableStreet(id: StreetId('pasteur'), name: pasteur).hashCode,
    );
    expect(
      street,
      isNot(UnreadableStreet(id: StreetId('other'), name: pasteur)),
    );
    expect(street, isNot(UnreadableStreet(id: StreetId('pasteur'))));
  });

  test('should say its id and name', () {
    expect(
      '${UnreadableStreet(id: StreetId('pasteur'), name: pasteur)}',
      'UnreadableStreet(pasteur, Rue Pasteur)',
    );
    expect(
      '${UnreadableStreet(id: StreetId('pasteur'))}',
      'UnreadableStreet(pasteur, null)',
    );
  });
}
