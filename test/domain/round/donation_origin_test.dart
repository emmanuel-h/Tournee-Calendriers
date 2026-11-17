import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_origin.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');

House _house(VisitStatus status, [String number = '12']) =>
    House(number: n(number), status: status);

Dwelling _door(VisitStatus status) => Dwelling(label: d('51'), status: status);

final _twelve = DonationOrigin(street: _lilas, number: n('12'));

final _door51 = DonationOrigin(
  street: _lilas,
  number: n('8'),
  door: DwellingKey(escA, 5, d('51')),
);

HouseMarked _houseMarked(VisitStatus from, VisitStatus to) => HouseMarked(
  streetId: _lilas,
  before: _house(from),
  stamp: leaAtTwo,
  status: to,
);

DwellingMarked _doorMarked(VisitStatus from, VisitStatus to) => DwellingMarked(
  streetId: _lilas,
  number: n('8'),
  staircase: escA,
  level: 5,
  before: _door(from),
  stamp: leaAtTwo,
  status: to,
);

void main() {
  const notDone = [
    VisitStatus.toDo,
    VisitStatus.nobodyHome,
    VisitStatus.comeBack,
    VisitStatus.refused,
  ];

  group('leftDoneBy', () {
    test('should name a house taken from ✓ to any other status, ⊘ too', () {
      for (final to in notDone) {
        expect(
          DonationOrigin.leftDoneBy(_houseMarked(VisitStatus.done, to)),
          _twelve,
          reason: '✓ → $to',
        );
      }
    });

    test('should name no house that was not ✓, or still is', () {
      for (final from in notDone) {
        expect(
          DonationOrigin.leftDoneBy(_houseMarked(from, VisitStatus.done)),
          isNull,
          reason: '$from → ✓',
        );
      }
      expect(
        DonationOrigin.leftDoneBy(
          _houseMarked(VisitStatus.refused, VisitStatus.nobodyHome),
        ),
        isNull,
      );
      expect(
        DonationOrigin.leftDoneBy(
          _houseMarked(VisitStatus.done, VisitStatus.done),
        ),
        isNull,
      );
    });

    test('should name a door taken from ✓, with its building', () {
      for (final to in notDone) {
        expect(
          DonationOrigin.leftDoneBy(_doorMarked(VisitStatus.done, to)),
          _door51,
          reason: '✓ → $to',
        );
      }
      expect(
        DonationOrigin.leftDoneBy(
          _doorMarked(VisitStatus.refused, VisitStatus.toDo),
        ),
        isNull,
      );
      expect(
        DonationOrigin.leftDoneBy(
          _doorMarked(VisitStatus.toDo, VisitStatus.done),
        ),
        isNull,
      );
    });

    test('should name a ✓ turned into « de nouveau personne »', () {
      HouseNobodyHomeAgain house(VisitStatus from) => HouseNobodyHomeAgain(
        streetId: _lilas,
        before: _house(from),
        stamp: leaAtTwo,
        tries: tries(2),
      );
      DwellingNobodyHomeAgain door(VisitStatus from) => DwellingNobodyHomeAgain(
        streetId: _lilas,
        number: n('8'),
        staircase: escA,
        level: 5,
        before: _door(from),
        stamp: leaAtTwo,
        tries: tries(2),
      );

      expect(DonationOrigin.leftDoneBy(house(VisitStatus.done)), _twelve);
      expect(DonationOrigin.leftDoneBy(house(VisitStatus.nobodyHome)), isNull);
      expect(DonationOrigin.leftDoneBy(door(VisitStatus.done)), _door51);
      expect(DonationOrigin.leftDoneBy(door(VisitStatus.comeBack)), isNull);
    });

    test('should name the ✓ an undo takes back, not the one it puts back', () {
      HouseReverted house(VisitStatus replaced, VisitStatus back) =>
          HouseReverted(
            streetId: _lilas,
            replaced: _house(replaced),
            house: _house(back),
            stamp: leaAtTwo,
          );
      DwellingReverted door(VisitStatus replaced, VisitStatus back) =>
          DwellingReverted(
            streetId: _lilas,
            number: n('8'),
            staircase: escA,
            level: 5,
            replaced: _door(replaced),
            dwelling: _door(back),
            stamp: leaAtTwo,
          );

      expect(
        DonationOrigin.leftDoneBy(house(VisitStatus.done, VisitStatus.toDo)),
        _twelve,
      );
      expect(
        DonationOrigin.leftDoneBy(house(VisitStatus.toDo, VisitStatus.done)),
        isNull,
      );
      expect(
        DonationOrigin.leftDoneBy(door(VisitStatus.done, VisitStatus.refused)),
        _door51,
      );
      expect(
        DonationOrigin.leftDoneBy(
          door(VisitStatus.nobodyHome, VisitStatus.done),
        ),
        isNull,
      );
    });

    test('should name the number the ✓ had when an undo renumbers', () {
      expect(
        DonationOrigin.leftDoneBy(
          HouseReverted(
            streetId: _lilas,
            replaced: _house(VisitStatus.done),
            house: _house(VisitStatus.toDo, '12bis'),
            stamp: leaAtTwo,
          ),
        ),
        _twelve,
      );
    });

    test('should name a ✓ house turned into a building (#171)', () {
      BuildingLaidOut laidOut(VisitStatus from) => BuildingLaidOut(
        streetId: _lilas,
        before: _house(from),
        stamp: leaAtTwo,
        building: building(topFloor: 1, doors: 2),
      );

      expect(DonationOrigin.leftDoneBy(laidOut(VisitStatus.done)), _twelve);
      for (final from in notDone) {
        expect(
          DonationOrigin.leftDoneBy(laidOut(from)),
          isNull,
          reason: '$from → immeuble',
        );
      }
    });

    test('should name nothing for a building laid out again, its doors '
        '✓ or not', () {
      final doneDoor = Dwelling(label: d('01'), status: VisitStatus.done);
      final before = House(
        number: n('8'),
        building: building(
          topFloor: 0,
          doors: 2,
        ).withDwelling(escA, 0, doneDoor),
      );

      expect(
        DonationOrigin.leftDoneBy(
          BuildingLaidOut(
            streetId: _lilas,
            before: before,
            stamp: leaAtTwo,
            building: building(topFloor: 0, doors: 3),
          ),
        ),
        isNull,
      );
    });

    test('should name nothing for a building turned back into a house', () {
      expect(
        DonationOrigin.leftDoneBy(
          BuildingRemoved(
            streetId: _lilas,
            before: House(
              number: n('8'),
              building: building(topFloor: 0, doors: 2),
            ),
            stamp: leaAtTwo,
            status: VisitStatus.toDo,
          ),
        ),
        isNull,
      );
    });

    test('should name nothing for a change of no status: a house removed '
        'while ✓ keeps its dons', () {
      expect(
        DonationOrigin.leftDoneBy(
          HouseCalendarsCounted(
            streetId: _lilas,
            before: _house(VisitStatus.done),
            stamp: leaAtTwo,
            calendars: calendars(2),
          ),
        ),
        isNull,
      );
      expect(
        DonationOrigin.leftDoneBy(
          ComeBackSet(
            streetId: _lilas,
            before: _house(VisitStatus.done),
            stamp: leaAtTwo,
            comeBack: comeBack('2026-10-24', hour: 18),
          ),
        ),
        isNull,
      );
      expect(
        DonationOrigin.leftDoneBy(
          StreetDeleted(streetId: _lilas, deletion: leaAtTwo),
        ),
        isNull,
      );
      expect(
        DonationOrigin.leftDoneBy(
          NumbersPurged(
            streetId: _lilas,
            purged: [
              RemovedHouse(house: _house(VisitStatus.done), removal: leaAtTwo),
            ],
          ),
        ),
        isNull,
      );
      expect(
        DonationOrigin.leftDoneBy(
          StreetRenamed(
            streetId: _lilas,
            before: streetName('Rue des Lilas'),
            name: streetName('Rue des Tilleuls'),
          ),
        ),
        isNull,
      );
    });
  });

  test('should equal an origin of the same street, number and door only', () {
    final same = DonationOrigin(street: _lilas, number: n('12'));

    expect(_twelve, same);
    expect(_twelve.hashCode, same.hashCode);
    expect(
      _twelve,
      isNot(
        DonationOrigin(street: StreetId('rue-de-la-paix'), number: n('12')),
      ),
    );
    expect(_twelve, isNot(DonationOrigin(street: _lilas, number: n('14'))));
    expect(
      _door51,
      isNot(
        DonationOrigin(
          street: _lilas,
          number: n('8'),
          door: DwellingKey(escA, 5, d('52')),
        ),
      ),
    );
    expect(_door51, isNot(DonationOrigin(street: _lilas, number: n('8'))));
  });

  test('should print its street, number and door', () {
    expect('$_twelve', 'DonationOrigin(rue-des-lilas, 12)');
    expect('$_door51', 'DonationOrigin(rue-des-lilas, 8, A5-51)');
  });
}
