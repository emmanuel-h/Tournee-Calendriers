import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';

void main() {
  group('NamedRoad', () {
    final road = StreetShape([
      [at(45.98800, 4.72500), at(45.98900, 4.72500)],
    ]);
    NamedRoad make({String name = 'Rue Pierre Morin', StreetShape? shape}) =>
        NamedRoad(name: name, shape: shape ?? road);

    test('should be equal by name and shape', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('should tell roads apart by each field', () {
      expect(make(name: 'Rue Pasteur'), isNot(make()));
      expect(make(shape: StreetShape.none), isNot(make()));
    });

    test('should name the road when printed', () {
      expect(make().toString(), 'NamedRoad(Rue Pierre Morin)');
    });
  });
}
