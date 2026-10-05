// A house keeps where its door is whatever command changes it: the map dot
// must not vanish after a tap (PLAN §6.1).
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/building_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// Number 5 a single house « repasser » at the town hall door, number 8 a one-door
/// building (RdC 01) at the north door.
final _street = valueOf(
  Street.create(
    id: StreetId('rue-nationale'),
    name: 'Rue Nationale',
    commune: villefranche,
    houses: [
      House(
        number: n('5'),
        status: VisitStatus.comeBack,
        position: townHallDoor,
      ),
      House(
        number: n('8'),
        position: northDoor,
        building: building(topFloor: 0, doors: 1),
      ),
    ],
  ),
);

final _door = DwellingKey(escA, 0, d('01'));

/// The position of the house numbered [label] in [street].
Object? _positionOf(Street street, String label) =>
    street.houses.singleWhere((house) => house.number == n(label)).position;

void main() {
  test('should keep the position when a house is marked', () {
    final (street, _) = valueOf(
      _street.markHouse(n('5'), VisitStatus.done, by: lea, at: twoPm),
    );

    expect(_positionOf(street, '5'), townHallDoor);
  });

  test('should keep the position when a come-back is set', () {
    final (street, _) = valueOf(
      _street.setComeBack(n('5'), comeBack('soir'), by: lea, at: twoPm),
    );

    expect(_positionOf(street, '5'), townHallDoor);
  });

  test('should keep the position when a house becomes a building', () {
    final (street, _) = valueOf(
      _street.describeBuilding(n('5'), plan(), by: lea, at: twoPm),
    );

    expect(_positionOf(street, '5'), townHallDoor);
  });

  test('should keep the position when a door is added', () {
    final (street, _) = valueOf(
      _street.addDoor(n('8'), escA, 0, by: lea, at: twoPm),
    );

    expect(_positionOf(street, '8'), northDoor);
  });

  test('should keep the position when a building becomes a house', () {
    final (street, _) = valueOf(
      _street.removeBuilding(n('8'), by: lea, at: twoPm),
    );

    expect(_positionOf(street, '8'), northDoor);
  });

  test('should keep the position when a door is marked', () {
    final (street, _) = valueOf(
      _street.markDwelling(n('8'), _door, VisitStatus.done, by: lea, at: twoPm),
    );

    expect(_positionOf(street, '8'), northDoor);
  });

  test('should keep the position when a house is renumbered', () {
    final (street, change) = valueOf(
      _street.renameNumber(n('5'), n('5bis'), by: lea, at: twoPm),
    );

    expect(_positionOf(street, '5bis'), townHallDoor);
    expect(change.after.position, townHallDoor);
  });

  test('should keep the position when a number goes and comes back', () {
    final (removed, _) = valueOf(
      _street.removeNumber(n('5'), by: lea, at: twoPm),
    );
    final (restored, _) = valueOf(removed.restoreNumber(n('5')));

    expect(removed.removedHouses.single.house.position, townHallDoor);
    expect(_positionOf(restored, '5'), townHallDoor);
  });
}
