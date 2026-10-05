import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_notifier.dart';
import 'package:tournee_calendriers/presentation/building/building_grid_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// 8: staircase A RdC–1er with two doors a floor, B the RdC alone with
/// two doors. A 11 done, A 12 nobody home, A 01 to come back with a note,
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
              Dwelling(label: d('12'), status: VisitStatus.nobodyHome),
            ],
          ),
          Floor(
            level: 0,
            dwellings: [
              Dwelling(
                label: d('01'),
                status: VisitStatus.comeBack,
                comeBack: comeBack('soir'),
                note: note('chien'),
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

  void phoneWith(Street? street) {
    streets = FakeStreetRepository([?street]);
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        clockProvider.overrideWithValue(FakeClock(twoPm)),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
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

    test('should show the first staircase, floors top first, each door with '
        'its look', () async {
      phoneWith(_street());

      final state = await shown('8');

      expect(state.selected, escA);
      expect(state.floors.map((floor) => floor.level), [1, 0]);
      expect(state.floors[0].doors, [
        (key: _key('A', 1, '11'), mark: const DoneMark(), hasNote: false),
        (key: _key('A', 1, '12'), mark: const NobodyHomeMark(), hasNote: false),
      ]);
      expect(state.floors[1].doors, [
        (key: _key('A', 0, '01'), mark: const ComeBackMark(), hasNote: true),
        (key: _key('A', 0, '02'), mark: const ToDoMark(), hasNote: false),
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

  group('cycle', () {
    test('should give the door its next status and say what changed', () async {
      phoneWith(_street());
      await settled('8');

      final marked = await notifier('8').cycle(_key('A', 0, '02'));

      expect(marked, (
        key: _key('A', 0, '02'),
        status: VisitStatus.done,
        namesStaircase: true,
      ));
      expect(
        streets.saved.single.$2,
        DwellingMarked(
          streetId: _id,
          number: n('8'),
          staircase: escA,
          level: 0,
          before: Dwelling(label: d('02')),
          stamp: leaAtTwo,
          status: VisitStatus.done,
        ),
      );
      final state = await shown('8');
      expect(state.done, 3);
      expect(state.staircases.first, (name: escA, done: 2, total: 4));
    });

    test(
      'should go from done to nobody home, to come back, then to do',
      () async {
        phoneWith(_street());
        await settled('8');

        await notifier('8').cycle(_key('A', 1, '11'));
        expect(doorNow(_key('A', 1, '11')).status, VisitStatus.nobodyHome);

        await notifier('8').cycle(_key('A', 1, '11'));
        expect(doorNow(_key('A', 1, '11')).status, VisitStatus.comeBack);
        expect(doorNow(_key('A', 1, '11')).comeBack, ComeBack.withoutHint);

        await notifier('8').cycle(_key('A', 1, '11'));
        expect(doorNow(_key('A', 1, '11')).status, VisitStatus.toDo);
        expect(doorNow(_key('A', 1, '11')).comeBack, isNull);
      },
    );

    test('should not name the staircase when the building has one', () async {
      phoneWith(_street());
      await settled('10');

      final marked = await notifier('10').cycle(_key('A', null, '2'));

      expect(marked?.namesStaircase, isFalse);
    });

    test(
      'should change nothing when the door is not in the building',
      () async {
        phoneWith(_street());
        await settled('8');

        final marked = await notifier('8').cycle(_key('A', 5, '51'));

        expect(marked, isNull);
        expect(streets.saved, isEmpty);
      },
    );

    test('should change nothing when the street refuses the tap', () async {
      streets = FakeStreetRepository([_street()]);
      container = ProviderContainer(
        overrides: [
          streetRepositoryProvider.overrideWithValue(_LostStreets(streets)),
          clockProvider.overrideWithValue(FakeClock(twoPm)),
          identityProvider.overrideWithValue(FakeIdentity(lea)),
        ],
      );
      addTearDown(container.dispose);
      await settled('8');

      final marked = await notifier('8').cycle(_key('A', 0, '02'));
      await notifier('8').undo();

      expect(marked, isNull);
      expect(streets.saved, isEmpty);
    });

    test('should change nothing before the street is read', () async {
      phoneWith(_street());

      final marked = await notifier('8').cycle(_key('A', 0, '02'));

      expect(marked, isNull);
      expect(streets.saved, isEmpty);
    });
  });

  group('undo', () {
    test('should put back the door the last tap changed', () async {
      phoneWith(_street());
      await settled('8');
      await notifier('8').cycle(_key('A', 0, '01'));
      await notifier('8').cycle(_key('A', 0, '02'));

      await notifier('8').undo();

      expect(doorNow(_key('A', 0, '02')), Dwelling(label: d('02')));
      // 01 was « repasser »: its tap, not undone, made it to do.
      expect(doorNow(_key('A', 0, '01')).status, VisitStatus.toDo);
    });

    test('should undo only once', () async {
      phoneWith(_street());
      await settled('8');
      await notifier('8').cycle(_key('A', 0, '02'));
      await notifier('8').undo();
      final saves = streets.saved.length;

      await notifier('8').undo();

      expect(streets.saved, hasLength(saves));
    });

    test('should do nothing when nothing was tapped', () async {
      phoneWith(_street());
      await settled('8');

      await notifier('8').undo();

      expect(streets.saved, isEmpty);
    });
  });
}
