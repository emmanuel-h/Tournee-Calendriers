import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/read_street_part_choice.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');
final _ban = BanStreetId('69264_0420');
final _oddSide = part(odd: SidePart.all, even: SidePart.none);
final _road = StreetShape([
  [townHallDoor, northDoor],
]);
final _otherDoor = at(45.99, 4.718);

/// The Rue des Lilas holding its odd side: 5 (at the town hall's door), 7
/// typed by hand, 9 in the Corbeille (at the north door).
Street _lilas({BanStreetId? banId}) => valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    banId: banId,
    shape: _road,
    part: _oddSide,
    houses: [
      House(number: n('5'), position: townHallDoor),
      House(number: n('7')),
    ],
    removedHouses: [
      RemovedHouse(
        house: House(number: n('9'), position: northDoor),
        removal: ChangeStamp(by: lea, at: twoPm),
      ),
    ],
  ),
);

/// The numbers the BAN gives the Rue des Lilas: 5 elsewhere, 7 at the
/// other door, 8 without position, 10 at the north door.
StreetNumbers _banNumbers() => StreetNumbers(
  id: _ban,
  name: streetName('Rue des Lilas'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('5'), position: _otherDoor),
    DirectoryNumber(number: n('7'), position: _otherDoor),
    DirectoryNumber(number: n('8')),
    DirectoryNumber(number: n('10'), position: northDoor),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

void main() {
  late FakeAddressDirectory directory;

  ReadStreetPartChoice read(
    Street? street, {
    Result<StreetNumbers, AddressDirectoryFailure>? answer,
  }) {
    directory = FakeAddressDirectory(streets: {_ban: ?answer});
    return ReadStreetPartChoice(FakeStreetRepository([?street]), directory);
  }

  test('should choose among the BAN numbers and the street\'s own, its '
      'positions first', () async {
    final choice = valueOf(
      await read(_lilas(banId: _ban), answer: Ok(_banNumbers()))(_id),
    );

    expect(choice.numbers, [
      PartNumber(n('5'), position: townHallDoor),
      PartNumber(n('7'), position: _otherDoor),
      PartNumber(n('8')),
      PartNumber(n('9'), position: northDoor),
      PartNumber(n('10'), position: northDoor),
    ]);
    expect(directory.streetsAsked, [_ban]);
  });

  test('should start from the street\'s part and road', () async {
    final choice = valueOf(
      await read(_lilas(banId: _ban), answer: Ok(_banNumbers()))(_id),
    );

    expect(choice.part, _oddSide);
    expect(choice.road, _road);
  });

  test('should choose among its own numbers, without asking the BAN, for a '
      'street typed by hand', () async {
    final choice = valueOf(await read(_lilas())(_id));

    expect(choice.numbers, [
      PartNumber(n('5'), position: townHallDoor),
      PartNumber(n('7')),
      PartNumber(n('9'), position: northDoor),
    ]);
    expect(directory.streetsAsked, isEmpty);
  });

  test('should choose among its own numbers when the BAN no longer knows '
      'the street', () async {
    final choice = valueOf(
      await read(
        _lilas(banId: _ban),
        answer: const Err(AddressDirectoryFailure.notFound),
      )(_id),
    );

    expect(choice.numbers.map((number) => number.number.label), [
      '5',
      '7',
      '9',
    ]);
  });

  test('should say the numbers cannot be read offline', () async {
    final refusal = failureOf(
      await read(
        _lilas(banId: _ban),
        answer: const Err(AddressDirectoryFailure.noNetwork),
      )(_id),
    );

    expect(
      refusal,
      const PartChoiceUnreadable(AddressDirectoryFailure.noNetwork),
    );
  });

  test('should say the numbers cannot be read when the BAN fails', () async {
    final refusal = failureOf(
      await read(
        _lilas(banId: _ban),
        answer: const Err(AddressDirectoryFailure.serviceError),
      )(_id),
    );

    expect(
      refusal,
      const PartChoiceUnreadable(AddressDirectoryFailure.serviceError),
    );
  });

  test('should say the street is gone', () async {
    final refusal = failureOf(await read(null)(_id));

    expect(refusal, const PartChoiceOfUnknownStreet());
  });

  test('should compare the refusals by value', () {
    const offline = PartChoiceUnreadable(AddressDirectoryFailure.noNetwork);

    expect(offline.hashCode, AddressDirectoryFailure.noNetwork.hashCode);
    expect(
      offline,
      isNot(const PartChoiceUnreadable(AddressDirectoryFailure.serviceError)),
    );
    expect(
      offline.toString(),
      'PartChoiceUnreadable(${AddressDirectoryFailure.noNetwork})',
    );
    expect(
      const PartChoiceOfUnknownStreet().hashCode,
      const PartChoiceOfUnknownStreet().hashCode,
    );
    expect(const PartChoiceOfUnknownStreet(), isNot(offline));
    expect(
      const PartChoiceOfUnknownStreet().toString(),
      'PartChoiceOfUnknownStreet',
    );
  });
}
