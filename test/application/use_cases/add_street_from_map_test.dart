// « Ajouter et me l'attribuer » / « Ajouter sans m'attribuer » on the street
// card (PLAN §5.4): the BAN street with its numbers and positions, its
// shape from OpenStreetMap when Overpass answers, stored in the tournée.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/add_street_from_map.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
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

/// A road as OpenStreetMap draws it: the middle point lies on the straight
/// line from the first to the last, so simplifying drops it.
final _start = at(45.98800, 4.72500);
final _middle = at(45.98850, 4.72500);
final _end = at(45.98900, 4.72500);
final _osmShape = StreetShape([
  [_start, _middle, _end],
]);

void main() {
  late FakeStreetRepository streets;
  late FakeStreetShapes shapes;
  late AddStreetFromMap add;

  setUp(() {
    streets = repositoryWithLilas();
    shapes = FakeStreetShapes(Ok(_osmShape));
    add = AddStreetFromMap(
      shapes,
      streets,
      FakeIdGenerator('street'),
      leaOnThePhone(),
    );
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

    test('should store the shape OpenStreetMap gives, simplified', () async {
      final street = valueOf(await add(_morinNumbers, assignToMe: false));

      expect(
        street.shape,
        StreetShape([
          [_start, _end],
        ]),
      );
      expect(shapes.asked, [('Rue Pierre Morin', '69264')]);
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

    test('should store the street without shape when OpenStreetMap does not '
        'know the road', () async {
      shapes.answer = const Ok(StreetShape.none);

      final street = valueOf(await add(_morinNumbers, assignToMe: false));

      expect(street.shape, StreetShape.none);
      expect(streets.added, hasLength(1));
    });

    // Overpass is often busy (502, 504): the street must not wait for it.
    test('should store the street without shape when Overpass fails', () async {
      shapes.answer = const Err(StreetShapesFailure.serviceError);

      final street = valueOf(await add(_morinNumbers, assignToMe: true));

      expect(street.shape, StreetShape.none);
      expect(street.houses, hasLength(3));
      expect(streets.added, hasLength(1));
    });

    test('should store the street without shape when Overpass cannot be '
        'reached', () async {
      shapes.answer = const Err(StreetShapesFailure.noNetwork);

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
      expect(shapes.asked, isEmpty);
    });

    test('should refuse it when a teammate added it while the shape was '
        'asked', () async {
      final teammates = valueOf(
        Street.create(
          id: StreetId('their-morin'),
          name: 'Rue Pierre Morin',
          commune: villefranche,
          banId: _morinId,
        ),
      );
      shapes.whileAsked = () => streets.add(teammates);

      final failure = failureOf(await add(_morinNumbers, assignToMe: true));

      expect(failure, AddStreetFailure.alreadyInTournee);
      expect(streets.added, [same(teammates)]);
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

      test('should bring it back with its marks, without Overpass', () async {
        final street = valueOf(await add(lilasNumbers, assignToMe: false));

        expect(street.isDeleted, isFalse);
        expect(street.id, lilasId);
        expect(street.houses, marked.houses);
        expect(streets[lilasId]!.isDeleted, isFalse);
        expect(streets.added, isEmpty);
        expect(streets.saved.single.$2, StreetRestored(streetId: lilasId));
        expect(shapes.asked, isEmpty);
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
