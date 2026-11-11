// The shared index of the secteurs' parts in Firestore, against an
// in-memory Firestore (fake_cloud_firestore, PLAN §11).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_street_part_index.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _nationale = BanStreetId('69264_0001');
const _path = 'streetParts/69264_0001';
final _csVillefranche = valueOf(RescueCentre.create('CS Villefranche'));

FirestoreStreetPartIndex _indexOf(
  FakeFirebaseFirestore db,
  String sector,
  int number,
) => FirestoreStreetPartIndex(
  db,
  sector: SectorId(sector),
  number: valueOf(SectorNumber.create(number)),
  centre: _csVillefranche,
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreStreetPartIndex t49;
  late FirestoreStreetPartIndex t12;

  setUp(() {
    db = FakeFirebaseFirestore();
    t49 = _indexOf(db, 't49', 49);
    t12 = _indexOf(db, 't12', 12);
  });

  Future<Map<String, dynamic>?> stored() async =>
      (await db.doc(_path).get()).data();

  void refuseWrites() => whenCalling(Invocation.method(#set, null))
      .on(db.doc(_path))
      .thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

  group('hold', () {
    test(
      'should create the street\'s document with the secteur\'s entry',
      () async {
        await t12.hold(
          _nationale,
          part(odd: range(19, 41), even: SidePart.none),
        );
        await pumpEventQueue();

        expect(await stored(), {
          'sector': 't12',
          'parts': {
            't12': {
              'number': 12,
              'centreName': 'CS Villefranche',
              'odd': [19, 41],
              'even': 'none',
            },
          },
        });
      },
    );

    test(
      'should keep the other secteurs\' entries, and replace its own',
      () async {
        await t12.hold(
          _nationale,
          part(odd: range(19, 41), even: SidePart.none),
        );
        await t49.hold(_nationale, StreetPart.whole);
        await t49.hold(_nationale, part(odd: SidePart.none, even: range(2, 8)));
        await pumpEventQueue();

        final document = (await stored())!;
        expect(document['sector'], 't49');
        expect((document['parts'] as Map)['t12'], {
          'number': 12,
          'centreName': 'CS Villefranche',
          'odd': [19, 41],
          'even': 'none',
        });
        expect((document['parts'] as Map)['t49'], {
          'number': 49,
          'centreName': 'CS Villefranche',
          'odd': 'none',
          'even': [2, 8],
        });
      },
    );

    test('should fail, for its caller to report it, when Firestore '
        'refuses the write', () async {
      refuseWrites();

      await expectLater(
        t49.hold(_nationale, StreetPart.whole),
        throwsA(isA<FirebaseException>()),
      );

      expect(await stored(), isNull);
    });
  });

  group('release', () {
    test('should remove only the secteur\'s entry', () async {
      await t12.hold(_nationale, StreetPart.whole);
      await t49.hold(_nationale, StreetPart.whole);
      await t49.release(_nationale);
      await pumpEventQueue();

      final document = (await stored())!;
      expect(document['sector'], 't49');
      expect((document['parts'] as Map).keys, ['t12']);
    });

    test('should leave the document there once its last entry goes', () async {
      await t49.hold(_nationale, StreetPart.whole);
      await t49.release(_nationale);
      await pumpEventQueue();

      expect(await stored(), {'sector': 't49', 'parts': <String, Object?>{}});
    });

    test('should release the entry of the secteur it is given', () async {
      await t12.hold(_nationale, StreetPart.whole);
      await releaseStreetPart(db, SectorId('t12'), _nationale);

      expect((await stored())!['parts'], isEmpty);
    });

    test('should fail, for its caller to report it, when Firestore '
        'refuses the write', () async {
      await t49.hold(_nationale, StreetPart.whole);
      refuseWrites();

      await expectLater(
        t49.release(_nationale),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(
        releaseStreetPart(db, SectorId('t49'), _nationale),
        throwsA(isA<FirebaseException>()),
      );

      expect((await stored())!['parts'], contains('t49'));
    });
  });

  group('othersOf', () {
    test('should give the other secteurs\' parts, not its own', () async {
      await t12.hold(_nationale, part(odd: range(19, 41), even: SidePart.none));
      await t49.hold(_nationale, StreetPart.whole);
      await pumpEventQueue();

      expect(await t49.othersOf(_nationale), [
        SectorPart(
          sector: valueOf(SectorNumber.create(12)),
          centre: _csVillefranche,
          part: part(odd: range(19, 41), even: SidePart.none),
        ),
      ]);
      expect(
        (await t12.othersOf(_nationale)).map((other) => other.sector.value),
        [49],
      );
    });

    test('should give none for a street no secteur holds', () async {
      expect(await t49.othersOf(_nationale), isEmpty);
    });

    test('should give none when the index cannot be read', () async {
      whenCalling(Invocation.method(#get, null))
          .on(db.doc(_path))
          .thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          );

      expect(await t49.othersOf(_nationale), isEmpty);
    });
  });
}
