import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';

import '../../domain/round/round_fixtures.dart';

CollecteRound _round({
  String id = 'sat',
  DateTime? start,
  DateTime? end,
  int houses = 23,
  DonationTotals? totals,
}) => CollecteRound(
  id: RoundId(id),
  startedAt: start ?? startedAt,
  endedAt: end ?? endedAt,
  housesVisited: houses,
  totals: totals ?? DonationTotals.of([cash(1000)]),
);

CollecteShown _shown({
  int number = 49,
  int campaign = 2026,
  List<CollecteRound>? rounds,
  DonationTotals? totals,
}) => CollecteShown(
  number: number,
  campaign: campaign,
  rounds: rounds ?? [_round()],
  totals: totals ?? DonationTotals.of([cash(1000)]),
);

void main() {
  test('should tell the loading and unavailable views apart', () {
    // Built at run time: `const` ones would never run the constructors.
    // ignore: prefer_const_constructors
    final loading = CollecteLoading();
    // ignore: prefer_const_constructors
    final unavailable = CollecteUnavailable();

    expect(loading, const CollecteLoading());
    expect(loading.hashCode, const CollecteLoading().hashCode);
    expect(unavailable, const CollecteUnavailable());
    expect(unavailable.hashCode, const CollecteUnavailable().hashCode);
    expect(loading, isNot(unavailable));
  });

  test('should compare tournées by every field', () {
    expect(_round(), _round());
    expect(_round().hashCode, _round().hashCode);
    expect(_round(id: 'fri'), isNot(_round()));
    expect(_round(start: endedAt), isNot(_round()));
    expect(_round(end: startedAt), isNot(_round()));
    expect(_round(houses: 9), isNot(_round()));
    expect(_round(totals: DonationTotals.none), isNot(_round()));
  });

  test('should compare collectes by every field', () {
    expect(_shown(), _shown());
    expect(_shown().hashCode, _shown().hashCode);
    expect(_shown(number: 12), isNot(_shown()));
    expect(_shown(campaign: 2027), isNot(_shown()));
    expect(_shown(rounds: []), isNot(_shown()));
    expect(_shown(totals: DonationTotals.none), isNot(_shown()));
  });

  test('should keep its tournées from being changed', () {
    expect(() => _shown().rounds.add(_round()), throwsUnsupportedError);
  });
}
