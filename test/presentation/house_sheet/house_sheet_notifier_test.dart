import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/nobody_home_tries.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/round/given_donation.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' as crew;
import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_reminders.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// 3 changed by Paul yesterday evening, nobody home once; 5 to come back
/// Saturday 7 at 19 h; 7 never changed; 8 a building; 13 to come back after
/// nobody was home twice; 11 done, with two calendars.
final _yesterday = DateTime(2026, 11, 1, 18, 30);
final _houses = [
  House(
    number: n('3'),
    status: VisitStatus.nobodyHome,
    lastChange: ChangeStamp(by: paul, at: _yesterday.toUtc()),
  ),
  House(
    number: n('5'),
    status: VisitStatus.comeBack,
    comeBack: comeBack('2026-11-07', hour: 19),
  ),
  House(number: n('7')),
  House(number: n('8'), building: building(topFloor: 0, doors: 2)),
  House(number: n('13'), status: VisitStatus.comeBack, tries: tries(2)),
  House(number: n('11'), status: VisitStatus.done, calendars: calendars(2)),
];

Street _street() => valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: _houses,
  ),
);

void main() {
  late FakeStreetRepository streets;
  late FakeClock clock;
  late FakeOpenRoundStore rounds;
  late FakeReminderScheduler reminders;
  late ProviderContainer container;

  /// A container whose phone holds [street] (none when null), with Léa
  /// changing houses at [twoPm]; no secteur is open unless [open] is, its
  /// team kept in [sectors].
  void phoneWith(
    Street? street, {
    SectorSummary? open,
    FakeSectorRepository? sectors,
    Round? round,
  }) {
    streets = FakeStreetRepository([?street]);
    clock = FakeClock(twoPm);
    rounds = FakeOpenRoundStore(round);
    reminders = FakeReminderScheduler();
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        reminderSchedulerProvider.overrideWithValue(reminders),
        reminderPreferencesProvider.overrideWithValue(
          FakeReminderPreferences(),
        ),
        clockProvider.overrideWithValue(clock),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
        openRoundStoreProvider.overrideWithValue(rounds),
        mySectorsStoreProvider.overrideWithValue(
          FakeMySectorsStore(switch (open) {
            final open? => valueOf(MySectors.none.remember(open).open(open.id)),
            null => MySectors.none,
          }),
        ),
        sectorRepositoryProvider.overrideWithValue(
          sectors ?? FakeSectorRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  HouseSheetKey keyOf(String number) => (street: _id, number: n(number));

  /// Opens the sheet of [number]: `listen` keeps the auto-disposed provider
  /// alive, as the sheet does while it shows.
  ProviderSubscription<HouseSheetState> open(String number) =>
      container.listen(houseSheetProvider(keyOf(number)), (_, _) {});

  HouseSheetNotifier notifier(String number) =>
      container.read(houseSheetProvider(keyOf(number)).notifier);

  /// Lets the repository's stream deliver, then reads the state.
  Future<HouseSheetState> settled(String number) async {
    await Future<void>.delayed(Duration.zero);
    return container.read(houseSheetProvider(keyOf(number)));
  }

  Future<HouseSheetShown> shown(String number) async =>
      (await settled(number)) as HouseSheetShown;

  House houseNow(String number) =>
      streets[_id]!.houses.singleWhere((house) => house.number == n(number));

  House houseBefore(String number) =>
      _houses.singleWhere((house) => house.number == n(number));

  group('who made the last change', () {
    /// The street with 3 changed by [by] yesterday evening.
    Street changedBy(MemberId by) => valueOf(
      Street.create(
        id: _id,
        name: 'Rue des Lilas',
        commune: villefranche,
        houses: [
          House(
            number: n('3'),
            status: VisitStatus.done,
            lastChange: ChangeStamp(by: by, at: _yesterday.toUtc()),
          ),
        ],
      ),
    );

    test('should name a member of the open secteur', () async {
      phoneWith(
        changedBy(crew.manuId),
        open: sector49,
        sectors: FakeSectorRepository([crew.team()]),
      );
      open('3');
      await pumpEventQueue();

      final state = await shown('3');

      expect(
        state.lastChange,
        ChangedEarlier(_yesterday, by: const ChangedByMember('Manu')),
      );
    });

    test('should name nobody who is no longer in the team', () async {
      phoneWith(
        changedBy(crew.paulId),
        open: sector49,
        sectors: FakeSectorRepository([crew.team()]),
      );
      open('3');
      await pumpEventQueue();

      expect((await shown('3')).lastChange, ChangedEarlier(_yesterday));
    });

    test('should name nobody when the team cannot be read', () async {
      final sectors = FakeSectorRepository([crew.team()])
        ..watchError = StateError('removed');
      phoneWith(changedBy(crew.manuId), open: sector49, sectors: sectors);
      open('3');
      await pumpEventQueue();

      expect((await shown('3')).lastChange, ChangedEarlier(_yesterday));
    });

    test('should name nobody but the phone when no secteur is open', () async {
      phoneWith(changedBy(crew.manuId));
      open('3');

      expect((await shown('3')).lastChange, ChangedEarlier(_yesterday));
    });
  });

  group('state', () {
    test('should be loading before the street is read', () {
      phoneWith(_street());
      open('5');

      expect(
        container.read(houseSheetProvider(keyOf('5'))),
        isA<HouseSheetLoading>(),
      );
    });

    test('should show the house when the street is read', () async {
      phoneWith(_street());
      open('5');

      final state = await shown('5');

      expect(state.streetName, 'Rue des Lilas');
      expect(state.number, n('5'));
      expect(state.status, VisitStatus.comeBack);
      expect(state.comeBack, isTrue);
      expect(state.comeBackTime.chosen, isNotNull);
      expect(state.comeBackTime.chosen!.day, day('2026-11-07'));
      expect(state.comeBackTime.chosen!.fromToday, DayFromToday.later);
      expect(state.comeBackTime.hour, 19);
      expect(state.lastChange, isNull);
      expect(state.tries, 0);
    });

    test('should show the status and the day of the last change when it '
        'was made before today', () async {
      phoneWith(_street());
      open('3');

      final state = await shown('3');

      expect(state.status, VisitStatus.nobodyHome);
      expect(state.comeBack, isFalse);
      expect(state.comeBackTime.chosen, isNull);
      expect(state.comeBackTime.hour, isNull);
      expect(state.lastChange, ChangedEarlier(_yesterday));
      // Nobody home, once.
      expect(state.tries, 1);
      expect(state.offersNobodyHomeAgain, isTrue);
    });

    test('should show the time only when the change was made today', () async {
      phoneWith(_street());
      open('7');
      await settled('7');
      await notifier('7').setStatus(VisitStatus.done);

      final state = await shown('7');

      expect(
        state.lastChange,
        ChangedToday(twoPm.toLocal(), by: const ChangedByMe()),
      );
    });

    test('should follow the house when it changes elsewhere', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      final (changed, change) = valueOf(
        _street().markHouse(n('7'), VisitStatus.done, by: paul, at: threePm),
      );
      await streets.save(changed, change);

      expect((await shown('7')).status, VisitStatus.done);
    });

    test(
      'should say the house is gone when the number is not in the street',
      () async {
        phoneWith(_street());
        open('9');

        expect(await settled('9'), isA<HouseSheetGone>());
      },
    );

    test('should say the house is gone when it is a building', () async {
      phoneWith(_street());
      open('8');

      expect(await settled('8'), isA<HouseSheetGone>());
    });

    test(
      'should say the house is gone when the street is not on the phone',
      () async {
        phoneWith(null);
        open('5');

        expect(await settled('5'), isA<HouseSheetGone>());
      },
    );

    test(
      'should say the house is gone when the street is in the Corbeille',
      () async {
        final (deleted, _) = _street().delete(by: lea, at: twoPm);
        phoneWith(deleted);
        open('5');

        expect(await settled('5'), isA<HouseSheetGone>());
      },
    );
  });

  group('setStatus', () {
    test('should store the status, stamped, and say what it stored when '
        'another one is chosen', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      final stored = await notifier('7').setStatus(VisitStatus.nobodyHome);

      final marked = HouseMarked(
        streetId: _id,
        before: houseBefore('7'),
        stamp: leaAtTwo,
        status: VisitStatus.nobodyHome,
      );
      expect(streets.saved.single.$2, marked);
      // One try: the tile shows no count below two.
      expect(
        stored,
        StoredStatus(
          status: VisitStatus.nobodyHome,
          tries: null,
          change: marked,
        ),
      );
      expect((await shown('7')).status, VisitStatus.nobodyHome);
      expect(houseNow('7').tries, tries(1));
    });

    test('should come back without time when « Repasser » is chosen', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      final stored = await notifier('7').setStatus(VisitStatus.comeBack);

      final marked = HouseMarked(
        streetId: _id,
        before: houseBefore('7'),
        stamp: leaAtTwo,
        status: VisitStatus.comeBack,
      );
      expect(streets.saved.single.$2, marked);
      expect(stored?.change, marked);
      expect(stored?.status, VisitStatus.comeBack);
      final state = await shown('7');
      expect(state.status, VisitStatus.comeBack);
      expect(state.comeBack, isTrue);
      expect(state.comeBackTime.chosen, isNull);
    });

    test('should drop the time when done is chosen', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').setStatus(VisitStatus.done);

      final state = await shown('5');
      expect(state.status, VisitStatus.done);
      expect(state.comeBack, isFalse);
      expect(state.comeBackTime.chosen, isNull);
      expect(state.comeBackTime.hour, isNull);
      expect(houseNow('5').comeBack, isNull);
    });

    test('should keep the tries when done is chosen, and say them', () async {
      phoneWith(_street());
      open('13');
      await settled('13');

      final stored = await notifier('13').setStatus(VisitStatus.done);

      expect(stored?.status, VisitStatus.done);
      expect(stored?.tries, 2);
      expect(houseNow('13').tries, tries(2));
    });

    test('should start the tries again when « À faire » is chosen', () async {
      phoneWith(_street());
      open('13');
      await settled('13');

      final stored = await notifier('13').setStatus(VisitStatus.toDo);

      expect(stored?.status, VisitStatus.toDo);
      expect(stored?.tries, isNull);
      expect(houseNow('13').tries, NobodyHomeTries.none);
    });

    test('should drop the tries and the time when « Refusé » is chosen on a '
        'house to come back to', () async {
      phoneWith(_street());
      open('13');
      await settled('13');

      final stored = await notifier('13').setStatus(VisitStatus.refused);

      expect(stored?.status, VisitStatus.refused);
      expect(stored?.tries, isNull);
      expect(houseNow('13').status, VisitStatus.refused);
      expect(houseNow('13').tries, NobodyHomeTries.none);
      expect(houseNow('13').comeBack, isNull);
      final state = await shown('13');
      expect(state.showsTries, isFalse);
      expect(state.offersNobodyHomeAgain, isFalse);
      expect(state.comeBack, isFalse);
    });

    test('should count one more try when « Personne » is chosen on a house '
        'nobody was home at', () async {
      phoneWith(_street());
      open('3');
      await settled('3');

      final stored = await notifier('3').setStatus(VisitStatus.nobodyHome);

      final again = HouseNobodyHomeAgain(
        streetId: _id,
        before: houseBefore('3'),
        stamp: leaAtTwo,
        tries: tries(2),
      );
      expect(streets.saved.single.$2, again);
      expect(
        stored,
        StoredStatus(status: VisitStatus.nobodyHome, tries: 2, change: again),
      );
      expect((await shown('3')).tries, 2);
    });

    test('should count one more try when « Personne » is chosen on a house '
        'to come back to after nobody was home', () async {
      phoneWith(_street());
      open('13');
      await settled('13');

      final stored = await notifier('13').setStatus(VisitStatus.nobodyHome);

      expect(streets.saved.single.$2, isA<HouseNobodyHomeAgain>());
      expect(stored?.tries, 3);
      expect(houseNow('13').status, VisitStatus.nobodyHome);
      expect(houseNow('13').tries, tries(3));
    });

    test('should count the first try only when « Personne » is chosen on a '
        'house to come back to that was never found empty', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      final stored = await notifier('5').setStatus(VisitStatus.nobodyHome);

      expect(streets.saved.single.$2, isA<HouseMarked>());
      expect(stored?.tries, isNull);
      expect(houseNow('5').tries, tries(1));
      expect(houseNow('5').comeBack, isNull);
    });

    for (final (number, status) in [
      ('7', VisitStatus.toDo),
      ('5', VisitStatus.comeBack),
    ]) {
      test(
        'should store nothing when house $number already is $status',
        () async {
          phoneWith(_street());
          open(number);
          await settled(number);

          final stored = await notifier(number).setStatus(status);

          expect(stored, isNull);
          expect(streets.saved, isEmpty);
        },
      );
    }

    test('should store nothing when the house is gone', () async {
      phoneWith(_street());
      open('9');
      await settled('9');

      expect(await notifier('9').setStatus(VisitStatus.done), isNull);
      expect(streets.saved, isEmpty);
    });

    test('should say nothing was stored when the street refuses it', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      // The status is asked first; 7 is removed before its turn comes, so
      // the sheet still shows it but the street no longer has it.
      final stored = notifier('7').setStatus(VisitStatus.done);
      final (removed, change) = valueOf(
        _street().removeNumber(n('7'), by: paul, at: threePm),
      );
      unawaited(streets.save(removed, change));

      expect(await stored, isNull);
      expect(streets.saved.map((saved) => saved.$2), [change]);
    });
  });

  group('setComeBack', () {
    test('should store nothing on a house to do, whose « repasser » is a '
        'status', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').setComeBack(on: true);

      expect(streets.saved, isEmpty);
      expect(houseNow('7').status, VisitStatus.toDo);
    });

    test(
      'should store nothing on a house « repasser » when unticked',
      () async {
        phoneWith(_street());
        open('5');
        await settled('5');

        await notifier('5').setComeBack(on: false);

        expect(streets.saved, isEmpty);
        expect(houseNow('5').comeBack, comeBack('2026-11-07', hour: 19));
      },
    );
  });

  group('the days offered', () {
    test('should start today on the phone\'s calendar', () async {
      phoneWith(_street());
      open('7');

      final time = (await shown('7')).comeBackTime;

      expect(time.today, day('2026-11-02'));
      expect(time.tomorrow, day('2026-11-03'));
    });

    test('should follow the clock when the street is shown again', () async {
      phoneWith(_street());
      open('7');
      await settled('7');
      clock.time = DateTime.utc(2026, 11, 4, 9);

      await notifier('7').setStatus(VisitStatus.comeBack);

      expect((await shown('7')).comeBackTime.today, day('2026-11-04'));
    });
  });

  group('chooseComeBackDay', () {
    test('should store the day, keeping the hour already chosen', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').chooseComeBackDay(day('2026-11-03'));

      expect(
        streets.saved.single.$2,
        ComeBackSet(
          streetId: _id,
          before: houseBefore('5'),
          stamp: leaAtTwo,
          comeBack: comeBack('2026-11-03', hour: 19),
        ),
      );
      final time = (await shown('5')).comeBackTime;
      expect(
        time.chosen,
        ComeBackDay(day('2026-11-03'), DayFromToday.tomorrow),
      );
      expect(time.hour, 19);
    });

    test('should ask Android for the reminders the first time', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').chooseComeBackDay(day('2026-11-03'));
      await notifier('5').chooseComeBackDay(day('2026-11-04'));

      expect(reminders.asked, 1);
    });

    test('should not ask when the day is unchosen', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').chooseComeBackDay(null);

      expect(reminders.asked, 0);
    });

    test('should not ask when nothing was stored', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').chooseComeBackDay(day('2026-11-07'));

      expect(reminders.asked, 0);
    });

    test('should store a day alone on a « repasser » without time', () async {
      phoneWith(_street());
      open('7');
      await settled('7');
      await notifier('7').setStatus(VisitStatus.comeBack);

      await notifier('7').chooseComeBackDay(day('2026-11-02'));

      expect(houseNow('7').comeBack, comeBack('2026-11-02'));
      expect(streets.saved, hasLength(2));
    });

    test('should leave no time, the hour with it, when the day is '
        'unchosen', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').chooseComeBackDay(null);

      expect(houseNow('5').comeBack, ComeBack.withoutTime);
      expect(houseNow('5').status, VisitStatus.comeBack);
      final time = (await shown('5')).comeBackTime;
      expect(time.chosen, isNull);
      expect(time.hour, isNull);
    });

    test('should store nothing when the day is the one stored', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').chooseComeBackDay(day('2026-11-07'));

      expect(streets.saved, isEmpty);
    });

    test('should store nothing when the house is not « repasser »', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').chooseComeBackDay(day('2026-11-07'));

      expect(streets.saved, isEmpty);
    });
  });

  group('chooseComeBackHour', () {
    test('should store the hour on the day stored', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').chooseComeBackHour(8);

      expect(
        streets.saved.single.$2,
        ComeBackSet(
          streetId: _id,
          before: houseBefore('5'),
          stamp: leaAtTwo,
          comeBack: comeBack('2026-11-07', hour: 8),
        ),
      );
      expect((await shown('5')).comeBackTime.hour, 8);
    });

    test('should store « Pas d\'heure », the day kept', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').chooseComeBackHour(null);

      expect(houseNow('5').comeBack, comeBack('2026-11-07'));
    });

    test('should store nothing when the hour is the one stored', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').chooseComeBackHour(19);

      expect(streets.saved, isEmpty);
    });

    test('should store nothing before a day is chosen', () async {
      phoneWith(_street());
      open('7');
      await settled('7');
      await notifier('7').setStatus(VisitStatus.comeBack);

      await notifier('7').chooseComeBackHour(18);

      expect(houseNow('7').comeBack, ComeBack.withoutTime);
      expect(streets.saved, hasLength(1));
    });

    test('should store nothing when the house is not « repasser »', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').chooseComeBackHour(18);

      expect(streets.saved, isEmpty);
    });
  });

  group('order', () {
    test(
      'should run the changes one after the other when asked at once',
      () async {
        phoneWith(_street());
        open('7');
        await settled('7');
        final sheet = notifier('7');

        // Not awaited in between: « Repasser » then a day tapped at once.
        // Run together, the day would be judged on a house not « repasser »
        // yet, and dropped.
        final first = sheet.setStatus(VisitStatus.comeBack);
        final second = sheet.chooseComeBackDay(day('2026-11-07'));
        await Future.wait([first, second]);

        expect(streets.saved.map((saved) => saved.$2.runtimeType), [
          HouseMarked,
          ComeBackSet,
        ]);
        expect(houseNow('7').status, VisitStatus.comeBack);
        expect(houseNow('7').comeBack, comeBack('2026-11-07'));
      },
    );

    test(
      'should still run the next changes when one fails to be stored',
      () async {
        phoneWith(_street());
        open('5');
        await settled('5');
        final sheet = notifier('5');
        streets.failNextSave = const FileSystemException('disk full');

        final failed = sheet.setStatus(VisitStatus.done);
        final next = sheet.chooseComeBackDay(day('2026-11-08'));

        await expectLater(failed, throwsA(isA<FileSystemException>()));
        await next;
        expect(houseNow('5').status, VisitStatus.comeBack);
        expect(houseNow('5').comeBack, comeBack('2026-11-08', hour: 19));
      },
    );

    test('should be settled once every change asked is stored', () async {
      phoneWith(_street());
      open('5');
      await settled('5');
      final sheet = notifier('5');

      unawaited(sheet.chooseComeBackDay(day('2026-11-08')));
      unawaited(sheet.chooseComeBackHour(20));
      await sheet.settled;

      expect(houseNow('5').comeBack, comeBack('2026-11-08', hour: 20));
    });

    test('should be settled even when a change failed', () async {
      phoneWith(_street());
      open('5');
      await settled('5');
      final sheet = notifier('5');
      streets.failNextSave = const FileSystemException('disk full');

      final failed = sheet.chooseComeBackHour(20);

      await expectLater(sheet.settled, completes);
      await expectLater(failed, throwsA(isA<FileSystemException>()));
    });
  });

  group('during a tournée', () {
    /// The phone of [_street] with the 49 open and its tournée on, 2 dons
    /// in it and 1 house visited.
    void duringRound() => phoneWith(
      _street(),
      open: sector49,
      round: Round.restore(
        id: roundId,
        sector: sector49Id,
        campaign: year2026,
        startedAt: startedAt,
        housesVisited: 1,
        donations: [cash(500), offered],
      ),
    );

    test('should know a tournée is on', () async {
      duringRound();
      open('7');

      expect((await shown('7')).roundOn, isTrue);
    });

    test('should know no tournée is on', () async {
      phoneWith(_street(), open: sector49);
      open('7');

      expect((await shown('7')).roundOn, isFalse);
    });

    test('should follow the tournée ending while the sheet shows', () async {
      duringRound();
      open('7');
      await shown('7');

      await rounds.clear();

      expect((await shown('7')).roundOn, isFalse);
    });

    test('should add a don to the tournée, last, and say where it '
        'went', () async {
      duringRound();
      open('7');
      await shown('7');

      final given = await notifier('7').giveDonation(cheque(2000));

      expect(given, GivenDonation(index: 2, donation: cheque(2000)));
      expect(rounds.openRound!.donations, [cash(500), offered, cheque(2000)]);
    });

    test('should leave the house as it is when a don is given', () async {
      duringRound();
      open('7');
      await shown('7');

      await notifier('7').giveDonation(cash(1000));

      expect(houseNow('7'), houseBefore('7'));
    });

    test('should give no don when no tournée is on', () async {
      phoneWith(_street(), open: sector49);
      open('7');
      await shown('7');

      expect(await notifier('7').giveDonation(cash(1000)), isNull);
      expect(rounds.saves, isEmpty);
    });

    test('should put the house back as it was and count it no more when « '
        'Fait » is taken back', () async {
      duringRound();
      open('3');
      await shown('3');
      final sheet = notifier('3');
      final stored = (await sheet.setStatus(VisitStatus.done))!;
      expect(rounds.openRound!.housesVisited, 2);

      await sheet.takeBack(stored.change);

      expect(houseNow('3').status, VisitStatus.nobodyHome);
      expect(houseNow('3').tries, houseBefore('3').tries);
      expect(houseNow('3').lastChange, houseBefore('3').lastChange);
      expect(rounds.openRound!.housesVisited, 1);
      expect(rounds.openRound!.donations, [cash(500), offered]);
    });
  });

  group('calendars', () {
    /// The phone of [_street] with the 49 open and its tournée on, 2 dons
    /// in it.
    void duringRound() => phoneWith(
      _street(),
      open: sector49,
      round: Round.restore(
        id: roundId,
        sector: sector49Id,
        campaign: year2026,
        startedAt: startedAt,
        housesVisited: 1,
        donations: [cash(500), offered],
      ),
    );

    test('should show the calendars of a house done', () async {
      phoneWith(_street());
      open('11');

      expect((await shown('11')).calendars, 2);
    });

    test('should show no calendar on a house not done', () async {
      phoneWith(_street());
      open('7');

      expect((await shown('7')).calendars, 0);
    });

    test('should add the don and one calendar to the house, and say '
        'both', () async {
      duringRound();
      open('11');
      await shown('11');

      final given = await notifier('11').addDonation(cheque(2000));

      final change = HouseCalendarsCounted(
        streetId: _id,
        before: houseBefore('11'),
        stamp: leaAtTwo,
        calendars: calendars(3),
      );
      expect(
        given,
        GivenDonation(index: 2, donation: cheque(2000), calendar: change),
      );
      expect(rounds.openRound!.donations, [cash(500), offered, cheque(2000)]);
      expect(houseNow('11').calendars, calendars(3));
      expect((await shown('11')).calendars, 3);
    });

    test('should keep the don and say the house took no calendar when it is '
        'not done', () async {
      duringRound();
      open('7');
      await shown('7');

      final given = await notifier('7').addDonation(cheque(2000));

      expect(
        given,
        GivenDonation(index: 2, donation: cheque(2000), calendarRefused: true),
      );
      expect(rounds.openRound!.donations, [cash(500), offered, cheque(2000)]);
      expect(houseNow('7'), houseBefore('7'));
    });

    test('should add no calendar when no tournée is on', () async {
      phoneWith(_street(), open: sector49);
      open('11');
      await shown('11');

      expect(await notifier('11').addDonation(cash(1000)), isNull);
      expect(houseNow('11'), houseBefore('11'));
    });

    test('should take one calendar away with « − », the dons as they '
        'were', () async {
      duringRound();
      open('11');
      await shown('11');

      await notifier('11').removeCalendar();

      expect(houseNow('11').calendars, calendars(1));
      expect(houseNow('11').lastChange, leaAtTwo);
      expect(rounds.openRound!.donations, [cash(500), offered]);
      expect((await shown('11')).calendars, 1);
    });

    test('should store nothing when « − » is tapped at one calendar', () async {
      phoneWith(_street());
      open('11');
      await shown('11');
      final sheet = notifier('11');
      await sheet.removeCalendar();

      await sheet.removeCalendar();

      expect(houseNow('11').calendars, calendars(1));
      expect(streets.saved, hasLength(1));
    });

    test('should store nothing when the house is gone', () async {
      phoneWith(_street());
      open('11');
      await shown('11');
      final (gone, change) = valueOf(
        streets[_id]!.removeNumber(n('11'), by: lea, at: twoPm),
      );
      await streets.save(gone, change);

      await notifier('11').removeCalendar();

      expect(streets.saved, hasLength(1));
    });
  });
}
