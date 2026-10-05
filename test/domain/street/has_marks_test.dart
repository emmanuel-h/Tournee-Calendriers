// Whether a house, a building or a door carries anything a person entered:
// removing such a number asks for confirmation first (PLAN §5.5).
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/street_fixtures.dart';

void main() {
  group('Dwelling', () {
    test('should have no mark when new, even with a last change', () {
      expect(Dwelling(label: d('51'), lastChange: leaAtTwo).hasMarks, isFalse);
    });

    test('should have a mark when done', () {
      expect(
        Dwelling(label: d('51'), status: VisitStatus.done).hasMarks,
        isTrue,
      );
    });

    test('should have a mark when nobody was home', () {
      expect(
        Dwelling(label: d('51'), status: VisitStatus.nobodyHome).hasMarks,
        isTrue,
      );
    });

    test('should have a mark when it has a « repasser »', () {
      expect(
        Dwelling(label: d('51'), status: VisitStatus.comeBack).hasMarks,
        isTrue,
      );
    });

    test('should have a mark when it has a note', () {
      expect(Dwelling(label: d('51'), note: note('chien')).hasMarks, isTrue);
    });
  });

  group('Building', () {
    test('should have no mark when no door has one', () {
      expect(building(topFloor: 1, doors: 2).hasMarks, isFalse);
    });

    test('should have a mark when one door, not the first, has one', () {
      final marked = building(
        topFloor: 1,
        doors: 2,
      ).withDwelling(escA, 0, Dwelling(label: d('02'), note: note('digicode')));

      expect(marked.hasMarks, isTrue);
    });

    test('should have a mark when a door of another staircase has one', () {
      final marked = building(staircases: 2, topFloor: 0, doors: 1)
          .withDwelling(
            escB,
            0,
            Dwelling(label: d('01'), status: VisitStatus.nobodyHome),
          );

      expect(marked.hasMarks, isTrue);
    });
  });

  group('House', () {
    test('should have no mark when new, even with a last change', () {
      expect(House(number: n('3'), lastChange: leaAtTwo).hasMarks, isFalse);
    });

    test('should have a mark when done', () {
      expect(House(number: n('3'), status: VisitStatus.done).hasMarks, isTrue);
    });

    test('should have a mark when nobody was home', () {
      expect(
        House(number: n('3'), status: VisitStatus.nobodyHome).hasMarks,
        isTrue,
      );
    });

    test('should have a mark when it has a « repasser »', () {
      expect(
        House(number: n('3'), status: VisitStatus.comeBack).hasMarks,
        isTrue,
      );
    });

    test('should have a mark when its building has its own « repasser »', () {
      expect(
        House(
          number: n('8'),
          comeBack: comeBack(''),
          building: building(),
        ).hasMarks,
        isTrue,
      );
    });

    test('should have a mark when it has a note', () {
      expect(House(number: n('3'), note: note('chien')).hasMarks, isTrue);
    });

    test('should have no mark when it is a building without marks', () {
      expect(House(number: n('8'), building: building()).hasMarks, isFalse);
    });

    test('should have a mark when a door of its building has one', () {
      final doors = building(topFloor: 0, doors: 1).withDwelling(
        escA,
        0,
        Dwelling(label: d('01'), status: VisitStatus.done),
      );

      expect(House(number: n('8'), building: doors).hasMarks, isTrue);
    });
  });
}
