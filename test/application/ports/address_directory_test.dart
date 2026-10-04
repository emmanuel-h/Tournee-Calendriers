import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

import '../../support/results.dart';

void main() {
  final villefranche = valueOf(
    Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
  );
  final pierreMorin = valueOf(StreetName.create('Rue Pierre Morin'));
  final nationale = valueOf(StreetName.create('Rue Nationale'));
  final entrance = valueOf(
    GeoPoint.create(latitude: 45.987173, longitude: 4.716138),
  );
  final otherEntrance = valueOf(
    GeoPoint.create(latitude: 45.987186, longitude: 4.71623),
  );

  group('DirectoryStreet', () {
    DirectoryStreet street({
      String id = '69264_1460',
      StreetName? name,
      int numberCount = 19,
    }) => DirectoryStreet(
      id: BanStreetId(id),
      name: name ?? pierreMorin,
      numberCount: numberCount,
    );

    test('should keep its id, name and number count', () {
      final made = street();

      expect(made.id, BanStreetId('69264_1460'));
      expect(made.name, pierreMorin);
      expect(made.numberCount, 19);
    });

    test('should be equal when every field is equal', () {
      expect(street(), street());
      expect(street().hashCode, street().hashCode);
    });

    test('should differ when the ids differ', () {
      expect(street(), isNot(street(id: '69264_1270')));
    });

    test('should differ when the names differ', () {
      expect(street(), isNot(street(name: nationale)));
    });

    test('should differ when the number counts differ', () {
      expect(street(), isNot(street(numberCount: 18)));
    });

    test('should differ from a value of another type', () {
      expect(street(), isNot('69264_1460'));
    });

    test('should show its id, name and count when printed', () {
      expect(
        street().toString(),
        'DirectoryStreet(69264_1460, Rue Pierre Morin, 19)',
      );
    });
  });

  group('DirectoryNumber', () {
    final twelve = HouseNumber.plain(12);
    final twelveBis = valueOf(HouseNumber.create(12, suffix: 'bis'));

    test('should keep its number and position', () {
      final number = DirectoryNumber(number: twelveBis, position: entrance);

      expect(number.number, twelveBis);
      expect(number.position, entrance);
    });

    test('should have no position when none is given', () {
      expect(DirectoryNumber(number: twelve).position, isNull);
    });

    test('should be equal when the number and the position are equal', () {
      expect(
        DirectoryNumber(number: twelve, position: entrance),
        DirectoryNumber(number: twelve, position: entrance),
      );
      expect(
        DirectoryNumber(number: twelve, position: entrance).hashCode,
        DirectoryNumber(number: twelve, position: entrance).hashCode,
      );
    });

    test('should differ when the numbers differ', () {
      expect(
        DirectoryNumber(number: twelve, position: entrance),
        isNot(DirectoryNumber(number: twelveBis, position: entrance)),
      );
    });

    test('should differ when the positions differ', () {
      expect(
        DirectoryNumber(number: twelve, position: entrance),
        isNot(DirectoryNumber(number: twelve, position: otherEntrance)),
      );
      expect(
        DirectoryNumber(number: twelve, position: entrance),
        isNot(DirectoryNumber(number: twelve)),
      );
    });

    test('should differ from a value of another type', () {
      expect(DirectoryNumber(number: twelve), isNot(twelve));
    });

    test('should show its label and position when printed', () {
      expect(
        DirectoryNumber(number: twelveBis, position: entrance).toString(),
        'DirectoryNumber(12bis, GeoPoint(45.987173, 4.716138))',
      );
      expect(
        DirectoryNumber(number: twelve).toString(),
        'DirectoryNumber(12, null)',
      );
    });
  });

  group('CommuneStreets', () {
    test('should keep its commune, streets and skipped count', () {
      final street = DirectoryStreet(
        id: BanStreetId('69264_1460'),
        name: pierreMorin,
        numberCount: 19,
      );

      final streets = CommuneStreets(
        commune: villefranche,
        streets: [street],
        skippedStreets: 2,
      );

      expect(streets.commune, villefranche);
      expect(streets.streets, [street]);
      expect(streets.skippedStreets, 2);
    });

    test('should not let the list of streets be changed', () {
      final source = <DirectoryStreet>[];
      final streets = CommuneStreets(
        commune: villefranche,
        streets: source,
        skippedStreets: 0,
      );

      source.add(
        DirectoryStreet(
          id: BanStreetId('69264_1460'),
          name: pierreMorin,
          numberCount: 19,
        ),
      );

      expect(streets.streets, isEmpty);
      expect(
        () => streets.streets.add(
          DirectoryStreet(
            id: BanStreetId('69264_1270'),
            name: nationale,
            numberCount: 403,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('StreetNumbers', () {
    test('should keep every field', () {
      final number = DirectoryNumber(
        number: HouseNumber.plain(32),
        position: entrance,
      );

      final numbers = StreetNumbers(
        id: BanStreetId('69264_1460'),
        name: pierreMorin,
        commune: villefranche,
        numbers: [number],
        invalidNumbers: 3,
        duplicateNumbers: 1,
      );

      expect(numbers.id, BanStreetId('69264_1460'));
      expect(numbers.name, pierreMorin);
      expect(numbers.commune, villefranche);
      expect(numbers.numbers, [number]);
      expect(numbers.invalidNumbers, 3);
      expect(numbers.duplicateNumbers, 1);
    });

    test('should not let the list of numbers be changed', () {
      final source = <DirectoryNumber>[];
      final numbers = StreetNumbers(
        id: BanStreetId('69264_1460'),
        name: pierreMorin,
        commune: villefranche,
        numbers: source,
        invalidNumbers: 0,
        duplicateNumbers: 0,
      );

      source.add(DirectoryNumber(number: HouseNumber.plain(32)));

      expect(numbers.numbers, isEmpty);
      expect(
        () =>
            numbers.numbers.add(DirectoryNumber(number: HouseNumber.plain(1))),
        throwsUnsupportedError,
      );
    });
  });
}
