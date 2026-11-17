// A street carried over to the next campaign (PLAN §5.10): the setup is
// kept, everything marked starts again, the Corbeille stays behind.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');
final _banId = BanStreetId('69264_0420');
final _shape = StreetShape([
  [townHallDoor, northDoor],
]);
final _part = part(odd: range(1, 21), even: SidePart.all);

/// The layout the tests use: two staircases, RdC and 1er, two doors a
/// floor labelled `1A`, then door `1B` of staircase A removed and door
/// `0A` of staircase B renamed `Gardien`, so the layout is not a fresh
/// plan's.
Building _layout() {
  final laidOut = building(
    staircases: 2,
    topFloor: 1,
    doors: 2,
    style: DoorLabelStyle.floorAndLetter,
  );
  final withoutDoor = valueOf(
    laidOut.withoutDoor(DwellingKey(escA, 1, d('1B'))),
  );
  return valueOf(
    withoutDoor.withDoorRenamed(DwellingKey(escB, 0, d('0A')), d('Gardien')),
  );
}

/// [_layout] with a door of each status, as during a campaign.
Building _markedLayout() => _layout()
    .withDwelling(
      escA,
      1,
      Dwelling(
        label: d('1A'),
        status: VisitStatus.done,
        lastChange: leaAtTwo,
        calendars: calendars(3),
      ),
    )
    .withDwelling(
      escA,
      0,
      Dwelling(
        label: d('0A'),
        status: VisitStatus.nobodyHome,
        lastChange: paulAtThree,
        tries: tries(2),
      ),
    )
    .withDwelling(
      escB,
      0,
      Dwelling(
        label: d('Gardien'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-07', hour: 19),
        lastChange: leaAtTwo,
      ),
    )
    .withDwelling(
      escB,
      1,
      Dwelling(label: d('1B'), status: VisitStatus.refused),
    );

/// Rue des Lilas at the end of a campaign: a house of each status, a
/// building with marked doors and its own « repasser », a number in the
/// Corbeille; deleted by Paul when [deleted].
Street _endOfCampaign({bool deleted = false}) => valueOf(
  Street.create(
    id: _lilas,
    name: 'Rue des Lilas',
    commune: villefranche,
    banId: _banId,
    shape: _shape,
    part: _part,
    houses: [
      House(
        number: n('1'),
        status: VisitStatus.done,
        lastChange: leaAtTwo,
        position: townHallDoor,
        calendars: calendars(2),
      ),
      House(
        number: n('2'),
        status: VisitStatus.nobodyHome,
        lastChange: paulAtThree,
        position: northDoor,
        tries: tries(3),
      ),
      House(
        number: n('3bis'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-08'),
        lastChange: leaAtTwo,
      ),
      House(
        number: n('4'),
        building: _markedLayout(),
        comeBack: comeBack('2026-11-09', hour: 18),
        lastChange: paulAtThree,
        position: townHallDoor,
      ),
    ],
    removedHouses: [
      RemovedHouse(
        house: House(number: n('5'), status: VisitStatus.done),
        removal: leaAtTwo,
      ),
    ],
    deletion: deleted ? ChangeStamp(by: paul, at: threePm) : null,
  ),
);

void main() {
  group('forNextCampaign', () {
    test('should keep the street setup when a new campaign starts', () {
      final next = _endOfCampaign().forNextCampaign()!;

      expect(next.id, _lilas);
      expect(next.name, streetName('Rue des Lilas'));
      expect(next.commune, villefranche);
      expect(next.banId, _banId);
      expect(next.shape, _shape);
      expect(next.part, _part);
      expect(next.isDeleted, isFalse);
    });

    test('should keep each number and its position with no mark when a new '
        'campaign starts', () {
      final next = _endOfCampaign().forNextCampaign()!;

      expect(next.houses, [
        House(number: n('1'), position: townHallDoor),
        House(number: n('2'), position: northDoor),
        House(number: n('3bis')),
        House(number: n('4'), building: _layout(), position: townHallDoor),
      ]);
    });

    test('should leave the Corbeille behind when a new campaign starts', () {
      expect(_endOfCampaign().forNextCampaign()!.removedHouses, isEmpty);
    });

    test('should not carry the street over when it is in the Corbeille', () {
      expect(_endOfCampaign(deleted: true).forNextCampaign(), isNull);
    });
  });

  group('House.unmarked', () {
    test('should reset every mark of a single house and keep its number and '
        'position', () {
      final done = House(
        number: n('12bis'),
        status: VisitStatus.done,
        lastChange: leaAtTwo,
        position: townHallDoor,
        calendars: calendars(4),
      );

      final unmarked = done.unmarked;

      expect(unmarked.number, n('12bis'));
      expect(unmarked.position, townHallDoor);
      expect(unmarked.status, VisitStatus.toDo);
      expect(unmarked.calendars.count, 0);
      expect(unmarked.lastChange, isNull);
      expect(unmarked.building, isNull);
    });

    test('should reset the tries of a house where nobody was home', () {
      final nobodyHome = House(
        number: n('2'),
        status: VisitStatus.nobodyHome,
        tries: tries(5),
      );

      expect(nobodyHome.unmarked.tries.count, 0);
    });

    test('should reset the « repasser » of a house', () {
      final comeBackLater = House(
        number: n('3'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-11-07', hour: 19),
      );

      expect(comeBackLater.unmarked.comeBack, isNull);
    });

    test('should reset the building own « repasser » and keep its layout', () {
      final house = House(
        number: n('4'),
        building: _markedLayout(),
        comeBack: comeBack('2026-11-09'),
        lastChange: paulAtThree,
      );

      final unmarked = house.unmarked;

      expect(unmarked.comeBack, isNull);
      expect(unmarked.lastChange, isNull);
      expect(unmarked.building, _layout());
    });
  });

  group('Building.unmarked', () {
    test('should keep the style, staircases, floors and doors when every '
        'door is reset', () {
      final unmarked = _markedLayout().unmarked;

      expect(unmarked, _layout());
      expect(unmarked.style, DoorLabelStyle.floorAndLetter);
      expect(unmarked.hasMarks, isFalse);
    });

    test('should keep an emptied floor when every door is reset', () {
      final emptied = valueOf(
        building(
          topFloor: 1,
          doors: 1,
        ).withoutDoor(DwellingKey(escA, 1, d('11'))),
      );

      final floors = emptied.unmarked.staircases.single.floors;

      expect([for (final floor in floors) floor.level], [1, 0]);
      expect(floors.first.dwellings, isEmpty);
    });

    test('should reset the tries, calendars and last change of every door', () {
      final doors = _markedLayout().unmarked.staircases.expand(
        (staircase) => staircase.dwellings,
      );

      for (final door in doors) {
        expect(door.status, VisitStatus.toDo, reason: door.label.text);
        expect(door.comeBack, isNull, reason: door.label.text);
        expect(door.tries.count, 0, reason: door.label.text);
        expect(door.calendars.count, 0, reason: door.label.text);
        expect(door.lastChange, isNull, reason: door.label.text);
      }
    });
  });
}
