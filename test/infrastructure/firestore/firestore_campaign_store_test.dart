// What an admin's phone writes to start a new campaign (#39, PLAN §5.10),
// against an in-memory Firestore (fake_cloud_firestore, PLAN §11). What
// the security rules accept of it is tested in the emulator
// (firebase/test/campaigns.test.mjs).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/application/ports/campaign_store.dart';
import 'package:tournee_calendriers/domain/sector/campaign_retention.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_campaign_store.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/sector_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart' show campaign2027;
import '../../domain/sector/sector_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

CampaignYear _year(int value) => valueOf(CampaignYear.create(value));

/// Rue Gambetta, in the Corbeille since Paul deleted it.
final _gambetta = valueOf(
  Street.create(
    id: StreetId('rue-gambetta'),
    name: 'Rue Gambetta',
    commune: villefranche,
    houses: [seven],
    deletion: ChangeStamp(by: paul, at: threePm),
  ),
);

/// A street of the 49 named [id], with one number to do.
Street _street(String id) => valueOf(
  Street.create(
    id: StreetId(id),
    name: 'Rue $id',
    commune: villefranche,
    houses: [seven],
  ),
);

const _streets2026 = 'sectors/t49/campaigns/2026/streets';
const _streets2027 = 'sectors/t49/campaigns/2027/streets';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreCampaignStore store;

  setUp(() async {
    db = FakeFirebaseFirestore();
    store = FirestoreCampaignStore(db);
    await db.doc('sectors/t49').set(sectorToDocument(team()));
    await db.doc('joinCodes/K7P2QX').set(joinCodeDocument(team()));
    await db
        .doc('sectors/t49/campaigns/2026')
        .set(firstCampaignDocument(team()));
  });

  Future<Map<String, dynamic>?> stored(String path) async =>
      (await db.doc(path).get()).data();

  Future<List<String>> idsIn(String collection) async => [
    for (final doc in (await db.collection(collection).get()).docs) doc.id,
  ];

  void failing(Object reference, String code) {
    whenCalling(Invocation.method(#get, null))
        .on(reference)
        .thenThrow(firestoreError(code));
  }

  /// Each way the server may fail a step, and what the step says of it.
  const answers = [
    ('unavailable', CampaignFailure.noNetwork),
    ('deadline-exceeded', CampaignFailure.noNetwork),
    ('permission-denied', CampaignFailure.notAdmin),
  ];

  group('streetsOf', () {
    setUp(() async {
      await db.doc('$_streets2026/rue-des-lilas').set(streetToDocument(lilas));
      await db
          .doc('$_streets2026/rue-gambetta')
          .set(streetToDocument(_gambetta));
      // Unreadable (#149): no commune, no houses.
      await db.doc('$_streets2026/rue-pasteur').set({'name': 'Rue Pasteur'});
      await db
          .doc('sectors/t49/campaigns/2025/streets/rue-ancienne')
          .set(streetToDocument(_street('rue-ancienne')));
    });

    test('should read every street of the campaign, those of the Corbeille '
        'too, and leave out the unreadable ones', () async {
      final streets = valueOf(await store.streetsOf(sectorId, campaign2026));

      expect(
        [for (final street in streets) street.id.value],
        ['rue-des-lilas', 'rue-gambetta'],
      );
      expect(streets.first.houses, lilas.houses);
      expect(streets.last.isDeleted, isTrue);
    });
  });

  group('writeCopies', () {
    final copy = lilas.forNextCampaign()!;

    test('should write the new campaign, copied from the year left, with '
        'each copy whole', () async {
      valueOf(
        await store.writeCopies(
          sectorId,
          from: campaign2026,
          to: campaign2027,
          streets: [copy],
        ),
      );

      final campaign = (await stored('sectors/t49/campaigns/2027'))!;
      expect(campaign['previousYear'], 2026);
      expect(campaign['startedAt'], isA<Timestamp>());
      expect(
        await stored('$_streets2027/rue-des-lilas'),
        streetToDocument(copy),
      );
    });

    test('should write every copy, more than a batch holds', () async {
      final streets = [
        for (var i = 0; i <= FirestoreCampaignStore.copiesPerBatch; i++)
          _street('s$i'),
      ];

      valueOf(
        await store.writeCopies(
          sectorId,
          from: campaign2026,
          to: campaign2027,
          streets: streets,
        ),
      );

      expect(await idsIn(_streets2027), hasLength(16));
      expect(await stored('$_streets2027/s15'), streetToDocument(streets[15]));
    });

    test('should write the campaign of a secteur without street', () async {
      valueOf(
        await store.writeCopies(
          sectorId,
          from: _year(2025),
          to: campaign2027,
          streets: const [],
        ),
      );

      expect(
        (await stored('sectors/t49/campaigns/2027'))!['previousYear'],
        2025,
      );
      expect(await idsIn(_streets2027), isEmpty);
    });

    test('should keep the campaign an earlier try wrote, write the copies '
        'again and delete those no longer to copy', () async {
      final earlier = {
        'startedAt': Timestamp.fromDate(createdAt),
        'previousYear': 2026,
      };
      await db.doc('sectors/t49/campaigns/2027').set(earlier);
      await db.doc('$_streets2027/rue-des-lilas').set(streetToDocument(lilas));
      await db
          .doc('$_streets2027/rue-gambetta')
          .set(streetToDocument(_street('rue-gambetta')));

      valueOf(
        await store.writeCopies(
          sectorId,
          from: campaign2026,
          to: campaign2027,
          streets: [copy],
        ),
      );

      expect(await stored('sectors/t49/campaigns/2027'), earlier);
      expect(
        await stored('$_streets2027/rue-des-lilas'),
        streetToDocument(copy),
      );
      expect(await idsIn(_streets2027), ['rue-des-lilas']);
    });

    for (final (code, failure) in answers) {
      test('should write nothing and fail with ${failure.name} when the '
          'server answers $code', () async {
        failing(db.doc('sectors/t49/campaigns/2027'), code);

        final written = await store.writeCopies(
          sectorId,
          from: campaign2026,
          to: campaign2027,
          streets: [copy],
        );

        expect(failureOf(written), failure);
        expect(await idsIn(_streets2027), isEmpty);
      });
    }
  });

  group('switchTo', () {
    test('should move the secteur and its join preview to the year', () async {
      valueOf(await store.switchTo(sectorId, campaign2027));

      expect((await stored('sectors/t49'))!['currentCampaign'], 2027);
      expect((await stored('joinCodes/K7P2QX'))!['campaign'], 2027);
      expect((await stored('sectors/t49'))!['number'], 49);
      expect((await stored('joinCodes/K7P2QX'))!['number'], 49);
    });

    test(
      'should leave a secteur another admin moved there or further',
      () async {
        await db.doc('sectors/t49').update({'currentCampaign': 2028});

        valueOf(await store.switchTo(sectorId, campaign2027));

        expect((await stored('sectors/t49'))!['currentCampaign'], 2028);
        expect((await stored('joinCodes/K7P2QX'))!['campaign'], 2026);
      },
    );

    test('should leave a secteur already on the year', () async {
      await db.doc('sectors/t49').update({'currentCampaign': 2027});

      valueOf(await store.switchTo(sectorId, campaign2027));

      expect((await stored('joinCodes/K7P2QX'))!['campaign'], 2026);
    });

    test('should write nothing for a secteur deleted meanwhile', () async {
      await db.doc('sectors/t49').delete();

      valueOf(await store.switchTo(sectorId, campaign2027));

      expect(await stored('sectors/t49'), isNull);
      expect((await stored('joinCodes/K7P2QX'))!['campaign'], 2026);
    });

    for (final (code, failure) in answers) {
      test('should fail with ${failure.name} when the server answers '
          '$code', () async {
        failing(db.doc('sectors/t49'), code);

        expect(
          failureOf(await store.switchTo(sectorId, campaign2027)),
          failure,
        );
      });
    }

    test('should throw any other failure of the server', () async {
      failing(db.doc('sectors/t49'), 'internal');

      await expectLater(
        store.switchTo(sectorId, campaign2027),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('campaignFailureOf', () {
    // Every step goes through it; the steps that only list collections
    // cannot be made to fail in fake_cloud_firestore, whose collections
    // are new objects at each call.
    for (final (code, failure) in answers) {
      test('should read $code as ${failure.name}', () {
        expect(campaignFailureOf(firestoreError(code)), failure);
      });
    }

    test('should read any other failure as none the user can act on', () {
      expect(campaignFailureOf(firestoreError('internal')), isNull);
    });
  });

  group('campaignsOf', () {
    test('should tell each campaign held and whether it had a validated '
        'tournée', () async {
      await db.doc('sectors/t49/campaigns/2025').set({'previousYear': null});
      await db.doc('sectors/t49/campaigns/2025/rounds/r1').set({'free': 1});
      await db.doc('sectors/t49/campaigns/2025/rounds/r2').set({'free': 2});
      // Not a year: left out.
      await db.doc('sectors/t49/campaigns/next').set({'previousYear': null});

      final records = valueOf(await store.campaignsOf(sectorId));

      expect(
        records,
        unorderedEquals([
          CampaignRecord(year: _year(2025), hasValidatedRound: true),
          CampaignRecord(year: campaign2026, hasValidatedRound: false),
        ]),
      );
    });
  });

  group('delete', () {
    setUp(() async {
      for (final year in [2024, 2025]) {
        await db.doc('sectors/t49/campaigns/$year').set({'previousYear': null});
        await db
            .doc('sectors/t49/campaigns/$year/streets/rue-des-lilas')
            .set(streetToDocument(lilas));
        await db.doc('sectors/t49/campaigns/$year/rounds/r1').set({'free': 1});
      }
      await db.doc('$_streets2026/rue-des-lilas').set(streetToDocument(lilas));
    });

    test('should delete the streets, the tournées and the campaign of each '
        'year, and nothing else', () async {
      valueOf(await store.delete(sectorId, {_year(2024), _year(2025)}));

      expect(await idsIn('sectors/t49/campaigns'), ['2026']);
      for (final year in [2024, 2025]) {
        expect(await idsIn('sectors/t49/campaigns/$year/streets'), isEmpty);
        expect(await idsIn('sectors/t49/campaigns/$year/rounds'), isEmpty);
      }
      expect(await idsIn(_streets2026), ['rue-des-lilas']);
    });

    test('should delete more documents than a batch holds', () async {
      final batch = db.batch();
      for (var i = 0; i < FirestoreCampaignStore.writesPerBatch; i++) {
        batch.set(db.doc('sectors/t49/campaigns/2025/streets/s$i'), {
          'name': 'Rue $i',
        });
      }
      await batch.commit();

      valueOf(await store.delete(sectorId, {_year(2025)}));

      expect(await idsIn('sectors/t49/campaigns/2025/streets'), isEmpty);
      expect(await stored('sectors/t49/campaigns/2025'), isNull);
    });
  });
}
