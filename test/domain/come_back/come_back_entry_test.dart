import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'come_back_fixtures.dart';

/// Rue Pasteur: 5 « repasser » (yesterday at 18 h, by Paul), 7 done, and
/// the building 8 with its own « Repasser » and door 51 « repasser ».
final _pasteur = valueOf(
  Street.create(
    id: pasteurId,
    name: 'Rue Pasteur',
    commune: villefranche,
    houses: [
      House(
        number: n('5'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-10-23', hour: 18),
        lastChange: paulAtThree,
      ),
      House(number: n('7'), status: VisitStatus.done, lastChange: leaAtTwo),
      House(
        number: n('8'),
        comeBack: ComeBack.withoutTime,
        lastChange: leaAtTwo,
        building: valueOf(
          Building.create(
            style: DoorLabelStyle.floorAndNumber,
            staircases: [
              Staircase(
                name: escA,
                floors: [
                  Floor(
                    level: 5,
                    dwellings: [
                      Dwelling(
                        label: d('51'),
                        status: VisitStatus.comeBack,
                        lastChange: paulAtThree,
                      ),
                      Dwelling(label: d('52')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);

/// Rue des Lilas: 12 « repasser » today, by nobody known.
final _lilas = valueOf(
  Street.create(
    id: lilasId,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(
        number: n('12'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-10-24'),
      ),
    ],
  ),
);

void main() {
  group('ComeBackEntry.allOf', () {
    test('should list every house, door and building « repasser »', () {
      expect(ComeBackEntry.allOf([_pasteur, _lilas]), [
        entry(
          pasteurId,
          '5',
          comeBack('2026-10-23', hour: 18),
          setBy: paulAtThree,
        ),
        entry(pasteurId, '8', ComeBack.withoutTime),
        entry(
          pasteurId,
          '8',
          ComeBack.withoutTime,
          door: DwellingKey(escA, 5, d('51')),
          setBy: paulAtThree,
        ),
        entry(lilasId, '12', comeBack('2026-10-24'), nobody: true),
      ]);
    });

    test('should list nothing when no house is « repasser »', () {
      final street = valueOf(
        Street.create(
          id: nationaleId,
          name: 'Rue Nationale',
          commune: villefranche,
          houses: [House(number: n('1'), status: VisitStatus.nobodyHome)],
        ),
      );

      expect(ComeBackEntry.allOf([street]), isEmpty);
    });
  });

  group('ComeBackEntry', () {
    test('should be set by the member of its last change', () {
      final mine = entry(lilasId, '12', ComeBack.withoutTime);

      expect(mine.isSetBy(lea), isTrue);
      expect(mine.isSetBy(paul), isFalse);
    });

    test('should be set by nobody when no change is known', () {
      expect(
        entry(lilasId, '12', ComeBack.withoutTime, nobody: true).isSetBy(lea),
        isFalse,
      );
    });

    test('should be equal when every field is equal', () {
      expect(
        entry(lilasId, '12', ComeBack.withoutTime),
        entry(lilasId, '12', ComeBack.withoutTime),
      );
      expect(
        entry(lilasId, '12', ComeBack.withoutTime).hashCode,
        entry(lilasId, '12', ComeBack.withoutTime).hashCode,
      );
    });

    test('should differ when any field differs', () {
      final base = entry(lilasId, '12', ComeBack.withoutTime);

      expect(base, isNot(entry(lilasId, '14', ComeBack.withoutTime)));
      expect(base, isNot(entry(pinsId, '12', ComeBack.withoutTime)));
      expect(base, isNot(entry(lilasId, '12', comeBack('2026-10-24'))));
      expect(
        base,
        isNot(entry(lilasId, '12', ComeBack.withoutTime, setBy: paulAtThree)),
      );
    });

    test('should print its place, street, time and change', () {
      expect(
        entry(
          pasteurId,
          '8',
          comeBack('2026-10-24', hour: 19),
          door: DwellingKey(escA, 5, d('51')),
        ).toString(),
        'ComeBackEntry(ComeBackPlace(pasteur, 8, A5-51), Rue Pasteur, '
        'ComeBack(2026-10-24 19h), ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
      );
    });
  });

  group('ComeBackEntry.byAddress', () {
    int compare(ComeBackEntry a, ComeBackEntry b) =>
        ComeBackEntry.byAddress(a, b).sign;

    test('should order by street name the French way', () {
      // « Allée » before « Rue »: the accent is ignored.
      expect(
        compare(
          entry(pinsId, '30', ComeBack.withoutTime),
          entry(lilasId, '1', ComeBack.withoutTime),
        ),
        -1,
      );
    });

    test('should order by number within a street', () {
      expect(
        compare(
          entry(lilasId, '12', ComeBack.withoutTime),
          entry(lilasId, '9', ComeBack.withoutTime),
        ),
        1,
      );
    });

    test('should put the building before its doors, the doors by id', () {
      final building = entry(pasteurId, '8', ComeBack.withoutTime);
      final door51 = entry(
        pasteurId,
        '8',
        ComeBack.withoutTime,
        door: DwellingKey(escA, 5, d('51')),
      );
      final door52 = entry(
        pasteurId,
        '8',
        ComeBack.withoutTime,
        door: DwellingKey(escA, 5, d('52')),
      );

      expect(compare(building, door51), -1);
      expect(compare(door52, door51), 1);
    });

    test('should order two streets of the same name by id', () {
      final other = ComeBackEntry(
        place: ComeBackPlace(street: lilasId, number: n('1')),
        streetName: streetName('Rue Pasteur'),
        comeBack: ComeBack.withoutTime,
      );

      expect(compare(entry(pasteurId, '1', ComeBack.withoutTime), other), 1);
      expect(compare(other, other), 0);
    });
  });

  group('ComeBackPlace', () {
    test('should be equal when street, number and door are equal', () {
      final a = ComeBackPlace(street: lilasId, number: n('12'));

      expect(a, ComeBackPlace(street: lilasId, number: n('12')));
      expect(
        a.hashCode,
        ComeBackPlace(street: lilasId, number: n('12')).hashCode,
      );
      expect(a, isNot(ComeBackPlace(street: pinsId, number: n('12'))));
      expect(a, isNot(ComeBackPlace(street: lilasId, number: n('14'))));
      expect(
        a,
        isNot(
          ComeBackPlace(
            street: lilasId,
            number: n('12'),
            door: DwellingKey(escA, 5, d('51')),
          ),
        ),
      );
    });

    test('should print its door only when it has one', () {
      expect(
        ComeBackPlace(street: lilasId, number: n('12')).toString(),
        'ComeBackPlace(lilas, 12)',
      );
    });
  });
}
