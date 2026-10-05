import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/describe_building.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_notifier.dart';
import 'package:tournee_calendriers/presentation/building/adjust_doors_state.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// 8: staircase A 1er [11 done, 12], RdC [01 with a note, 02]; staircase
/// B 1er emptied, RdC [01]. 9: a single house. 10: one door left.
final _eight = valueOf(
  Building.create(
    style: DoorLabelStyle.floorAndNumber,
    staircases: [
      Staircase(
        name: escA,
        floors: [
          Floor(
            level: 1,
            dwellings: [
              Dwelling(label: d('11'), status: VisitStatus.done),
              Dwelling(label: d('12')),
            ],
          ),
          Floor(
            level: 0,
            dwellings: [
              Dwelling(label: d('01'), note: note('digicode 12')),
              Dwelling(label: d('02')),
            ],
          ),
        ],
      ),
      Staircase(
        name: escB,
        floors: [
          Floor(level: 1, dwellings: const []),
          Floor(level: 0, dwellings: [Dwelling(label: d('01'))]),
        ],
      ),
    ],
  ),
);

/// A building of one door, marked done.
final _ten = building(
  topFloor: 0,
  doors: 1,
).withDwelling(escA, 0, Dwelling(label: d('01'), status: VisitStatus.done));

Street _street({List<House>? houses, bool deleted = false}) => valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses:
        houses ??
        [
          House(number: n('8'), building: _eight),
          House(number: n('9')),
          House(number: n('10'), building: _ten),
        ],
    deletion: deleted ? leaAtTwo : null,
  ),
);

DwellingKey _key(String staircase, int? level, String label) =>
    DwellingKey(staircase == 'A' ? escA : escB, level, d(label));

/// Shows the street of [inner] but has lost it when a use case loads it:
/// the street went between the read and the tap.
final class _LostStreets implements StreetRepository {
  _LostStreets(this.inner);

  final FakeStreetRepository inner;

  @override
  Stream<Street?> watch(StreetId id) => inner.watch(id);

  @override
  Future<Street?> find(StreetId id) async => null;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeStreetRepository streets;
  late ProviderContainer container;
  late BuildingGridKey building8;

  /// A container whose phone holds [street] (none when null), adjusting
  /// the building at [number]; [lost] loses the street when a use case
  /// loads it.
  void phoneWith(Street? street, {String number = '8', bool lost = false}) {
    streets = FakeStreetRepository([?street]);
    building8 = (street: _id, number: n(number));
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(
          lost ? _LostStreets(streets) : streets,
        ),
        clockProvider.overrideWithValue(FakeClock(twoPm)),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the auto-disposed provider alive, as the screen does.
    container.listen(adjustDoorsProvider(building8), (_, _) {});
  }

  AdjustDoorsNotifier adjust() =>
      container.read(adjustDoorsProvider(building8).notifier);

  Future<AdjustDoorsState> settled() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(adjustDoorsProvider(building8));
  }

  Future<AdjustDoorsShown> shown() async =>
      (await settled()) as AdjustDoorsShown;

  /// The floors shown, one line each: `1: A1-11 A1-12` (level, door ids).
  Future<List<String>> floors() async => [
    for (final floor in (await shown()).floors)
      '${floor.level}: ${[for (final door in floor.doors) door.id].join(' ')}'
          .trim(),
  ];

  /// The building at [number] as stored now.
  Building stored([String number = '8']) => streets[_id]!.houses
      .firstWhere((house) => house.number == n(number))
      .building!;

  group('view', () {
    test('should be loading before the street is read', () {
      phoneWith(_street());

      expect(
        container.read(adjustDoorsProvider(building8)),
        isA<AdjustDoorsLoading>(),
      );
    });

    test('should show the floors of the first staircase when the building is '
        'read', () async {
      phoneWith(_street());

      final state = await shown();

      expect(state.streetName, 'Rue des Lilas');
      expect(state.number, n('8'));
      expect(state.staircases, [escA, escB]);
      expect(state.selected, escA);
      expect(state.showsStaircases, isTrue);
      expect(await floors(), ['1: A1-11 A1-12', '0: A0-01 A0-02']);
    });

    test('should list an empty floor when its staircase is selected', () async {
      phoneWith(_street());
      await settled();

      adjust().selectStaircase(escB);

      expect((await shown()).selected, escB);
      expect(await floors(), ['1:', '0: B0-01']);
    });

    test('should go back to the first staircase and hide the control when '
        'the chosen one disappears', () async {
      phoneWith(_street());
      await settled();
      adjust().selectStaircase(escB);
      await container.read(describeBuildingProvider)(
        _id,
        n('8'),
        LayOutBuilding(plan(topFloor: 0, doors: 2)),
      );

      final state = await shown();

      expect(state.selected, escA);
      expect(state.showsStaircases, isFalse);
      expect(await floors(), ['0: A0-01 A0-02']);
    });

    test('should be gone when the number is a single house', () async {
      phoneWith(_street(), number: '9');

      expect(await settled(), isA<AdjustDoorsGone>());
    });

    test('should be gone when the number is not in the street', () async {
      phoneWith(_street(), number: '11');

      expect(await settled(), isA<AdjustDoorsGone>());
    });

    test('should be gone when the street is in the Corbeille', () async {
      phoneWith(_street(deleted: true));

      expect(await settled(), isA<AdjustDoorsGone>());
    });

    test('should be gone when the street is not on the phone', () async {
      phoneWith(null);

      expect(await settled(), isA<AdjustDoorsGone>());
    });
  });

  group('add a door', () {
    test('should add the next door at the end of the floor and keep the '
        'marks of the others', () async {
      phoneWith(_street());
      await settled();

      final outcome = await adjust().addDoor(escA, 1);

      expect(outcome, DoorEditApplied(_key('A', 1, '13')));
      expect(await floors(), ['1: A1-11 A1-12 A1-13', '0: A0-01 A0-02']);
      expect(stored().dwellingAt(_key('A', 1, '11'))!.status, VisitStatus.done);
      expect(
        stored().dwellingAt(_key('A', 0, '01'))!.note,
        note('digicode 12'),
      );
      final (_, change) = streets.saved.single;
      expect((change as BuildingLaidOut).stamp, leaAtTwo);
    });

    test('should add a door to an empty floor', () async {
      phoneWith(_street());
      await settled();
      adjust().selectStaircase(escB);

      expect(
        await adjust().addDoor(escB, 1),
        DoorEditApplied(_key('B', 1, '11')),
      );

      expect(await floors(), ['1: B1-11', '0: B0-01']);
    });

    test('should refuse when the floor has no letter left', () async {
      phoneWith(
        _street(
          houses: [
            House(
              number: n('8'),
              building: building(
                topFloor: 0,
                doors: 26,
                style: DoorLabelStyle.floorAndLetter,
              ),
            ),
          ],
        ),
      );
      await settled();

      final outcome = await adjust().addDoor(escA, 0);

      expect(outcome, const DoorEditRefused(BuildingChangeFailure.noLabelLeft));
      expect(streets.saved, isEmpty);
    });

    test('should refuse as a gone building when the street went', () async {
      phoneWith(_street(), lost: true);
      await settled();

      expect(
        await adjust().addDoor(escA, 1),
        const DoorEditRefused(BuildingChangeFailure.unknownHouse),
      );
    });
  });

  group('remove a door', () {
    test('should remove a door without marks at once and keep the marks of '
        'the others', () async {
      phoneWith(_street());
      await settled();

      final outcome = await adjust().remove(_key('A', 1, '12'));

      expect(outcome, DoorEditApplied(_key('A', 1, '12')));
      expect(await floors(), ['1: A1-11', '0: A0-01 A0-02']);
      expect(stored().dwellingAt(_key('A', 1, '11'))!.status, VisitStatus.done);
    });

    test('should ask first when the door has a mark', () async {
      phoneWith(_street());
      await settled();

      final outcome = await adjust().remove(_key('A', 0, '01'));

      expect(outcome, const DoorEditNeedsConfirmation());
      expect(streets.saved, isEmpty);
    });

    test('should remove a door with a mark when confirmed', () async {
      phoneWith(_street());
      await settled();

      final outcome = await adjust().remove(
        _key('A', 1, '11'),
        confirmed: true,
      );

      expect(outcome, DoorEditApplied(_key('A', 1, '11')));
      expect(stored().dwellingAt(_key('A', 1, '11')), isNull);
    });

    test('should refuse the last door of the building without asking, even '
        'with a mark', () async {
      phoneWith(_street(), number: '10');
      await settled();

      final outcome = await adjust().remove(_key('A', 0, '01'));

      expect(
        outcome,
        const DoorEditRefused(BuildingChangeFailure.lastDwelling),
      );
      expect(streets.saved, isEmpty);
    });

    test('should refuse a door that is no longer in the building', () async {
      phoneWith(_street());
      await settled();

      expect(
        await adjust().remove(_key('A', 1, '13')),
        const DoorEditRefused(BuildingChangeFailure.unknownDwelling),
      );
      expect(streets.saved, isEmpty);
    });

    test('should refuse when the number is no longer a building', () async {
      phoneWith(_street(), number: '9');
      await settled();

      expect(
        await adjust().remove(_key('A', 0, '01')),
        const DoorEditRefused(BuildingChangeFailure.notABuilding),
      );
    });

    test('should refuse as a gone building when the street went', () async {
      phoneWith(_street(), lost: true);
      await settled();

      expect(
        await adjust().remove(_key('A', 1, '12')),
        const DoorEditRefused(BuildingChangeFailure.unknownHouse),
      );
    });
  });

  group('rename a door', () {
    test(
      'should give Gauche to a door on two floors and keep its marks',
      () async {
        phoneWith(_street());
        await settled();

        expect(
          await adjust().rename(_key('A', 1, '11'), 'Gauche'),
          DoorRenamed(_key('A', 1, 'Gauche')),
        );
        expect(
          await adjust().rename(_key('A', 0, '01'), '  Gauche '),
          DoorRenamed(_key('A', 0, 'Gauche')),
        );

        expect(await floors(), ['1: A1-Gauche A1-12', '0: A0-Gauche A0-02']);
        expect(
          stored().dwellingAt(_key('A', 1, 'Gauche'))!.status,
          VisitStatus.done,
        );
        expect(
          stored().dwellingAt(_key('A', 0, 'Gauche'))!.note,
          note('digicode 12'),
        );
      },
    );

    test('should refuse a name another door of the floor has', () async {
      phoneWith(_street());
      await settled();

      expect(
        await adjust().rename(_key('A', 1, '12'), '11'),
        const DoorRenameRefused(BuildingChangeFailure.duplicateLabel),
      );
      expect(streets.saved, isEmpty);
    });

    test('should refuse a blank name', () async {
      phoneWith(_street());
      await settled();

      expect(
        await adjust().rename(_key('A', 1, '12'), '   '),
        const DoorLabelInvalid(DwellingLabelFailure.blank),
      );
      expect(streets.saved, isEmpty);
    });

    test('should refuse a name longer than 12 characters', () async {
      phoneWith(_street());
      await settled();

      expect(
        await adjust().rename(_key('A', 1, '12'), 'Fond de cour'),
        DoorRenamed(_key('A', 1, 'Fond de cour')),
      );
      expect(
        await adjust().rename(_key('A', 1, 'Fond de cour'), 'Fond de cours'),
        const DoorLabelInvalid(DwellingLabelFailure.tooLong),
      );
      expect(streets.saved, hasLength(1));
    });

    test(
      'should store nothing when the name is the one the door has',
      () async {
        phoneWith(_street());
        await settled();

        expect(
          await adjust().rename(_key('A', 1, '12'), ' 12 '),
          const DoorNameKept(),
        );
        expect(streets.saved, isEmpty);
      },
    );

    test('should refuse as a gone building when the street went', () async {
      phoneWith(_street(), lost: true);
      await settled();

      expect(
        await adjust().rename(_key('A', 1, '12'), 'Droite'),
        const DoorRenameRefused(BuildingChangeFailure.unknownHouse),
      );
    });
  });

  group('undo', () {
    test('should bring a removed door back with its marks, once', () async {
      phoneWith(_street());
      await settled();
      await adjust().remove(_key('A', 1, '11'), confirmed: true);

      await adjust().undo();

      expect(await floors(), ['1: A1-11 A1-12', '0: A0-01 A0-02']);
      expect(stored().dwellingAt(_key('A', 1, '11'))!.status, VisitStatus.done);
      expect(streets.saved, hasLength(2));

      await adjust().undo();

      expect(streets.saved, hasLength(2));
    });

    test('should take a door added away', () async {
      phoneWith(_street());
      await settled();
      await adjust().addDoor(escA, 1);

      await adjust().undo();

      expect(await floors(), ['1: A1-11 A1-12', '0: A0-01 A0-02']);
      expect(streets.saved, hasLength(2));
    });

    test('should give a renamed door its name back, its marks kept', () async {
      phoneWith(_street());
      await settled();
      await adjust().rename(_key('A', 1, '11'), 'Gauche');

      await adjust().undo();

      expect(await floors(), ['1: A1-11 A1-12', '0: A0-01 A0-02']);
      expect(stored().dwellingAt(_key('A', 1, '11'))!.status, VisitStatus.done);
    });

    test('should do nothing when nothing was changed', () async {
      phoneWith(_street());
      await settled();

      await adjust().undo();

      expect(streets.saved, isEmpty);
    });
  });
}
