import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';

import 'round_fixtures.dart';

void main() {
  RoundSummary summary({
    String id = 'round-1',
    DateTime? started,
    DateTime? ended,
    int houses = 23,
    DonationTotals? totals,
  }) => RoundSummary(
    id: RoundId(id),
    startedAt: started ?? startedAt,
    endedAt: ended ?? endedAt,
    housesVisited: houses,
    totals: totals ?? DonationTotals.of([cash(1000)]),
  );

  test('should equal a summary of the same values only', () {
    expect(summary(), summary());
    expect(summary().hashCode, summary().hashCode);
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
  });

  test('should print its tournée, dates, houses and totals', () {
    expect(
      summary(totals: DonationTotals.none).toString(),
      'RoundSummary(round-1, 2026-10-24 12:05:00.000Z → '
      '2026-10-24 16:20:00.000Z, 23 houses, ${DonationTotals.none})',
    );
  });
}
