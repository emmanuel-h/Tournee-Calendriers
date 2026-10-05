import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street/street_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_view_preferences.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

final _id = StreetId('lilas');

/// The Main mockup in short: 1 to do, 3 done, 3bis nobody home, 5 to come
/// back, 7 to do with a note; 2 done, 8 a building with 1 of its 2 doors
/// done and its own « repasser ».
final _houses = [
  House(number: n('1')),
  House(number: n('3'), status: VisitStatus.done),
  House(number: n('3bis'), status: VisitStatus.nobodyHome),
  House(
    number: n('5'),
    status: VisitStatus.comeBack,
    comeBack: comeBack('après 19h'),
  ),
  House(number: n('7'), note: note('chien')),
  House(number: n('2'), status: VisitStatus.done),
  House(
    number: n('8'),
    comeBack: comeBack('gardien'),
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
  bool hasNote = false,
  bool isBuilding = false,
}) => HouseTile(
  number: n(number),
  mark: mark,
  hasNote: hasNote,
  isBuilding: isBuilding,
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
      expect(state.nobodyHome, 1);
      // 5, and the building 8 itself.
      expect(state.comeBack, 2);
      expect(state.hideDone, isFalse);
      expect(state.columns, StreetColumns.both);
      expect(state.odd, [
        _tile('1', const ToDoMark()),
        _tile('3', const DoneMark()),
        _tile('3bis', const NobodyHomeMark()),
        _tile('5', const ComeBackMark()),
        _tile('7', const ToDoMark(), hasNote: true),
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

  group('tap', () {
    test('should give the house its next status and tell it', () async {
      phoneWith(_street());
      await settled();

      final marked = await notifier().cycle(n('1'));

      expect(marked, MarkedHouse(number: n('1'), status: VisitStatus.done));
      final (saved, change) = streets.saved.single;
      expect(change, isA<HouseMarked>());
      expect((change as HouseMarked).status, VisitStatus.done);
      expect(change.stamp, leaAtTwo);
      expect(saved.houses.first.status, VisitStatus.done);
      expect((await shown()).odd.first, _tile('1', const DoneMark()));
    });

    test('should move a done house to nobody home', () async {
      phoneWith(_street());
      await settled();

      final marked = await notifier().cycle(n('3'));

      expect(
        marked,
        MarkedHouse(number: n('3'), status: VisitStatus.nobodyHome),
      );
    });

    test('should move a nobody-home house to come back', () async {
      phoneWith(_street());
      await settled();

      final marked = await notifier().cycle(n('3bis'));

      expect(
        marked,
        MarkedHouse(number: n('3bis'), status: VisitStatus.comeBack),
      );
      expect((await shown()).odd[2], _tile('3bis', const ComeBackMark()));
      expect((await shown()).comeBack, 3);
    });

    test('should move a come-back house to do', () async {
      phoneWith(_street());
      await settled();

      final marked = await notifier().cycle(n('5'));

      expect(marked, MarkedHouse(number: n('5'), status: VisitStatus.toDo));
      expect(streets[_id]!.houses[4].number, n('5'));
      expect(streets[_id]!.houses[4].comeBack, isNull);
    });

    test('should change nothing when the tile is a building', () async {
      phoneWith(_street());
      await settled();

      expect(await notifier().cycle(n('8')), isNull);
      expect(streets.saved, isEmpty);
    });

    test('should change nothing when the street is not read yet', () async {
      phoneWith(_street());

      expect(await notifier().cycle(n('1')), isNull);
      expect(streets.saved, isEmpty);
    });

    test('should change nothing when the street has no such number', () async {
      phoneWith(_street());
      await settled();

      expect(await notifier().cycle(n('99')), isNull);
      expect(streets.saved, isEmpty);
    });
  });

  group('undo', () {
    test('should put the house back as it was before the tap', () async {
      final street = _street();
      phoneWith(street);
      await settled();
      await notifier().cycle(n('5'));

      await notifier().undo();

      expect(streets[_id]!.houses, street.houses);
      expect((await shown()).odd[3], _tile('5', const ComeBackMark()));
    });

    test('should undo only the last tap', () async {
      phoneWith(_street());
      await settled();
      await notifier().cycle(n('1'));
      await notifier().cycle(n('7'));

      await notifier().undo();

      final state = await shown();
      expect(state.odd.first, _tile('1', const DoneMark()));
      expect(state.odd.last, _tile('7', const ToDoMark(), hasNote: true));
    });

    test('should undo a tap once only', () async {
      phoneWith(_street());
      await settled();
      await notifier().cycle(n('1'));
      await notifier().undo();

      await notifier().undo();

      expect(streets.saved, hasLength(2));
    });

    test('should do nothing when nothing was tapped', () async {
      phoneWith(_street());
      await settled();

      await notifier().undo();

      expect(streets.saved, isEmpty);
    });
  });

  group('Redevenir une maison', () {
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
