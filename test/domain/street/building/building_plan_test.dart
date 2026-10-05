import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';

const _number = DoorLabelStyle.floorAndNumber;
const _letter = DoorLabelStyle.floorAndLetter;
const _free = DoorLabelStyle.free;

BuildingPlan _plan({
  int staircases = 1,
  int? topFloor = 5,
  int doors = 4,
  DoorLabelStyle style = _number,
}) => valueOf(
  BuildingPlan.create(
    staircaseCount: staircases,
    topFloor: topFloor,
    doorsPerFloor: doors,
    style: style,
  ),
);

BuildingPlanFailure _failure({
  int staircases = 1,
  int? topFloor = 5,
  int doors = 4,
  DoorLabelStyle style = _number,
}) => failureOf(
  BuildingPlan.create(
    staircaseCount: staircases,
    topFloor: topFloor,
    doorsPerFloor: doors,
    style: style,
  ),
);

StaircasePlan _stairs(int? topFloor, int doors) =>
    StaircasePlan(topFloor: topFloor, doorsPerFloor: doors);

/// Staircase A RdC–5e with 4 doors a floor, then [b] (by default RdC–2e
/// with 2 doors): the « Décrire l'immeuble » sketch.
BuildingPlan _uneven({StaircasePlan? b, DoorLabelStyle style = _number}) =>
    valueOf(
      BuildingPlan.perStaircase(
        staircases: [_stairs(5, 4), b ?? _stairs(2, 2)],
        style: style,
      ),
    );

BuildingPlanFailure _unevenFailure(
  StaircasePlan b, {
  DoorLabelStyle style = _number,
}) => failureOf(
  BuildingPlan.perStaircase(staircases: [_stairs(5, 4), b], style: style),
);

/// Each floor of [staircase] as `level: label label…`, top first.
List<String> _rows(Staircase staircase) => [
  for (final floor in staircase.floors)
    '${floor.level}: ${floor.dwellings.map((d) => d.label.text).join(' ')}',
];

void main() {
  group('DoorLabelStyle.label', () {
    final cases = <String, (DoorLabelStyle, int?, int, int, String?)>{
      'floor digit then door on the RdC': (_number, 0, 1, 1, '01'),
      'floor digit then door on the 1er': (_number, 1, 4, 1, '14'),
      'floor digit then door on the 5e': (_number, 5, 1, 1, '51'),
      'two-digit floor then door': (_number, 12, 3, 1, '123'),
      'door padded to the width': (_number, 1, 2, 2, '102'),
      'door as long as the width': (_number, 1, 12, 2, '112'),
      'door number alone when floors are unknown': (_number, null, 7, 2, '7'),
      'floor then letter on the RdC': (_letter, 0, 1, 1, '0A'),
      'floor then letter on the 5e': (_letter, 5, 2, 1, '5B'),
      'letter Z for the 26th door': (_letter, 5, 26, 1, '5Z'),
      'no letter left for the 27th door': (_letter, 5, 27, 1, null),
      'letter alone when floors are unknown': (_letter, null, 3, 1, 'C'),
      'free: the door number, padded never': (_free, 3, 9, 2, '9'),
      'free: the door number when floors are unknown': (_free, null, 2, 1, '2'),
    };
    cases.forEach((what, given) {
      final (style, level, door, width, expected) = given;
      test('should give the $what', () {
        expect(style.label(level: level, door: door, width: width), expected);
      });
    });

    test('should not pad the door by default', () {
      expect(_number.label(level: 1, door: 2), '12');
    });

    test('should have one letter per door at most', () {
      expect(DoorLabelStyle.letterCount, 26);
    });
  });

  group('create', () {
    test('should keep what it was given', () {
      final plan = _plan(staircases: 2, topFloor: 3, doors: 6, style: _letter);

      expect(plan.staircaseCount, 2);
      expect(plan.staircases, [_stairs(3, 6), _stairs(3, 6)]);
      expect(plan.style, _letter);
      expect(plan.isUniform, isTrue);
    });

    test('should accept unknown floors', () {
      expect(_plan(topFloor: null).staircases.single.topFloor, isNull);
    });

    test('should count the dwellings of the Décrire l’immeuble preview', () {
      expect(_plan(staircases: 2, topFloor: 5, doors: 4).dwellingCount, 48);
    });

    test('should count one row per staircase when floors are unknown', () {
      expect(_plan(staircases: 3, topFloor: null, doors: 7).dwellingCount, 21);
    });

    group('limits', () {
      test('should refuse no staircase', () {
        expect(_failure(staircases: 0), BuildingPlanFailure.noStaircase);
      });

      test('should accept one staircase', () {
        expect(_plan(staircases: 1).staircaseCount, 1);
      });

      test('should accept as many staircases as letters', () {
        expect(
          _plan(staircases: 26, topFloor: 0, doors: 1).staircaseCount,
          StaircaseName.maxCount,
        );
      });

      test('should refuse more staircases than letters', () {
        expect(
          _failure(staircases: 27, topFloor: 0, doors: 1),
          BuildingPlanFailure.tooManyStaircases,
        );
      });

      test('should refuse a top floor below the RdC', () {
        expect(_failure(topFloor: -1), BuildingPlanFailure.belowGroundFloor);
      });

      test('should accept the RdC alone', () {
        expect(_plan(topFloor: 0).staircases.single.topFloor, 0);
      });

      test('should accept the highest top floor', () {
        expect(
          _plan(
            topFloor: BuildingPlan.maxTopFloor,
            doors: 1,
          ).staircases.single.topFloor,
          50,
        );
      });

      test('should refuse a top floor above the highest', () {
        expect(
          _failure(topFloor: BuildingPlan.maxTopFloor + 1, doors: 1),
          BuildingPlanFailure.tooManyFloors,
        );
      });

      test('should refuse no door per floor', () {
        expect(_failure(doors: 0), BuildingPlanFailure.noDoor);
      });

      test('should accept one door per floor', () {
        expect(_plan(doors: 1).staircases.single.doorsPerFloor, 1);
      });

      test('should accept 26 doors per floor with letters', () {
        expect(
          _plan(doors: 26, style: _letter).staircases.single.doorsPerFloor,
          26,
        );
      });

      test('should refuse 27 doors per floor with letters', () {
        expect(
          _failure(doors: 27, style: _letter),
          BuildingPlanFailure.tooManyDoorsForLetters,
        );
      });

      test('should accept 27 doors per floor with numbers', () {
        expect(
          _plan(doors: 27, style: _number).staircases.single.doorsPerFloor,
          27,
        );
      });

      test('should accept the largest building', () {
        expect(
          _plan(topFloor: null, doors: BuildingPlan.maxDwellings).dwellingCount,
          500,
        );
      });

      test('should refuse one dwelling more than the largest building', () {
        expect(
          _failure(topFloor: null, doors: BuildingPlan.maxDwellings + 1),
          BuildingPlanFailure.tooManyDwellings,
        );
      });

      test('should count every staircase and floor against the limit', () {
        // 2 × 26 × 10 = 520 dwellings.
        expect(
          _failure(staircases: 2, topFloor: 25, doors: 10),
          BuildingPlanFailure.tooManyDwellings,
        );
      });
    });
  });

  group('generate', () {
    test('should number RdC 01–04 up to 5e 51–54, top floor first', () {
      final staircases = _plan().generate();

      expect(staircases, hasLength(1));
      expect(staircases.single.name, escA);
      expect(_rows(staircases.single), [
        '5: 51 52 53 54',
        '4: 41 42 43 44',
        '3: 31 32 33 34',
        '2: 21 22 23 24',
        '1: 11 12 13 14',
        '0: 01 02 03 04',
      ]);
    });

    test('should give each staircase its letter and the same floors', () {
      final staircases = _plan(staircases: 2, topFloor: 1, doors: 2).generate();

      expect(staircases.map((s) => s.name), [escA, escB]);
      expect(_rows(staircases[1]), ['1: 11 12', '0: 01 02']);
    });

    test('should pad the doors to two digits when a floor has 10', () {
      final staircase = _plan(topFloor: 1, doors: 10).generate().single;

      expect(_rows(staircase), [
        '1: 101 102 103 104 105 106 107 108 109 110',
        '0: 001 002 003 004 005 006 007 008 009 010',
      ]);
    });

    test('should not pad the doors when a floor has 9', () {
      final staircase = _plan(topFloor: 0, doors: 9).generate().single;

      expect(_rows(staircase), ['0: 01 02 03 04 05 06 07 08 09']);
    });

    test('should not show floor 1 door 11 like floor 11 door 1', () {
      final staircase = _plan(topFloor: 11, doors: 11).generate().single;
      final labels = staircase.dwellings.map((d) => d.label.text).toList();

      expect(labels, containsAll(['111', '1101']));
      expect(labels.toSet(), hasLength(labels.length));
    });

    test('should put the floor before the door from the 10e up', () {
      final staircase = _plan(topFloor: 10, doors: 2).generate().single;

      expect(_rows(staircase).first, '10: 101 102');
      expect(_rows(staircase)[9], '1: 11 12');
    });

    test('should letter the doors with style 5A', () {
      final staircase = _plan(
        topFloor: 1,
        doors: 3,
        style: _letter,
      ).generate().single;

      expect(_rows(staircase), ['1: 1A 1B 1C', '0: 0A 0B 0C']);
    });

    test('should end with the letter Z on a floor of 26 doors', () {
      final staircase = _plan(
        topFloor: 0,
        doors: 26,
        style: _letter,
      ).generate().single;

      expect(staircase.dwellings.last.label, d('0Z'));
    });

    test('should number free doors from 1 again on each floor', () {
      final staircase = _plan(
        topFloor: 2,
        doors: 2,
        style: _free,
      ).generate().single;

      expect(_rows(staircase), ['2: 1 2', '1: 1 2', '0: 1 2']);
    });

    test(
      'should make one Logements row without level when floors are unknown',
      () {
        final staircase = _plan(topFloor: null, doors: 4).generate().single;

        expect(_rows(staircase), ['null: 1 2 3 4']);
      },
    );

    test('should letter the Logements row with style 5A', () {
      final staircase = _plan(
        topFloor: null,
        doors: 3,
        style: _letter,
      ).generate().single;

      expect(_rows(staircase), ['null: A B C']);
    });

    test('should number the Logements row with free labels', () {
      final staircase = _plan(
        topFloor: null,
        doors: 3,
        style: _free,
      ).generate().single;

      expect(_rows(staircase), ['null: 1 2 3']);
    });

    test('should make one floor when there is only the RdC', () {
      final staircase = _plan(topFloor: 0, doors: 2).generate().single;

      expect(_rows(staircase), ['0: 01 02']);
    });

    test('should make every dwelling new and to do', () {
      final dwellings = _plan(staircases: 2)
          .generate()
          .expand((s) => s.dwellings);

      expect(dwellings, hasLength(48));
      for (final dwelling in dwellings) {
        expect(dwelling.status, VisitStatus.toDo);
        expect(dwelling.comeBack, isNull);
        expect(dwelling.lastChange, isNull);
      }
    });
  });

  group('perStaircase', () {
    test('should keep the floors and doors of each staircase', () {
      final plan = _uneven();

      expect(plan.staircases, [_stairs(5, 4), _stairs(2, 2)]);
      expect(plan.staircaseCount, 2);
      expect(plan.style, _number);
      expect(plan.isUniform, isFalse);
    });

    test('should be uniform when every staircase is alike', () {
      expect(_uneven(b: _stairs(5, 4)).isUniform, isTrue);
    });

    test('should differ from uniform when only the doors differ', () {
      expect(_uneven(b: _stairs(5, 3)).isUniform, isFalse);
    });

    test('should not let its staircases be modified', () {
      expect(
        () => _uneven().staircases.add(_stairs(1, 1)),
        throwsUnsupportedError,
      );
    });

    test('should count the dwellings of every staircase: 24 + 6', () {
      expect(_uneven().dwellingCount, 30);
    });

    test('should count one row for a staircase whose floors are unknown', () {
      expect(_uneven(b: _stairs(null, 3)).dwellingCount, 27);
    });

    test('should equal the uniform plan with the same staircases', () {
      expect(
        _uneven(b: _stairs(5, 4)),
        _plan(staircases: 2, topFloor: 5, doors: 4),
      );
    });

    group('limits', () {
      final refusals = <String, (StaircasePlan, DoorLabelStyle, Object)>{
        'a top floor of B below the RdC': (
          _stairs(-1, 2),
          _number,
          BuildingPlanFailure.belowGroundFloor,
        ),
        'a top floor of B above the 50th': (
          _stairs(51, 1),
          _number,
          BuildingPlanFailure.tooManyFloors,
        ),
        'no door on the floors of B': (
          _stairs(2, 0),
          _number,
          BuildingPlanFailure.noDoor,
        ),
        '27 doors a floor in B with letters': (
          _stairs(0, 27),
          _letter,
          BuildingPlanFailure.tooManyDoorsForLetters,
        ),
        // A has 24 dwellings: B's 477 make 501.
        'one dwelling more than 500 in all': (
          _stairs(null, 477),
          _number,
          BuildingPlanFailure.tooManyDwellings,
        ),
      };
      refusals.forEach((what, given) {
        final (b, style, failure) = given;
        test('should refuse $what', () {
          expect(_unevenFailure(b, style: style), failure);
        });
      });

      final accepted = <String, (StaircasePlan, DoorLabelStyle, int)>{
        'unknown floors in B': (_stairs(null, 2), _number, 26),
        'the RdC alone in B': (_stairs(0, 2), _number, 26),
        'the 50th floor in B': (_stairs(50, 1), _number, 75),
        'one door a floor in B': (_stairs(2, 1), _number, 27),
        '26 doors a floor in B with letters': (_stairs(0, 26), _letter, 50),
        '27 doors a floor in B with numbers': (_stairs(0, 27), _number, 51),
        '500 dwellings in all': (_stairs(null, 476), _number, 500),
      };
      accepted.forEach((what, given) {
        final (b, style, dwellings) = given;
        test('should accept $what', () {
          expect(_uneven(b: b, style: style).dwellingCount, dwellings);
        });
      });

      test('should refuse no staircase', () {
        expect(
          failureOf(BuildingPlan.perStaircase(staircases: [], style: _number)),
          BuildingPlanFailure.noStaircase,
        );
      });

      test('should accept 26 staircases and refuse 27', () {
        expect(
          valueOf(
            BuildingPlan.perStaircase(
              staircases: List.filled(26, _stairs(0, 1)),
              style: _number,
            ),
          ).staircaseCount,
          26,
        );
        expect(
          failureOf(
            BuildingPlan.perStaircase(
              staircases: List.filled(27, _stairs(0, 1)),
              style: _number,
            ),
          ),
          BuildingPlanFailure.tooManyStaircases,
        );
      });

      test('should check staircase A as well as B', () {
        expect(
          failureOf(
            BuildingPlan.perStaircase(
              staircases: [_stairs(2, 0), _stairs(2, 2)],
              style: _number,
            ),
          ),
          BuildingPlanFailure.noDoor,
        );
      });
    });

    group('generate', () {
      test('should lay out each staircase as its own answers say', () {
        final staircases = _uneven().generate();

        expect(staircases.map((s) => s.name), [escA, escB]);
        expect(_rows(staircases[0]).first, '5: 51 52 53 54');
        expect(_rows(staircases[0]).last, '0: 01 02 03 04');
        expect(_rows(staircases[1]), ['2: 21 22', '1: 11 12', '0: 01 02']);
      });

      test('should pad the doors of each staircase to its own count', () {
        final staircases = _uneven(b: _stairs(0, 10)).generate();

        expect(_rows(staircases[0]).last, '0: 01 02 03 04');
        expect(_rows(staircases[1]), [
          '0: 001 002 003 004 005 006 007 008 009 010',
        ]);
      });

      test('should make one Logements row for B only when its floors are '
          'unknown', () {
        final staircases = _uneven(b: _stairs(null, 2)).generate();

        expect(staircases[0].floors, hasLength(6));
        expect(_rows(staircases[1]), ['null: 1 2']);
      });
    });
  });

  group('StaircasePlan', () {
    test('should count its dwellings', () {
      expect(_stairs(5, 4).dwellingCount, 24);
      expect(_stairs(0, 3).dwellingCount, 3);
      expect(_stairs(null, 7).dwellingCount, 7);
    });

    test('should be equal when its floors and doors are', () {
      expect(_stairs(2, 2), _stairs(2, 2));
      expect(_stairs(2, 2).hashCode, _stairs(2, 2).hashCode);
      expect(_stairs(2, 2), isNot(_stairs(3, 2)));
      expect(_stairs(2, 2), isNot(_stairs(2, 3)));
      expect(_stairs(null, 2), isNot(_stairs(0, 2)));
    });

    test('should show its fields when printed', () {
      expect(
        _stairs(null, 3).toString(),
        'StaircasePlan(top floor null, 3 door(s) per floor)',
      );
    });
  });

  group('equality', () {
    test('should be equal when every field is equal', () {
      expect(_plan(), _plan());
      expect(_plan().hashCode, _plan().hashCode);
    });

    final others = <String, BuildingPlan>{
      'staircase counts': _plan(staircases: 2),
      'top floors': _plan(topFloor: 4),
      'door counts': _plan(doors: 3),
      'styles': _plan(style: _letter),
      'staircases B': _uneven(b: _stairs(5, 3)),
    };
    others.forEach((field, other) {
      test('should differ when the $field differ', () {
        expect(_plan(), isNot(other));
      });
    });

    test('should show its fields when printed', () {
      expect(
        _plan().toString(),
        'BuildingPlan([StaircasePlan(top floor 5, 4 door(s) per floor)], '
        'DoorLabelStyle.floorAndNumber)',
      );
    });
  });
}
