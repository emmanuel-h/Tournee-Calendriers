import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');

/// A street of Villefranche-sur-Saône holding [houses], which the test knows
/// are valid.
Street _street(List<House> houses) => valueOf(
  Street.create(
    id: _lilas,
    name: 'Rue des Lilas',
    commune: villefranche,
    banId: BanStreetId('69264_0420'),
    houses: houses,
  ),
);

/// A street whose houses are all new, numbered [labels].
Street _streetOf(List<String> labels) =>
    _street([for (final label in labels) House(number: n(label))]);

List<String> _labels(List<House> houses) => [
  for (final house in houses) house.number.label,
];

void main() {
  group('create', () {
    test('should keep its identity when given it', () {
      final street = _streetOf(['1']);

      expect(street.id, _lilas);
      expect(street.name, 'Rue des Lilas');
      expect(street.commune, villefranche);
      expect(street.banId, BanStreetId('69264_0420'));
      expect(street.deletion, isNull);
      expect(street.isDeleted, isFalse);
    });

    test('should have no BAN id, no house and no deletion by default', () {
      final street = valueOf(
        Street.create(id: _lilas, name: 'Impasse', commune: villefranche),
      );

      expect(street.banId, isNull);
      expect(street.houses, isEmpty);
      expect(street.deletion, isNull);
    });

    test('should be deleted when created with a deletion', () {
      final street = valueOf(
        Street.create(
          id: _lilas,
          name: 'Rue des Lilas',
          commune: villefranche,
          deletion: paulAtThree,
        ),
      );

      expect(street.deletion, paulAtThree);
      expect(street.isDeleted, isTrue);
    });

    test('should sort the houses by number when given out of order', () {
      final street = _streetOf(['4', '3A', '3', '12', '3quater', '3bis', '1']);

      expect(_labels(street.houses), [
        '1',
        '3',
        '3bis',
        '3quater',
        '3A',
        '4',
        '12',
      ]);
    });

    test('should keep each house as given when sorting', () {
      final done = House(
        number: n('7'),
        status: VisitStatus.done,
        lastChange: leaAtTwo,
      );
      final street = _street([done, House(number: n('5'))]);

      expect(street.houses, [House(number: n('5')), done]);
    });

    test('should refuse the houses when two have the same number', () {
      final houses = [
        House(number: n('12bis')),
        House(number: n('3')),
        House(number: n('12 BIS'), status: VisitStatus.done),
      ];

      expect(
        failureOf(
          Street.create(
            id: _lilas,
            name: 'Rue des Lilas',
            commune: villefranche,
            houses: houses,
          ),
        ),
        NewStreetFailure.duplicateHouseNumber,
      );
    });

    test('should refuse the houses when the two lowest numbers are equal', () {
      expect(
        failureOf(
          Street.create(
            id: _lilas,
            name: 'Rue des Lilas',
            commune: villefranche,
            houses: [
              House(number: n('1')),
              House(number: n('1')),
            ],
          ),
        ),
        NewStreetFailure.duplicateHouseNumber,
      );
    });

    test('should accept numbers that differ only by their suffix', () {
      expect(_labels(_streetOf(['12bis', '12']).houses), ['12', '12bis']);
    });

    test('should not change when the list it was given changes', () {
      final houses = [House(number: n('1'))];
      final street = _street(houses);

      houses.add(House(number: n('2')));

      expect(_labels(street.houses), ['1']);
    });

    test('should refuse a change to its list of houses from outside', () {
      final street = _streetOf(['1']);

      expect(
        () => street.houses.add(House(number: n('2'))),
        throwsUnsupportedError,
      );
    });
  });

  group('sides', () {
    final street = _streetOf(['8', '3bis', '0', '2', '1', '3', '11', '10']);

    test('should list the odd numbers in order on the odd side', () {
      expect(_labels(street.oddHouses), ['1', '3', '3bis', '11']);
    });

    test('should list the even numbers, 0 included, on the even side', () {
      expect(_labels(street.evenHouses), ['0', '2', '8', '10']);
    });

    test('should have an empty even side when every number is odd', () {
      final oddOnly = _streetOf(['1', '3']);

      expect(oddOnly.evenHouses, isEmpty);
      expect(_labels(oddOnly.oddHouses), ['1', '3']);
    });

    test('should refuse a change to a side from outside', () {
      expect(
        () => street.oddHouses.add(House(number: n('5'))),
        throwsUnsupportedError,
      );
      expect(
        () => street.evenHouses.add(House(number: n('4'))),
        throwsUnsupportedError,
      );
    });
  });

  group('progress', () {
    test('should count nothing when the street has no house', () {
      expect(_streetOf([]).progress, Progress.empty);
    });

    test('should count each of the four statuses on a mixed street', () {
      final street = _street([
        House(number: n('1'), status: VisitStatus.done),
        House(number: n('2'), status: VisitStatus.done),
        House(number: n('3'), status: VisitStatus.done),
        House(number: n('4'), status: VisitStatus.nobodyHome),
        House(number: n('5'), status: VisitStatus.nobodyHome),
        House(
          number: n('6'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('après 19h'),
        ),
        House(number: n('7')),
        House(number: n('8')),
        House(number: n('9')),
        House(number: n('10')),
      ]);

      final progress = street.progress;

      expect(progress.done, 3);
      expect(progress.nobodyHome, 2);
      expect(progress.comeBack, 1);
      expect(progress.toDo, 4);
      expect(progress.total, 10);
      expect(progress.toComeBack, 1);
    });
  });

  group('markHouse', () {
    final street = _street([
      House(number: n('1')),
      House(
        number: n('3'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('après 19h'),
        note: note('chien'),
        lastChange: paulAtThree,
      ),
      House(number: n('4'), status: VisitStatus.done),
    ]);

    test('should give the house its new status and stamp', () {
      final (marked, _) = valueOf(
        street.markHouse(n('1'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(
        marked.houses[0],
        House(number: n('1'), status: VisitStatus.done, lastChange: leaAtTwo),
      );
    });

    test('should describe the change and the house it replaced', () {
      final before = street.houses[1];

      final (_, change) = valueOf(
        street.markHouse(n('3'), VisitStatus.nobodyHome, by: lea, at: twoPm),
      );

      expect(
        change,
        HouseMarked(
          streetId: _lilas,
          before: before,
          status: VisitStatus.nobodyHome,
          stamp: leaAtTwo,
        ),
      );
    });

    test('should drop the hint but keep the note when nobody is home', () {
      final (marked, change) = valueOf(
        street.markHouse(n('3'), VisitStatus.nobodyHome, by: lea, at: twoPm),
      );

      expect(
        marked.houses[1],
        House(
          number: n('3'),
          status: VisitStatus.nobodyHome,
          note: note('chien'),
          lastChange: leaAtTwo,
        ),
      );
      expect(marked.houses[1].comeBack, isNull);
      expect(change.comeBack, isNull);
      expect(change.before.comeBack, comeBack('après 19h'));
    });

    test('should drop the hint but keep the note when done', () {
      final (marked, change) = valueOf(
        street.markHouse(n('3'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(
        marked.houses[1],
        House(
          number: n('3'),
          status: VisitStatus.done,
          note: note('chien'),
          lastChange: leaAtTwo,
        ),
      );
      expect(change.comeBack, isNull);
    });

    test('should come back without hint when a house becomes it', () {
      final (marked, change) = valueOf(
        street.markHouse(n('4'), VisitStatus.comeBack, by: lea, at: twoPm),
      );

      expect(marked.houses[2].status, VisitStatus.comeBack);
      expect(marked.houses[2].comeBack, ComeBack.withoutHint);
      expect(marked.houses[2].lastChange, leaAtTwo);
      expect(change.status, VisitStatus.comeBack);
      expect(change.comeBack, ComeBack.withoutHint);
    });

    test('should keep the hint when a house stays « repasser »', () {
      final (marked, _) = valueOf(
        street.markHouse(n('3'), VisitStatus.comeBack, by: lea, at: twoPm),
      );

      expect(marked.houses[1].comeBack, comeBack('après 19h'));
    });

    test('should move a done house back to do', () {
      final (marked, _) = valueOf(
        street.markHouse(n('4'), VisitStatus.toDo, by: paul, at: threePm),
      );

      expect(marked.houses[2], House(number: n('4'), lastChange: paulAtThree));
    });

    test('should leave the other houses and the street identity alone', () {
      final (marked, _) = valueOf(
        street.markHouse(n('3'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(marked.houses[0], street.houses[0]);
      expect(marked.houses[2], street.houses[2]);
      expect(marked.houses, hasLength(3));
      expect(marked.id, street.id);
      expect(marked.name, street.name);
      expect(marked.commune, street.commune);
      expect(marked.banId, street.banId);
      expect(marked.deletion, street.deletion);
    });

    test('should keep the street in the Corbeille when it was there', () {
      final (deleted, _) = street.delete(by: paul, at: threePm);

      final (marked, _) = valueOf(
        deleted.markHouse(n('1'), VisitStatus.done, by: lea, at: twoPm),
      );

      expect(marked.deletion, paulAtThree);
    });

    test('should leave the original street unchanged', () {
      final before = street.houses[0];

      street.markHouse(n('1'), VisitStatus.done, by: lea, at: twoPm);

      expect(street.houses[0], before);
    });

    test('should fail when the street has no such number', () {
      expect(
        failureOf(
          street.markHouse(n('1bis'), VisitStatus.done, by: lea, at: twoPm),
        ),
        HouseChangeFailure.unknownHouse,
      );
    });
  });

  group('setComeBack', () {
    final street = _street([
      House(number: n('1'), status: VisitStatus.comeBack, note: note('chien')),
      House(number: n('2'), status: VisitStatus.nobodyHome),
      House(number: n('4'), status: VisitStatus.done, lastChange: paulAtThree),
    ]);

    test('should set the hint and keep status and note when « repasser »', () {
      final (changed, change) = valueOf(
        street.setComeBack(n('1'), comeBack('après 19h'), by: lea, at: twoPm),
      );

      expect(
        changed.houses[0],
        House(
          number: n('1'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('après 19h'),
          note: note('chien'),
          lastChange: leaAtTwo,
        ),
      );
      expect(
        change,
        ComeBackSet(
          streetId: _lilas,
          before: street.houses[0],
          comeBack: comeBack('après 19h'),
          stamp: leaAtTwo,
        ),
      );
    });

    final refused = <String, (String, ComeBack?)>{
      'nobody was home': ('2', ComeBack.withoutHint),
      'the house is done': ('4', comeBack('samedi')),
      'no hint is given to a house « repasser »': ('1', null),
    };
    refused.forEach((when, given) {
      test('should refuse a hint when $when', () {
        expect(
          failureOf(
            street.setComeBack(n(given.$1), given.$2, by: lea, at: twoPm),
          ),
          HouseChangeFailure.notComeBack,
        );
      });
    });

    test('should leave the other houses alone', () {
      final (changed, _) = valueOf(
        street.setComeBack(n('1'), ComeBack.withoutHint, by: lea, at: twoPm),
      );

      expect(changed.houses.sublist(1), street.houses.sublist(1));
      expect(changed.id, street.id);
    });

    test('should fail when the street has no such number', () {
      expect(
        failureOf(
          street.setComeBack(n('3'), ComeBack.withoutHint, by: lea, at: twoPm),
        ),
        HouseChangeFailure.unknownHouse,
      );
    });
  });

  group('setNote', () {
    final street = _street([
      House(
        number: n('1'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('le samedi'),
      ),
      House(number: n('2'), status: VisitStatus.done, note: note('digicode')),
    ]);

    test('should write the note and keep status and come-back', () {
      final (changed, change) = valueOf(
        street.setNote(n('1'), note('chien'), by: lea, at: twoPm),
      );

      expect(
        changed.houses[0],
        House(
          number: n('1'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('le samedi'),
          note: note('chien'),
          lastChange: leaAtTwo,
        ),
      );
      expect(
        change,
        NoteSet(
          streetId: _lilas,
          before: street.houses[0],
          note: note('chien'),
          stamp: leaAtTwo,
        ),
      );
    });

    test('should erase the note when given the empty note', () {
      final (changed, change) = valueOf(
        street.setNote(n('2'), Note.empty, by: paul, at: threePm),
      );

      expect(
        changed.houses[1],
        House(
          number: n('2'),
          status: VisitStatus.done,
          lastChange: paulAtThree,
        ),
      );
      expect(change.before.note, note('digicode'));
    });

    test('should leave the other houses alone', () {
      final (changed, _) = valueOf(
        street.setNote(n('2'), note('chien'), by: lea, at: twoPm),
      );

      expect(changed.houses[0], street.houses[0]);
      expect(changed.id, street.id);
    });

    test('should fail when the street has no such number', () {
      expect(
        failureOf(street.setNote(n('3'), note('chien'), by: lea, at: twoPm)),
        HouseChangeFailure.unknownHouse,
      );
    });
  });

  group('delete and restore', () {
    final street = _street([
      House(number: n('1'), status: VisitStatus.done, note: note('chien')),
    ]);

    test('should mark the street deleted with who and when', () {
      final (deleted, change) = street.delete(by: paul, at: threePm);

      expect(deleted.isDeleted, isTrue);
      expect(deleted.deletion, paulAtThree);
      expect(change, StreetDeleted(streetId: _lilas, deletion: paulAtThree));
    });

    test('should keep the houses and identity when deleted', () {
      final (deleted, _) = street.delete(by: paul, at: threePm);

      expect(deleted.houses, street.houses);
      expect(deleted.id, street.id);
      expect(deleted.name, street.name);
      expect(deleted.commune, street.commune);
      expect(deleted.banId, street.banId);
    });

    test('should leave the original street undeleted', () {
      street.delete(by: paul, at: threePm);

      expect(street.isDeleted, isFalse);
    });

    test('should bring the street back with its houses when restored', () {
      final (deleted, _) = street.delete(by: paul, at: threePm);

      final (restored, change) = deleted.restore();

      expect(restored.isDeleted, isFalse);
      expect(restored.deletion, isNull);
      expect(restored.houses, street.houses);
      expect(restored.id, street.id);
      expect(change, StreetRestored(streetId: _lilas));
    });
  });
}
