import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/collecte.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';

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
}
