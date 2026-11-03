import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show lea;

/// The 49's tournée with, in the order added, 10 € in cash, a free
/// calendar and 20 € by cheque; 3 houses visited.
Round _threeDons() => Round.restore(
  id: roundId,
  sector: sector49Id,
  campaign: year2026,
  startedAt: startedAt,
  housesVisited: 3,
  donations: [cash(1000), offered, cheque(2000)],
);

void main() {
  late FakeOpenRoundStore rounds;
  late FakeRoundLedger ledger;
  late FakeClock clock;
  late ProviderContainer container;

  /// A phone where [open] is the secteur shown (none when null), with
  /// [round] on; the clock reads [endedAt].
  void phoneWith({
    SectorSummary? open,
    Round? round,
    List<SectorSummary>? also,
  }) {
    rounds = FakeOpenRoundStore(round);
    ledger = FakeRoundLedger();
    clock = FakeClock(endedAt);
    var mine = MySectors.none;
    for (final sector in [?open, ...?also]) {
      mine = mine.remember(sector);
    }
    if (open != null) mine = valueOf(mine.open(open.id));
    container = ProviderContainer(
      overrides: [
        openRoundStoreProvider.overrideWithValue(rounds),
        roundLedgerProvider.overrideWithValue(ledger),
        clockProvider.overrideWithValue(clock),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('round')),
        mySectorsStoreProvider.overrideWithValue(FakeMySectorsStore(mine)),
        // « Mes secteurs » follows the requests of the other secteurs.
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
        // A don of « Nouveau don » names no house; `AddDonation` is still
        // built with the streets it gives a calendar to otherwise.
        streetRepositoryProvider.overrideWithValue(FakeStreetRepository()),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
      ],
    );
    addTearDown(container.dispose);
    // `listen` keeps the auto-disposed provider alive, as a screen does.
    container.listen(roundProvider, (_, _) {});
  }

  /// Lets the tournée's stream deliver, then reads the view.
  Future<RoundView> settled() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(roundProvider);
  }

  RoundNotifier notifier() => container.read(roundProvider.notifier);

  test('should show nothing when the tournée is not read yet', () {
    phoneWith(open: sector49);

    expect(container.read(roundProvider), const RoundLoading());
  });

  group('no tournée on', () {
    test('should offer to start one when the member is in the team of the '
        'open secteur', () async {
      phoneWith(open: sector49);

      expect(await settled(), const RoundOff(canStart: true));
    });

    test('should not offer it when an admin visits the open secteur', () async {
      phoneWith(open: sector12Visited);

      expect(await settled(), const RoundOff(canStart: false));
    });

    test('should not offer it when no secteur is open', () async {
      phoneWith();

      expect(await settled(), const RoundOff(canStart: false));
    });

    test('should not show the tournée of another secteur', () async {
      phoneWith(open: sector12, round: _threeDons(), also: [sector49]);

      expect(await settled(), const RoundOff(canStart: true));
    });
  });

  group('a tournée on', () {
    test('should show its start, the time now, the houses visited, the '
        'totals and the dons newest first, each with its place in the order '
        'added', () async {
      phoneWith(open: sector49, round: _threeDons());

      final view = await settled() as RoundOn;

      expect(view.startedAt, startedAt.toLocal());
      expect(view.startedAt.isUtc, isFalse);
      expect(view.now, endedAt.toLocal());
      expect(view.now.isUtc, isFalse);
      expect(view.housesVisited, 3);
      expect(
        view.totals,
        DonationTotals.of([cash(1000), offered, cheque(2000)]),
      );
      expect(view.donations, [
        DonationRow(index: 2, donation: cheque(2000)),
        const DonationRow(index: 1, donation: offered),
        DonationRow(index: 0, donation: cash(1000)),
      ]);
    });

    test('should say how long it has been on', () async {
      phoneWith(open: sector49, round: _threeDons());

      final view = await settled() as RoundOn;

      expect(view.elapsed, const Duration(hours: 4, minutes: 15));
    });

    test(
      'should say it has just started when the clock was set back',
      () async {
        phoneWith(open: sector49, round: _threeDons());
        await settled();
        clock.time = startedAt.subtract(const Duration(minutes: 5));
        notifier().tick();

        final view = container.read(roundProvider) as RoundOn;

        expect(view.elapsed, Duration.zero);
      },
    );

    test('should read the clock again on a tick', () async {
      phoneWith(open: sector49, round: _threeDons());
      await settled();
      clock.time = endedAt.add(const Duration(minutes: 1));

      notifier().tick();

      final view = container.read(roundProvider) as RoundOn;
      expect(view.now, endedAt.add(const Duration(minutes: 1)).toLocal());
    });

    test('should show a don added at the top of the list', () async {
      phoneWith(open: sector49, round: _threeDons());
      await settled();

      await notifier().addDonation(card(500));

      final view = container.read(roundProvider) as RoundOn;
      expect(view.donations.first, DonationRow(index: 3, donation: card(500)));
      expect(view.donations.length, 4);
    });
  });

  group('intents', () {
    test('should say it was refused when an admin visits the open '
        'secteur', () async {
      phoneWith(open: sector12Visited);
      await settled();

      expect(await notifier().start(), StartOutcome.refused);
      expect(rounds.saves, isEmpty);
    });

    test('should say it was refused when no secteur is open', () async {
      phoneWith();
      await settled();

      expect(await notifier().start(), StartOutcome.refused);
    });

    test('should start a tournée of the open secteur', () async {
      phoneWith(open: sector49);
      await settled();

      expect(await notifier().start(), StartOutcome.started);

      final view = container.read(roundProvider) as RoundOn;
      expect(view.startedAt, endedAt.toLocal());
      expect(view.donations, isEmpty);
      expect(rounds.openRound!.id, RoundId('round-1'));
    });

    test('should say why it cannot start when one is on in another '
        'secteur', () async {
      phoneWith(open: sector12, round: _threeDons(), also: [sector49]);
      await settled();

      expect(await notifier().start(), StartOutcome.alreadyOnElsewhere);
      expect(rounds.saves, isEmpty);
    });

    test('should change the don at its place in the order added', () async {
      phoneWith(open: sector49, round: _threeDons());
      await settled();

      await notifier().changeDonation(0, card(1500));

      expect(rounds.openRound!.donations, [card(1500), offered, cheque(2000)]);
    });

    test('should remove the don at its place in the order added', () async {
      phoneWith(open: sector49, round: _threeDons());
      await settled();

      await notifier().removeDonation(1);

      expect(rounds.openRound!.donations, [cash(1000), cheque(2000)]);
    });

    test('should change the don of the row shown when one row is tapped in '
        'the list shown newest first', () async {
      phoneWith(open: sector49, round: _threeDons());
      final view = await settled() as RoundOn;
      // The last row shown is the first don added: 10 € in cash.
      final row = view.donations.last;

      await notifier().changeDonation(row.index, cash(1200));

      expect(rounds.openRound!.donations, [cash(1200), offered, cheque(2000)]);
    });

    test('should validate the tournée: its summary recorded, the tournée '
        'gone', () async {
      phoneWith(open: sector49, round: _threeDons());
      await settled();

      await notifier().validate();

      final (sector, _, summary) = ledger.recorded.single;
      expect(sector, sector49Id);
      expect(summary.endedAt, endedAt);
      expect(summary.housesVisited, 3);
      expect(rounds.openRound, isNull);
      expect(container.read(roundProvider), const RoundOff(canStart: true));
    });
  });

  test('should follow the tournée of the secteur opened next', () async {
    phoneWith(open: sector12, round: _threeDons(), also: [sector49]);
    await settled();

    await container.read(mySectorsProvider.notifier).open(sector49.id);

    expect(await settled(), isA<RoundOn>());
  });
}
