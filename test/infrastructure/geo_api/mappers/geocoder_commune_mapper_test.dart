import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/mappers/commune_search_mapper.dart';

import '../../../support/geo_fixtures.dart';
import '../../../support/street_fixtures.dart';
import '../../ban/ban_fixtures.dart';

void main() {
  // One feature as the Géoplateforme geocoder writes it, with [changes]
  // applied to its properties and [geometry] in place of its point.
  Map<String, Object?> feature({
    Map<String, Object?> changes = const {},
    Object? geometry = const {
      'type': 'Point',
      'coordinates': [4.724382, 45.985089],
    },
  }) => {
    'type': 'Feature',
    'geometry': geometry,
    'properties': {
      'type': 'municipality',
      'name': 'Villefranche-sur-Saône',
      'citycode': '69264',
      'postcode': '69400',
      ...changes,
    },
  };

  Map<String, Object?> answer(List<Object?> features) => {
    'type': 'FeatureCollection',
    'features': features,
  };

  test('should read the commune, its postcode and its centre from the '
      'fixture', () {
    final matches = communeMatchesFromGeocoderJson(
      geopfFixture('municipality_villefranche.json'),
    );

    expect(matches, [
      CommuneMatch(
        commune: villefranche,
        postcodes: const ['69400'],
        centre: at(45.985089, 4.724382),
      ),
    ]);
  });

  test('should read no commune from an empty answer', () {
    expect(
      communeMatchesFromGeocoderJson(geopfFixture('municipality_none.json')),
      isEmpty,
    );
  });

  test('should keep the order of the service', () {
    final matches = communeMatchesFromGeocoderJson(
      answer([
        feature(),
        feature(
          changes: {
            'name': 'Villefranche',
            'citycode': '69265',
            'postcode': '69401',
          },
        ),
      ]),
    );

    expect(matches.map((match) => match.commune.inseeCode.value), [
      '69264',
      '69265',
    ]);
    expect(matches.last.commune.name, 'Villefranche');
    expect(matches.last.postcodes, ['69401']);
  });

  final noPostcode = <String, Object?>{
    'no postcode': null,
    'a postcode of four digits': '6940',
    'a postcode of six digits': '694000',
    'a postcode that is a number': 69400,
  };
  for (final MapEntry(key: what, value: postcode) in noPostcode.entries) {
    test('should keep the commune without postcode when it has $what', () {
      final match = communeMatchesFromGeocoderJson(
        answer([
          feature(changes: {'postcode': postcode}),
        ]),
      ).single;

      expect(match.commune, villefranche);
      expect(match.postcodes, isEmpty);
    });
  }

  final noCentre = <String, Object?>{
    'no geometry': null,
    'a geometry that is not a point': {
      'type': 'Polygon',
      'coordinates': [4.724382, 45.985089],
    },
    'a latitude out of range': {
      'type': 'Point',
      'coordinates': [4.724382, 95.0],
    },
  };
  for (final MapEntry(key: what, value: geometry) in noCentre.entries) {
    test('should keep the commune without centre when it has $what', () {
      final match = communeMatchesFromGeocoderJson(
        answer([feature(geometry: geometry)]),
      ).single;

      expect(match.commune, villefranche);
      expect(match.centre, isNull);
    });
  }

  test('should skip a feature that is not a valid commune', () {
    final matches = communeMatchesFromGeocoderJson(
      answer([
        feature(changes: {'citycode': '6926'}),
        feature(changes: {'name': '  '}),
        feature(changes: {'name': null}),
        feature(changes: {'citycode': 69264}),
        {'type': 'Feature', 'geometry': null},
        'Villefranche',
        feature(),
      ]),
    );

    expect(matches, [
      CommuneMatch(
        commune: villefranche,
        postcodes: const ['69400'],
        centre: at(45.985089, 4.724382),
      ),
    ]);
  });

  test('should refuse a document that is not a feature collection', () {
    expect(
      () => communeMatchesFromGeocoderJson([feature()]),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => communeMatchesFromGeocoderJson({
        'code': 400,
        'message': 'Failed parsing query',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
