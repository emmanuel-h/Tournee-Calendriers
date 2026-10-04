import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/infrastructure/ban/mappers/ban_lookup_mapper.dart';

import '../../../support/results.dart';
import '../ban_fixtures.dart';

void main() {
  final villefranche = valueOf(
    Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
  );
  StreetName name(String text) => valueOf(StreetName.create(text));
  GeoPoint point(double latitude, double longitude) =>
      valueOf(GeoPoint.create(latitude: latitude, longitude: longitude));
  HouseNumber number(int number, [String? suffix]) =>
      valueOf(HouseNumber.create(number, suffix: suffix));

  group('communeStreetsFromJson', () {
    // A commune document with [voies] as its list of streets.
    Map<String, Object?> commune(List<Object?> voies) => {
      'id': '69264',
      'type': 'commune',
      'codeCommune': '69264',
      'nomCommune': 'Villefranche-sur-Saône',
      'voies': voies,
    };

    // A street entry of the list, valid unless a field is overridden.
    Map<String, Object?> voie({
      Object? id = '69264_1460',
      Object? name = 'Rue Pierre Morin',
      Object? count = 19,
      String type = 'voie',
    }) => {
      'id': id,
      'idVoie': id,
      'nomVoie': name,
      'nbNumeros': count,
      'type': type,
    };

    test('should read the commune and its streets from the BAN', () {
      final result = communeStreetsFromJson(banFixture('lookup_69264.json'));

      expect(result.commune, villefranche);
      expect(result.streets, [
        DirectoryStreet(
          id: BanStreetId('69264_1460'),
          name: name('Rue Pierre Morin'),
          numberCount: 19,
        ),
        DirectoryStreet(
          id: BanStreetId('69264_7bh70d'),
          name: name('Allée Eugene Berne'),
          numberCount: 7,
        ),
        DirectoryStreet(
          id: BanStreetId('69264_0246'),
          name: name('Petit Chemin de Bordelan'),
          numberCount: 14,
        ),
        DirectoryStreet(
          id: BanStreetId('69264_1781'),
          name: name('Allée du Square'),
          numberCount: 1,
        ),
        DirectoryStreet(
          id: BanStreetId('69264_0682'),
          name: name('Rue des Freres Bonnet'),
          numberCount: 22,
        ),
        DirectoryStreet(
          id: BanStreetId('69264_1270'),
          name: name('Rue Nationale'),
          numberCount: 403,
        ),
      ]);
      expect(result.skippedStreets, 0);
    });

    test('should keep a lieu-dit like a street when the BAN lists one', () {
      final result = communeStreetsFromJson(
        commune([
          voie(id: '69264_b123', name: 'Les Grillons', type: 'lieu-dit'),
        ]),
      );

      expect(result.streets, [
        DirectoryStreet(
          id: BanStreetId('69264_b123'),
          name: name('Les Grillons'),
          numberCount: 19,
        ),
      ]);
    });

    test('should clean the street name when the BAN pads it', () {
      final result = communeStreetsFromJson(
        commune([voie(name: '  Rue  Pierre Morin ')]),
      );

      expect(result.streets.single.name, name('Rue Pierre Morin'));
    });

    test('should keep a street with no number when the count is 0', () {
      final result = communeStreetsFromJson(commune([voie(count: 0)]));

      expect(result.streets.single.numberCount, 0);
      expect(result.skippedStreets, 0);
    });

    test('should return no street when the commune lists none', () {
      final result = communeStreetsFromJson(commune([]));

      expect(result.commune, villefranche);
      expect(result.streets, isEmpty);
      expect(result.skippedStreets, 0);
    });

    final unreadableEntries = <String, Object?>{
      'not an object': '69264_1460',
      'null': null,
      'no id': {'nomVoie': 'Rue Pierre Morin', 'nbNumeros': 19},
      'a blank id': voie(id: '  '),
      'an id that is not text': voie(id: 691460),
      'no name': {'idVoie': '69264_1460', 'nbNumeros': 19},
      'a blank name': voie(name: ' '),
      'a name too long': voie(name: 'R' * (StreetName.maxLength + 1)),
      'a name that is not text': voie(name: 12),
      'no count': {'idVoie': '69264_1460', 'nomVoie': 'Rue Pierre Morin'},
      'a negative count': voie(count: -1),
      'a fractional count': voie(count: 19.5),
      'a count that is text': voie(count: '19'),
    };
    unreadableEntries.forEach((what, entry) {
      test('should skip and count an entry with $what', () {
        final result = communeStreetsFromJson(
          commune([
            voie(),
            entry,
            voie(id: '69264_1270', name: 'Rue Nationale'),
          ]),
        );

        expect(result.streets.map((street) => street.id.value), [
          '69264_1460',
          '69264_1270',
        ]);
        expect(result.skippedStreets, 1);
      });
    });

    test('should keep a name of exactly the longest length', () {
      final longest = 'R' * StreetName.maxLength;

      final result = communeStreetsFromJson(commune([voie(name: longest)]));

      expect(result.streets.single.name, name(longest));
    });

    final unreadableDocuments = <String, Object?>{
      'not an object': ['69264'],
      'null': null,
      'a document with no code': {
        'nomCommune': 'Villefranche-sur-Saône',
        'voies': <Object?>[],
      },
      'a document with an invalid code': {
        'codeCommune': '6926',
        'nomCommune': 'Villefranche-sur-Saône',
        'voies': <Object?>[],
      },
      'a document with a blank commune name': {
        'codeCommune': '69264',
        'nomCommune': ' ',
        'voies': <Object?>[],
      },
      'a document with no list of streets': {
        'codeCommune': '69264',
        'nomCommune': 'Villefranche-sur-Saône',
      },
      'a document whose streets are not a list': {
        'codeCommune': '69264',
        'nomCommune': 'Villefranche-sur-Saône',
        'voies': {'0': voie()},
      },
      'a street document': banFixture('lookup_69264_0246.json'),
    };
    unreadableDocuments.forEach((what, json) {
      test('should throw a FormatException when given $what', () {
        expect(
          () => communeStreetsFromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });

  group('streetNumbersFromJson', () {
    // A street document with [numeros] as its numbers.
    Map<String, Object?> street(List<Object?> numeros) => {
      'idVoie': '69264_1460',
      'nomVoie': 'Rue Pierre Morin',
      'commune': {'code': '69264', 'nom': 'Villefranche-sur-Saône'},
      'numeros': numeros,
    };

    // A number entry, valid unless a field is overridden. The position is
    // GeoJSON: [longitude, latitude].
    Map<String, Object?> numero({
      Object? number = 32,
      Object? suffix,
      Object? position = const {
        'type': 'Point',
        'coordinates': [4.716138, 45.987173],
      },
    }) => {'numero': number, 'suffixe': suffix, 'position': position};

    test('should read the street, its commune and its numbers', () {
      final result = streetNumbersFromJson(
        banFixture('lookup_69264_0682.json'),
      );

      expect(result.id, BanStreetId('69264_0682'));
      expect(result.name, name('Rue des Freres Bonnet'));
      expect(result.commune, villefranche);
      expect(result.numbers, [
        DirectoryNumber(
          number: number(185),
          position: point(45.988853, 4.74126),
        ),
        DirectoryNumber(
          number: number(200),
          position: point(45.988783, 4.740376),
        ),
        DirectoryNumber(
          number: number(200, 'a'),
          position: point(45.989016, 4.740343),
        ),
        DirectoryNumber(
          number: number(200, 'b'),
          position: point(45.989532, 4.739785),
        ),
        DirectoryNumber(
          number: number(200, 'c'),
          position: point(45.989749, 4.739704),
        ),
        DirectoryNumber(
          number: number(200, 'd'),
          position: point(45.990069, 4.739912),
        ),
        DirectoryNumber(
          number: number(201),
          position: point(45.988761, 4.740722),
        ),
      ]);
      expect(result.invalidNumbers, 0);
      expect(result.duplicateNumbers, 0);
    });

    test('should label letter suffixes in uppercase', () {
      final result = streetNumbersFromJson(
        banFixture('lookup_69264_0682.json'),
      );

      expect(result.numbers.map((entry) => entry.number.label), [
        '185',
        '200',
        '200A',
        '200B',
        '200C',
        '200D',
        '201',
      ]);
    });

    test('should keep the first of two entries with the same number', () {
      final result = streetNumbersFromJson(
        banFixture('lookup_69264_0246.json'),
      );

      expect(result.numbers.map((entry) => entry.number.label), [
        '89',
        '165',
        '177',
        '185',
        '217',
        '217bis',
        '245',
        '269',
        '303',
        '401',
        '409',
        '427',
        '493',
      ]);
      expect(
        result.numbers.singleWhere((entry) => entry.number == number(303)),
        DirectoryNumber(
          number: number(303),
          position: point(45.972657, 4.743552),
        ),
      );
      expect(result.duplicateNumbers, 1);
      expect(result.invalidNumbers, 0);
    });

    test('should read a bis suffix with its own position', () {
      final result = streetNumbersFromJson(
        banFixture('lookup_69264_0246.json'),
      );

      expect(
        result.numbers.singleWhere((entry) => entry.number.suffix == 'bis'),
        DirectoryNumber(
          number: number(217, 'bis'),
          position: point(45.973576, 4.743866),
        ),
      );
    });

    test('should return no number when the street has none', () {
      final result = streetNumbersFromJson(
        banFixture('lookup_69264_1781_no_numbers.json'),
      );

      expect(result.id, BanStreetId('69264_1781'));
      expect(result.name, name('Allée du Square'));
      expect(result.numbers, isEmpty);
      expect(result.invalidNumbers, 0);
      expect(result.duplicateNumbers, 0);
    });

    test('should keep a number without position when its position is null', () {
      final result = streetNumbersFromJson(
        banFixture('lookup_69264_1460_null_position.json'),
      );

      expect(result.numbers, [
        DirectoryNumber(
          number: number(32),
          position: point(45.987173, 4.716138),
        ),
        DirectoryNumber(number: number(33)),
        DirectoryNumber(
          number: number(34),
          position: point(45.987186, 4.71623),
        ),
      ]);
      expect(result.invalidNumbers, 0);
    });

    test('should read the number with no suffix when the key is missing', () {
      final result = streetNumbersFromJson(
        street([
          {'numero': 32},
        ]),
      );

      expect(result.numbers, [DirectoryNumber(number: number(32))]);
    });

    test('should read the number with no suffix when the suffix is blank', () {
      final result = streetNumbersFromJson(street([numero(suffix: ' ')]));

      expect(result.numbers.single.number, number(32));
      expect(result.numbers.single.number.suffix, isNull);
    });

    test('should keep the edge numbers 0 and 99999', () {
      final result = streetNumbersFromJson(
        street([numero(number: 0), numero(number: 99999)]),
      );

      expect(result.numbers.map((entry) => entry.number.number), [0, 99999]);
      expect(result.invalidNumbers, 0);
    });

    test('should count a suffix written in two cases as a duplicate', () {
      final result = streetNumbersFromJson(
        street([numero(suffix: 'a'), numero(suffix: 'A'), numero(suffix: 'b')]),
      );

      expect(result.numbers.map((entry) => entry.number.label), ['32A', '32B']);
      expect(result.duplicateNumbers, 1);
    });

    test('should count each duplicate once it is seen again', () {
      final result = streetNumbersFromJson(
        street([numero(), numero(), numero(), numero(number: 34)]),
      );

      expect(result.numbers.length, 2);
      expect(result.duplicateNumbers, 2);
      expect(result.invalidNumbers, 0);
    });

    test('should not count an invalid entry as a duplicate', () {
      final result = streetNumbersFromJson(
        street([numero(number: -1), numero(number: -1)]),
      );

      expect(result.numbers, isEmpty);
      expect(result.invalidNumbers, 2);
      expect(result.duplicateNumbers, 0);
    });

    final invalidEntries = <String, Object?>{
      'not an object': 32,
      'null': null,
      'no number': {'suffixe': null},
      'a number that is text': numero(number: '32'),
      'a fractional number': numero(number: 32.5),
      'a negative number': numero(number: -1),
      'a number above 99999': numero(number: 100000),
      'a suffix starting with a digit': numero(suffix: '1'),
      'a suffix with a dash': numero(suffix: 'b-1'),
      'a suffix too long': numero(
        suffix: 'a' * (HouseNumber.maxSuffixLength + 1),
      ),
      'a suffix that is not text': numero(suffix: 2),
    };
    invalidEntries.forEach((what, entry) {
      test('should skip and count an entry with $what', () {
        final result = streetNumbersFromJson(
          street([numero(number: 30), entry, numero(number: 34)]),
        );

        expect(result.numbers.map((entry) => entry.number.number), [30, 34]);
        expect(result.invalidNumbers, 1);
        expect(result.duplicateNumbers, 0);
      });
    });

    final unusablePositions = <String, Object?>{
      'not an object': 'Point',
      'no coordinates': {'type': 'Point'},
      'coordinates that are not a list': {
        'type': 'Point',
        'coordinates': {'lon': 4.7, 'lat': 45.9},
      },
      'a single coordinate': {
        'type': 'Point',
        'coordinates': [4.716138],
      },
      'a coordinate that is text': {
        'type': 'Point',
        'coordinates': ['4.716138', 45.987173],
      },
      'a latitude out of range': {
        'type': 'Point',
        'coordinates': [4.716138, 90.5],
      },
      'a longitude out of range': {
        'type': 'Point',
        'coordinates': [180.5, 45.987173],
      },
    };
    unusablePositions.forEach((what, position) {
      test('should keep the number without position when given $what', () {
        final result = streetNumbersFromJson(
          street([numero(position: position)]),
        );

        expect(result.numbers, [DirectoryNumber(number: number(32))]);
        expect(result.invalidNumbers, 0);
      });
    });

    test('should keep the number without position when the key is missing', () {
      final result = streetNumbersFromJson(
        street([
          {'numero': 32, 'suffixe': null},
        ]),
      );

      expect(result.numbers, [DirectoryNumber(number: number(32))]);
    });

    test('should read whole-degree coordinates and ignore an altitude', () {
      final result = streetNumbersFromJson(
        street([
          numero(
            position: {
              'type': 'Point',
              'coordinates': [5, 46, 170.5],
            },
          ),
        ]),
      );

      expect(result.numbers.single.position, point(46, 5));
    });

    final unreadableDocuments = <String, Object?>{
      'not an object': ['69264_1460'],
      'null': null,
      'a document with no id': {
        'nomVoie': 'Rue Pierre Morin',
        'commune': {'code': '69264', 'nom': 'Villefranche-sur-Saône'},
        'numeros': <Object?>[],
      },
      'a document with a blank id': {...street([]), 'idVoie': ' '},
      'a document with an invalid name': {...street([]), 'nomVoie': ''},
      'a document with no commune': {
        'idVoie': '69264_1460',
        'nomVoie': 'Rue Pierre Morin',
        'numeros': <Object?>[],
      },
      'a document with an invalid commune code': {
        ...street([]),
        'commune': {'code': 'XX264', 'nom': 'Villefranche-sur-Saône'},
      },
      'a document with no list of numbers': {
        'idVoie': '69264_1460',
        'nomVoie': 'Rue Pierre Morin',
        'commune': {'code': '69264', 'nom': 'Villefranche-sur-Saône'},
      },
      'a document whose numbers are not a list': {
        ...street([]),
        'numeros': 'none',
      },
      'a commune document': banFixture('lookup_69264.json'),
    };
    unreadableDocuments.forEach((what, json) {
      test('should throw a FormatException when given $what', () {
        expect(
          () => streetNumbersFromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
