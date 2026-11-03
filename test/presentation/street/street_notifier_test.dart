import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_view_preferences.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// The Main mockup in short: 1 to do, 3 done, 3bis nobody home, 5 to come
/// back, 7 to do; 2 done, 8 a building with 1 of its 2 doors
/// done and its own « repasser ».
final _houses = [
  House(number: n('1')),
  House(number: n('3'), status: VisitStatus.done),
  House(number: n('3bis'), status: VisitStatus.nobodyHome, tries: tries(2)),
  House(
    number: n('5'),
    status: VisitStatus.comeBack,
    comeBack: comeBack('2026-11-07', hour: 19),
  ),
  House(number: n('7')),
  House(number: n('2'), status: VisitStatus.done),
  House(
    number: n('8'),
    comeBack: comeBack('2026-11-03', hour: 10),
    building: building(
      topFloor: 0,
      doors: 2,
    ).withDwelling(escA, 0, Dwelling(label: d('01'), status: VisitStatus.done)),
  ),
];

Street _street({List<House>? houses, String name = 'Rue des Lilas'}) => valueOf(
  Street.create(
    id: _id,
    name: name,
    commune: villefranche,
    houses: houses ?? _houses,
  ),
);

HouseTile _tile(
  String number,
  TileMark mark, {
  bool isBuilding = false,
  int? tries,
}) => HouseTile(
  number: n(number),
  mark: mark,
  isBuilding: isBuilding,
  tries: tries,
);

void main() {
  late FakeStreetRepository streets;
  late FakeStreetViewPreferences preferences;
  late ProviderContainer container;

  /// A container whose phone holds [street] (none when null), with
  /// « Masquer faits » on when [hideDone].
  void phoneWith(Street? street, {bool hideDone = false}) {
    streets = FakeStreetRepository([?street]);
    preferences = FakeStreetViewPreferences([if (hideDone) _id]);
    container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        streetViewPreferencesProvider.overrideWithValue(preferences),
        clockProvider.overrideWithValue(FakeClock(twoPm)),
        identityProvider.overrideWithValue(FakeIdentity(lea)),
        openRoundStoreProvider.overrideWithValue(FakeOpenRoundStore()),
        mySectorsStoreProvider.overrideWithValue(FakeMySectorsStore()),
      ],
    );
    addTearDown(container.dispose);
    // `listen` keeps the auto-disposed provider alive for the whole test, as
    // the screen does while it shows.
    container.listen(streetProvider(_id), (_, _) {});
  }

  StreetNotifier notifier() => container.read(streetProvider(_id).notifier);

  /// Lets the repository's stream deliver, then reads the state.
  Future<StreetViewState> settled() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(streetProvider(_id));
  }

  Future<StreetShown> shown() async => (await settled()) as StreetShown;

  test('should be loading before the street is read', () {
    phoneWith(_street());

    expect(container.read(streetProvider(_id)), isA<StreetLoading>());
  });

  test(
    'should show the counts and both sides in order when the street is read',
    () async {
      phoneWith(_street());

      final state = await shown();

      expect(state.name, 'Rue des Lilas');
      expect(state.done, 3);
      expect(state.total, 8);
      expect(state.refused, 0);
      expect(state.nobodyHome, 1);
      // 5, and the building 8 itself.
      expect(state.comeBack, 2);
      expect(state.hideDone, isFalse);
      expect(state.columns, StreetColumns.both);
      expect(state.odd, [
        _tile('1', const ToDoMark()),
        _tile('3', const DoneMark()),
        _tile('3bis', const NobodyHomeMark(), tries: 2),
        _tile('5', const ComeBackMark()),
        _tile('7', const ToDoMark()),
      ]);
      expect(state.even, [
        _tile('2', const DoneMark()),
        _tile(
          '8',
          const PartialBuildingMark(done: 1, total: 2),
          isBuilding: true,
        ),
      ]);
    },
  );

  group('refused houses', () {
    // 1 refused, 3 done, 5 to do, 7 refused; 2 a building with one door
    // refused and the other done.
    final refusing = _street(
      houses: [
        House(number: n('1'), status: VisitStatus.refused),
        House(number: n('3'), status: VisitStatus.done),
        House(number: n('5')),
        House(number: n('7'), status: VisitStatus.refused),
        House(
          number: n('2'),
          building: building(topFloor: 0, doors: 2)
              .withDwelling(
                escA,
                0,
                Dwelling(label: d('01'), status: VisitStatus.refused),
              )
              .withDwelling(
                escA,
                0,
                Dwelling(label: d('02'), status: VisitStatus.done),
              ),
        ),
      ],
    );

    test('should count them with the done ones, and apart in ⊘', () async {
      phoneWith(refusing);

      final state = await shown();

      // 1, 3, 7 and both doors of 2: five of six doors.
      expect(state.done, 5);
      expect(state.total, 6);
      expect(state.refused, 3);
      expect(state.nobodyHome, 0);
      expect(state.comeBack, 0);
      expect(state.odd, [
        _tile('1', const RefusedMark()),
        _tile('3', const DoneMark()),
        _tile('5', const ToDoMark()),
        _tile('7', const RefusedMark()),
      ]);
      expect(state.even, [_tile('2', const DoneMark(), isBuilding: true)]);
    });

    test('should leave them out with the done ones when the street hides '
        'them', () async {
      phoneWith(refusing, hideDone: true);

      final state = await shown();

      expect(state.odd.map((tile) => tile.number.label), ['5']);
      expect(state.even, isEmpty);
    });
  });

  test('should say the street is gone when it is not on the phone', () async {
    phoneWith(null);

    expect(await settled(), isA<StreetGone>());
  });

  test('should say the street is gone when it is in the Corbeille', () async {
    final street = _street();
    final (deleted, _) = street.delete(by: lea, at: twoPm);
    phoneWith(deleted);

    expect(await settled(), isA<StreetGone>());
  });

  test('should follow the street when it changes elsewhere', () async {
    phoneWith(_street());
    await settled();

    final (marked, change) = valueOf(
      _street().markHouse(n('1'), VisitStatus.done, by: paul, at: threePm),
    );
    await streets.save(marked, change);
    final state = await shown();

    expect(state.done, 4);
    expect(state.odd.first, _tile('1', const DoneMark()));
  });

  group('columns', () {
    test(
      'should show one column when the street has odd numbers only',
      () async {
        phoneWith(
          _street(
            houses: [
              House(number: n('1')),
              House(number: n('3')),
            ],
          ),
        );

        final state = await shown();

        expect(state.columns, StreetColumns.oddOnly);
        expect(state.even, isEmpty);
        expect(state.odd, hasLength(2));
      },
    );

    test(
      'should show one column when the street has even numbers only',
      () async {
        phoneWith(
          _street(
            houses: [
              House(number: n('0')),
              House(number: n('2')),
            ],
          ),
        );

        final state = await shown();

        expect(state.columns, StreetColumns.evenOnly);
        expect(state.odd, isEmpty);
        expect(state.even, hasLength(2));
      },
    );

    test('should keep both columns when the street has no number', () async {
      phoneWith(_street(houses: []));

      final state = await shown();

      expect(state.columns, StreetColumns.both);
      expect(state.total, 0);
    });

    test(
      'should keep both columns when a side is hidden as all done',
      () async {
        phoneWith(
          _street(
            houses: [
              House(number: n('1')),
              House(number: n('2'), status: VisitStatus.done),
            ],
          ),
          hideDone: true,
        );

        final state = await shown();

        expect(state.columns, StreetColumns.both);
        expect(state.even, isEmpty);
      },
    );
  });

  group('« Masquer faits »', () {
    test(
      'should leave the done tiles out when the street hides them',
      () async {
        phoneWith(_street(), hideDone: true);

        final state = await shown();

        expect(state.hideDone, isTrue);
        expect(state.odd.map((tile) => tile.number.label), [
          '1',
          '3bis',
          '5',
          '7',
        ]);
        expect(state.even.map((tile) => tile.number.label), ['8']);
        // The header still counts every door.
        expect(state.done, 3);
        expect(state.total, 8);
      },
    );

    test(
      'should hide the done tiles and remember it when toggled on',
      () async {
        phoneWith(_street());
        await settled();

        await notifier().toggleHideDone();
        final state = await shown();

        expect(state.hideDone, isTrue);
        expect(state.odd, hasLength(4));
        expect(preferences.writes, [(_id, true)]);
      },
    );

    test('should show them again and remember it when toggled off', () async {
      phoneWith(_street(), hideDone: true);
      await settled();

      await notifier().toggleHideDone();
      final state = await shown();

      expect(state.hideDone, isFalse);
      expect(state.odd, hasLength(5));
      expect(preferences.writes, [(_id, false)]);
    });
  });

  group('undo', () {
    /// Chooses [status] in the picker of [number], then keeps what it
    /// stored for « Annuler », as the street screen does.
    Future<void> pick(String number, VisitStatus status) async {
      final key = (street: _id, number: n(number));
      final picker = container.listen(houseSheetProvider(key), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final stored = await container
          .read(houseSheetProvider(key).notifier)
          .setStatus(status);
      picker.close();
      notifier().keepForUndo(stored!.change);
    }

    test('should put the house back as it was before the status was '
        'chosen', () async {
      final street = _street();
      phoneWith(street);
      await settled();
      await pick('5', VisitStatus.toDo);

      await notifier().undo();

      expect(streets[_id]!.houses, street.houses);
      expect((await shown()).odd[3], _tile('5', const ComeBackMark()));
    });

    test('should put back its status, time and tries after « Repasser » and '
        'a day were chosen', () async {
      final street = _street();
      phoneWith(street);
      await settled();
      final key = (street: _id, number: n('3bis'));
      container.listen(houseSheetProvider(key), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final picker = container.read(houseSheetProvider(key).notifier);
      final stored = await picker.setStatus(VisitStatus.comeBack);
      await picker.chooseComeBackDay(day('2026-11-03'));
      notifier().keepForUndo(stored!.change);

      await notifier().undo();

      expect(streets[_id]!.houses, street.houses);
    });

    test('should undo only the last status', () async {
      phoneWith(_street());
      await settled();
      await pick('1', VisitStatus.done);
      await pick('7', VisitStatus.done);

      await notifier().undo();

      final state = await shown();
      expect(state.odd.first, _tile('1', const DoneMark()));
      expect(state.odd.last, _tile('7', const ToDoMark()));
    });

    test('should undo a status once only', () async {
      phoneWith(_street());
      await settled();
      await pick('1', VisitStatus.done);
      await notifier().undo();

      await notifier().undo();

      expect(streets.saved, hasLength(2));
    });

    test('should do nothing when nothing was stored', () async {
      phoneWith(_street());
      await settled();

      await notifier().undo();

      expect(streets.saved, isEmpty);
    });
  });

  group('Changer en maison', () {
    House eight() =>
        streets[_id]!.houses.singleWhere((h) => h.number == n('8'));

    test('should make the building a house, its doors gone', () async {
      phoneWith(_street());
      await settled();

      expect(await notifier().backToSingleHouse(n('8')), isTrue);

      expect(eight().building, isNull);
      expect((await shown()).even[1], _tile('8', const ComeBackMark()));
    });

    test('should bring the doors back when Annuler is tapped', () async {
      phoneWith(_street());
      await settled();
      await notifier().backToSingleHouse(n('8'));

      await notifier().undo();

      expect(eight(), _houses.last);
    });

    test('should fail when the house is not a building', () async {
      phoneWith(_street());
      await settled();

      expect(await notifier().backToSingleHouse(n('1')), isFalse);
      expect(streets.saved, isEmpty);
    });
  });
}
