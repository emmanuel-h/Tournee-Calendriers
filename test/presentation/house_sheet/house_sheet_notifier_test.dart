import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/come_back_time.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart' as crew;
import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// 3 changed by Paul yesterday evening; 5 to come back Saturday 7 at 19 h; 7
/// never changed; 8 a building.
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
  late ProviderContainer container;

  /// A container whose phone holds [street] (none when null), with Léa
  /// changing houses at [twoPm]; no tournée is open unless [open] is, its
  /// team kept in [tournees].
  void phoneWith(
    Street? street, {
    TourneeSummary? open,
    FakeTourneeRepository? tournees,
  }) {
    streets = FakeStreetRepository([?street]);
    clock = FakeClock(twoPm);
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        clockProvider.overrideWithValue(clock),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
        myTourneesStoreProvider.overrideWithValue(
          FakeMyTourneesStore(switch (open) {
            final open? => valueOf(
              MyTournees.none.remember(open).open(open.id),
            ),
            null => MyTournees.none,
          }),
        ),
        tourneeRepositoryProvider.overrideWithValue(
          tournees ?? FakeTourneeRepository(),
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

    test('should name a member of the open tournée', () async {
      phoneWith(
        changedBy(crew.manuId),
        open: tournee49,
        tournees: FakeTourneeRepository([crew.team()]),
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
        open: tournee49,
        tournees: FakeTourneeRepository([crew.team()]),
      );
      open('3');
      await pumpEventQueue();

      expect((await shown('3')).lastChange, ChangedEarlier(_yesterday));
    });

    test('should name nobody when the team cannot be read', () async {
      final tournees = FakeTourneeRepository([crew.team()])
        ..watchError = StateError('removed');
      phoneWith(changedBy(crew.manuId), open: tournee49, tournees: tournees);
      open('3');
      await pumpEventQueue();

      expect((await shown('3')).lastChange, ChangedEarlier(_yesterday));
    });

    test('should name nobody but the phone when no tournée is open', () async {
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
    test(
      'should store the status, stamped, when another one is chosen',
      () async {
        phoneWith(_street());
        open('7');
        await settled('7');

        await notifier('7').setStatus(VisitStatus.nobodyHome);

        expect(
          streets.saved.single.$2,
          HouseMarked(
            streetId: _id,
            before: houseBefore('7'),
            stamp: leaAtTwo,
            status: VisitStatus.nobodyHome,
          ),
        );
        expect((await shown('7')).status, VisitStatus.nobodyHome);
      },
    );

    test('should come back without time when « Repasser » is chosen', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').setStatus(VisitStatus.comeBack);

      expect(
        streets.saved.single.$2,
        HouseMarked(
          streetId: _id,
          before: houseBefore('7'),
          stamp: leaAtTwo,
          status: VisitStatus.comeBack,
        ),
      );
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

    test(
      'should store nothing when the house already has that status',
      () async {
        phoneWith(_street());
        open('3');
        await settled('3');

        await notifier('3').setStatus(VisitStatus.nobodyHome);

        expect(streets.saved, isEmpty);
      },
    );

    test('should store nothing when the house is gone', () async {
      phoneWith(_street());
      open('9');
      await settled('9');

      await notifier('9').setStatus(VisitStatus.done);

      expect(streets.saved, isEmpty);
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

      final days = (await shown('7')).comeBackTime.days;

      expect(days.first, ComeBackDay(day('2026-11-02'), DayFromToday.today));
      expect(days, hasLength(ComeBackTime.dayCount));
    });

    test('should follow the clock when the street is shown again', () async {
      phoneWith(_street());
      open('7');
      await settled('7');
      clock.time = DateTime.utc(2026, 11, 4, 9);

      await notifier('7').setStatus(VisitStatus.comeBack);

      expect(
        (await shown('7')).comeBackTime.days.first,
        ComeBackDay(day('2026-11-04'), DayFromToday.today),
      );
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
}
