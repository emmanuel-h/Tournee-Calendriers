import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/presentation/building/building_setup_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

void main() {
  group('BuildingPreview.of', () {
    test('should give the RdC, the 1er, then the top floor after a gap, as '
        'the mockup', () {
      final preview = BuildingPreview.of(plan(staircases: 2));

      expect(preview.dwellings, 48);
      expect(preview.namesStaircases, isTrue);
      final part = preview.parts.single;
      expect(part.staircases, [escA, escB]);
      expect(part.floors, [
        (level: 0, first: '01', last: '04'),
        (level: 1, first: '11', last: '14'),
        (level: 5, first: '51', last: '54'),
      ]);
      expect(part.skipsFloors, isTrue);
    });

    test('should give every floor and no gap up to three floors', () {
      final preview = BuildingPreview.of(plan(topFloor: 2, doors: 2));

      expect(preview.dwellings, 6);
      expect(preview.namesStaircases, isFalse);
      final part = preview.parts.single;
      expect(part.staircases, [escA]);
      expect(part.floors, [
        (level: 0, first: '01', last: '02'),
        (level: 1, first: '11', last: '12'),
        (level: 2, first: '21', last: '22'),
      ]);
      expect(part.skipsFloors, isFalse);
    });

    test('should leave a gap from four floors on', () {
      final preview = BuildingPreview.of(plan(topFloor: 3, doors: 1));

      final part = preview.parts.single;
      expect(part.floors.map((floor) => floor.level), [0, 1, 3]);
      expect(part.skipsFloors, isTrue);
    });

    test('should give the RdC alone', () {
      final preview = BuildingPreview.of(plan(topFloor: 0, doors: 1));

      final part = preview.parts.single;
      expect(part.floors, [(level: 0, first: '01', last: '01')]);
      expect(part.skipsFloors, isFalse);
    });

    test('should give the « Logements » row when the floors are unknown', () {
      final preview = BuildingPreview.of(
        plan(staircases: 3, topFloor: null, doors: 3),
      );

      expect(preview.dwellings, 9);
      expect(preview.parts.single.staircases, hasLength(3));
      expect(preview.parts.single.floors, [
        (level: null, first: '1', last: '3'),
      ]);
    });

    test('should follow the label style', () {
      final preview = BuildingPreview.of(
        plan(topFloor: 1, doors: 3, style: DoorLabelStyle.floorAndLetter),
      );

      expect(preview.parts.single.floors, [
        (level: 0, first: '0A', last: '0C'),
        (level: 1, first: '1A', last: '1C'),
      ]);
    });

    group('when the staircases differ', () {
      BuildingPreview of(List<StaircasePlan> staircases) => BuildingPreview.of(
        valueOf(
          BuildingPlan.perStaircase(
            staircases: staircases,
            style: DoorLabelStyle.floorAndNumber,
          ),
        ),
      );

      test('should give one part per staircase, its RdC then its top floor '
          'after a gap: the sketch', () {
        final preview = of(const [
          StaircasePlan(topFloor: 5, doorsPerFloor: 4),
          StaircasePlan(topFloor: 2, doorsPerFloor: 2),
        ]);

        expect(preview.dwellings, 30);
        expect(preview.namesStaircases, isTrue);
        expect(preview.parts, hasLength(2));
        expect(preview.parts[0].staircases, [escA]);
        expect(preview.parts[0].floors, [
          (level: 0, first: '01', last: '04'),
          (level: 5, first: '51', last: '54'),
        ]);
        expect(preview.parts[0].skipsFloors, isTrue);
        expect(preview.parts[1].staircases, [escB]);
        expect(preview.parts[1].floors, [
          (level: 0, first: '01', last: '02'),
          (level: 2, first: '21', last: '22'),
        ]);
        expect(preview.parts[1].skipsFloors, isTrue);
      });

      test('should give both floors and no gap for RdC–1er, and the RdC '
          'alone', () {
        final preview = of(const [
          StaircasePlan(topFloor: 1, doorsPerFloor: 2),
          StaircasePlan(topFloor: 0, doorsPerFloor: 1),
        ]);

        expect(preview.parts[0].floors.map((floor) => floor.level), [0, 1]);
        expect(preview.parts[0].skipsFloors, isFalse);
        expect(preview.parts[1].floors, [(level: 0, first: '01', last: '01')]);
        expect(preview.parts[1].skipsFloors, isFalse);
      });

      test('should give the « Logements » row of a staircase whose floors '
          'are unknown', () {
        final preview = of(const [
          StaircasePlan(topFloor: 0, doorsPerFloor: 2),
          StaircasePlan(topFloor: null, doorsPerFloor: 3),
        ]);

        expect(preview.parts[1].floors, [(level: null, first: '1', last: '3')]);
      });
    });
  });
}
