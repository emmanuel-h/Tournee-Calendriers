import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
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

/// 3 changed by Paul yesterday evening; 5 to come back « après 19h » with a
/// note; 7 never changed; 8 a building.
final _yesterday = DateTime(2026, 11, 1, 18, 30);
final _houses = [
  House(
    number: n('3'),
    status: VisitStatus.nobodyHome,
    lastChange: ChangeStamp(by: paul, at: _yesterday.toUtc()),
  ),
  House(
    number: n('5'),
    comeBack: comeBack('après 19h'),
    note: note('chien dans le jardin'),
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
      expect(state.status, VisitStatus.toDo);
      expect(state.comeBack, isTrue);
      expect(state.comeBackHint, 'après 19h');
      expect(state.note, 'chien dans le jardin');
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
      expect(state.note, '');
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
        _street().setNote(n('7'), note('volets bleus'), by: paul, at: threePm),
      );
      await streets.save(changed, change);

      expect((await shown('7')).note, 'volets bleus');
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

    test('should clear the « repasser » when done is chosen', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').setStatus(VisitStatus.done);

      final state = await shown('5');
      expect(state.status, VisitStatus.done);
      expect(state.comeBack, isFalse);
      expect(state.comeBackHint, '');
      expect(state.canComeBack, isFalse);
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
    test('should store a « repasser » without hint when ticked', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').setComeBack(on: true);

      expect(
        streets.saved.single.$2,
        ComeBackSet(
          streetId: _id,
          before: houseBefore('7'),
          stamp: leaAtTwo,
          comeBack: ComeBack.withoutHint,
        ),
      );
      final state = await shown('7');
      expect(state.comeBack, isTrue);
      expect(state.comeBackHint, '');
    });

    test('should remove the « repasser » and its hint when unticked', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').setComeBack(on: false);

      expect(
        streets.saved.single.$2,
        ComeBackSet(
          streetId: _id,
          before: houseBefore('5'),
          stamp: leaAtTwo,
          comeBack: null,
        ),
      );
      expect((await shown('5')).comeBack, isFalse);
    });

    test('should keep the hint when ticked while already ticked', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').setComeBack(on: true);

      expect(streets.saved, isEmpty);
    });

    test('should store nothing when unticked while not ticked', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').setComeBack(on: false);

      expect(streets.saved, isEmpty);
    });

    test('should store nothing when the house is done', () async {
      phoneWith(_street());
      open('7');
      await settled('7');
      await notifier('7').setStatus(VisitStatus.done);
      streets.saved.clear();

      await notifier('7').setComeBack(on: true);

      expect(streets.saved, isEmpty);
      expect(houseNow('7').comeBack, isNull);
    });
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

    test('should store nothing when « repasser » is not ticked', () async {
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

      await notifier('5').saveComeBackHint('a' * 51);

      expect(streets.saved, isEmpty);
      expect(houseNow('5').comeBack, comeBack('après 19h'));
    });
  });

  group('saveNote', () {
    test('should store the trimmed note when it changed', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').saveNote(' volets bleus\n');

      expect(
        streets.saved.single.$2,
        NoteSet(
          streetId: _id,
          before: houseBefore('7'),
          stamp: leaAtTwo,
          note: note('volets bleus'),
        ),
      );
      expect((await shown('7')).note, 'volets bleus');
    });

    test('should erase the note when the text is blank', () async {
      phoneWith(_street());
      open('5');
      await settled('5');

      await notifier('5').saveNote('   ');

      expect(houseNow('5').note, Note.empty);
      expect((await shown('5')).note, '');
    });

    test(
      'should store nothing when the note is the same once trimmed',
      () async {
        phoneWith(_street());
        open('5');
        await settled('5');

        await notifier('5').saveNote('chien dans le jardin ');

        expect(streets.saved, isEmpty);
      },
    );

    test('should store nothing when the note is too long', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').saveNote('a' * 201);

      expect(streets.saved, isEmpty);
    });

    test('should store the note when 200 characters long', () async {
      phoneWith(_street());
      open('7');
      await settled('7');

      await notifier('7').saveNote('a' * 200);

      expect(houseNow('7').note, note('a' * 200));
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

        // Not awaited in between: the note leaves its field as « Fait » is
        // tapped. Run together, the second change would start from the
        // street without the note and lose it.
        final first = sheet.saveNote('volets bleus');
        final second = sheet.setStatus(VisitStatus.done);
        await Future.wait([first, second]);

        expect(streets.saved.map((saved) => saved.$2.runtimeType), [
          NoteSet,
          HouseMarked,
        ]);
        expect(houseNow('7').note, note('volets bleus'));
        expect(houseNow('7').status, VisitStatus.done);
      },
    );

    test(
      'should still run the next changes when one fails to be stored',
      () async {
        phoneWith(_street());
        open('7');
        await settled('7');
        final sheet = notifier('7');
        streets.failNextSave = const FileSystemException('disk full');

        final failed = sheet.setStatus(VisitStatus.done);
        final next = sheet.saveNote('volets bleus');

        await expectLater(failed, throwsA(isA<FileSystemException>()));
        await next;
        expect(houseNow('7').note, note('volets bleus'));
        expect(houseNow('7').status, VisitStatus.toDo);
      },
    );

    test('should store the text when the sheet has just closed', () async {
      phoneWith(_street());
      final subscription = open('7');
      await settled('7');
      final sheet = notifier('7');

      // The sheet saves its fields as it goes away: the notifier is then
      // about to be disposed.
      subscription.close();
      await sheet.saveNote('volets bleus');

      expect(houseNow('7').note, note('volets bleus'));
    });
  });
}
