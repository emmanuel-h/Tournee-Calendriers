// A street added without its line on the map gets it later, once
// (PLAN §5.3, #92): the shape is filled while it is empty, never replaced.
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _road = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);

final _otherRoad = StreetShape([
  [at(45.98800, 4.72500), at(45.98900, 4.72500)],
]);

/// Rue Nationale without a line, one house on the map and one marked.
Street _nationale({
  StreetShape shape = StreetShape.none,
  bool positioned = true,
}) => valueOf(
  Street.create(
    id: StreetId('nationale'),
    name: 'Rue Nationale',
    commune: villefranche,
    banId: BanStreetId('69264_1460'),
    shape: shape,
    assignees: {lea},
    houses: [
      House(
        number: n('1'),
        position: positioned ? at(45.98920, 4.71860) : null,
      ),
      House(number: n('2'), status: VisitStatus.done),
    ],
  ),
);

void main() {
  group('fillShape', () {
    test('should give the street the shape when it has none', () {
      final (street, change) = valueOf(_nationale().fillShape(_road));

      expect(street.shape, _road);
      expect(
        change,
        StreetShapeFilled(streetId: StreetId('nationale'), shape: _road),
      );
    });

    test('should change nothing else', () {
      final before = _nationale();

      final (street, _) = valueOf(before.fillShape(_road));

      expect(street.id, before.id);
      expect(street.name, before.name);
      expect(street.commune, before.commune);
      expect(street.banId, before.banId);
      expect(street.assignees, {lea});
      expect(street.houses, before.houses);
      expect(street.removedHouses, before.removedHouses);
      expect(street.deletion, isNull);
    });

    test('should keep the Corbeille of a deleted street', () {
      final (deleted, _) = _nationale().delete(by: lea, at: twoPm);

      final (street, _) = valueOf(deleted.fillShape(_road));

      expect(street.deletion, deleted.deletion);
    });

    test('should refuse a street that has a shape already', () {
      expect(
        failureOf(_nationale(shape: _otherRoad).fillShape(_road)),
        ShapeFillFailure.alreadyShaped,
      );
    });

    test('should refuse a shape without any line', () {
      expect(
        failureOf(_nationale().fillShape(StreetShape.none)),
        ShapeFillFailure.noLine,
      );
    });

    test('should not be undone', () {
      final (street, change) = valueOf(_nationale().fillShape(_road));

      expect(failureOf(street.undo(change)), UndoFailure.notUndoable);
    });
  });

  group('needsShape', () {
    test('should need a shape without one, with a house on the map', () {
      expect(_nationale().needsShape, isTrue);
    });

    test('should not need one once it has one', () {
      expect(_nationale(shape: _road).needsShape, isFalse);
    });

    test('should not need one without any house on the map', () {
      expect(_nationale(positioned: false).needsShape, isFalse);
    });

    test('should not need one in the Corbeille', () {
      final (deleted, _) = _nationale().delete(by: lea, at: twoPm);

      expect(deleted.needsShape, isFalse);
    });
  });

  group('StreetShapeFilled', () {
    final change = StreetShapeFilled(
      streetId: StreetId('nationale'),
      shape: _road,
    );

    test('should be equal when every field is equal', () {
      final same = StreetShapeFilled(
        streetId: StreetId('nationale'),
        shape: StreetShape([
          [at(45.98915, 4.71862), at(45.99210, 4.71705)],
        ]),
      );

      expect(change, same);
      expect(change.hashCode, same.hashCode);
    });

    test('should differ when the streets differ', () {
      expect(
        change,
        isNot(StreetShapeFilled(streetId: StreetId('paix'), shape: _road)),
      );
    });

    test('should differ when the shapes differ', () {
      expect(
        change,
        isNot(
          StreetShapeFilled(streetId: StreetId('nationale'), shape: _otherRoad),
        ),
      );
    });

    test('should show its street and its count of lines when printed', () {
      expect(change.toString(), 'StreetShapeFilled(nationale, 1 lines)');
    });
  });
}
