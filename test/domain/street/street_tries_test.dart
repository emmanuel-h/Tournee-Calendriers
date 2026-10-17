// The tries with nobody home on the Street aggregate (#80, PLAN §6.1): how
// each command keeps or resets them, and « Repassé, toujours personne »
// (markNobodyHomeAgain) on a house and on a door.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/nobody_home_tries.dart';
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

/// Number 7 with [status] and [count] tries, last changed by Paul.
Street _seven(VisitStatus status, {int count = 0}) => _street([
  House(
    number: n('7'),
    status: status,
    tries: tries(count),
    lastChange: paulAtThree,
    position: townHallDoor,
  ),
]);

/// Door 01 of the RdC of the building at number 8.
final _door = DwellingKey(escA, 0, d('01'));

/// Number 8 a building whose door 01 has [status] and [count] tries.
Street _eight(VisitStatus status, {int count = 0}) => _street([
  House(
    number: n('8'),
    building: building(topFloor: 0, doors: 2).withDwelling(
      escA,
      0,
      Dwelling(
        label: d('01'),
        status: status,
        tries: tries(count),
        lastChange: paulAtThree,
      ),
    ),
  ),
]);

House _houseOf(Street street) => street.houses.single;

Dwelling _doorOf(Street street) =>
    street.houses.single.building!.dwellingAt(_door)!;

void main() {
  group('markHouse', () {
    test('should count the first try when a house becomes nobody home', () {
      final (marked, _) = valueOf(
        _seven(VisitStatus.done)
            .markHouse(n('7'), VisitStatus.nobodyHome, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).tries, tries(1));
    });

    test('should keep the tries when nobody home becomes come back', () {
      final (marked, _) = valueOf(
        _seven(
          VisitStatus.nobodyHome,
          count: 3,
        ).markHouse(n('7'), VisitStatus.comeBack, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).tries, tries(3));
    });

    test('should add no try when come back becomes nobody home again', () {
      final (marked, _) = valueOf(
        _seven(
          VisitStatus.comeBack,
          count: 3,
        ).markHouse(n('7'), VisitStatus.nobodyHome, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).tries, tries(3));
    });

    test('should keep the tries when the house becomes done', () {
      final (marked, _) = valueOf(
        _seven(
          VisitStatus.nobodyHome,
          count: 2,
        ).markHouse(n('7'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).tries, tries(2));
    });

    test('should reset the tries when the house is to do again', () {
      final (marked, _) = valueOf(
        _seven(
          VisitStatus.comeBack,
          count: 2,
        ).markHouse(n('7'), VisitStatus.toDo, by: lea, at: twoPm),
      );

      expect(_houseOf(marked).tries, NobodyHomeTries.none);
    });
  });

  group('setComeBack', () {
    test('should keep the tries when the hint is set', () {
      final (changed, _) = valueOf(
        _seven(
          VisitStatus.comeBack,
          count: 2,
        ).setComeBack(n('7'), comeBack('après 19h'), by: lea, at: twoPm),
      );

      expect(_houseOf(changed).tries, tries(2));
    });
  });

  group('renameNumber', () {
    test('should keep the tries when the house is renumbered', () {
      final (renamed, _) = valueOf(
        _seven(
          VisitStatus.nobodyHome,
          count: 2,
        ).renameNumber(n('7'), n('7bis'), by: lea, at: twoPm),
      );

      expect(_houseOf(renamed).tries, tries(2));
    });
  });

  group('markNobodyHomeAgain', () {
    test('should add a try and stamp the house when nobody is home again', () {
      final street = _seven(VisitStatus.nobodyHome, count: 2);

      final (marked, change) = valueOf(
        street.markNobodyHomeAgain(n('7'), by: lea, at: twoPm),
      );

      expect(
        _houseOf(marked),
        House(
          number: n('7'),
          status: VisitStatus.nobodyHome,
          tries: tries(3),
          lastChange: leaAtTwo,
          position: townHallDoor,
        ),
      );
      expect(
        change,
        HouseNobodyHomeAgain(
          streetId: _lilas,
          before: _houseOf(street),
          stamp: leaAtTwo,
          tries: tries(3),
        ),
      );
    });

    test('should make the house nobody home when it was come back', () {
      final street = _street([
        House(
          number: n('7'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('après 19h'),
          tries: tries(1),
        ),
      ]);

      final (marked, _) = valueOf(
        street.markNobodyHomeAgain(n('7'), by: lea, at: twoPm),
      );

      expect(_houseOf(marked).status, VisitStatus.nobodyHome);
      expect(_houseOf(marked).comeBack, isNull);
      expect(_houseOf(marked).tries, tries(2));
    });

    test('should count the first try when come back had none', () {
      final (marked, change) = valueOf(
        _seven(VisitStatus.comeBack)
            .markNobodyHomeAgain(n('7'), by: lea, at: twoPm),
      );

      expect(_houseOf(marked).tries, tries(1));
      expect(change.tries, tries(1));
    });

    for (final status in [VisitStatus.toDo, VisitStatus.done]) {
      test('should refuse when the house is $status', () {
        expect(
          failureOf(
            _seven(status).markNobodyHomeAgain(n('7'), by: lea, at: twoPm),
          ),
          HouseChangeFailure.notToVisitAgain,
        );
      });
    }

    test('should refuse when the street has no such house', () {
      expect(
        failureOf(
          _seven(VisitStatus.nobodyHome)
              .markNobodyHomeAgain(n('9'), by: lea, at: twoPm),
        ),
        HouseChangeFailure.unknownHouse,
      );
    });

    test('should refuse when the house is a building', () {
      expect(
        failureOf(
          _eight(VisitStatus.nobodyHome)
              .markNobodyHomeAgain(n('8'), by: lea, at: twoPm),
        ),
        HouseChangeFailure.houseIsBuilding,
      );
    });

    test('should put the house back with its tries when undone', () {
      final street = _seven(VisitStatus.nobodyHome, count: 2);
      final (marked, change) = valueOf(
        street.markNobodyHomeAgain(n('7'), by: lea, at: twoPm),
      );

      final (undone, _) = valueOf(marked.undo(change));

      expect(_houseOf(undone), _houseOf(street));
      expect(_houseOf(undone).tries, tries(2));
    });
  });

  group('markDwelling', () {
    test('should count the first try when a door becomes nobody home', () {
      final (marked, _) = valueOf(
        _eight(VisitStatus.done).markDwelling(
          n('8'),
          _door,
          VisitStatus.nobodyHome,
          by: lea,
          at: twoPm,
        ),
      );

      expect(_doorOf(marked).tries, tries(1));
    });

    test('should keep the tries when the door becomes done', () {
      final (marked, _) = valueOf(
        _eight(
          VisitStatus.nobodyHome,
          count: 3,
        ).markDwelling(n('8'), _door, VisitStatus.done, by: lea, at: twoPm),
      );

      expect(_doorOf(marked).tries, tries(3));
    });

    test('should reset the tries when the door is to do again', () {
      final (marked, _) = valueOf(
        _eight(
          VisitStatus.comeBack,
          count: 3,
        ).markDwelling(n('8'), _door, VisitStatus.toDo, by: lea, at: twoPm),
      );

      expect(_doorOf(marked).tries, NobodyHomeTries.none);
    });
  });

  group('setDwellingComeBack', () {
    test('should keep the tries when the hint is set', () {
      final (changed, _) = valueOf(
        _eight(VisitStatus.comeBack, count: 2).setDwellingComeBack(
          n('8'),
          _door,
          comeBack('samedi'),
          by: lea,
          at: twoPm,
        ),
      );

      expect(_doorOf(changed).tries, tries(2));
    });
  });

  group('renameDoor', () {
    test('should keep the tries when the door is renamed', () {
      final (renamed, _) = valueOf(
        _eight(
          VisitStatus.nobodyHome,
          count: 2,
        ).renameDoor(n('8'), _door, d('Gauche'), by: lea, at: twoPm),
      );

      final door = renamed.houses.single.building!.dwellingAt(
        DwellingKey(escA, 0, d('Gauche')),
      );
      expect(door!.tries, tries(2));
    });
  });

  group('markDwellingNobodyHomeAgain', () {
    test('should add a try and stamp only the door', () {
      final street = _eight(VisitStatus.nobodyHome, count: 1);

      final (marked, change) = valueOf(
        street.markDwellingNobodyHomeAgain(n('8'), _door, by: lea, at: twoPm),
      );

      expect(
        _doorOf(marked),
        Dwelling(
          label: d('01'),
          status: VisitStatus.nobodyHome,
          tries: tries(2),
          lastChange: leaAtTwo,
        ),
      );
      expect(_houseOf(marked).lastChange, isNull);
      expect(
        change,
        DwellingNobodyHomeAgain(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 0,
          before: _doorOf(street),
          stamp: leaAtTwo,
          tries: tries(2),
        ),
      );
    });

    test('should make the door nobody home when it was come back', () {
      final (marked, _) = valueOf(
        _eight(
          VisitStatus.comeBack,
          count: 2,
        ).markDwellingNobodyHomeAgain(n('8'), _door, by: lea, at: twoPm),
      );

      expect(_doorOf(marked).status, VisitStatus.nobodyHome);
      expect(_doorOf(marked).comeBack, isNull);
      expect(_doorOf(marked).tries, tries(3));
    });

    for (final status in [VisitStatus.toDo, VisitStatus.done]) {
      test('should refuse when the door is $status', () {
        expect(
          failureOf(
            _eight(status)
                .markDwellingNobodyHomeAgain(n('8'), _door, by: lea, at: twoPm),
          ),
          DwellingChangeFailure.notToVisitAgain,
        );
      });
    }

    test('should refuse when the building has no such door', () {
      expect(
        failureOf(
          _eight(VisitStatus.nobodyHome).markDwellingNobodyHomeAgain(
            n('8'),
            DwellingKey(escA, 3, d('31')),
            by: lea,
            at: twoPm,
          ),
        ),
        DwellingChangeFailure.unknownDwelling,
      );
    });

    test('should put the door back with its tries when undone', () {
      final street = _eight(VisitStatus.nobodyHome, count: 4);
      final (marked, change) = valueOf(
        street.markDwellingNobodyHomeAgain(n('8'), _door, by: lea, at: twoPm),
      );

      final (undone, _) = valueOf(marked.undo(change));

      expect(_doorOf(undone), _doorOf(street));
    });
  });

  group('HouseNobodyHomeAgain', () {
    HouseNobodyHomeAgain change({
      StreetId? streetId,
      ChangeStamp? stamp,
      int count = 3,
    }) => HouseNobodyHomeAgain(
      streetId: streetId ?? _lilas,
      before: _houseOf(_seven(VisitStatus.nobodyHome, count: 2)),
      stamp: stamp ?? leaAtTwo,
      tries: tries(count),
    );

    test('should be equal when every field is equal', () {
      expect(change(), change());
      expect(change().hashCode, change().hashCode);
    });

    test('should differ when the tries differ', () {
      expect(change(), isNot(change(count: 4)));
    });

    test('should differ when the stamps differ', () {
      expect(change(), isNot(change(stamp: paulAtThree)));
    });

    test('should name the house it changed', () {
      expect(change().number, n('7'));
    });

    test('should show the house and the tries when printed', () {
      expect(
        change().toString(),
        'HouseNobodyHomeAgain(rue-des-lilas, 7, ×3, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('DwellingNobodyHomeAgain', () {
    DwellingNobodyHomeAgain change({int count = 2, int? level = 0}) =>
        DwellingNobodyHomeAgain(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: level,
          before: _doorOf(_eight(VisitStatus.nobodyHome)),
          stamp: leaAtTwo,
          tries: tries(count),
        );

    test('should be equal when every field is equal', () {
      expect(change(), change());
      expect(change().hashCode, change().hashCode);
    });

    test('should differ when the tries differ', () {
      expect(change(), isNot(change(count: 3)));
    });

    test('should differ when the floors differ', () {
      expect(change(), isNot(change(level: 1)));
    });

    test('should show the door and the tries when printed', () {
      expect(
        change().toString(),
        'DwellingNobodyHomeAgain(rue-des-lilas, 8, A0-01, ×2, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });
}
