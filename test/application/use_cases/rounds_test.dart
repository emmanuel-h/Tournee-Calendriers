import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/rounds.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show campaign2026;
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/results.dart';

/// « Mes secteurs » with the 49 and the 12, [open] the one shown.
MySectors _with(SectorId? open) {
  final mine = MySectors.none.remember(sector49).remember(sector12);
  return open == null ? mine : valueOf(mine.open(open));
}

void main() {
  late FakeOpenRoundStore rounds;
  late FakeMySectorsStore mySectors;
  late FakeClock clock;

  setUp(() {
    rounds = FakeOpenRoundStore();
    mySectors = FakeMySectorsStore(_with(sector49.id));
    clock = FakeClock(startedAt);
  });

  group('StartRound', () {
    late StartRound start;

    setUp(() {
      start = StartRound(rounds, mySectors, clock, FakeIdGenerator('round'));
    });

    test('should start a tournée of the open secteur now', () async {
      final round = valueOf(await start());

      expect(round.id, RoundId('round-1'));
      expect(round.sector, sector49.id);
      expect(round.campaign, campaign2026);
      expect(round.startedAt, startedAt);
      expect(round.housesVisited, 0);
      expect(round.donations, isEmpty);
      expect(rounds.saves, [round]);
    });

    test('should start it in the campaign of the open secteur', () async {
      mySectors.mySectors = valueOf(
        MySectors.none
            .remember(summaryOf('t9', 9, campaign: campaign2027))
            .open(SectorId('t9')),
      );

      final round = valueOf(await start());

      expect(round.sector, SectorId('t9'));
      expect(round.campaign, campaign2027);
    });

    test('should refuse to start with no secteur open', () async {
      mySectors.mySectors = _with(null);

      expect(failureOf(await start()), StartRoundFailure.noSectorOpen);
      expect(rounds.saves, isEmpty);
    });

    test('should refuse an admin visiting the secteur', () async {
      mySectors.mySectors = valueOf(
        MySectors.none.remember(sector12Visited).open(sector12Visited.id),
      );

      expect(failureOf(await start()), StartRoundFailure.notInTheTeam);
      expect(rounds.saves, isEmpty);
    });

    test('should refuse a second tournée while one is on', () async {
      rounds.openRound = newRound();

      expect(failureOf(await start()), StartRoundFailure.alreadyOn);
      expect(rounds.saves, isEmpty);
    });

    test('should refuse a second one even from another secteur', () async {
      mySectors.mySectors = _with(sector12.id);
      rounds.openRound = newRound();

      expect(failureOf(await start()), StartRoundFailure.alreadyOn);
    });
  });

  group('WatchOpenRound', () {
    test('should give the tournée on now, then each change', () async {
      rounds.openRound = newRound();
      final seen = <Round?>[];
      final listening = WatchOpenRound(rounds)(sector49.id).listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      await rounds.save(newRound().add(cash(1000)));
      await rounds.clear();
      await listening.cancel();

      expect(seen, [newRound(), newRound().add(cash(1000)), null]);
    });

    test('should give none while no tournée is on', () async {
      expect(await WatchOpenRound(rounds)(sector49.id).first, isNull);
    });

    test('should hide a tournée of another secteur', () async {
      rounds.openRound = newRound();
      final seen = <Round?>[];
      final listening = WatchOpenRound(rounds)(sector12.id).listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      await rounds.save(newRound().visited());
      await listening.cancel();

      expect(seen, [null, null]);
    });

    test('should hide it while no secteur is open', () async {
      rounds.openRound = newRound();

      expect(await WatchOpenRound(rounds)(null).first, isNull);
    });
  });

  group('AddDonation', () {
    test('should add the don to the tournée on', () async {
      rounds.openRound = newRound().add(cash(1000));

      final round = valueOf(await AddDonation(rounds)(offered));

      expect(round.donations, [cash(1000), offered]);
      expect(rounds.saves, [round]);
    });

    test('should refuse with no tournée on', () async {
      expect(failureOf(await AddDonation(rounds)(offered)), const NoRoundOn());
      expect(rounds.saves, isEmpty);
    });
  });

  group('ChangeDonation', () {
    test('should replace the don at the index', () async {
      rounds.openRound = newRound().add(cash(1000)).add(offered);

      final round = valueOf(await ChangeDonation(rounds)(0, cheque(2000)));

      expect(round.donations, [cheque(2000), offered]);
      expect(rounds.saves, [round]);
    });

    test('should refuse an index past the dons', () async {
      rounds.openRound = newRound().add(cash(1000));

      expect(
        failureOf(await ChangeDonation(rounds)(1, offered)),
        DonationEditFailure.noSuchDonation,
      );
      expect(rounds.saves, isEmpty);
    });

    test('should refuse with no tournée on', () async {
      expect(
        failureOf(await ChangeDonation(rounds)(0, offered)),
        DonationEditFailure.noRoundOn,
      );
      expect(rounds.saves, isEmpty);
    });
  });

  group('RemoveDonation', () {
    test('should remove the don at the index', () async {
      rounds.openRound = newRound().add(cash(1000)).add(offered);

      final round = valueOf(await RemoveDonation(rounds)(1));

      expect(round.donations, [cash(1000)]);
      expect(rounds.saves, [round]);
    });

    test('should refuse an index past the dons', () async {
      rounds.openRound = newRound().add(cash(1000));

      expect(
        failureOf(await RemoveDonation(rounds)(1)),
        DonationEditFailure.noSuchDonation,
      );
      expect(rounds.saves, isEmpty);
    });

    test('should refuse with no tournée on', () async {
      expect(
        failureOf(await RemoveDonation(rounds)(0)),
        DonationEditFailure.noRoundOn,
      );
    });
  });

  group('ValidateRound', () {
    late FakeRoundLedger ledger;
    late ValidateRound validate;

    setUp(() {
      ledger = FakeRoundLedger();
      clock.time = endedAt;
      validate = ValidateRound(rounds, ledger, clock);
    });

    test('should send the summary to the secteur it started in', () async {
      // Opened the 12 since: the tournée still belongs to the 49.
      mySectors.mySectors = _with(sector12.id);
      rounds.openRound = newRound().visited().add(cash(1000)).add(offered);

      final summary = valueOf(await validate());

      final expected = RoundSummary(
        id: roundId,
        startedAt: startedAt,
        endedAt: endedAt,
        housesVisited: 1,
        totals: DonationTotals.of([cash(1000), offered]),
      );
      expect(summary, expected);
      expect(ledger.recorded, [(sector49Id, year2026, expected)]);
    });

    test('should forget the tournée and its dons once sent', () async {
      rounds.openRound = newRound().add(cash(1000));

      await validate();

      expect(rounds.openRound, isNull);
      expect(rounds.clears, 1);
    });

    test('should keep the tournée until the summary is handed over', () async {
      rounds.openRound = newRound();
      Round? onWhileSending;
      ledger.onRecord = () => onWhileSending = rounds.openRound;

      await validate();

      expect(onWhileSending, newRound());
    });

    test('should refuse with no tournée on', () async {
      expect(failureOf(await validate()), const NoRoundOn());
      expect(ledger.recorded, isEmpty);
      expect(rounds.clears, 0);
    });
  });

  test('should name the missing tournée', () {
    // Built at run time: a `const` one would never run the constructor.
    // ignore: prefer_const_constructors
    final none = NoRoundOn();

    expect(none, const NoRoundOn());
    expect(none.hashCode, const NoRoundOn().hashCode);
    expect(none, isNot(DonationEditFailure.noRoundOn));
    expect(none.toString(), 'NoRoundOn');
  });
}
