import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/street_fixtures.dart';

void main() {
  final fourteen = House(
    number: n('14ter'),
    status: VisitStatus.done,
    note: note('chien'),
  );

  test('should keep the house and who removed it when', () {
    final removed = RemovedHouse(house: fourteen, removal: leaAtTwo);

    expect(removed.house, fourteen);
    expect(removed.removal, leaAtTwo);
    expect(removed.number, n('14ter'));
  });

  test('should be equal when the house and the removal are equal', () {
    final a = RemovedHouse(house: fourteen, removal: leaAtTwo);
    final b = RemovedHouse(house: fourteen, removal: leaAtTwo);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('should differ when the houses differ', () {
    expect(
      RemovedHouse(house: fourteen, removal: leaAtTwo),
      isNot(
        RemovedHouse(
          house: House(number: n('14ter')),
          removal: leaAtTwo,
        ),
      ),
    );
  });

  test('should differ when the removals differ', () {
    expect(
      RemovedHouse(house: fourteen, removal: leaAtTwo),
      isNot(RemovedHouse(house: fourteen, removal: paulAtThree)),
    );
  });

  test('should differ from its house', () {
    expect(RemovedHouse(house: fourteen, removal: leaAtTwo), isNot(fourteen));
  });

  test('should show its house and removal when printed', () {
    expect(
      RemovedHouse(
        house: House(number: n('3')),
        removal: leaAtTwo,
      ).toString(),
      'RemovedHouse(House(3, VisitStatus.toDo, null, Note(), null), '
      'ChangeStamp(lea, 2026-11-02 14:02:00.000Z))',
    );
  });
}
