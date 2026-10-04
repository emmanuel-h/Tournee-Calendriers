import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../../support/street_fixtures.dart';

void main() {
  final fiftyOne = Dwelling(label: d('51'), status: VisitStatus.done);
  final fiftyTwo = Dwelling(label: d('52'), comeBack: ComeBack.withoutHint);
  final fortyOne = Dwelling(label: d('41'), status: VisitStatus.nobodyHome);

  group('Floor', () {
    test('should keep its level and its doors in order', () {
      final floor = Floor(level: 5, dwellings: [fiftyOne, fiftyTwo]);

      expect(floor.level, 5);
      expect(floor.dwellings, [fiftyOne, fiftyTwo]);
    });

    test('should find a door by its label', () {
      final floor = Floor(level: 5, dwellings: [fiftyOne, fiftyTwo]);

      expect(floor.dwelling(d('52')), fiftyTwo);
    });

    test('should find no door when no label matches', () {
      final floor = Floor(level: 5, dwellings: [fiftyOne, fiftyTwo]);

      expect(floor.dwelling(d('53')), isNull);
    });

    test('should have no level when the floors are unknown', () {
      expect(Floor(level: null, dwellings: [fiftyOne]).level, isNull);
    });

    test('should not change when the list it was given changes', () {
      final doors = [fiftyOne];
      final floor = Floor(level: 5, dwellings: doors);

      doors.add(fiftyTwo);

      expect(floor.dwellings, [fiftyOne]);
    });

    test('should refuse a change to its doors from outside', () {
      final floor = Floor(level: 5, dwellings: [fiftyOne]);

      expect(() => floor.dwellings.add(fiftyTwo), throwsUnsupportedError);
    });

    test('should be equal when level and doors are equal', () {
      expect(
        Floor(level: 5, dwellings: [fiftyOne, fiftyTwo]),
        Floor(level: 5, dwellings: [fiftyOne, fiftyTwo]),
      );
      expect(
        Floor(level: 5, dwellings: [fiftyOne]).hashCode,
        Floor(level: 5, dwellings: [fiftyOne]).hashCode,
      );
    });

    test('should differ when the levels differ', () {
      expect(
        Floor(level: 5, dwellings: [fiftyOne]),
        isNot(Floor(level: null, dwellings: [fiftyOne])),
      );
    });

    test('should differ when the doors differ', () {
      expect(
        Floor(level: 5, dwellings: [fiftyOne]),
        isNot(Floor(level: 5, dwellings: [fiftyOne, fiftyTwo])),
      );
    });

    test('should show its level and doors when printed', () {
      expect(
        Floor(level: 5, dwellings: [fiftyOne]).toString(),
        'Floor(5, [$fiftyOne])',
      );
    });
  });

  group('Staircase', () {
    final staircase = Staircase(
      name: escA,
      floors: [
        Floor(level: 5, dwellings: [fiftyOne, fiftyTwo]),
        Floor(level: 4, dwellings: [fortyOne]),
      ],
    );

    test('should keep its name and its floors in order', () {
      expect(staircase.name, escA);
      expect(staircase.floors.map((floor) => floor.level), [5, 4]);
    });

    test('should list every door, floor after floor', () {
      expect(staircase.dwellings, [fiftyOne, fiftyTwo, fortyOne]);
    });

    test('should find a floor by its level', () {
      expect(staircase.floor(4), staircase.floors[1]);
    });

    test('should find no floor when no level matches', () {
      expect(staircase.floor(3), isNull);
      expect(staircase.floor(null), isNull);
    });

    test('should find the Logements row by the null level', () {
      final unknown = Staircase(
        name: escA,
        floors: [
          Floor(level: null, dwellings: [fiftyOne]),
        ],
      );

      expect(unknown.floor(null), unknown.floors.single);
      expect(unknown.floor(0), isNull);
    });

    test('should add up its doors in its progress', () {
      expect(
        staircase.progress,
        fiftyOne.progress + fiftyTwo.progress + fortyOne.progress,
      );
      expect(staircase.progress.total, 3);
    });

    test('should count nothing when it has no door', () {
      final empty = Staircase(
        name: escA,
        floors: [Floor(level: 0, dwellings: const [])],
      );

      expect(empty.progress, Progress.empty);
    });

    test('should refuse a change to its floors from outside', () {
      expect(
        () => staircase.floors.add(Floor(level: 3, dwellings: const [])),
        throwsUnsupportedError,
      );
    });

    test('should be equal when name and floors are equal', () {
      Staircase make() => Staircase(
        name: escB,
        floors: [
          Floor(level: 0, dwellings: [fiftyOne]),
        ],
      );

      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('should differ when the names differ', () {
      final floors = [
        Floor(level: 0, dwellings: [fiftyOne]),
      ];

      expect(
        Staircase(name: escA, floors: floors),
        isNot(Staircase(name: escB, floors: floors)),
      );
    });

    test('should differ when the floors differ', () {
      expect(
        Staircase(
          name: escA,
          floors: [
            Floor(level: 0, dwellings: [fiftyOne]),
          ],
        ),
        isNot(
          Staircase(
            name: escA,
            floors: [
              Floor(level: 1, dwellings: [fiftyOne]),
            ],
          ),
        ),
      );
    });

    test('should show its name and floors when printed', () {
      final floor = Floor(level: 0, dwellings: [fiftyOne]);

      expect(
        Staircase(name: escB, floors: [floor]).toString(),
        'Staircase(B, [$floor])',
      );
    });
  });
}
