import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

// Moving the phone's streets into a tournée (PLAN §5.0): every stamp names
// the member who moves them, at the time it had.
void main() {
  // The id the phone made for itself in M1: not a member of any tournée.
  final phoneId = MemberId('phone42');
  final manu = MemberId('manu');
  ChangeStamp phoneAt(DateTime at) => ChangeStamp(by: phoneId, at: at);
  final manuAtTwo = ChangeStamp(by: manu, at: twoPm);
  final manuAtThree = ChangeStamp(by: manu, at: threePm);

  final five = House(
    number: n('5'),
    status: VisitStatus.comeBack,
    comeBack: comeBack('après 19h'),
    lastChange: phoneAt(twoPm),
    position: townHallDoor,
  );
  final seven = House(number: n('7'));
  final eightDoors = building(topFloor: 1, doors: 2)
      .withDwelling(
        escA,
        0,
        Dwelling(
          label: d('01'),
          status: VisitStatus.done,
          lastChange: phoneAt(threePm),
        ),
      )
      .withDwelling(
        escA,
        1,
        Dwelling(
          label: d('12'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('sonner fort'),
          lastChange: phoneAt(twoPm),
        ),
      );
  final eight = House(
    number: n('8'),
    comeBack: comeBack('digicode'),
    lastChange: phoneAt(threePm),
    building: eightDoors,
    position: northDoor,
  );
  final removedTen = RemovedHouse(
    house: House(
      number: n('10'),
      status: VisitStatus.done,
      lastChange: phoneAt(twoPm),
    ),
    removal: phoneAt(threePm),
  );
  final street = valueOf(
    Street.create(
      id: StreetId('lilas'),
      name: 'Rue des Lilas',
      commune: villefranche,
      banId: BanStreetId('69264_0420'),
      houses: [five, seven, eight],
      removedHouses: [removedTen],
    ),
  );

  test('should stamp a marked house with the member, at its time', () {
    final moved = street.restampedBy(manu);

    final house = moved.houseAt(n('5'))!;
    expect(house.lastChange, manuAtTwo);
    expect(house.status, VisitStatus.comeBack);
    expect(house.comeBack, comeBack('après 19h'));
    expect(house.position, townHallDoor);
  });

  test('should leave a house nobody changed without stamp', () {
    final moved = street.restampedBy(manu);

    expect(moved.houseAt(n('7')), seven);
  });

  test('should stamp a building and each of its doors, at their times', () {
    final moved = street.restampedBy(manu);

    final house = moved.houseAt(n('8'))!;
    expect(house.lastChange, manuAtThree);
    expect(house.comeBack, comeBack('digicode'));
    expect(house.position, northDoor);
    final doors = house.building!;
    expect(doors.style, eightDoors.style);
    expect(
      doors.dwellingAt(DwellingKey(escA, 0, d('01')))!.lastChange,
      manuAtThree,
    );
    expect(
      doors.dwellingAt(DwellingKey(escA, 0, d('01')))!.status,
      VisitStatus.done,
    );
    expect(
      doors.dwellingAt(DwellingKey(escA, 1, d('12')))!.lastChange,
      manuAtTwo,
    );
    expect(
      doors.dwellingAt(DwellingKey(escA, 1, d('12')))!.status,
      VisitStatus.comeBack,
    );
    expect(
      doors.dwellingAt(DwellingKey(escA, 1, d('12')))!.comeBack,
      comeBack('sonner fort'),
    );
    // A door nobody marked keeps no stamp.
    expect(doors.dwellingAt(DwellingKey(escA, 1, d('11')))!.lastChange, isNull);
    expect(doors.progress, eightDoors.progress);
  });

  test('should keep the layout of a building, floor by floor', () {
    final moved = street.restampedBy(manu);

    final doors = moved.houseAt(n('8'))!.building!;
    expect(
      [
        for (final staircase in doors.staircases)
          for (final floor in staircase.floors)
            // A list, not a record: `expect` compares lists item by item.
            [
              staircase.name,
              floor.level,
              ...[for (final door in floor.dwellings) door.label],
            ],
      ],
      [
        [escA, 1, d('11'), d('12')],
        [escA, 0, d('01'), d('02')],
      ],
    );
  });

  test('should stamp a removed number and its removal, at their times', () {
    final moved = street.restampedBy(manu);

    expect(moved.removedHouses, [
      RemovedHouse(
        house: House(
          number: n('10'),
          status: VisitStatus.done,
          lastChange: manuAtTwo,
        ),
        removal: manuAtThree,
      ),
    ]);
  });

  test('should keep the street itself as it is', () {
    final moved = street.restampedBy(manu);

    expect(moved.id, StreetId('lilas'));
    expect(moved.name, streetName('Rue des Lilas'));
    expect(moved.commune, villefranche);
    expect(moved.banId, BanStreetId('69264_0420'));
    expect(
      [for (final house in moved.houses) house.number],
      [n('5'), n('7'), n('8')],
    );
    expect(moved.deletion, isNull);
  });

  test('should stamp the deletion of a street in the Corbeille', () {
    final (deleted, _) = street.delete(by: phoneId, at: twoPm);

    expect(deleted.restampedBy(manu).deletion, manuAtTwo);
  });

  test('should change nothing but the stamps when they name the member', () {
    final mine = street.restampedBy(manu);
    final again = mine.restampedBy(manu);

    // A street is an aggregate, equal by identity: compare its parts.
    expect(again.houses, mine.houses);
    expect(again.removedHouses, mine.removedHouses);
    expect(mine.houses, isNot(street.houses));
  });

  test('should stamp a building without changing its derived status', () {
    final moved = street.restampedBy(manu);

    expect(moved.houseAt(n('8'))!.building!.status, eightDoors.status);
    expect(moved.progress, street.progress);
  });

  test('should be unchanged when a building has no stamp at all', () {
    final plain = Building.laidOut(plan(topFloor: 0, doors: 1));

    expect(plain.restampedBy(manu), plain);
  });
}
