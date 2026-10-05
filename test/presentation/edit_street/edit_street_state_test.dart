import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_state.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/street_fixtures.dart';

void main() {
  group('EditTile', () {
    test('should name a single house', () {
      final tile = EditTile.of(House(number: n('3bis')));

      expect(tile.number, n('3bis'));
      expect(tile.isBuilding, isFalse);
      expect(tile.toString(), 'EditTile(3bis)');
    });

    test('should say a building is one', () {
      final tile = EditTile.of(
        House(number: n('8'), building: building(topFloor: 0, doors: 2)),
      );

      expect(tile.isBuilding, isTrue);
      expect(tile.toString(), 'EditTile(8, building)');
    });

    test('should be equal when number and kind are', () {
      final tile = EditTile(number: n('8'), isBuilding: true);

      expect(tile, EditTile(number: n('8'), isBuilding: true));
      expect(
        tile.hashCode,
        EditTile(number: n('8'), isBuilding: true).hashCode,
      );
      expect(tile, isNot(EditTile(number: n('8'), isBuilding: false)));
      expect(tile, isNot(EditTile(number: n('10'), isBuilding: true)));
    });
  });

  group('EditStreetShown.tileOf', () {
    final state = EditStreetShown(
      name: 'Rue des Lilas',
      columns: StreetColumns.both,
      odd: [EditTile(number: n('1'), isBuilding: false)],
      even: [EditTile(number: n('8'), isBuilding: true)],
    );

    test('should find a tile of either side', () {
      expect(state.tileOf(n('1')), EditTile(number: n('1'), isBuilding: false));
      expect(state.tileOf(n('8')), EditTile(number: n('8'), isBuilding: true));
    });

    test('should find nothing for a number not shown', () {
      expect(state.tileOf(n('3')), isNull);
    });
  });

  group('RenumberOutcome', () {
    test('should be equal by value', () {
      expect(Renumbered(n('3bis')), Renumbered(n('3bis')));
      expect(Renumbered(n('3bis')).hashCode, Renumbered(n('3bis')).hashCode);
      expect(Renumbered(n('3bis')), isNot(Renumbered(n('3ter'))));
      expect(
        const RenumberInvalid(HouseNumberFailure.malformed).hashCode,
        const RenumberInvalid(HouseNumberFailure.malformed).hashCode,
      );
      expect(
        const RenumberInvalid(HouseNumberFailure.malformed),
        isNot(const RenumberInvalid(HouseNumberFailure.empty)),
      );
      expect(RenumberTaken(n('5')).hashCode, RenumberTaken(n('5')).hashCode);
      expect(RenumberTaken(n('5')), isNot(RenumberTaken(n('7'))));
      expect(
        RenumberInCorbeille(n('7')).hashCode,
        RenumberInCorbeille(n('7')).hashCode,
      );
      expect(RenumberInCorbeille(n('7')), isNot(RenumberInCorbeille(n('9'))));
    });

    test('should name its numbers when printed', () {
      expect(Renumbered(n('3bis')).toString(), 'Renumbered(3bis)');
      expect(
        const RenumberInvalid(HouseNumberFailure.malformed).toString(),
        'RenumberInvalid(HouseNumberFailure.malformed)',
      );
      expect(RenumberTaken(n('5')).toString(), 'RenumberTaken(5)');
      expect(RenumberInCorbeille(n('7')).toString(), 'RenumberInCorbeille(7)');
    });
  });
}
