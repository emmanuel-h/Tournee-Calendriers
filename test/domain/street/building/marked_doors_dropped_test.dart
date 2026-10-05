import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../../support/building_fixtures.dart';
import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';

/// [building] with the door [label] of floor [level] of [staircase]
/// replaced by [door].
Building _with(
  Building building,
  StaircaseName staircase,
  int? level,
  Dwelling door,
) => building.withDwelling(staircase, level, door);

void main() {
  // Two staircases, RdC to 2e, two doors a floor: A2 21 22 … B0 01 02.
  final empty = building(staircases: 2, topFloor: 2, doors: 2);

  group('markedDoorsDroppedBy', () {
    test('should count nothing when no door has a mark', () {
      expect(empty.markedDoorsDroppedBy(plan(topFloor: 0, doors: 1)), 0);
    });

    test('should count nothing when the marked doors stay', () {
      final marked = _with(
        empty,
        escA,
        2,
        Dwelling(label: d('22'), status: VisitStatus.done),
      );

      expect(
        marked.markedDoorsDroppedBy(plan(staircases: 2, topFloor: 3, doors: 2)),
        0,
      );
    });

    test('should count a done door whose floor goes', () {
      final marked = _with(
        empty,
        escA,
        2,
        Dwelling(label: d('21'), status: VisitStatus.done),
      );

      expect(
        marked.markedDoorsDroppedBy(plan(staircases: 2, topFloor: 1, doors: 2)),
        1,
      );
    });

    test('should count a door nobody answered or a « repasser »', () {
      final marked = _with(
        _with(
          empty,
          escB,
          0,
          Dwelling(label: d('02'), status: VisitStatus.nobodyHome),
        ),
        escB,
        1,
        Dwelling(
          label: d('12'),
          status: VisitStatus.comeBack,
          comeBack: comeBack('soir'),
        ),
      );

      expect(
        marked.markedDoorsDroppedBy(plan(staircases: 2, topFloor: 2, doors: 1)),
        2,
      );
    });

    test('should count the marked doors of a staircase that goes', () {
      final marked = _with(
        _with(
          empty,
          escB,
          0,
          Dwelling(label: d('01'), status: VisitStatus.nobodyHome),
        ),
        escA,
        0,
        Dwelling(label: d('01'), status: VisitStatus.nobodyHome),
      );

      expect(
        marked.markedDoorsDroppedBy(plan(staircases: 1, topFloor: 2, doors: 2)),
        1,
      );
    });

    test('should count the marked doors whose labels change with the '
        'style', () {
      final marked = _with(
        empty,
        escA,
        1,
        Dwelling(label: d('11'), status: VisitStatus.done),
      );

      expect(
        marked.markedDoorsDroppedBy(
          plan(
            staircases: 2,
            topFloor: 2,
            doors: 2,
            style: DoorLabelStyle.floorAndLetter,
          ),
        ),
        1,
      );
    });

    test('should count only the marked doors of the staircase made '
        'smaller', () {
      // A keeps RdC–2e; B shrinks to the RdC with one door: B's 21 (done)
      // and 02 (nobody home) go, A's 21 (done) and B's 01 (done) stay.
      final marked = _with(
        _with(
          _with(
            _with(
              empty,
              escA,
              2,
              Dwelling(label: d('21'), status: VisitStatus.done),
            ),
            escB,
            2,
            Dwelling(label: d('21'), status: VisitStatus.done),
          ),
          escB,
          0,
          Dwelling(label: d('02'), status: VisitStatus.nobodyHome),
        ),
        escB,
        0,
        Dwelling(label: d('01'), status: VisitStatus.done),
      );
      final smallerB = valueOf(
        BuildingPlan.perStaircase(
          staircases: const [
            StaircasePlan(topFloor: 2, doorsPerFloor: 2),
            StaircasePlan(topFloor: 0, doorsPerFloor: 1),
          ],
          style: DoorLabelStyle.floorAndNumber,
        ),
      );

      expect(marked.markedDoorsDroppedBy(smallerB), 2);
    });

    test('should count a door the « Logements » row no longer has', () {
      final unknown = building(topFloor: null, doors: 3);
      final marked = _with(
        unknown,
        escA,
        null,
        Dwelling(label: d('3'), status: VisitStatus.done),
      );

      expect(marked.markedDoorsDroppedBy(plan(topFloor: null, doors: 3)), 0);
      expect(marked.markedDoorsDroppedBy(plan(topFloor: null, doors: 2)), 1);
    });
  });
}
