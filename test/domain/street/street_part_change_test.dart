// The part of a street a secteur holds (PLAN §5.15): stored on the street,
// changed with `Street.changePart`, which moves the numbers left out to the
// Corbeille and brings back those the new part holds.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');

/// Odd numbers 7 to 21 and even numbers 2 to 8.
final _held = part(odd: range(7, 21), even: range(2, 8));

/// A street of Villefranche-sur-Saône holding [houses] and [removed], of
/// the part [held].
Street _street(
  List<House> houses, {
  List<RemovedHouse> removed = const [],
  StreetPart held = StreetPart.whole,
}) => valueOf(
  Street.create(
    id: _lilas,
    name: 'Rue des Lilas',
    commune: villefranche,
    banId: BanStreetId('69264_0420'),
    shape: valueOf(StreetShape.decode(['_p~iF~ps|U_ulLnnqC'])),
    part: held,
    houses: houses,
    removedHouses: removed,
  ),
);

House _house(String label) => House(number: n(label));

House _done(String label) =>
    House(number: n(label), status: VisitStatus.done, lastChange: paulAtThree);

List<String> _labels(Iterable<House> houses) => [
  for (final house in houses) house.number.label,
];

List<String> _removedLabels(Iterable<RemovedHouse> removed) => [
  for (final house in removed) house.number.label,
];

void main() {
  group('part', () {
    test('should be the whole street when none is given', () {
      expect(_street([_house('7')]).part, StreetPart.whole);
    });

    test('should be the part given', () {
      expect(_street([_house('7')], held: _held).part, _held);
    });

    test('should be the whole street on a street typed by hand', () {
      final manual = Street.manual(
        id: _lilas,
        name: streetName('Rue des Lilas'),
        commune: villefranche,
        numbers: [n('1')],
      );

      expect(manual.part, StreetPart.whole);
    });

    test('should be kept by the other commands', () {
      final street = _street([_house('7'), _house('9')], held: _held);

      final (marked, _) = valueOf(
        street.markHouse(n('7'), VisitStatus.done, by: lea, at: twoPm),
      );
      final (removed, _) = valueOf(
        street.removeNumber(n('9'), by: lea, at: twoPm),
      );
      final (renamed, _) = street.renameStreet(streetName('Rue des Roses'));
      final (deleted, _) = street.delete(by: lea, at: twoPm);

      expect(marked.part, _held);
      expect(removed.part, _held);
      expect(renamed.part, _held);
      expect(deleted.part, _held);
      expect(deleted.restore().$1.part, _held);
    });

    test('should be kept when the street gets its shape', () {
      final street = valueOf(
        Street.create(
          id: _lilas,
          name: 'Rue des Lilas',
          commune: villefranche,
          part: _held,
          houses: [_house('7')],
        ),
      );

      final (shaped, _) = valueOf(
        street.fillShape(valueOf(StreetShape.decode(['_p~iF~ps|U_ulLnnqC']))),
      );

      expect(shaped.part, _held);
    });
  });

  group('progress', () {
    test('should count only the numbers held, the part needing no change', () {
      // The numbers outside the part are never stored, so the street of a
      // part counts as a whole street of the same houses.
      final houses = [_done('7'), _house('9'), _done('4')];

      expect(_street(houses, held: _held).progress, _street(houses).progress);
      final progress = _street(houses, held: _held).progress;
      expect(progress.total, 3);
      expect(progress.done, 2);
    });
  });

  group('housesLeftOutBy', () {
    test('should list the houses the old part holds and the new one not', () {
      final street = _street([
        _house('5'),
        _house('7'),
        _house('9'),
        _house('21'),
        _house('2'),
        _house('4'),
      ]);

      final leaving = street.housesLeftOutBy(
        part(odd: range(7, 9), even: SidePart.all),
      );

      expect(_labels(leaving), ['5', '21']);
    });

    test('should leave alone a number held outside the old part', () {
      // 23 was added by hand outside the part: the user chose it.
      final street = _street([_house('7'), _house('23')], held: _held);

      final leaving = street.housesLeftOutBy(
        part(odd: range(7, 9), even: range(2, 8)),
      );

      expect(_labels(leaving), isEmpty);
    });

    test('should list nothing when the new part holds every house', () {
      final street = _street([_house('7'), _house('2')], held: _held);

      expect(street.housesLeftOutBy(StreetPart.whole), isEmpty);
    });
  });

  group('changePart', () {
    test('should store the new part and say which it replaced', () {
      final street = _street([_house('7')]);

      final (changed, change) = valueOf(
        street.changePart(_held, by: lea, at: twoPm),
      );

      expect(changed.part, _held);
      expect(change.before, StreetPart.whole);
      expect(change.part, _held);
      expect(change.streetId, _lilas);
    });

    test('should refuse the part the street holds already', () {
      final street = _street([_house('7')], held: _held);

      expect(
        failureOf(
          street.changePart(
            part(odd: range(7, 21), even: range(2, 8)),
            by: lea,
            at: twoPm,
          ),
        ),
        PartChangeFailure.samePart,
      );
    });

    test('should send the numbers left out to the Corbeille with their '
        'marks', () {
      final street = _street([
        _done('5'),
        _house('7'),
        _house('23'),
        _house('2'),
        _done('10'),
      ]);

      final (changed, change) = valueOf(
        street.changePart(_held, by: lea, at: twoPm),
      );

      expect(_labels(changed.houses), ['2', '7']);
      expect(changed.removedHouses, [
        RemovedHouse(house: _done('5'), removal: leaAtTwo),
        RemovedHouse(house: _done('10'), removal: leaAtTwo),
        RemovedHouse(house: _house('23'), removal: leaAtTwo),
      ]);
      expect(change.removed, changed.removedHouses);
      expect(change.restored, isEmpty);
      expect(change.added, isEmpty);
    });

    test('should keep the numbers of the Corbeille the part leaves out', () {
      final earlier = RemovedHouse(house: _done('25'), removal: paulAtThree);
      final street = _street([_house('7')], removed: [earlier]);

      final (changed, _) = valueOf(
        street.changePart(_held, by: lea, at: twoPm),
      );

      expect(changed.removedHouses, [earlier]);
    });

    test('should bring back from the Corbeille the numbers the new part '
        'holds, with their marks', () {
      final street = _street([_house('7')], held: _held);
      final (shrunk, _) = valueOf(
        street.changePart(
          part(odd: range(7, 21), even: SidePart.none),
          by: lea,
          at: twoPm,
        ),
      );
      final twentyThree = RemovedHouse(
        house: _done('23'),
        removal: paulAtThree,
      );
      final withTwentyThree = _street(
        shrunk.houses,
        removed: [twentyThree],
        held: shrunk.part,
      );

      final (changed, change) = valueOf(
        withTwentyThree.changePart(StreetPart.whole, by: lea, at: twoPm),
      );

      expect(changed.houseAt(n('23')), _done('23'));
      expect(changed.removedHouses, isEmpty);
      expect(change.restored, [twentyThree]);
      expect(change.removed, isEmpty);
    });

    test('should leave in the Corbeille a number removed with ✕ inside the '
        'old part', () {
      // 9 was in the part and removed by hand: widening does not undo it.
      final nine = RemovedHouse(house: _done('9'), removal: paulAtThree);
      final street = _street([_house('7')], removed: [nine], held: _held);

      final (changed, change) = valueOf(
        street.changePart(StreetPart.whole, by: lea, at: twoPm),
      );

      expect(changed.removedHouses, [nine]);
      expect(change.restored, isEmpty);
    });

    test('should add the numbers read that the new part brings in', () {
      final street = _street([_done('7'), _house('2')], held: _held);

      final (changed, change) = valueOf(
        street.changePart(
          part(odd: range(5, 23), even: range(2, 8)),
          fromDirectory: [
            House(number: n('3')),
            House(number: n('5'), position: townHallDoor),
            House(number: n('7')),
            House(number: n('23bis')),
            House(number: n('25')),
            House(number: n('10')),
          ],
          by: lea,
          at: twoPm,
        ),
      );

      expect(_labels(changed.houses), ['2', '5', '7', '23bis']);
      expect(
        changed.houseAt(n('5')),
        House(number: n('5'), position: townHallDoor),
      );
      expect(changed.houseAt(n('7')), _done('7'));
      expect(_labels(change.added), ['5', '23bis']);
    });

    test('should add a number read once, even when given twice', () {
      final street = _street([_house('7')], held: _held);

      final (_, change) = valueOf(
        street.changePart(
          StreetPart.whole,
          fromDirectory: [
            House(number: n('23'), position: townHallDoor),
            House(number: n('23'), position: northDoor),
          ],
          by: lea,
          at: twoPm,
        ),
      );

      expect(change.added, [House(number: n('23'), position: townHallDoor)]);
    });

    test('should add the numbers read as to do, without their marks', () {
      final street = _street([_house('7')], held: _held);

      final (changed, _) = valueOf(
        street.changePart(
          StreetPart.whole,
          fromDirectory: [_done('23')],
          by: lea,
          at: twoPm,
        ),
      );

      expect(changed.houseAt(n('23')), House(number: n('23')));
    });

    test('should not add a number read that is in the Corbeille: it comes '
        'back with its marks', () {
      final twentyThree = RemovedHouse(
        house: _done('23'),
        removal: paulAtThree,
      );
      final street = _street(
        [_house('7')],
        removed: [twentyThree],
        held: _held,
      );

      final (changed, change) = valueOf(
        street.changePart(
          StreetPart.whole,
          fromDirectory: [_house('23')],
          by: lea,
          at: twoPm,
        ),
      );

      expect(changed.houseAt(n('23')), _done('23'));
      expect(change.added, isEmpty);
      expect(change.restored, [twentyThree]);
    });

    test('should not add a number read inside the old part, nor one shown '
        'outside it', () {
      // 9 is inside the old part (gone for good after a purge); 23 was
      // added by hand outside it.
      final street = _street([_house('7'), _done('23')], held: _held);

      final (changed, change) = valueOf(
        street.changePart(
          StreetPart.whole,
          fromDirectory: [_house('9'), _house('23'), _house('25')],
          by: lea,
          at: twoPm,
        ),
      );

      expect(_labels(changed.houses), ['7', '23', '25']);
      expect(changed.houseAt(n('23')), _done('23'));
      expect(_labels(change.added), ['25']);
    });

    test('should move both ways at once and keep each list sorted', () {
      final back = RemovedHouse(house: _done('3'), removal: paulAtThree);
      final street = _street(
        [_house('7'), _house('9'), _house('4')],
        removed: [back],
        held: part(odd: range(7, 9), even: SidePart.all),
      );

      final (changed, change) = valueOf(
        street.changePart(
          part(odd: range(1, 7), even: SidePart.all),
          fromDirectory: [_house('5'), _house('1')],
          by: lea,
          at: twoPm,
        ),
      );

      expect(_labels(changed.houses), ['1', '3', '4', '5', '7']);
      expect(_removedLabels(changed.removedHouses), ['9']);
      expect(_removedLabels(change.removed), ['9']);
      expect(_removedLabels(change.restored), ['3']);
      expect(_labels(change.added), ['1', '5']);
    });

    test('should keep the street otherwise as it was', () {
      final street = _street([_house('7')]);

      final (changed, _) = valueOf(
        street.changePart(_held, by: lea, at: twoPm),
      );

      expect(changed.id, street.id);
      expect(changed.name, street.name);
      expect(changed.commune, street.commune);
      expect(changed.banId, street.banId);
      expect(changed.shape, street.shape);
      expect(changed.deletion, street.deletion);
    });

    test('should keep a street of the Corbeille there', () {
      final (deleted, _) = _street([_house('7')]).delete(by: paul, at: threePm);

      final (changed, _) = valueOf(
        deleted.changePart(_held, by: lea, at: twoPm),
      );

      expect(changed.deletion, paulAtThree);
    });

    test('should not be undone', () {
      final street = _street([_house('7')]);
      final (changed, change) = valueOf(
        street.changePart(_held, by: lea, at: twoPm),
      );

      expect(failureOf(changed.undo(change)), UndoFailure.notUndoable);
    });
  });

  group('StreetPartChanged', () {
    StreetPartChanged change({
      StreetPart before = StreetPart.whole,
      StreetPart? after,
      List<RemovedHouse>? removed,
      List<RemovedHouse> restored = const [],
      List<House> added = const [],
    }) => StreetPartChanged(
      streetId: _lilas,
      before: before,
      part: after ?? _held,
      removed: removed ?? [RemovedHouse(house: _house('5'), removal: leaAtTwo)],
      restored: restored,
      added: added,
    );

    test('should be equal to the same change only', () {
      final back = RemovedHouse(house: _house('23'), removal: paulAtThree);

      expect(change(), change());
      expect(change().hashCode, change().hashCode);
      expect(change(), isNot(change(before: _held, after: StreetPart.whole)));
      expect(change(), isNot(change(after: StreetPart.whole)));
      expect(change(), isNot(change(removed: [])));
      expect(change(), isNot(change(restored: [back])));
      expect(change(), isNot(change(added: [_house('25')])));
      expect(
        change(),
        isNot(
          StreetPartChanged(
            streetId: StreetId('rue-des-roses'),
            before: StreetPart.whole,
            part: _held,
            removed: [RemovedHouse(house: _house('5'), removal: leaAtTwo)],
            restored: const [],
            added: const [],
          ),
        ),
      );
    });

    test('should keep its lists as given', () {
      final added = [_house('25')];
      final given = change(added: added);
      added.add(_house('27'));

      expect(_labels(given.added), ['25']);
    });

    test('should name the numbers it moved', () {
      expect(
        '${change(
          restored: [RemovedHouse(house: _house('23'), removal: paulAtThree)],
          added: [_house('25')],
        )}',
        'StreetPartChanged(rue-des-lilas, StreetPart(odd: all, even: all) → '
            'StreetPart(odd: 7–21, even: 2–8), removed: [5], restored: [23], '
            'added: [25])',
      );
    });
  });
}
