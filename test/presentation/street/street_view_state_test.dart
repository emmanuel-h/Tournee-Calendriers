import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/street_fixtures.dart';

/// A building of two RdC doors, 01 and 02, with the statuses given.
House _building(
  VisitStatus first,
  VisitStatus second, {
  bool comeBack = false,
}) => House(
  number: n('8'),
  comeBack: comeBack ? comeBackHint : null,
  building: building(topFloor: 0, doors: 2)
      .withDwelling(escA, 0, Dwelling(label: d('01'), status: first))
      .withDwelling(escA, 0, Dwelling(label: d('02'), status: second)),
);

final comeBackHint = comeBack('après 19h');

void main() {
  group('TileMark.of', () {
    test('should show a single house to do as to do', () {
      expect(TileMark.of(House(number: n('1'))), const ToDoMark());
    });

    test('should show a house to do with a « repasser » as come back', () {
      expect(
        TileMark.of(House(number: n('5'), comeBack: comeBackHint)),
        const ComeBackMark(),
      );
    });

    test('should show a done house as done', () {
      expect(
        TileMark.of(House(number: n('3'), status: VisitStatus.done)),
        const DoneMark(),
      );
    });

    test('should show nobody home first, « repasser » or not', () {
      expect(
        TileMark.of(
          House(
            number: n('3bis'),
            status: VisitStatus.nobodyHome,
            comeBack: comeBackHint,
          ),
        ),
        const NobodyHomeMark(),
      );
    });

    test('should show a building with some doors done as partial', () {
      expect(
        TileMark.of(_building(VisitStatus.done, VisitStatus.nobodyHome)),
        const PartialBuildingMark(done: 1, total: 2),
      );
    });

    test('should show a building with every door done as done', () {
      expect(
        TileMark.of(_building(VisitStatus.done, VisitStatus.done)),
        const DoneMark(),
      );
    });

    test('should show a building with no door done as to do', () {
      expect(
        TileMark.of(_building(VisitStatus.nobodyHome, VisitStatus.toDo)),
        const ToDoMark(),
      );
    });

    test(
      'should show a building to do with its own « repasser » as come back',
      () {
        expect(
          TileMark.of(
            _building(VisitStatus.toDo, VisitStatus.toDo, comeBack: true),
          ),
          const ComeBackMark(),
        );
      },
    );
  });

  group('TileMark.ofDwelling', () {
    test('should show a door to do as to do', () {
      expect(TileMark.ofDwelling(Dwelling(label: d('51'))), const ToDoMark());
    });

    test('should show a door to do with a « repasser » as come back', () {
      expect(
        TileMark.ofDwelling(Dwelling(label: d('51'), comeBack: comeBackHint)),
        const ComeBackMark(),
      );
    });

    test('should show a done door as done', () {
      expect(
        TileMark.ofDwelling(Dwelling(label: d('51'), status: VisitStatus.done)),
        const DoneMark(),
      );
    });

    test('should show nobody home first, « repasser » or not', () {
      expect(
        TileMark.ofDwelling(
          Dwelling(
            label: d('51'),
            status: VisitStatus.nobodyHome,
            comeBack: comeBackHint,
          ),
        ),
        const NobodyHomeMark(),
      );
    });
  });

  group('PartialBuildingMark', () {
    test('should be equal when both counts are equal', () {
      const mark = PartialBuildingMark(done: 7, total: 12);

      expect(mark, const PartialBuildingMark(done: 7, total: 12));
      expect(
        mark.hashCode,
        const PartialBuildingMark(done: 7, total: 12).hashCode,
      );
      expect(mark, isNot(const PartialBuildingMark(done: 6, total: 12)));
      expect(mark, isNot(const PartialBuildingMark(done: 7, total: 11)));
    });

    test('should name both counts when printed', () {
      expect(
        const PartialBuildingMark(done: 7, total: 12).toString(),
        'PartialBuildingMark(7/12)',
      );
    });
  });

  group('HouseTile', () {
    test('should give the number, mark, note and kind of a house', () {
      final tile = HouseTile.of(
        House(
          number: n('3bis'),
          status: VisitStatus.nobodyHome,
          note: note('chien'),
        ),
      );

      expect(tile.number, n('3bis'));
      expect(tile.mark, const NobodyHomeMark());
      expect(tile.hasNote, isTrue);
      expect(tile.isBuilding, isFalse);
    });

    test('should say a building is one and has no note when none written', () {
      final tile = HouseTile.of(_building(VisitStatus.done, VisitStatus.toDo));

      expect(tile.number, n('8'));
      expect(tile.hasNote, isFalse);
      expect(tile.isBuilding, isTrue);
    });

    test('should be equal when every field is equal', () {
      HouseTile tile({
        String number = '1',
        TileMark mark = const ToDoMark(),
        bool hasNote = false,
        bool isBuilding = false,
      }) => HouseTile(
        number: n(number),
        mark: mark,
        hasNote: hasNote,
        isBuilding: isBuilding,
      );

      expect(tile(), tile());
      expect(tile().hashCode, tile().hashCode);
      expect(tile(), isNot(tile(number: '3')));
      expect(tile(), isNot(tile(mark: const DoneMark())));
      expect(tile(), isNot(tile(hasNote: true)));
      expect(tile(), isNot(tile(isBuilding: true)));
    });

    test('should name every field when printed', () {
      final tile = HouseTile(
        number: n('3bis'),
        mark: const NobodyHomeMark(),
        hasNote: true,
        isBuilding: false,
      );

      expect(
        tile.toString(),
        "HouseTile(3bis, Instance of 'NobodyHomeMark', note: true, "
        'building: false)',
      );
    });
  });

  group('StreetShown', () {
    StreetShown shown({int done = 0, int total = 0}) => StreetShown(
      name: 'Rue des Lilas',
      done: done,
      total: total,
      nobodyHome: 0,
      comeBack: 0,
      hideDone: false,
      columns: StreetColumns.both,
      odd: const [],
      even: const [],
    );

    test('should give the share of doors done', () {
      expect(shown(done: 1, total: 4).fraction, 0.25);
    });

    test('should give no share when the street has no door', () {
      expect(shown().fraction, 0);
    });
  });

  group('MarkedHouse', () {
    test('should be equal when the number and the status are equal', () {
      final marked = MarkedHouse(number: n('7'), status: VisitStatus.done);

      expect(marked, MarkedHouse(number: n('7'), status: VisitStatus.done));
      expect(
        marked.hashCode,
        MarkedHouse(number: n('7'), status: VisitStatus.done).hashCode,
      );
      expect(
        marked,
        isNot(MarkedHouse(number: n('9'), status: VisitStatus.done)),
      );
      expect(
        marked,
        isNot(MarkedHouse(number: n('7'), status: VisitStatus.nobodyHome)),
      );
    });

    test('should name the number and the status when printed', () {
      expect(
        MarkedHouse(number: n('7'), status: VisitStatus.done).toString(),
        'MarkedHouse(7, VisitStatus.done)',
      );
    });
  });
}
