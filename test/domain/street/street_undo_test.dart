// Street.undo: every change the screens offer to cancel (« Annuler » of the
// snackbar) puts back exactly what was there before (PLAN §7).
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
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

/// Number 5: « repasser » with a hint, Paul's last change and a position.
/// Number 7: to do. Number 8: a building RdC 01 02, door 01 done.
final _five = House(
  number: n('5'),
  status: VisitStatus.comeBack,
  comeBack: comeBack('après 19h'),
  lastChange: paulAtThree,
  position: townHallDoor,
);
final _seven = House(number: n('7'));
final _doorOne = Dwelling(
  label: d('01'),
  status: VisitStatus.done,
  lastChange: paulAtThree,
);
final _eight = House(
  number: n('8'),
  building: building(topFloor: 0, doors: 2).withDwelling(escA, 0, _doorOne),
);
final _street = valueOf(
  Street.create(
    id: _lilas,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [_five, _seven, _eight],
  ),
);

DwellingKey _rdc(String label) => DwellingKey(escA, 0, d(label));

/// The house numbered [label] in [street].
House _house(Street street, String label) =>
    street.houses.singleWhere((house) => house.number == n(label));

/// Runs [command] on [street] and undoes its change on the street it made.
(Street, StreetChange) _undone<C extends StreetChange, F>(
  Street street,
  Result<(Street, C), F> Function(Street) command,
) {
  final (changed, change) = valueOf(command(street));
  return valueOf(changed.undo(change));
}

void main() {
  group('house changes', () {
    test('should put the exact house back when a mark is undone', () {
      final (street, change) = _undone(
        _street,
        (s) => s.markHouse(n('5'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(_house(street, '5'), _five);
      expect(
        change,
        HouseReverted(
          streetId: _lilas,
          replaced: House(
            number: n('5'),
            status: VisitStatus.done,
            lastChange: leaAtTwo,
            position: townHallDoor,
          ),
          house: _five,
        ),
      );
    });

    test('should put the come-back back when its change is undone', () {
      final (street, _) = _undone(
        _street,
        (s) => s.setComeBack(n('5'), comeBack('samedi'), by: lea, at: twoPm),
      );

      expect(_house(street, '5'), _five);
    });

    test('should leave the other houses as they are when undoing', () {
      final (marked, change) = valueOf(
        _street.markHouse(n('5'), VisitStatus.done, by: lea, at: twoPm),
      );
      final (both, _) = valueOf(
        marked.markHouse(n('7'), VisitStatus.done, by: paul, at: threePm),
      );

      final (street, _) = valueOf(both.undo(change));

      expect(_house(street, '5'), _five);
      expect(_house(street, '7').status, VisitStatus.done);
      expect(_house(street, '7').lastChange, paulAtThree);
    });

    test('should put the whole house back when it changed again since', () {
      final (marked, change) = valueOf(
        _street.markHouse(n('5'), VisitStatus.done, by: lea, at: twoPm),
      );
      final (markedAgain, _) = valueOf(
        marked.markHouse(n('5'), VisitStatus.nobodyHome, by: paul, at: threePm),
      );

      final (street, _) = valueOf(markedAgain.undo(change));

      expect(_house(street, '5'), _five);
    });

    test('should refuse when the house was removed since', () {
      final (marked, change) = valueOf(
        _street.markHouse(n('5'), VisitStatus.done, by: lea, at: twoPm),
      );
      final (removed, _) = valueOf(
        marked.removeNumber(n('5'), by: paul, at: threePm),
      );

      expect(failureOf(removed.undo(change)), UndoFailure.gone);
    });

    test('should refuse when the change is about another street', () {
      final (_, change) = valueOf(
        _street.markHouse(n('5'), VisitStatus.done, by: lea, at: twoPm),
      );
      final other = valueOf(
        Street.create(
          id: StreetId('rue-gambetta'),
          name: 'Rue Gambetta',
          commune: villefranche,
          houses: [_five],
        ),
      );

      expect(failureOf(other.undo(change)), UndoFailure.otherStreet);
    });
  });

  group('building changes', () {
    test('should put the single house back when a layout is undone', () {
      final (street, _) = _undone(
        _street,
        (s) => s.describeBuilding(n('5'), plan(), by: lea, at: twoPm),
      );

      expect(_house(street, '5'), _five);
    });

    test('should put a removed door back with its marks', () {
      final (street, _) = _undone(
        _street,
        (s) => s.removeDoor(n('8'), _rdc('01'), by: lea, at: twoPm),
      );

      expect(_house(street, '8'), _eight);
      expect(_house(street, '8').building!.dwellingAt(_rdc('01')), _doorOne);
    });

    test(
      'should put the building back when going back to a house is undone',
      () {
        final (street, _) = _undone(
          _street,
          (s) => s.removeBuilding(n('8'), by: lea, at: twoPm),
        );

        expect(_house(street, '8'), _eight);
      },
    );
  });

  group('door changes', () {
    test('should put the exact door back when its mark is undone', () {
      final (street, change) = _undone(
        _street,
        (s) => s.markDwelling(
          n('8'),
          _rdc('01'),
          VisitStatus.nobodyHome,
          by: lea,
          at: twoPm,
        ),
      );

      expect(_house(street, '8'), _eight);
      expect(
        change,
        DwellingReverted(
          streetId: _lilas,
          number: n('8'),
          staircase: escA,
          level: 0,
          replaced: Dwelling(
            label: d('01'),
            status: VisitStatus.nobodyHome,
            lastChange: leaAtTwo,
          ),
          dwelling: _doorOne,
        ),
      );
    });

    test('should put the door back when its come-back is undone', () {
      final (comingBack, _) = valueOf(
        _street.markDwelling(
          n('8'),
          _rdc('02'),
          VisitStatus.comeBack,
          by: paul,
          at: threePm,
        ),
      );

      final (street, _) = _undone(
        comingBack,
        (s) => s.setDwellingComeBack(
          n('8'),
          _rdc('02'),
          comeBack('samedi'),
          by: lea,
          at: twoPm,
        ),
      );

      expect(_house(street, '8'), _house(comingBack, '8'));
    });

    test('should put the hint back when leaving « repasser » is undone', () {
      final (comingBack, _) = valueOf(
        _street.markDwelling(
          n('8'),
          _rdc('02'),
          VisitStatus.comeBack,
          by: paul,
          at: threePm,
        ),
      );
      final (hinted, _) = valueOf(
        comingBack.setDwellingComeBack(
          n('8'),
          _rdc('02'),
          comeBack('samedi'),
          by: paul,
          at: threePm,
        ),
      );

      final (street, _) = _undone(
        hinted,
        (s) => s.markDwelling(
          n('8'),
          _rdc('02'),
          VisitStatus.toDo,
          by: lea,
          at: twoPm,
        ),
      );

      expect(
        street.houses[2].building!.dwellingAt(_rdc('02'))!.comeBack,
        comeBack('samedi'),
      );
    });

    test('should refuse when the door was removed since', () {
      final (marked, change) = valueOf(
        _street.markDwelling(
          n('8'),
          _rdc('02'),
          VisitStatus.done,
          by: lea,
          at: twoPm,
        ),
      );
      final (removed, _) = valueOf(
        marked.removeDoor(n('8'), _rdc('02'), by: paul, at: threePm),
      );

      expect(failureOf(removed.undo(change)), UndoFailure.gone);
    });

    test('should refuse when the building became a house since', () {
      final (marked, change) = valueOf(
        _street.markDwelling(
          n('8'),
          _rdc('02'),
          VisitStatus.done,
          by: lea,
          at: twoPm,
        ),
      );
      final (single, _) = valueOf(
        marked.removeBuilding(n('8'), by: paul, at: threePm),
      );

      expect(failureOf(single.undo(change)), UndoFailure.gone);
    });

    test('should refuse when the building was removed since', () {
      final (marked, change) = valueOf(
        _street.markDwelling(
          n('8'),
          _rdc('02'),
          VisitStatus.done,
          by: lea,
          at: twoPm,
        ),
      );
      final (removed, _) = valueOf(
        marked.removeNumber(n('8'), by: paul, at: threePm),
      );

      expect(failureOf(removed.undo(change)), UndoFailure.gone);
    });

    test('should put the undone door back again when the undo is undone', () {
      final (marked, change) = valueOf(
        _street.markDwelling(
          n('8'),
          _rdc('02'),
          VisitStatus.done,
          by: lea,
          at: twoPm,
        ),
      );
      final (undone, undo) = valueOf(marked.undo(change));

      final (street, redo) = valueOf(undone.undo(undo));

      expect(_house(street, '8'), _house(marked, '8'));
      expect(redo, isA<DwellingReverted>());
    });
  });

  group('numbers', () {
    test(
      'should give the house its old number back when renaming is undone',
      () {
        final (street, change) = _undone(
          _street,
          (s) => s.renameNumber(n('5'), n('5bis'), by: lea, at: twoPm),
        );

        expect(_house(street, '5'), _five);
        expect(street.houses.map((house) => house.number), [
          n('5'),
          n('7'),
          n('8'),
        ]);
        expect(change, isA<HouseReverted>());
        expect((change as HouseReverted).renumbers, isTrue);
      },
    );

    test('should refuse to rename back when the old number is shown again', () {
      final (renamed, change) = valueOf(
        _street.renameNumber(n('5'), n('5bis'), by: lea, at: twoPm),
      );
      final (added, _) = valueOf(renamed.addNumbers([n('5')]));

      expect(failureOf(added.undo(change)), UndoFailure.numberTaken);
    });

    test('should refuse to rename back when the old number is removed', () {
      final (renamed, change) = valueOf(
        _street.renameNumber(n('5'), n('5bis'), by: lea, at: twoPm),
      );
      final (added, _) = valueOf(renamed.addNumbers([n('5')]));
      final (removed, _) = valueOf(
        added.removeNumber(n('5'), by: paul, at: threePm),
      );

      expect(failureOf(removed.undo(change)), UndoFailure.numberTaken);
    });

    test('should refuse to rename back when the new number is gone', () {
      final (renamed, change) = valueOf(
        _street.renameNumber(n('5'), n('5bis'), by: lea, at: twoPm),
      );
      final (removed, _) = valueOf(
        renamed.removeNumber(n('5bis'), by: paul, at: threePm),
      );

      expect(failureOf(removed.undo(change)), UndoFailure.gone);
    });

    test('should rename again when the undone renaming is undone', () {
      final (renamed, change) = valueOf(
        _street.renameNumber(n('5'), n('5bis'), by: lea, at: twoPm),
      );
      final (undone, undo) = valueOf(renamed.undo(change));

      final (street, _) = valueOf(undone.undo(undo));

      expect(street.houses, renamed.houses);
    });

    test('should refuse to redo a renaming when the number is taken again', () {
      final (renamed, change) = valueOf(
        _street.renameNumber(n('5'), n('5bis'), by: lea, at: twoPm),
      );
      final (undone, undo) = valueOf(renamed.undo(change));
      final (added, _) = valueOf(undone.addNumbers([n('5bis')]));

      expect(failureOf(added.undo(undo)), UndoFailure.numberTaken);
    });

    test('should bring a removed number back with its marks', () {
      final (street, change) = _undone(
        _street,
        (s) => s.removeNumber(n('5'), by: lea, at: twoPm),
      );

      expect(street.houses, _street.houses);
      expect(street.removedHouses, isEmpty);
      expect(
        change,
        NumberRestored(
          streetId: _lilas,
          removed: RemovedHouse(house: _five, removal: leaAtTwo),
        ),
      );
    });

    test(
      'should refuse to bring a number back when it is no longer removed',
      () {
        final (removed, change) = valueOf(
          _street.removeNumber(n('5'), by: lea, at: twoPm),
        );
        final (restored, _) = valueOf(removed.restoreNumber(n('5')));

        expect(failureOf(restored.undo(change)), UndoFailure.gone);
      },
    );

    test('should send a restored number back with its old removal', () {
      final (removed, _) = valueOf(
        _street.removeNumber(n('5'), by: lea, at: twoPm),
      );

      final (street, change) = _undone(removed, (s) => s.restoreNumber(n('5')));

      expect(street.removedHouses, removed.removedHouses);
      expect(street.houses, removed.houses);
      expect(
        change,
        NumberRemoved(
          streetId: _lilas,
          removed: RemovedHouse(house: _five, removal: leaAtTwo),
        ),
      );
    });

    test('should refuse to send a number back when it is no longer shown', () {
      final (removed, _) = valueOf(
        _street.removeNumber(n('5'), by: lea, at: twoPm),
      );
      final (restored, change) = valueOf(removed.restoreNumber(n('5')));
      final (renamed, _) = valueOf(
        restored.renameNumber(n('5'), n('5A'), by: paul, at: threePm),
      );

      expect(failureOf(renamed.undo(change)), UndoFailure.gone);
    });

    test('should refuse to undo added numbers', () {
      final (added, change) = valueOf(_street.addNumbers([n('9')]));

      expect(failureOf(added.undo(change)), UndoFailure.notUndoable);
    });
  });

  group('street changes', () {
    test('should give the street its old name back', () {
      final (renamed, change) = _street.renameStreet(
        valueOf(StreetName.create('Rue des Roses')),
      );

      final (street, undo) = valueOf(renamed.undo(change));

      expect(street.name, 'Rue des Lilas');
      expect(
        undo,
        StreetRenamed(
          streetId: _lilas,
          before: 'Rue des Roses',
          name: 'Rue des Lilas',
        ),
      );
      expect(street.houses, _street.houses);
    });

    test('should bring a deleted street back', () {
      final (deleted, change) = _street.delete(by: lea, at: twoPm);

      final (street, undo) = valueOf(deleted.undo(change));

      expect(street.isDeleted, isFalse);
      expect(undo, StreetRestored(streetId: _lilas));
    });

    test('should refuse to undo a restoration of the street', () {
      final (deleted, _) = _street.delete(by: lea, at: twoPm);
      final (restored, change) = deleted.restore();

      expect(failureOf(restored.undo(change)), UndoFailure.notUndoable);
    });
  });
}
