import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/building_status.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/progress.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../../support/building_fixtures.dart';
import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';

DwellingKey _key(StaircaseName staircase, int? level, String label) =>
    DwellingKey(staircase, level, d(label));

/// [building] with the door [label] on floor [level] of [staircase] given
/// [status].
Building _marked(
  Building building,
  StaircaseName staircase,
  int? level,
  String label,
  VisitStatus status,
) => building.withDwelling(
  staircase,
  level,
  Dwelling(label: d(label), status: status, lastChange: leaAtTwo),
);

/// Each floor of [staircase] as `level: label label…`, top first.
List<String> _rows(Staircase staircase) => [
  for (final floor in staircase.floors)
    '${floor.level}: ${floor.dwellings.map((d) => d.label.text).join(' ')}',
];

List<String> _labels(Building building, StaircaseName staircase) => [
  for (final dwelling
      in building.staircases.firstWhere((s) => s.name == staircase).dwellings)
    dwelling.label.text,
];

/// A free-style building, RdC and 1er, each floor `Gauche Droite`.
Building _leftRight() {
  var result = building(topFloor: 1, doors: 2, style: DoorLabelStyle.free);
  for (final level in [0, 1]) {
    result = valueOf(
      result.withDoorRenamed(_key(escA, level, '1'), d('Gauche')),
    );
    result = valueOf(
      result.withDoorRenamed(_key(escA, level, '2'), d('Droite')),
    );
  }
  return result;
}

Floor _floor(int? level, List<String> labels) => Floor(
  level: level,
  dwellings: [for (final label in labels) Dwelling(label: d(label))],
);

void main() {
  group('laidOut', () {
    test('should hold the staircases its plan generates, and the style', () {
      final thePlan = plan(
        staircases: 2,
        topFloor: 2,
        style: DoorLabelStyle.free,
      );

      final laidOut = Building.laidOut(thePlan);

      expect(laidOut.style, DoorLabelStyle.free);
      expect(laidOut.staircases, thePlan.generate());
    });

    test('should refuse a change to its staircases from outside', () {
      final laidOut = building();

      expect(
        () => laidOut.staircases.add(laidOut.staircases.first),
        throwsUnsupportedError,
      );
    });

    group('again, keeping the doors that still exist', () {
      // Staircase A: 31 done, 21 nobody home with a come-back;
      // staircase B: 21 done.
      final before = building(staircases: 2, topFloor: 3, doors: 2)
          .withDwelling(
            escA,
            3,
            Dwelling(
              label: d('31'),
              status: VisitStatus.done,
              lastChange: leaAtTwo,
            ),
          )
          .withDwelling(
            escA,
            2,
            Dwelling(
              label: d('21'),
              status: VisitStatus.nobodyHome,
              comeBack: comeBack('après 19h'),
              lastChange: paulAtThree,
            ),
          )
          .withDwelling(
            escB,
            2,
            Dwelling(
              label: d('21'),
              status: VisitStatus.done,
              lastChange: leaAtTwo,
            ),
          );

      // One staircase only, RdC to 2e, three doors: 31 disappears, 23 is new.
      final after = Building.laidOut(
        plan(topFloor: 2, doors: 3),
        keeping: before,
      );

      test('should keep status, come-back and change of a kept door', () {
        expect(
          after.dwellingAt(_key(escA, 2, '21')),
          before.dwellingAt(_key(escA, 2, '21')),
        );
      });

      test('should drop the doors whose label is gone', () {
        expect(after.dwellingAt(_key(escA, 3, '31')), isNull);
      });

      test('should drop the staircases that are gone', () {
        expect(after.staircases.map((s) => s.name), [escA]);
        expect(after.dwellingAt(_key(escB, 2, '21')), isNull);
      });

      test('should make the new labels new doors', () {
        expect(after.dwellingAt(_key(escA, 2, '23')), Dwelling(label: d('23')));
      });

      test('should lay out the new floors', () {
        expect(_rows(after.staircases.single), [
          '2: 21 22 23',
          '1: 11 12 13',
          '0: 01 02 03',
        ]);
      });

      test('should take the new style', () {
        final lettered = Building.laidOut(
          plan(topFloor: 2, doors: 3, style: DoorLabelStyle.floorAndLetter),
          keeping: before,
        );

        expect(lettered.style, DoorLabelStyle.floorAndLetter);
        expect(_rows(lettered.staircases.single).first, '2: 2A 2B 2C');
        expect(lettered.progress.nobodyHome, 0);
      });

      test('should not take a label from another staircase', () {
        // Staircase B had 21 done; A's 21 was nobody home.
        final both = Building.laidOut(
          plan(staircases: 2, topFloor: 2, doors: 1),
          keeping: before,
        );

        expect(
          both.dwellingAt(_key(escA, 2, '21'))!.status,
          VisitStatus.nobodyHome,
        );
        expect(both.dwellingAt(_key(escB, 2, '21'))!.status, VisitStatus.done);
      });

      test('should keep the marks of the doors that stay in a staircase '
          'made smaller', () {
        // A stays RdC–3e with two doors; B becomes RdC–2e with one door:
        // A's 21 and B's 21 (done) both stay, each in its staircase.
        final smallerB = Building.laidOut(
          valueOf(
            BuildingPlan.perStaircase(
              staircases: const [
                StaircasePlan(topFloor: 3, doorsPerFloor: 2),
                StaircasePlan(topFloor: 2, doorsPerFloor: 1),
              ],
              style: DoorLabelStyle.floorAndNumber,
            ),
          ),
          keeping: before,
        );

        expect(
          smallerB.dwellingAt(_key(escA, 2, '21')),
          before.dwellingAt(_key(escA, 2, '21')),
        );
        expect(
          smallerB.dwellingAt(_key(escB, 2, '21')),
          before.dwellingAt(_key(escB, 2, '21')),
        );
        expect(_rows(smallerB.staircases[0]), hasLength(4));
        expect(_rows(smallerB.staircases[1]), ['2: 21', '1: 11', '0: 01']);
      });

      test('should not take a label from another floor', () {
        // Gauche of the RdC is done; laid out again with the floors unknown,
        // the « Logements » row's 1 is not the RdC's.
        final free = _marked(
          building(topFloor: 1, doors: 2, style: DoorLabelStyle.free),
          escA,
          0,
          '1',
          VisitStatus.done,
        );

        final again = Building.laidOut(
          plan(topFloor: 1, doors: 2, style: DoorLabelStyle.free),
          keeping: free,
        );
        final unknown = Building.laidOut(
          plan(topFloor: null, doors: 2, style: DoorLabelStyle.free),
          keeping: free,
        );

        expect(again.dwellingAt(_key(escA, 0, '1'))!.status, VisitStatus.done);
        expect(again.dwellingAt(_key(escA, 1, '1'))!.status, VisitStatus.toDo);
        expect(unknown.progress.done, 0);
      });
    });
  });

  group('create', () {
    Result<Building, NewBuildingFailure> create(List<Staircase> staircases) =>
        Building.create(style: DoorLabelStyle.free, staircases: staircases);

    test('should rebuild a laid-out building from its parts', () {
      final marked = _marked(building(), escA, 5, '52', VisitStatus.done);

      final rebuilt = valueOf(
        Building.create(style: marked.style, staircases: marked.staircases),
      );

      expect(rebuilt, marked);
    });

    test('should keep the style it is given', () {
      final rebuilt = valueOf(
        Building.create(
          style: DoorLabelStyle.floorAndLetter,
          staircases: building().staircases,
        ),
      );

      expect(rebuilt.style, DoorLabelStyle.floorAndLetter);
    });

    test('should sort the staircases by name and the floors top first', () {
      final rebuilt = valueOf(
        create([
          Staircase(
            name: escB,
            floors: [
              _floor(0, ['1']),
              _floor(2, ['1']),
              _floor(1, ['1']),
            ],
          ),
          Staircase(
            name: escA,
            floors: [
              _floor(0, ['1']),
            ],
          ),
        ]),
      );

      expect(rebuilt.staircases.map((s) => s.name), [escA, escB]);
      expect(rebuilt.staircases[1].floors.map((f) => f.level), [2, 1, 0]);
    });

    test('should accept the same label on two floors', () {
      final rebuilt = valueOf(
        create([
          Staircase(
            name: escA,
            floors: [
              _floor(1, ['Gauche', 'Droite']),
              _floor(0, ['Gauche', 'Droite']),
            ],
          ),
        ]),
      );

      expect(rebuilt.progress.total, 4);
    });

    test('should accept the same label in two staircases', () {
      expect(
        valueOf(
          create([
            Staircase(
              name: escA,
              floors: [
                _floor(0, ['1']),
              ],
            ),
            Staircase(
              name: escB,
              floors: [
                _floor(0, ['1']),
              ],
            ),
          ]),
        ).progress.total,
        2,
      );
    });

    test('should accept a single Logements row', () {
      final rebuilt = valueOf(
        create([
          Staircase(
            name: escA,
            floors: [
              _floor(null, ['1', '2']),
            ],
          ),
        ]),
      );

      expect(rebuilt.staircases.single.floors.single.level, isNull);
    });

    test('should accept an empty floor', () {
      expect(
        valueOf(
          create([
            Staircase(
              name: escA,
              floors: [
                _floor(1, ['1']),
                _floor(0, []),
              ],
            ),
          ]),
        ).staircases.single.floors,
        hasLength(2),
      );
    });

    test('should accept the RdC and the highest floor', () {
      expect(
        valueOf(
          create([
            Staircase(
              name: escA,
              floors: [
                _floor(50, ['1']),
                _floor(0, ['1']),
              ],
            ),
          ]),
        ).progress.total,
        2,
      );
    });

    final refused = <String, (List<Staircase>, NewBuildingFailure)>{
      'no staircase': (const [], NewBuildingFailure.noStaircase),
      'two staircases with one name': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(0, ['1']),
            ],
          ),
          Staircase(
            name: escA,
            floors: [
              _floor(1, ['1']),
            ],
          ),
        ],
        NewBuildingFailure.duplicateStaircase,
      ),
      'a floor below the RdC': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(-1, ['1']),
            ],
          ),
        ],
        NewBuildingFailure.floorOutOfRange,
      ),
      'a floor above the highest': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(51, ['1']),
            ],
          ),
        ],
        NewBuildingFailure.floorOutOfRange,
      ),
      'two floors with one level': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(1, ['1']),
              _floor(1, ['2']),
            ],
          ),
        ],
        NewBuildingFailure.duplicateFloor,
      ),
      'two Logements rows': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(null, ['1']),
              _floor(null, ['2']),
            ],
          ),
        ],
        NewBuildingFailure.duplicateFloor,
      ),
      'a Logements row after known floors': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(0, ['1']),
              _floor(null, ['2']),
            ],
          ),
        ],
        NewBuildingFailure.unknownFloorNotAlone,
      ),
      'a Logements row before known floors': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(null, ['1']),
              _floor(0, ['2']),
            ],
          ),
        ],
        NewBuildingFailure.unknownFloorNotAlone,
      ),
      'the same label twice on one floor': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(1, ['Gauche']),
              _floor(0, ['Gauche', 'Droite', 'Gauche']),
            ],
          ),
        ],
        NewBuildingFailure.duplicateLabel,
      ),
      'a broken second staircase': (
        [
          Staircase(
            name: escA,
            floors: [
              _floor(0, ['1']),
            ],
          ),
          Staircase(
            name: escB,
            floors: [
              _floor(0, ['1', '1']),
            ],
          ),
        ],
        NewBuildingFailure.duplicateLabel,
      ),
      'not a single door': (
        [
          Staircase(name: escA, floors: [_floor(0, [])]),
        ],
        NewBuildingFailure.noDwelling,
      ),
    };
    refused.forEach((what, given) {
      test('should refuse $what', () {
        expect(failureOf(create(given.$1)), given.$2);
      });
    });

    test('should accept the largest building', () {
      final largest = building(
        topFloor: null,
        doors: BuildingPlan.maxDwellings,
      );

      expect(
        valueOf(create(largest.staircases)).progress.total,
        BuildingPlan.maxDwellings,
      );
    });

    test('should refuse one door more than the largest building', () {
      final largest = building(
        staircases: 2,
        topFloor: null,
        doors: BuildingPlan.maxDwellings ~/ 2,
      );
      final extra = Staircase(
        name: StaircaseName('C'),
        floors: [
          _floor(null, ['1']),
        ],
      );

      expect(
        failureOf(create([...largest.staircases, extra])),
        NewBuildingFailure.tooManyDwellings,
      );
    });
  });

  group('status and progress', () {
    final twoDoors = building(topFloor: 0, doors: 2);

    test('should be to do when no door is done', () {
      final nobody = _marked(twoDoors, escA, 0, '01', VisitStatus.nobodyHome);

      expect(nobody.status, BuildingStatus.toDo);
    });

    test('should be partial when some doors are done', () {
      final one = _marked(twoDoors, escA, 0, '01', VisitStatus.done);

      expect(one.status, BuildingStatus.partial);
      expect(one.progress.done, 1);
      expect(one.progress.total, 2);
    });

    test('should be done when every door is done', () {
      final both = _marked(
        _marked(twoDoors, escA, 0, '01', VisitStatus.done),
        escA,
        0,
        '02',
        VisitStatus.done,
      );

      expect(both.status, BuildingStatus.done);
    });

    test('should add up the doors of every staircase', () {
      final two =
          _marked(
            building(staircases: 2, topFloor: 0, doors: 2),
            escB,
            0,
            '02',
            VisitStatus.done,
          ).withDwelling(
            escA,
            0,
            Dwelling(label: d('01'), status: VisitStatus.comeBack),
          );

      expect(
        two.progress,
        Progress.of(VisitStatus.done) +
            Progress.of(VisitStatus.comeBack) +
            Progress.of(VisitStatus.toDo) +
            Progress.of(VisitStatus.toDo),
      );
    });
  });

  group('dwellingAt', () {
    final two = building(staircases: 2, topFloor: 1, doors: 2);

    test('should find the door of the named staircase', () {
      final marked = _marked(two, escB, 1, '12', VisitStatus.done);

      expect(marked.dwellingAt(_key(escB, 1, '12'))!.status, VisitStatus.done);
      expect(marked.dwellingAt(_key(escA, 1, '12'))!.status, VisitStatus.toDo);
    });

    test('should find the door of the named floor', () {
      final marked = _marked(_leftRight(), escA, 1, 'Gauche', VisitStatus.done);

      expect(
        marked.dwellingAt(_key(escA, 1, 'Gauche'))!.status,
        VisitStatus.done,
      );
      expect(
        marked.dwellingAt(_key(escA, 0, 'Gauche'))!.status,
        VisitStatus.toDo,
      );
    });

    test('should find nothing when the label is unknown', () {
      expect(two.dwellingAt(_key(escA, 1, '13')), isNull);
    });

    test('should find nothing when the label is on another floor', () {
      expect(two.dwellingAt(_key(escA, 0, '11')), isNull);
    });

    test('should find nothing when the floor is unknown', () {
      expect(two.dwellingAt(_key(escA, 2, '11')), isNull);
      expect(two.dwellingAt(_key(escA, null, '11')), isNull);
    });

    test('should find nothing when the staircase is unknown', () {
      expect(two.dwellingAt(_key(StaircaseName('C'), 1, '11')), isNull);
    });
  });

  group('withDwelling', () {
    test('should replace only the door of that staircase, floor and label', () {
      final leftRight = _leftRight();
      final done = Dwelling(label: d('Gauche'), status: VisitStatus.done);

      final changed = leftRight.withDwelling(escA, 0, done);

      expect(changed.dwellingAt(_key(escA, 0, 'Gauche')), done);
      expect(
        changed.staircases.single.floors.first,
        leftRight.staircases.single.floors.first,
      );
      expect(_labels(changed, escA), _labels(leftRight, escA));
    });

    test('should leave the other staircases alone', () {
      final two = building(staircases: 2, topFloor: 0, doors: 1);

      final changed = _marked(two, escA, 0, '01', VisitStatus.done);

      expect(changed.staircases[1], two.staircases[1]);
    });
  });

  group('withDoorAdded', () {
    test('should add the next number at the end of the floor', () {
      final added = valueOf(building().withDoorAdded(escA, 5));

      expect(_rows(added.staircases.single).first, '5: 51 52 53 54 55');
      expect(added.dwellingAt(_key(escA, 5, '55')), Dwelling(label: d('55')));
      expect(
        added.staircases.single.floors[1],
        building().staircases.single.floors[1],
      );
    });

    test('should add to the RdC with its 0', () {
      final added = valueOf(building().withDoorAdded(escA, 0));

      expect(_rows(added.staircases.single).last, '0: 01 02 03 04 05');
    });

    test('should skip a label already taken on the floor', () {
      final renamed = valueOf(
        building().withDoorRenamed(_key(escA, 5, '54'), d('55')),
      );

      final added = valueOf(renamed.withDoorAdded(escA, 5));

      expect(_rows(added.staircases.single).first, '5: 51 52 53 55 56');
    });

    test('should not skip a label taken on another floor only', () {
      // Free labels: 1er 1 2 (its 3 removed), RdC 1 2 3. The RdC's 3 does
      // not stop the 1er from getting a 3 again.
      final free = valueOf(
        building(
          topFloor: 1,
          doors: 3,
          style: DoorLabelStyle.free,
        ).withoutDoor(_key(escA, 1, '3')),
      );

      final added = valueOf(free.withDoorAdded(escA, 1));

      expect(_rows(added.staircases.single), ['1: 1 2 3', '0: 1 2 3']);
    });

    test('should not pad the door number when adding', () {
      final added = valueOf(
        building(topFloor: 1, doors: 9).withDoorAdded(escA, 1),
      );

      expect(
        _rows(added.staircases.single).first,
        '1: 11 12 13 14 15 16 17 18 19 110',
      );
    });

    test('should add the next letter with style 5A', () {
      final added = valueOf(
        building(
          topFloor: 1,
          doors: 2,
          style: DoorLabelStyle.floorAndLetter,
        ).withDoorAdded(escA, 1),
      );

      expect(_rows(added.staircases.single).first, '1: 1A 1B 1C');
    });

    test('should accept a 26th letter on a floor', () {
      final full = building(
        topFloor: 0,
        doors: 25,
        style: DoorLabelStyle.floorAndLetter,
      );

      final added = valueOf(full.withDoorAdded(escA, 0));

      expect(added.staircases.single.dwellings.last.label, d('0Z'));
    });

    test('should refuse a 27th letter on a floor', () {
      final full = building(
        topFloor: 0,
        doors: 26,
        style: DoorLabelStyle.floorAndLetter,
      );

      expect(
        failureOf(full.withDoorAdded(escA, 0)),
        BuildingChangeFailure.noLabelLeft,
      );
    });

    test('should number a free door after the doors of its floor', () {
      final added = valueOf(_leftRight().withDoorAdded(escA, 0));

      expect(_rows(added.staircases.single), [
        '1: Gauche Droite',
        '0: Gauche Droite 3',
      ]);
    });

    test('should add to the Logements row when the floors are unknown', () {
      final unknown = building(topFloor: null, doors: 3);

      final added = valueOf(unknown.withDoorAdded(escA, null));

      expect(_rows(added.staircases.single), ['null: 1 2 3 4']);
    });

    test('should add to the named staircase only', () {
      final two = building(staircases: 2, topFloor: 0, doors: 1);

      final added = valueOf(two.withDoorAdded(escB, 0));

      expect(_labels(added, escA), ['01']);
      expect(_labels(added, escB), ['01', '02']);
    });

    test('should refuse an unknown staircase', () {
      expect(
        failureOf(building().withDoorAdded(escB, 5)),
        BuildingChangeFailure.unknownStaircase,
      );
    });

    test('should refuse a floor the staircase does not have', () {
      expect(
        failureOf(building().withDoorAdded(escA, 6)),
        BuildingChangeFailure.unknownFloor,
      );
    });

    test('should refuse a level when the floors are unknown', () {
      expect(
        failureOf(building(topFloor: null).withDoorAdded(escA, 0)),
        BuildingChangeFailure.unknownFloor,
      );
    });

    test('should accept the door that makes the largest building', () {
      final almost = building(
        topFloor: null,
        doors: BuildingPlan.maxDwellings - 1,
      );

      final added = valueOf(almost.withDoorAdded(escA, null));

      expect(added.progress.total, 500);
    });

    test('should refuse a door beyond the largest building', () {
      final largest = building(
        topFloor: null,
        doors: BuildingPlan.maxDwellings,
      );

      expect(
        failureOf(largest.withDoorAdded(escA, null)),
        BuildingChangeFailure.tooManyDwellings,
      );
    });
  });

  group('withoutDoor', () {
    test('should remove the door and keep the others in order', () {
      final removed = valueOf(building().withoutDoor(_key(escA, 5, '52')));

      expect(_rows(removed.staircases.single).first, '5: 51 53 54');
      expect(removed.progress.total, 23);
    });

    test('should remove the door of the named floor only', () {
      final removed = valueOf(
        _leftRight().withoutDoor(_key(escA, 0, 'Gauche')),
      );

      expect(_rows(removed.staircases.single), [
        '1: Gauche Droite',
        '0: Droite',
      ]);
    });

    test('should keep a floor whose last door was removed', () {
      final two = building(topFloor: 1, doors: 1);

      final removed = valueOf(two.withoutDoor(_key(escA, 0, '01')));

      expect(_rows(removed.staircases.single), ['1: 11', '0: ']);
    });

    test('should remove from the named staircase only', () {
      final two = building(staircases: 2, topFloor: 0, doors: 1);

      final removed = valueOf(two.withoutDoor(_key(escB, 0, '01')));

      expect(_labels(removed, escA), ['01']);
      expect(_labels(removed, escB), isEmpty);
    });

    test('should refuse to remove the last door of the building', () {
      final one = building(topFloor: 0, doors: 1);

      expect(
        failureOf(one.withoutDoor(_key(escA, 0, '01'))),
        BuildingChangeFailure.lastDwelling,
      );
    });

    test('should accept removing one of the last two doors', () {
      final two = building(topFloor: 0, doors: 2);

      expect(valueOf(two.withoutDoor(_key(escA, 0, '01'))).progress.total, 1);
    });

    test('should refuse an unknown door', () {
      expect(
        failureOf(building().withoutDoor(_key(escA, 5, '55'))),
        BuildingChangeFailure.unknownDwelling,
      );
    });

    test('should refuse a door named on the wrong floor', () {
      expect(
        failureOf(building().withoutDoor(_key(escA, 4, '51'))),
        BuildingChangeFailure.unknownDwelling,
      );
    });
  });

  group('withDoorRenamed', () {
    final marked = building(staircases: 2, topFloor: 1, doors: 2).withDwelling(
      escA,
      1,
      Dwelling(
        label: d('11'),
        status: VisitStatus.nobodyHome,
        comeBack: comeBack('le soir'),
        lastChange: leaAtTwo,
      ),
    );

    test('should give the door its new label and keep its marks', () {
      final renamed = valueOf(
        marked.withDoorRenamed(_key(escA, 1, '11'), d('Gauche')),
      );

      expect(
        renamed.dwellingAt(_key(escA, 1, 'Gauche')),
        Dwelling(
          label: d('Gauche'),
          status: VisitStatus.nobodyHome,
          comeBack: comeBack('le soir'),
          lastChange: leaAtTwo,
        ),
      );
      expect(renamed.dwellingAt(_key(escA, 1, '11')), isNull);
      expect(_rows(renamed.staircases.first).first, '1: Gauche 12');
    });

    test('should refuse a label another door of the floor has', () {
      expect(
        failureOf(marked.withDoorRenamed(_key(escA, 1, '11'), d('12'))),
        BuildingChangeFailure.duplicateLabel,
      );
    });

    test('should accept a label a door of another floor has', () {
      final renamed = valueOf(
        marked.withDoorRenamed(_key(escA, 1, '11'), d('01')),
      );

      expect(_rows(renamed.staircases.first), ['1: 01 12', '0: 01 02']);
    });

    test('should accept Gauche and Droite on every floor', () {
      expect(_rows(_leftRight().staircases.single), [
        '1: Gauche Droite',
        '0: Gauche Droite',
      ]);
    });

    test('should accept a label a door of another staircase has', () {
      final inA = valueOf(
        marked.withDoorRenamed(_key(escA, 1, '11'), d('Gauche')),
      );

      final inB = valueOf(
        inA.withDoorRenamed(_key(escB, 1, '12'), d('Gauche')),
      );

      expect(_labels(inB, escA), ['Gauche', '12', '01', '02']);
      expect(_labels(inB, escB), ['11', 'Gauche', '01', '02']);
    });

    test('should accept the label the door already has', () {
      expect(
        valueOf(marked.withDoorRenamed(_key(escA, 1, '11'), d('11'))),
        marked,
      );
    });

    test('should refuse an unknown door', () {
      expect(
        failureOf(marked.withDoorRenamed(_key(escA, 1, '13'), d('Droite'))),
        BuildingChangeFailure.unknownDwelling,
      );
    });
  });

  group('equality', () {
    test('should be equal when style and staircases are equal', () {
      expect(building(), building());
      expect(building().hashCode, building().hashCode);
    });

    test('should differ when the styles differ', () {
      // With unknown floors both styles number the doors 1, 2, 3.
      final numbered = building(topFloor: null, doors: 3);
      final free = building(
        topFloor: null,
        doors: 3,
        style: DoorLabelStyle.free,
      );

      expect(free.staircases, numbered.staircases);
      expect(free, isNot(numbered));
    });

    test('should differ when the staircases differ', () {
      expect(
        building(),
        isNot(_marked(building(), escA, 5, '51', VisitStatus.done)),
      );
    });

    test('should show its style and staircases when printed', () {
      final one = building(topFloor: 0, doors: 1);

      expect(
        one.toString(),
        'Building(DoorLabelStyle.floorAndNumber, ${one.staircases})',
      );
    });
  });
}
