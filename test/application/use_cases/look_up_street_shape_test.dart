// The road highlighted on « Ajouter des rues » (PLAN §5.4): the shape of a
// street the tournée does not have yet, asked of the map while its card
// shows.
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

final _morin = StreetToAdd(
  StreetMatch(
    id: _morinId,
    name: streetName('Rue Pierre Morin'),
    commune: villefranche,
    position: _morinPoint,
  ),
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

    final shape = await lookUp(_morin);

    expect(
      valueOf(shape),
      StreetShape([
        [at(45.98800, 4.72500), at(45.98900, 4.72500)],
      ]),
    );
  });

  test('should look for the street\'s name around its numbers and its '
      'point, 150 m beyond', () async {
    await lookUp(_morin);

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

  test('should give no shape when the map does not know the road', () async {
    final shape = await lookUp(_morin);

    expect(valueOf(shape), StreetShape.none);
  });

  test('should say why the map could not answer', () async {
    shapes.answer = const Err(StreetShapesFailure.noNetwork);

    final shape = await lookUp(_morin);

    expect(failureOf(shape), StreetShapesFailure.noNetwork);
  });
}
