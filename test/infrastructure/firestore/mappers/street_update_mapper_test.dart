// Each change of a street becomes a Firestore update of the fields it names
// only (PLAN §6.2), so two people changing different houses or doors never
// overwrite each other.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_update_mapper.dart';

import '../../../support/building_fixtures.dart';
import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';
import '../../local_storage/stored_street_fixtures.dart';

/// What the test passes for « remove this field » (the adapter passes
/// `FieldValue.delete()`).
const removed = #removed;

/// Who undoes, and when: Manu, at four.
final manu = MemberId('manu');
final fourPm = DateTime.utc(2026, 11, 2, 16);
final manuAtFour = ChangeStamp(by: manu, at: fourPm);

FieldPath house(String label, [List<String> rest = const []]) =>
    FieldPath(['houses', label, ...rest]);

FieldPath door(String label, String key, String field) =>
    FieldPath(['houses', label, 'dwellings', key, field]);

Timestamp at(DateTime time) => Timestamp.fromDate(time);

/// The update storing the change [command] makes on [street].
Map<FieldPath, Object?> updateOf<C extends StreetChange, F>(
  Street street,
  Result<(Street, C), F> Function(Street street) command,
) {
  final (changed, change) = valueOf(command(street));
  return streetUpdate(changed, change, undoStamp: manuAtFour, removal: removed);
}

/// The update storing the undo of the change [command] makes on [street].
Map<FieldPath, Object?> undoOf<C extends StreetChange, F>(
  Street street,
  Result<(Street, C), F> Function(Street street) command,
) {
  final (changed, change) = valueOf(command(street));
  return updateOf(changed, (street) => street.undo(change));
}

/// A street with a single house 4 and building 8 of two staircases, out of
/// the Corbeille.
final lilas = valueOf(
  Street.create(
    id: richStreet.id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('4'), status: VisitStatus.done, lastChange: leaAtTwo),
      House(
        number: n('8'),
        comeBack: comeBack('gardien'),
        building: twoStaircases,
        position: townHallDoor,
      ),
      House(number: n('10'), building: unknownFloors),
    ],
    removedHouses: [removedFourteen],
  ),
);

void main() {
  group('house', () {
    test('should write the status, the hint and the stamp of a mark', () {
      final update = updateOf(
        lilas,
        (s) =>
            s.markHouse(n('4'), VisitStatus.nobodyHome, by: paul, at: threePm),
      );

      expect(update, {
        house('4', ['status']): 'NOBODY_HOME',
        house('4', ['comeBack']): null,
        house('4', ['by']): 'paul',
        house('4', ['at']): at(threePm),
      });
    });

    test('should write an empty hint when a house becomes « repasser »', () {
      final update = updateOf(
        lilas,
        (s) => s.markHouse(n('4'), VisitStatus.comeBack, by: paul, at: threePm),
      );

      expect(update[house('4', ['status'])], 'COME_BACK');
      expect(update[house('4', ['comeBack'])], '');
    });

    test('should write the hint and the stamp of a « repasser »', () {
      final comingBack = valueOf(
        lilas.markHouse(n('4'), VisitStatus.comeBack, by: lea, at: twoPm),
      ).$1;

      final update = updateOf(
        comingBack,
        (s) =>
            s.setComeBack(n('4'), comeBack('après 19h'), by: paul, at: threePm),
      );

      expect(update, {
        house('4', ['comeBack']): 'après 19h',
        house('4', ['by']): 'paul',
        house('4', ['at']): at(threePm),
      });
    });

    test('should write null when a building loses its own « repasser »', () {
      final update = updateOf(
        lilas,
        (s) => s.setComeBack(n('8'), null, by: paul, at: threePm),
      );

      expect(update, {
        house('8', ['comeBack']): null,
        house('8', ['by']): 'paul',
        house('8', ['at']): at(threePm),
      });
    });
  });

  group('door', () {
    test('should write the fields of one door with path segments', () {
      final update = updateOf(
        lilas,
        (s) => s.markDwelling(
          n('8'),
          DwellingKey(escA, 1, d('12')),
          VisitStatus.done,
          by: lea,
          at: twoPm,
        ),
      );

      expect(update, {
        door('8', 'A1-12', 'status'): 'DONE',
        door('8', 'A1-12', 'comeBack'): null,
        door('8', 'A1-12', 'by'): 'lea',
        door('8', 'A1-12', 'at'): at(twoPm),
      });
    });

    test('should keep a dot of a door label inside one segment', () {
      // A typed label may hold a dot, which a dotted path would read as
      // one more level: `houses.10.dwellings.A-Porte 1.2.status`.
      final renamed = valueOf(
        lilas.renameDoor(
          n('10'),
          DwellingKey(escA, null, d('Gauche')),
          d('Porte 1.2'),
          by: lea,
          at: twoPm,
        ),
      ).$1;

      final update = updateOf(
        renamed,
        (s) => s.markDwelling(
          n('10'),
          DwellingKey(escA, null, d('Porte 1.2')),
          VisitStatus.nobodyHome,
          by: paul,
          at: threePm,
        ),
      );

      expect(update.keys.first.components, [
        'houses',
        '10',
        'dwellings',
        'A-Porte 1.2',
        'status',
      ]);
    });

    test('should write the hint and the stamp of a door « repasser »', () {
      final update = updateOf(
        lilas,
        (s) => s.setDwellingComeBack(
          n('8'),
          DwellingKey(escB, 0, d('01')),
          comeBack('samedi'),
          by: paul,
          at: threePm,
        ),
      );

      expect(update, {
        door('8', 'B0-01', 'comeBack'): 'samedi',
        door('8', 'B0-01', 'by'): 'paul',
        door('8', 'B0-01', 'at'): at(threePm),
      });
    });
  });

  group('layout', () {
    test('should write a new building door by door', () {
      final update = updateOf(
        lilas,
        (s) => s.describeBuilding(
          n('4'),
          plan(topFloor: 0, doors: 2),
          by: paul,
          at: threePm,
        ),
      );

      expect(update, {
        house('4', ['status']): 'TO_DO',
        house('4', ['comeBack']): null,
        house('4', ['by']): 'paul',
        house('4', ['at']): at(threePm),
        house('4', ['labelStyle']): 'FLOOR_AND_NUMBER',
        house('4', ['layout']): [
          {
            'esc': 'A',
            'floor': 0,
            'doors': ['01', '02'],
          },
        ],
        house('4', ['dwellings', 'A0-01']): {
          'status': 'TO_DO',
          'comeBack': null,
          'by': null,
          'at': null,
        },
        house('4', ['dwellings', 'A0-02']): {
          'status': 'TO_DO',
          'comeBack': null,
          'by': null,
          'at': null,
        },
      });
    });

    test('should remove the doors a new layout drops and keep the others', () {
      final update = updateOf(
        lilas,
        (s) => s.describeBuilding(
          n('8'),
          plan(topFloor: 1, doors: 1),
          by: paul,
          at: threePm,
        ),
      );

      expect(update[house('8', ['dwellings', 'A1-11'])], {
        'status': 'DONE',
        'comeBack': null,
        'by': 'lea',
        'at': at(twoPm),
      });
      expect(update[house('8', ['dwellings', 'A0-01'])], {
        'status': 'TO_DO',
        'comeBack': null,
        'by': null,
        'at': null,
      });
      expect(update[house('8', ['dwellings', 'A1-12'])], removed);
      expect(update[house('8', ['dwellings', 'B0-01'])], removed);
      expect(update[house('8', ['comeBack'])], 'gardien');
      expect(update[house('8', ['layout'])], [
        {
          'esc': 'A',
          'floor': 1,
          'doors': ['11'],
        },
        {
          'esc': 'A',
          'floor': 0,
          'doors': ['01'],
        },
      ]);
      expect(update.containsKey(house('8', ['dwellings'])), isFalse);
    });

    test('should remove the building fields when it is a house again', () {
      final update = updateOf(
        lilas,
        (s) => s.removeBuilding(n('8'), by: paul, at: threePm),
      );

      expect(update, {
        house('8', ['status']): 'COME_BACK',
        house('8', ['comeBack']): 'gardien',
        house('8', ['by']): 'paul',
        house('8', ['at']): at(threePm),
        house('8', ['labelStyle']): removed,
        house('8', ['layout']): removed,
        house('8', ['dwellings']): removed,
      });
    });
  });

  group('numbers', () {
    test('should write the new houses whole and clear the restored ones', () {
      final update = updateOf(
        lilas,
        (s) => s.addNumbers([n('6'), n('14ter'), n('4')]),
      );

      expect(update, {
        house('6'): houseEntry(House(number: n('6'))),
        house('14ter', ['deletedAt']): null,
        house('14ter', ['deletedBy']): null,
      });
    });

    test('should write who removed a number and when', () {
      final update = updateOf(
        lilas,
        (s) => s.removeNumber(n('4'), by: paul, at: threePm),
      );

      expect(update, {
        house('4', ['deletedAt']): at(threePm),
        house('4', ['deletedBy']): 'paul',
      });
    });

    test('should clear the removal of a restored number', () {
      final update = updateOf(lilas, (s) => s.restoreNumber(n('14ter')));

      expect(update, {
        house('14ter', ['deletedAt']): null,
        house('14ter', ['deletedBy']): null,
      });
    });

    test('should move a renumbered house to its new key', () {
      final update = updateOf(
        lilas,
        (s) => s.renameNumber(n('8'), n('8bis'), by: paul, at: threePm),
      );

      expect(update, {
        house('8'): removed,
        house('8bis'): houseEntry(
          House(
            number: n('8bis'),
            comeBack: comeBack('gardien'),
            lastChange: paulAtThree,
            building: twoStaircases,
            position: townHallDoor,
          ),
        ),
      });
    });
  });

  group('street', () {
    test('should write the new name of the street', () {
      final update = updateOf(
        lilas,
        (s) => Ok<(Street, StreetRenamed), Never>(
          s.renameStreet(streetName('Rue des Roses')),
        ),
      );

      expect(update, {
        FieldPath(const ['name']): 'Rue des Roses',
      });
    });

    test('should write who deleted the street and when', () {
      final update = updateOf(
        lilas,
        (s) =>
            Ok<(Street, StreetDeleted), Never>(s.delete(by: paul, at: threePm)),
      );

      expect(update, {
        FieldPath(const ['deletedAt']): at(threePm),
        FieldPath(const ['deletedBy']): 'paul',
      });
    });

    test('should clear the deletion of a restored street', () {
      final update = updateOf(
        richStreet,
        (s) => Ok<(Street, StreetRestored), Never>(s.restore()),
      );

      expect(update, {
        FieldPath(const ['deletedAt']): null,
        FieldPath(const ['deletedBy']): null,
      });
    });
  });

  group('undo', () {
    test('should stamp the house put back with who undoes and when', () {
      final update = undoOf(
        lilas,
        (s) =>
            s.markHouse(n('4'), VisitStatus.nobodyHome, by: paul, at: threePm),
      );

      // Back to « fait », but stamped by Manu at four, not by Léa at two:
      // the security rules accept only the caller's own stamp (PLAN §8.2).
      expect(update, {
        house('4', ['status']): 'DONE',
        house('4', ['comeBack']): null,
        house('4', ['by']): 'manu',
        house('4', ['at']): at(fourPm),
      });
    });

    test(
      'should put a building back door by door when its removal is undone',
      () {
        final update = undoOf(
          lilas,
          (s) => s.removeBuilding(n('8'), by: paul, at: threePm),
        );

        expect(update[house('8', ['status'])], 'TO_DO');
        expect(update[house('8', ['comeBack'])], 'gardien');
        expect(update[house('8', ['by'])], 'manu');
        expect(update[house('8', ['labelStyle'])], 'FLOOR_AND_NUMBER');
        expect(update[house('8', ['layout'])], layoutOf(twoStaircases));
        // Each door keeps its own last change.
        expect(update[house('8', ['dwellings', 'A1-12'])], {
          'status': 'COME_BACK',
          'comeBack': 'le soir',
          'by': 'paul',
          'at': at(threePm),
        });
        expect(
          update.keys.where((path) => path.components.length == 4),
          hasLength(3),
        );
      },
    );

    test('should remove the building fields when a first layout is undone', () {
      final update = undoOf(
        lilas,
        (s) => s.describeBuilding(n('4'), plan(), by: paul, at: threePm),
      );

      expect(update, {
        house('4', ['status']): 'DONE',
        house('4', ['comeBack']): null,
        house('4', ['by']): 'manu',
        house('4', ['at']): at(fourPm),
        house('4', ['labelStyle']): removed,
        house('4', ['layout']): removed,
        house('4', ['dwellings']): removed,
      });
    });

    test(
      'should move the house back to its old key when a renumbering is undone',
      () {
        final update = undoOf(
          lilas,
          (s) => s.renameNumber(n('4'), n('4bis'), by: paul, at: threePm),
        );

        expect(update, {
          house('4bis'): removed,
          house('4'): houseEntry(
            House(
              number: n('4'),
              status: VisitStatus.done,
              lastChange: manuAtFour,
            ),
          ),
        });
      },
    );

    test('should put the door back whole, stamped with who undoes', () {
      final update = undoOf(
        lilas,
        (s) => s.markDwelling(
          n('8'),
          DwellingKey(escA, 1, d('11')),
          VisitStatus.nobodyHome,
          by: paul,
          at: threePm,
        ),
      );

      expect(update, {
        house('8', ['dwellings', 'A1-11']): {
          'status': 'DONE',
          'comeBack': null,
          'by': 'manu',
          'at': at(fourPm),
        },
      });
    });

    test('should write a removal again when a restore is undone', () {
      final update = undoOf(lilas, (s) => s.restoreNumber(n('14ter')));

      expect(update, {
        house('14ter', ['deletedAt']): at(threePm),
        house('14ter', ['deletedBy']): 'paul',
      });
    });
  });
}
