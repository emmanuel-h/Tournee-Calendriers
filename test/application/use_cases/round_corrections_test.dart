// Correcting a validated tournée and marking its forgotten houses (PLAN
// §5.20, #168), with a hand-written ledger standing for the secteur's.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/round_corrections.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/round_correction.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/round/round_summary.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../domain/round/round_fixtures.dart';
import '../../support/fakes/fake_round_ledger.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

/// Saturday's tournée of the 49: 23 houses, 10 € in cash, 5 € by card and
/// a free calendar, [toMark] houses to mark.
RoundSummary _saturday({int toMark = 0}) => RoundSummary(
  id: roundId,
  startedAt: startedAt,
  endedAt: endedAt,
  housesVisited: 23,
  totals: DonationTotals.of([cash(1000), card(500), offered]),
  donations: [cash(1000), card(500), offered],
  housesToMark: toMark,
);

final RoundPlace _place = (
  sector: sector49Id,
  campaign: year2026,
  round: roundId,
);

final RoundPlace _elsewhere = (
  sector: sector49Id,
  campaign: year2026,
  round: RoundId('other'),
);

void main() {
  late FakeRoundLedger ledger;

  setUp(() {
    ledger = FakeRoundLedger()..have(sector49Id, year2026, _saturday());
  });

  group('CorrectRoundDonations', () {
    test('should write the new list and its totals, stamped with the '
        'clock', () async {
      final corrected = valueOf(
        await CorrectRoundDonations(ledger, clockAtTwo())(_place, [
          cash(1000),
          card(500),
          offered,
          cheque(2000),
        ]),
      );

      final totals = DonationTotals.of([
        cash(1000),
        card(500),
        offered,
        cheque(2000),
      ]);
      expect(ledger.corrected, [
        (
          sector49Id,
          year2026,
          roundId,
          RoundCorrected(
            totals: totals,
            donations: [cash(1000), card(500), offered, cheque(2000)],
            correctedAt: twoPm,
            housesAdded: 1,
          ),
        ),
      ]);
      expect(corrected.totals, totals);
      expect(corrected.correctedAt, twoPm);
      expect(corrected.housesToMark, 1);
    });

    test('should write nothing for a tournée it does not find', () async {
      expect(
        failureOf(
          await CorrectRoundDonations(ledger, clockAtTwo())(_elsewhere, []),
        ),
        const RoundNotFound<CorrectionFailure>(),
      );
      expect(ledger.corrected, isEmpty);
    });

    test('should write nothing when the tournée refuses it', () async {
      ledger = FakeRoundLedger()
        ..have(
          sector49Id,
          year2026,
          RoundSummary(
            id: roundId,
            startedAt: startedAt,
            endedAt: endedAt,
            housesVisited: 3,
            totals: DonationTotals.none,
          ),
        );

      expect(
        failureOf(
          await CorrectRoundDonations(ledger, clockAtTwo())(_place, []),
        ),
        const RoundCommandRefused(CorrectionFailure.noDonationList),
      );
      expect(ledger.corrected, isEmpty);
    });
  });

  group('CorrectRoundTotals', () {
    final totals = DonationTotals(
      cash: MethodTotal(count: 2, cents: 3000),
      cheque: MethodTotal.none,
      card: MethodTotal(count: 1, cents: 500),
      free: 1,
    );

    test('should write the new totals and leave the list', () async {
      final corrected = valueOf(
        await CorrectRoundTotals(ledger, clockAtTwo())(_place, totals),
      );

      expect(ledger.corrected, [
        (
          sector49Id,
          year2026,
          roundId,
          RoundCorrected(
            totals: totals,
            donations: null,
            correctedAt: twoPm,
            housesAdded: 1,
          ),
        ),
      ]);
      expect(corrected.donations, [cash(1000), card(500), offered]);
      expect(corrected.listDiffersFromTotals, isTrue);
    });

    test('should write nothing for totals out of their bounds', () async {
      final faulty = DonationTotals(
        cash: MethodTotal(count: 8, cents: 0),
        cheque: MethodTotal.none,
        card: MethodTotal.none,
        free: 0,
      );

      expect(
        failureOf(
          await CorrectRoundTotals(ledger, clockAtTwo())(_place, faulty),
        ),
        const RoundCommandRefused(CorrectionFailure.totalsNotSound),
      );
      expect(ledger.corrected, isEmpty);
    });
  });

  group('IgnoreForgottenHouse', () {
    test('should take one off the houses to mark', () async {
      ledger = FakeRoundLedger()
        ..have(sector49Id, year2026, _saturday(toMark: 2));

      final settled = valueOf(await IgnoreForgottenHouse(ledger)(_place));

      expect(ledger.settled, [
        (sector49Id, year2026, roundId, ForgottenHouse.ignored),
      ]);
      expect(settled.housesToMark, 1);
      expect(settled.housesVisited, 23);
    });

    test('should write nothing when none is left to mark', () async {
      expect(
        failureOf(await IgnoreForgottenHouse(ledger)(_place)),
        const RoundCommandRefused(NoHouseToMark()),
      );
      expect(ledger.settled, isEmpty);
    });
  });

  group('MarkForgottenHouse', () {
    late FakeStreetRepository streets;

    setUp(() {
      streets = repositoryWithLilas();
      ledger = FakeRoundLedger()
        ..have(sector49Id, year2026, _saturday(toMark: 1));
    });

    MarkForgottenHouse markForgotten() =>
        MarkForgottenHouse(ledger, streets, clockAtTwo(), leaOnThePhone());

    test('should mark the house done as the member now, and count it on '
        'the tournée', () async {
      final change = valueOf(
        await markForgotten()(_place, (
          street: lilasId,
          number: n('7'),
          door: null,
        )),
      );

      expect(
        change,
        HouseMarked(
          streetId: lilasId,
          before: seven,
          stamp: leaAtTwo,
          status: VisitStatus.done,
        ),
      );
      expect(houseOf(streets.saved.single.$1, '7').status, VisitStatus.done);
      expect(ledger.settled, [
        (sector49Id, year2026, roundId, ForgottenHouse.marked),
      ]);
      final summary = (await ledger.find(sector49Id, year2026, roundId))!;
      expect(summary.housesVisited, 24);
      expect(summary.housesToMark, 0);
    });

    test('should mark a door of a building', () async {
      final change = valueOf(
        await markForgotten()(_place, (
          street: lilasId,
          number: n('8'),
          door: rdc('02'),
        )),
      );

      expect(change, isA<DwellingMarked>());
      expect(
        houseOf(
          streets.saved.single.$1,
          '8',
        ).building!.dwellingAt(rdc('02'))!.status,
        VisitStatus.done,
      );
      expect(ledger.settled, hasLength(1));
    });

    test('should change nothing when no house is left to mark', () async {
      ledger = FakeRoundLedger()..have(sector49Id, year2026, _saturday());

      expect(
        failureOf(
          await markForgotten()(_place, (
            street: lilasId,
            number: n('7'),
            door: null,
          )),
        ),
        MarkForgottenFailure.nothingToMark,
      );
      expect(streets.saved, isEmpty);
      expect(ledger.settled, isEmpty);
    });

    test('should change nothing for a tournée it does not find', () async {
      expect(
        failureOf(
          await markForgotten()(_elsewhere, (
            street: lilasId,
            number: n('7'),
            door: null,
          )),
        ),
        MarkForgottenFailure.nothingToMark,
      );
      expect(streets.saved, isEmpty);
    });

    test('should say a house already visited, and count nothing', () async {
      expect(
        failureOf(
          await markForgotten()(_place, (
            street: lilasId,
            number: n('8'),
            door: rdc('01'),
          )),
        ),
        MarkForgottenFailure.alreadyVisited,
      );
      expect(streets.saved, isEmpty);
      expect(ledger.settled, isEmpty);
    });

    test('should say the house is gone: no such number, or no such '
        'street', () async {
      expect(
        failureOf(
          await markForgotten()(_place, (
            street: lilasId,
            number: n('99'),
            door: null,
          )),
        ),
        MarkForgottenFailure.houseGone,
      );
      expect(
        failureOf(
          await MarkForgottenHouse(
            ledger,
            FakeStreetRepository(const []),
            clockAtTwo(),
            leaOnThePhone(),
          )(_place, (street: lilasId, number: n('7'), door: null)),
        ),
        MarkForgottenFailure.houseGone,
      );
      expect(ledger.settled, isEmpty);
    });
  });

  test('the failures should equal their like and print their name', () {
    expect(const RoundNotFound<int>(), const RoundNotFound<int>());
    expect(
      const RoundNotFound<int>().hashCode,
      const RoundNotFound<int>().hashCode,
    );
    expect(const RoundNotFound<int>().toString(), 'RoundNotFound');
    expect(const RoundCommandRefused(1), const RoundCommandRefused(1));
    expect(const RoundCommandRefused(1), isNot(const RoundCommandRefused(2)));
    expect(
      const RoundCommandRefused(1).hashCode,
      const RoundCommandRefused(1).hashCode,
    );
    expect(const RoundCommandRefused(1).toString(), 'RoundCommandRefused(1)');
  });
}
