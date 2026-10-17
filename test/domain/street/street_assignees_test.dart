// Who covers a street (« Mes rues », PLAN §5.3, §5.4): a member takes it
// (« Me l'attribuer », « La faire aussi ») or stops (« Ne plus la faire »),
// for themself only, and nothing else of the street changes.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('rue-nationale');
final _shape = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);

/// Rue Nationale, covered by Paul, with house 5 done.
final _nationale = valueOf(
  Street.create(
    id: _id,
    name: 'Rue Nationale',
    commune: villefranche,
    banId: BanStreetId('69264_0900'),
    shape: _shape,
    assignees: {paul},
    houses: [
      House(number: n('5'), status: VisitStatus.done, lastChange: leaAtTwo),
    ],
  ),
);

void main() {
  group('creation', () {
    test('should keep the assignees it is created with', () {
      expect(_nationale.assignees, {paul});
    });

    test('should have no assignee when created without any', () {
      final street = valueOf(
        Street.create(id: _id, name: 'Rue Nationale', commune: villefranche),
      );

      expect(street.assignees, isEmpty);
    });

    test('should have no assignee when typed in by hand without any', () {
      final street = Street.manual(
        id: _id,
        name: streetName('Chemin Neuf'),
        commune: villefranche,
        numbers: [n('1')],
      );

      expect(street.assignees, isEmpty);
    });

    test('should keep the assignees of a street typed in by hand', () {
      final street = Street.manual(
        id: _id,
        name: streetName('Chemin Neuf'),
        commune: villefranche,
        numbers: [n('1')],
        assignees: {lea},
      );

      expect(street.assignees, {lea});
    });

    test('should not let the assignees be changed from outside', () {
      expect(() => _nationale.assignees.add(lea), throwsUnsupportedError);
    });

    test('should not follow a set changed after creation', () {
      final given = {paul};
      final street = valueOf(
        Street.create(
          id: _id,
          name: 'Rue Nationale',
          commune: villefranche,
          assignees: given,
        ),
      );

      given.add(lea);

      expect(street.assignees, {paul});
    });
  });

  group('take', () {
    test('should add the member to the assignees', () {
      final (street, _) = valueOf(_nationale.take(lea));

      expect(street.assignees, {paul, lea});
    });

    test('should say who took which street', () {
      final (_, change) = valueOf(_nationale.take(lea));

      expect(change, StreetTaken(streetId: _id, member: lea));
      expect(change.streetId, _id);
      expect(change.member, lea);
    });

    test('should take a street nobody covers', () {
      final free = valueOf(
        Street.create(id: _id, name: 'Rue Nationale', commune: villefranche),
      );

      final (street, _) = valueOf(free.take(lea));

      expect(street.assignees, {lea});
    });

    test('should refuse a member who already covers it', () {
      expect(
        failureOf(_nationale.take(paul)),
        AssignmentFailure.alreadyAssigned,
      );
    });

    test('should keep everything else of the street', () {
      final (street, _) = valueOf(_nationale.take(lea));

      expect(street.id, _id);
      expect(street.name, streetName('Rue Nationale'));
      expect(street.commune, villefranche);
      expect(street.banId, BanStreetId('69264_0900'));
      expect(street.shape, _shape);
      expect(street.houses, _nationale.houses);
      expect(street.deletion, isNull);
    });

    test('should not let the new assignees be changed from outside', () {
      final (street, _) = valueOf(_nationale.take(lea));

      expect(() => street.assignees.remove(paul), throwsUnsupportedError);
    });
  });

  group('release', () {
    test('should remove the member from the assignees', () {
      final (street, _) = valueOf(_nationale.release(paul));

      expect(street.assignees, isEmpty);
    });

    test('should keep the other assignees', () {
      final (shared, _) = valueOf(_nationale.take(lea));

      final (street, _) = valueOf(shared.release(paul));

      expect(street.assignees, {lea});
    });

    test('should say who released which street', () {
      final (_, change) = valueOf(_nationale.release(paul));

      expect(change, StreetReleased(streetId: _id, member: paul));
      expect(change.member, paul);
    });

    test('should refuse a member who does not cover it', () {
      expect(failureOf(_nationale.release(lea)), AssignmentFailure.notAssigned);
    });

    test('should keep the houses and the shape', () {
      final (street, _) = valueOf(_nationale.release(paul));

      expect(street.houses, _nationale.houses);
      expect(street.shape, _shape);
    });
  });

  group('kept by the other commands', () {
    test('should keep the assignees when a house is marked', () {
      final (street, _) = valueOf(
        _nationale.markHouse(n('5'), VisitStatus.toDo, by: lea, at: twoPm),
      );

      expect(street.assignees, {paul});
    });

    test('should keep the assignees when the street is renamed', () {
      final (street, _) = _nationale.renameStreet(streetName('Rue de la Paix'));

      expect(street.assignees, {paul});
    });

    test('should keep the assignees when the street is deleted', () {
      final (street, _) = _nationale.delete(by: lea, at: twoPm);

      expect(street.assignees, {paul});
    });
  });

  group('undo', () {
    test('should release the member when a take is undone', () {
      final (taken, change) = valueOf(_nationale.take(lea));

      final (street, undo) = valueOf(taken.undo(change));

      expect(street.assignees, {paul});
      expect(undo, StreetReleased(streetId: _id, member: lea));
    });

    test('should take the street back when a release is undone', () {
      final (released, change) = valueOf(_nationale.release(paul));

      final (street, undo) = valueOf(released.undo(change));

      expect(street.assignees, {paul});
      expect(undo, StreetTaken(streetId: _id, member: paul));
    });

    test('should refuse to undo a take already released', () {
      final (taken, change) = valueOf(_nationale.take(lea));
      final (released, _) = valueOf(taken.release(lea));

      expect(failureOf(released.undo(change)), UndoFailure.gone);
    });

    test('should refuse to undo a release already taken back', () {
      final (released, change) = valueOf(_nationale.release(paul));
      final (takenBack, _) = valueOf(released.take(paul));

      expect(failureOf(takenBack.undo(change)), UndoFailure.gone);
    });
  });

  group('restamp', () {
    // The phone's own id of M1 is no member of the tournée the street moves
    // into: the street is covered by the member who moves it instead.
    final phoneId = MemberId('phone42');

    test('should give the street to the member when it was covered', () {
      final covered = valueOf(
        Street.create(
          id: _id,
          name: 'Rue Nationale',
          commune: villefranche,
          assignees: {phoneId},
        ),
      );

      expect(covered.restampedBy(lea).assignees, {lea});
    });

    test('should leave a street nobody covered free', () {
      final free = valueOf(
        Street.create(id: _id, name: 'Rue Nationale', commune: villefranche),
      );

      expect(free.restampedBy(lea).assignees, isEmpty);
    });
  });

  group('changes', () {
    test('should be equal by street and member', () {
      expect(
        StreetTaken(streetId: _id, member: lea),
        StreetTaken(streetId: _id, member: lea),
      );
      expect(
        StreetTaken(streetId: _id, member: lea).hashCode,
        StreetTaken(streetId: _id, member: lea).hashCode,
      );
      expect(
        StreetTaken(streetId: _id, member: lea),
        isNot(StreetTaken(streetId: _id, member: paul)),
      );
      expect(
        StreetTaken(streetId: _id, member: lea),
        isNot(StreetTaken(streetId: StreetId('other'), member: lea)),
      );
      expect(
        StreetTaken(streetId: _id, member: lea),
        isNot(StreetReleased(streetId: _id, member: lea)),
      );
      expect(
        StreetReleased(streetId: _id, member: lea),
        StreetReleased(streetId: _id, member: lea),
      );
      expect(
        StreetReleased(streetId: _id, member: lea).hashCode,
        StreetReleased(streetId: _id, member: lea).hashCode,
      );
      expect(
        StreetReleased(streetId: _id, member: lea),
        isNot(StreetReleased(streetId: _id, member: paul)),
      );
      expect(
        StreetReleased(streetId: _id, member: lea),
        isNot(StreetReleased(streetId: StreetId('other'), member: lea)),
      );
    });

    test('should name the street and the member when printed', () {
      expect(
        '${StreetTaken(streetId: _id, member: lea)}',
        'StreetTaken(rue-nationale, lea)',
      );
      expect(
        '${StreetReleased(streetId: _id, member: lea)}',
        'StreetReleased(rue-nationale, lea)',
      );
    });
  });
}
