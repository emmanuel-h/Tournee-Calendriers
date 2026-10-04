import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
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
    test('should write the schema version 1', () {
      expect(streetToJson(manualStreet)['version'], 1);
      expect(storedStreetVersion, 1);
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
              status: VisitStatus.nobodyHome,
              comeBack: comeBack('après 19h'),
              note: note('chien'),
              lastChange: leaAtTwo,
              position: townHallDoor,
            ),
            House(number: n('12'), building: lettered),
          ],
          deletion: paulAtThree,
        ),
      );

      expect(streetToJson(street), {
        'version': 1,
        'id': 'lilas',
        'name': 'Rue des Lilas',
        'commune': {'inseeCode': '69264', 'name': 'Villefranche-sur-Saône'},
        'banId': '69264_0420',
        'deletion': {'by': 'paul', 'at': '2026-11-02T15:00:00.000Z'},
        'houses': [
          {
            'number': '3bis',
            'status': 'nobodyHome',
            'comeBack': 'après 19h',
            'note': 'chien',
            'lastChange': {'by': 'lea', 'at': '2026-11-02T14:02:00.000Z'},
            'position': {'latitude': 45.98915, 'longitude': 4.71862},
            'building': null,
          },
          {
            'number': '12',
            'status': 'toDo',
            'comeBack': null,
            'note': '',
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
                          'note': '',
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
      expect(houseAt(json, 1)['status'], 'nobodyHome');
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

  group('stored file of version 1', () {
    test('should read the file a phone wrote', () {
      final json = jsonDecode(
        File('test/fixtures/local_storage/street_v1.json').readAsStringSync(),
      );

      final street = streetFromJson(json);

      expectSameStreet(
        street,
        valueOf(
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
                note: note('sonnette en panne'),
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
                            ],
                          ),
                          Floor(
                            level: 0,
                            dwellings: [Dwelling(label: d('01'))],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
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
      'the version is newer': (json) => json['version'] = 2,
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
      'a hint is too long': (json) => houseAt(json, 1)['comeBack'] = 'x' * 51,
      'a note is too long': (json) => houseAt(json, 1)['note'] = 'x' * 201,
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
          doorTwelve(json)['comeBack'] = 'x' * 51,
      'a door note is too long': (json) => doorTwelve(json)['note'] = 'x' * 201,
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
