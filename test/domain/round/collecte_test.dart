import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/collecte.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';

import 'round_fixtures.dart';

RoundSummary _summary(String id, DateTime start, DonationTotals totals) =>
    RoundSummary(
      id: RoundId(id),
      startedAt: start,
      endedAt: start.add(const Duration(hours: 4)),
      housesVisited: 20,
      totals: totals,
    );

void main() {
  final saturday = _summary(
    'sat',
    DateTime.utc(2026, 10, 24, 12),
    DonationTotals.of([cash(1000), offered, cheque(2000)]),
  );
  final sunday = _summary(
    'sun',
    DateTime.utc(2026, 10, 25, 9),
    DonationTotals.of([cash(500), card(1000)]),
  );
  final friday = _summary(
    'fri',
    DateTime.utc(2026, 10, 23, 16),
    DonationTotals.of([offered]),
  );

  test('should list the tournées newest first', () {
    final collecte = Collecte.of([saturday, sunday, friday]);

    expect(collecte.rounds, [sunday, saturday, friday]);
  });

  test('should add every tournée up, method by method', () {
    final collecte = Collecte.of([saturday, sunday, friday]);

    expect(collecte.totals.cash, MethodTotal(count: 2, cents: 1500));
    expect(collecte.totals.cheque, MethodTotal(count: 1, cents: 2000));
    expect(collecte.totals.card, MethodTotal(count: 1, cents: 1000));
    expect(collecte.totals.free, 2);
    expect(collecte.totals.count, 4);
    expect(collecte.totals.cents, 4500);
  });

  test('should be empty with no tournée validated', () {
    final collecte = Collecte.of(const []);

    expect(collecte.rounds, isEmpty);
    expect(collecte.totals, DonationTotals.none);
  });

  test('should not let a caller change the list', () {
    final collecte = Collecte.of([saturday]);

    expect(() => collecte.rounds.add(sunday), throwsUnsupportedError);
  });

  group('with tournées not yet sent', () {
    UnsentRound unsent(RoundSummary summary) =>
        UnsentRound(sector: sector49Id, campaign: year2026, summary: summary);

    test('should list them apart, newest first, out of the totals', () {
      final collecte = Collecte.of(
        [saturday],
        unsent: [unsent(friday), unsent(sunday).refused()],
      );

      expect(collecte.rounds, [saturday]);
      expect(collecte.unsent, [unsent(sunday).refused(), unsent(friday)]);
      expect(collecte.totals, saturday.totals);
    });

    test('should leave out of the sent ones a tournée still waiting, which '
        "the phone's copy of the server may already show", () {
      final collecte = Collecte.of(
        [saturday, sunday],
        unsent: [unsent(sunday)],
      );

      expect(collecte.rounds, [saturday]);
      expect(collecte.unsent, [unsent(sunday)]);
      expect(collecte.totals, saturday.totals);
    });

    test('should have none by default', () {
      expect(Collecte.of([saturday]).unsent, isEmpty);
    });

    test('should not let a caller change them', () {
      final collecte = Collecte.of(const [], unsent: [unsent(friday)]);

      expect(() => collecte.unsent.add(unsent(sunday)), throwsUnsupportedError);
    });
  });
}
