import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/round_summary_json_mapper.dart';

import '../../../domain/round/round_fixtures.dart';

void main() {
  test('should write the summary with no member and no don', () {
    final summary = newRound()
        .visited()
        .visited()
        .visited()
        .add(cash(1000))
        .add(cash(750))
        .add(cheque(2000))
        .add(card(500))
        .add(offered)
        .add(offered)
        .validate(endedAt);

    expect(roundSummaryToJson(summary), {
      'version': 1,
      'startedAt': '2026-10-24T12:05:00.000Z',
      'endedAt': '2026-10-24T16:20:00.000Z',
      'housesVisited': 3,
      'free': 2,
      'cash': {'count': 2, 'cents': 1750},
      'cheque': {'count': 1, 'cents': 2000},
      'card': {'count': 1, 'cents': 500},
    });
  });
}
