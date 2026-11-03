// The calendars of a house or a door on the Street aggregate (#114, PLAN
// §6.1): how the status keeps or resets them, one more (« + Ajouter un
// don ») and one less (« − »), and their undo.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/calendars.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');

Street _street(List<House> houses) => valueOf(
  Street.create(
    id: _lilas,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: houses,
  ),
);

/// Number 9 with [status], [count] calendars and two tries, last changed
/// by Paul.
Street _nine(VisitStatus status, {int count = 0}) => _street([
  House(
    number: n('9'),
    status: status,
    tries: tries(2),
    calendars: calendars(count),
    lastChange: paulAtThree,
    position: townHallDoor,
  ),
]);

/// Door 01 of the RdC of the building at number 8.
final _door = DwellingKey(escA, 0, d('01'));

/// Number 8 a building whose door 01 has [status], [count] calendars and
/// two tries.
Street _eight(VisitStatus status, {int count = 0}) => _street([
  House(
    number: n('8'),
    comeBack: comeBack('2026-11-07'),
    building: building(topFloor: 0, doors: 2).withDwelling(
      escA,
      0,
      Dwelling(
        label: d('01'),
        status: status,
        tries: tries(2),
        calendars: calendars(count),
        lastChange: paulAtThree,
      ),
    ),
  ),
]);

House _houseOf(Street street) => street.houses.single;

Dwelling _doorOf(Street street) =>
    street.houses.single.building!.dwellingAt(_door)!;

void main() {
  group('House', () {
    test('should take one calendar when it is done without a count', () {
      expect(_houseOf(_nine(VisitStatus.done)).calendars, Calendars.one);
    });

    test('should keep its calendars when it is done', () {
      expect(
        _houseOf(_nine(VisitStatus.done, count: 3)).calendars,
        calendars(3),
      );
    });

    test('should have no calendar when it is not done', () {
      expect(
        _houseOf(_nine(VisitStatus.refused, count: 3)).calendars,
        Calendars.none,
      );
    });

    test('should have no calendar when it is a building', () {
      final house = House(
        number: n('8'),
        status: VisitStatus.done,
        calendars: calendars(3),
        building: building(topFloor: 0, doors: 1),
      );

      expect(house.calendars, Calendars.none);
    });

    test('should differ when the calendars differ', () {
      expect(
        _houseOf(_nine(VisitStatus.done, count: 2)),
        isNot(_houseOf(_nine(VisitStatus.done, count: 3))),
      );
      expect(
        _houseOf(_nine(VisitStatus.done, count: 2)).hashCode,
        isNot(_houseOf(_nine(VisitStatus.done, count: 3)).hashCode),
      );
    });

    test('should print its calendars from two', () {
      expect(
        _houseOf(_nine(VisitStatus.done, count: 2)).toString(),
        contains('×2, 2 calendars'),
      );
    });

    test('should print no calendar when it took one', () {
      expect(
        _houseOf(_nine(VisitStatus.done, count: 1)).toString(),
        isNot(contains('calendar')),
      );
    });
  });

  group('Dwelling', () {
    test('should take one calendar when it is done without a count', () {
      expect(_doorOf(_eight(VisitStatus.done)).calendars, Calendars.one);
    });

    test('should have no calendar when it is not done', () {
      expect(
        _doorOf(_eight(VisitStatus.nobodyHome, count: 3)).calendars,
        Calendars.none,
      );
    });

    test('should differ when the calendars differ', () {
      expect(
        _doorOf(_eight(VisitStatus.done, count: 2)),
        isNot(_doorOf(_eight(VisitStatus.done, count: 3))),
      );
    });

    test('should print its calendars from two', () {
      expect(
        _doorOf(_eight(VisitStatus.done, count: 2)).toString(),
        'Dwelling(01, VisitStatus.done, null, '
        'ChangeStamp(paul, 2026-11-02 15:00:00.000Z), ×2, 2 calendars)',
      );
    });
  });

  group('markHouse', () {
    test('should give one calendar when the house becomes done', () {
      final (marked, _) = valueOf(
        _nine(VisitStatus.toDo)
            .markHouse(n('9'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).calendars, Calendars.one);
    });

    test('should keep the calendars when a done house is done again', () {
      final (marked, _) = valueOf(
        _nine(
          VisitStatus.done,
          count: 3,
        ).markHouse(n('9'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).calendars, calendars(3));
    });

    test('should reset the calendars when the house leaves done', () {
      final (marked, _) = valueOf(
        _nine(
          VisitStatus.done,
          count: 3,
        ).markHouse(n('9'), VisitStatus.refused, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).calendars, Calendars.none);
    });

    test('should start again at one when the house is done again', () {
      final (left, _) = valueOf(
        _nine(
          VisitStatus.done,
          count: 3,
        ).markHouse(n('9'), VisitStatus.toDo, by: lea, at: twoPm),
      );
      final (back, _) = valueOf(
        left.markHouse(n('9'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(_houseOf(back).calendars, Calendars.one);
    });

    test('should reset the calendars when nobody is home again', () {
      final street = _nine(VisitStatus.done, count: 3);
      final (marked, _) = valueOf(
        street.markHouse(n('9'), VisitStatus.nobodyHome, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).calendars, Calendars.none);
    });
  });

  group('markDwelling', () {
    test('should give one calendar when the door becomes done', () {
      final (marked, _) = valueOf(
        _eight(VisitStatus.toDo)
            .markDwelling(n('8'), _door, VisitStatus.done, by: lea, at: twoPm),
      );

      expect(_doorOf(marked).calendars, Calendars.one);
    });

    test('should keep the calendars when a done door is done again', () {
      final (marked, _) = valueOf(
        _eight(
          VisitStatus.done,
          count: 3,
        ).markDwelling(n('8'), _door, VisitStatus.done, by: lea, at: twoPm),
      );

      expect(_doorOf(marked).calendars, calendars(3));
    });

    test('should reset the calendars when the door leaves done', () {
      final (marked, _) = valueOf(
        _eight(
          VisitStatus.done,
          count: 3,
        ).markDwelling(n('8'), _door, VisitStatus.comeBack, by: lea, at: twoPm),
      );

      expect(_doorOf(marked).calendars, Calendars.none);
    });
  });

  group('renameDoor', () {
    test('should keep the calendars when the door is renamed', () {
      final (renamed, _) = valueOf(
        _eight(
          VisitStatus.done,
          count: 3,
        ).renameDoor(n('8'), _door, d('A'), by: lea, at: twoPm),
      );

      expect(
        renamed.houses.single.building!
            .dwellingAt(DwellingKey(escA, 0, d('A')))!
            .calendars,
        calendars(3),
      );
    });
  });

  group('renameNumber', () {
    test('should keep the calendars when the house is renumbered', () {
      final (renamed, _) = valueOf(
        _nine(
          VisitStatus.done,
          count: 3,
        ).renameNumber(n('9'), n('9bis'), by: lea, at: twoPm),
      );

      expect(renamed.houses.single.calendars, calendars(3));
    });
  });

  group('addCalendar on a house', () {
    test('should add one calendar and stamp the house', () {
      final street = _nine(VisitStatus.done, count: 2);

      final (counted, change) = valueOf(
        street.addCalendar(n('9'), by: lea, at: twoPm),
      );

      expect(
        _houseOf(counted),
        House(
          number: n('9'),
          status: VisitStatus.done,
          tries: tries(2),
          calendars: calendars(3),
          lastChange: leaAtTwo,
          position: townHallDoor,
        ),
      );
      expect(
        change,
        HouseCalendarsCounted(
          streetId: _lilas,
          before: _houseOf(street),
          stamp: leaAtTwo,
          calendars: calendars(3),
        ),
      );
    });

    test('should add the last calendar when one below the limit', () {
      final (counted, _) = valueOf(
        _nine(
          VisitStatus.done,
          count: 98,
        ).addCalendar(n('9'), by: lea, at: twoPm),
      );

      expect(_houseOf(counted).calendars, calendars(99));
    });

    test('should refuse when the house has the most calendars', () {
      expect(
        failureOf(
          _nine(
            VisitStatus.done,
            count: 99,
          ).addCalendar(n('9'), by: lea, at: twoPm),
        ),
        CalendarChangeFailure.tooMany,
      );
    });

    for (final status in [
      VisitStatus.toDo,
      VisitStatus.refused,
      VisitStatus.nobodyHome,
      VisitStatus.comeBack,
    ]) {
      test('should refuse when the house is $status', () {
        expect(
          failureOf(_nine(status).addCalendar(n('9'), by: lea, at: twoPm)),
          CalendarChangeFailure.notDone,
        );
      });
    }

    test('should refuse when the street has no such house', () {
      expect(
        failureOf(
          _nine(VisitStatus.done).addCalendar(n('11'), by: lea, at: twoPm),
        ),
        CalendarChangeFailure.unknownHouse,
      );
    });

    test('should refuse when the house is a building', () {
      expect(
        failureOf(
          _eight(VisitStatus.done).addCalendar(n('8'), by: lea, at: twoPm),
        ),
        CalendarChangeFailure.houseIsBuilding,
      );
    });

    test('should put the house back with its calendars when undone', () {
      final street = _nine(VisitStatus.done, count: 2);
      final (counted, change) = valueOf(
        street.addCalendar(n('9'), by: lea, at: twoPm),
      );

      final (undone, _) = valueOf(counted.undo(change));

      expect(_houseOf(undone), _houseOf(street));
    });
  });

  group('removeCalendar on a house', () {
    test('should take one calendar away and stamp the house', () {
      final street = _nine(VisitStatus.done, count: 3);

      final (counted, change) = valueOf(
        street.removeCalendar(n('9'), by: lea, at: twoPm),
      );

      expect(_houseOf(counted).calendars, calendars(2));
      expect(_houseOf(counted).lastChange, leaAtTwo);
      expect(
        change,
        HouseCalendarsCounted(
          streetId: _lilas,
          before: _houseOf(street),
          stamp: leaAtTwo,
          calendars: calendars(2),
        ),
      );
    });

    test('should leave one calendar when there were two', () {
      final (counted, _) = valueOf(
        _nine(
          VisitStatus.done,
          count: 2,
        ).removeCalendar(n('9'), by: lea, at: twoPm),
      );

      expect(_houseOf(counted).calendars, Calendars.one);
    });

    test('should refuse when the house took one calendar', () {
      expect(
        failureOf(
          _nine(
            VisitStatus.done,
            count: 1,
          ).removeCalendar(n('9'), by: lea, at: twoPm),
        ),
        CalendarChangeFailure.lastCalendar,
      );
    });

    test('should refuse when the house is not done', () {
      expect(
        failureOf(
          _nine(VisitStatus.toDo).removeCalendar(n('9'), by: lea, at: twoPm),
        ),
        CalendarChangeFailure.notDone,
      );
    });
  });

  group('addCalendar on a door', () {
    test('should add one calendar and stamp only the door', () {
      final street = _eight(VisitStatus.done, count: 2);

      final (counted, change) = valueOf(
        street.addCalendar(n('8'), door: _door, by: lea, at: twoPm),
      );

      expect(
        _doorOf(counted),
        Dwelling(
          label: d('01'),
          status: VisitStatus.done,
          tries: tries(2),
          calendars: calendars(3),
          lastChange: leaAtTwo,
        ),
      );
      expect(_houseOf(counted).lastChange, _houseOf(street).lastChange);
      expect(_houseOf(counted).comeBack, comeBack('2026-11-07'));
      expect(
        change,
        DwellingCalendarsCounted(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 0,
          before: _doorOf(street),
          stamp: leaAtTwo,
          calendars: calendars(3),
        ),
      );
    });

    test('should refuse when the door has the most calendars', () {
      expect(
        failureOf(
          _eight(
            VisitStatus.done,
            count: 99,
          ).addCalendar(n('8'), door: _door, by: lea, at: twoPm),
        ),
        CalendarChangeFailure.tooMany,
      );
    });

    test('should refuse when the door is not done', () {
      expect(
        failureOf(
          _eight(VisitStatus.refused)
              .addCalendar(n('8'), door: _door, by: lea, at: twoPm),
        ),
        CalendarChangeFailure.notDone,
      );
    });

    test('should refuse when the house is not a building', () {
      expect(
        failureOf(
          _nine(VisitStatus.done)
              .addCalendar(n('9'), door: _door, by: lea, at: twoPm),
        ),
        CalendarChangeFailure.notABuilding,
      );
    });

    test('should refuse when the building has no such door', () {
      expect(
        failureOf(
          _eight(VisitStatus.done).addCalendar(
            n('8'),
            door: DwellingKey(escA, 0, d('09')),
            by: lea,
            at: twoPm,
          ),
        ),
        CalendarChangeFailure.unknownDwelling,
      );
    });

    test('should refuse when the street has no such house', () {
      expect(
        failureOf(
          _eight(VisitStatus.done)
              .addCalendar(n('10'), door: _door, by: lea, at: twoPm),
        ),
        CalendarChangeFailure.unknownHouse,
      );
    });

    test('should put the door back with its calendars when undone', () {
      final street = _eight(VisitStatus.done, count: 2);
      final (counted, change) = valueOf(
        street.addCalendar(n('8'), door: _door, by: lea, at: twoPm),
      );

      final (undone, _) = valueOf(counted.undo(change));

      expect(_doorOf(undone), _doorOf(street));
    });
  });

  group('removeCalendar on a door', () {
    test('should take one calendar away from the door', () {
      final (counted, change) = valueOf(
        _eight(
          VisitStatus.done,
          count: 2,
        ).removeCalendar(n('8'), door: _door, by: lea, at: twoPm),
      );

      expect(_doorOf(counted).calendars, Calendars.one);
      expect((change as DwellingCalendarsCounted).calendars, Calendars.one);
    });

    test('should refuse when the door took one calendar', () {
      expect(
        failureOf(
          _eight(
            VisitStatus.done,
            count: 1,
          ).removeCalendar(n('8'), door: _door, by: lea, at: twoPm),
        ),
        CalendarChangeFailure.lastCalendar,
      );
    });
  });

  group('HouseCalendarsCounted', () {
    HouseCalendarsCounted change({ChangeStamp? stamp, int count = 3}) =>
        HouseCalendarsCounted(
          streetId: _lilas,
          before: _houseOf(_nine(VisitStatus.done, count: 2)),
          stamp: stamp ?? leaAtTwo,
          calendars: calendars(count),
        );

    test('should be equal when every field is equal', () {
      expect(change(), change());
      expect(change().hashCode, change().hashCode);
    });

    test('should differ when the calendars differ', () {
      expect(change(), isNot(change(count: 4)));
    });

    test('should differ when the stamps differ', () {
      expect(change(), isNot(change(stamp: paulAtThree)));
    });

    test('should show the house and the calendars when printed', () {
      expect(
        change().toString(),
        'HouseCalendarsCounted(rue-des-lilas, 9, 3, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('DwellingCalendarsCounted', () {
    DwellingCalendarsCounted change({int count = 2, int? level = 0}) =>
        DwellingCalendarsCounted(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: level,
          before: _doorOf(_eight(VisitStatus.done)),
          stamp: leaAtTwo,
          calendars: calendars(count),
        );

    test('should be equal when every field is equal', () {
      expect(change(), change());
      expect(change().hashCode, change().hashCode);
    });

    test('should differ when the calendars differ', () {
      expect(change(), isNot(change(count: 3)));
    });

    test('should differ when the floors differ', () {
      expect(change(), isNot(change(level: 1)));
    });

    test('should show the door and the calendars when printed', () {
      expect(
        change().toString(),
        'DwellingCalendarsCounted(rue-des-lilas, 8, A0-01, 2, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });
}
