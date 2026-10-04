import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/street_fixtures.dart';

void main() {
  test('should be to do, without come-back, note or change when new', () {
    final house = House(number: n('12'));

    expect(house.number, n('12'));
    expect(house.status, VisitStatus.toDo);
    expect(house.comeBack, isNull);
    expect(house.note, Note.empty);
    expect(house.lastChange, isNull);
    expect(house.building, isNull);
    expect(house.isBuilding, isFalse);
    expect(house.position, isNull);
  });

  test('should keep its position when given one', () {
    final house = House(number: n('12'), position: townHallDoor);

    expect(house.position, townHallDoor);
  });

  test('should keep every field when given them', () {
    final house = House(
      number: n('3bis'),
      status: VisitStatus.nobodyHome,
      comeBack: comeBack('après 19h'),
      note: note('chien dans le jardin'),
      lastChange: leaAtTwo,
    );

    expect(house.number, n('3bis'));
    expect(house.status, VisitStatus.nobodyHome);
    expect(house.comeBack, comeBack('après 19h'));
    expect(house.note, note('chien dans le jardin'));
    expect(house.lastChange, leaAtTwo);
  });

  test('should keep the come-back when the house is to do', () {
    final house = House(number: n('5'), comeBack: ComeBack.withoutHint);

    expect(house.comeBack, ComeBack.withoutHint);
  });

  test('should drop the come-back when the house is done', () {
    final house = House(
      number: n('5'),
      status: VisitStatus.done,
      comeBack: comeBack('après 19h'),
    );

    expect(house.comeBack, isNull);
  });

  group('building', () {
    test('should hold the building it is given', () {
      final house = House(number: n('8'), building: building());

      expect(house.building, building());
      expect(house.isBuilding, isTrue);
    });

    test('should be to do itself when it is a building', () {
      final house = House(
        number: n('8'),
        status: VisitStatus.done,
        building: building(),
      );

      expect(house.status, VisitStatus.toDo);
    });

    test('should keep its own come-back and note when it is a building', () {
      final house = House(
        number: n('8'),
        status: VisitStatus.done,
        comeBack: comeBack('gardien'),
        note: note('digicode'),
        building: building(),
      );

      expect(house.comeBack, comeBack('gardien'));
      expect(house.note, note('digicode'));
    });
  });

  group('progress', () {
    test('should count one done door when the house is done', () {
      final house = House(number: n('2'), status: VisitStatus.done);

      expect(house.progress, Progress.of(VisitStatus.done, comeBack: false));
    });

    test('should count the come-back when the house has one', () {
      final house = House(
        number: n('7'),
        status: VisitStatus.nobodyHome,
        comeBack: ComeBack.withoutHint,
      );

      expect(
        house.progress,
        Progress.of(VisitStatus.nobodyHome, comeBack: true),
      );
    });

    test('should count no come-back when the house has none', () {
      final house = House(number: n('7'));

      expect(house.progress, Progress.of(VisitStatus.toDo, comeBack: false));
    });

    test('should count the doors of its building instead of itself', () {
      final doors = building(topFloor: 0, doors: 2).withDwelling(
        escA,
        0,
        Dwelling(label: d('01'), status: VisitStatus.done),
      );
      final house = House(number: n('8'), building: doors);

      expect(house.progress, doors.progress);
      expect(house.progress.total, 2);
      expect(house.progress.done, 1);
    });

    test('should add the building\'s own come-back to its doors', () {
      final doors = building(topFloor: 0, doors: 2);
      final house = House(
        number: n('8'),
        comeBack: ComeBack.withoutHint,
        building: doors,
      );

      expect(house.progress, doors.progress + Progress.comeBackAlone);
      expect(house.progress.total, 2);
      expect(house.progress.comeBack, 1);
    });
  });

  group('equality', () {
    House full() => House(
      number: n('3bis'),
      status: VisitStatus.nobodyHome,
      comeBack: comeBack('après 19h'),
      note: note('chien'),
      lastChange: leaAtTwo,
    );

    test('should be equal when every field is equal', () {
      expect(full(), full());
      expect(full().hashCode, full().hashCode);
    });

    final others = <String, House>{
      'number': House(
        number: n('3ter'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('après 19h'),
        note: note('chien'),
        lastChange: leaAtTwo,
      ),
      'status': House(
        number: n('3bis'),
        comeBack: comeBack('après 19h'),
        note: note('chien'),
        lastChange: leaAtTwo,
      ),
      'come-back': House(
        number: n('3bis'),
        status: VisitStatus.nobodyHome,
        note: note('chien'),
        lastChange: leaAtTwo,
      ),
      'note': House(
        number: n('3bis'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('après 19h'),
        lastChange: leaAtTwo,
      ),
      'last change': House(
        number: n('3bis'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('après 19h'),
        note: note('chien'),
        lastChange: paulAtThree,
      ),
      'position': House(
        number: n('3bis'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('après 19h'),
        note: note('chien'),
        lastChange: leaAtTwo,
        position: townHallDoor,
      ),
    };

    test('should be equal when the positions are equal', () {
      expect(
        House(number: n('3'), position: townHallDoor),
        House(number: n('3'), position: townHallDoor),
      );
      expect(
        House(number: n('3'), position: townHallDoor).hashCode,
        House(number: n('3'), position: townHallDoor).hashCode,
      );
      expect(
        House(number: n('3'), position: townHallDoor),
        isNot(House(number: n('3'), position: northDoor)),
      );
    });

    test('should differ when the buildings differ', () {
      final four = House(number: n('8'), building: building(doors: 4));

      expect(four, isNot(House(number: n('8'), building: building(doors: 3))));
      expect(four, isNot(House(number: n('8'))));
    });

    test('should be equal when the buildings are equal', () {
      expect(
        House(number: n('8'), building: building()),
        House(number: n('8'), building: building()),
      );
      expect(
        House(number: n('8'), building: building()).hashCode,
        House(number: n('8'), building: building()).hashCode,
      );
    });
    others.forEach((field, other) {
      test('should differ when the ${field}s differ', () {
        expect(full(), isNot(other));
      });
    });

    test('should differ from a value of another type', () {
      expect(House(number: n('3')), isNot(n('3')));
    });
  });

  test('should show its fields when printed', () {
    final house = House(
      number: n('12'),
      status: VisitStatus.nobodyHome,
      comeBack: comeBack('après 19h'),
      note: note('chien'),
      lastChange: leaAtTwo,
    );

    expect(
      house.toString(),
      'House(12, VisitStatus.nobodyHome, ComeBack(après 19h), Note(chien), '
      'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
    );
  });

  test('should show its building after its fields when printed', () {
    final one = building(topFloor: 0, doors: 1);
    final house = House(number: n('8'), building: one);

    expect(
      house.toString(),
      'House(8, VisitStatus.toDo, null, Note(), null, $one)',
    );
  });
}
