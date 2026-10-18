// « Ajouter et me l'attribuer » / « Ajouter sans m'attribuer » on the street
// card (PLAN §5.4): the BAN street with its numbers and positions, and the
// road the card found when it did, stored in the tournée at once.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/add_street_from_map.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

final _morinId = BanStreetId('69264_1460');

final _morinNumbers = StreetNumbers(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('3'), position: townHallDoor),
    DirectoryNumber(number: n('1'), position: northDoor),
    DirectoryNumber(number: n('2')),
  ],
  invalidNumbers: 1,
  duplicateNumbers: 0,
);

/// The road the card found, simplified.
final _road = StreetShape([
  [at(45.98800, 4.72500), at(45.98900, 4.72500)],
]);

void main() {
  late FakeStreetRepository streets;
  late AddStreetFromMap add;

  setUp(() {
    streets = repositoryWithLilas();
    add = AddStreetFromMap(streets, FakeIdGenerator('street'), leaOnThePhone());
  });

  group('a new street', () {
    test('should store the street with its numbers and positions', () async {
      final street = valueOf(await add(_morinNumbers, assignToMe: false));

      expect(streets.added, [same(street)]);
      expect(street.id, StreetId('street-1'));
      expect(street.name, streetName('Rue Pierre Morin'));
      expect(street.commune, villefranche);
      expect(street.banId, _morinId);
      expect(street.houses, [
        House(number: n('1'), position: northDoor),
        House(number: n('2')),
        House(number: n('3'), position: townHallDoor),
      ]);
      expect(street.deletion, isNull);
    });

    test('should give the street to the member with « Ajouter et me '
        'l\'attribuer »', () async {
      final street = valueOf(await add(_morinNumbers, assignToMe: true));

      expect(street.assignees, {lea});
    });

    test('should leave the street free with « Ajouter sans '
        'm\'attribuer »', () async {
      final street = valueOf(await add(_morinNumbers, assignToMe: false));

      expect(street.assignees, isEmpty);
    });

    test('should store the road the card found', () async {
      final street = valueOf(
        await add(_morinNumbers, assignToMe: false, shape: _road),
      );

      expect(street.shape, _road);
      expect(streets.added.single.shape, _road);
    });

    // The road may still be on its way: adding never waits for it, the
    // street gets its line later (`FillStreetShape`).
    test('should store the street without shape when the card has no '
        'road', () async {
      final street = valueOf(await add(_morinNumbers, assignToMe: false));

      expect(street.shape, StreetShape.none);
      expect(streets.added, hasLength(1));
    });

    test('should refuse numbers the BAN gave twice', () async {
      final twice = StreetNumbers(
        id: _morinId,
        name: streetName('Rue Pierre Morin'),
        commune: villefranche,
        numbers: [
          DirectoryNumber(number: n('1')),
          DirectoryNumber(number: n('1')),
        ],
        invalidNumbers: 0,
        duplicateNumbers: 0,
      );

      final failure = failureOf(await add(twice, assignToMe: false));

      expect(failure, AddStreetFailure.serviceError);
      expect(streets.added, isEmpty);
    });
  });

  group('a street the tournée has already', () {
    final lilasNumbers = StreetNumbers(
      id: lilas.banId!,
      name: streetName('Rue des Lilas'),
      commune: villefranche,
      numbers: [DirectoryNumber(number: n('5'))],
      invalidNumbers: 0,
      duplicateNumbers: 0,
    );

    test('should refuse it and change nothing', () async {
      final failure = failureOf(await add(lilasNumbers, assignToMe: true));

      expect(failure, AddStreetFailure.alreadyInTournee);
      expect(streets.added, isEmpty);
      expect(streets.saved, isEmpty);
    });

    group('in the Corbeille', () {
      late Street marked;

      setUp(() async {
        final (done, mark) = valueOf(
          lilas.markHouse(n('7'), VisitStatus.done, by: paul, at: threePm),
        );
        final (deleted, deletion) = done.delete(by: paul, at: threePm);
        await streets.save(done, mark);
        await streets.save(deleted, deletion);
        marked = done;
        streets.saved.clear();
      });

      test('should bring it back with its marks', () async {
        final street = valueOf(await add(lilasNumbers, assignToMe: false));

        expect(street.isDeleted, isFalse);
        expect(street.id, lilasId);
        expect(street.houses, marked.houses);
        expect(streets[lilasId]!.isDeleted, isFalse);
        expect(streets.added, isEmpty);
        expect(streets.saved.single.$2, StreetRestored(streetId: lilasId));
      });

      test('should give it to the member with « Ajouter et me '
          'l\'attribuer »', () async {
        final street = valueOf(await add(lilasNumbers, assignToMe: true));

        expect(street.assignees, {lea});
        expect(streets[lilasId]!.assignees, {lea});
        expect(streets.saved.map((saved) => saved.$2), [
          StreetRestored(streetId: lilasId),
          StreetTaken(streetId: lilasId, member: lea),
        ]);
      });

      test('should not take it again when the member covers it', () async {
        final (taken, change) = valueOf(streets[lilasId]!.take(lea));
        await streets.save(taken, change);
        streets.saved.clear();

        final street = valueOf(await add(lilasNumbers, assignToMe: true));

        expect(street.assignees, {lea});
        expect(streets.saved.map((saved) => saved.$2), [
          StreetRestored(streetId: lilasId),
        ]);
      });
    });
  });
}
