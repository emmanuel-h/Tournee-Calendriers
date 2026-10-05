// The changes an undo makes (PLAN §7: undo is a normal write of the
// previous value): a whole house, or a whole door, put back.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/street_fixtures.dart';

void main() {
  final lilas = StreetId('rue-des-lilas');
  final gambetta = StreetId('rue-gambetta');
  final twelveDone = House(
    number: n('12'),
    status: VisitStatus.done,
    lastChange: leaAtTwo,
  );
  final twelve = House(number: n('12'), comeBack: comeBack('après 19h'));

  group('HouseReverted', () {
    HouseReverted reverted({
      StreetId? streetId,
      House? replaced,
      House? house,
    }) => HouseReverted(
      streetId: streetId ?? lilas,
      replaced: replaced ?? twelveDone,
      house: house ?? twelve,
    );

    test('should carry the house it replaced and the house put back', () {
      final change = reverted();

      expect(change.streetId, lilas);
      expect(change.replaced, twelveDone);
      expect(change.house, twelve);
      expect(change.number, n('12'));
    });

    test('should not renumber when both houses have the same number', () {
      expect(reverted().renumbers, isFalse);
    });

    test('should renumber when the houses have different numbers', () {
      final change = reverted(replaced: House(number: n('12bis')));

      expect(change.renumbers, isTrue);
      expect(change.number, n('12'));
    });

    test('should be equal when every field is equal', () {
      expect(reverted(), reverted());
      expect(reverted().hashCode, reverted().hashCode);
    });

    final others = <String, HouseReverted Function()>{
      'streets': () => reverted(streetId: gambetta),
      'houses replaced': () => reverted(replaced: twelve),
      'houses put back': () => reverted(house: twelveDone),
    };
    others.forEach((field, other) {
      test('should differ when the $field differ', () {
        expect(reverted(), isNot(other()));
      });
    });

    test('should show its fields when printed', () {
      expect(
        reverted(replaced: House(number: n('12bis'))).toString(),
        'HouseReverted(rue-des-lilas, 12bis → 12)',
      );
    });
  });

  group('DwellingReverted', () {
    final doneDoor = Dwelling(
      label: d('51'),
      status: VisitStatus.done,
      lastChange: leaAtTwo,
    );
    final door = Dwelling(label: d('51'), status: VisitStatus.nobodyHome);

    DwellingReverted reverted({
      StreetId? streetId,
      HouseNumber? number,
      StaircaseName? staircase,
      int? level = 5,
      Dwelling? replaced,
      Dwelling? dwelling,
    }) => DwellingReverted(
      streetId: streetId ?? lilas,
      number: number ?? n('8'),
      staircase: staircase ?? escA,
      level: level,
      replaced: replaced ?? doneDoor,
      dwelling: dwelling ?? door,
    );

    test('should name the house, the door and its key', () {
      final change = reverted(staircase: escB);

      expect(change.streetId, lilas);
      expect(change.number, n('8'));
      expect(change.staircase, escB);
      expect(change.level, 5);
      expect(change.replaced, doneDoor);
      expect(change.dwelling, door);
      expect(change.key, DwellingKey(escB, 5, d('51')));
    });

    test('should be equal when every field is equal', () {
      expect(reverted(), reverted());
      expect(reverted().hashCode, reverted().hashCode);
    });

    final others = <String, DwellingReverted Function()>{
      'streets': () => reverted(streetId: gambetta),
      'houses': () => reverted(number: n('10')),
      'staircases': () => reverted(staircase: escB),
      'floors': () => reverted(level: 4),
      'floors, one unknown': () => reverted(level: null),
      'doors replaced': () => reverted(replaced: door),
      'doors put back': () => reverted(dwelling: doneDoor),
    };
    others.forEach((field, other) {
      test('should differ when the $field differ', () {
        expect(reverted(), isNot(other()));
      });
    });

    test('should show its fields when printed', () {
      expect(
        reverted(level: null).toString(),
        'DwellingReverted(rue-des-lilas, 8, A-51)',
      );
    });
  });
}
