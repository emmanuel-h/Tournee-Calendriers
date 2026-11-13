import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/road_side.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';
import '../../support/street_fixtures.dart';

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

  group('BanRoad', () {
    final road = StreetShape([
      [at(45.98800, 4.72500), at(45.98900, 4.72500)],
    ]);
    BanRoad make({
      String? id = '69264_1270',
      String name = 'Rue Nationale',
      String? commune = '69264',
      StreetShape? shape,
      RoadSide? side = RoadSide.left,
    }) => BanRoad(
      banId: id == null ? null : BanStreetId(id),
      name: name,
      commune: commune == null ? null : insee(commune),
      shape: shape ?? road,
      side: side,
    );

    test('should be equal by every field', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('should tell roads apart by each field', () {
      expect(make(id: '69264_0290'), isNot(make()));
      expect(make(id: null), isNot(make()));
      expect(make(name: 'Rue Pasteur'), isNot(make()));
      expect(make(commune: '69400'), isNot(make()));
      expect(make(commune: null), isNot(make()));
      expect(make(shape: StreetShape.none), isNot(make()));
      expect(make(side: RoadSide.right), isNot(make()));
      expect(make(side: null), isNot(make()));
    });

    test('should be on both sides when no side is given', () {
      final both = BanRoad(
        banId: BanStreetId('69264_1270'),
        name: 'Rue Nationale',
        commune: insee('69264'),
        shape: road,
      );

      expect(both.side, isNull);
    });

    test('should name its street and side when printed', () {
      expect(make().toString(), 'BanRoad(69264_1270, Rue Nationale, left)');
      expect(
        make(id: null, side: null).toString(),
        'BanRoad(null, Rue Nationale, null)',
      );
    });
  });
}
