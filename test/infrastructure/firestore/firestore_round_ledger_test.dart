// The validated tournées in Firestore, against an in-memory Firestore
// (fake_cloud_firestore, PLAN §11).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
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
    .validate(endedAt)
    .summary;

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
        'campaign, and say the server keeps it', () async {
      final answer = await ledger.record(sector49Id, year2026, summary);

      final stored = await db.doc('$roundsPath/round-1').get();
      expect(answer, LedgerAnswer.kept);
      expect(stored.data(), roundToDocument(summary));
      expect(
        (await db.collection('sectors/t49/campaigns/2026/streets').get()).docs,
        isEmpty,
      );
    });

    test('should write in the campaign and secteur it is given', () async {
      final year2027 = valueOf(CampaignYear.create(2027));

      await ledger.record(SectorId('t12'), year2027, summary);

      expect(
        (await db.doc('sectors/t12/campaigns/2027/rounds/round-1').get())
            .data(),
        roundToDocument(summary),
      );
      expect((await db.collection(roundsPath).get()).docs, isEmpty);
    });

    test('should keep, without writing it again, a summary the server '
        'already has (sent before a kill)', () async {
      // What the server has: written by the earlier try.
      final earlier = {...roundToDocument(summary), 'housesVisited': 99};
      await db.doc('$roundsPath/round-1').set(earlier);
      whenCalling(Invocation.method(#set, null))
          .on(db.doc('$roundsPath/round-1'))
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );

      final answer = await ledger.record(sector49Id, year2026, summary);

      expect(answer, LedgerAnswer.kept);
      expect((await db.doc('$roundsPath/round-1').get()).data(), earlier);
    });

    test('should say refused when Firestore refuses the write', () async {
      whenCalling(Invocation.method(#set, null))
          .on(db.doc('$roundsPath/round-1'))
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );

      final answer = await ledger.record(sector49Id, year2026, summary);

      expect(answer, LedgerAnswer.refused);
      expect((await db.doc('$roundsPath/round-1').get()).exists, isFalse);
    });
  });

  group('isServerWord', () {
    test('should take only a snapshot from the server with nothing of this '
        'phone waiting', () {
      expect(
        isServerWord(const _Metadata(cache: false, pending: false)),
        isTrue,
      );
      expect(
        isServerWord(const _Metadata(cache: true, pending: false)),
        isFalse,
      );
      expect(
        isServerWord(const _Metadata(cache: false, pending: true)),
        isFalse,
      );
      expect(
        isServerWord(const _Metadata(cache: true, pending: true)),
        isFalse,
      );
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

/// Where a snapshot comes from, as Firestore tells it.
final class _Metadata implements SnapshotMetadata {
  const _Metadata({required this.cache, required this.pending});

  final bool cache;
  final bool pending;

  @override
  bool get isFromCache => cache;

  @override
  bool get hasPendingWrites => pending;
}
