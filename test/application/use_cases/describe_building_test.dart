import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

void main() {
  late FakeStreetRepository streets;
  late DescribeBuilding describeBuilding;

  setUp(() {
    streets = repositoryWithLilas();
    describeBuilding = DescribeBuilding(streets, clockAtTwo(), leaOnThePhone());
  });

  Building? buildingOf(String label) =>
      houseOf(streets[lilasId]!, label).building;

  test('should make a house the building of the plan', () async {
    final change = valueOf(
      await describeBuilding(
        lilasId,
        n('7'),
        LayOutBuilding(plan(topFloor: 1, doors: 2)),
      ),
    );

    expect(
      change,
      BuildingLaidOut(
        streetId: lilasId,
        before: seven,
        stamp: leaAtTwo,
        building: building(topFloor: 1, doors: 2),
      ),
    );
    expect(streets.saved.single.$2, change);
    expect(buildingOf('7'), building(topFloor: 1, doors: 2));
  });

  test('should add a door at the end of a floor', () async {
    final change = valueOf(
      await describeBuilding(lilasId, n('8'), AddDoor(escA, 0)),
    );

    expect(change, isA<BuildingLaidOut>());
    expect(change.before, eight);
    expect(buildingOf('8')!.dwellingAt(rdc('03')), Dwelling(label: d('03')));
  });

  test('should remove a door', () async {
    valueOf(await describeBuilding(lilasId, n('8'), RemoveDoor(rdc('02'))));

    expect(buildingOf('8')!.dwellingAt(rdc('02')), isNull);
    expect(buildingOf('8')!.dwellingAt(rdc('01')), doorOne);
  });

  test('should rename a door and keep its marks', () async {
    valueOf(
      await describeBuilding(
        lilasId,
        n('8'),
        RenameDoor(rdc('01'), d('Gauche')),
      ),
    );

    final renamed = buildingOf('8')!.dwellingAt(rdc('Gauche'))!;
    expect(renamed.status, VisitStatus.done);
    expect(renamed.lastChange, paulAtThree);
  });

  test('should turn a building back into a single house', () async {
    final change = valueOf(
      // Built at run time, as the screen does: a `const` instance is made by
      // the compiler, so its constructor line would never count as covered.
      // ignore: prefer_const_constructors
      await describeBuilding(lilasId, n('8'), BackToSingleHouse()),
    );

    expect(
      change,
      BuildingRemoved(
        streetId: lilasId,
        before: eight,
        stamp: leaAtTwo,
        status: VisitStatus.toDo,
      ),
    );
    expect(buildingOf('8'), isNull);
  });

  test('should fail when the street refuses the edit', () async {
    final failure = failureOf(
      await describeBuilding(lilasId, n('7'), const BackToSingleHouse()),
    );

    expect(failure, const CommandRefused(BuildingChangeFailure.notABuilding));
    expect(streets.saved, isEmpty);
  });

  test('should fail when the house to lay out is unknown', () async {
    final failure = failureOf(
      await describeBuilding(lilasId, n('99'), LayOutBuilding(plan())),
    );

    expect(failure, const CommandRefused(BuildingChangeFailure.unknownHouse));
  });

  test('should fail when the street is unknown', () async {
    final failure = failureOf(
      await describeBuilding(
        StreetId('rue-inconnue'),
        n('8'),
        const BackToSingleHouse(),
      ),
    );

    expect(failure, const StreetNotFound<BuildingChangeFailure>());
  });
}
