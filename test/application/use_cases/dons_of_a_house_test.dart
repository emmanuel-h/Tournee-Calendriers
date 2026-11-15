// A ✓ taken back takes its own dons out of the tournée (PLAN §5.21, #169):
// the don step after « Fait » and « + Ajouter un don » link a don to its
// house or door; a status leaving ✓ takes the linked dons out, and
// « Annuler » puts them back.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/calendars.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/application/use_cases/mark_dwelling.dart';
import 'package:tournee_calendriers/application/use_cases/rounds.dart';
import 'package:tournee_calendriers/application/use_cases/set_house_details.dart';
import 'package:tournee_calendriers/application/use_cases/undo_last_change.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_origin.dart';
import 'package:tournee_calendriers/domain/round/donations_taken_out.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../domain/round/round_fixtures.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

final _seven = DonationOrigin(street: lilasId, number: n('7'));
final _five = DonationOrigin(street: lilasId, number: n('5'));
final _doorOne = DonationOrigin(
  street: lilasId,
  number: n('8'),
  door: rdc('01'),
);

CalendarPlace _place(DonationOrigin origin) =>
    (street: origin.street, number: origin.number, door: origin.door);

void main() {
  late FakeStreetRepository streets;
  late FakeOpenRoundStore rounds;
  late SetHouseDetails setHouseDetails;
  late MarkDwelling markDwelling;
  late UndoLastChange undo;
  late AddDonation addDonation;

  setUp(() {
    streets = repositoryWithLilas();
    rounds = aRoundOn();
    setHouseDetails = SetHouseDetails(
      streets,
      clockAtTwo(),
      leaOnThePhone(),
      visitsTo(rounds),
    );
    markDwelling = MarkDwelling(
      streets,
      clockAtTwo(),
      leaOnThePhone(),
      visitsTo(rounds),
    );
    undo = UndoLastChange(
      streets,
      clockAtTwo(),
      leaOnThePhone(),
      visitsTo(rounds),
    );
    addDonation = AddDonation(rounds, streets, clockAtTwo(), leaOnThePhone());
  });

  /// N° 7 made ✓ with [donation] given in « Montant du don ».
  Future<HouseChange> sevenDoneWith(Donation donation) async {
    final done = valueOf(
      await setHouseDetails(
        lilasId,
        n('7'),
        const StatusMark(VisitStatus.done),
      ),
    ).change;
    await addDonation(donation, from: _place(_seven));
    return done;
  }

  group('AddDonation', () {
    test('should link the don of « Montant du don » to its house', () async {
      final added = valueOf(
        await addDonation(cash(2000), from: _place(_seven)),
      );

      expect(added.round.origins, [_seven]);
      expect(added.calendar, isNull);
      expect(streets.saved, isEmpty);
    });

    test('should link the don of « + Ajouter un don » to its door', () async {
      final added = valueOf(
        await addDonation(cheque(500), calendarFor: _place(_doorOne)),
      );

      expect(added.round.origins, [_doorOne]);
      expect(added.calendar, isA<DwellingCalendarsCounted>());
    });

    test('should link no don given without a house', () async {
      expect(valueOf(await addDonation(offered)).round.origins, [null]);
    });

    test('should link the don to the house it is noted from first', () async {
      final added = valueOf(
        await addDonation(
          cash(500),
          from: _place(_five),
          calendarFor: _place(_doorOne),
        ),
      );

      expect(added.round.origins, [_five]);
    });
  });

  group('a ✓ taken back', () {
    test('should take its don out of the tournée and say which', () async {
      await sevenDoneWith(cash(2000));
      await addDonation(card(1000));

      final marked = valueOf(
        await setHouseDetails(
          lilasId,
          n('7'),
          const StatusMark(VisitStatus.nobodyHome),
        ),
      );

      expect(marked.change, isA<HouseMarked>());
      expect(
        marked.takenOut,
        DonationsTakenOut(
          round: roundId,
          origin: _seven,
          taken: [(index: 0, donation: cash(2000))],
        ),
      );
      expect(rounds.openRound!.donations, [card(1000)]);
      expect(rounds.openRound!.origins, [null]);
      expect(rounds.openRound!.housesVisited, 0);
    });

    test('should take the dons out when the ✓ becomes ⊘, which still '
        'counts the house', () async {
      await sevenDoneWith(cash(2000));

      final marked = valueOf(
        await setHouseDetails(
          lilasId,
          n('7'),
          const StatusMark(VisitStatus.refused),
        ),
      );

      expect(marked.takenOut!.donations, [cash(2000)]);
      expect(rounds.openRound!.donations, isEmpty);
      expect(rounds.openRound!.housesVisited, 1);
    });

    test('should take out every don of the house, not another\'s', () async {
      await sevenDoneWith(cash(2000));
      await addDonation(offered, from: _place(_five));
      await addDonation(cheque(500), calendarFor: _place(_seven));

      final marked = valueOf(
        await setHouseDetails(
          lilasId,
          n('7'),
          const StatusMark(VisitStatus.toDo),
        ),
      );

      expect(marked.takenOut!.taken, [
        (index: 0, donation: cash(2000)),
        (index: 2, donation: cheque(500)),
      ]);
      expect(rounds.openRound!.donations, [offered]);
    });

    test('should take out a door\'s dons', () async {
      await addDonation(cash(1000), from: _place(_doorOne));

      final marked = valueOf(
        await markDwelling(
          lilasId,
          n('8'),
          rdc('01'),
          const StatusMark(VisitStatus.comeBack),
        ),
      );

      expect(marked.takenOut!.origin, _doorOne);
      expect(rounds.openRound!.donations, isEmpty);
    });

    test(
      'should take out nothing from a ✓ marked before the tournée',
      () async {
        // Door 01 was ✓ before: no don of the tournée is linked to it.
        await addDonation(cash(1000));

        final marked = valueOf(
          await markDwelling(
            lilasId,
            n('8'),
            rdc('01'),
            const StatusMark(VisitStatus.toDo),
          ),
        );

        expect(marked.takenOut, isNull);
        expect(rounds.openRound!.donations, [cash(1000)]);
      },
    );

    test(
      'should take out nothing for a status that does not leave ✓',
      () async {
        await addDonation(cash(1000), from: _place(_five));

        final marked = valueOf(
          await setHouseDetails(
            lilasId,
            n('5'),
            const StatusMark(VisitStatus.nobodyHome),
          ),
        );

        expect(marked.takenOut, isNull);
        expect(rounds.openRound!.donations, [cash(1000)]);
      },
    );

    test('should take out nothing from a tournée of another secteur', () async {
      rounds.openRound = Round.start(
        id: RoundId('round-12'),
        sector: SectorId('t12'),
        campaign: year2026,
        at: startedAt,
      ).add(cash(2000), from: _seven);
      await setHouseDetails(
        lilasId,
        n('7'),
        const StatusMark(VisitStatus.done),
      );

      final marked = valueOf(
        await setHouseDetails(
          lilasId,
          n('7'),
          const StatusMark(VisitStatus.toDo),
        ),
      );

      expect(marked.takenOut, isNull);
      expect(rounds.openRound!.donations, [cash(2000)]);
    });

    test('should keep the dons of a house removed while ✓', () async {
      await sevenDoneWith(cash(2000));

      expect(
        await visitsTo(rounds).noteChange(
          NumberRemoved(
            streetId: lilasId,
            removed: RemovedHouse(
              house: houseOf(streets[lilasId]!, '7'),
              removal: leaAtTwo,
            ),
          ),
        ),
        isNull,
      );
      expect(rounds.openRound!.donations, [cash(2000)]);
    });
  });

  group('« Annuler »', () {
    test('should put the ✓ and its dons back at their places, linked '
        'again', () async {
      await addDonation(card(1000));
      await sevenDoneWith(cash(2000));
      await addDonation(offered);
      final before = rounds.openRound!;
      final marked = valueOf(
        await setHouseDetails(
          lilasId,
          n('7'),
          const StatusMark(VisitStatus.nobodyHome),
        ),
      );

      await undo(marked.change, putBack: marked.takenOut);

      expect(houseOf(streets[lilasId]!, '7').status, VisitStatus.done);
      expect(rounds.openRound, before);
      expect(rounds.openRound!.origins, [null, _seven, null]);
    });

    test('should put back the dons of a door', () async {
      await addDonation(cash(1000), from: _place(_doorOne));
      final before = rounds.openRound!;
      final marked = valueOf(
        await markDwelling(
          lilasId,
          n('8'),
          rdc('01'),
          const StatusMark(VisitStatus.refused),
        ),
      );

      await undo(marked.change, putBack: marked.takenOut);

      expect(rounds.openRound, before);
    });

    test(
      'should take out the dons of a ✓ undone, as any ✓ taken back',
      () async {
        final done = await sevenDoneWith(cash(2000));

        await undo(done);

        expect(rounds.openRound!.donations, isEmpty);
        expect(rounds.openRound!.housesVisited, 0);
      },
    );
  });
}
