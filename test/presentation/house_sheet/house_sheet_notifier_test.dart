import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// 3 changed by Paul yesterday evening; 5 to come back « après 19h »; 7
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
    comeBack: comeBack('après 19h'),
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
  /// changing houses at [twoPm].
  void phoneWith(Street? street) {
    streets = FakeStreetRepository([?street]);
    clock = FakeClock(twoPm);
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        clockProvider.overrideWithValue(clock),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
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
      expect(state.comeBackHint, 'après 19h');
      expect(state.lastChange, isNull);
    });

    test('should show the status and the day of the last change when it '
        'was made before today', () async {
      phoneWith(_street());
      open('3');

      final state = await shown('3');

      expect(state.status, VisitStatus.nobodyHome);
      expect(state.comeBack, isFalse);
      expect(state.comeBackHint, '');
      expect(state.lastChange, ChangedEarlier(_yesterday));
    });

    test('should show the time only when the change was made today', () async {
      phoneWith(_street());
      open('7');
      await settled('7');
      await notifier('7').setStatus(VisitStatus.done);

      final state = await shown('7');

      expect(state.lastChange, ChangedToday(twoPm.toLocal()));
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

    test('should come back without hint when « Repasser » is chosen', () async {
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
      expect(state.comeBackHint, '');
    });

    test('should drop the hint when done is chosen', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').setStatus(VisitStatus.done);

      final state = await shown('5');
      expect(state.status, VisitStatus.done);
      expect(state.comeBack, isFalse);
      expect(state.comeBackHint, '');
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
        expect(houseNow('5').comeBack, comeBack('après 19h'));
      },
    );
  });

  group('saveComeBackHint', () {
    test('should store the trimmed hint when it changed', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').saveComeBackHint('  samedi matin ');

      expect(
        streets.saved.single.$2,
        ComeBackSet(
          streetId: _id,
          before: houseBefore('5'),
          stamp: leaAtTwo,
          comeBack: comeBack('samedi matin'),
        ),
      );
      expect((await shown('5')).comeBackHint, 'samedi matin');
    });

    test(
      'should store nothing when the hint is the same once trimmed',
      () async {
        phoneWith(_street());
        open('5');
        await settled('5');

        await notifier('5').saveComeBackHint(' après 19h ');

        expect(streets.saved, isEmpty);
      },
    );

    test('should store nothing when the house is not « repasser »', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').saveComeBackHint('samedi');

      expect(streets.saved, isEmpty);
    });

    test('should store nothing when the hint is too long', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').saveComeBackHint('a' * 21);

      expect(streets.saved, isEmpty);
      expect(houseNow('5').comeBack, comeBack('après 19h'));
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

        // Not awaited in between: « Repasser » is tapped and the hint
        // leaves its field at once. Run together, the hint would be judged
        // on a house not « repasser » yet, and dropped.
        final first = sheet.setStatus(VisitStatus.comeBack);
        final second = sheet.saveComeBackHint('samedi');
        await Future.wait([first, second]);

        expect(streets.saved.map((saved) => saved.$2.runtimeType), [
          HouseMarked,
          ComeBackSet,
        ]);
        expect(houseNow('7').status, VisitStatus.comeBack);
        expect(houseNow('7').comeBack, comeBack('samedi'));
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
        final next = sheet.saveComeBackHint('samedi');

        await expectLater(failed, throwsA(isA<FileSystemException>()));
        await next;
        expect(houseNow('5').status, VisitStatus.comeBack);
        expect(houseNow('5').comeBack, comeBack('samedi'));
      },
    );

    test('should store the text when the sheet has just closed', () async {
      phoneWith(_street());
      final subscription = open('5');
      await settled('5');
      final sheet = notifier('5');

      // The sheet saves its hint as it goes away: the notifier is then
      // about to be disposed.
      subscription.close();
      await sheet.saveComeBackHint('samedi');

      expect(houseNow('5').comeBack, comeBack('samedi'));
    });
  });
}
