import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/road_side.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/geopf/mappers/bdtopo_roads_mapper.dart';

import '../../../support/geo_fixtures.dart';
import '../../../support/street_fixtures.dart';
import '../bdtopo_fixtures.dart';

/// One stretch of road as the WFS gives it, with [properties] over those
/// of a stretch of Rue Nationale on both sides.
Map<String, Object?> _stretch({
  Map<String, Object?> properties = const {},
  Object? geometry = const {
    'type': 'LineString',
    'coordinates': [
      [4.71899213, 45.99386171, 194],
      [4.71902948, 45.99447812, 194.3],
    ],
  },
}) => {
  'type': 'Feature',
  'geometry': geometry,
  'properties': {
    'nom_collaboratif_gauche': 'R NATIONALE',
    'nom_collaboratif_droite': 'R NATIONALE',
    'insee_commune_gauche': '69264',
    'insee_commune_droite': '69264',
    'nom_voie_ban_gauche': 'Rue Nationale',
    'nom_voie_ban_droite': 'Rue Nationale',
    'identifiant_voie_ban_gauche': '69264_1270',
    'identifiant_voie_ban_droite': '69264_1270',
    ...properties,
  },
};

/// A collection of [stretches], [matched] in the area.
Map<String, Object?> _collection(
  List<Object?> stretches, {
  Object? matched = 1,
}) => {
  'type': 'FeatureCollection',
  'features': stretches,
  'numberMatched': matched,
};

/// The line of [_stretch]'s default geometry.
final _line = StreetShape([
  [at(45.99386171, 4.71899213), at(45.99447812, 4.71902948)],
]);

void main() {
  group('the captured answers', () {
    test('should read every named stretch of a zone, in order', () {
      final read = banRoadsFromJson(bdTopoFixture('zone_centre.json'));

      expect(read.matched, 38);
      // 38 stretches, 3 with neither a name nor a BAN id.
      expect(read.roads, hasLength(35));
      expect(
        read.roads.first,
        BanRoad(
          banId: BanStreetId('69264_0240'),
          name: 'Rue Boiron',
          commune: insee('69264'),
          shape: StreetShape([
            [at(45.99152394, 4.71795253), at(45.99149449, 4.7187657)],
          ]),
        ),
      );
    });

    test('should keep a named stretch without BAN id, by its own name', () {
      final read = banRoadsFromJson(bdTopoFixture('zone_centre.json'));

      final paulBert = read.roads.where((road) => road.banId == null);
      expect(paulBert.map((road) => road.name), [
        'ESP PAUL BERT',
        'ESP PAUL BERT',
      ]);
      expect(paulBert.first.commune, insee('69264'));
      expect(paulBert.first.side, isNull);
      expect(paulBert.first.shape.lines.single, hasLength(8));
    });

    test('should read every stretch of a street asked by its id', () {
      final read = banRoadsFromJson(bdTopoFixture('by_id_rue_nationale.json'));

      expect(read.matched, 26);
      expect(read.roads, hasLength(26));
      expect(
        read.roads.every(
          (road) =>
              road.banId == BanStreetId('69264_1270') &&
              road.name == 'Rue Nationale' &&
              road.side == null,
        ),
        isTrue,
      );
    });

    test('should read an answer without any stretch', () {
      final read = banRoadsFromJson(bdTopoFixture('by_id_none.json'));

      expect(read.matched, 0);
      expect(read.roads, isEmpty);
    });

    test('should tell how many stretches the area holds beyond those '
        'given', () {
      final read = banRoadsFromJson(bdTopoFixture('zone_too_many.json'));

      expect(read.matched, 1531);
      expect(read.roads.map((road) => road.name), [
        'Rue Mirabeau',
        'Rue Lavoisier',
      ]);
    });
  });

  group('the two sides', () {
    test('should give one road on both sides when they are alike', () {
      final read = banRoadsFromJson(_collection([_stretch()]));

      expect(read.roads, [
        BanRoad(
          banId: BanStreetId('69264_1270'),
          name: 'Rue Nationale',
          commune: insee('69264'),
          shape: _line,
        ),
      ]);
    });

    test('should give a road per side when their streets differ', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            properties: {
              'identifiant_voie_ban_droite': '69264_0290',
              'nom_voie_ban_droite': 'Rue Caroline Blondeau',
              'insee_commune_droite': '69400',
            },
          ),
        ]),
      );

      expect(read.roads, [
        BanRoad(
          banId: BanStreetId('69264_1270'),
          name: 'Rue Nationale',
          commune: insee('69264'),
          shape: _line,
          side: RoadSide.left,
        ),
        BanRoad(
          banId: BanStreetId('69264_0290'),
          name: 'Rue Caroline Blondeau',
          commune: insee('69400'),
          shape: _line,
          side: RoadSide.right,
        ),
      ]);
    });

    test('should give a road per side when only their names differ', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(properties: {'nom_voie_ban_gauche': 'Rue  Nationale'}),
        ]),
      );

      expect(read.roads.map((road) => (road.name, road.side)), [
        ('Rue  Nationale', RoadSide.left),
        ('Rue Nationale', RoadSide.right),
      ]);
    });

    test('should give a road per side when only their communes differ', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(properties: {'insee_commune_gauche': '69400'}),
        ]),
      );

      expect(read.roads.map((road) => (road.commune, road.side)), [
        (insee('69400'), RoadSide.left),
        (insee('69264'), RoadSide.right),
      ]);
    });

    test('should keep only the side with a BAN street when the other has '
        'none', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            properties: {
              'identifiant_voie_ban_gauche': null,
              'nom_voie_ban_gauche': null,
            },
          ),
        ]),
      );

      expect(read.roads, [
        BanRoad(
          banId: BanStreetId('69264_1270'),
          name: 'Rue Nationale',
          commune: insee('69264'),
          shape: _line,
          side: RoadSide.right,
        ),
      ]);
    });

    test('should take a blank BAN id as none', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(properties: {'identifiant_voie_ban_droite': ' '}),
        ]),
      );

      expect(read.roads.single.side, RoadSide.left);
    });
  });

  group('the names', () {
    test('should name a stretch without BAN id after its left side', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            properties: {
              'identifiant_voie_ban_gauche': null,
              'identifiant_voie_ban_droite': null,
              'nom_collaboratif_gauche': 'ESP PAUL BERT',
              'nom_collaboratif_droite': 'ESPLANADE PAUL BERT',
              'insee_commune_gauche': '69400',
            },
          ),
        ]),
      );

      expect(read.roads, [
        BanRoad(
          banId: null,
          name: 'ESP PAUL BERT',
          commune: insee('69400'),
          shape: _line,
        ),
      ]);
    });

    test('should name a stretch without BAN id after its right side when '
        'the left has no name', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            properties: {
              'identifiant_voie_ban_gauche': null,
              'identifiant_voie_ban_droite': null,
              'nom_collaboratif_gauche': '',
              'nom_collaboratif_droite': 'ESP PAUL BERT',
              'insee_commune_gauche': null,
            },
          ),
        ]),
      );

      expect(read.roads.single.name, 'ESP PAUL BERT');
      expect(read.roads.single.commune, insee('69264'));
    });

    test('should leave out a stretch with neither a name nor a BAN id', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            properties: {
              'identifiant_voie_ban_gauche': null,
              'identifiant_voie_ban_droite': null,
              'nom_collaboratif_gauche': null,
              'nom_collaboratif_droite': ' ',
            },
          ),
        ]),
      );

      expect(read.roads, isEmpty);
      expect(read.matched, 1);
    });

    test('should name a BAN street after the collaborative name when the '
        'BAN name is missing', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            properties: {
              'nom_voie_ban_gauche': null,
              'nom_voie_ban_droite': null,
            },
          ),
        ]),
      );

      expect(read.roads.single.name, 'R NATIONALE');
      expect(read.roads.single.banId, BanStreetId('69264_1270'));
    });

    test('should leave a BAN street without any name unnamed', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            properties: {
              'nom_voie_ban_gauche': null,
              'nom_voie_ban_droite': null,
              'nom_collaboratif_gauche': null,
              'nom_collaboratif_droite': null,
            },
          ),
        ]),
      );

      expect(read.roads.single.name, '');
      expect(read.roads.single.banId, BanStreetId('69264_1270'));
    });

    test('should give no commune for an INSEE code it cannot read', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            properties: {
              'insee_commune_gauche': 'Villefranche',
              'insee_commune_droite': 'Villefranche',
            },
          ),
        ]),
      );

      expect(read.roads.single.commune, isNull);
    });
  });

  group('the lines', () {
    test('should read each line of a multi-line stretch', () {
      final read = banRoadsFromJson(
        _collection([
          _stretch(
            geometry: {
              'type': 'MultiLineString',
              'coordinates': [
                [
                  [4.7190, 45.9938],
                  [4.7191, 45.9939],
                ],
                [
                  [4.7192, 45.9940],
                  [4.7193, 45.9941],
                ],
              ],
            },
          ),
        ]),
      );

      expect(
        read.roads.single.shape,
        StreetShape([
          [at(45.9938, 4.7190), at(45.9939, 4.7191)],
          [at(45.9940, 4.7192), at(45.9941, 4.7193)],
        ]),
      );
    });

    for (final (what, geometry) in <(String, Object?)>[
      ('no geometry', null),
      (
        'a point',
        {
          'type': 'Point',
          'coordinates': [4.7190, 45.9938],
        },
      ),
      (
        'a single point',
        {
          'type': 'LineString',
          'coordinates': [
            [4.7190, 45.9938],
          ],
        },
      ),
      (
        'coordinates that are not a list',
        {'type': 'LineString', 'coordinates': 'none'},
      ),
      (
        'a point that is not a list',
        {
          'type': 'LineString',
          'coordinates': [
            [4.7190, 45.9938],
            'here',
          ],
        },
      ),
      (
        'a point without latitude',
        {
          'type': 'LineString',
          'coordinates': [
            [4.7190, 45.9938],
            [4.7191],
          ],
        },
      ),
      (
        'a coordinate that is not a number',
        {
          'type': 'LineString',
          'coordinates': [
            [4.7190, 45.9938],
            [4.7191, 'north'],
          ],
        },
      ),
      (
        'a latitude out of range',
        {
          'type': 'LineString',
          'coordinates': [
            [4.7190, 45.9938],
            [4.7191, 95],
          ],
        },
      ),
      (
        'lines of a multi-line that are not a list',
        {
          'type': 'MultiLineString',
          'coordinates': ['none'],
        },
      ),
    ]) {
      test('should leave out a stretch with $what', () {
        final read = banRoadsFromJson(
          _collection([_stretch(geometry: geometry), _stretch()]),
        );

        expect(read.roads, hasLength(1));
        expect(read.roads.single.shape, _line);
      });
    }

    test('should leave out a stretch that is not an object', () {
      final read = banRoadsFromJson(_collection(['stretch', _stretch()]));

      expect(read.roads, hasLength(1));
    });

    test('should leave out a stretch without properties', () {
      final read = banRoadsFromJson(
        _collection([
          {'type': 'Feature', 'geometry': _stretch()['geometry']},
          _stretch(),
        ]),
      );

      expect(read.roads, hasLength(1));
    });
  });

  group('the count', () {
    test('should count the stretches given when the service does not say '
        'how many the area holds', () {
      final read = banRoadsFromJson(
        _collection([_stretch(), _stretch()], matched: 'unknown'),
      );

      expect(read.matched, 2);
    });
  });

  group('an unreadable answer', () {
    for (final (what, json) in <(String, Object?)>[
      ('not an object', ['FeatureCollection']),
      ('an object without stretches', {'type': 'FeatureCollection'}),
      (
        'stretches that are not a list',
        {'type': 'FeatureCollection', 'features': 'none'},
      ),
    ]) {
      test('should throw a FormatException for $what', () {
        expect(() => banRoadsFromJson(json), throwsFormatException);
      });
    }
  });
}
