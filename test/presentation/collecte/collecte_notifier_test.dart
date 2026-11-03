import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';

/// A ledger that cannot be read: an error other than « no longer
/// readable », which the Firestore adapter already turns into none.
final class _BrokenLedger implements RoundLedger {
  @override
  Future<void> record(SectorId s, CampaignYear c, RoundSummary r) async {}

  @override
  Stream<List<RoundSummary>> watch(SectorId s, CampaignYear c) =>
      Stream.error(StateError('unreadable'));
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
  late ProviderContainer container;

  /// A phone where [open] is the secteur shown (none when null), with the
  /// ledger [given] (the fake one by default).
  void phoneWith({SectorSummary? open, RoundLedger? given}) {
    ledger = FakeRoundLedger();
    var mine = MySectors.none.remember(sector12);
    if (open != null) mine = valueOf(mine.remember(open).open(open.id));
    store = FakeMySectorsStore(mine);
    container = ProviderContainer(
      overrides: [
        roundLedgerProvider.overrideWithValue(given ?? ledger),
        mySectorsStoreProvider.overrideWithValue(store),
        // « Mes secteurs » follows the requests of the other secteurs.
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
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
}
