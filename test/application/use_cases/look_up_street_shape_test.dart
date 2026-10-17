// The road highlighted on « Ajouter des rues » (PLAN §5.4): the shape of a
// street the tournée does not have yet, asked of OpenStreetMap while its
// card shows.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/application/use_cases/look_up_street_shape.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _morin = StreetMatch(
  id: BanStreetId('69264_1460'),
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  position: at(45.98850, 4.72500),
);

void main() {
  late FakeStreetShapes shapes;
  late LookUpStreetShape lookUp;

  setUp(() {
    shapes = FakeStreetShapes();
    lookUp = LookUpStreetShape(shapes);
  });

  test('should give the road OpenStreetMap draws, simplified', () async {
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
    expect(shapes.asked, [('Rue Pierre Morin', '69264')]);
  });

  test('should give no shape when OpenStreetMap does not know the '
      'road', () async {
    final shape = await lookUp(_morin);

    expect(valueOf(shape), StreetShape.none);
  });

  test('should say why Overpass could not answer', () async {
    shapes.answer = const Err(StreetShapesFailure.noNetwork);

    final shape = await lookUp(_morin);

    expect(failureOf(shape), StreetShapesFailure.noNetwork);
  });
}
