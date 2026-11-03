import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
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
    expect(sectorMarginMetres, 300);
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
      sectorArea(streets),
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
      sectorArea([deleted]),
      GeoBounds.around([at(45.98200, 4.71000), at(45.98500, 4.72000)])!
          .expandedBy(300),
    );
  });

  test('should be null when no street has a place on the map', () {
    final manual = _street('a', houses: [House(number: n('1'))]);

    expect(sectorArea([manual]), isNull);
  });

  test('should be null when there is no street', () {
    expect(sectorArea([]), isNull);
  });

  group('streetsBounds', () {
    test('should hold every shape point and house position, with no '
        'margin', () {
      final street = _street(
        'a',
        shape: StreetShape([
          [at(45.98200, 4.71000), at(45.98500, 4.72000)],
        ]),
        houses: [
          House(number: n('1'), position: at(45.99210, 4.70100)),
          House(number: n('3')),
        ],
      );

      expect(
        streetsBounds([street]),
        GeoBounds.around([at(45.98200, 4.70100), at(45.99210, 4.72000)]),
      );
    });

    test('should be null when no street has a place on the map', () {
      expect(streetsBounds([_street('a')]), isNull);
    });
  });

  group('communesArea', () {
    final villefrancheCentre = at(45.9837, 4.726);
    final gleizeCentre = at(45.9915, 4.6883);
    final gleize = valueOf(Commune.create(inseeCode: '69092', name: 'Gleizé'));

    test('should add a margin of 2 km', () {
      expect(communeMarginMetres, 2000);
    });

    test('should hold every commune centre, with the margin', () {
      expect(
        communesArea([
          SectorCommune(commune: villefranche, centre: villefrancheCentre),
          SectorCommune(commune: gleize, centre: gleizeCentre),
        ]),
        GeoBounds.around([at(45.9837, 4.6883), at(45.9915, 4.726)])!
            .expandedBy(2000),
      );
    });

    test('should leave out a commune without centre', () {
      expect(
        communesArea([
          SectorCommune(commune: villefranche, centre: villefrancheCentre),
          SectorCommune(commune: gleize),
        ]),
        GeoBounds.around([villefrancheCentre])!.expandedBy(2000),
      );
    });

    test('should be null when no commune has a centre', () {
      expect(communesArea([SectorCommune(commune: gleize)]), isNull);
      expect(communesArea(const []), isNull);
    });
  });

  group('addStreetsArea', () {
    final placed = _street(
      'a',
      houses: [House(number: n('1'), position: at(45.99210, 4.71500))],
    );

    test('should show the communes when one has a centre', () {
      final commune = SectorCommune(
        commune: villefranche,
        centre: at(45.9837, 4.726),
      );

      expect(addStreetsArea([commune], [placed]), communesArea([commune]));
    });

    test('should show the streets when no commune has a centre', () {
      expect(
        addStreetsArea([SectorCommune(commune: villefranche)], [placed]),
        sectorArea([placed]),
      );
    });

    test('should be null when neither has a place on the map', () {
      expect(addStreetsArea(const [], [_street('b')]), isNull);
    });
  });

  group('homeArea', () {
    final placed = _street(
      'a',
      houses: [House(number: n('1'), position: at(45.99210, 4.71500))],
    );
    final commune = SectorCommune(
      commune: villefranche,
      centre: at(45.9837, 4.726),
    );

    test('should show the streets when one has a place on the map', () {
      expect(homeArea([commune], [placed]), sectorArea([placed]));
    });

    test('should show the communes when no street has a place', () {
      expect(homeArea([commune], [_street('b')]), communesArea([commune]));
    });

    test('should be null when neither has a place on the map', () {
      expect(
        homeArea([SectorCommune(commune: villefranche)], [_street('b')]),
        isNull,
      );
    });
  });

  group('shapeSearchArea', () {
    test('should add a margin of 150 m', () {
      expect(shapeSearchMarginMetres, 150);
    });

    test('should hold every house position, with the margin', () {
      final positions = [at(45.98920, 4.71860), at(45.99200, 4.71710)];

      expect(
        shapeSearchArea(positions),
        GeoBounds.around(positions)!.expandedBy(150),
      );
    });

    test('should be null without any position', () {
      expect(shapeSearchArea([]), isNull);
    });
  });
}
