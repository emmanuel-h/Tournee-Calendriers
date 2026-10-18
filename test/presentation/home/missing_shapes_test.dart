// The streets of the open tournée without a line on the map get their road
// in the background, gently (PLAN §5.3, #92): once a session each, one at
// a time, and a pause after a failure.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/fill_street_shape.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/home/missing_shapes.dart';

import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _road = StreetShape([
  [at(45.98800, 4.72500), at(45.98900, 4.72500)],
]);

/// A street named [name] with one house on the map, or none when
/// [placed] is false, and [shape].
Street _street(
  String name, {
  bool placed = true,
  StreetShape shape = StreetShape.none,
}) => valueOf(
  Street.create(
    id: StreetId(name),
    name: name,
    commune: villefranche,
    shape: shape,
    houses: [
      House(number: n('1'), position: placed ? at(45.98850, 4.72500) : null),
    ],
  ),
);

final _morin = _street('Rue Pierre Morin');
final _paix = _street('Rue de la Paix');
final _shaped = _street('Rue Nationale', shape: _road);
final _byHand = _street('Allée Émile Zola', placed: false);

void main() {
  late FakeStreetRepository streets;
  late FakeStreetShapes shapes;
  late FakeClock clock;
  late MissingShapes missing;

  setUp(() {
    streets = FakeStreetRepository([_morin, _paix, _shaped, _byHand]);
    shapes = FakeStreetShapes(Ok(_road));
    clock = FakeClock(twoPm);
    missing = MissingShapes(FillStreetShape(shapes, streets), clock);
  });

  test('should wait two minutes after a failure', () {
    expect(MissingShapes.retryDelay, const Duration(minutes: 2));
  });

  test('should fill, in turn, the streets that need a shape', () async {
    await missing.fillAmong([_morin, _shaped, _byHand, _paix]);

    expect(shapes.askedNames, ['Rue Pierre Morin', 'Rue de la Paix']);
    expect(streets[_morin.id]!.shape, _road);
    expect(streets[_paix.id]!.shape, _road);
  });

  test('should ask each street once a session, whatever the map '
      'answered', () async {
    shapes.answer = const Ok(StreetShape.none);
    await missing.fillAmong([_morin, _paix]);

    await missing.fillAmong([_morin, _paix]);

    expect(shapes.askedNames, ['Rue Pierre Morin', 'Rue de la Paix']);
  });

  group('after a failure', () {
    setUp(() async {
      shapes.answer = const Err(StreetShapesFailure.noNetwork);
      await missing.fillAmong([_morin, _paix]);
      shapes.answer = Ok(_road);
    });

    test('should stop at the street that failed', () {
      expect(shapes.askedNames, ['Rue Pierre Morin']);
      expect(streets.saved, isEmpty);
    });

    test('should ask nothing until the pause is over', () async {
      clock.time = twoPm.add(
        MissingShapes.retryDelay - const Duration(microseconds: 1),
      );

      await missing.fillAmong([_morin, _paix]);

      expect(shapes.askedNames, ['Rue Pierre Morin']);
    });

    test('should ask the street that failed again once the pause is '
        'over', () async {
      clock.time = twoPm.add(MissingShapes.retryDelay);

      await missing.fillAmong([_morin, _paix]);

      expect(shapes.askedNames, [
        'Rue Pierre Morin',
        'Rue Pierre Morin',
        'Rue de la Paix',
      ]);
      expect(streets[_morin.id]!.shape, _road);
    });
  });

  test('should take the streets handed during a run once it is '
      'over', () async {
    final third = _street('Rue Victor Hugo');
    await streets.add(third);
    Future<void>? handedMeanwhile;
    shapes.whileAsked = () async {
      shapes.whileAsked = null;
      handedMeanwhile = missing.fillAmong([_morin, third]);
    };

    final run = missing.fillAmong([_morin]);
    await handedMeanwhile;

    // The call made during the run is back at once, before the run.
    expect(shapes.askedNames, ['Rue Pierre Morin']);
    await run;
    expect(shapes.askedNames, ['Rue Pierre Morin', 'Rue Victor Hugo']);
  });

  test('should drop the streets handed during a run that failed', () async {
    shapes
      ..answer = const Err(StreetShapesFailure.serviceError)
      ..whileAsked = () async {
        shapes.whileAsked = null;
        await missing.fillAmong([_paix]);
      };

    await missing.fillAmong([_morin]);

    expect(shapes.askedNames, ['Rue Pierre Morin']);
  });

  test('should run again after a run broken by storage', () async {
    streets.failNextSave = Exception('disk full');
    await expectLater(missing.fillAmong([_morin]), throwsException);

    await missing.fillAmong([_paix]);

    expect(shapes.askedNames, ['Rue Pierre Morin', 'Rue de la Paix']);
    expect(streets[_paix.id]!.shape, _road);
  });
}
