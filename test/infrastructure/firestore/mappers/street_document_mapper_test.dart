// The street document of Firestore (PLAN §6.2): what is written must come
// back as the same street, and the field names are the ones the security
// rules (T2.4) check.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';

import '../../../support/street_fixtures.dart';
import '../../local_storage/stored_street_fixtures.dart';

/// [data] as Firestore gives it back: maps of `String` to `dynamic`, lists
/// of `dynamic`, a fresh copy so nothing is shared with what was written.
Map<String, dynamic> asRead(Map<String, Object?> data) =>
    _copy(data)! as Map<String, dynamic>;

Object? _copy(Object? value) => switch (value) {
  final Map<String, Object?> map => <String, dynamic>{
    for (final MapEntry(:key, :value) in map.entries) key: _copy(value),
  },
  final List<Object?> list => <dynamic>[for (final item in list) _copy(item)],
  _ => value,
};

/// [richStreet]'s document after [change] altered it.
Map<String, dynamic> storedRich(
  void Function(Map<String, dynamic> data) change,
) {
  final data = asRead(streetToDocument(richStreet));
  change(data);
  return data;
}

Map<String, dynamic> housesOf(Map<String, dynamic> data) =>
    data['houses'] as Map<String, dynamic>;

Map<String, dynamic> eight(Map<String, dynamic> data) =>
    housesOf(data)['8'] as Map<String, dynamic>;

/// The floor at [index] of the layout of building 8.
Map<String, dynamic> floorOfEight(Map<String, dynamic> data, int index) =>
    (eight(data)['layout'] as List<dynamic>)[index] as Map<String, dynamic>;

Street read(Map<String, dynamic> data) =>
    streetFromDocument(richStreet.id.value, data);

final twoPmStamp = Timestamp.fromDate(twoPm);
final threePmStamp = Timestamp.fromDate(threePm);

void main() {
  group('round trip', () {
    test('should give back every field of a street when read again', () {
      final back = streetFromDocument(
        richStreet.id.value,
        asRead(streetToDocument(richStreet)),
      );

      expectSameStreet(back, richStreet);
    });

    test('should give back a street typed in by hand when read again', () {
      final back = streetFromDocument(
        manualStreet.id.value,
        asRead(streetToDocument(manualStreet)),
      );

      expectSameStreet(back, manualStreet);
    });

    test('should take the street id from the document id', () {
      final back = streetFromDocument(
        'other-id',
        asRead(streetToDocument(manualStreet)),
      );

      expect(back.id, StreetId('other-id'));
    });
  });

  group('document', () {
    test('should write the street fields under their stored names', () {
      final data = streetToDocument(richStreet);

      expect(data['name'], 'Rue des Lilas');
      expect(data['communeName'], 'Villefranche-sur-Saône');
      expect(data['communeCode'], '69264');
      expect(data['banId'], '69264_0420');
      expect(data['deletedAt'], twoPmStamp);
      expect(data['deletedBy'], 'lea');
      expect(data.keys, {
        'name',
        'communeName',
        'communeCode',
        'banId',
        'deletedAt',
        'deletedBy',
        'houses',
      });
    });

    test('should write null for what a street typed by hand lacks', () {
      final data = streetToDocument(manualStreet);

      expect(data['banId'], isNull);
      expect(data['deletedAt'], isNull);
      expect(data['deletedBy'], isNull);
    });

    test('should key each house by its label, removed ones included', () {
      final houses =
          streetToDocument(richStreet)['houses']! as Map<String, Object?>;

      expect(houses.keys, ['1', '3bis', '3A', '5', '8', '10', '12', '14ter']);
    });

    test('should write a single house with every field it stores', () {
      final houses =
          streetToDocument(richStreet)['houses']! as Map<String, Object?>;

      expect(houses['3bis'], {
        'n': 3,
        'sfx': 'bis',
        'lat': 45.99210,
        'lon': 4.71705,
        'status': 'COME_BACK',
        'comeBack': 'après 19h',
        'by': 'lea',
        'at': twoPmStamp,
        'deletedAt': null,
        'deletedBy': null,
      });
    });

    test('should write null for an unmarked house without position', () {
      final house = houseEntry(House(number: n('7')));

      expect(house, {
        'n': 7,
        'sfx': null,
        'lat': null,
        'lon': null,
        'status': 'TO_DO',
        'comeBack': null,
        'by': null,
        'at': null,
        'deletedAt': null,
        'deletedBy': null,
      });
    });

    test('should write a removed number with who removed it and when', () {
      final houses =
          streetToDocument(richStreet)['houses']! as Map<String, Object?>;
      final removed = houses['14ter']! as Map<String, Object?>;

      expect(removed['deletedAt'], threePmStamp);
      expect(removed['deletedBy'], 'paul');
      // Its own last change stays apart from the removal.
      expect(removed['by'], 'lea');
      expect(removed['at'], twoPmStamp);
    });

    test('should write each status under its stored name', () {
      expect(statusName(VisitStatus.toDo), 'TO_DO');
      expect(statusName(VisitStatus.done), 'DONE');
      expect(statusName(VisitStatus.nobodyHome), 'NOBODY_HOME');
      expect(statusName(VisitStatus.comeBack), 'COME_BACK');
    });

    test('should write each label style under its stored name', () {
      expect(labelStyleName(DoorLabelStyle.floorAndNumber), 'FLOOR_AND_NUMBER');
      expect(labelStyleName(DoorLabelStyle.floorAndLetter), 'FLOOR_AND_LETTER');
      expect(labelStyleName(DoorLabelStyle.free), 'FREE');
    });

    test('should write a building with its style, layout and doors', () {
      final house =
          streetToDocument(richStreet)['houses']! as Map<String, Object?>;
      final building = house['8']! as Map<String, Object?>;

      expect(building['status'], 'TO_DO');
      expect(building['comeBack'], 'gardien');
      expect(building['labelStyle'], 'FLOOR_AND_NUMBER');
      expect(building['layout'], [
        {
          'esc': 'A',
          'floor': 1,
          'doors': ['11', '12'],
        },
        {'esc': 'A', 'floor': 0, 'doors': <String>[]},
        {
          'esc': 'B',
          'floor': 0,
          'doors': ['01'],
        },
      ]);
      expect(building['dwellings'], {
        'A1-11': {
          'status': 'DONE',
          'comeBack': null,
          'by': 'lea',
          'at': twoPmStamp,
        },
        'A1-12': {
          'status': 'COME_BACK',
          'comeBack': 'le soir',
          'by': 'paul',
          'at': threePmStamp,
        },
        'B0-01': {
          'status': 'COME_BACK',
          'comeBack': '',
          'by': null,
          'at': null,
        },
      });
    });

    test('should write the « Logements » row of unknown floors as null', () {
      final houses =
          streetToDocument(richStreet)['houses']! as Map<String, Object?>;
      final ten = houses['10']! as Map<String, Object?>;

      expect(ten['layout'], [
        {
          'esc': 'A',
          'floor': null,
          'doors': ['Gauche', 'Droite'],
        },
      ]);
      expect((ten['dwellings']! as Map<String, Object?>).keys, [
        'A-Gauche',
        'A-Droite',
      ]);
    });

    test('should write no building field on a single house', () {
      final house = houseEntry(House(number: n('7')));

      expect(house.containsKey('labelStyle'), isFalse);
      expect(house.containsKey('layout'), isFalse);
      expect(house.containsKey('dwellings'), isFalse);
    });

    test('should write a door entry with its marks only', () {
      final door = dwellingEntry(
        Dwelling(
          label: d('51'),
          status: VisitStatus.nobodyHome,
          lastChange: paulAtThree,
        ),
      );

      expect(door, {
        'status': 'NOBODY_HOME',
        'comeBack': null,
        'by': 'paul',
        'at': threePmStamp,
      });
    });
  });

  group('reading', () {
    test('should read the doors of a floor in the layout order', () {
      final data = storedRich((data) {
        final ten = housesOf(data)['10'] as Map<String, dynamic>;
        // Firestore gives a map's keys in its own order, not the doors'.
        final doors = ten['dwellings'] as Map<String, dynamic>;
        ten['dwellings'] = <String, dynamic>{
          'A-Droite': doors['A-Droite'],
          'A-Gauche': doors['A-Gauche'],
        };
      });

      final ten = read(data).houses.singleWhere((h) => h.number == n('10'));
      final labels = ten.building!.staircases.single.floors.single.dwellings
          .map((door) => door.label.text);

      expect(labels, ['Gauche', 'Droite']);
    });

    test('should keep an emptied floor when read', () {
      final eightHouse = read(asRead(streetToDocument(richStreet))).houses
          .singleWhere((h) => h.number == n('8'));
      final floors = eightHouse.building!.staircases.first.floors;

      expect(floors.map((floor) => floor.level), [1, 0]);
      expect(floors.last.dwellings, isEmpty);
    });

    test('should accept whole numbers as a position', () {
      final data = storedRich((data) {
        final one = housesOf(data)['1'] as Map<String, dynamic>;
        one['lat'] = 46;
        one['lon'] = 5;
      });

      final one = read(data).houses.first;

      expect(one.position!.latitude, 46.0);
      expect(one.position!.longitude, 5.0);
    });

    test('should skip a house entry without its number', () {
      // What a mark leaves when it lands just after a teammate renumbered
      // or removed that house: the fields of the mark, nothing else.
      final data = storedRich((data) {
        housesOf(data)['4'] = <String, dynamic>{
          'status': 'DONE',
          'comeBack': null,
          'by': 'paul',
          'at': threePmStamp,
        };
      });

      final street = read(data);

      expect(street.houses.map((h) => h.number.label), [
        '1',
        '3bis',
        '3A',
        '5',
        '8',
        '10',
        '12',
      ]);
    });

    test('should ignore a door entry the layout does not list', () {
      final data = storedRich((data) {
        (eight(data)['dwellings']
            as Map<String, dynamic>)['A2-21'] = <String, dynamic>{
          'comeBack': 'x',
          'by': 'paul',
          'at': threePmStamp,
        };
      });

      final building = read(data).houses
          .singleWhere((h) => h.number == n('8'))
          .building!;

      expect(building.dwellingAt(DwellingKey(escA, 2, d('21'))), isNull);
      expect(building.staircases.expand((s) => s.dwellings), hasLength(3));
    });

    test('should read a single house when doors are left without layout', () {
      final data = storedRich((data) {
        final one = housesOf(data)['1'] as Map<String, dynamic>;
        one['dwellings'] = <String, dynamic>{
          'A0-01': <String, dynamic>{'status': 'DONE'},
        };
      });

      expect(read(data).houses.first.building, isNull);
    });

    test('should read a removed number into the Corbeille of the street', () {
      final street = read(asRead(streetToDocument(richStreet)));

      expect(street.removedHouses, [removedFourteen]);
      expect(street.houses.map((h) => h.number), isNot(contains(n('14ter'))));
    });

    test('should read a street out of the Corbeille when not deleted', () {
      final data = storedRich((data) {
        data['deletedAt'] = null;
        data['deletedBy'] = null;
      });

      expect(read(data).deletion, isNull);
    });

    test('should read a time in UTC', () {
      final street = read(asRead(streetToDocument(richStreet)));

      expect(street.deletion!.at.isUtc, isTrue);
      expect(street.deletion!.at, twoPm);
    });
  });

  group('unreadable', () {
    void expectUnreadable(void Function(Map<String, dynamic> data) change) {
      expect(() => read(storedRich(change)), throwsFormatException);
    }

    Map<String, dynamic> one(Map<String, dynamic> data) =>
        housesOf(data)['1'] as Map<String, dynamic>;

    Map<String, dynamic> doorEleven(Map<String, dynamic> data) =>
        (eight(data)['dwellings'] as Map<String, dynamic>)['A1-11']
            as Map<String, dynamic>;

    test('should refuse a document without a name', () {
      expectUnreadable((data) => data.remove('name'));
    });

    test('should refuse a name the domain refuses', () {
      expectUnreadable((data) => data['name'] = '   ');
    });

    test('should refuse a commune the domain refuses', () {
      expectUnreadable((data) => data['communeCode'] = '6926');
    });

    test('should refuse a blank BAN id', () {
      expectUnreadable((data) => data['banId'] = ' ');
    });

    test('should refuse a deletion time without who deleted', () {
      expectUnreadable((data) => data['deletedBy'] = null);
    });

    test('should refuse who deleted without a time', () {
      expectUnreadable((data) => data['deletedAt'] = null);
    });

    test('should refuse a time that is not a Firestore time', () {
      expectUnreadable((data) => data['deletedAt'] = '2026-11-02T14:02:00Z');
    });

    test('should refuse houses that are not a map', () {
      expectUnreadable((data) => data['houses'] = <dynamic>[]);
    });

    test('should refuse a house entry that is not a map', () {
      expectUnreadable((data) => housesOf(data)['1'] = 'done');
    });

    test('should refuse a house without its status', () {
      expectUnreadable((data) => one(data).remove('status'));
    });

    test('should refuse a status it does not know', () {
      expectUnreadable((data) => one(data)['status'] = 'done');
    });

    test('should refuse a number the domain refuses', () {
      expectUnreadable((data) => one(data)['n'] = -1);
    });

    test('should refuse a house whose number is not its key', () {
      expectUnreadable((data) => one(data)['sfx'] = 'bis');
    });

    test('should refuse a position with only a latitude', () {
      expectUnreadable((data) => one(data)['lon'] = null);
    });

    test('should refuse a position with only a longitude', () {
      expectUnreadable((data) => one(data)['lat'] = null);
    });

    test('should refuse a position the domain refuses', () {
      expectUnreadable((data) => one(data)['lat'] = 91);
    });

    test('should refuse who changed a house without when', () {
      expectUnreadable((data) => one(data)['by'] = 'lea');
    });

    test('should refuse when a house changed without who', () {
      expectUnreadable((data) => one(data)['at'] = twoPmStamp);
    });

    test('should refuse a blank member id', () {
      expectUnreadable((data) {
        one(data)['by'] = '';
        one(data)['at'] = twoPmStamp;
      });
    });

    test('should refuse a hint longer than the domain allows', () {
      expectUnreadable((data) {
        final threeBis = housesOf(data)['3bis'] as Map<String, dynamic>;
        threeBis['comeBack'] = 'x' * (ComeBack.maxHintLength + 1);
      });
    });

    test('should refuse a removal time without who removed', () {
      expectUnreadable((data) {
        (housesOf(data)['14ter'] as Map<String, dynamic>)['deletedBy'] = null;
      });
    });

    test('should refuse a label style it does not know', () {
      expectUnreadable((data) => eight(data)['labelStyle'] = 'floorAndNumber');
    });

    test('should refuse a building without its doors', () {
      expectUnreadable((data) => eight(data).remove('dwellings'));
    });

    test('should refuse a floor of the layout without its doors', () {
      expectUnreadable((data) {
        floorOfEight(data, 0).remove('doors');
      });
    });

    test('should refuse a staircase name the domain refuses', () {
      expectUnreadable((data) {
        floorOfEight(data, 2)['esc'] = 'b';
      });
    });

    test('should refuse a door label the domain refuses', () {
      expectUnreadable((data) {
        floorOfEight(data, 2)['doors'] = <dynamic>[' '];
      });
    });

    test('should refuse a door label that is not text', () {
      expectUnreadable((data) {
        floorOfEight(data, 2)['doors'] = <dynamic>[1];
      });
    });

    test('should refuse a door the layout lists without its entry', () {
      expectUnreadable((data) {
        (eight(data)['dwellings'] as Map<String, dynamic>).remove('A1-11');
      });
    });

    test('should refuse a door entry without its status', () {
      expectUnreadable((data) => doorEleven(data).remove('status'));
    });

    test('should refuse who changed a door without when', () {
      expectUnreadable((data) => doorEleven(data)['at'] = null);
    });

    test('should refuse a building the domain refuses', () {
      // Two floors at the same level of one staircase.
      expectUnreadable((data) {
        floorOfEight(data, 1)['floor'] = 1;
      });
    });
  });
}
