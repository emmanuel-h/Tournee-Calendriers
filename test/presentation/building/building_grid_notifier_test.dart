import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// 8: staircase A RdC–1er with two doors a floor, B the RdC alone with
/// two doors. A 11 done, A 12 nobody home (three tries), A 01 to come back,
/// B 01 done: 2 doors done of 6. 9: a single house; 10: unknown floors.
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
              Dwelling(
                label: d('12'),
                status: VisitStatus.nobodyHome,
                tries: tries(3),
              ),
            ],
          ),
          Floor(
            level: 0,
            dwellings: [
              Dwelling(
                label: d('01'),
                status: VisitStatus.comeBack,
                comeBack: comeBack('2026-11-03', hour: 18),
              ),
              Dwelling(label: d('02')),
            ],
          ),
        ],
      ),
      Staircase(
        name: escB,
        floors: [
          // An emptied floor: the grid leaves it out.
          Floor(level: 1, dwellings: const []),
          Floor(
            level: 0,
            dwellings: [
              Dwelling(label: d('01'), status: VisitStatus.done),
              Dwelling(label: d('02')),
            ],
          ),
        ],
      ),
    ],
  ),
);

Street _street() => valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('8'), building: _eight),
      House(number: n('9')),
      House(number: n('10'), building: building(topFloor: null, doors: 3)),
    ],
  ),
);

DwellingKey _key(String staircase, int? level, String label) =>
    DwellingKey(staircase == 'A' ? escA : escB, level, d(label));

void main() {
  late FakeStreetRepository streets;
  late ProviderContainer container;

  void phoneWith(Street? street) {
    streets = FakeStreetRepository([?street]);
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        clockProvider.overrideWithValue(FakeClock(twoPm)),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
        openRoundStoreProvider.overrideWithValue(FakeOpenRoundStore()),
        mySectorsStoreProvider.overrideWithValue(FakeMySectorsStore()),
      ],
    );
    addTearDown(container.dispose);
  }

  BuildingGridKey keyOf(String number) => (street: _id, number: n(number));

  Future<BuildingGridState> settled(String number) async {
    final provider = buildingGridProvider(keyOf(number));
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container.read(provider);
  }

  Future<BuildingGridShown> shown(String number) async =>
      (await settled(number)) as BuildingGridShown;

  BuildingGridNotifier notifier(String number) =>
      container.read(buildingGridProvider(keyOf(number)).notifier);

  Dwelling doorNow(DwellingKey key) => streets[_id]!.houses
      .singleWhere((house) => house.number == n('8'))
      .building!
      .dwellingAt(key)!;

  group('state', () {
    test('should be loading before the street is read', () {
      phoneWith(_street());
      final provider = buildingGridProvider(keyOf('8'));
      container.listen(provider, (_, _) {});

      expect(container.read(provider), isA<BuildingGridLoading>());
    });

    test('should count the doors of the whole building and of each '
        'staircase', () async {
      phoneWith(_street());

      final state = await shown('8');

      expect(state.streetName, 'Rue des Lilas');
      expect(state.number, n('8'));
      expect(state.done, 2);
      expect(state.total, 6);
      expect(state.staircases, [
        (name: escA, done: 1, total: 4),
        (name: escB, done: 1, total: 2),
      ]);
      expect(state.showsStaircases, isTrue);
    });

    test('should count a refused door with the done ones', () async {
      final (refusing, _) = valueOf(
        _street().markDwelling(
          n('8'),
          _key('A', 0, '02'),
          VisitStatus.refused,
          by: lea,
          at: twoPm,
        ),
      );
      phoneWith(refusing);

      final state = await shown('8');

      expect(state.done, 3);
      expect(state.total, 6);
      expect(state.staircases, [
        (name: escA, done: 2, total: 4),
        (name: escB, done: 1, total: 2),
      ]);
    });

    test('should show the first staircase, floors top first, each door with '
        'its look', () async {
      phoneWith(_street());

      final state = await shown('8');

      expect(state.selected, escA);
      expect(state.floors.map((floor) => floor.level), [1, 0]);
      expect(state.floors[0].doors, [
        (key: _key('A', 1, '11'), mark: const DoneMark(), tries: null),
        (key: _key('A', 1, '12'), mark: const NobodyHomeMark(), tries: 3),
      ]);
      expect(state.floors[1].doors, [
        (key: _key('A', 0, '01'), mark: const ComeBackMark(), tries: null),
        (key: _key('A', 0, '02'), mark: const ToDoMark(), tries: null),
      ]);
    });

    test('should show the « Logements » row and no staircase control when '
        'the floors are unknown in a single staircase', () async {
      phoneWith(_street());

      final state = await shown('10');

      expect(state.showsStaircases, isFalse);
      expect(state.floors.single.level, isNull);
      expect(state.floors.single.doors.map((door) => door.key.label.text), [
        '1',
        '2',
        '3',
      ]);
    });

    test('should say a door has a mark, so going back to a house asks '
        'first', () async {
      phoneWith(_street());

      expect((await shown('8')).hasMarks, isTrue);
    });

    test('should say no door has a mark in a new building', () async {
      phoneWith(_street());

      expect((await shown('10')).hasMarks, isFalse);
    });

    test('should say it is gone when the house is a single house', () async {
      phoneWith(_street());

      expect(await settled('9'), isA<BuildingGridGone>());
    });

    test(
      'should say it is gone when the number is not in the street',
      () async {
        phoneWith(_street());

        expect(await settled('12'), isA<BuildingGridGone>());
      },
    );

    test('should say it is gone when the street is not on the phone', () async {
      phoneWith(null);

      expect(await settled('8'), isA<BuildingGridGone>());
    });

    test('should say it is gone when the street is in the Corbeille', () async {
      final (deleted, _) = _street().delete(by: lea, at: twoPm);
      phoneWith(deleted);

      expect(await settled('8'), isA<BuildingGridGone>());
    });
  });

  group('selectStaircase', () {
    test('should show the floors of the chosen staircase, empty ones left '
        'out', () async {
      phoneWith(_street());
      await settled('8');

      notifier('8').selectStaircase(escB);

      final state = await shown('8');
      expect(state.selected, escB);
      expect(state.floors.map((floor) => floor.level), [0]);
      expect(state.floors.single.doors.first.key, _key('B', 0, '01'));
    });

    test('should go back to the first staircase when the chosen one is '
        'gone', () async {
      phoneWith(_street());
      await settled('8');
      notifier('8').selectStaircase(escB);

      final (changed, change) = valueOf(
        streets[_id]!.describeBuilding(
          n('8'),
          plan(topFloor: 0, doors: 1),
          by: paul,
          at: threePm,
        ),
      );
      await streets.save(changed, change);

      final state = await shown('8');
      expect(state.selected, escA);
      expect(state.staircases, [(name: escA, done: 0, total: 1)]);
    });
  });

  group('undo', () {
    /// Chooses [status] in the picker of door [key] of 8, then keeps what
    /// it stored for « Annuler », as the grid does.
    Future<void> pick(DwellingKey key, VisitStatus status) async {
      final door = (street: _id, number: n('8'), door: key);
      final picker = container.listen(doorSheetProvider(door), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final stored = await container
          .read(doorSheetProvider(door).notifier)
          .setStatus(status);
      picker.close();
      notifier('8').keepForUndo(stored!.change);
    }

    test('should put back the door whose status was chosen last', () async {
      phoneWith(_street());
      await settled('8');
      await pick(_key('A', 0, '01'), VisitStatus.done);
      await pick(_key('A', 0, '02'), VisitStatus.done);

      await notifier('8').undo();

      expect(doorNow(_key('A', 0, '02')), Dwelling(label: d('02')));
      // 01 was « repasser »: its status, not undone, stays done.
      expect(doorNow(_key('A', 0, '01')).status, VisitStatus.done);
    });

    test('should undo only once', () async {
      phoneWith(_street());
      await settled('8');
      await pick(_key('A', 0, '02'), VisitStatus.done);
      await notifier('8').undo();
      final saves = streets.saved.length;

      await notifier('8').undo();

      expect(streets.saved, hasLength(saves));
    });

    test('should do nothing when nothing was stored', () async {
      phoneWith(_street());
      await settled('8');

      await notifier('8').undo();

      expect(streets.saved, isEmpty);
    });
  });
}
