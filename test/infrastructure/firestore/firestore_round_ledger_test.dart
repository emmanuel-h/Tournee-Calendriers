// The validated tournées in Firestore, against an in-memory Firestore
// (fake_cloud_firestore, PLAN §11).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_round_ledger.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/round_document_mapper.dart';

import '../../domain/round/round_fixtures.dart';
import '../../support/results.dart';

const roundsPath = 'sectors/t49/campaigns/2026/rounds';

/// 2 houses, 10 € in cash, a calendar given for free.
final summary = newRound()
    .visited()
    .visited()
    .add(cash(1000))
    .add(offered)
    .validate(endedAt);

/// Another tournée of the 49, the next day: 1 house, 5 € by card.
final nextDay = RoundSummary(
  id: RoundId('round-2'),
  startedAt: startedAt.add(const Duration(days: 1)),
  endedAt: endedAt.add(const Duration(days: 1)),
  housesVisited: 1,
  totals: DonationTotals.of([card(500)]),
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreRoundLedger ledger;

  setUp(() {
    db = FakeFirebaseFirestore();
    ledger = FirestoreRoundLedger(db);
  });

  group('record', () {
    test('should write the summary under its round id, in its secteur and '
        'campaign', () async {
      await ledger.record(sector49Id, year2026, summary);
      await pumpEventQueue();

      final stored = await db.doc('$roundsPath/round-1').get();
      expect(stored.data(), roundToDocument(summary));
      expect(
        (await db.collection('sectors/t49/campaigns/2026/streets').get()).docs,
        isEmpty,
      );
    });

    test('should write in the campaign and secteur it is given', () async {
      final year2027 = valueOf(CampaignYear.create(2027));

      await ledger.record(SectorId('t12'), year2027, summary);
      await pumpEventQueue();

      expect(
        (await db.doc('sectors/t12/campaigns/2027/rounds/round-1').get())
            .data(),
        roundToDocument(summary),
      );
      expect((await db.collection(roundsPath).get()).docs, isEmpty);
    });

    test('should not throw when Firestore refuses the write', () async {
      whenCalling(Invocation.method(#set, null))
          .on(db.doc('$roundsPath/round-1'))
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );

      await ledger.record(sector49Id, year2026, summary);
      await pumpEventQueue();

      expect((await db.doc('$roundsPath/round-1').get()).exists, isFalse);
    });
  });

  group('watch', () {
    test('should give none when no tournée was validated', () async {
      expect(await ledger.watch(sector49Id, year2026).first, isEmpty);
    });

    test('should give the tournées of the campaign, and the next one once '
        'recorded', () async {
      await ledger.record(sector49Id, year2026, summary);
      await pumpEventQueue();
      final seen = <List<RoundSummary>>[];
      final listening = ledger.watch(sector49Id, year2026).listen(seen.add);
      await pumpEventQueue();

      await ledger.record(sector49Id, year2026, nextDay);
      await pumpEventQueue();
      await listening.cancel();

      expect(seen.first, [summary]);
      expect(seen.last, unorderedEquals([summary, nextDay]));
    });

    test(
      'should leave out the tournées of another campaign or secteur',
      () async {
        await ledger.record(sector49Id, year2026, summary);
        await ledger.record(
          sector49Id,
          valueOf(CampaignYear.create(2027)),
          nextDay,
        );
        await ledger.record(SectorId('t12'), year2026, nextDay);
        await pumpEventQueue();

        expect(await ledger.watch(sector49Id, year2026).first, [summary]);
      },
    );

    test('should leave out a document it cannot read', () async {
      await db.doc('$roundsPath/odd').set({'housesVisited': 3});
      await ledger.record(sector49Id, year2026, summary);
      await pumpEventQueue();

      expect(await ledger.watch(sector49Id, year2026).first, [summary]);
    });
  });
}
