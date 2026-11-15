import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/round_visits.dart';
import 'package:tournee_calendriers/domain/round/donation_origin.dart';
import 'package:tournee_calendriers/domain/round/donations_taken_out.dart';
import 'package:tournee_calendriers/domain/round/round_visit.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

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

  group('the dons of a ✓ taken back (#169)', () {
    final three = DonationOrigin(
      street: StreetId('rue-des-lilas'),
      number: n('3'),
    );
    final nine = DonationOrigin(
      street: StreetId('rue-des-lilas'),
      number: n('9'),
    );

    test('should take out the dons of the house leaving ✓ with the count, in '
        'one save', () async {
      rounds.openRound = newRound()
          .visited()
          .add(cash(2000), from: three)
          .add(card(500));

      final taken = await visits.note(RoundVisit.unvisited, leaving: three);

      expect(taken!.donations, [cash(2000)]);
      expect(taken.origin, three);
      expect(rounds.saves.single.donations, [card(500)]);
      expect(rounds.saves.single.housesVisited, 0);
    });

    test('should say nothing was taken out from a house with no don', () async {
      rounds.openRound = newRound().add(card(500), from: nine);

      final taken = await visits.note(RoundVisit.none, leaving: three);

      expect(taken, isNull);
      expect(rounds.saves, isEmpty);
    });

    test(
      'should put back the dons of an undo, and count the house again',
      () async {
        final linked = newRound().visited().add(cash(2000), from: three);
        final (without, out) = linked.takeOut(three);
        rounds.openRound = without.unvisited();

        final taken = await visits.note(RoundVisit.visited, putBack: out);

        expect(taken, isNull);
        expect(rounds.saves.single, linked);
      },
    );

    test('should take out nothing in another secteur than its own', () async {
      rounds.openRound = newRound().add(cash(2000), from: three);
      mySectors.mySectors = valueOf(mySectors.mySectors.open(sector12.id));

      expect(await visits.note(RoundVisit.none, leaving: three), isNull);
      expect(rounds.saves, isEmpty);
    });
  });

  group('Marked', () {
    final change = StreetDeleted(
      streetId: StreetId('rue-des-lilas'),
      deletion: leaAtTwo,
    );
    final taken = DonationsTakenOut(
      round: roundId,
      origin: DonationOrigin(street: StreetId('rue-des-lilas'), number: n('3')),
      taken: [(index: 0, donation: cash(2000))],
    );

    test('should equal what stored the same change and took the same dons', () {
      expect(Marked(change, takenOut: taken), Marked(change, takenOut: taken));
      expect(
        Marked(change, takenOut: taken).hashCode,
        Marked(change, takenOut: taken).hashCode,
      );
      expect(Marked(change, takenOut: taken), isNot(Marked(change)));
      expect(
        Marked(change),
        isNot(
          Marked(
            StreetDeleted(
              streetId: StreetId('rue-des-lilas'),
              deletion: paulAtThree,
            ),
          ),
        ),
      );
    });

    test('should print its change and its dons', () {
      expect('${Marked(change)}', 'Marked($change, null)');
    });
  });
}
