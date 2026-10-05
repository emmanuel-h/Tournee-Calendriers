import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_json_mapper.dart';

import '../../../support/results.dart';
import '../../../support/street_fixtures.dart';
import '../stored_street_fixtures.dart';

/// [street] written, encoded as text, decoded and read back: the path the
/// phone storage takes.
Street throughText(Street street) =>
    streetFromJson(jsonDecode(jsonEncode(streetToJson(street))));

/// The stored form of [richStreet], decoded from text like a file, after
/// [change] altered it.
Object? storedRichStreet(void Function(Map<String, Object?> json) change) {
  final json =
      jsonDecode(jsonEncode(streetToJson(richStreet))) as Map<String, Object?>;
  change(json);
  return json;
}

Map<String, Object?> _at(Object? list, int index) =>
    (list! as List<Object?>)[index]! as Map<String, Object?>;

/// The stored house at [index] (0 is number 1, 1 is 3bis, 4 is building 8).
Map<String, Object?> houseAt(Map<String, Object?> json, int index) =>
    _at(json['houses'], index);

/// The stored building of house 8 (staircase A first).
Map<String, Object?> buildingOfEight(Map<String, Object?> json) =>
    houseAt(json, 4)['building']! as Map<String, Object?>;

/// The stored first floor of staircase A of house 8, and its door 12.
Map<String, Object?> firstFloorOfEight(Map<String, Object?> json) =>
    _at(_at(buildingOfEight(json)['staircases'], 0)['floors'], 0);
Map<String, Object?> doorTwelve(Map<String, Object?> json) =>
    _at(firstFloorOfEight(json)['dwellings'], 1);

/// Every key of every map in [json], however deep.
Set<String> _keysIn(Object? json) => switch (json) {
  final Map<String, Object?> map => {
    ...map.keys,
    for (final value in map.values) ..._keysIn(value),
  },
  final List<Object?> list => {for (final item in list) ..._keysIn(item)},
  _ => const {},
};

/// Turns every « repasser » status in [json] into the version 1 form: to
/// do, the come-back beside it being the flag.
void _asFlags(Object? json) {
  switch (json) {
    case final Map<String, Object?> map:
      if (map['status'] == 'comeBack') map['status'] = 'toDo';
      map.values.forEach(_asFlags);
    case final List<Object?> list:
      list.forEach(_asFlags);
  }
}

void main() {
  group('round trip', () {
    test('should read back every field of a full street', () {
      expectSameStreet(throughText(richStreet), richStreet);
    });

    test('should read back a street typed in by hand', () {
      expectSameStreet(throughText(manualStreet), manualStreet);
    });

    test('should read back the map it wrote without text in between', () {
      expectSameStreet(streetFromJson(streetToJson(richStreet)), richStreet);
    });
  });

  group('written form', () {
    test('should write the schema version 3', () {
      expect(streetToJson(manualStreet)['version'], 3);
      expect(storedStreetVersion, 3);
    });

    test('should write each field under its name', () {
      final street = valueOf(
        Street.create(
          id: StreetId('lilas'),
          name: 'Rue des Lilas',
          commune: villefranche,
          banId: BanStreetId('69264_0420'),
          houses: [
            House(
              number: n('3bis'),
              status: VisitStatus.comeBack,
              comeBack: comeBack('après 19h'),
              lastChange: leaAtTwo,
              position: townHallDoor,
            ),
            House(number: n('12'), building: lettered),
          ],
          deletion: paulAtThree,
        ),
      );

      expect(streetToJson(street), {
        'version': 3,
        'id': 'lilas',
        'name': 'Rue des Lilas',
        'commune': {'inseeCode': '69264', 'name': 'Villefranche-sur-Saône'},
        'banId': '69264_0420',
        'deletion': {'by': 'paul', 'at': '2026-11-02T15:00:00.000Z'},
        'houses': [
          {
            'number': '3bis',
            'status': 'comeBack',
            'comeBack': 'après 19h',
            'lastChange': {'by': 'lea', 'at': '2026-11-02T14:02:00.000Z'},
            'position': {'latitude': 45.98915, 'longitude': 4.71862},
            'building': null,
          },
          {
            'number': '12',
            'status': 'toDo',
            'comeBack': null,
            'lastChange': null,
            'position': null,
            'building': {
              'style': 'floorAndLetter',
              'staircases': [
                {
                  'name': 'A',
                  'floors': [
                    {
                      'level': 2,
                      'dwellings': [
                        {
                          'label': '2A',
                          'status': 'toDo',
                          'comeBack': null,
                          'lastChange': null,
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          },
        ],
        'removedHouses': <Object?>[],
      });
    });

    test('should write a removed house with its removal', () {
      final json = streetToJson(richStreet);

      final removed = _at(json['removedHouses'], 0);
      expect(_at([removed['house']], 0)['number'], '14ter');
      expect(removed['removal'], {
        'by': 'paul',
        'at': '2026-11-02T15:00:00.000Z',
      });
    });

    test('should write each status and style under a stable name', () {
      final json = streetToJson(richStreet);

      expect(houseAt(json, 0)['status'], 'toDo');
      expect(houseAt(json, 2)['status'], 'done');
      expect(houseAt(json, 3)['status'], 'nobodyHome');
      expect(houseAt(json, 1)['status'], 'comeBack');
      expect(buildingOfEight(json)['style'], 'floorAndNumber');
      expect(
        (houseAt(json, 5)['building']! as Map<String, Object?>)['style'],
        'free',
      );
      expect(firstFloorOfEight(json)['level'], 1);
    });

    test('should write the time in UTC whatever the time zone', () {
      final street = valueOf(
        Street.create(
          id: StreetId('lilas'),
          name: 'Rue des Lilas',
          commune: villefranche,
          deletion: leaAtTwo,
        ),
      );
      final local = valueOf(
        Street.create(
          id: StreetId('lilas'),
          name: 'Rue des Lilas',
          commune: villefranche,
        ),
      ).delete(by: lea, at: twoPm.toLocal()).$1;

      expect(streetToJson(local)['deletion'], streetToJson(street)['deletion']);
    });
  });

  group('stored files', () {
    /// The street every fixture file holds: houses 5 and 7 and doors 02 and
    /// 12 « repasser » (each with its hint, or none), building 4 with its
    /// own « repasser », and number 11 « repasser » in the Corbeille. The
    /// files of versions 1 and 2 also hold notes on 4, its door 12, 5 and
    /// 11, which reading drops.
    final rueNationale = valueOf(
      Street.create(
        id: StreetId('x7Kq2LmP9sTb4VnW1cZd'),
        name: 'Rue Nationale',
        commune: villefranche,
        banId: BanStreetId('69264_1460'),
        houses: [
          House(
            number: n('2'),
            status: VisitStatus.done,
            lastChange: leaAtTwo,
            position: northDoor,
          ),
          House(
            number: n('4'),
            comeBack: comeBack('samedi'),
            lastChange: paulAtThree,
            building: valueOf(
              Building.create(
                style: DoorLabelStyle.floorAndNumber,
                staircases: [
                  Staircase(
                    name: escA,
                    floors: [
                      Floor(
                        level: 1,
                        dwellings: [
                          Dwelling(
                            label: d('11'),
                            status: VisitStatus.nobodyHome,
                            lastChange: leaAtTwo,
                          ),
                          Dwelling(
                            label: d('12'),
                            status: VisitStatus.comeBack,
                            comeBack: comeBack('le soir'),
                            lastChange: leaAtTwo,
                          ),
                        ],
                      ),
                      Floor(
                        level: 0,
                        dwellings: [
                          Dwelling(label: d('01')),
                          Dwelling(
                            label: d('02'),
                            status: VisitStatus.comeBack,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          House(
            number: n('5'),
            status: VisitStatus.comeBack,
            comeBack: comeBack('après 19h'),
            lastChange: leaAtTwo,
          ),
          House(
            number: n('7'),
            status: VisitStatus.comeBack,
            lastChange: paulAtThree,
          ),
          House(
            number: n('9'),
            status: VisitStatus.nobodyHome,
            lastChange: paulAtThree,
          ),
        ],
        removedHouses: [
          RemovedHouse(
            house: House(
              number: n('11'),
              status: VisitStatus.comeBack,
              comeBack: comeBack('dimanche'),
            ),
            removal: paulAtThree,
          ),
        ],
      ),
    );

    Object? fixture(String name) => jsonDecode(
      File('test/fixtures/local_storage/$name').readAsStringSync(),
    );

    test('should read the file a phone wrote in version 3', () {
      expectSameStreet(streetFromJson(fixture('street_v3.json')), rueNationale);
    });

    test('should read a version 2 file without its notes, every other '
        'mark kept', () {
      expectSameStreet(streetFromJson(fixture('street_v2.json')), rueNationale);
    });

    test('should turn every « repasser » flag of version 1 into the status, '
        'hint kept', () {
      expectSameStreet(streetFromJson(fixture('street_v1.json')), rueNationale);
    });

    /// [name] read and written again, decoded from text like a file.
    Object? rewritten(String name) =>
        jsonDecode(jsonEncode(streetToJson(streetFromJson(fixture(name)))));

    for (final older in ['street_v1.json', 'street_v2.json']) {
      test('should write $older back as the version 3 file, no note left', () {
        final written = rewritten(older);

        expect(written, rewritten('street_v3.json'));
        expect((written! as Map<String, Object?>)['version'], 3);
        expect(_keysIn(written), isNot(contains('note')));
        // Not vacuous: the file read did hold notes.
        expect(_keysIn(fixture(older)), contains('note'));
      });
    }

    test('should tell a file of versions 1 and 2 to be written again', () {
      expect(isOlderStoredStreet(fixture('street_v1.json')), isTrue);
      expect(isOlderStoredStreet(fixture('street_v2.json')), isTrue);
    });

    test('should not tell a file of version 3 to be written again', () {
      expect(isOlderStoredStreet(fixture('street_v3.json')), isFalse);
    });

    test('should not tell what is not a stored street to be written', () {
      expect(isOlderStoredStreet(<Object?>[]), isFalse);
      expect(isOlderStoredStreet({'version': '1'}), isFalse);
    });

    test('should keep a done house done when version 1 read it', () {
      final street = streetFromJson(fixture('street_v1.json'));

      expect(street.houses.first.status, VisitStatus.done);
      expect(street.houses.first.comeBack, isNull);
    });
  });

  group('hints longer than 20 characters in an older file', () {
    // Versions 1 and 2 allowed 50 characters; version 3 allows 20 (Q23).
    for (final version in [1, 2]) {
      /// The rich street stored in [version] with long hints on house
      /// 3bis, building 8, its door 12 and removed 14ter, read back.
      Street readWithLongHints() => streetFromJson(
        storedRichStreet((json) {
          json['version'] = version;
          if (version == 1) _asFlags(json);
          // The 20th character is a space: the cut hint is trimmed.
          houseAt(json, 1)['comeBack'] = '${'a' * 19} bbbb';
          houseAt(json, 4)['comeBack'] = '🔔' * 25;
          doorTwelve(json)['comeBack'] = 'c' * 21;
          final removed = _at(json['removedHouses'], 0);
          (removed['house']! as Map<String, Object?>)
            ..['status'] = version == 1 ? 'toDo' : 'comeBack'
            ..['comeBack'] = '${'d' * 20}e';
        }),
      );

      test('should cut each hint of version $version to its first 20 '
          'characters, trimmed', () {
        final street = readWithLongHints();

        expect(street.houses[1].status, VisitStatus.comeBack);
        expect(street.houses[1].comeBack, comeBack('a' * 19));
        expect(street.houses[4].comeBack, comeBack('🔔' * 20));
        final door = street.houses[4].building!.dwellingAt(
          DwellingKey(escA, 1, d('12')),
        )!;
        expect(door.status, VisitStatus.comeBack);
        expect(door.comeBack, comeBack('c' * 20));
        expect(street.removedHouses.single.house.comeBack, comeBack('d' * 20));
      });

      test('should keep a hint of version $version of 20 characters or '
          'fewer as it is', () {
        final street = streetFromJson(
          storedRichStreet((json) {
            json['version'] = version;
            if (version == 1) _asFlags(json);
            houseAt(json, 4)['comeBack'] = 'e' * 20;
          }),
        );

        expect(street.houses[4].comeBack, comeBack('e' * 20));
      });
    }
  });

  group('lenient reading', () {
    test('should read whole-degree coordinates', () {
      final street = streetFromJson(
        storedRichStreet(
          (json) =>
              houseAt(json, 0)['position'] = {'latitude': 46, 'longitude': 5},
        ),
      );

      expect(street.houses.first.position!.latitude, 46.0);
      expect(street.houses.first.position!.longitude, 5.0);
    });

    test('should read a time written with an offset as UTC', () {
      final street = streetFromJson(
        storedRichStreet(
          (json) => json['deletion'] = {
            'by': 'lea',
            'at': '2026-11-02T15:02:00.000+01:00',
          },
        ),
      );

      expect(street.deletion, leaAtTwo);
      expect(street.deletion!.at.isUtc, isTrue);
    });
  });

  group('unreadable data', () {
    final cases = <String, void Function(Map<String, Object?> json)>{
      'the version is missing': (json) => json.remove('version'),
      'the version is newer': (json) => json['version'] = 4,
      'the version is older': (json) => json['version'] = 0,
      'the version is text': (json) => json['version'] = '2',
      'a version 1 file holds the « repasser » status': (json) {
        json['version'] = 1;
        houseAt(json, 1)['status'] = 'comeBack';
      },
      'the id is missing': (json) => json.remove('id'),
      'the id is blank': (json) => json['id'] = '  ',
      'the name is blank': (json) => json['name'] = ' ',
      'the commune code is wrong': (json) =>
          json['commune'] = {'inseeCode': 'ABCDE', 'name': 'Villefranche'},
      'the commune has no name': (json) =>
          json['commune'] = {'inseeCode': '69264'},
      'the BAN id is blank': (json) => json['banId'] = '',
      'the BAN id is a number': (json) => json['banId'] = 69264,
      'the deletion is not a stamp': (json) => json['deletion'] = 'hier',
      'a stamp has a blank member': (json) =>
          json['deletion'] = {'by': '', 'at': '2026-11-02T14:02:00.000Z'},
      'a stamp has no readable time': (json) =>
          json['deletion'] = {'by': 'lea', 'at': 'demain'},
      'the houses are not a list': (json) => json['houses'] = 'none',
      'the removed houses are missing': (json) => json.remove('removedHouses'),
      'a house has no building field': (json) =>
          houseAt(json, 0).remove('building'),
      'a house number is not one': (json) =>
          houseAt(json, 0)['number'] = '12-1',
      'a status is unknown': (json) => houseAt(json, 0)['status'] = 'DONE',
      'a hint is too long': (json) => houseAt(json, 1)['comeBack'] = 'x' * 21,
      'a building hint is too long': (json) =>
          houseAt(json, 4)['comeBack'] = 'x' * 21,
      'a last change is not a stamp': (json) =>
          houseAt(json, 1)['lastChange'] = 12,
      'a position is out of range': (json) =>
          houseAt(json, 0)['position'] = {'latitude': 91, 'longitude': 4},
      'a position has another shape': (json) =>
          houseAt(json, 0)['position'] = [4.7, 45.9],
      'a coordinate is text': (json) =>
          houseAt(json, 0)['position'] = {'latitude': '45', 'longitude': 4},
      'two houses have a number': (json) => houseAt(json, 0)['number'] = '3bis',
      'a removed house has no removal': (json) =>
          _at(json['removedHouses'], 0).remove('removal'),
      'a building style is unknown': (json) =>
          buildingOfEight(json)['style'] = 'roman',
      'a building has no staircase': (json) =>
          buildingOfEight(json)['staircases'] = <Object?>[],
      'a building is not a map': (json) => houseAt(json, 4)['building'] = 8,
      'a staircase name is not a capital': (json) =>
          _at(buildingOfEight(json)['staircases'], 0)['name'] = 'a',
      'a staircase has no floors': (json) =>
          _at(buildingOfEight(json)['staircases'], 0).remove('floors'),
      'a floor level is text': (json) => firstFloorOfEight(json)['level'] = '1',
      'a door label is blank': (json) => doorTwelve(json)['label'] = ' ',
      'a door status is unknown': (json) =>
          doorTwelve(json)['status'] = 'absent',
      'a door hint is too long': (json) =>
          doorTwelve(json)['comeBack'] = 'x' * 21,
      'a door has no last change field': (json) =>
          doorTwelve(json).remove('lastChange'),
    };

    cases.forEach((what, change) {
      test('should refuse the street when $what', () {
        expect(
          () => streetFromJson(storedRichStreet(change)),
          throwsFormatException,
        );
      });
    });

    test('should refuse what is not a map', () {
      expect(() => streetFromJson(<Object?>[]), throwsFormatException);
      expect(() => streetFromJson(null), throwsFormatException);
    });
  });
}
