import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/edit_street_numbers.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  late FakeStreetRepository streets;
  late EditStreetNumbers editStreet;

  setUp(() {
    streets = repositoryWithLilas();
    editStreet = EditStreetNumbers(streets, clockAtTwo(), leaOnThePhone());
  });

  Street stored() => streets[lilasId]!;

  List<String> labels(Street street) => [
    for (final house in street.houses) house.number.label,
  ];

  test('should add the new numbers and skip those shown', () async {
    final change = valueOf(
      await editStreet(lilasId, AddNumbers([n('7'), n('9'), n('11')])),
    );

    expect(change, isA<NumbersAdded>());
    final added = change as NumbersAdded;
    expect(added.added.map((house) => house.number), [n('9'), n('11')]);
    expect(added.alreadyThere, [n('7')]);
    expect(labels(stored()), ['5', '7', '8', '9', '11']);
    expect(streets.saved.single.$2, change);
  });

  test('should keep the numbers given when the list changes after', () {
    final numbers = [n('9')];
    final edit = AddNumbers(numbers);
    numbers.add(n('11'));

    expect(edit.numbers, [n('9')]);
  });

  test('should send a number to the Corbeille with its marks', () async {
    final change = valueOf(await editStreet(lilasId, RemoveNumber(n('5'))));

    expect(
      change,
      NumberRemoved(
        streetId: lilasId,
        removed: RemovedHouse(house: five, removal: leaAtTwo),
      ),
    );
    expect(labels(stored()), ['7', '8']);
    expect(stored().removedHouses.single.house, five);
  });

  test('should bring a number back from the Corbeille', () async {
    valueOf(await editStreet(lilasId, RemoveNumber(n('5'))));

    final change = valueOf(await editStreet(lilasId, RestoreNumber(n('5'))));

    expect(change, isA<NumberRestored>());
    expect(houseOf(stored(), '5'), five);
    expect(stored().removedHouses, isEmpty);
  });

  test('should give a house a new number', () async {
    final change = valueOf(
      await editStreet(lilasId, RenameNumber(n('5'), n('5bis'))),
    );

    expect(
      change,
      NumberRenamed(
        streetId: lilasId,
        before: five,
        stamp: leaAtTwo,
        newNumber: n('5bis'),
      ),
    );
    expect(labels(stored()), ['5bis', '7', '8']);
  });

  test('should rename the street', () async {
    final change = valueOf(
      await editStreet(
        lilasId,
        RenameStreet(valueOf(StreetName.create('Rue des Roses'))),
      ),
    );

    expect(
      change,
      StreetRenamed(
        streetId: lilasId,
        before: streetName('Rue des Lilas'),
        name: streetName('Rue des Roses'),
      ),
    );
    expect(stored().name.text, 'Rue des Roses');
  });

  test('should send the street to the Corbeille', () async {
    // Built at run time, as the screen does: a `const` instance is made by
    // the compiler, so its constructor line would never count as covered.
    // ignore: prefer_const_constructors
    final change = valueOf(await editStreet(lilasId, DeleteStreet()));

    expect(change, StreetDeleted(streetId: lilasId, deletion: leaAtTwo));
    expect(stored().deletion, leaAtTwo);
  });

  test('should bring a deleted street back from the Corbeille', () async {
    await editStreet(lilasId, const DeleteStreet());

    // Built at run time, like DeleteStreet above, so CI counts its
    // constructor line as covered.
    // ignore: prefer_const_constructors
    final change = valueOf(await editStreet(lilasId, RestoreStreet()));

    expect(change, StreetRestored(streetId: lilasId));
    expect(stored().deletion, isNull);
    expect(labels(stored()), ['5', '7', '8']);
  });

  test('should fail when the street refuses the edit', () async {
    final failure = failureOf(
      await editStreet(lilasId, RenameNumber(n('5'), n('7'))),
    );

    expect(failure, const CommandRefused(NumberChangeFailure.numberTaken));
    expect(streets.saved, isEmpty);
  });

  test('should fail when the street is unknown', () async {
    final failure = failureOf(
      await editStreet(StreetId('rue-inconnue'), const DeleteStreet()),
    );

    expect(failure, const StreetNotFound<NumberChangeFailure>());
  });
}
