import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';

import '../../support/results.dart';
import 'round_fixtures.dart';

void main() {
  /// 15 €: 10 € in cash, 5 € by card, and a calendar given for free.
  final dons = [cash(1000), card(500), offered];

  RoundSummary summary({
    String id = 'round-1',
    DateTime? started,
    DateTime? ended,
    int houses = 23,
    DonationTotals? totals,
    List<Donation>? donations,
    DateTime? correctedAt,
    int toMark = 0,
  }) => RoundSummary(
    id: RoundId(id),
    startedAt: started ?? startedAt,
    endedAt: ended ?? endedAt,
    housesVisited: houses,
    totals: totals ?? DonationTotals.of([cash(1000)]),
    donations: donations,
    correctedAt: correctedAt,
    housesToMark: toMark,
  );

  /// The tournée of [dons], its totals theirs.
  RoundSummary withDons({int toMark = 0}) =>
      summary(totals: DonationTotals.of(dons), donations: dons, toMark: toMark);

  final correctedAt = DateTime.utc(2026, 10, 25, 9);

  test('should equal a summary of the same values only', () {
    expect(summary(), summary());
    expect(summary().hashCode, summary().hashCode);
    expect(withDons().hashCode, withDons().hashCode);
    expect(summary(), isNot(summary(id: 'round-2')));
    expect(
      summary(),
      isNot(summary(started: endedAt.subtract(const Duration(hours: 1)))),
    );
    expect(
      summary(),
      isNot(summary(ended: endedAt.add(const Duration(hours: 1)))),
    );
    expect(summary(), isNot(summary(houses: 24)));
    expect(summary(), isNot(summary(totals: DonationTotals.none)));
    expect(summary(), isNot(summary(donations: [cash(1000)])));
    expect(
      summary(donations: [cash(1000)]),
      isNot(summary(donations: [cash(1001)])),
    );
    expect(summary(), isNot(summary(correctedAt: correctedAt)));
    expect(summary(), isNot(summary(toMark: 1)));
  });

  test('should print its tournée, dates, houses, totals, dons and '
      'corrections', () {
    expect(
      summary(
        totals: DonationTotals.none,
        donations: dons,
        correctedAt: correctedAt,
        toMark: 2,
      ).toString(),
      'RoundSummary(round-1, 2026-10-24 12:05:00.000Z → '
      '2026-10-24 16:20:00.000Z, 23 houses, ${DonationTotals.none}, 3 dons, '
      'corrected 2026-10-25 09:00:00.000Z, 2 to mark)',
    );
  });

  test('should refuse negative houses visited or to mark', () {
    expect(() => summary(houses: -1), throwsArgumentError);
    expect(() => summary(toMark: -1), throwsArgumentError);
    expect(summary(houses: 0, toMark: 0).housesVisited, 0);
  });

  test('should keep its dons apart from the list it was given', () {
    final given = [cash(1000)];
    final kept = summary(donations: given);

    given.add(card(500));

    expect(kept.donations, [cash(1000)]);
    expect(() => kept.donations!.add(offered), throwsUnsupportedError);
  });

  group('listDiffersFromTotals', () {
    test('should be false when the list adds up to the totals', () {
      expect(withDons().listDiffersFromTotals, isFalse);
    });

    test('should be true when the list no longer adds up to them', () {
      expect(
        summary(
          totals: DonationTotals.of([cash(1000)]),
          donations: dons,
        ).listDiffersFromTotals,
        isTrue,
      );
      // A free calendar more is a difference too.
      expect(
        summary(
          totals: DonationTotals.of([...dons, offered]),
          donations: dons,
        ).listDiffersFromTotals,
        isTrue,
      );
    });

    test('should be false without a list (validated before #168)', () {
      expect(summary().listDiffersFromTotals, isFalse);
    });
  });

  group('correctDonations (« Don par don »)', () {
    test('should take the new list, work the totals out of it, and say '
        'when', () {
      final (corrected, change) = valueOf(
        withDons().correctDonations([cash(2000), card(500)], at: correctedAt),
      );

      final totals = DonationTotals.of([cash(2000), card(500)]);
      expect(corrected.donations, [cash(2000), card(500)]);
      expect(corrected.totals, totals);
      expect(corrected.correctedAt, correctedAt);
      expect(corrected.listDiffersFromTotals, isFalse);
      expect(corrected.housesVisited, 23);
      expect(corrected.startedAt, startedAt);
      expect(corrected.endedAt, endedAt);
      expect(corrected.housesToMark, 0);
      expect(
        change,
        RoundCorrected(
          totals: totals,
          donations: [cash(2000), card(500)],
          correctedAt: correctedAt,
          housesAdded: 0,
        ),
      );
    });

    test('should add to the houses to mark the dons and calendars it '
        'adds', () {
      final (corrected, change) = valueOf(
        withDons(toMark: 1)
            .correctDonations([...dons, cheque(700), offered], at: correctedAt),
      );

      expect(change.housesAdded, 2);
      expect(corrected.housesToMark, 3);
    });

    test('should add one house for one don more, none for the same '
        'count', () {
      final one = valueOf(
        withDons().correctDonations([...dons, cash(100)], at: correctedAt),
      );
      final same = valueOf(
        withDons().correctDonations([
          cash(9000),
          card(500),
          offered,
        ], at: correctedAt),
      );

      expect(one.$2.housesAdded, 1);
      expect(one.$1.housesToMark, 1);
      expect(same.$2.housesAdded, 0);
    });

    test('should add no house when it takes dons away', () {
      final (corrected, change) = valueOf(
        withDons(toMark: 1).correctDonations([cash(1000)], at: correctedAt),
      );

      expect(change.housesAdded, 0);
      expect(corrected.housesToMark, 1);
    });

    test('should refuse a tournée validated before #168: it has no list', () {
      expect(
        failureOf(summary().correctDonations([cash(100)], at: correctedAt)),
        CorrectionFailure.noDonationList,
      );
    });

    test('should take $mostDonations dons and refuse one more', () {
      final most = List.filled(mostDonations, cash(100));

      expect(
        valueOf(withDons().correctDonations(most, at: correctedAt))
            .$1
            .donations,
        hasLength(mostDonations),
      );
      expect(
        failureOf(
          withDons().correctDonations([...most, cash(100)], at: correctedAt),
        ),
        CorrectionFailure.tooManyDonations,
      );
    });
  });

  group('correctTotals (« Totaux »)', () {
    final newTotals = DonationTotals(
      cash: MethodTotal(count: 1, cents: 1000),
      cheque: MethodTotal(count: 1, cents: 2000),
      card: MethodTotal(count: 1, cents: 500),
      free: 1,
    );

    test('should take the new totals and leave the list as it was', () {
      final (corrected, change) = valueOf(
        withDons().correctTotals(newTotals, at: correctedAt),
      );

      expect(corrected.totals, newTotals);
      expect(corrected.donations, dons);
      expect(corrected.correctedAt, correctedAt);
      expect(corrected.listDiffersFromTotals, isTrue);
      expect(corrected.housesVisited, 23);
      expect(
        change,
        RoundCorrected(
          totals: newTotals,
          donations: null,
          correctedAt: correctedAt,
          housesAdded: 1,
        ),
      );
      expect(corrected.housesToMark, 1);
    });

    test('should correct a tournée validated before #168, which keeps no '
        'list', () {
      final (corrected, _) = valueOf(
        summary().correctTotals(newTotals, at: correctedAt),
      );

      expect(corrected.donations, isNull);
      expect(corrected.listDiffersFromTotals, isFalse);
    });

    test('should refuse totals out of their bounds', () {
      final faulty = DonationTotals(
        cash: MethodTotal(count: 0, cents: 2000),
        cheque: MethodTotal.none,
        card: MethodTotal.none,
        free: 0,
      );

      expect(
        failureOf(withDons().correctTotals(faulty, at: correctedAt)),
        CorrectionFailure.totalsNotSound,
      );
    });
  });

  group('settleForgottenHouse', () {
    test('should count a house marked as visited, one fewer to mark', () {
      final (settled, how) = valueOf(
        withDons(toMark: 2).settleForgottenHouse(ForgottenHouse.marked),
      );

      expect(how, ForgottenHouse.marked);
      expect(settled.housesVisited, 24);
      expect(settled.housesToMark, 1);
      expect(settled.totals, withDons().totals);
      expect(settled.donations, dons);
    });

    test('should only take one off the houses to mark when ignored', () {
      final (settled, how) = valueOf(
        withDons(toMark: 1).settleForgottenHouse(ForgottenHouse.ignored),
      );

      expect(how, ForgottenHouse.ignored);
      expect(settled.housesVisited, 23);
      expect(settled.housesToMark, 0);
    });

    test('should refuse when no house is left to mark', () {
      for (final how in ForgottenHouse.values) {
        expect(
          failureOf(withDons().settleForgottenHouse(how)),
          const NoHouseToMark(),
        );
      }
    });
  });

  test('RoundCorrected should equal one of the same values only', () {
    RoundCorrected change({
      DonationTotals? totals,
      List<Donation>? donations,
      DateTime? at,
      int added = 1,
    }) => RoundCorrected(
      totals: totals ?? DonationTotals.of(dons),
      donations: donations,
      correctedAt: at ?? correctedAt,
      housesAdded: added,
    );

    expect(change(), change());
    expect(change().hashCode, change().hashCode);
    expect(change(donations: dons).hashCode, change(donations: dons).hashCode);
    expect(change(), isNot(change(totals: DonationTotals.none)));
    expect(change(), isNot(change(donations: dons)));
    expect(change(), isNot(change(at: endedAt)));
    expect(change(), isNot(change(added: 2)));
    expect(
      change(donations: [cash(1)]).toString(),
      'RoundCorrected(${DonationTotals.of(dons)}, [PaidDonation(cash, 1)], '
      '2026-10-25 09:00:00.000Z, +1)',
    );
  });

  test('NoHouseToMark should equal another and print its name', () {
    expect(const NoHouseToMark(), const NoHouseToMark());
    expect(const NoHouseToMark().hashCode, const NoHouseToMark().hashCode);
    expect(const NoHouseToMark().toString(), 'NoHouseToMark');
  });
}
