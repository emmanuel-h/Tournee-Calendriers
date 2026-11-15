import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_origin.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/donations_taken_out.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'round_fixtures.dart';

final _lilas = StreetId('rue-des-lilas');
final _three = DonationOrigin(street: _lilas, number: n('3'));
final _nine = DonationOrigin(street: _lilas, number: n('9'));
final _door51 = DonationOrigin(
  street: _lilas,
  number: n('8'),
  door: DwellingKey(escA, 5, d('51')),
);

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

  group('dons noted from a house (#169)', () {
    test('should link a don to the house it was noted from, and none to a '
        'don given without a house', () {
      final round = newRound()
          .add(cash(2000), from: _three)
          .add(cheque(500))
          .add(offered, from: _door51);

      expect(round.donations, [cash(2000), cheque(500), offered]);
      expect(round.origins, [_three, null, _door51]);
      expect(newRound().origins, isEmpty);
    });

    test('should keep the link when the don is changed, and drop it with '
        'the don removed', () {
      final round = newRound().add(cash(2000), from: _three).add(card(500));

      expect(valueOf(round.replace(0, cheque(1500))).origins, [_three, null]);
      expect(valueOf(round.remove(0)).origins, [null]);
      expect(valueOf(round.remove(1)).origins, [_three]);
    });

    test('should not let a caller change the links', () {
      final round = newRound().add(cash(2000), from: _three);

      expect(() => round.origins.add(null), throwsUnsupportedError);
    });

    test('should take out only the dons of that house, with their places', () {
      final round = newRound()
          .visited()
          .add(cash(1000), from: _nine)
          .add(card(2000), from: _three)
          .add(cheque(500), from: _nine)
          .add(offered);

      final (changed, taken) = round.takeOut(_nine);

      expect(changed.donations, [card(2000), offered]);
      expect(changed.origins, [_three, null]);
      expect(changed.housesVisited, 1);
      expect(changed.id, roundId);
      expect(taken.round, roundId);
      expect(taken.origin, _nine);
      expect(taken.taken, [
        (index: 0, donation: cash(1000)),
        (index: 2, donation: cheque(500)),
      ]);
      expect(taken.donations, [cash(1000), cheque(500)]);
      expect(taken.isEmpty, isFalse);
    });

    test('should take out a door\'s dons apart from its building\'s', () {
      final building = DonationOrigin(street: _lilas, number: n('8'));
      final round = newRound()
          .add(cash(1000), from: building)
          .add(cash(500), from: _door51);

      final (changed, taken) = round.takeOut(_door51);

      expect(changed.donations, [cash(1000)]);
      expect(taken.donations, [cash(500)]);
    });

    test('should take out nothing from a house with no don linked', () {
      final round = newRound().add(cash(1000)).add(cash(500), from: _three);

      final (changed, taken) = round.takeOut(_nine);

      expect(changed, same(round));
      expect(taken.isEmpty, isTrue);
      expect(taken.taken, isEmpty);
      expect(taken.origin, _nine);
    });

    test('should put the dons back at their places, linked again', () {
      final round = newRound()
          .add(cash(1000), from: _nine)
          .add(card(2000), from: _three)
          .add(cheque(500), from: _nine)
          .add(offered);
      final (out, taken) = round.takeOut(_nine);

      expect(out.putBack(taken), round);
    });

    test('should put a don last when its place is past the end', () {
      final round = newRound()
          .add(card(2000))
          .add(cash(1000), from: _nine)
          .add(offered);
      final (out, taken) = round.takeOut(_nine);
      final fewer = valueOf(valueOf(out.remove(1)).remove(0));

      final back = fewer.putBack(taken);

      expect(back.donations, [cash(1000)]);
      expect(back.origins, [_nine]);
      expect(valueOf(out.remove(1)).putBack(taken).donations, [
        card(2000),
        cash(1000),
      ]);
    });

    test('should put back nothing taken out of another tournée', () {
      final (_, taken) = newRound().add(cash(1000), from: _nine).takeOut(_nine);
      final other = Round.start(
        id: RoundId('round-2'),
        sector: sector49Id,
        campaign: year2026,
        at: startedAt,
      ).add(card(500));

      expect(other.putBack(taken), same(other));
    });

    test('should put back nothing when nothing was taken out', () {
      final round = newRound().add(cash(1000));
      final (_, nothing) = round.takeOut(_nine);

      expect(round.putBack(nothing), same(round));
    });

    test('should send no link: the summary\'s dons name no house', () {
      final round = newRound().add(cash(2000), from: _three).add(offered);

      expect(round.validate(endedAt).summary.donations, [cash(2000), offered]);
    });

    test('should tell a tournée apart by its links', () {
      final linked = newRound().add(cash(2000), from: _three);

      expect(linked, isNot(newRound().add(cash(2000))));
      expect(linked, isNot(newRound().add(cash(2000), from: _nine)));
      expect(linked, newRound().add(cash(2000), from: _three));
      expect(
        linked.hashCode,
        newRound().add(cash(2000), from: _three).hashCode,
      );
    });
  });

  group('dons taken out', () {
    DonationsTakenOut takenOut({
      RoundId? round,
      DonationOrigin? origin,
      int index = 0,
    }) => DonationsTakenOut(
      round: round ?? roundId,
      origin: origin ?? _three,
      taken: [(index: index, donation: cash(2000))],
    );

    test('should equal the same dons of the same house and tournée only', () {
      expect(takenOut(), takenOut());
      expect(takenOut().hashCode, takenOut().hashCode);
      expect(takenOut(), isNot(takenOut(round: RoundId('round-2'))));
      expect(takenOut(), isNot(takenOut(origin: _nine)));
      expect(takenOut(), isNot(takenOut(index: 1)));
    });

    test('should not let a caller change its list', () {
      expect(
        () => takenOut().taken.add((index: 1, donation: offered)),
        throwsUnsupportedError,
      );
    });

    test('should print its tournée, house and dons', () {
      expect(
        '${takenOut()}',
        'DonationsTakenOut(round-1, DonationOrigin(rue-des-lilas, 3), '
            '[(donation: PaidDonation(cash, 2000), index: 0)])',
      );
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
    test('should sum the tournée up with its dons in order (#168), waiting '
        'to be sent to its secteur', () {
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
          donations: [cash(1000), offered, cheque(2000)],
        ),
      );
      expect(validated.summary.correctedAt, isNull);
      expect(validated.summary.housesToMark, 0);
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

    test('should give back the links the phone kept (#169)', () {
      final round = Round.restore(
        id: roundId,
        sector: sector49Id,
        campaign: year2026,
        startedAt: startedAt,
        housesVisited: 0,
        donations: [cash(1000), offered],
        origins: [_three, null],
      );

      expect(round, newRound().add(cash(1000), from: _three).add(offered));
    });

    test('should link no don of a tournée kept before #169', () {
      final round = Round.restore(
        id: roundId,
        sector: sector49Id,
        campaign: year2026,
        startedAt: startedAt,
        housesVisited: 0,
        donations: [cash(1000), offered],
      );

      expect(round.origins, [null, null]);
    });

    test('should refuse links not one per don', () {
      Round restoring(List<DonationOrigin?> origins) => Round.restore(
        id: roundId,
        sector: sector49Id,
        campaign: year2026,
        startedAt: startedAt,
        housesVisited: 0,
        donations: [cash(1000)],
        origins: origins,
      );

      expect(() => restoring([]), throwsArgumentError);
      expect(() => restoring([null, null]), throwsArgumentError);
      expect(restoring([_three]).origins, [_three]);
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
