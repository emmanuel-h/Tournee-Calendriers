import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/infrastructure/ban/mappers/geopf_geocoding_mapper.dart';

import '../../../support/geo_fixtures.dart';
import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';
import '../ban_fixtures.dart';

void main() {
  StreetName name(String text) => valueOf(StreetName.create(text));

  // A geocoding answer holding [features].
  Map<String, Object?> collection(List<Object?> features) => {
    'type': 'FeatureCollection',
    'features': features,
  };

  // A street feature as the service writes it, valid unless a field is
  // overridden.
  Map<String, Object?> feature({
    Object? id = '69264_1460',
    Object? name = 'Rue Pierre Morin',
    Object? citycode = '69264',
    Object? city = 'Villefranche-sur-Saône',
    Object? coordinates = const [4.7158, 45.987094],
  }) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': coordinates},
    'properties': {
      'type': 'street',
      'id': id,
      'name': name,
      'citycode': citycode,
      'city': city,
    },
  };

  final pierreMorin = StreetMatch(
    id: BanStreetId('69264_1460'),
    name: name('Rue Pierre Morin'),
    commune: villefranche,
    position: at(45.987094, 4.7158),
  );

  test('should read the street under a tap from the reverse geocoder', () {
    expect(
      streetMatchesFromJson(geopfFixture('reverse_rue_pierre_morin.json')),
      [pierreMorin],
    );
  });

  test('should read the streets found by a search, best first', () {
    final matches = streetMatchesFromJson(
      geopfFixture('search_rue_pierre.json'),
    );

    expect(matches, hasLength(9));
    expect(
      matches.first,
      StreetMatch(
        id: BanStreetId('69264_1420'),
        name: name('Rue Pierre Berthier'),
        commune: villefranche,
        position: at(45.986224, 4.726123),
      ),
    );
    expect(matches[2], pierreMorin);
    expect(matches.last.name, name('Rue Anne et Pierre de Beaujeu'));
  });

  test('should give no street when the service finds none', () {
    expect(
      streetMatchesFromJson(geopfFixture('reverse_nothing.json')),
      isEmpty,
    );
    expect(streetMatchesFromJson(geopfFixture('search_none.json')), isEmpty);
  });

  test('should clean the name the way a street name is cleaned', () {
    final matches = streetMatchesFromJson(
      collection([feature(name: '  Rue   Pierre Morin ')]),
    );

    expect(matches.single.name.text, 'Rue Pierre Morin');
  });

  test('should ignore an altitude after the coordinates', () {
    final matches = streetMatchesFromJson(
      collection([
        feature(coordinates: [4.7158, 45.987094, 170]),
      ]),
    );

    expect(matches.single.position, at(45.987094, 4.7158));
  });

  group('should leave out a feature it cannot read', () {
    final unreadable = <String, Object?>{
      'not a map': 'Rue Pierre Morin',
      'without an id': feature(id: null),
      'with a blank id': feature(id: '  '),
      'with an id that is not text': feature(id: 1460),
      'without a name': feature(name: null),
      'with a blank name': feature(name: ' '),
      'with a name too long': feature(name: 'R' * 151),
      'without a commune code': feature(citycode: null),
      'with an invalid commune code': feature(citycode: '6926'),
      'without a commune name': feature(city: null),
      'with a blank commune name': feature(city: ' '),
      'without coordinates': feature(coordinates: null),
      'with one coordinate': feature(coordinates: [4.7158]),
      'with text coordinates': feature(coordinates: ['4.7158', '45.987094']),
      'with a latitude out of range': feature(coordinates: [4.7158, 95.0]),
      'with a longitude out of range': feature(coordinates: [184.0, 45.98]),
    };

    unreadable.forEach((description, entry) {
      test(description, () {
        expect(streetMatchesFromJson(collection([entry, feature()])), [
          pierreMorin,
        ]);
      });
    });
  });

  test('should keep a name of exactly the longest length a street has', () {
    final matches = streetMatchesFromJson(
      collection([feature(name: 'R' * 150)]),
    );

    expect(matches.single.name.text, 'R' * 150);
  });

  test('should read whole-number coordinates', () {
    final matches = streetMatchesFromJson(
      collection([
        feature(coordinates: [5, 46]),
      ]),
    );

    expect(matches.single.position, at(46, 5));
  });

  group('should throw a FormatException when the document', () {
    final notCollections = <String, Object?>{
      'is not a map': ['features'],
      'has no features': {'type': 'FeatureCollection'},
      'has features that are not a list': {'features': 'none'},
      'is the error of a refused query': geopfFixture('search_too_short.json'),
    };

    notCollections.forEach((description, json) {
      test(description, () {
        expect(() => streetMatchesFromJson(json), throwsFormatException);
      });
    });
  });
}
