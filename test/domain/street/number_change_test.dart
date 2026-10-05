// The changes made by the edit mode of a street (PLAN §5.5): numbers added,
// removed, restored, renamed, and the street renamed.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/street_fixtures.dart';

void main() {
  final lilas = StreetId('rue-des-lilas');
  final gambetta = StreetId('rue-gambetta');
  final fourteenTer = RemovedHouse(
    house: House(number: n('14ter'), status: VisitStatus.done),
    removal: leaAtTwo,
  );
  final three = House(
    number: n('3'),
    status: VisitStatus.nobodyHome,
    comeBack: comeBack('après 19h'),
    lastChange: leaAtTwo,
  );

  group('NumbersAdded', () {
    NumbersAdded added({
      StreetId? streetId,
      List<House>? houses,
      List<RemovedHouse>? restored,
      List<HouseNumber>? alreadyThere,
    }) => NumbersAdded(
      streetId: streetId ?? lilas,
      added: houses ?? [House(number: n('21')), House(number: n('22'))],
      restored: restored ?? [fourteenTer],
      alreadyThere: alreadyThere ?? [n('12bis')],
    );

    test('should keep what was added, restored and already there', () {
      final change = added();

      expect(change.streetId, lilas);
      expect(change.added, [House(number: n('21')), House(number: n('22'))]);
      expect(change.restored, [fourteenTer]);
      expect(change.alreadyThere, [n('12bis')]);
    });

    test('should not change when the lists it was given change', () {
      final houses = [House(number: n('21'))];
      final restored = [fourteenTer];
      final there = [n('12bis')];
      final change = added(
        houses: houses,
        restored: restored,
        alreadyThere: there,
      );

      houses.clear();
      restored.clear();
      there.clear();

      expect(change.added, [House(number: n('21'))]);
      expect(change.restored, [fourteenTer]);
      expect(change.alreadyThere, [n('12bis')]);
    });

    test('should refuse to have its lists modified', () {
      final change = added();

      expect(change.added.clear, throwsUnsupportedError);
      expect(change.restored.clear, throwsUnsupportedError);
      expect(change.alreadyThere.clear, throwsUnsupportedError);
    });

    test('should be equal when every field is equal', () {
      expect(added(), added());
      expect(added().hashCode, added().hashCode);
    });

    test('should differ when the streets differ', () {
      expect(added(), isNot(added(streetId: gambetta)));
    });

    test('should differ when the added houses differ', () {
      expect(added(), isNot(added(houses: [House(number: n('21'))])));
    });

    test('should differ when the restored houses differ', () {
      expect(added(), isNot(added(restored: [])));
    });

    test('should differ when the numbers already there differ', () {
      expect(added(), isNot(added(alreadyThere: [n('12')])));
    });

    test('should differ from a value of another type', () {
      expect(added(), isNot(StreetRestored(streetId: lilas)));
    });

    test('should show the numbers when printed', () {
      expect(
        added().toString(),
        'NumbersAdded(rue-des-lilas, added: [21, 22], restored: [14ter], '
        'alreadyThere: [12bis])',
      );
    });
  });

  group('NumberRemoved', () {
    NumberRemoved removed({StreetId? streetId, RemovedHouse? house}) =>
        NumberRemoved(
          streetId: streetId ?? lilas,
          removed: house ?? fourteenTer,
        );

    test('should keep the house as removed and who removed it', () {
      final change = removed();

      expect(change.streetId, lilas);
      expect(change.removed, fourteenTer);
      expect(change.number, n('14ter'));
    });

    test('should say it removed marks when the house had some', () {
      expect(removed().hadMarks, isTrue);
    });

    test('should say it removed no mark when the house had none', () {
      final blank = RemovedHouse(
        house: House(number: n('5')),
        removal: leaAtTwo,
      );

      expect(removed(house: blank).hadMarks, isFalse);
    });

    test('should be equal when every field is equal', () {
      expect(removed(), removed());
      expect(removed().hashCode, removed().hashCode);
    });

    test('should differ when the streets differ', () {
      expect(removed(), isNot(removed(streetId: gambetta)));
    });

    test('should differ when the removed houses differ', () {
      final other = RemovedHouse(
        house: fourteenTer.house,
        removal: paulAtThree,
      );

      expect(removed(), isNot(removed(house: other)));
    });

    test('should differ from the restoring of the same house', () {
      expect(
        removed(),
        isNot(NumberRestored(streetId: lilas, removed: fourteenTer)),
      );
    });

    test('should show the number and the removal when printed', () {
      expect(
        removed().toString(),
        'NumberRemoved(rue-des-lilas, 14ter, '
        'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('NumberRestored', () {
    NumberRestored restored({StreetId? streetId, RemovedHouse? house}) =>
        NumberRestored(
          streetId: streetId ?? lilas,
          removed: house ?? fourteenTer,
        );

    test('should keep the house as it was in the Corbeille', () {
      final change = restored();

      expect(change.streetId, lilas);
      expect(change.removed, fourteenTer);
      expect(change.number, n('14ter'));
    });

    test('should be equal when every field is equal', () {
      expect(restored(), restored());
      expect(restored().hashCode, restored().hashCode);
    });

    test('should differ when the streets differ', () {
      expect(restored(), isNot(restored(streetId: gambetta)));
    });

    test('should differ when the removed houses differ', () {
      final other = RemovedHouse(
        house: fourteenTer.house,
        removal: paulAtThree,
      );

      expect(restored(), isNot(restored(house: other)));
    });

    test('should differ from the removing of the same house', () {
      expect(
        restored(),
        isNot(NumberRemoved(streetId: lilas, removed: fourteenTer)),
      );
    });

    test('should show the number when printed', () {
      expect(restored().toString(), 'NumberRestored(rue-des-lilas, 14ter)');
    });
  });

  group('NumberRenamed', () {
    NumberRenamed renamed({
      StreetId? streetId,
      House? before,
      ChangeStamp? stamp,
      HouseNumber? newNumber,
    }) => NumberRenamed(
      streetId: streetId ?? lilas,
      before: before ?? three,
      stamp: stamp ?? paulAtThree,
      newNumber: newNumber ?? n('3bis'),
    );

    test('should name the old number and the new one', () {
      final change = renamed();

      expect(change.streetId, lilas);
      expect(change.number, n('3'));
      expect(change.before, three);
      expect(change.newNumber, n('3bis'));
      expect(change.stamp, paulAtThree);
    });

    test('should give the house under its new number with its marks', () {
      expect(
        renamed().after,
        House(
          number: n('3bis'),
          status: VisitStatus.nobodyHome,
          comeBack: comeBack('après 19h'),
          lastChange: paulAtThree,
        ),
      );
    });

    test('should keep the building of the house under its new number', () {
      final eight = House(number: n('8'), building: building());

      expect(
        renamed(before: eight, newNumber: n('8A')).after,
        House(number: n('8A'), lastChange: paulAtThree, building: building()),
      );
    });

    test('should be equal when every field is equal', () {
      expect(renamed(), renamed());
      expect(renamed().hashCode, renamed().hashCode);
    });

    test('should differ when the streets differ', () {
      expect(renamed(), isNot(renamed(streetId: gambetta)));
    });

    test('should differ when the houses before differ', () {
      expect(renamed(), isNot(renamed(before: House(number: n('3')))));
    });

    test('should differ when the stamps differ', () {
      expect(renamed(), isNot(renamed(stamp: leaAtTwo)));
    });

    test('should differ when the new numbers differ', () {
      expect(renamed(), isNot(renamed(newNumber: n('3ter'))));
    });

    test('should show both numbers when printed', () {
      expect(
        renamed().toString(),
        'NumberRenamed(rue-des-lilas, 3 → 3bis, '
        'ChangeStamp(paul, 2026-11-02 15:00:00.000Z))',
      );
    });
  });

  group('StreetRenamed', () {
    StreetRenamed renamed({
      StreetId? streetId,
      StreetName? before,
      StreetName? name,
    }) => StreetRenamed(
      streetId: streetId ?? lilas,
      before: before ?? streetName('Rue des Lilas'),
      name: name ?? streetName('Allée des Lilas'),
    );

    test('should keep the old name and the new one', () {
      final change = renamed();

      expect(change.streetId, lilas);
      expect(change.before.text, 'Rue des Lilas');
      expect(change.name.text, 'Allée des Lilas');
    });

    test('should be equal when every field is equal', () {
      expect(renamed(), renamed());
      expect(renamed().hashCode, renamed().hashCode);
    });

    test('should differ when the streets differ', () {
      expect(renamed(), isNot(renamed(streetId: gambetta)));
    });

    test('should differ when the old names differ', () {
      expect(renamed(), isNot(renamed(before: streetName('Rue des Roses'))));
    });

    test('should differ when the new names differ', () {
      expect(renamed(), isNot(renamed(name: streetName('Impasse des Lilas'))));
    });

    test('should show both names when printed', () {
      expect(
        renamed().toString(),
        'StreetRenamed(rue-des-lilas, Rue des Lilas → Allée des Lilas)',
      );
    });
  });
}
