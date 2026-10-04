// The building commands of the Street aggregate (PLAN §5.7). The commands
// on single houses are in street_test.dart.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
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

/// Number 6 a single house, number 8 the two-door building RdC 01 02 (01
/// done), number 10 a single house with a note.
final _six = House(number: n('6'), status: VisitStatus.nobodyHome);
final _eightDoors = building(topFloor: 0, doors: 2).withDwelling(
  escA,
  0,
  Dwelling(label: d('01'), status: VisitStatus.done, lastChange: paulAtThree),
);
final _eight = House(
  number: n('8'),
  comeBack: comeBack('gardien'),
  note: note('digicode'),
  lastChange: paulAtThree,
  building: _eightDoors,
);
final _street8 = _street([_six, _eight]);

/// Door [label] of the RdC of staircase A.
DwellingKey _a(String label) => DwellingKey(escA, 0, d(label));

void main() {
  group('describeBuilding', () {
    test('should turn a single house into the planned building', () {
      final street = _street([
        House(
          number: n('8'),
          status: VisitStatus.nobodyHome,
          comeBack: comeBack('après 19h'),
          note: note('digicode'),
        ),
      ]);

      final (described, change) = valueOf(
        street.describeBuilding(n('8'), plan(), by: lea, at: twoPm),
      );

      expect(
        described.houses.single,
        House(
          number: n('8'),
          comeBack: comeBack('après 19h'),
          note: note('digicode'),
          lastChange: leaAtTwo,
          building: building(),
        ),
      );
      expect(described.houses.single.status, VisitStatus.toDo);
      expect(
        change,
        BuildingLaidOut(
          streetId: _lilas,
          before: street.houses.single,
          stamp: leaAtTwo,
          building: building(),
        ),
      );
    });

    test('should make a done house a building that is to do', () {
      final street = _street([House(number: n('8'), status: VisitStatus.done)]);

      final (described, _) = valueOf(
        street.describeBuilding(n('8'), plan(), by: lea, at: twoPm),
      );

      expect(described.houses.single.status, VisitStatus.toDo);
      expect(described.progress.total, 24);
      expect(described.progress.done, 0);
    });

    test('should keep the doors whose label survives a new layout', () {
      // Three doors on the RdC now: 01 keeps its done mark, 03 is new.
      final (described, change) = valueOf(
        _street8.describeBuilding(
          n('8'),
          plan(topFloor: 0, doors: 3),
          by: lea,
          at: twoPm,
        ),
      );
      final newBuilding = described.houses[1].building!;

      expect(
        newBuilding.dwellingAt(_a('01')),
        _eightDoors.dwellingAt(_a('01')),
      );
      expect(newBuilding.dwellingAt(_a('03')), Dwelling(label: d('03')));
      expect(change.before, _eight);
      expect(change.building, newBuilding);
    });

    test('should keep the building\'s own come-back and note', () {
      final (described, _) = valueOf(
        _street8.describeBuilding(n('8'), plan(), by: lea, at: twoPm),
      );

      expect(described.houses[1].comeBack, comeBack('gardien'));
      expect(described.houses[1].note, note('digicode'));
      expect(described.houses[1].lastChange, leaAtTwo);
    });

    test('should leave the other houses alone', () {
      final (described, _) = valueOf(
        _street8.describeBuilding(n('8'), plan(), by: lea, at: twoPm),
      );

      expect(described.houses[0], _six);
      expect(described.id, _lilas);
    });

    test('should fail when the street has no such number', () {
      expect(
        failureOf(
          _street8.describeBuilding(n('9'), plan(), by: lea, at: twoPm),
        ),
        HouseChangeFailure.unknownHouse,
      );
    });
  });

  group('progress', () {
    test('should count the doors of a building instead of the house', () {
      // 6: nobody home; 8: 01 done, 02 to do, and its own « repasser ».
      final progress = _street8.progress;

      expect(progress.total, 3);
      expect(progress.done, 1);
      expect(progress.nobodyHome, 1);
      expect(progress.toDo, 1);
      expect(progress.comeBack, 1);
    });
  });

  group('markHouse', () {
    test('should refuse to mark a building as a whole', () {
      expect(
        failureOf(
          _street8.markHouse(n('8'), VisitStatus.done, by: lea, at: twoPm),
        ),
        HouseChangeFailure.houseIsBuilding,
      );
    });
  });

  group('setComeBack and setNote on a building', () {
    test('should set the building\'s own come-back and keep its doors', () {
      final (changed, _) = valueOf(
        _street8.setComeBack(n('8'), null, by: lea, at: twoPm),
      );

      expect(changed.houses[1].comeBack, isNull);
      expect(changed.houses[1].building, _eightDoors);
    });

    test(
      'should accept a come-back on a building whose doors are all done',
      () {
        final street = _street([
          House(
            number: n('8'),
            building: building(topFloor: 0, doors: 1).withDwelling(
              escA,
              0,
              Dwelling(label: d('01'), status: VisitStatus.done),
            ),
          ),
        ]);

        final (changed, _) = valueOf(
          street.setComeBack(n('8'), ComeBack.withoutHint, by: lea, at: twoPm),
        );

        expect(changed.houses.single.comeBack, ComeBack.withoutHint);
      },
    );

    test('should set the building\'s own note and keep its doors', () {
      final (changed, _) = valueOf(
        _street8.setNote(n('8'), note('code 1234'), by: lea, at: twoPm),
      );

      expect(changed.houses[1].note, note('code 1234'));
      expect(changed.houses[1].building, _eightDoors);
    });
  });

  group('markDwelling', () {
    test('should give the door its status and stamp, and say so', () {
      final (marked, change) = valueOf(
        _street8.markDwelling(
          n('8'),
          _a('02'),
          VisitStatus.nobodyHome,
          by: lea,
          at: twoPm,
        ),
      );

      expect(
        marked.houses[1].building!.dwellingAt(_a('02')),
        Dwelling(
          label: d('02'),
          status: VisitStatus.nobodyHome,
          lastChange: leaAtTwo,
        ),
      );
      expect(
        change,
        DwellingMarked(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 0,
          before: Dwelling(label: d('02')),
          stamp: leaAtTwo,
          status: VisitStatus.nobodyHome,
        ),
      );
    });

    test('should leave the house, its other doors and other houses alone', () {
      final (marked, _) = valueOf(
        _street8.markDwelling(
          n('8'),
          _a('02'),
          VisitStatus.done,
          by: lea,
          at: twoPm,
        ),
      );
      final house = marked.houses[1];

      expect(
        house.building!.dwellingAt(_a('01')),
        _eightDoors.dwellingAt(_a('01')),
      );
      expect(house.lastChange, paulAtThree);
      expect(house.comeBack, comeBack('gardien'));
      expect(house.note, note('digicode'));
      expect(marked.houses[0], _six);
    });

    test('should clear the door\'s come-back but keep its note when done', () {
      final (withComeBack, _) = valueOf(
        _street8.setDwellingComeBack(
          n('8'),
          _a('02'),
          comeBack('le soir'),
          by: lea,
          at: twoPm,
        ),
      );
      final (noted, _) = valueOf(
        withComeBack.setDwellingNote(
          n('8'),
          _a('02'),
          note('chien'),
          by: lea,
          at: twoPm,
        ),
      );

      final (marked, change) = valueOf(
        noted.markDwelling(
          n('8'),
          _a('02'),
          VisitStatus.done,
          by: paul,
          at: threePm,
        ),
      );

      expect(
        marked.houses[1].building!.dwellingAt(_a('02')),
        Dwelling(
          label: d('02'),
          status: VisitStatus.done,
          note: note('chien'),
          lastChange: paulAtThree,
        ),
      );
      expect(change.clearsComeBack, isTrue);
      expect(change.before.comeBack, comeBack('le soir'));
    });

    test('should make the building done once its last door is done', () {
      final (marked, _) = valueOf(
        _street8.markDwelling(
          n('8'),
          _a('02'),
          VisitStatus.done,
          by: lea,
          at: twoPm,
        ),
      );

      expect(marked.houses[1].building!.progress.done, 2);
      expect(
        marked.progress,
        Progress.of(VisitStatus.nobodyHome, comeBack: false) +
            Progress.of(VisitStatus.done, comeBack: false) +
            Progress.of(VisitStatus.done, comeBack: false) +
            Progress.comeBackAlone,
      );
    });

    test('should mark Gauche on its floor only when every floor has one', () {
      var free = building(topFloor: 1, doors: 1, style: DoorLabelStyle.free);
      for (final level in [0, 1]) {
        free = valueOf(
          free.withDoorRenamed(DwellingKey(escA, level, d('1')), d('Gauche')),
        );
      }
      final street = _street([House(number: n('8'), building: free)]);
      final firstFloor = DwellingKey(escA, 1, d('Gauche'));

      final (marked, change) = valueOf(
        street.markDwelling(
          n('8'),
          firstFloor,
          VisitStatus.done,
          by: lea,
          at: twoPm,
        ),
      );
      final changed = marked.houses.single.building!;

      expect(changed.dwellingAt(firstFloor)!.status, VisitStatus.done);
      expect(
        changed.dwellingAt(DwellingKey(escA, 0, d('Gauche')))!.status,
        VisitStatus.toDo,
      );
      expect(change.key, firstFloor);
      expect(change.key.id, 'A1-Gauche');
    });

    test('should fail when the street has no such number', () {
      expect(
        failureOf(
          _street8.markDwelling(
            n('9'),
            _a('01'),
            VisitStatus.done,
            by: lea,
            at: twoPm,
          ),
        ),
        DwellingChangeFailure.unknownHouse,
      );
    });

    test('should fail when the house is not a building', () {
      expect(
        failureOf(
          _street8.markDwelling(
            n('6'),
            _a('01'),
            VisitStatus.done,
            by: lea,
            at: twoPm,
          ),
        ),
        DwellingChangeFailure.notABuilding,
      );
    });

    test('should fail when the building has no such door', () {
      expect(
        failureOf(
          _street8.markDwelling(
            n('8'),
            _a('03'),
            VisitStatus.done,
            by: lea,
            at: twoPm,
          ),
        ),
        DwellingChangeFailure.unknownDwelling,
      );
    });

    test('should fail when the door is in a staircase the building lacks', () {
      expect(
        failureOf(
          _street8.markDwelling(
            n('8'),
            DwellingKey(escB, 0, d('01')),
            VisitStatus.done,
            by: lea,
            at: twoPm,
          ),
        ),
        DwellingChangeFailure.unknownDwelling,
      );
    });
  });

  group('setDwellingComeBack', () {
    test('should add the come-back to a door and say so', () {
      final (changed, change) = valueOf(
        _street8.setDwellingComeBack(
          n('8'),
          _a('02'),
          comeBack('samedi'),
          by: lea,
          at: twoPm,
        ),
      );

      expect(
        changed.houses[1].building!.dwellingAt(_a('02')),
        Dwelling(
          label: d('02'),
          comeBack: comeBack('samedi'),
          lastChange: leaAtTwo,
        ),
      );
      expect(
        change,
        DwellingComeBackSet(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 0,
          before: Dwelling(label: d('02')),
          stamp: leaAtTwo,
          comeBack: comeBack('samedi'),
        ),
      );
    });

    test('should remove the come-back when given none', () {
      final (withComeBack, _) = valueOf(
        _street8.setDwellingComeBack(
          n('8'),
          _a('02'),
          ComeBack.withoutHint,
          by: lea,
          at: twoPm,
        ),
      );

      final (changed, change) = valueOf(
        withComeBack.setDwellingComeBack(
          n('8'),
          _a('02'),
          null,
          by: paul,
          at: threePm,
        ),
      );

      expect(
        changed.houses[1].building!.dwellingAt(_a('02'))!.comeBack,
        isNull,
      );
      expect(change.before.comeBack, ComeBack.withoutHint);
    });

    test('should accept removing the come-back of a done door', () {
      final (changed, _) = valueOf(
        _street8.setDwellingComeBack(
          n('8'),
          _a('01'),
          null,
          by: lea,
          at: twoPm,
        ),
      );

      expect(
        changed.houses[1].building!.dwellingAt(_a('01')),
        Dwelling(
          label: d('01'),
          status: VisitStatus.done,
          lastChange: leaAtTwo,
        ),
      );
    });

    test('should refuse a come-back on a done door', () {
      expect(
        failureOf(
          _street8.setDwellingComeBack(
            n('8'),
            _a('01'),
            ComeBack.withoutHint,
            by: lea,
            at: twoPm,
          ),
        ),
        DwellingChangeFailure.comeBackOnDoneDwelling,
      );
    });

    test('should fail when the house is not a building', () {
      expect(
        failureOf(
          _street8.setDwellingComeBack(
            n('6'),
            _a('01'),
            null,
            by: lea,
            at: twoPm,
          ),
        ),
        DwellingChangeFailure.notABuilding,
      );
    });
  });

  group('setDwellingNote', () {
    test('should write the note of a door, keep its status and say so', () {
      final (changed, change) = valueOf(
        _street8.setDwellingNote(
          n('8'),
          _a('01'),
          note('chien'),
          by: lea,
          at: twoPm,
        ),
      );

      expect(
        changed.houses[1].building!.dwellingAt(_a('01')),
        Dwelling(
          label: d('01'),
          status: VisitStatus.done,
          note: note('chien'),
          lastChange: leaAtTwo,
        ),
      );
      expect(
        change,
        DwellingNoteSet(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 0,
          before: _eightDoors.dwellingAt(_a('01'))!,
          stamp: leaAtTwo,
          note: note('chien'),
        ),
      );
    });

    test('should erase the note when given the empty note', () {
      final (noted, _) = valueOf(
        _street8.setDwellingNote(
          n('8'),
          _a('02'),
          note('chien'),
          by: lea,
          at: twoPm,
        ),
      );

      final (changed, _) = valueOf(
        noted.setDwellingNote(n('8'), _a('02'), Note.empty, by: lea, at: twoPm),
      );

      expect(
        changed.houses[1].building!.dwellingAt(_a('02'))!.note,
        Note.empty,
      );
    });

    test('should fail when the building has no such door', () {
      expect(
        failureOf(
          _street8.setDwellingNote(
            n('8'),
            _a('99'),
            note('chien'),
            by: lea,
            at: twoPm,
          ),
        ),
        DwellingChangeFailure.unknownDwelling,
      );
    });
  });

  group('addDoor', () {
    test('should add a door to the floor and stamp the house', () {
      final (changed, change) = valueOf(
        _street8.addDoor(n('8'), escA, 0, by: lea, at: twoPm),
      );
      final expected = valueOf(_eightDoors.withDoorAdded(escA, 0));

      expect(
        changed.houses[1],
        House(
          number: n('8'),
          comeBack: comeBack('gardien'),
          note: note('digicode'),
          lastChange: leaAtTwo,
          building: expected,
        ),
      );
      expect(
        change,
        BuildingLaidOut(
          streetId: _lilas,
          before: _eight,
          stamp: leaAtTwo,
          building: expected,
        ),
      );
      expect(changed.houses[0], _six);
    });

    test('should pass on why the building refused', () {
      expect(
        failureOf(_street8.addDoor(n('8'), escA, 1, by: lea, at: twoPm)),
        BuildingChangeFailure.unknownFloor,
      );
    });

    test('should fail when the street has no such number', () {
      expect(
        failureOf(_street8.addDoor(n('9'), escA, 0, by: lea, at: twoPm)),
        BuildingChangeFailure.unknownHouse,
      );
    });

    test('should fail when the house is not a building', () {
      expect(
        failureOf(_street8.addDoor(n('6'), escA, 0, by: lea, at: twoPm)),
        BuildingChangeFailure.notABuilding,
      );
    });
  });

  group('removeDoor', () {
    test('should remove the door and stamp the house', () {
      final (changed, change) = valueOf(
        _street8.removeDoor(n('8'), _a('01'), by: lea, at: twoPm),
      );
      final expected = valueOf(_eightDoors.withoutDoor(_a('01')));

      expect(changed.houses[1].building, expected);
      expect(changed.houses[1].lastChange, leaAtTwo);
      expect(change.before, _eight);
      expect(change.building, expected);
    });

    test('should pass on why the building refused', () {
      expect(
        failureOf(_street8.removeDoor(n('8'), _a('03'), by: lea, at: twoPm)),
        BuildingChangeFailure.unknownDwelling,
      );
    });

    test('should fail when the house is not a building', () {
      expect(
        failureOf(_street8.removeDoor(n('6'), _a('01'), by: lea, at: twoPm)),
        BuildingChangeFailure.notABuilding,
      );
    });
  });

  group('renameDoor', () {
    test('should rename the door, keep its mark and stamp the house', () {
      final (changed, change) = valueOf(
        _street8.renameDoor(n('8'), _a('01'), d('Gauche'), by: lea, at: twoPm),
      );

      expect(
        changed.houses[1].building!.dwellingAt(_a('Gauche')),
        Dwelling(
          label: d('Gauche'),
          status: VisitStatus.done,
          lastChange: paulAtThree,
        ),
      );
      expect(changed.houses[1].lastChange, leaAtTwo);
      expect(change.before, _eight);
      expect(change.building, changed.houses[1].building);
    });

    test('should pass on why the building refused', () {
      expect(
        failureOf(
          _street8.renameDoor(n('8'), _a('01'), d('02'), by: lea, at: twoPm),
        ),
        BuildingChangeFailure.duplicateLabel,
      );
    });

    test('should fail when the street has no such number', () {
      expect(
        failureOf(
          _street8.renameDoor(n('9'), _a('01'), d('G'), by: lea, at: twoPm),
        ),
        BuildingChangeFailure.unknownHouse,
      );
    });
  });

  group('removeBuilding', () {
    test('should make a partly done building a single house to do', () {
      final (changed, change) = valueOf(
        _street8.removeBuilding(n('8'), by: lea, at: twoPm),
      );

      expect(
        changed.houses[1],
        House(
          number: n('8'),
          comeBack: comeBack('gardien'),
          note: note('digicode'),
          lastChange: leaAtTwo,
        ),
      );
      expect(
        change,
        BuildingRemoved(
          streetId: _lilas,
          before: _eight,
          stamp: leaAtTwo,
          status: VisitStatus.toDo,
        ),
      );
      expect(changed.houses[0], _six);
    });

    test('should make a building whose doors are all done a done house', () {
      final allDone = _eightDoors.withDwelling(
        escA,
        0,
        Dwelling(label: d('02'), status: VisitStatus.done),
      );
      final street = _street([
        House(number: n('8'), comeBack: comeBack('gardien'), building: allDone),
      ]);

      final (changed, change) = valueOf(
        street.removeBuilding(n('8'), by: lea, at: twoPm),
      );

      expect(
        changed.houses.single,
        House(number: n('8'), status: VisitStatus.done, lastChange: leaAtTwo),
      );
      expect(change.status, VisitStatus.done);
      expect(change.clearsComeBack, isTrue);
    });

    test('should make a building where nobody was home a house to do', () {
      final street = _street([
        House(
          number: n('8'),
          building: building(topFloor: 0, doors: 1).withDwelling(
            escA,
            0,
            Dwelling(label: d('01'), status: VisitStatus.nobodyHome),
          ),
        ),
      ]);

      final (changed, _) = valueOf(
        street.removeBuilding(n('8'), by: lea, at: twoPm),
      );

      expect(changed.houses.single.status, VisitStatus.toDo);
    });

    test('should fail when the house is not a building', () {
      expect(
        failureOf(_street8.removeBuilding(n('6'), by: lea, at: twoPm)),
        BuildingChangeFailure.notABuilding,
      );
    });

    test('should fail when the street has no such number', () {
      expect(
        failureOf(_street8.removeBuilding(n('9'), by: lea, at: twoPm)),
        BuildingChangeFailure.unknownHouse,
      );
    });
  });

  test('should leave the original street unchanged', () {
    _street8.markDwelling(
      n('8'),
      _a('02'),
      VisitStatus.done,
      by: lea,
      at: twoPm,
    );
    _street8.addDoor(n('8'), escA, 0, by: lea, at: twoPm);

    expect(_street8.houses[1], _eight);
  });

  test(
    'should keep the doors of a house when it is described with the same plan',
    () {
      final (again, _) = valueOf(
        _street8.describeBuilding(
          n('8'),
          plan(topFloor: 0, doors: 2),
          by: lea,
          at: twoPm,
        ),
      );

      expect(again.houses[1].building, _eightDoors);
      expect(again.houses[1].building!.style, DoorLabelStyle.floorAndNumber);
    },
  );
}
