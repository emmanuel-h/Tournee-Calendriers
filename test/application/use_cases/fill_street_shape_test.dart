// A street of the tournée without a line on the map gets the road the map
// draws for it, once (PLAN §5.3, #92).
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/fill_street_shape.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _morinId = StreetId('morin');

/// A road as the map draws it: the middle point lies on the straight line
/// from the first to the last, so simplifying drops it.
final _start = at(45.98800, 4.72500);
final _middle = at(45.98850, 4.72500);
final _end = at(45.98900, 4.72500);
final _mapRoad = StreetShape([
  [_start, _middle, _end],
]);
final _simplified = StreetShape([
  [_start, _end],
]);

/// Rue Pierre Morin, imported from a list: two houses on the map, one
/// typed in by hand, no line.
Street _morin({StreetShape shape = StreetShape.none, bool placed = true}) =>
    valueOf(
      Street.create(
        id: _morinId,
        name: 'Rue Pierre Morin',
        commune: villefranche,
        shape: shape,
        houses: [
          House(number: n('1'), position: placed ? _start : null),
          House(number: n('2')),
          House(
            number: n('3'),
            position: placed ? at(45.98900, 4.72550) : null,
          ),
        ],
      ),
    );

void main() {
  late FakeStreetRepository streets;
  late FakeStreetShapes shapes;
  late FillStreetShape fill;

  setUp(() {
    streets = FakeStreetRepository([_morin()]);
    shapes = FakeStreetShapes(Ok(_mapRoad));
    fill = FillStreetShape(shapes, streets);
  });

  group('asking the map', () {
    test('should store the road the map draws, simplified', () async {
      final outcome = await fill(_morinId);

      expect(valueOf(outcome), ShapeFillOutcome.filled);
      expect(streets[_morinId]!.shape, _simplified);
      expect(
        streets.saved.single.$2,
        StreetShapeFilled(streetId: _morinId, shape: _simplified),
      );
    });

    test('should look for the street\'s name around its houses, 150 m '
        'beyond', () async {
      await fill(_morinId);

      expect(shapes.asked, [
        (
          'Rue Pierre Morin',
          GeoBounds.around([_start, at(45.98900, 4.72550)])!.expandedBy(150),
        ),
      ]);
    });

    test('should store nothing when the map has no such road', () async {
      shapes.answer = const Ok(StreetShape.none);

      final outcome = await fill(_morinId);

      expect(valueOf(outcome), ShapeFillOutcome.noRoad);
      expect(streets.saved, isEmpty);
    });

    test('should say why the map could not answer, and store '
        'nothing', () async {
      shapes.answer = const Err(StreetShapesFailure.noNetwork);

      final outcome = await fill(_morinId);

      expect(failureOf(outcome), StreetShapesFailure.noNetwork);
      expect(streets.saved, isEmpty);
    });

    test('should ask nothing for a street that has a shape', () async {
      streets = FakeStreetRepository([_morin(shape: _simplified)]);
      fill = FillStreetShape(shapes, streets);

      final outcome = await fill(_morinId);

      expect(valueOf(outcome), ShapeFillOutcome.notNeeded);
      expect(shapes.asked, isEmpty);
      expect(streets.saved, isEmpty);
    });

    test('should ask nothing for a street without any house on the '
        'map', () async {
      streets = FakeStreetRepository([_morin(placed: false)]);
      fill = FillStreetShape(shapes, streets);

      final outcome = await fill(_morinId);

      expect(valueOf(outcome), ShapeFillOutcome.notNeeded);
      expect(shapes.asked, isEmpty);
    });

    test('should ask nothing for a street in the Corbeille', () async {
      final (deleted, _) = _morin().delete(by: lea, at: twoPm);
      streets = FakeStreetRepository([deleted]);
      fill = FillStreetShape(shapes, streets);

      final outcome = await fill(_morinId);

      expect(valueOf(outcome), ShapeFillOutcome.notNeeded);
      expect(shapes.asked, isEmpty);
    });

    test('should ask nothing for a street that is not there', () async {
      final outcome = await fill(StreetId('gone'));

      expect(valueOf(outcome), ShapeFillOutcome.notNeeded);
      expect(shapes.asked, isEmpty);
    });

    test('should keep the shape a teammate stored while the map was '
        'asked', () async {
      final theirs = StreetShape([
        [_start, at(45.98900, 4.72600)],
      ]);
      shapes.whileAsked = () async {
        final (filled, change) = valueOf(_morin().fillShape(theirs));
        await streets.save(filled, change);
      };

      final outcome = await fill(_morinId);

      expect(valueOf(outcome), ShapeFillOutcome.notNeeded);
      expect(streets[_morinId]!.shape, theirs);
      expect(streets.saved, hasLength(1));
    });

    test('should store nothing when the street was purged while the map '
        'was asked', () async {
      shapes.whileAsked = () => streets.purge(_morinId);

      final outcome = await fill(_morinId);

      expect(valueOf(outcome), ShapeFillOutcome.notNeeded);
      expect(streets.saved, isEmpty);
    });
  });

  group('with the road known', () {
    test('should store it without asking the map', () async {
      final outcome = await fill(_morinId, road: _simplified);

      expect(valueOf(outcome), ShapeFillOutcome.filled);
      expect(streets[_morinId]!.shape, _simplified);
      expect(shapes.asked, isEmpty);
    });

    test('should store it on a street without any house on the map', () async {
      streets = FakeStreetRepository([_morin(placed: false)]);
      fill = FillStreetShape(shapes, streets);

      final outcome = await fill(_morinId, road: _simplified);

      expect(valueOf(outcome), ShapeFillOutcome.filled);
      expect(streets[_morinId]!.shape, _simplified);
    });

    test('should keep the shape the street has', () async {
      final theirs = StreetShape([
        [_start, at(45.98900, 4.72600)],
      ]);
      streets = FakeStreetRepository([_morin(shape: theirs)]);
      fill = FillStreetShape(shapes, streets);

      final outcome = await fill(_morinId, road: _simplified);

      expect(valueOf(outcome), ShapeFillOutcome.notNeeded);
      expect(streets[_morinId]!.shape, theirs);
      expect(streets.saved, isEmpty);
    });

    test('should store nothing for a road without any line', () async {
      final outcome = await fill(_morinId, road: StreetShape.none);

      expect(valueOf(outcome), ShapeFillOutcome.noRoad);
      expect(streets.saved, isEmpty);
    });

    test('should store nothing for a street that is not there', () async {
      final outcome = await fill(StreetId('gone'), road: _simplified);

      expect(valueOf(outcome), ShapeFillOutcome.notNeeded);
      expect(streets.saved, isEmpty);
    });
  });
}
