import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/ui/map/map_geojson.dart';

import '../../support/geo_fixtures.dart';
import '../../support/street_fixtures.dart';

final _nationale = StreetId('rue-nationale');
final _paix = StreetId('rue-de-la-paix');

/// Rue Nationale in two pieces of road, Villefranche-sur-Saône.
final _twoPieces = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
  [at(45.99210, 4.71705), at(45.99300, 4.71650), at(45.99400, 4.71600)],
]);

void main() {
  group('streetLinesGeoJson', () {
    test('should write one MultiLineString per street, longitude first, with its id and level', () {
      final geoJson = streetLinesGeoJson([
        StreetLine(
          street: _nationale,
          shape: _twoPieces,
          level: ProgressLevel.partial,
        ),
        StreetLine(
          street: _paix,
          shape: StreetShape([
            [at(45.98500, 4.72000), at(45.98600, 4.72100)],
          ]),
          level: ProgressLevel.free,
        ),
      ]);

      expect(geoJson, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'rue-nationale',
            'properties': {'level': 'partial'},
            'geometry': {
              'type': 'MultiLineString',
              'coordinates': [
                [
                  [4.71862, 45.98915],
                  [4.71705, 45.99210],
                ],
                [
                  [4.71705, 45.99210],
                  [4.71650, 45.99300],
                  [4.71600, 45.99400],
                ],
              ],
            },
          },
          {
            'type': 'Feature',
            'id': 'rue-de-la-paix',
            'properties': {'level': 'free'},
            'geometry': {
              'type': 'MultiLineString',
              'coordinates': [
                [
                  [4.72000, 45.98500],
                  [4.72100, 45.98600],
                ],
              ],
            },
          },
        ],
      });
    });

    test('should write an empty collection when there is no line', () {
      expect(streetLinesGeoJson([]), {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
    });
  });

  group('houseDotsGeoJson', () {
    test(
      'should write one Point per house, with its street id, status and number',
      () {
        final geoJson = houseDotsGeoJson([
          HouseDot(
            street: _nationale,
            number: n('3bis'),
            position: at(45.98920, 4.71860),
            status: HouseDotStatus.comeBack,
          ),
          HouseDot(
            street: _paix,
            number: n('12'),
            position: at(45.98550, 4.72050),
            status: HouseDotStatus.partial,
          ),
        ]);

        expect(geoJson, {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'id': 'rue-nationale',
              'properties': {'status': 'comeBack', 'number': '3bis'},
              'geometry': {
                'type': 'Point',
                'coordinates': [4.71860, 45.98920],
              },
            },
            {
              'type': 'Feature',
              'id': 'rue-de-la-paix',
              'properties': {'status': 'partial', 'number': '12'},
              'geometry': {
                'type': 'Point',
                'coordinates': [4.72050, 45.98550],
              },
            },
          ],
        });
      },
    );
  });

  group('selectedRoadGeoJson', () {
    test('should write the picked road as one MultiLineString', () {
      expect(selectedRoadGeoJson(_twoPieces), {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'selected',
            'properties': <String, Object>{},
            'geometry': {
              'type': 'MultiLineString',
              'coordinates': [
                [
                  [4.71862, 45.98915],
                  [4.71705, 45.99210],
                ],
                [
                  [4.71705, 45.99210],
                  [4.71650, 45.99300],
                  [4.71600, 45.99400],
                ],
              ],
            },
          },
        ],
      });
    });

    test('should write an empty collection when no road is picked', () {
      expect(selectedRoadGeoJson(StreetShape.none), {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
    });
  });
}
