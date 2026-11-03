// The calendars of a house or door from the status picker (#114, PLAN
// §5.6): « + Ajouter un don » gives the don to the tournée and one
// calendar more to the house; « − » takes one away and never touches a
// don.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/calendars.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/rounds.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../domain/round/round_fixtures.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

/// Number 9 done, with two calendars (Paul's change), beside the houses of
/// the Rue des Lilas.
final _nine = House(
  number: n('9'),
  status: VisitStatus.done,
  calendars: calendars(2),
  lastChange: paulAtThree,
);

final _street = valueOf(
  Street.create(
    id: lilasId,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [...lilas.houses, _nine],
  ),
);

CalendarPlace _house(String number) =>
    (street: lilasId, number: n(number), door: null);

void main() {
  late FakeStreetRepository streets;

  setUp(() {
    streets = FakeStreetRepository([_street]);
  });

  group('AddDonation', () {
    late FakeOpenRoundStore rounds;
    late AddDonation addDonation;

    setUp(() {
      rounds = aRoundOn();
      addDonation = AddDonation(rounds, streets, clockAtTwo(), leaOnThePhone());
    });

    test('should add the don and one calendar to the house', () async {
      final added = valueOf(
        await addDonation(cheque(500), calendarFor: _house('9')),
      );

      final change = HouseCalendarsCounted(
        streetId: lilasId,
        before: _nine,
        stamp: leaAtTwo,
        calendars: calendars(3),
      );
      expect(added.round.donations, [cheque(500)]);
      expect(added.calendar, change);
      expect(rounds.saves, [added.round]);
      expect(streets.saved.single.$2, change);
      expect(houseOf(streets[lilasId]!, '9').calendars, calendars(3));
    });

    test('should add one calendar to a door of a building', () async {
      final added = valueOf(
        await addDonation(
          offered,
          calendarFor: (street: lilasId, number: n('8'), door: rdc('01')),
        ),
      );

      expect(
        added.calendar,
        DwellingCalendarsCounted(
          streetId: lilasId,
          number: n('8'),
          staircase: escA,
          level: 0,
          before: doorOne,
          stamp: leaAtTwo,
          calendars: calendars(2),
        ),
      );
      expect(
        houseOf(
          streets[lilasId]!,
          '8',
        ).building!.dwellingAt(rdc('01'))!.calendars,
        calendars(2),
      );
    });

    test('should keep the don when the house is no longer done', () async {
      final added = valueOf(
        await addDonation(cash(1000), calendarFor: _house('7')),
      );

      expect(added.round.donations, [cash(1000)]);
      expect(added.calendar, isNull);
      expect(rounds.saves, [added.round]);
      expect(streets.saved, isEmpty);
    });

    test('should add no calendar with no tournée on', () async {
      rounds.openRound = null;

      expect(
        failureOf(await addDonation(cash(1000), calendarFor: _house('9'))),
        const NoRoundOn(),
      );
      expect(streets.saved, isEmpty);
      expect(rounds.saves, isEmpty);
    });
  });

  group('AddedDonation', () {
    final round = newRound().add(offered);
    final change = HouseCalendarsCounted(
      streetId: lilasId,
      before: _nine,
      stamp: leaAtTwo,
      calendars: calendars(3),
    );

    test('should be equal when the tournée and the calendar are', () {
      expect(
        AddedDonation(round: round, calendar: change),
        AddedDonation(round: round, calendar: change),
      );
      expect(
        AddedDonation(round: round, calendar: change).hashCode,
        AddedDonation(round: round, calendar: change).hashCode,
      );
    });

    test('should differ when only one has a calendar', () {
      expect(
        AddedDonation(round: round, calendar: change),
        isNot(AddedDonation(round: round)),
      );
    });

    test('should differ when the tournées differ', () {
      expect(
        AddedDonation(round: round),
        isNot(AddedDonation(round: newRound())),
      );
    });

    test('should show its tournée and calendar when printed', () {
      expect(
        AddedDonation(round: round, calendar: change).toString(),
        'AddedDonation($round, $change)',
      );
    });
  });

  group('RemoveCalendar', () {
    late RemoveCalendar removeCalendar;

    setUp(() {
      removeCalendar = RemoveCalendar(streets, clockAtTwo(), leaOnThePhone());
    });

    test('should take one calendar from the house', () async {
      final change = valueOf(await removeCalendar(_house('9')));

      expect(
        change,
        HouseCalendarsCounted(
          streetId: lilasId,
          before: _nine,
          stamp: leaAtTwo,
          calendars: calendars(1),
        ),
      );
      expect(streets.saved.single.$2, change);
      expect(houseOf(streets[lilasId]!, '9').calendars, calendars(1));
    });

    test('should refuse the last calendar of a door', () async {
      expect(
        failureOf(
          await removeCalendar((
            street: lilasId,
            number: n('8'),
            door: rdc('01'),
          )),
        ),
        const CommandRefused(CalendarChangeFailure.lastCalendar),
      );
      expect(streets.saved, isEmpty);
    });

    test('should refuse when the street is not on the phone', () async {
      streets = FakeStreetRepository();
      removeCalendar = RemoveCalendar(streets, clockAtTwo(), leaOnThePhone());

      expect(
        failureOf(await removeCalendar(_house('9'))),
        const StreetNotFound<CalendarChangeFailure>(),
      );
    });
  });
}
