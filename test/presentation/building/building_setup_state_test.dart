import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/presentation/building/building_setup_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/street_fixtures.dart';

void main() {
  group('BuildingPreview.of', () {
    test('should give the RdC, the 1er, then the top floor after a gap, as '
        'the mockup', () {
      final preview = BuildingPreview.of(plan(staircases: 2));

      expect(preview.dwellings, 48);
      expect(preview.staircases, [escA, escB]);
      expect(preview.floors, [
        (level: 0, first: '01', last: '04'),
        (level: 1, first: '11', last: '14'),
        (level: 5, first: '51', last: '54'),
      ]);
      expect(preview.skipsFloors, isTrue);
    });

    test('should give every floor and no gap up to three floors', () {
      final preview = BuildingPreview.of(plan(topFloor: 2, doors: 2));

      expect(preview.dwellings, 6);
      expect(preview.staircases, [escA]);
      expect(preview.floors, [
        (level: 0, first: '01', last: '02'),
        (level: 1, first: '11', last: '12'),
        (level: 2, first: '21', last: '22'),
      ]);
      expect(preview.skipsFloors, isFalse);
    });

    test('should leave a gap from four floors on', () {
      final preview = BuildingPreview.of(plan(topFloor: 3, doors: 1));

      expect(preview.floors.map((floor) => floor.level), [0, 1, 3]);
      expect(preview.skipsFloors, isTrue);
    });

    test('should give the RdC alone', () {
      final preview = BuildingPreview.of(plan(topFloor: 0, doors: 1));

      expect(preview.floors, [(level: 0, first: '01', last: '01')]);
      expect(preview.skipsFloors, isFalse);
    });

    test('should give the « Logements » row when the floors are unknown', () {
      final preview = BuildingPreview.of(
        plan(staircases: 3, topFloor: null, doors: 3),
      );

      expect(preview.dwellings, 9);
      expect(preview.staircases, hasLength(3));
      expect(preview.floors, [(level: null, first: '1', last: '3')]);
    });

    test('should follow the label style', () {
      final preview = BuildingPreview.of(
        plan(topFloor: 1, doors: 3, style: DoorLabelStyle.floorAndLetter),
      );

      expect(preview.floors, [
        (level: 0, first: '0A', last: '0C'),
        (level: 1, first: '1A', last: '1C'),
      ]);
    });
  });
}
