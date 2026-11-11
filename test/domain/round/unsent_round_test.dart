import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

import '../../support/results.dart';
import 'round_fixtures.dart';

void main() {
  final summary = RoundSummary(
    id: roundId,
    startedAt: startedAt,
    endedAt: endedAt,
    housesVisited: 3,
    totals: DonationTotals.of([cash(1000)]),
  );
  final waiting = UnsentRound(
    sector: sector49Id,
    campaign: year2026,
    summary: summary,
  );

  test('should wait to be sent once validated', () {
    expect(waiting.state, UnsentState.waiting);
    expect(waiting.id, roundId);
    expect(waiting.sector, sector49Id);
    expect(waiting.campaign, year2026);
    expect(waiting.summary, summary);
  });

  test('should be refused, the rest kept', () {
    final refused = waiting.refused();

    expect(refused.state, UnsentState.refused);
    expect(refused.summary, summary);
    expect(refused.sector, sector49Id);
    expect(refused.campaign, year2026);
  });

  test('should wait again when tried again', () {
    final again = waiting.refused().retried();

    expect(again.state, UnsentState.waiting);
    expect(again, waiting);
  });

  test('should equal a round of the same values only', () {
    final same = UnsentRound(
      sector: SectorId('t49'),
      campaign: year2026,
      summary: summary,
    );

    expect(waiting, same);
    expect(waiting.hashCode, same.hashCode);
    expect(waiting, isNot(waiting.refused()));
    expect(
      waiting,
      isNot(
        UnsentRound(
          sector: SectorId('t12'),
          campaign: year2026,
          summary: summary,
        ),
      ),
    );
    expect(
      waiting,
      isNot(
        UnsentRound(
          sector: sector49Id,
          campaign: valueOf(CampaignYear.create(2027)),
          summary: summary,
        ),
      ),
    );
    expect(
      waiting,
      isNot(
        UnsentRound(
          sector: sector49Id,
          campaign: year2026,
          summary: RoundSummary(
            id: RoundId('round-2'),
            startedAt: startedAt,
            endedAt: endedAt,
            housesVisited: 3,
            totals: DonationTotals.of([cash(1000)]),
          ),
        ),
      ),
    );
  });

  test('should name its round and state', () {
    expect(
      waiting.refused().toString(),
      'UnsentRound(round-1, t49, 2026, refused)',
    );
  });
}
