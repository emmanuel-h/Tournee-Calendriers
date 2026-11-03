import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/round_visits.dart';
import 'package:tournee_calendriers/domain/round/round_visit.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/results.dart';

void main() {
  late FakeOpenRoundStore rounds;
  late FakeMySectorsStore mySectors;
  late RoundVisits visits;

  setUp(() {
    rounds = FakeOpenRoundStore(newRound().visited());
    mySectors = FakeMySectorsStore(
      valueOf(
        MySectors.none.remember(sector49).remember(sector12).open(sector49.id),
      ),
    );
    visits = RoundVisits(rounds, mySectors);
  });

  test('should count a house made visited', () async {
    await visits.note(RoundVisit.visited);

    expect(rounds.saves.single.housesVisited, 2);
    expect(rounds.saves.single.id, roundId);
  });

  test('should take back a house no longer visited', () async {
    await visits.note(RoundVisit.unvisited);

    expect(rounds.saves.single.housesVisited, 0);
  });

  test('should save nothing when there is nothing to take back', () async {
    rounds.openRound = newRound();

    await visits.note(RoundVisit.unvisited);

    expect(rounds.saves, isEmpty);
  });

  test('should save nothing for a change of no visit', () async {
    await visits.note(RoundVisit.none);

    expect(rounds.saves, isEmpty);
  });

  test('should count nothing with no tournée on', () async {
    rounds.openRound = null;

    await visits.note(RoundVisit.visited);

    expect(rounds.saves, isEmpty);
  });

  test('should count nothing in another secteur than its own', () async {
    mySectors.mySectors = valueOf(mySectors.mySectors.open(sector12.id));

    await visits.note(RoundVisit.visited);

    expect(rounds.saves, isEmpty);
  });

  test('should count nothing while no secteur is open', () async {
    mySectors.mySectors = MySectors.none.remember(sector49);

    await visits.note(RoundVisit.visited);

    expect(rounds.saves, isEmpty);
  });
}
