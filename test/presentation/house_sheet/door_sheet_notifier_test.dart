import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
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
final _yesterday = DateTime(2026, 11, 1, 18, 30);

/// Door 11 of staircase A of number 8, nobody home, to come back, with a
/// note, changed by Paul yesterday.
final _door11 = Dwelling(
  label: d('11'),
  status: VisitStatus.nobodyHome,
  comeBack: comeBack('soir'),
  note: note('digicode 1234'),
  lastChange: ChangeStamp(by: paul, at: _yesterday.toUtc()),
);

/// 8: two staircases, RdC and 1er, two doors a floor, with its own note
/// and « repasser »; 10: a single staircase; 9: a single house.
final _houses = [
  House(
    number: n('8'),
    note: note('grille verte'),
    comeBack: comeBack('mardi'),
    lastChange: leaAtTwo,
    building: building(
      staircases: 2,
      topFloor: 1,
      doors: 2,
    ).withDwelling(escA, 1, _door11),
  ),
  House(number: n('9')),
  House(number: n('10'), building: building(topFloor: 0, doors: 1)),
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
  late ProviderContainer container;

  void phoneWith(Street street) {
    streets = FakeStreetRepository([street]);
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        clockProvider.overrideWithValue(FakeClock(twoPm)),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
      ],
    );
    addTearDown(container.dispose);
  }

  DoorSheetKey doorKey(String number, DwellingKey door) =>
      (street: _id, number: n(number), door: door);

  final a11 = DwellingKey(escA, 1, d('11'));
  final b01 = DwellingKey(escB, 0, d('01'));

  Future<HouseSheetState> door(String number, DwellingKey key) async {
    final provider = doorSheetProvider(doorKey(number, key));
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container.read(provider);
  }

  DoorSheetNotifier doorNotifier(String number, DwellingKey key) =>
      container.read(doorSheetProvider(doorKey(number, key)).notifier);

  Future<HouseSheetState> details(String number) async {
    final provider = buildingDetailsProvider((street: _id, number: n(number)));
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container.read(provider);
  }

  BuildingDetailsNotifier detailsNotifier(String number) => container.read(
    buildingDetailsProvider((street: _id, number: n(number))).notifier,
  );

  group('door sheet', () {
    test('should show the door, named with its staircase, when the building '
        'has several', () async {
      phoneWith(_street());

      final state = await door('8', a11) as HouseSheetShown;

      expect(state.subject, DoorSubject(staircase: escA));
      expect(state.streetName, 'Rue des Lilas');
      expect(state.number, n('8'));
      expect(state.status, VisitStatus.nobodyHome);
      expect(state.comeBack, isTrue);
      expect(state.comeBackHint, 'soir');
      expect(state.note, 'digicode 1234');
      expect(state.lastChange, ChangedEarlier(_yesterday));
      expect(state.canComeBack, isTrue);
    });

    test(
      'should leave the staircase unnamed when the building has one',
      () async {
        phoneWith(_street());

        final state =
            await door('10', DwellingKey(escA, 0, d('01'))) as HouseSheetShown;

        expect(state.subject, const DoorSubject(staircase: null));
        expect(state.status, VisitStatus.toDo);
        expect(state.comeBack, isFalse);
        expect(state.note, '');
        expect(state.lastChange, isNull);
      },
    );

    test(
      'should say the door is gone when the building has no such door',
      () async {
        phoneWith(_street());

        expect(
          await door('8', DwellingKey(escA, 5, d('51'))),
          isA<HouseSheetGone>(),
        );
      },
    );

    test(
      'should say the door is gone when the house is not a building',
      () async {
        phoneWith(_street());

        expect(await door('9', b01), isA<HouseSheetGone>());
      },
    );

    test(
      'should say the door is gone when the number is not in the street',
      () async {
        phoneWith(_street());

        expect(await door('12', b01), isA<HouseSheetGone>());
      },
    );

    test('should store the status of that door only, stamped', () async {
      phoneWith(_street());
      await door('8', b01);

      await doorNotifier('8', b01).setStatus(VisitStatus.done);

      expect(
        streets.saved.single.$2,
        DwellingMarked(
          streetId: _id,
          number: n('8'),
          staircase: escB,
          level: 0,
          before: Dwelling(label: d('01')),
          stamp: leaAtTwo,
          status: VisitStatus.done,
        ),
      );
      expect(
        (await door('8', b01) as HouseSheetShown).status,
        VisitStatus.done,
      );
    });

    test('should store the « repasser » of the door when ticked', () async {
      phoneWith(_street());
      await door('8', b01);

      await doorNotifier('8', b01).setComeBack(on: true);

      expect(
        streets.saved.single.$2,
        DwellingComeBackSet(
          streetId: _id,
          number: n('8'),
          staircase: escB,
          level: 0,
          before: Dwelling(label: d('01')),
          stamp: leaAtTwo,
          comeBack: ComeBack.withoutHint,
        ),
      );
    });

    test('should store the note of the door', () async {
      phoneWith(_street());
      await door('8', a11);

      await doorNotifier('8', a11).saveNote('chien');

      expect(
        streets.saved.single.$2,
        DwellingNoteSet(
          streetId: _id,
          number: n('8'),
          staircase: escA,
          level: 1,
          before: _door11,
          stamp: leaAtTwo,
          note: note('chien'),
        ),
      );
    });
  });

  group('building details', () {
    test('should show the building own marks without a status', () async {
      phoneWith(_street());

      final state = await details('8') as HouseSheetShown;

      expect(state.subject, isA<BuildingSubject>());
      expect(state.number, n('8'));
      expect(state.status, isNull);
      expect(state.comeBack, isTrue);
      expect(state.comeBackHint, 'mardi');
      expect(state.note, 'grille verte');
      expect(state.lastChange, ChangedToday(twoPm.toLocal()));
      expect(state.canComeBack, isTrue);
    });

    test('should say it is gone when the house is a single house', () async {
      phoneWith(_street());

      expect(await details('9'), isA<HouseSheetGone>());
    });

    test(
      'should say it is gone when the number is not in the street',
      () async {
        phoneWith(_street());

        expect(await details('12'), isA<HouseSheetGone>());
      },
    );

    test('should store no status', () async {
      phoneWith(_street());
      await details('8');

      await detailsNotifier('8').setStatus(VisitStatus.done);

      expect(streets.saved, isEmpty);
    });

    test('should store the building own note', () async {
      phoneWith(_street());
      await details('8');

      await detailsNotifier('8').saveNote('digicode 42');

      expect(
        streets.saved.single.$2,
        NoteSet(
          streetId: _id,
          before: _houses.first,
          stamp: leaAtTwo,
          note: note('digicode 42'),
        ),
      );
    });

    test('should drop the building own « repasser » when unticked', () async {
      phoneWith(_street());
      await details('8');

      await detailsNotifier('8').setComeBack(on: false);

      expect(streets[_id]!.houses.first.comeBack, isNull);
      expect(streets[_id]!.houses.first.building, _houses.first.building);
    });
  });
}
