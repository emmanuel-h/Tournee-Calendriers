import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/building/building_setup_notifier.dart';
import 'package:tournee_calendriers/presentation/building/building_setup_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// 7: a single house with a note; 8: two staircases RdC–3e, three doors a
/// floor, labelled 5A, its 3e door 3C of staircase B done; 10: a building
/// whose floors are unknown.
final _seven = House(number: n('7'), note: note('volets bleus'));
final _eight = House(
  number: n('8'),
  building: building(
    staircases: 2,
    topFloor: 3,
    doors: 3,
    style: DoorLabelStyle.floorAndLetter,
  ).withDwelling(escB, 3, Dwelling(label: d('3C'), status: VisitStatus.done)),
);

/// Staircase A: RdC of 3 doors, 1er of 1, 2e of 2; staircase B: one
/// « Logements » row of 2 doors. « Libres » labels.
final _uneven = valueOf(
  Building.create(
    style: DoorLabelStyle.free,
    staircases: [
      Staircase(
        name: escA,
        floors: [
          Floor(
            level: 2,
            dwellings: [
              Dwelling(label: d('1')),
              Dwelling(label: d('2')),
            ],
          ),
          Floor(level: 1, dwellings: [Dwelling(label: d('1'))]),
          Floor(
            level: 0,
            dwellings: [
              for (final l in ['1', '2', '3']) Dwelling(label: d(l)),
            ],
          ),
        ],
      ),
      Staircase(
        name: escB,
        floors: [
          Floor(
            level: null,
            dwellings: [
              Dwelling(label: d('1')),
              Dwelling(label: d('2')),
            ],
          ),
        ],
      ),
    ],
  ),
);

Street _street({List<House>? houses}) => valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses:
        houses ??
        [
          _seven,
          _eight,
          House(number: n('10'), building: building(topFloor: null, doors: 2)),
        ],
  ),
);

/// Shows the street of [inner] but has lost it when a use case loads it.
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

  void phoneWith(Street? street, {bool lost = false}) {
    streets = FakeStreetRepository([?street]);
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
  }

  BuildingSetupKey keyOf(String number) => (street: _id, number: n(number));

  Future<BuildingSetupState> settled(String number) async {
    final provider = buildingSetupProvider(keyOf(number));
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container.read(provider);
  }

  Future<BuildingSetupShown> shown(String number) async =>
      (await settled(number)) as BuildingSetupShown;

  BuildingSetupNotifier notifier(String number) =>
      container.read(buildingSetupProvider(keyOf(number)).notifier);

  /// Opens the sheet of [number] and runs [steps] on its notifier.
  Future<BuildingSetupShown> after(
    String number,
    void Function(BuildingSetupNotifier setup) steps,
  ) async {
    await settled(number);
    steps(notifier(number));
    return shown(number);
  }

  group('state', () {
    test('should be loading before the street is read', () {
      phoneWith(_street());
      final provider = buildingSetupProvider(keyOf('7'));
      container.listen(provider, (_, _) {});

      expect(container.read(provider), isA<BuildingSetupLoading>());
    });

    test('should start a single house at one staircase, RdC–2e, two doors '
        'labelled 51', () async {
      phoneWith(_street());

      final state = await shown('7');

      expect(state.streetName, 'Rue des Lilas');
      expect(state.number, n('7'));
      expect(state.plan, plan(topFloor: 2, doors: 2));
      expect(state.refusal, isNull);
      expect(state.preview.dwellings, 6);
    });

    test('should start a building from its layout', () async {
      phoneWith(_street());

      final state = await shown('8');

      expect(
        state.plan,
        plan(
          staircases: 2,
          topFloor: 3,
          doors: 3,
          style: DoorLabelStyle.floorAndLetter,
        ),
      );
    });

    test(
      'should start a building whose floors are unknown at unknown',
      () async {
        phoneWith(_street());

        expect((await shown('10')).plan, plan(topFloor: null, doors: 2));
      },
    );

    test('should start an uneven building at its largest floor', () async {
      final uneven = valueOf(
        Building.create(
          style: DoorLabelStyle.free,
          staircases: [
            Staircase(
              name: escA,
              floors: [
                Floor(level: 4, dwellings: [Dwelling(label: d('1'))]),
                Floor(
                  level: 0,
                  dwellings: [
                    for (final l in ['1', '2', '3']) Dwelling(label: d(l)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      phoneWith(
        _street(
          houses: [House(number: n('8'), building: uneven)],
        ),
      );

      expect(
        (await shown('8')).plan,
        plan(topFloor: 4, doors: 3, style: DoorLabelStyle.free),
      );
    });

    test('should start from the default when the building is larger than a '
        'plan allows', () async {
      // One staircase: the RdC with 20 doors and the 29e with one. A plan
      // of 30 floors × 20 doors would pass 500 dwellings.
      final odd = valueOf(
        Building.create(
          style: DoorLabelStyle.floorAndNumber,
          staircases: [
            Staircase(
              name: escA,
              floors: [
                Floor(level: 29, dwellings: [Dwelling(label: d('291'))]),
                Floor(
                  level: 0,
                  dwellings: [
                    for (var door = 1; door <= 20; door++)
                      Dwelling(label: d('$door')),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      phoneWith(
        _street(
          houses: [House(number: n('8'), building: odd)],
        ),
      );

      expect((await shown('8')).plan, plan(topFloor: 2, doors: 2));
    });

    test('should start each staircase from its own floors, unticked, when '
        'they differ', () async {
      // A: RdC–2e, its largest floor 3 doors; B: unknown floors, 2 doors.
      phoneWith(
        _street(
          houses: [House(number: n('8'), building: _uneven)],
        ),
      );

      final state = await shown('8');

      expect(state.plan.staircases, const [
        StaircasePlan(topFloor: 2, doorsPerFloor: 3),
        StaircasePlan(topFloor: null, doorsPerFloor: 2),
      ]);
      expect(state.plan.style, DoorLabelStyle.free);
      expect(state.sameForEach, isFalse);
      expect(state.stepsEachStaircase, isTrue);
    });

    test('should start ticked when every staircase is alike', () async {
      phoneWith(_street());

      final state = await shown('8');

      expect(state.sameForEach, isTrue);
      expect(state.offersSameForEach, isTrue);
      expect(state.stepsEachStaircase, isFalse);
    });

    test('should not offer the box for a single staircase', () async {
      phoneWith(_street());

      final state = await shown('7');

      expect(state.sameForEach, isTrue);
      expect(state.offersSameForEach, isFalse);
      expect(state.stepsEachStaircase, isFalse);
    });

    test(
      'should say it is gone when the number is not in the street',
      () async {
        phoneWith(_street());

        expect(await settled('12'), isA<BuildingSetupGone>());
      },
    );

    test('should say it is gone when the street is in the Corbeille', () async {
      final (deleted, _) = _street().delete(by: lea, at: twoPm);
      phoneWith(deleted);

      expect(await settled('7'), isA<BuildingSetupGone>());
    });

    test('should keep the answers when the street changes', () async {
      phoneWith(_street());
      await after('7', (setup) => setup.addDoor());

      final (changed, change) = valueOf(
        _street().setNote(n('7'), note('chien'), by: paul, at: threePm),
      );
      await streets.save(changed, change);

      expect((await shown('7')).plan.staircases.first.doorsPerFloor, 3);
    });
  });

  group('steppers', () {
    test('should add and remove a staircase', () async {
      phoneWith(_street());

      expect(
        (await after('7', (s) => s.addStaircase())).plan.staircaseCount,
        2,
      );
      expect(
        (await after('7', (s) => s.removeStaircase())).plan.staircaseCount,
        1,
      );
    });

    test('should refuse fewer than one staircase and keep the plan', () async {
      phoneWith(_street());

      final state = await after('7', (s) => s.removeStaircase());

      expect(state.refusal, BuildingPlanFailure.noStaircase);
      expect(state.plan, plan(topFloor: 2, doors: 2));
    });

    test('should refuse a 27th staircase', () async {
      phoneWith(_street(houses: [House(number: n('7'))]));
      await settled('7');
      for (var i = 0; i < 25; i++) {
        notifier('7').addStaircase();
      }
      expect((await shown('7')).plan.staircaseCount, 26);

      final state = await after('7', (s) => s.addStaircase());

      expect(state.refusal, BuildingPlanFailure.tooManyStaircases);
      expect(state.plan.staircaseCount, 26);
    });

    test('should clear the refusal at the next step taken', () async {
      phoneWith(_street());
      await after('7', (s) => s.removeStaircase());

      final state = await after('7', (s) => s.addDoor());

      expect(state.refusal, isNull);
      expect(state.plan.staircases.first.doorsPerFloor, 3);
    });

    test('should add a floor above the top one', () async {
      phoneWith(_street());

      expect(
        (await after('7', (s) => s.addFloor())).plan.staircases.first.topFloor,
        3,
      );
    });

    test('should go from the RdC down to unknown floors, and back', () async {
      phoneWith(_street());

      final down = await after('7', (s) {
        s.removeFloor();
        s.removeFloor();
      });
      expect(down.plan.staircases.first.topFloor, 0);

      expect(
        (await after(
          '7',
          (s) => s.removeFloor(),
        )).plan.staircases.first.topFloor,
        isNull,
      );
      expect(
        (await after('7', (s) => s.addFloor())).plan.staircases.first.topFloor,
        0,
      );
    });

    test('should refuse to go below unknown floors', () async {
      phoneWith(_street());

      final state = await after('10', (s) => s.removeFloor());

      expect(state.refusal, BuildingPlanFailure.belowGroundFloor);
      expect(state.plan.staircases.first.topFloor, isNull);
    });

    test('should refuse a floor above the 50th', () async {
      phoneWith(_street());
      await settled('7');
      notifier('7').removeDoor();
      for (var i = 0; i < 48; i++) {
        notifier('7').addFloor();
      }
      expect((await shown('7')).plan.staircases.first.topFloor, 50);

      final state = await after('7', (s) => s.addFloor());

      expect(state.refusal, BuildingPlanFailure.tooManyFloors);
      expect(state.plan.staircases.first.topFloor, 50);
    });

    test('should add and remove a door per floor', () async {
      phoneWith(_street());

      expect(
        (await after(
          '7',
          (s) => s.addDoor(),
        )).plan.staircases.first.doorsPerFloor,
        3,
      );
      expect(
        (await after(
          '7',
          (s) => s.removeDoor(),
        )).plan.staircases.first.doorsPerFloor,
        2,
      );
    });

    test('should refuse fewer than one door per floor', () async {
      phoneWith(_street());

      final state = await after('7', (s) {
        s.removeDoor();
        s.removeDoor();
      });

      expect(state.refusal, BuildingPlanFailure.noDoor);
      expect(state.plan.staircases.first.doorsPerFloor, 1);
    });

    test('should refuse more than 500 dwellings', () async {
      phoneWith(_street());
      await settled('7');
      // 1 staircase, RdC–2e: 3 floors; 166 doors make 498 dwellings.
      for (var i = 0; i < 164; i++) {
        notifier('7').addDoor();
      }
      expect((await shown('7')).preview.dwellings, 498);

      final state = await after('7', (s) => s.addDoor());

      expect(state.refusal, BuildingPlanFailure.tooManyDwellings);
      expect(state.plan.staircases.first.doorsPerFloor, 166);
    });

    test('should change the label style', () async {
      phoneWith(_street());

      final state = await after(
        '7',
        (s) => s.setStyle(DoorLabelStyle.floorAndLetter),
      );

      expect(state.plan.style, DoorLabelStyle.floorAndLetter);
      expect(state.preview.parts.single.floors.first, (
        level: 0,
        first: '0A',
        last: '0B',
      ));
    });

    test('should refuse letters for more than 26 doors a floor', () async {
      phoneWith(_street());
      await settled('7');
      for (var i = 0; i < 25; i++) {
        notifier('7').addDoor();
      }

      final state = await after(
        '7',
        (s) => s.setStyle(DoorLabelStyle.floorAndLetter),
      );

      expect(state.refusal, BuildingPlanFailure.tooManyDoorsForLetters);
      expect(state.plan.style, DoorLabelStyle.floorAndNumber);
    });

    test('should do nothing before the street is read', () async {
      phoneWith(_street());
      final provider = buildingSetupProvider(keyOf('7'));
      container.listen(provider, (_, _) {});

      notifier('7').addDoor();

      expect(container.read(provider), isA<BuildingSetupLoading>());
      expect((await shown('7')).plan.staircases.first.doorsPerFloor, 2);
    });
  });

  group('each staircase', () {
    /// Opens 8 (two staircases RdC–3e, three doors) unticked.
    Future<BuildingSetupShown> unticked(
      void Function(BuildingSetupNotifier setup) steps,
    ) => after('8', (s) {
      s.setSameForEach(same: false);
      steps(s);
    });

    test('should untick the box and keep the plan', () async {
      phoneWith(_street());

      final state = await unticked((_) {});

      expect(state.sameForEach, isFalse);
      expect(state.stepsEachStaircase, isTrue);
      expect(state.plan.isUniform, isTrue);
    });

    test('should add a floor to staircase B only', () async {
      phoneWith(_street());

      final state = await unticked((s) => s.addFloor(staircase: escB));

      expect(state.plan.staircases, const [
        StaircasePlan(topFloor: 3, doorsPerFloor: 3),
        StaircasePlan(topFloor: 4, doorsPerFloor: 3),
      ]);
      expect(state.preview.dwellings, 12 + 15);
    });

    test('should remove a floor from staircase B only', () async {
      phoneWith(_street());

      final state = await unticked((s) => s.removeFloor(staircase: escB));

      expect(state.plan.staircases.map((s) => s.topFloor), [3, 2]);
    });

    test('should add a door to staircase A only', () async {
      phoneWith(_street());

      final state = await unticked((s) => s.addDoor(staircase: escA));

      expect(state.plan.staircases.map((s) => s.doorsPerFloor), [4, 3]);
    });

    test('should remove a door from staircase B only', () async {
      phoneWith(_street());

      final state = await unticked((s) => s.removeDoor(staircase: escB));

      expect(state.plan.staircases.map((s) => s.doorsPerFloor), [3, 2]);
    });

    test('should refuse no door in staircase B and keep the plan', () async {
      phoneWith(_street());

      final state = await unticked((s) {
        s
          ..removeDoor(staircase: escB)
          ..removeDoor(staircase: escB)
          ..removeDoor(staircase: escB);
      });

      expect(state.refusal, BuildingPlanFailure.noDoor);
      expect(state.plan.staircases.map((s) => s.doorsPerFloor), [3, 1]);
    });

    test('should step every staircase when none is named', () async {
      phoneWith(_street());

      final state = await unticked((s) {
        s
          ..removeDoor(staircase: escB)
          ..addDoor();
      });

      expect(state.plan.staircases.map((s) => s.doorsPerFloor), [4, 3]);
    });

    test('should give a new staircase the floors and doors of the last '
        'one', () async {
      phoneWith(_street());

      final state = await unticked((s) {
        s
          ..removeFloor(staircase: escB)
          ..addStaircase();
      });

      expect(state.plan.staircases.map((s) => s.topFloor), [3, 2, 2]);
    });

    test('should make every staircase like A when the box is ticked '
        'again', () async {
      phoneWith(_street());

      final state = await unticked((s) {
        s
          ..addFloor(staircase: escB)
          ..setSameForEach(same: true);
      });

      expect(state.sameForEach, isTrue);
      expect(
        state.plan,
        plan(
          staircases: 2,
          topFloor: 3,
          doors: 3,
          style: DoorLabelStyle.floorAndLetter,
        ),
      );
    });

    test('should refuse to tick the box when B like A makes too many '
        'dwellings', () async {
      // A: one « Logements » row of 251 doors; B: one of 1. Alike: 502.
      final big = valueOf(
        Building.create(
          style: DoorLabelStyle.floorAndNumber,
          staircases: [
            for (final (name, doors) in [(escA, 251), (escB, 1)])
              Staircase(
                name: name,
                floors: [
                  Floor(
                    level: null,
                    dwellings: [
                      for (var door = 1; door <= doors; door++)
                        Dwelling(label: d('$door')),
                    ],
                  ),
                ],
              ),
          ],
        ),
      );
      phoneWith(
        _street(
          houses: [House(number: n('8'), building: big)],
        ),
      );

      final state = await after('8', (s) => s.setSameForEach(same: true));

      expect(state.refusal, BuildingPlanFailure.tooManyDwellings);
      expect(state.sameForEach, isFalse);
      expect(state.plan.dwellingCount, 252);
    });

    test('should clear the refusal when the box is unticked', () async {
      phoneWith(_street());
      await after('8', (s) {
        for (var i = 0; i < 25; i++) {
          s.addStaircase();
        }
      });

      final state = await unticked((_) {});

      expect(state.refusal, isNull);
    });
  });

  group('validate', () {
    test(
      'should make the single house the building the answers describe',
      () async {
        phoneWith(_street());
        await after('7', (s) => s.addStaircase());

        final outcome = await notifier('7').validate();

        expect(outcome, isA<SetupLaidOut>());
        expect(
          streets.saved.single.$2,
          BuildingLaidOut(
            streetId: _id,
            before: _seven,
            stamp: leaAtTwo,
            building: Building.laidOut(
              plan(staircases: 2, topFloor: 2, doors: 2),
            ),
          ),
        );
      },
    );

    test(
      'should lay a building out again when no marked door is dropped',
      () async {
        phoneWith(_street());
        await after('8', (s) => s.addFloor());

        final outcome = await notifier('8').validate();

        expect(outcome, isA<SetupLaidOut>());
        final now = streets[_id]!.houses[1].building!;
        expect(now.progress.total, 2 * 5 * 3);
        expect(
          now.dwellingAt(DwellingKey(escB, 3, d('3C')))!.status,
          VisitStatus.done,
        );
      },
    );

    test('should ask first when marked doors would be dropped', () async {
      phoneWith(_street());
      await after('8', (s) => s.removeFloor());

      final outcome = await notifier('8').validate();

      expect(outcome, isA<SetupNeedsConfirmation>());
      expect((outcome as SetupNeedsConfirmation).markedDoors, 1);
      expect(streets.saved, isEmpty);
    });

    test('should drop the marked doors once confirmed', () async {
      phoneWith(_street());
      await after('8', (s) => s.removeFloor());

      final outcome = await notifier('8').validate(confirmed: true);

      expect(outcome, isA<SetupLaidOut>());
      expect(streets[_id]!.houses[1].building!.hasMarks, isFalse);
    });

    test('should fail when the house is gone', () async {
      phoneWith(_street());
      await settled('12');

      expect(await notifier('12').validate(), isA<SetupFailed>());
      expect(streets.saved, isEmpty);
    });

    test('should fail when the street refuses', () async {
      phoneWith(_street(), lost: true);
      await settled('7');

      expect(await notifier('7').validate(), isA<SetupFailed>());
      expect(streets.saved, isEmpty);
    });
  });
}
