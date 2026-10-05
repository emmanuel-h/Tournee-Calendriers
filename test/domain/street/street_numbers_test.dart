// The edit-mode commands of the Street aggregate (PLAN §5.5, §5.11): the
// manual street, adding, removing, restoring and renaming numbers, and
// renaming the street. House commands are in street_test.dart.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');

/// A street of Villefranche-sur-Saône holding [houses] and [removed].
Street _street(List<House> houses, {List<RemovedHouse> removed = const []}) =>
    valueOf(
      Street.create(
        id: _lilas,
        name: 'Rue des Lilas',
        commune: villefranche,
        banId: BanStreetId('69264_0420'),
        houses: houses,
        removedHouses: removed,
        deletion: paulAtThree,
      ),
    );

StreetName _name(String text) => valueOf(StreetName.create(text));

List<String> _labels(Iterable<House> houses) => [
  for (final house in houses) house.number.label,
];

List<HouseNumber> _numbers(List<String> labels) => [
  for (final label in labels) n(label),
];

/// 3 nobody home, 4 new, 5 done.
final _three = House(
  number: n('3'),
  status: VisitStatus.nobodyHome,
  comeBack: comeBack('après 19h'),
  lastChange: leaAtTwo,
);
final _four = House(number: n('4'));
final _five = House(
  number: n('5'),
  status: VisitStatus.done,
  lastChange: leaAtTwo,
);

/// 14ter, done, removed by Léa.
final _fourteenTer = RemovedHouse(
  house: House(
    number: n('14ter'),
    status: VisitStatus.done,
    lastChange: paulAtThree,
  ),
  removal: leaAtTwo,
);

void main() {
  group('create with removed houses', () {
    test('should keep the removed houses apart, sorted by number', () {
      final seven = RemovedHouse(
        house: House(number: n('7')),
        removal: leaAtTwo,
      );
      final street = _street([_four], removed: [_fourteenTer, seven]);

      expect(street.houses, [_four]);
      expect(street.removedHouses, [seven, _fourteenTer]);
    });

    test('should have no removed house by default', () {
      expect(_street([_four]).removedHouses, isEmpty);
    });

    test('should refuse a removed house with the number of a shown one', () {
      final four = RemovedHouse(
        house: House(number: n('4')),
        removal: leaAtTwo,
      );

      expect(
        failureOf(
          Street.create(
            id: _lilas,
            name: 'Rue des Lilas',
            commune: villefranche,
            houses: [_three, _four],
            removedHouses: [four],
          ),
        ),
        NewStreetFailure.duplicateHouseNumber,
      );
    });

    test('should refuse two removed houses with the same number', () {
      expect(
        failureOf(
          Street.create(
            id: _lilas,
            name: 'Rue des Lilas',
            commune: villefranche,
            removedHouses: [_fourteenTer, _fourteenTer],
          ),
        ),
        NewStreetFailure.duplicateHouseNumber,
      );
    });

    test('should refuse to have its removed houses modified', () {
      final street = _street([], removed: [_fourteenTer]);

      expect(street.removedHouses.clear, throwsUnsupportedError);
    });

    test('should leave the removed houses out of the sides and the '
        'progress', () {
      final street = _street([_four, _five], removed: [_fourteenTer]);

      expect(_labels(street.evenHouses), ['4']);
      expect(_labels(street.oddHouses), ['5']);
      expect(
        street.progress,
        Progress.of(VisitStatus.done) + Progress.of(VisitStatus.toDo),
      );
    });

    test('should refuse to mark a removed house', () {
      final street = _street([_four], removed: [_fourteenTer]);

      expect(
        failureOf(
          street.markHouse(n('14ter'), VisitStatus.toDo, by: lea, at: twoPm),
        ),
        HouseChangeFailure.unknownHouse,
      );
    });
  });

  group('create with a name', () {
    test('should clean the name like a typed street name', () {
      final street = valueOf(
        Street.create(
          id: _lilas,
          name: ' Rue  des Lilas ',
          commune: villefranche,
        ),
      );

      expect(street.name, 'Rue des Lilas');
    });

    test('should refuse a blank name', () {
      expect(
        failureOf(Street.create(id: _lilas, name: '  ', commune: villefranche)),
        NewStreetFailure.invalidName,
      );
    });

    test('should accept a name of 150 characters', () {
      expect(
        valueOf(
          Street.create(id: _lilas, name: 'a' * 150, commune: villefranche),
        ).name,
        'a' * 150,
      );
    });

    test('should refuse a name of 151 characters', () {
      expect(
        failureOf(
          Street.create(id: _lilas, name: 'a' * 151, commune: villefranche),
        ),
        NewStreetFailure.invalidName,
      );
    });
  });

  group('manual', () {
    Street manual(List<String> labels) => Street.manual(
      id: _lilas,
      name: _name('Chemin des Vignes'),
      commune: villefranche,
      numbers: _numbers(labels),
    );

    test('should be a street of the commune with no BAN id', () {
      final street = manual(['1']);

      expect(street.id, _lilas);
      expect(street.name, 'Chemin des Vignes');
      expect(street.commune, villefranche);
      expect(street.banId, isNull);
      expect(street.isDeleted, isFalse);
      expect(street.removedHouses, isEmpty);
    });

    test('should have one new house per number, in street order', () {
      final street = manual(['14ter', '2', '1', '12bis']);

      expect(street.houses, [
        House(number: n('1')),
        House(number: n('2')),
        House(number: n('12bis')),
        House(number: n('14ter')),
      ]);
    });

    test('should take the numbers of the manual form', () {
      final numbers = valueOf(
        manualStreetNumbers(
          from: '1',
          to: '57',
          sides: Sides.both,
          extras: '12bis, 14ter',
        ),
      );

      final street = Street.manual(
        id: _lilas,
        name: _name('Chemin des Vignes'),
        commune: villefranche,
        numbers: numbers,
      );

      expect(street.houses.length, 59);
      expect(street.progress.toDo, 59);
    });

    test('should keep each number once when given twice', () {
      expect(_labels(manual(['3', '3 ', '3bis']).houses), ['3', '3bis']);
    });

    test('should have no house when given no number', () {
      expect(manual([]).houses, isEmpty);
    });

    test('should refuse to have its houses modified', () {
      expect(() => manual(['1']).houses.clear(), throwsUnsupportedError);
    });
  });

  group('addNumbers', () {
    final street = _street([_three, _four], removed: [_fourteenTer]);

    test('should add new houses on the right side, in order', () {
      final (changed, change) = valueOf(
        street.addNumbers(_numbers(['21', '2', '3bis'])),
      );

      expect(_labels(changed.houses), ['2', '3', '3bis', '4', '21']);
      expect(_labels(changed.oddHouses), ['3', '3bis', '21']);
      expect(_labels(changed.evenHouses), ['2', '4']);
      expect(changed.houses[0], House(number: n('2')));
      expect(
        change,
        NumbersAdded(
          streetId: _lilas,
          added: [
            House(number: n('2')),
            House(number: n('3bis')),
            House(number: n('21')),
          ],
          restored: const [],
          alreadyThere: const [],
        ),
      );
    });

    test('should leave the numbers already there untouched and say so', () {
      final (changed, change) = valueOf(
        street.addNumbers(_numbers(['3', '6'])),
      );

      expect(changed.houses, [_three, _four, House(number: n('6'))]);
      expect(change.added, [House(number: n('6'))]);
      expect(change.alreadyThere, [n('3')]);
    });

    test('should bring a removed number back with its marks', () {
      final (changed, change) = valueOf(
        street.addNumbers(_numbers(['14ter', '6'])),
      );

      expect(changed.houses, [
        _three,
        _four,
        House(number: n('6')),
        _fourteenTer.house,
      ]);
      expect(changed.removedHouses, isEmpty);
      expect(change.restored, [_fourteenTer]);
      expect(change.added, [House(number: n('6'))]);
    });

    test('should leave the other removed numbers in the Corbeille', () {
      final seven = RemovedHouse(
        house: House(number: n('7')),
        removal: paulAtThree,
      );
      final (changed, _) = valueOf(
        _street([_four], removed: [seven, _fourteenTer]).addNumbers([n('7')]),
      );

      expect(changed.removedHouses, [_fourteenTer]);
      expect(_labels(changed.houses), ['4', '7']);
    });

    test('should succeed when the only number was removed', () {
      final (changed, change) = valueOf(street.addNumbers([n('14ter')]));

      expect(changed.houses.last, _fourteenTer.house);
      expect(change.added, isEmpty);
      expect(change.restored, [_fourteenTer]);
    });

    test('should add each number once when given twice', () {
      final (changed, change) = valueOf(
        street.addNumbers(_numbers(['6', '6', '6 '])),
      );

      expect(_labels(changed.houses), ['3', '4', '6']);
      expect(change.added, [House(number: n('6'))]);
    });

    test('should keep the street identity and deletion', () {
      final (changed, _) = valueOf(street.addNumbers([n('6')]));

      expect(changed.id, _lilas);
      expect(changed.name, 'Rue des Lilas');
      expect(changed.commune, villefranche);
      expect(changed.banId, BanStreetId('69264_0420'));
      expect(changed.deletion, paulAtThree);
    });

    test('should fail when every number is already there', () {
      expect(
        failureOf(street.addNumbers(_numbers(['3', '4']))),
        NumberChangeFailure.nothingNew,
      );
    });

    test('should fail when given no number', () {
      expect(failureOf(street.addNumbers([])), NumberChangeFailure.nothingNew);
    });

    test('should refuse to have its houses modified after adding', () {
      final (changed, _) = valueOf(street.addNumbers([n('6')]));

      expect(changed.houses.clear, throwsUnsupportedError);
    });
  });

  group('removeNumber', () {
    final street = _street([_three, _four, _five]);

    test('should hide the house with who removed it and when', () {
      final (changed, change) = valueOf(
        street.removeNumber(n('3'), by: paul, at: threePm),
      );

      final removed = RemovedHouse(house: _three, removal: paulAtThree);
      expect(changed.houses, [_four, _five]);
      expect(changed.removedHouses, [removed]);
      expect(change, NumberRemoved(streetId: _lilas, removed: removed));
    });

    test('should take the house out of the sides and the progress', () {
      final (changed, _) = valueOf(
        street.removeNumber(n('5'), by: paul, at: threePm),
      );

      expect(_labels(changed.oddHouses), ['3']);
      expect(changed.progress.total, 2);
      expect(changed.progress.done, 0);
    });

    test('should say the house had marks when it had some', () {
      final (_, change) = valueOf(
        street.removeNumber(n('3'), by: paul, at: threePm),
      );

      expect(change.hadMarks, isTrue);
    });

    test('should say the house had no mark when it had none', () {
      final (_, change) = valueOf(
        street.removeNumber(n('4'), by: paul, at: threePm),
      );

      expect(change.hadMarks, isFalse);
    });

    test('should keep a building and its doors when removing it', () {
      final eight = House(
        number: n('8'),
        building: building(topFloor: 0, doors: 1).withDwelling(
          escA,
          0,
          Dwelling(label: d('01'), status: VisitStatus.done),
        ),
      );
      final (changed, change) = valueOf(
        _street([eight]).removeNumber(n('8'), by: lea, at: twoPm),
      );

      expect(changed.houses, isEmpty);
      expect(changed.removedHouses.single.house, eight);
      expect(change.hadMarks, isTrue);
    });

    test('should keep the other removed houses in number order', () {
      final (changed, _) = valueOf(
        _street(
          [_three],
          removed: [_fourteenTer],
        ).removeNumber(n('3'), by: paul, at: threePm),
      );

      expect(changed.removedHouses, [
        RemovedHouse(house: _three, removal: paulAtThree),
        _fourteenTer,
      ]);
    });

    test('should keep the street identity and deletion', () {
      final (changed, _) = valueOf(
        street.removeNumber(n('4'), by: paul, at: threePm),
      );

      expect(changed.id, _lilas);
      expect(changed.name, 'Rue des Lilas');
      expect(changed.deletion, paulAtThree);
    });

    test('should fail when the street shows no such number', () {
      expect(
        failureOf(street.removeNumber(n('7'), by: paul, at: threePm)),
        NumberChangeFailure.unknownHouse,
      );
    });

    test('should fail when the number is already removed', () {
      expect(
        failureOf(
          _street(
            [],
            removed: [_fourteenTer],
          ).removeNumber(n('14ter'), by: paul, at: threePm),
        ),
        NumberChangeFailure.unknownHouse,
      );
    });
  });

  group('restoreNumber', () {
    final street = _street([_three, _four], removed: [_fourteenTer]);

    test('should bring the house back with its status', () {
      final (changed, change) = valueOf(street.restoreNumber(n('14ter')));

      expect(changed.houses, [_three, _four, _fourteenTer.house]);
      expect(changed.houses.last.status, VisitStatus.done);
      expect(changed.removedHouses, isEmpty);
      expect(change, NumberRestored(streetId: _lilas, removed: _fourteenTer));
    });

    test('should leave the other removed numbers in the Corbeille', () {
      final seven = RemovedHouse(
        house: House(number: n('7')),
        removal: paulAtThree,
      );
      final (changed, _) = valueOf(
        _street([], removed: [seven, _fourteenTer]).restoreNumber(n('14ter')),
      );

      expect(changed.removedHouses, [seven]);
      expect(changed.houses, [_fourteenTer.house]);
    });

    test('should undo a removal exactly', () {
      final (removed, _) = valueOf(
        street.removeNumber(n('3'), by: paul, at: threePm),
      );

      final (restored, _) = valueOf(removed.restoreNumber(n('3')));

      expect(restored.houses, street.houses);
      expect(restored.removedHouses, street.removedHouses);
      expect(restored.progress, street.progress);
    });

    test('should keep the street identity and deletion', () {
      final (changed, _) = valueOf(street.restoreNumber(n('14ter')));

      expect(changed.id, _lilas);
      expect(changed.name, 'Rue des Lilas');
      expect(changed.deletion, paulAtThree);
    });

    test('should fail when the number is shown, not removed', () {
      expect(
        failureOf(street.restoreNumber(n('3'))),
        NumberChangeFailure.notRemoved,
      );
    });

    test('should fail when the street has no such number at all', () {
      expect(
        failureOf(street.restoreNumber(n('99'))),
        NumberChangeFailure.notRemoved,
      );
    });
  });

  group('renameNumber', () {
    final street = _street([_three, _four, _five], removed: [_fourteenTer]);

    test('should give the house its new number with its marks', () {
      final (changed, change) = valueOf(
        street.renameNumber(n('3'), n('3bis'), by: paul, at: threePm),
      );

      final renamed = House(
        number: n('3bis'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('après 19h'),
        lastChange: paulAtThree,
      );
      expect(changed.houses, [renamed, _four, _five]);
      expect(
        change,
        NumberRenamed(
          streetId: _lilas,
          before: _three,
          stamp: paulAtThree,
          newNumber: n('3bis'),
        ),
      );
    });

    test('should move the house to its new place and side', () {
      final (changed, _) = valueOf(
        street.renameNumber(n('3'), n('6'), by: paul, at: threePm),
      );

      expect(_labels(changed.houses), ['4', '5', '6']);
      expect(_labels(changed.evenHouses), ['4', '6']);
      expect(_labels(changed.oddHouses), ['5']);
    });

    test('should keep the building of the house', () {
      final eight = House(number: n('8'), building: building());
      final (changed, _) = valueOf(
        _street([eight]).renameNumber(n('8'), n('8A'), by: lea, at: twoPm),
      );

      expect(changed.houses.single.building, building());
      expect(changed.houses.single.number, n('8A'));
    });

    test('should keep the removed houses and the street identity', () {
      final (changed, _) = valueOf(
        street.renameNumber(n('4'), n('2'), by: paul, at: threePm),
      );

      expect(changed.removedHouses, [_fourteenTer]);
      expect(changed.id, _lilas);
      expect(changed.deletion, paulAtThree);
    });

    test('should fail when the street shows no such number', () {
      expect(
        failureOf(street.renameNumber(n('7'), n('7bis'), by: lea, at: twoPm)),
        NumberChangeFailure.unknownHouse,
      );
    });

    test('should fail when the new number is the same', () {
      expect(
        failureOf(street.renameNumber(n('3'), n('3'), by: lea, at: twoPm)),
        NumberChangeFailure.sameNumber,
      );
    });

    test('should fail when another house has the new number', () {
      expect(
        failureOf(street.renameNumber(n('3'), n('5'), by: lea, at: twoPm)),
        NumberChangeFailure.numberTaken,
      );
    });

    test('should fail when a removed house has the new number', () {
      expect(
        failureOf(street.renameNumber(n('3'), n('14ter'), by: lea, at: twoPm)),
        NumberChangeFailure.numberRemoved,
      );
    });
  });

  group('renameStreet', () {
    final street = _street([_three], removed: [_fourteenTer]);

    test('should give the street the new name and say what it was', () {
      final (changed, change) = street.renameStreet(_name('Allée des Lilas'));

      expect(changed.name, 'Allée des Lilas');
      expect(
        change,
        StreetRenamed(
          streetId: _lilas,
          before: 'Rue des Lilas',
          name: 'Allée des Lilas',
        ),
      );
    });

    test('should keep everything else', () {
      final (changed, _) = street.renameStreet(_name('Allée des Lilas'));

      expect(changed.id, _lilas);
      expect(changed.commune, villefranche);
      expect(changed.banId, BanStreetId('69264_0420'));
      expect(changed.houses, [_three]);
      expect(changed.removedHouses, [_fourteenTer]);
      expect(changed.deletion, paulAtThree);
    });

    test('should leave the original street with its name', () {
      street.renameStreet(_name('Allée des Lilas'));

      expect(street.name, 'Rue des Lilas');
    });
  });

  group('commands keep the removed houses', () {
    final street = _street([_four], removed: [_fourteenTer]);

    test('should keep them when a house is marked', () {
      final (changed, _) = valueOf(
        street.markHouse(n('4'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(changed.removedHouses, [_fourteenTer]);
    });

    test('should keep them when the street is deleted and restored', () {
      final (deleted, _) = street.delete(by: lea, at: twoPm);
      final (restored, _) = deleted.restore();

      expect(deleted.removedHouses, [_fourteenTer]);
      expect(restored.removedHouses, [_fourteenTer]);
    });
  });
}
