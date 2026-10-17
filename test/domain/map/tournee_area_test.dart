import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// A street of Villefranche-sur-Saône with [shape] and [houses].
Street _street(
  String id, {
  StreetShape shape = StreetShape.none,
  List<House> houses = const [],
}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: 'Rue $id',
    commune: villefranche,
    shape: shape,
    houses: houses,
  ),
);

void main() {
  test('should add a margin of 300 m', () {
    expect(tourneeMarginMetres, 300);
  });

  test('should hold every shape point and house position, with the '
      'margin', () {
    final streets = [
      _street(
        'a',
        shape: StreetShape([
          [at(45.98200, 4.71000), at(45.98500, 4.72000)],
        ]),
        houses: [House(number: n('1'), position: at(45.99210, 4.71500))],
      ),
      _street(
        'b',
        shape: StreetShape([
          [at(45.98600, 4.70100), at(45.98700, 4.70200)],
        ]),
        houses: [
          House(number: n('2'), position: at(45.98800, 4.73000)),
          House(number: n('4')),
        ],
      ),
    ];

    expect(
      tourneeArea(streets),
      GeoBounds.around([at(45.98200, 4.70100), at(45.99210, 4.73000)])!
          .expandedBy(300),
    );
  });

  // A street in the Corbeille may be restored offline: its area is kept.
  test('should hold the streets in the Corbeille', () {
    final (deleted, _) = _street(
      'a',
      shape: StreetShape([
        [at(45.98200, 4.71000), at(45.98500, 4.72000)],
      ]),
    ).delete(by: lea, at: twoPm);

    expect(
      tourneeArea([deleted]),
      GeoBounds.around([at(45.98200, 4.71000), at(45.98500, 4.72000)])!
          .expandedBy(300),
    );
  });

  test('should be null when no street has a place on the map', () {
    final manual = _street('a', houses: [House(number: n('1'))]);

    expect(tourneeArea([manual]), isNull);
  });

  test('should be null when there is no street', () {
    expect(tourneeArea([]), isNull);
  });
}
