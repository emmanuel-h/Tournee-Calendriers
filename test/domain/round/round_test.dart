import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

import '../../support/results.dart';
import 'round_fixtures.dart';

void main() {
  test('should start with no house visited and no don', () {
    final round = newRound();

    expect(round.id, roundId);
    expect(round.sector, sector49Id);
    expect(round.campaign, year2026);
    expect(round.startedAt, startedAt);
    expect(round.housesVisited, 0);
    expect(round.donations, isEmpty);
    expect(round.totals, DonationTotals.none);
  });

  group('dons', () {
    test('should keep the dons in the order added', () {
      final round = newRound().add(cash(1000)).add(offered).add(cheque(2000));

      expect(round.donations, [cash(1000), offered, cheque(2000)]);
    });

    test('should add the dons up', () {
      final round = newRound().add(cash(1000)).add(offered).add(cash(750));

      expect(round.totals, DonationTotals.of([cash(1000), offered, cash(750)]));
      expect(round.totals.count, 2);
      expect(round.totals.cents, 1750);
      expect(round.totals.free, 1);
    });

    test('should not let a caller change the list', () {
      final round = newRound().add(cash(1000));

      expect(() => round.donations.add(offered), throwsUnsupportedError);
    });

    test('should replace the don at an index', () {
      final round = newRound().add(cash(1000)).add(cheque(2000));

      final changed = valueOf(round.replace(1, card(500)));

      expect(changed.donations, [cash(1000), card(500)]);
      expect(round.donations, [cash(1000), cheque(2000)]);
    });

    test('should remove the don at an index', () {
      final round = newRound().add(cash(1000)).add(offered).add(card(500));

      final changed = valueOf(round.remove(1));

      expect(changed.donations, [cash(1000), card(500)]);
    });

    test('should replace or remove the first and the last don', () {
      final round = newRound().add(cash(1000)).add(cheque(2000));

      expect(valueOf(round.replace(0, offered)).donations, [
        offered,
        cheque(2000),
      ]);
      expect(valueOf(round.remove(0)).donations, [cheque(2000)]);
      expect(valueOf(round.remove(1)).donations, [cash(1000)]);
    });

    test('should refuse an index past the dons', () {
      final round = newRound().add(cash(1000)).add(cheque(2000));

      expect(failureOf(round.replace(2, offered)), const NoSuchDonation());
      expect(failureOf(round.replace(-1, offered)), const NoSuchDonation());
      expect(failureOf(round.remove(2)), const NoSuchDonation());
      expect(failureOf(round.remove(-1)), const NoSuchDonation());
    });

    test('should name a missing don', () {
      // Built at run time: a `const` one would never run the constructor.
      // ignore: prefer_const_constructors
      final missing = NoSuchDonation();

      expect(missing.hashCode, const NoSuchDonation().hashCode);
      expect(missing, isNot(offered));
      expect(missing.toString(), 'NoSuchDonation');
    });

    test('should keep the houses visited across dons', () {
      final round = newRound().visited().add(cash(1000));

      expect(valueOf(round.replace(0, offered)).housesVisited, 1);
      expect(valueOf(round.remove(0)).housesVisited, 1);
    });
  });

  group('houses visited', () {
    test('should count one more house visited', () {
      final round = newRound().visited().visited();

      expect(round.housesVisited, 2);
    });

    test('should count one less house when one is undone', () {
      final round = newRound().visited().visited().unvisited();

      expect(round.housesVisited, 1);
    });

    test('should never count below no house', () {
      final round = newRound().visited().unvisited().unvisited();

      expect(round.housesVisited, 0);
    });

    test('should keep the dons across houses', () {
      final round = newRound().add(cash(1000)).visited().visited().unvisited();

      expect(round.donations, [cash(1000)]);
      expect(round.id, roundId);
      expect(round.sector, sector49Id);
      expect(round.campaign, year2026);
      expect(round.startedAt, startedAt);
    });
  });

  group('validate', () {
    test('should sum the tournée up, without its dons, waiting to be sent to its secteur', () {
      final round = newRound()
          .add(cash(1000))
          .add(offered)
          .add(cheque(2000))
          .visited()
          .visited();

      final validated = round.validate(endedAt);

      expect(validated.state, UnsentState.waiting);
      expect(validated.sector, sector49Id);
      expect(validated.campaign, year2026);
      expect(
        validated.summary,
        RoundSummary(
          id: roundId,
          startedAt: startedAt,
          endedAt: endedAt,
          housesVisited: 2,
          totals: DonationTotals.of([cash(1000), offered, cheque(2000)]),
        ),
      );
    });

    test('should end at least one second after it started', () {
      final round = newRound();
      final oneSecondIn = startedAt.add(const Duration(seconds: 1));

      expect(round.validate(startedAt).summary.endedAt, oneSecondIn);
      expect(
        round
            .validate(startedAt.subtract(const Duration(hours: 1)))
            .summary
            .endedAt,
        oneSecondIn,
      );
      expect(round.validate(oneSecondIn).summary.endedAt, oneSecondIn);
      final twoSecondsIn = startedAt.add(const Duration(seconds: 2));
      expect(round.validate(twoSecondsIn).summary.endedAt, twoSecondsIn);
    });
  });

  group('restore', () {
    test('should give back the tournée the phone kept', () {
      final round = Round.restore(
        id: roundId,
        sector: sector49Id,
        campaign: year2026,
        startedAt: startedAt,
        housesVisited: 3,
        donations: [cash(1000), offered],
      );

      expect(
        round,
        newRound().visited().visited().visited().add(cash(1000)).add(offered),
      );
    });

    test('should refuse a negative count of houses', () {
      Round restoring(int housesVisited) => Round.restore(
        id: roundId,
        sector: sector49Id,
        campaign: year2026,
        startedAt: startedAt,
        housesVisited: housesVisited,
        donations: const [],
      );

      expect(() => restoring(-1), throwsArgumentError);
      expect(restoring(0).housesVisited, 0);
    });
  });

  test('should equal a tournée of the same values only', () {
    final round = newRound().visited().add(cash(1000));
    final same = newRound().visited().add(cash(1000));

    expect(round, same);
    expect(round.hashCode, same.hashCode);
    expect(round, isNot(newRound().add(cash(1000))));
    expect(round, isNot(newRound().visited().add(cash(1001))));
    expect(round, isNot(newRound().visited()));
    expect(
      round,
      isNot(
        Round.start(
          id: RoundId('round-2'),
          sector: sector49Id,
          campaign: year2026,
          at: startedAt,
        ).visited().add(cash(1000)),
      ),
    );
    expect(
      round,
      isNot(
        Round.start(
          id: roundId,
          sector: SectorId('t12'),
          campaign: year2026,
          at: startedAt,
        ).visited().add(cash(1000)),
      ),
    );
    expect(
      round,
      isNot(
        Round.start(
          id: roundId,
          sector: sector49Id,
          campaign: valueOf(CampaignYear.create(2027)),
          at: startedAt,
        ).visited().add(cash(1000)),
      ),
    );
    expect(
      round,
      isNot(
        Round.start(
          id: roundId,
          sector: sector49Id,
          campaign: year2026,
          at: endedAt,
        ).visited().add(cash(1000)),
      ),
    );
    expect(
      round.toString(),
      'Round(round-1, t49, 2026, 2026-10-24 12:05:00.000Z, 1 houses, '
      '[PaidDonation(cash, 1000)])',
    );
  });
}
