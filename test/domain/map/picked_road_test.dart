import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';

final _road = StreetShape([
  [at(45.98800, 4.72500), at(45.98900, 4.72500)],
]);

PickedRoad _picked({
  String street = '69264_1460',
  StreetShape? road,
  double latitude = 45.98850,
}) => PickedRoad(
  street: BanStreetId(street),
  road: road ?? _road,
  mark: at(latitude, 4.72500),
);

void main() {
  test('should keep its street, road and mark', () {
    final picked = _picked();

    expect(picked.street, BanStreetId('69264_1460'));
    expect(picked.road, _road);
    expect(picked.mark, at(45.98850, 4.72500));
  });

  test('should equal a picked road with the same values only', () {
    expect(_picked(), _picked());
    expect(_picked().hashCode, _picked().hashCode);
    expect(_picked(street: '69264_0682'), isNot(_picked()));
    expect(_picked(road: StreetShape.none), isNot(_picked()));
    expect(_picked(latitude: 45.99), isNot(_picked()));
  });

  test('should name its street when printed', () {
    expect(_picked().toString(), 'PickedRoad(69264_1460)');
  });
}
