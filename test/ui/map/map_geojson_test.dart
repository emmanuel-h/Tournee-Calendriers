import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
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
          level: ProgressLevel.toDo,
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
            'properties': {'level': 'toDo'},
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

  group('selectedPointGeoJson', () {
    test('should write the point tapped as one Point', () {
      expect(selectedPointGeoJson(at(45.98915, 4.71862)), {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'selected-point',
            'properties': <String, Object>{},
            'geometry': {
              'type': 'Point',
              'coordinates': [4.71862, 45.98915],
            },
          },
        ],
      });
    });

    test('should write an empty collection without a point', () {
      expect(selectedPointGeoJson(null), {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
    });
  });

  group('picked roads', () {
    final morin = PickedRoad(
      street: BanStreetId('69264_1460'),
      road: _twoPieces,
      mark: at(45.98915, 4.71862),
    );
    final pasteur = PickedRoad(
      street: BanStreetId('69264_1200'),
      road: StreetShape.none,
      mark: at(45.98700, 4.72000),
    );

    test('should write the known roads as MultiLineStrings named by their '
        'BAN id', () {
      expect(pickedRoadsGeoJson([morin, pasteur]), {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': '69264_1460',
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

    test('should write a ✓ for every street ticked, road known or not', () {
      expect(pickedMarksGeoJson([morin, pasteur]), {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': '69264_1460',
            'properties': <String, Object>{},
            'geometry': {
              'type': 'Point',
              'coordinates': [4.71862, 45.98915],
            },
          },
          {
            'type': 'Feature',
            'id': '69264_1200',
            'properties': <String, Object>{},
            'geometry': {
              'type': 'Point',
              'coordinates': [4.72000, 45.98700],
            },
          },
        ],
      });
    });

    test('should write empty collections with nothing ticked', () {
      const empty = {'type': 'FeatureCollection', 'features': <Object>[]};

      expect(pickedRoadsGeoJson(const []), empty);
      expect(pickedMarksGeoJson(const []), empty);
    });
  });

  group('zoneGeoJson', () {
    test('should dim the world around the zone, edge it and put the handle '
        'at its south-east corner', () {
      final zone = GeoBounds.of(
        south: 45.98,
        west: 4.71,
        north: 45.99,
        east: 4.73,
      )!;
      const ring = [
        [4.71, 45.98],
        [4.73, 45.98],
        [4.73, 45.99],
        [4.71, 45.99],
        [4.71, 45.98],
      ];

      expect(zoneGeoJson(zone), {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'zone-shade',
            'properties': {'part': 'shade'},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [-180.0, -85.0],
                  [180.0, -85.0],
                  [180.0, 85.0],
                  [-180.0, 85.0],
                  [-180.0, -85.0],
                ],
                ring,
              ],
            },
          },
          {
            'type': 'Feature',
            'id': 'zone-edge',
            'properties': {'part': 'edge'},
            'geometry': {'type': 'LineString', 'coordinates': ring},
          },
          {
            'type': 'Feature',
            'id': 'zone-handle',
            'properties': {'part': 'handle'},
            'geometry': {
              'type': 'Point',
              'coordinates': [4.73, 45.98],
            },
          },
        ],
      });
    });

    test('should write an empty collection with no zone', () {
      expect(zoneGeoJson(null), {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
    });

    test('should name the parts of a zone', () {
      expect(zonePartProperty, 'part');
      expect(ZonePart.values.map((part) => part.name), [
        'shade',
        'edge',
        'handle',
      ]);
    });
  });

  group('partRoadGeoJson', () {
    test('should write the road as one MultiLineString', () {
      expect(partRoadGeoJson(_twoPieces), {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'part-road',
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

    test('should write an empty collection without a road', () {
      expect(partRoadGeoJson(StreetShape.none), {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
    });
  });

  group('partDotsGeoJson', () {
    test('should write one Point per dot named by its number, with its look '
        'and number', () {
      expect(
        partDotsGeoJson([
          PartDot(
            number: n('3bis'),
            position: at(45.98915, 4.71862),
            look: PartDotLook.leftOut,
          ),
          PartDot(
            number: n('4'),
            position: at(45.99210, 4.71705),
            look: PartDotLook.otherSide,
          ),
        ]),
        {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'id': '3bis',
              'properties': {'look': 'leftOut', 'number': '3bis'},
              'geometry': {
                'type': 'Point',
                'coordinates': [4.71862, 45.98915],
              },
            },
            {
              'type': 'Feature',
              'id': '4',
              'properties': {'look': 'otherSide', 'number': '4'},
              'geometry': {
                'type': 'Point',
                'coordinates': [4.71705, 45.99210],
              },
            },
          ],
        },
      );
    });
  });
}
