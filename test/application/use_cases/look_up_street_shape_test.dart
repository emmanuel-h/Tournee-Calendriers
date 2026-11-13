// The road highlighted on « Ajouter des rues » (PLAN §5.4, §5.18): the
// line of a street the secteur does not have yet, by its BAN id, asked
// while it is ticked.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street_shape.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _morinId = BanStreetId('69264_1460');

/// The point the BAN gives for the street, south of its numbers.
final _morinPoint = at(45.98750, 4.72400);

final _morinMatch = StreetMatch(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  position: _morinPoint,
);

final _morin = StreetToAdd(
  _morinMatch,
  StreetNumbers(
    id: _morinId,
    name: streetName('Rue Pierre Morin'),
    commune: villefranche,
    numbers: [
      DirectoryNumber(number: n('1'), position: at(45.98800, 4.72500)),
      DirectoryNumber(number: n('2')),
      DirectoryNumber(number: n('3'), position: at(45.98900, 4.72550)),
    ],
    invalidNumbers: 0,
    duplicateNumbers: 0,
  ),
);

void main() {
  late FakeStreetShapes shapes;
  late LookUpStreetShape lookUp;

  setUp(() {
    shapes = FakeStreetShapes();
    lookUp = LookUpStreetShape(shapes);
  });

  test('should give the road the map draws, simplified', () async {
    // The middle point lies on the straight line: simplifying drops it.
    shapes.answer = Ok(
      StreetShape([
        [at(45.98800, 4.72500), at(45.98850, 4.72500), at(45.98900, 4.72500)],
      ]),
    );

    final shape = await lookUp(_morin.match, numbers: _morin.numbers);

    expect(
      valueOf(shape),
      StreetShape([
        [at(45.98800, 4.72500), at(45.98900, 4.72500)],
      ]),
    );
  });

  test('should look for the street by its BAN id', () async {
    await lookUp(_morin.match, numbers: _morin.numbers);

    expect(shapes.idsAsked, [_morinId]);
  });

  test('should look for the street\'s name around its numbers and its '
      'point, 150 m beyond', () async {
    await lookUp(_morin.match, numbers: _morin.numbers);

    expect(shapes.asked, [
      (
        'Rue Pierre Morin',
        GeoBounds.around([
          _morinPoint,
          at(45.98800, 4.72500),
          at(45.98900, 4.72550),
        ])!.expandedBy(150),
      ),
    ]);
  });

  test('should look around its point alone when its numbers are not read '
      'yet', () async {
    // A street ticked in a zone: its numbers come when it is added.
    await lookUp(_morinMatch);

    expect(shapes.asked, [
      ('Rue Pierre Morin', GeoBounds.around([_morinPoint])!.expandedBy(150)),
    ]);
    expect(shapes.idsAsked, [_morinId]);
  });

  test('should give no shape when the map does not know the road', () async {
    final shape = await lookUp(_morinMatch);

    expect(valueOf(shape), StreetShape.none);
  });

  test('should say why the map could not answer', () async {
    shapes.answer = const Err(StreetShapesFailure.noNetwork);

    final shape = await lookUp(_morinMatch);

    expect(failureOf(shape), StreetShapesFailure.noNetwork);
  });
}
