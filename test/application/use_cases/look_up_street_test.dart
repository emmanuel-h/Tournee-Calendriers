// What the street card of « Ajouter des rues » shows (PLAN §5.4): the BAN
// street under a tap, or chosen in the search, and whether the tournée has
// it already.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

final _tap = at(45.98800, 4.72500);
final _morinId = BanStreetId('69264_1460');

final _morin = StreetMatch(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  position: at(45.98810, 4.72490),
);

final _morinNumbers = StreetNumbers(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('1'), position: townHallDoor),
    DirectoryNumber(number: n('3')),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

/// The match of the Rue des Lilas, which the tournée has.
final _lilasMatch = StreetMatch(
  id: lilas.banId!,
  name: streetName('Rue des Lilas'),
  commune: villefranche,
  position: northDoor,
);

void main() {
  late FakeStreetRepository streets;

  setUp(() => streets = repositoryWithLilas());

  LookUpStreet lookUp(FakeAddressDirectory directory) =>
      LookUpStreet(directory, streets);

  group('a tap on the map', () {
    test('should give the street under the tap with its numbers when the '
        'tournée does not have it', () async {
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(_morin)},
        streets: {_morinId: Ok(_morinNumbers)},
      );

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found, isA<StreetToAdd>());
      found as StreetToAdd;
      expect(found.match, _morin);
      expect(found.numbers, same(_morinNumbers));
      expect(found.numberCount, 2);
      expect(directory.pointsAsked, [_tap]);
      expect(directory.streetsAsked, [_morinId]);
    });

    test('should give the street of the tournée when it has it, without '
        'asking its numbers', () async {
      final directory = FakeAddressDirectory(places: {_tap: Ok(_lilasMatch)});

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found, isA<StreetOfTheTournee>());
      found as StreetOfTheTournee;
      expect(found.match, _lilasMatch);
      expect(found.street, same(lilas));
      expect(directory.streetsAsked, isEmpty);
    });

    test('should offer to add again a street of the Corbeille', () async {
      final (deleted, change) = lilas.delete(by: lea, at: twoPm);
      await streets.save(deleted, change);
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(_lilasMatch)},
        streets: {lilas.banId!: Ok(_morinNumbers)},
      );

      final found = valueOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(found, isA<StreetToAdd>());
      expect(directory.streetsAsked, [lilas.banId]);
    });

    test('should say no street is there when the BAN has no match', () async {
      final directory = FakeAddressDirectory();

      final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(failure, AddressDirectoryFailure.notFound);
      expect(directory.streetsAsked, isEmpty);
    });

    test('should say the network is missing when offline', () async {
      final directory = FakeAddressDirectory(
        places: {_tap: const Err(AddressDirectoryFailure.noNetwork)},
      );

      final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(failure, AddressDirectoryFailure.noNetwork);
    });

    test('should say the network is missing when it goes before the '
        'numbers come', () async {
      final directory = FakeAddressDirectory(
        places: {_tap: Ok(_morin)},
        streets: {_morinId: const Err(AddressDirectoryFailure.noNetwork)},
      );

      final failure = failureOf(await lookUp(directory)(StreetAtPoint(_tap)));

      expect(failure, AddressDirectoryFailure.noNetwork);
    });
  });

  group('a street found by the search', () {
    test('should give its numbers without asking the geocoder', () async {
      final directory = FakeAddressDirectory(
        streets: {_morinId: Ok(_morinNumbers)},
      );

      final found = valueOf(await lookUp(directory)(FoundStreet(_morin)));

      expect(found, isA<StreetToAdd>());
      found as StreetToAdd;
      expect(found.match, _morin);
      expect(found.numberCount, 2);
      expect(directory.pointsAsked, isEmpty);
    });

    test('should give the street of the tournée when it has it', () async {
      final directory = FakeAddressDirectory();

      final found = valueOf(await lookUp(directory)(FoundStreet(_lilasMatch)));

      expect((found as StreetOfTheTournee).street.id, lilasId);
      expect(directory.streetsAsked, isEmpty);
    });

    test('should pass on a BAN that cannot answer', () async {
      final directory = FakeAddressDirectory(
        streets: {_morinId: const Err(AddressDirectoryFailure.serviceError)},
      );

      final failure = failureOf(await lookUp(directory)(FoundStreet(_morin)));

      expect(failure, AddressDirectoryFailure.serviceError);
    });
  });

  test('should not change any street', () async {
    final directory = FakeAddressDirectory(
      places: {_tap: Ok(_morin)},
      streets: {_morinId: Ok(_morinNumbers)},
    );

    await lookUp(directory)(StreetAtPoint(_tap));

    expect(streets.added, isEmpty);
    expect(streets.saved, isEmpty);
    expect(await streets.findByBanId(_morinId), isNull);
    expect(streets[lilasId], isA<Street>());
  });
}
