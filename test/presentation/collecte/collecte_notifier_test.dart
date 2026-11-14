import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show n;

/// A ledger that cannot be read: an error other than « no longer
/// readable », which the Firestore adapter already turns into none.
final class _BrokenLedger implements RoundLedger {
  @override
  Future<LedgerAnswer> record(
    SectorId s,
    CampaignYear c,
    RoundSummary r,
  ) async => LedgerAnswer.kept;

  @override
  Stream<List<RoundSummary>> watch(SectorId s, CampaignYear c) =>
      Stream.error(StateError('unreadable'));

  @override
  Future<RoundSummary?> find(SectorId s, CampaignYear c, RoundId r) async =>
      null;

  @override
  Future<void> correct(
    SectorId s,
    CampaignYear c,
    RoundId r,
    RoundCorrected correction,
  ) async {}

  @override
  Future<void> settleForgottenHouse(
    SectorId s,
    CampaignYear c,
    RoundId r,
    ForgottenHouse settled,
  ) async {}
}

/// Saturday's tournée of the Cash mockup, 14:05 → 18:20 in Villefranche:
/// 23 houses, 10 € in cash, 20 € by cheque, a free calendar.
final saturday = RoundSummary(
  id: RoundId('sat'),
  startedAt: startedAt,
  endedAt: endedAt,
  housesVisited: 23,
  totals: DonationTotals.of([cash(1000), cheque(2000), offered]),
);

/// Friday's, the day before: 14 houses, 7,50 € by card.
final friday = RoundSummary(
  id: RoundId('fri'),
  startedAt: startedAt.subtract(const Duration(days: 1)),
  endedAt: endedAt.subtract(const Duration(days: 1)),
  housesVisited: 14,
  totals: DonationTotals.of([card(750)]),
);

void main() {
  late FakeRoundLedger ledger;
  late FakeMySectorsStore store;
  late FakeOpenRoundStore rounds;
  late FakeStreetRepository streets;
  late ProviderContainer container;

  /// A phone where [open] is the secteur shown (none when null), with the
  /// ledger [given] (the fake one by default).
  void phoneWith({
    SectorSummary? open,
    RoundLedger? given,
    List<UnsentRound> unsent = const [],
  }) {
    ledger = FakeRoundLedger();
    rounds = FakeOpenRoundStore(null, unsent);
    streets = repositoryWithLilas();
    var mine = MySectors.none.remember(sector12);
    if (open != null) mine = valueOf(mine.remember(open).open(open.id));
    store = FakeMySectorsStore(mine);
    container = ProviderContainer(
      overrides: [
        roundLedgerProvider.overrideWithValue(given ?? ledger),
        openRoundStoreProvider.overrideWithValue(rounds),
        mySectorsStoreProvider.overrideWithValue(store),
        // « Mes secteurs » follows the requests of the other secteurs.
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
        // For a forgotten house (#168).
        streetRepositoryProvider.overrideWithValue(streets),
        clockProvider.overrideWithValue(clockAtTwo()),
        identityProvider.overrideWithValue(leaOnThePhone()),
      ],
    );
    addTearDown(container.dispose);
    // `listen` keeps the auto-disposed provider alive, as a screen does.
    container.listen(collecteProvider, (_, _) {});
  }

  /// Lets the ledger's stream deliver, then reads the view.
  Future<CollecteView> settled() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(collecteProvider);
  }

  test('should be loading until the ledger answers', () {
    phoneWith(open: sector49);

    expect(container.read(collecteProvider), const CollecteLoading());
  });

  test('should show the secteur, its campaign and the tournées newest '
      'first, at the phone\'s time', () async {
    phoneWith(open: sector49);
    await ledger.record(sector49Id, year2026, friday);
    await ledger.record(sector49Id, year2026, saturday);

    final view = await settled() as CollecteShown;

    expect(view.number, 49);
    expect(view.campaign, 2026);
    expect(view.rounds, [
      CollecteRound(
        id: RoundId('sat'),
        startedAt: startedAt.toLocal(),
        endedAt: endedAt.toLocal(),
        housesVisited: 23,
        totals: saturday.totals,
      ),
      CollecteRound(
        id: RoundId('fri'),
        startedAt: friday.startedAt.toLocal(),
        endedAt: friday.endedAt.toLocal(),
        housesVisited: 14,
        totals: friday.totals,
      ),
    ]);
    expect(view.rounds.first.startedAt.isUtc, isFalse);
    expect(view.rounds.first.endedAt.isUtc, isFalse);
  });

  test('should add every tournée up, method by method', () async {
    phoneWith(open: sector49);
    await ledger.record(sector49Id, year2026, friday);
    await ledger.record(sector49Id, year2026, saturday);

    final view = await settled() as CollecteShown;

    expect(view.totals, saturday.totals + friday.totals);
    expect(view.totals.count, 3);
    expect(view.totals.cents, 3750);
    expect(view.totals.free, 1);
  });

  test('should show an empty collecte before the first tournée', () async {
    phoneWith(open: sector49);

    final view = await settled() as CollecteShown;

    expect(view.rounds, isEmpty);
    expect(view.totals, DonationTotals.none);
  });

  test('should show a tournée as soon as it is validated', () async {
    phoneWith(open: sector49);
    await settled();

    await ledger.record(sector49Id, year2026, saturday);
    final view = await settled() as CollecteShown;

    expect(view.rounds.single.id, RoundId('sat'));
  });

  test('should read only the open secteur\'s current campaign', () async {
    phoneWith(open: summaryOf('t49', 49, campaign: campaign2027));
    await ledger.record(sector49Id, year2026, saturday);
    await ledger.record(sector49Id, campaign2027, friday);
    await ledger.record(sector12.id, campaign2027, saturday);

    final view = await settled() as CollecteShown;

    expect(view.campaign, 2027);
    expect([for (final round in view.rounds) round.id], [RoundId('fri')]);
  });

  test('should show the collecte to an admin visiting the secteur', () async {
    phoneWith(open: summaryOf('t49', 49, status: MemberStatus.visiting));
    await ledger.record(sector49Id, year2026, saturday);

    final view = await settled() as CollecteShown;

    expect(view.rounds.single.id, RoundId('sat'));
  });

  test('should follow the secteur opened next', () async {
    phoneWith(open: sector49);
    await ledger.record(sector49Id, year2026, saturday);
    await ledger.record(sector12.id, year2026, friday);
    await settled();

    await container.read(mySectorsProvider.notifier).open(sector12.id);
    final view = await settled() as CollecteShown;

    expect(view.number, 12);
    expect([for (final round in view.rounds) round.id], [RoundId('fri')]);
  });

  test('should have nothing to show with no secteur open', () async {
    phoneWith();

    expect(await settled(), const CollecteUnavailable());
  });

  test(
    'should say the collecte cannot be shown when the ledger fails',
    () async {
      phoneWith(open: sector49, given: _BrokenLedger());

      expect(await settled(), const CollecteUnavailable());
    },
  );

  group('tournées not yet sent', () {
    final waiting = UnsentRound(
      sector: sector49Id,
      campaign: year2026,
      summary: saturday,
    );
    final refused = UnsentRound(
      sector: sector49Id,
      campaign: year2026,
      summary: friday,
      state: UnsentState.refused,
    );

    test('should show them apart, newest first, out of the totals', () async {
      phoneWith(open: sector49, unsent: [refused, waiting]);

      final view = await settled() as CollecteShown;

      expect(view.unsent, [
        CollecteUnsentRound(
          round: CollecteRound(
            id: RoundId('sat'),
            startedAt: startedAt.toLocal(),
            endedAt: endedAt.toLocal(),
            housesVisited: 23,
            totals: saturday.totals,
          ),
          state: UnsentState.waiting,
        ),
        CollecteUnsentRound(
          round: CollecteRound(
            id: RoundId('fri'),
            startedAt: friday.startedAt.toLocal(),
            endedAt: friday.endedAt.toLocal(),
            housesVisited: 14,
            totals: friday.totals,
          ),
          state: UnsentState.refused,
        ),
      ]);
      expect(view.rounds, isEmpty);
      expect(view.totals, DonationTotals.none);
    });

    test('should make a refused one wait again on « Réessayer »', () async {
      phoneWith(open: sector49, unsent: [refused]);
      await settled();

      await container.read(collecteProvider.notifier).retry(RoundId('fri'));
      final view = await settled() as CollecteShown;

      expect(rounds.unsent, [refused.retried()]);
      expect(view.unsent.single.state, UnsentState.waiting);
    });

    test('should forget a refused one on « Effacer »', () async {
      phoneWith(open: sector49, unsent: [refused, waiting]);
      await settled();

      await container.read(collecteProvider.notifier).erase(RoundId('fri'));
      final view = await settled() as CollecteShown;

      expect(rounds.unsent, [waiting]);
      expect(view.unsent.single.round.id, RoundId('sat'));
    });
  });

  group('corrections and forgotten houses (#168)', () {
    final correctedAt = DateTime.utc(2026, 10, 25, 9);

    /// Saturday, its dons kept, corrected by « Totaux » (one free calendar
    /// more than its list), one house left to mark.
    final corrected = RoundSummary(
      id: RoundId('sat'),
      startedAt: startedAt,
      endedAt: endedAt,
      housesVisited: 23,
      totals: DonationTotals.of([cash(1000), cheque(2000), offered, offered]),
      donations: [cash(1000), cheque(2000), offered],
      correctedAt: correctedAt,
      housesToMark: 1,
    );

    test('should show its dons newest first, its correction, its houses to '
        'mark and that its list differs', () async {
      phoneWith(open: sector49);
      ledger.have(sector49Id, year2026, corrected);

      final round = (await settled() as CollecteShown).rounds.single;

      expect(round.donations, [cash(1000), cheque(2000), offered]);
      expect(round.donationRows, [
        const DonationRow(index: 2, donation: offered),
        DonationRow(index: 1, donation: cheque(2000)),
        DonationRow(index: 0, donation: cash(1000)),
      ]);
      expect(round.listedDons, 2);
      expect(round.showsDonations, isTrue);
      expect(round.correctedAt, correctedAt.toLocal());
      expect(round.housesToMark, 1);
      expect(round.listDiffers, isTrue);
      expect(round, CollecteRound.of(corrected));
      expect(round.hashCode, CollecteRound.of(corrected).hashCode);
    });

    test('should show no dons for a tournée validated before #168, nor for '
        'an empty list', () async {
      phoneWith(open: sector49);
      ledger
        ..have(sector49Id, year2026, saturday)
        ..have(
          sector49Id,
          year2026,
          RoundSummary(
            id: RoundId('fri'),
            startedAt: friday.startedAt,
            endedAt: friday.endedAt,
            housesVisited: 2,
            totals: DonationTotals.none,
            donations: const [],
          ),
        );

      final view = await settled() as CollecteShown;

      for (final round in view.rounds) {
        expect(round.showsDonations, isFalse);
        expect(round.donationRows, isEmpty);
        expect(round.listedDons, 0);
        expect(round.listDiffers, isFalse);
        expect(round.correctedAt, isNull);
        expect(round.housesToMark, 0);
      }
      expect(view.rounds.first.donations, isNull);
      expect(view.rounds.last.donations, isEmpty);
    });

    test('should tell rounds apart by their corrections', () {
      final plain = CollecteRound.of(corrected);

      expect(plain, isNot(CollecteRound.of(saturday)));
      expect(
        plain,
        isNot(
          CollecteRound(
            id: plain.id,
            startedAt: plain.startedAt,
            endedAt: plain.endedAt,
            housesVisited: plain.housesVisited,
            totals: plain.totals,
            donations: plain.donations,
            correctedAt: plain.correctedAt,
            housesToMark: plain.housesToMark,
          ),
        ),
      );
    });

    test('should take one off the houses to mark on « Ignorer »', () async {
      phoneWith(open: sector49);
      ledger.have(sector49Id, year2026, corrected);
      await settled();

      await container
          .read(collecteProvider.notifier)
          .ignoreForgottenHouse(RoundId('sat'));
      final view = await settled() as CollecteShown;

      expect(ledger.settled, [
        (sector49Id, year2026, RoundId('sat'), ForgottenHouse.ignored),
      ]);
      expect(view.rounds.single.housesToMark, 0);
    });

    test('should mark a forgotten house, counted on the tournée', () async {
      phoneWith(open: sector49);
      ledger.have(sector49Id, year2026, corrected);
      await settled();

      final outcome = await container
          .read(collecteProvider.notifier)
          .markForgottenHouse(RoundId('sat'), street: lilasId, number: n('7'));
      final view = await settled() as CollecteShown;

      expect(outcome, ForgottenMarkOutcome.marked);
      expect(view.rounds.single.housesVisited, 24);
      expect(view.rounds.single.housesToMark, 0);
      expect(streets.saved.single.$2.streetId, lilasId);
    });

    test('should say a door already visited, a house gone, or nothing left '
        'to mark', () async {
      phoneWith(open: sector49);
      ledger.have(sector49Id, year2026, corrected);
      await settled();
      final notifier = container.read(collecteProvider.notifier);

      expect(
        await notifier.markForgottenHouse(
          RoundId('sat'),
          street: lilasId,
          number: n('8'),
          door: rdc('01'),
        ),
        ForgottenMarkOutcome.alreadyVisited,
      );
      expect(
        await notifier.markForgottenHouse(
          RoundId('sat'),
          street: lilasId,
          number: n('99'),
        ),
        ForgottenMarkOutcome.houseGone,
      );
      expect(
        await notifier.markForgottenHouse(
          RoundId('fri'),
          street: lilasId,
          number: n('7'),
        ),
        ForgottenMarkOutcome.nothingToMark,
      );
      expect(streets.saved, isEmpty);
    });

    test('should do nothing with no secteur open', () async {
      phoneWith();
      final notifier = container.read(collecteProvider.notifier);

      await notifier.ignoreForgottenHouse(RoundId('sat'));

      expect(
        await notifier.markForgottenHouse(
          RoundId('sat'),
          street: lilasId,
          number: n('7'),
        ),
        ForgottenMarkOutcome.nothingToMark,
      );
      expect(ledger.settled, isEmpty);
    });
  });
}
