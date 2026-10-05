import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/street_fixtures.dart';

void main() {
  final lilas = StreetId('rue-des-lilas');
  final gambetta = StreetId('rue-gambetta');
  final eight = House(number: n('8'), status: VisitStatus.nobodyHome);
  final eightBuilding = House(number: n('8'), building: building());

  group('BuildingLaidOut', () {
    BuildingLaidOut laidOut({
      StreetId? streetId,
      House? before,
      ChangeStamp? stamp,
      Building? newBuilding,
    }) => BuildingLaidOut(
      streetId: streetId ?? lilas,
      before: before ?? eight,
      stamp: stamp ?? leaAtTwo,
      building: newBuilding ?? building(),
    );

    test('should carry the new building and the house before', () {
      final change = laidOut();

      expect(change.streetId, lilas);
      expect(change.number, n('8'));
      expect(change.before, eight);
      expect(change.stamp, leaAtTwo);
      expect(change.building, building());
    });

    test('should be equal when every field is equal', () {
      expect(laidOut(), laidOut());
      expect(laidOut().hashCode, laidOut().hashCode);
    });

    final others = <String, BuildingLaidOut Function()>{
      'streets': () => laidOut(streetId: gambetta),
      'houses before': () => laidOut(before: eightBuilding),
      'stamps': () => laidOut(stamp: paulAtThree),
      'buildings': () => laidOut(newBuilding: building(doors: 3)),
    };
    others.forEach((field, other) {
      test('should differ when the $field differ', () {
        expect(laidOut(), isNot(other()));
      });
    });

    test('should show its fields when printed', () {
      expect(
        laidOut(newBuilding: building(topFloor: 0, doors: 1)).toString(),
        'BuildingLaidOut(rue-des-lilas, 8, '
        '${building(topFloor: 0, doors: 1)}, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('BuildingRemoved', () {
    BuildingRemoved removed({
      StreetId? streetId,
      House? before,
      ChangeStamp? stamp,
      VisitStatus status = VisitStatus.done,
    }) => BuildingRemoved(
      streetId: streetId ?? lilas,
      before: before ?? eightBuilding,
      stamp: stamp ?? leaAtTwo,
      status: status,
    );

    test('should carry the new status and the building before', () {
      final change = removed();

      expect(change.streetId, lilas);
      expect(change.number, n('8'));
      expect(change.before, eightBuilding);
      expect(change.stamp, leaAtTwo);
      expect(change.status, VisitStatus.done);
    });

    final eightComingBack = House(
      number: n('8'),
      comeBack: comeBack('gardien'),
      building: building(),
    );

    test('should drop the building\'s come-back when the house is done', () {
      expect(
        removed(before: eightComingBack, status: VisitStatus.done).comeBack,
        isNull,
      );
    });

    test('should keep the building\'s come-back when the house is it', () {
      expect(
        removed(before: eightComingBack, status: VisitStatus.comeBack).comeBack,
        comeBack('gardien'),
      );
    });

    test('should be equal when every field is equal', () {
      expect(removed(), removed());
      expect(removed().hashCode, removed().hashCode);
    });

    final others = <String, BuildingRemoved Function()>{
      'streets': () => removed(streetId: gambetta),
      'houses before': () => removed(before: eight),
      'stamps': () => removed(stamp: paulAtThree),
      'statuses': () => removed(status: VisitStatus.toDo),
    };
    others.forEach((field, other) {
      test('should differ when the $field differ', () {
        expect(removed(), isNot(other()));
      });
    });

    test('should show its fields when printed', () {
      expect(
        removed().toString(),
        'BuildingRemoved(rue-des-lilas, 8, VisitStatus.done, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('dwelling changes', () {
    final door = Dwelling(
      label: d('51'),
      status: VisitStatus.comeBack,
      comeBack: comeBack('le soir'),
    );
    final otherDoor = Dwelling(label: d('52'));

    group('DwellingMarked', () {
      DwellingMarked marked({
        StreetId? streetId,
        HouseNumber? number,
        StaircaseName? staircase,
        int? level = 5,
        Dwelling? before,
        ChangeStamp? stamp,
        VisitStatus status = VisitStatus.done,
      }) => DwellingMarked(
        streetId: streetId ?? lilas,
        number: number ?? n('8'),
        staircase: staircase ?? escA,
        level: level,
        before: before ?? door,
        stamp: stamp ?? leaAtTwo,
        status: status,
      );

      test('should name the house, the door and its key', () {
        final change = marked(staircase: escB);

        expect(change.streetId, lilas);
        expect(change.number, n('8'));
        expect(change.staircase, escB);
        expect(change.level, 5);
        expect(change.before, door);
        expect(change.key, DwellingKey(escB, 5, d('51')));
        expect(change.stamp, leaAtTwo);
        expect(change.status, VisitStatus.done);
      });

      for (final status in [
        VisitStatus.toDo,
        VisitStatus.done,
        VisitStatus.nobodyHome,
      ]) {
        test('should leave no come-back when the door becomes $status', () {
          expect(marked(status: status).comeBack, isNull);
        });
      }

      test('should keep the hint when the door stays « repasser »', () {
        expect(
          marked(status: VisitStatus.comeBack).comeBack,
          comeBack('le soir'),
        );
      });

      test('should come back without hint when the door becomes it', () {
        expect(
          marked(before: otherDoor, status: VisitStatus.comeBack).comeBack,
          ComeBack.withoutHint,
        );
      });

      test('should be equal when every field is equal', () {
        expect(marked(), marked());
        expect(marked().hashCode, marked().hashCode);
      });

      final others = <String, DwellingMarked Function()>{
        'streets': () => marked(streetId: gambetta),
        'houses': () => marked(number: n('10')),
        'staircases': () => marked(staircase: escB),
        'floors': () => marked(level: 4),
        'floors, one unknown': () => marked(level: null),
        'doors before': () => marked(before: otherDoor),
        'stamps': () => marked(stamp: paulAtThree),
        'statuses': () => marked(status: VisitStatus.toDo),
      };
      others.forEach((field, other) {
        test('should differ when the $field differ', () {
          expect(marked(), isNot(other()));
        });
      });

      test('should differ from another change of the same door', () {
        final comeBackSet = DwellingComeBackSet(
          streetId: lilas,
          number: n('8'),
          staircase: escA,
          level: 5,
          before: door,
          stamp: leaAtTwo,
          comeBack: null,
        );

        expect(marked(), isNot(comeBackSet));
      });

      test('should show its fields when printed', () {
        expect(
          marked().toString(),
          'DwellingMarked(rue-des-lilas, 8, A5-51, VisitStatus.done, '
          'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
        );
      });
    });

    group('DwellingComeBackSet', () {
      DwellingComeBackSet set({
        Dwelling? before,
        ComeBack? comeBack = ComeBack.withoutHint,
      }) => DwellingComeBackSet(
        streetId: lilas,
        number: n('8'),
        staircase: escA,
        level: null,
        before: before ?? door,
        stamp: leaAtTwo,
        comeBack: comeBack,
      );

      test('should carry the new come-back and the door before', () {
        final change = set(comeBack: comeBack('samedi'));

        expect(change.key, DwellingKey(escA, null, d('51')));
        expect(change.before, door);
        expect(change.comeBack, comeBack('samedi'));
      });

      test('should be equal when every field is equal', () {
        expect(set(), set());
        expect(set().hashCode, set().hashCode);
      });

      test('should differ when the come-backs differ', () {
        expect(set(), isNot(set(comeBack: null)));
      });

      test('should differ when the doors before differ', () {
        expect(set(), isNot(set(before: otherDoor)));
      });

      test('should show its fields when printed', () {
        expect(
          set(comeBack: null).toString(),
          'DwellingComeBackSet(rue-des-lilas, 8, A-51, null, '
          'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
        );
      });
    });
  });
}
