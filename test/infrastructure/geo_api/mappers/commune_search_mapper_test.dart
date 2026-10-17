import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/mappers/commune_search_mapper.dart';

import '../../../support/geo_fixtures.dart';
import '../../../support/street_fixtures.dart';
import '../geo_api_fixtures.dart';

void main() {
  // One entry as the service writes it, with [changes] applied.
  Map<String, Object?> entry([Map<String, Object?> changes = const {}]) => {
    'nom': 'Villefranche-sur-Saône',
    'code': '69264',
    'codesPostaux': ['69400'],
    ...changes,
  };

  test('should read the commune, its postcodes and its centre from the '
      'fixture', () {
    final matches = communeMatchesFromJson(
      geoApiFixture('communes_villefranche.json'),
    );

    expect(matches, [
      CommuneMatch(
        commune: villefranche,
        postcodes: const ['69400'],
        centre: at(45.9837, 4.726),
      ),
    ]);
  });

  test('should read a centre written as whole numbers', () {
    final matches = communeMatchesFromJson([
      entry({
        'centre': {
          'type': 'Point',
          'coordinates': [5, 46],
        },
      }),
    ]);

    expect(matches.single.centre, at(46, 5));
  });

  final noCentre = <String, Object?>{
    'no centre': null,
    'not a point': {
      'type': 'Polygon',
      'coordinates': [4.726, 45.9837],
    },
    'one coordinate': {
      'type': 'Point',
      'coordinates': [4.726],
    },
    'coordinates that are not numbers': {
      'type': 'Point',
      'coordinates': ['4.726', '45.9837'],
    },
    'a latitude out of range': {
      'type': 'Point',
      'coordinates': [4.726, 95.0],
    },
  };
  for (final MapEntry(key: what, value: centre) in noCentre.entries) {
    test('should keep the commune without centre when it has $what', () {
      final match = communeMatchesFromJson([
        entry({'centre': centre}),
      ]).single;

      expect(match.commune, villefranche);
      expect(match.centre, isNull);
    });
  }

  test('should read no commune from an empty answer', () {
    expect(
      communeMatchesFromJson(geoApiFixture('communes_none.json')),
      isEmpty,
    );
  });

  test('should keep the order and every postcode of the service', () {
    final matches = communeMatchesFromJson([
      entry({
        'codesPostaux': ['69400', '69401'],
      }),
      entry({'nom': 'Villefranche', 'code': '69265'}),
    ]);

    expect(matches.map((match) => match.commune.inseeCode.value), [
      '69264',
      '69265',
    ]);
    expect(matches.first.postcodes, ['69400', '69401']);
    expect(matches.last.commune.name, 'Villefranche');
  });

  test('should keep a commune without postcodes', () {
    final missing = entry()..remove('codesPostaux');

    expect(communeMatchesFromJson([missing]).single.postcodes, isEmpty);
    expect(
      communeMatchesFromJson([
        entry({'codesPostaux': null}),
      ]).single.postcodes,
      isEmpty,
    );
  });

  test('should leave out the postcodes that are not five digits', () {
    final matches = communeMatchesFromJson([
      entry({
        'codesPostaux': ['6940', '694000', '6940A', 69400, null, '69400'],
      }),
    ]);

    expect(matches.single.postcodes, ['69400']);
  });

  test('should skip an entry that is not a valid commune', () {
    final matches = communeMatchesFromJson([
      entry({'code': '6926'}),
      entry({'nom': '  '}),
      entry({'nom': null}),
      entry({'code': 69264}),
      'Villefranche',
      entry(),
    ]);

    expect(matches, [
      CommuneMatch(commune: villefranche, postcodes: const ['69400']),
    ]);
  });

  test('should refuse a document that is not a list', () {
    expect(
      () => communeMatchesFromJson(entry()),
      throwsA(isA<FormatException>()),
    );
    expect(() => communeMatchesFromJson(null), throwsA(isA<FormatException>()));
  });
}
