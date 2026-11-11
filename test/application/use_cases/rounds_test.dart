import 'dart:async';

import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/round_ledger.dart';
import 'package:tournee_calendriers/application/use_cases/rounds.dart';
import 'package:tournee_calendriers/domain/round/collecte.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show campaign2026;
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show lea;

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

  // With a house or a door: add_donation_test.dart.
  group('AddDonation', () {
    late FakeStreetRepository streets;
    late AddDonation addDonation;

    setUp(() {
      streets = FakeStreetRepository();
      addDonation = AddDonation(rounds, streets, clock, FakeIdentity(lea));
    });

    test('should add the don to the tournée on', () async {
      rounds.openRound = newRound().add(cash(1000));

      final added = valueOf(await addDonation(offered));

      expect(added.round.donations, [cash(1000), offered]);
      expect(added.calendar, isNull);
      expect(rounds.saves, [added.round]);
      expect(streets.saved, isEmpty);
    });

    test('should refuse with no tournée on', () async {
      expect(failureOf(await addDonation(offered)), const NoRoundOn());
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
    late ValidateRound validate;

    setUp(() {
      clock.time = endedAt;
      validate = ValidateRound(rounds, clock);
    });

    test('should keep the tournée as validated, waiting to be sent to the '
        'secteur it started in', () async {
      // Opened the 12 since: the tournée still belongs to the 49.
      mySectors.mySectors = _with(sector12.id);
      rounds.openRound = newRound().visited().add(cash(1000)).add(offered);

      final validated = valueOf(await validate());

      final expected = UnsentRound(
        sector: sector49Id,
        campaign: year2026,
        summary: RoundSummary(
          id: roundId,
          startedAt: startedAt,
          endedAt: endedAt,
          housesVisited: 1,
          totals: DonationTotals.of([cash(1000), offered]),
        ),
      );
      expect(validated, expected);
      expect(rounds.unsent, [expected]);
    });

    test('should forget the tournée on and its dons', () async {
      rounds.openRound = newRound().add(cash(1000));

      await validate();

      expect(rounds.openRound, isNull);
    });

    test('should keep the tournées already waiting', () async {
      final earlier = _unsent('round-0', 23);
      rounds = FakeOpenRoundStore(newRound(), [earlier]);
      validate = ValidateRound(rounds, clock);

      await validate();

      expect(rounds.unsent.map((round) => round.id), [
        RoundId('round-0'),
        roundId,
      ]);
    });

    test('should refuse with no tournée on', () async {
      expect(failureOf(await validate()), const NoRoundOn());
      expect(rounds.unsent, isEmpty);
    });
  });

  group('SendUnsentRounds', () {
    late FakeRoundLedger ledger;
    late SendUnsentRounds send;

    setUp(() {
      ledger = FakeRoundLedger();
      send = SendUnsentRounds(rounds, ledger);
    });

    test('should send the tournées waiting at start, each to its secteur and '
        'campaign, and forget each the server keeps', () async {
      final mine = _unsent('a', 23);
      final other = UnsentRound(
        sector: sector12.id,
        campaign: campaign2027,
        summary: _unsent('b', 24).summary,
      );
      rounds = FakeOpenRoundStore(null, [mine, other]);
      send = SendUnsentRounds(rounds, ledger);

      final sending = send();
      addTearDown(sending.cancel);
      await pumpEventQueue();

      expect(ledger.recorded, [
        (sector49Id, year2026, mine.summary),
        (sector12.id, campaign2027, other.summary),
      ]);
      expect(rounds.unsent, isEmpty);
    });

    test('should send a tournée as soon as it is validated', () async {
      final sending = send();
      addTearDown(sending.cancel);

      await rounds.keepValidated(_unsent('a', 23));
      await pumpEventQueue();

      expect(ledger.recorded.single.$3, _unsent('a', 23).summary);
      expect(rounds.unsent, isEmpty);
    });

    test('should keep a refused tournée, marked refused', () async {
      ledger.answer = LedgerAnswer.refused;
      rounds = FakeOpenRoundStore(null, [_unsent('a', 23)]);
      send = SendUnsentRounds(rounds, ledger);

      final sending = send();
      addTearDown(sending.cancel);
      await pumpEventQueue();

      expect(rounds.unsent, [_unsent('a', 23).refused()]);
      expect(ledger.asked, [_unsent('a', 23).summary]);
    });

    test('should not send a refused tournée again by itself', () async {
      rounds = FakeOpenRoundStore(null, [_unsent('a', 23).refused()]);
      send = SendUnsentRounds(rounds, ledger);

      final sending = send();
      addTearDown(sending.cancel);
      await rounds.keepValidated(_unsent('b', 24));
      await pumpEventQueue();

      expect(ledger.asked, [_unsent('b', 24).summary]);
      expect(rounds.unsent, [_unsent('a', 23).refused()]);
    });

    test('should send a tournée only once while the server has not '
        'answered', () async {
      ledger.server = Completer();
      final sending = send();
      addTearDown(sending.cancel);

      await rounds.keepValidated(_unsent('a', 23));
      // Another change while the first send waits.
      await rounds.keepValidated(_unsent('b', 24));
      await pumpEventQueue();

      expect(ledger.asked, [
        _unsent('a', 23).summary,
        _unsent('b', 24).summary,
      ]);
      expect(rounds.unsent, hasLength(2));

      ledger.server!.complete();
      await pumpEventQueue();

      expect(ledger.asked, hasLength(2));
      expect(rounds.unsent, isEmpty);
    });

    test('should send it again once tried again after a refusal', () async {
      ledger.answer = LedgerAnswer.refused;
      rounds = FakeOpenRoundStore(null, [_unsent('a', 23)]);
      send = SendUnsentRounds(rounds, ledger);
      final sending = send();
      addTearDown(sending.cancel);
      await pumpEventQueue();

      ledger.answer = LedgerAnswer.kept;
      await RetryUnsentRound(rounds)(RoundId('a'));
      await pumpEventQueue();

      expect(ledger.asked, [
        _unsent('a', 23).summary,
        _unsent('a', 23).summary,
      ]);
      expect(rounds.unsent, isEmpty);
    });

    test('should not bring back a tournée erased while the server had not '
        'answered', () async {
      ledger
        ..server = Completer()
        ..answer = LedgerAnswer.refused;
      rounds = FakeOpenRoundStore(null, [_unsent('a', 23)]);
      send = SendUnsentRounds(rounds, ledger);
      final sending = send();
      addTearDown(sending.cancel);
      await pumpEventQueue();

      await rounds.forgetUnsent(RoundId('a'));
      ledger.server!.complete();
      await pumpEventQueue();

      expect(rounds.unsent, isEmpty);
    });

    test('should stop sending new ones once cancelled', () async {
      final sending = send();
      await sending.cancel();

      await rounds.keepValidated(_unsent('a', 23));
      await pumpEventQueue();

      expect(ledger.asked, isEmpty);
    });
  });

  group('RetryUnsentRound', () {
    test('should make a refused tournée wait again', () async {
      rounds = FakeOpenRoundStore(null, [
        _unsent('a', 23).refused(),
        _unsent('b', 24).refused(),
      ]);

      await RetryUnsentRound(rounds)(RoundId('a'));

      expect(rounds.unsent, [_unsent('a', 23), _unsent('b', 24).refused()]);
    });

    test('should leave a tournée waiting as it is', () async {
      rounds = FakeOpenRoundStore(null, [_unsent('a', 23)]);
      final heard = <List<UnsentRound>>[];
      rounds.unsentChanges.listen(heard.add);

      await RetryUnsentRound(rounds)(RoundId('a'));
      await RetryUnsentRound(rounds)(RoundId('z'));

      expect(rounds.unsent, [_unsent('a', 23)]);
      expect(heard, isEmpty);
    });
  });

  group('EraseUnsentRound', () {
    test('should forget a refused tournée', () async {
      rounds = FakeOpenRoundStore(null, [
        _unsent('a', 23).refused(),
        _unsent('b', 24).refused(),
      ]);

      await EraseUnsentRound(rounds)(RoundId('a'));

      expect(rounds.unsent, [_unsent('b', 24).refused()]);
    });

    test('should leave a tournée still waiting: it may be on its way to '
        'the server', () async {
      rounds = FakeOpenRoundStore(null, [_unsent('a', 23)]);

      await EraseUnsentRound(rounds)(RoundId('a'));
      await EraseUnsentRound(rounds)(RoundId('z'));

      expect(rounds.unsent, [_unsent('a', 23)]);
    });
  });

  group('RoundsUnreadableAtStart', () {
    test('should say whether the tournées could not be read', () {
      expect(RoundsUnreadableAtStart(rounds)(), isFalse);

      rounds.unreadableAtStart = true;

      expect(RoundsUnreadableAtStart(rounds)(), isTrue);
    });
  });

  group('AbandonRound', () {
    late AbandonRound abandon;

    // Built without the `RoundLedger`: nothing of an abandoned tournée can
    // reach « Collecte ».
    setUp(() => abandon = AbandonRound(rounds));

    test('should forget the tournée and its dons, and give it back', () async {
      final round = newRound().visited().add(cash(1000));
      rounds.openRound = round;

      final forgotten = valueOf(await abandon());

      expect(forgotten, round);
      expect(rounds.openRound, isNull);
      expect(rounds.clears, 1);
      expect(rounds.saves, isEmpty);
    });

    test('should refuse with no tournée on', () async {
      expect(failureOf(await abandon()), const NoRoundOn());
      expect(rounds.clears, 0);
    });
  });

  group('WatchCollecte', () {
    late FakeRoundLedger ledger;
    late WatchCollecte watch;

    /// A tournée of the 49 named [id], started [day] at noon UTC, with
    /// [donations].
    RoundSummary summary(String id, int day, List<Donation> donations) =>
        RoundSummary(
          id: RoundId(id),
          startedAt: DateTime.utc(2026, 10, day, 12),
          endedAt: DateTime.utc(2026, 10, day, 16),
          housesVisited: day,
          totals: DonationTotals.of(donations),
        );

    setUp(() {
      ledger = FakeRoundLedger();
      watch = WatchCollecte(ledger, rounds);
    });

    test('should give the validated tournées of the secteur and campaign, '
        'newest first, added up', () async {
      final saturday = summary('sat', 24, [cash(1000), offered]);
      final friday = summary('fri', 23, [cheque(2000)]);
      await ledger.record(sector49Id, year2026, friday);
      await ledger.record(sector49Id, year2026, saturday);
      // Another secteur's, and another campaign's: not this collecte.
      await ledger.record(sector12.id, year2026, summary('t12', 25, []));
      await ledger.record(sector49Id, campaign2027, summary('old', 26, []));

      final collecte = await watch(sector49Id, year2026).first;

      expect(collecte.rounds, [saturday, friday]);
      expect(
        collecte.totals,
        DonationTotals.of([cash(1000), offered, cheque(2000)]),
      );
    });

    test(
      'should give the collecte again when a tournée is validated',
      () async {
        final shown = <Collecte>[];
        final listening = watch(sector49Id, year2026).listen(shown.add);
        addTearDown(listening.cancel);
        await Future<void>.delayed(Duration.zero);

        await ledger.record(
          sector49Id,
          year2026,
          summary('sat', 24, [cash(500)]),
        );
        await Future<void>.delayed(Duration.zero);

        expect(shown.map((c) => c.rounds.length), [0, 1]);
        expect(shown.last.totals.cents, 500);
      },
    );

    test('should give apart the tournées of the secteur and campaign not '
        'yet sent, out of the totals', () async {
      final sent = summary('sat', 24, [cash(1000)]);
      await ledger.record(sector49Id, year2026, sent);
      final waiting = _unsent('sun', 25);
      rounds = FakeOpenRoundStore(null, [
        waiting,
        // Another secteur's, and another campaign's: not this collecte.
        UnsentRound(
          sector: sector12.id,
          campaign: year2026,
          summary: _unsent('t12', 26).summary,
        ),
        UnsentRound(
          sector: sector49Id,
          campaign: campaign2027,
          summary: _unsent('old', 27).summary,
        ),
      ]);
      watch = WatchCollecte(ledger, rounds);

      final collecte = await watch(sector49Id, year2026).first;

      expect(collecte.rounds, [sent]);
      expect(collecte.unsent, [waiting]);
      expect(collecte.totals, DonationTotals.of([cash(1000)]));
    });

    test('should give the collecte again when a tournée waits, is refused '
        'or is sent', () async {
      final shown = <Collecte>[];
      final listening = watch(sector49Id, year2026).listen(shown.add);
      addTearDown(listening.cancel);
      await pumpEventQueue();

      await rounds.keepValidated(_unsent('a', 23));
      await pumpEventQueue();
      await rounds.updateUnsent(_unsent('a', 23).refused());
      await pumpEventQueue();
      await ledger.record(sector49Id, year2026, _unsent('a', 23).summary);
      await pumpEventQueue();
      await rounds.forgetUnsent(RoundId('a'));
      await pumpEventQueue();

      expect(shown.first.unsent, isEmpty);
      expect(shown.map((c) => c.unsent.map((u) => u.state).toList()), [
        <UnsentState>[],
        [UnsentState.waiting],
        [UnsentState.refused],
        // The server has it, the phone not told yet: still apart.
        [UnsentState.refused],
        <UnsentState>[],
      ]);
      expect(shown.last.rounds, [_unsent('a', 23).summary]);
    });

    test('should fail when the ledger fails', () async {
      final failing = WatchCollecte(_FailingLedger(), rounds);

      await expectLater(
        failing(sector49Id, year2026),
        emitsError(isA<StateError>()),
      );
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

/// A tournée of the 49 validated [day] October, waiting to be sent.
UnsentRound _unsent(String id, int day) => UnsentRound(
  sector: sector49Id,
  campaign: year2026,
  summary: RoundSummary(
    id: RoundId(id),
    startedAt: DateTime.utc(2026, 10, day, 12),
    endedAt: DateTime.utc(2026, 10, day, 16),
    housesVisited: day,
    totals: DonationTotals.of([cash(100 * day)]),
  ),
);

/// A ledger whose tournées cannot be read.
final class _FailingLedger implements RoundLedger {
  @override
  Future<LedgerAnswer> record(
    SectorId sector,
    CampaignYear campaign,
    RoundSummary summary,
  ) async => LedgerAnswer.kept;

  @override
  Stream<List<RoundSummary>> watch(SectorId sector, CampaignYear campaign) =>
      Stream.error(StateError('unreadable'));
}
