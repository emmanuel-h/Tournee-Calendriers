import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' as streets_fixtures show lea;
import '../../support/street_fixtures.dart' hide lea;

final _me = streets_fixtures.lea;

final _morinId = BanStreetId('69264_1460');
final _nationaleId = BanStreetId('69264_1781');

/// Where the finger taps on Rue Pierre Morin, not yet in the tournée.
final _onMorin = at(45.98850, 4.72500);

/// Where the finger taps on Rue Nationale, in the tournée.
final _onNationale = at(45.98915, 4.71862);

/// Where the finger taps where the BAN knows no street.
final _nowhere = at(45.99500, 4.73000);

StreetMatch _match(BanStreetId id, String name, GeoPoint position) =>
    StreetMatch(
      id: id,
      name: streetName(name),
      commune: villefranche,
      position: position,
    );

final _pasteurId = BanStreetId('69264_1200');

/// Where the finger taps on Rue Pasteur, not yet in the secteur.
final _onPasteur = at(45.98700, 4.72000);

final _morinMatch = _match(_morinId, 'Rue Pierre Morin', _onMorin);
final _pasteurMatch = _match(_pasteurId, 'Rue Pasteur', _onPasteur);
final _nationaleMatch = _match(_nationaleId, 'Rue Nationale', _onNationale);

final _morinNumbers = StreetNumbers(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('1'), position: _onMorin),
    DirectoryNumber(number: n('2')),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

/// Rue Pasteur, three numbers.
final _pasteurNumbers = StreetNumbers(
  id: _pasteurId,
  name: streetName('Rue Pasteur'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('1')),
    DirectoryNumber(number: n('3')),
    DirectoryNumber(number: n('5')),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

/// The road of Rue Pierre Morin as OpenStreetMap draws it (already
/// simple: two points).
final _morinRoad = StreetShape([
  [at(45.98800, 4.72500), at(45.98900, 4.72500)],
]);

final _nationaleRoad = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);

/// Rue Nationale, in the tournée, nobody's.
final _nationale = valueOf(
  Street.create(
    id: StreetId('nationale'),
    name: 'Rue Nationale',
    commune: villefranche,
    banId: _nationaleId,
    shape: _nationaleRoad,
    houses: [House(number: n('1'), position: townHallDoor)],
  ),
);

/// Allée Émile Zola, typed in by hand.
final _emile = valueOf(
  Street.create(
    id: StreetId('emile'),
    name: 'Allée Émile Zola',
    commune: villefranche,
    houses: [House(number: n('4'))],
  ),
);

void main() {
  late FakeStreetRepository streets;
  late FakeSectorRepository sectors;
  late FakeAddressDirectory directory;
  late FakeStreetShapes shapes;

  /// Léa's phone with the 49 open, or none when [open] is false.
  ProviderContainer phone({bool open = true}) {
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        sectorRepositoryProvider.overrideWithValue(sectors),
        addressDirectoryProvider.overrideWithValue(directory),
        streetShapesProvider.overrideWithValue(shapes),
        identityProvider.overrideWithValue(FakeIdentity(_me)),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
        mySectorsStoreProvider.overrideWithValue(
          FakeMySectorsStore(
            open
                ? valueOf(MySectors.none.remember(sector49).open(sectorId))
                : MySectors.none,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // An `autoDispose` provider lives only while someone listens to it:
    // the test listens as the screen would.
    container.listen(addStreetsMapProvider, (_, _) {});
    return container;
  }

  AddStreetsMapState stateOf(ProviderContainer container) =>
      container.read(addStreetsMapProvider);

  AddStreetsMapNotifier notifierOf(ProviderContainer container) =>
      container.read(addStreetsMapProvider.notifier);

  setUp(() {
    streets = FakeStreetRepository([_nationale, _emile]);
    sectors = FakeSectorRepository([
      team(communes: [villefrancheCommune, gleizeCommune]),
    ]);
    directory = FakeAddressDirectory(
      places: {
        _onMorin: Ok(_morinMatch),
        _onPasteur: Ok(_pasteurMatch),
        _onNationale: Ok(_nationaleMatch),
      },
      streets: {_morinId: Ok(_morinNumbers), _pasteurId: Ok(_pasteurNumbers)},
      searches: {
        'morin': Ok([_morinMatch]),
      },
    );
    // OpenStreetMap knows Rue Pierre Morin, not Rue Pasteur.
    shapes = FakeStreetShapes()..answers['Rue Pierre Morin'] = Ok(_morinRoad);
  });

  group('map', () {
    test('should draw the streets and open on the communes', () async {
      final container = phone();
      await pumpEventQueue();

      final state = stateOf(container);

      expect(state.layers.lines.single.street, StreetId('nationale'));
      expect(state.layers.dots.single.street, StreetId('nationale'));
      expect(state.area, communesArea([villefrancheCommune, gleizeCommune]));
      expect(state.picked, isEmpty);
      expect(state.pickedRoads, isEmpty);
      expect(state.lookingAt, isNull);
      expect(state.search, const NoStreetSearch());
      expect(state.run, const AddIdle());
    });

    test('should draw « à faire » a street with nothing visited', () async {
      final container = phone();
      await pumpEventQueue();

      expect(stateOf(container).layers.lines.single.level, ProgressLevel.toDo);
    });

    test('should open on the streets for a tournée without commune', () async {
      sectors.put(team());
      final container = phone();
      await pumpEventQueue();

      expect(stateOf(container).area, sectorArea([_nationale, _emile]));
    });

    test('should follow the communes as they change', () async {
      final container = phone();
      await pumpEventQueue();

      sectors.put(team(communes: [gleizeCommune]));
      await pumpEventQueue();

      expect(stateOf(container).area, communesArea([gleizeCommune]));
    });

    test('should open on the streets with no tournée open', () async {
      final container = phone(open: false);
      await pumpEventQueue();

      expect(stateOf(container).area, sectorArea([_nationale, _emile]));
      expect(sectors.watched, isEmpty);
    });

    test('should draw nothing and show France before anything is read', () {
      streets.watchError = StateError('not yet');
      sectors.put(team());
      final container = phone();

      final state = stateOf(container);

      expect(state.layers.lines, isEmpty);
      expect(state.layers.dots, isEmpty);
      expect(state.area, isNull);
    });

    test('should draw no street once the streets cannot be read', () async {
      streets.watchError = StateError('removed');
      sectors.put(team());
      final container = phone();
      await pumpEventQueue();

      final state = stateOf(container);

      expect(state.layers.dots, isEmpty);
      expect(state.area, isNull);
    });
  });

  test('should keep showing the map when the secteur can no longer be '
      'read', () async {
    sectors.watchError = StateError('removed');
    final container = phone();
    await pumpEventQueue();

    final answer = notifierOf(container).tapStreet(StreetId('emile'));

    expect(answer, const AlreadyInSector('Allée Émile Zola'));
    expect(stateOf(container).area, sectorArea([_nationale, _emile]));
  });

  final morinRow = PickedStreetRow(
    id: _morinId,
    name: 'Rue Pierre Morin',
    commune: 'Villefranche-sur-Saône',
    numberCount: 2,
  );
  final pasteurRow = PickedStreetRow(
    id: _pasteurId,
    name: 'Rue Pasteur',
    commune: 'Villefranche-sur-Saône',
    numberCount: 3,
  );

  group('a road tapped', () {
    test('should mark the point while the street there is looked up', () async {
      final container = phone();
      await pumpEventQueue();

      unawaited(notifierOf(container).tapMap(_onMorin));

      expect(stateOf(container).lookingAt, _onMorin);
      expect(stateOf(container).picked, isEmpty);
      expect(directory.pointsAsked, [_onMorin]);
    });

    test('should tick a street the secteur does not have, with its '
        'numbers', () async {
      final container = phone();
      await pumpEventQueue();

      final answer = await notifierOf(container).tapMap(_onMorin);

      expect(answer, const NothingToSay());
      expect(stateOf(container).picked, [morinRow]);
      expect(stateOf(container).lookingAt, isNull);
      expect(directory.streetsAsked, [_morinId]);
    });

    test('should tick the road under the finger, with its own road, when '
        'the geocoder answers a street ticked next to it (#134)', () async {
      // 23 m east of Rue Pierre Morin, on Rue Pasteur, which runs north
      // there. The geocoder answers Rue Pierre Morin, whose middle is
      // nearer: the tap used to untick it, or tick a street the finger was
      // not on, its ✓ there without its road.
      final nearMorin = at(45.98850, 4.72530);
      final pasteurRoad = StreetShape([
        [at(45.98800, 4.72530), at(45.98900, 4.72530)],
      ]);
      directory = FakeAddressDirectory(
        places: {_onMorin: Ok(_morinMatch), nearMorin: Ok(_morinMatch)},
        streets: {_morinId: Ok(_morinNumbers), _pasteurId: Ok(_pasteurNumbers)},
        searches: {
          'Rue Pasteur': Ok([_pasteurMatch]),
        },
      );
      shapes
        ..roads = Ok([
          NamedRoad(name: 'Rue Pierre Morin', shape: _morinRoad),
          NamedRoad(name: 'Rue Pasteur', shape: pasteurRoad),
        ])
        ..answers['Rue Pasteur'] = Ok(pasteurRoad);
      final container = phone();
      await pumpEventQueue();
      await notifierOf(container).tapMap(_onMorin);
      await pumpEventQueue();

      await notifierOf(container).tapMap(nearMorin);
      await pumpEventQueue();

      expect(stateOf(container).picked, [morinRow, pasteurRow]);
      expect(stateOf(container).pickedRoads, [
        PickedRoad(street: _morinId, road: _morinRoad, mark: _onMorin),
        PickedRoad(street: _pasteurId, road: pasteurRoad, mark: nearMorin),
      ]);
    });

    test('should draw its road with its ✓ once the map tells it', () async {
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);
      await pumpEventQueue();

      expect(stateOf(container).pickedRoads, [
        PickedRoad(street: _morinId, road: _morinRoad, mark: _onMorin),
      ]);
      expect(shapes.askedNames, ['Rue Pierre Morin']);
    });

    test('should show only the ✓ while the map does not answer', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);
      await pumpEventQueue();

      expect(stateOf(container).pickedRoads, [
        PickedRoad(street: _morinId, road: StreetShape.none, mark: _onMorin),
      ]);
      answer.complete();
    });

    test('should show only the ✓ when the map fails', () async {
      shapes.answers['Rue Pierre Morin'] = const Err(
        StreetShapesFailure.serviceError,
      );
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);
      await pumpEventQueue();

      expect(stateOf(container).pickedRoads.single.road, StreetShape.none);
      expect(stateOf(container).picked, [morinRow]);
    });

    test('should add up the streets tapped, in the order they were', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);

      await notifier.tapMap(_onPasteur);
      await notifier.tapMap(_onMorin);
      await pumpEventQueue();

      expect(stateOf(container).picked, [pasteurRow, morinRow]);
      expect(stateOf(container).pickedRoads, [
        PickedRoad(
          street: _pasteurId,
          road: StreetShape.none,
          mark: _onPasteur,
        ),
        PickedRoad(street: _morinId, road: _morinRoad, mark: _onMorin),
      ]);
    });

    test('should untick a ticked street tapped again', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onPasteur);
      await notifier.tapMap(_onMorin);

      final answer = await notifier.tapMap(_onMorin);

      expect(answer, const NothingToSay());
      expect(stateOf(container).picked, [pasteurRow]);
      expect(stateOf(container).pickedRoads.single.street, _pasteurId);
    });

    test('should tick nothing on a street of the secteur, and say it is in '
        'it already', () async {
      final container = phone();
      await pumpEventQueue();

      final answer = await notifierOf(container).tapMap(_onNationale);

      expect(answer, const AlreadyInSector('Rue Nationale'));
      expect(stateOf(container).picked, isEmpty);
      expect(stateOf(container).lookingAt, isNull);
      expect(shapes.asked, isEmpty);
    });

    test('should say a connection is needed when offline', () async {
      directory = FakeAddressDirectory(
        places: {_onMorin: const Err(AddressDirectoryFailure.noNetwork)},
      );
      final container = phone();
      await pumpEventQueue();

      final answer = await notifierOf(container).tapMap(_onMorin);

      expect(answer, const LookUpFailed(LookUpProblem.noNetwork));
      expect(stateOf(container).picked, isEmpty);
      expect(stateOf(container).lookingAt, isNull);
    });

    test('should say the BAN knows no street there', () async {
      final container = phone();
      await pumpEventQueue();

      final answer = await notifierOf(container).tapMap(_nowhere);

      expect(answer, const LookUpFailed(LookUpProblem.noStreetHere));
      expect(stateOf(container).picked, isEmpty);
    });

    test('should say the address service failed', () async {
      directory = FakeAddressDirectory(
        places: {_onMorin: Ok(_morinMatch)},
        streets: {_morinId: const Err(AddressDirectoryFailure.serviceError)},
      );
      final container = phone();
      await pumpEventQueue();

      final answer = await notifierOf(container).tapMap(_onMorin);

      expect(answer, const LookUpFailed(LookUpProblem.serviceError));
    });

    test('should keep the point of the last tap while an earlier one is '
        'answered, and tick both', () async {
      directory
        ..holdStreet(_morinId)
        ..holdStreet(_pasteurId);
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      final first = notifier.tapMap(_onMorin);
      final last = notifier.tapMap(_onPasteur);
      await pumpEventQueue();

      directory.releaseStreet(_morinId);
      await first;

      expect(stateOf(container).lookingAt, _onPasteur);
      expect(stateOf(container).picked, [morinRow]);

      directory.releaseStreet(_pasteurId);
      await last;

      expect(stateOf(container).lookingAt, isNull);
      expect(stateOf(container).picked, [morinRow, pasteurRow]);
    });

    test(
      'should tick nothing for a tap answered after « Tout décocher »',
      () async {
        directory.holdStreet(_morinId);
        final container = phone();
        await pumpEventQueue();
        final notifier = notifierOf(container);
        final late = notifier.tapMap(_onMorin);
        await pumpEventQueue();

        notifier.untickAll();
        expect(stateOf(container).lookingAt, isNull);
        directory.releaseStreet(_morinId);

        expect(await late, const NothingToSay());
        expect(stateOf(container).picked, isEmpty);
        expect(stateOf(container).lookingAt, isNull);
      },
    );

    test('should drop the road of a street unticked meanwhile', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onPasteur);
      await notifier.tapMap(_onMorin);

      notifier.untick(_morinId);
      answer.complete();
      await pumpEventQueue();

      expect(stateOf(container).pickedRoads, [
        PickedRoad(
          street: _pasteurId,
          road: StreetShape.none,
          mark: _onPasteur,
        ),
      ]);
    });

    test(
      'should drop an answer that comes once the screen is closed',
      () async {
        directory.holdStreet(_morinId);
        final container = phone();
        await pumpEventQueue();
        final late = notifierOf(container).tapMap(_onMorin);
        await pumpEventQueue();

        container.dispose();
        directory.releaseStreet(_morinId);

        expect(await late, const NothingToSay());
      },
    );

    test('should drop a road that comes once the screen is closed', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();
      await notifierOf(container).tapMap(_onMorin);

      container.dispose();
      answer.complete();

      await expectLater(pumpEventQueue(), completes);
    });
  });

  group('a street of the secteur tapped', () {
    test('should say at once that it is in the secteur, ticking '
        'nothing', () async {
      final container = phone();
      await pumpEventQueue();

      final answer = notifierOf(container).tapStreet(StreetId('emile'));

      expect(answer, const AlreadyInSector('Allée Émile Zola'));
      expect(stateOf(container).picked, isEmpty);
      expect(directory.pointsAsked, isEmpty);
    });

    test('should say nothing for a street no longer on the phone', () async {
      final container = phone();
      await pumpEventQueue();

      final answer = notifierOf(container).tapStreet(StreetId('gone'));

      expect(answer, const NothingToSay());
    });
  });

  group('unticking', () {
    test('should untick only the street of the ✕', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      await notifier.tapMap(_onPasteur);

      notifier.untick(_morinId);

      expect(stateOf(container).picked, [pasteurRow]);
      expect(stateOf(container).pickedRoads.single.street, _pasteurId);
    });

    test('should untick every street with « Tout décocher »', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      await notifier.tapMap(_onPasteur);

      notifier.untickAll();

      expect(stateOf(container).picked, isEmpty);
      expect(stateOf(container).pickedRoads, isEmpty);
    });
  });

  group('adding', () {
    /// Rue Brisée: the BAN gives its 1 twice, which no street can take.
    final brokenId = BanStreetId('69264_9999');
    final onBroken = at(45.98600, 4.71900);
    final brokenRow = PickedStreetRow(
      id: brokenId,
      name: 'Rue Brisée',
      commune: 'Villefranche-sur-Saône',
      numberCount: 2,
    );

    setUp(() {
      directory = FakeAddressDirectory(
        places: {
          _onMorin: Ok(_morinMatch),
          _onPasteur: Ok(_pasteurMatch),
          onBroken: Ok(_match(brokenId, 'Rue Brisée', onBroken)),
        },
        streets: {
          _morinId: Ok(_morinNumbers),
          _pasteurId: Ok(_pasteurNumbers),
          brokenId: Ok(
            StreetNumbers(
              id: brokenId,
              name: streetName('Rue Brisée'),
              commune: villefranche,
              numbers: [
                DirectoryNumber(number: n('1')),
                DirectoryNumber(number: n('1')),
              ],
              invalidNumbers: 0,
              duplicateNumbers: 0,
            ),
          ),
        },
      );
    });

    test('should add every street ticked, in order, each with its road '
        'when known, and say how many', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      await notifier.tapMap(_onPasteur);
      await pumpEventQueue();

      final added = await notifier.add();

      expect(added, 2);
      expect(
        [for (final street in streets.added) street.banId],
        [_morinId, _pasteurId],
      );
      expect(streets.added.first.name.text, 'Rue Pierre Morin');
      expect(streets.added.first.shape, _morinRoad);
      expect(streets.added.last.shape, StreetShape.none);
      expect(streets.added.last.houses, hasLength(3));
      expect(stateOf(container).picked, isEmpty);
      expect(stateOf(container).run, const AddIdle());
    });

    test('should tell the progress while adding', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      await notifier.tapMap(_onPasteur);
      final runs = <AddRun>[];
      container.listen(
        addStreetsMapProvider.select((state) => state.run),
        (_, run) => runs.add(run),
      );

      await notifier.add();

      expect(runs, [
        const AddRunning(0, 2),
        const AddRunning(1, 2),
        const AddRunning(2, 2),
        const AddIdle(),
      ]);
    });

    test('should add a street at once while its road is awaited', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);

      expect(await notifier.add(), 1);

      expect(streets.added.single.shape, StreetShape.none);
      answer.complete();
    });

    test('should add a street with the road that came after the button was '
        'pressed', () async {
      final road = Completer<void>();
      shapes.whileAsked = () => road.future;
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onPasteur);
      await notifier.tapMap(_onMorin);
      final stored = Completer<void>();
      streets.holdAdds = stored;
      final adding = notifier.add();
      await pumpEventQueue();

      road.complete();
      await pumpEventQueue();
      stored.complete();
      await adding;

      expect(streets.added.last.banId, _morinId);
      expect(streets.added.last.shape, _morinRoad);
    });

    test('should keep ticked the streets that failed, and say how '
        'many', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(onBroken);
      await notifier.tapMap(_onMorin);

      final added = await notifier.add();

      expect(added, isNull);
      expect(stateOf(container).picked, [brokenRow]);
      expect(stateOf(container).run, const AddFailed(1));
      expect(streets.added.single.banId, _morinId);
    });

    test('should forget the failure once the ticks change', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(onBroken);
      await notifier.add();

      await notifier.tapMap(_onMorin);

      expect(stateOf(container).run, const AddIdle());
      expect(stateOf(container).picked, [brokenRow, morinRow]);
    });

    test('should count a street a teammate added meanwhile', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      await streets.add(
        valueOf(
          Street.create(
            id: StreetId('morin-by-manu'),
            name: 'Rue Pierre Morin',
            commune: villefranche,
            banId: _morinId,
            houses: [House(number: n('1'))],
          ),
        ),
      );

      expect(await notifier.add(), 1);

      expect(
        [for (final street in streets.added) street.id.value],
        ['morin-by-manu'],
      );
      expect(stateOf(container).picked, isEmpty);
    });

    test('should add nothing with nothing ticked', () async {
      final container = phone();
      await pumpEventQueue();

      expect(await notifierOf(container).add(), isNull);

      expect(streets.added, isEmpty);
      expect(stateOf(container).run, const AddIdle());
    });

    test('should add once on a second press while adding', () async {
      final stored = Completer<void>();
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      streets.holdAdds = stored;
      final first = notifier.add();

      expect(await notifier.add(), isNull);
      stored.complete();

      expect(await first, 1);
      expect(streets.added, hasLength(1));
    });

    test('should keep the ticks as they are while adding', () async {
      final stored = Completer<void>();
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      streets.holdAdds = stored;
      final adding = notifier.add();
      await pumpEventQueue();

      final answer = await notifier.tapMap(_onPasteur);
      notifier
        ..untick(_morinId)
        ..untickAll();

      expect(answer, const NothingToSay());
      expect(directory.pointsAsked, [_onMorin]);
      expect(stateOf(container).picked, [morinRow]);
      expect(stateOf(container).run, const AddRunning(0, 1));
      stored.complete();
      await adding;
    });

    test('should tick nothing for a tap answered while adding', () async {
      directory.holdStreet(_pasteurId);
      final stored = Completer<void>();
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      final late = notifier.tapMap(_onPasteur);
      await pumpEventQueue();
      streets.holdAdds = stored;
      final adding = notifier.add();

      directory.releaseStreet(_pasteurId);

      expect(await late, const NothingToSay());
      expect(stateOf(container).picked, [morinRow]);
      stored.complete();
      await adding;
    });

    test('should still add the streets when the screen closes', () async {
      final stored = Completer<void>();
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      await notifier.tapMap(_onPasteur);
      streets.holdAdds = stored;
      final adding = notifier.add();
      await pumpEventQueue();

      container.dispose();
      stored.complete();
      await adding;

      expect(streets.added, hasLength(2));
    });
  });

  group('search', () {
    test('should list the streets found in the secteur\'s communes', () async {
      directory = FakeAddressDirectory(
        searches: {
          'rue p': Ok([_morinMatch, _pasteurMatch]),
        },
      );
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).search('rue p');

      expect(
        stateOf(container).search,
        StreetsFound([
          FoundStreetRow(
            id: _morinId,
            name: 'Rue Pierre Morin',
            commune: 'Villefranche-sur-Saône',
          ),
          FoundStreetRow(
            id: _pasteurId,
            name: 'Rue Pasteur',
            commune: 'Villefranche-sur-Saône',
          ),
        ]),
      );
      expect(directory.searchesAsked, [('rue p', '69264'), ('rue p', '69092')]);
    });

    test('should show the search running', () async {
      final container = phone();
      await pumpEventQueue();

      unawaited(notifierOf(container).search('morin'));

      expect(stateOf(container).search, const SearchingStreets());
    });

    test('should search the communes of the streets for a secteur without '
        'commune', () async {
      sectors.put(team());
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).search('morin');

      expect(directory.searchesAsked, [('morin', '69264')]);
    });

    test('should find nothing in a commune the BAN does not know', () async {
      directory = FakeAddressDirectory(
        searchesByCommune: {
          '69264': const Err(AddressDirectoryFailure.notFound),
        },
      );
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).search('morin');

      expect(stateOf(container).search, StreetsFound(const []));
    });

    test('should say a connection is needed when offline', () async {
      directory = FakeAddressDirectory(
        searchesByCommune: {
          '69264': const Err(AddressDirectoryFailure.noNetwork),
        },
      );
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).search('morin');

      expect(
        stateOf(container).search,
        const StreetSearchFailed(LookUpProblem.noNetwork),
      );
    });

    test('should close the list for a blank text, without asking', () async {
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).search('  ');

      expect(stateOf(container).search, const NoStreetSearch());
      expect(directory.searchesAsked, isEmpty);
    });

    test('should drop a search answered after the list was closed', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      final late = notifier.search('morin');

      notifier.clearSearch();
      await late;

      expect(stateOf(container).search, const NoStreetSearch());
    });

    test('should close the list when the map is tapped', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');

      await notifier.tapMap(_onMorin);

      expect(stateOf(container).search, const NoStreetSearch());
    });

    test('should close the list when a street of the secteur is '
        'tapped', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');

      notifier.tapStreet(StreetId('emile'));

      expect(stateOf(container).search, const NoStreetSearch());
    });

    test('should move the map to the street picked and tick it', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');

      final answer = await notifier.pick(_morinId);

      final state = stateOf(container);
      expect(answer, const NothingToSay());
      expect(state.search, const NoStreetSearch());
      expect(state.area, GeoBounds.around([_onMorin])!.expandedBy(200));
      expect(state.picked, [morinRow]);
      expect(state.pickedRoads.single.mark, _onMorin);
      // The street is known: no point to look up.
      expect(directory.pointsAsked, isEmpty);
    });

    test('should keep ticked a street picked again', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');
      await notifier.pick(_morinId);
      await notifier.search('morin');

      await notifier.pick(_morinId);

      expect(stateOf(container).picked, [morinRow]);
    });

    test('should keep the map on the street picked as the team adds '
        'streets', () async {
      sectors.put(team());
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');
      await notifier.pick(_morinId);

      await notifier.add();
      await pumpEventQueue();

      expect(
        stateOf(container).area,
        GeoBounds.around([_onMorin])!.expandedBy(200),
      );
    });

    test('should do nothing for a street not among the results', () async {
      final container = phone();
      await pumpEventQueue();

      final answer = await notifierOf(container).pick(_morinId);

      expect(answer, const NothingToSay());
      expect(stateOf(container).picked, isEmpty);
      expect(directory.streetsAsked, isEmpty);
    });
  });
  group('zone', () {
    /// A zone in the centre of Villefranche-sur-Saône.
    final zone = GeoBounds.of(
      south: 45.98,
      west: 4.71,
      north: 45.99,
      east: 4.73,
    )!;

    /// Another zone, just south of it.
    final southZone = GeoBounds.of(
      south: 45.97,
      west: 4.71,
      north: 45.98,
      east: 4.73,
    )!;

    /// A road across [zone] at [latitude]: its mark is at 4.714 E.
    StreetShape across(double latitude) => StreetShape([
      [at(latitude, 4.712), at(latitude, 4.716)],
    ]);

    final morinInZone = NamedRoad(
      name: 'Rue Pierre Morin',
      shape: across(45.985),
    );
    final pasteurInZone = NamedRoad(name: 'Rue Pasteur', shape: across(45.984));
    final nationaleInZone = NamedRoad(
      name: 'Rue Nationale',
      shape: across(45.986),
    );
    final halage = NamedRoad(name: 'Chemin de Halage', shape: across(45.987));
    final saoneInSouth = NamedRoad(
      name: 'Quai de la Saône',
      shape: StreetShape([
        [at(45.975, 4.712), at(45.975, 4.716)],
      ]),
    );
    final saoneId = BanStreetId('69264_1900');

    final morinZoneRow = ZoneStreetRow(
      kind: ZoneRowKind.toAdd,
      name: 'Rue Pierre Morin',
      id: _morinId,
      numberCount: 19,
      ticked: true,
    );

    DirectoryStreet listed(BanStreetId id, String name, int count) =>
        DirectoryStreet(id: id, name: streetName(name), numberCount: count);

    setUp(() {
      directory = FakeAddressDirectory(
        communes: {
          '69264': Ok(
            CommuneStreets(
              commune: villefranche,
              streets: [
                listed(_morinId, 'Rue Pierre Morin', 19),
                listed(_pasteurId, 'Rue Pasteur', 3),
                listed(_nationaleId, 'Rue Nationale', 40),
                listed(saoneId, 'Quai de la Saône', 12),
              ],
              skippedStreets: 0,
            ),
          ),
        },
        places: {_onMorin: Ok(_morinMatch)},
        streets: {_morinId: Ok(_morinNumbers), _pasteurId: Ok(_pasteurNumbers)},
      );
      shapes.roads = Ok([morinInZone, nationaleInZone, halage]);
    });

    /// Léa's phone, « Zone » on.
    Future<ProviderContainer> zoning() async {
      final container = phone();
      await pumpEventQueue();
      notifierOf(container).toggleZone();
      return container;
    }

    test('should be off when the screen opens', () async {
      final container = phone();
      await pumpEventQueue();

      expect(stateOf(container).zoneMode, isFalse);
      expect(stateOf(container).zone, const NoZone());
    });

    test('should turn « Zone » on, then off', () async {
      final container = await zoning();

      expect(stateOf(container).zoneMode, isTrue);
      notifierOf(container).toggleZone();
      expect(stateOf(container).zoneMode, isFalse);
    });

    test('should list the streets of the zone drawn, ticking those to '
        'add', () async {
      final container = await zoning();

      final answer = await notifierOf(container).drawZone(zone);

      expect(answer, const NothingToSay());
      expect(
        stateOf(container).zone,
        ZoneStreetsFound(zone, [
          morinZoneRow,
          ZoneStreetRow(
            kind: ZoneRowKind.inSector,
            name: 'Rue Nationale',
            id: _nationaleId,
          ),
          const ZoneStreetRow(
            kind: ZoneRowKind.noAddress,
            name: 'Chemin de Halage',
          ),
        ]),
      );
      expect(stateOf(container).picked, [
        PickedStreetRow(
          id: _morinId,
          name: 'Rue Pierre Morin',
          commune: 'Villefranche-sur-Saône',
          numberCount: 19,
        ),
      ]);
      expect(stateOf(container).pickedRoads, [
        PickedRoad(
          street: _morinId,
          road: across(45.985),
          mark: at(45.985, 4.714),
        ),
      ]);
      expect(shapes.zonesAsked, [zone]);
      // The numbers wait until the street is added.
      expect(directory.streetsAsked, isEmpty);
    });

    test('should show the zone while its streets are looked for', () async {
      shapes.holdRoads();
      final container = await zoning();

      final drawing = notifierOf(container).drawZone(zone);
      await pumpEventQueue();

      expect(stateOf(container).zone, FindingZoneStreets(zone));
      shapes.releaseRoads();
      await drawing;
      expect(stateOf(container).zone, isA<ZoneStreetsFound>());
    });

    test('should draw no zone with « Zone » off', () async {
      final container = phone();
      await pumpEventQueue();

      final answer = await notifierOf(container).drawZone(zone);

      expect(answer, const NothingToSay());
      expect(stateOf(container).zone, const NoZone());
      expect(shapes.zonesAsked, isEmpty);
    });

    test('should list the streets of a zone drawn however far out the '
        'map is', () async {
      // The zone has no zoom: its roads are read at street level whatever
      // the map shows.
      final container = await zoning();

      final answer = await notifierOf(container).drawZone(zone);

      expect(answer, const NothingToSay());
      expect(shapes.zonesAsked, [zone]);
    });

    test('should say the zone is too large when it needs too many tiles, '
        'listing nothing', () async {
      final container = await zoning();
      final notifier = notifierOf(container);
      await notifier.drawZone(zone);
      shapes.roads = const Err(StreetShapesFailure.tooLarge);

      final answer = await notifier.drawZone(southZone);

      expect(answer, const ZoneTooLarge());
      expect(stateOf(container).zone, const NoZone());
      // The ticks of the zone before stay.
      expect([for (final row in stateOf(container).picked) row.id], [_morinId]);
    });

    test('should say the zone is too large, listing nothing', () async {
      shapes.roads = Ok([
        for (var i = 0; i < 51; i++)
          NamedRoad(name: 'Chemin $i', shape: across(45.981 + i * 0.0001)),
      ]);
      final container = await zoning();

      final answer = await notifierOf(container).drawZone(zone);

      expect(answer, const ZoneTooLarge());
      expect(stateOf(container).zone, const NoZone());
      expect(stateOf(container).picked, isEmpty);
    });

    test('should say a connection is needed when offline', () async {
      shapes.roads = const Err(StreetShapesFailure.noNetwork);
      final container = await zoning();

      final answer = await notifierOf(container).drawZone(zone);

      expect(answer, const LookUpFailed(LookUpProblem.noNetwork));
      expect(stateOf(container).zone, const NoZone());
    });

    test('should say the service failed', () async {
      shapes.roads = const Err(StreetShapesFailure.serviceError);
      final container = await zoning();

      final answer = await notifierOf(container).drawZone(zone);

      expect(answer, const LookUpFailed(LookUpProblem.serviceError));
      expect(stateOf(container).zone, const NoZone());
    });

    test(
      'should keep a street ticked by a tap, once, among the zone\'s',
      () async {
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.tapMap(_onMorin);

        await notifier.drawZone(zone);

        expect(stateOf(container).picked, [morinRow]);
        // The ✓ stays where the finger tapped.
        expect(stateOf(container).pickedRoads.single.mark, _onMorin);
        final found = stateOf(container).zone as ZoneStreetsFound;
        expect(found.rows.first, morinZoneRow);
      },
    );

    test('should add up the streets of two zones', () async {
      final container = await zoning();
      final notifier = notifierOf(container);
      await notifier.drawZone(zone);
      shapes.roads = Ok([saoneInSouth]);

      await notifier.drawZone(southZone);

      expect(
        [for (final row in stateOf(container).picked) row.id],
        [_morinId, saoneId],
      );
      final found = stateOf(container).zone as ZoneStreetsFound;
      expect(found.area, southZone);
      expect([for (final row in found.rows) row.name], ['Quai de la Saône']);
    });

    test('should list only the last zone drawn', () async {
      shapes.holdRoads();
      final container = await zoning();
      final notifier = notifierOf(container);
      final first = notifier.drawZone(zone);
      await pumpEventQueue();
      shapes.roads = Ok([saoneInSouth]);

      await notifier.drawZone(southZone);
      shapes
        ..roads = Ok([morinInZone])
        ..releaseRoads();

      expect(await first, const NothingToSay());
      expect((stateOf(container).zone as ZoneStreetsFound).area, southZone);
      expect([for (final row in stateOf(container).picked) row.id], [saoneId]);
    });

    test('should leave the zone and keep the ticks when « Zone » goes '
        'off', () async {
      final container = await zoning();
      final notifier = notifierOf(container);
      await notifier.drawZone(zone);

      notifier.toggleZone();

      expect(stateOf(container).zone, const NoZone());
      expect(stateOf(container).picked, hasLength(1));
    });

    test('should list nothing once « Zone » went off meanwhile', () async {
      shapes.holdRoads();
      final container = await zoning();
      final notifier = notifierOf(container);
      final drawing = notifier.drawZone(zone);
      await pumpEventQueue();

      notifier.toggleZone();
      shapes.releaseRoads();

      expect(await drawing, const NothingToSay());
      expect(stateOf(container).zone, const NoZone());
      expect(stateOf(container).picked, isEmpty);
    });

    test('should drop the answer once the screen is closed', () async {
      shapes.holdRoads();
      final container = await zoning();
      final drawing = notifierOf(container).drawZone(zone);
      await pumpEventQueue();

      container.dispose();
      shapes.releaseRoads();

      expect(await drawing, const NothingToSay());
    });

    test('should close the search when a zone is drawn', () async {
      final container = await zoning();
      final notifier = notifierOf(container);
      await notifier.search('morin');

      await notifier.drawZone(zone);

      expect(stateOf(container).search, const NoStreetSearch());
    });

    group('its checkboxes', () {
      test('should untick a street of the zone, then tick it again', () async {
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);

        notifier.toggleZoneStreet(_morinId);

        expect(stateOf(container).picked, isEmpty);
        final unticked = stateOf(container).zone as ZoneStreetsFound;
        expect(unticked.rows.first.ticked, isFalse);

        notifier.toggleZoneStreet(_morinId);

        expect(stateOf(container).picked, hasLength(1));
        expect(stateOf(container).pickedRoads.single.mark, at(45.985, 4.714));
      });

      test('should tick nothing for a street of the secteur', () async {
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);

        notifier.toggleZoneStreet(_nationaleId);

        expect(
          [for (final row in stateOf(container).picked) row.id],
          [_morinId],
        );
      });

      test('should tick nothing with no zone listed', () async {
        final container = await zoning();

        notifierOf(container).toggleZoneStreet(_morinId);

        expect(stateOf(container).picked, isEmpty);
      });
    });

    group('adding', () {
      test('should read the numbers of a street of the zone and add it '
          'without its road', () async {
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);

        expect(await notifier.add(), 1);

        expect(directory.streetsAsked, [_morinId]);
        expect(streets.added.single.banId, _morinId);
        expect(streets.added.single.houses, hasLength(2));
        expect(streets.added.single.shape, StreetShape.none);
        expect(stateOf(container).run, const AddIdle());
      });

      test('should drop the zone once every street is added, « Zone » '
          'staying on for the next one', () async {
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);

        await notifier.add();

        expect(stateOf(container).zone, const NoZone());
        expect(stateOf(container).zoneMode, isTrue);
        expect(stateOf(container).picked, isEmpty);
        expect(stateOf(container).pickedRoads, isEmpty);
      });

      test('should keep the zone when a street failed, the street added '
          'showing as one of the secteur', () async {
        shapes.roads = Ok([morinInZone, pasteurInZone]);
        directory = FakeAddressDirectory(
          communes: {
            '69264': Ok(
              CommuneStreets(
                commune: villefranche,
                streets: [
                  listed(_morinId, 'Rue Pierre Morin', 19),
                  listed(_pasteurId, 'Rue Pasteur', 3),
                ],
                skippedStreets: 0,
              ),
            ),
          },
          streets: {
            _morinId: Ok(_morinNumbers),
            _pasteurId: const Err(AddressDirectoryFailure.serviceError),
          },
        );
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);

        await notifier.add();
        await pumpEventQueue();

        final found = stateOf(container).zone as ZoneStreetsFound;
        expect(found.area, zone);
        expect(found.rows, [
          ZoneStreetRow(
            kind: ZoneRowKind.toAdd,
            name: 'Rue Pasteur',
            id: _pasteurId,
            numberCount: 3,
            ticked: true,
          ),
          ZoneStreetRow(
            kind: ZoneRowKind.inSector,
            name: 'Rue Pierre Morin',
            id: _morinId,
          ),
        ]);
      });

      test('should count a street of the zone a teammate added '
          'meanwhile', () async {
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);
        await streets.add(
          valueOf(
            Street.create(
              id: StreetId('morin-by-manu'),
              name: 'Rue Pierre Morin',
              commune: villefranche,
              banId: _morinId,
              houses: [House(number: n('1'))],
            ),
          ),
        );

        expect(await notifier.add(), 1);

        expect(directory.streetsAsked, isEmpty);
        expect(stateOf(container).picked, isEmpty);
      });

      test('should stop offline, keeping the street and those after it '
          'ticked', () async {
        shapes.roads = Ok([morinInZone, pasteurInZone]);
        directory = FakeAddressDirectory(
          communes: {
            '69264': Ok(
              CommuneStreets(
                commune: villefranche,
                streets: [
                  listed(_morinId, 'Rue Pierre Morin', 19),
                  listed(_pasteurId, 'Rue Pasteur', 3),
                ],
                skippedStreets: 0,
              ),
            ),
          },
          places: {_onMorin: Ok(_morinMatch)},
          streets: {
            _morinId: Ok(_morinNumbers),
            _pasteurId: const Err(AddressDirectoryFailure.noNetwork),
          },
        );
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);
        // Ticked after the zone's, so it comes after Rue Pasteur.
        notifier
          ..toggleZoneStreet(_morinId)
          ..toggleZoneStreet(_morinId);

        expect(await notifier.add(), isNull);

        expect(directory.streetsAsked, [_pasteurId]);
        expect(streets.added, isEmpty);
        expect(
          stateOf(container).run,
          const AddFailed(2, problem: AddProblem.noNetwork),
        );
        expect(
          [for (final row in stateOf(container).picked) row.id],
          [_pasteurId, _morinId],
        );
      });

      test('should say the service failed, adding the others', () async {
        shapes.roads = Ok([morinInZone, pasteurInZone]);
        directory = FakeAddressDirectory(
          communes: {
            '69264': Ok(
              CommuneStreets(
                commune: villefranche,
                streets: [
                  listed(_morinId, 'Rue Pierre Morin', 19),
                  listed(_pasteurId, 'Rue Pasteur', 3),
                ],
                skippedStreets: 0,
              ),
            ),
          },
          streets: {
            _morinId: Ok(_morinNumbers),
            _pasteurId: const Err(AddressDirectoryFailure.serviceError),
          },
        );
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);

        expect(await notifier.add(), isNull);

        expect(streets.added.single.banId, _morinId);
        expect(
          stateOf(container).run,
          const AddFailed(1, problem: AddProblem.serviceError),
        );
      });

      test('should say the service failed for a street the BAN no longer '
          'knows', () async {
        shapes.roads = Ok([pasteurInZone]);
        directory = FakeAddressDirectory(
          communes: {
            '69264': Ok(
              CommuneStreets(
                commune: villefranche,
                streets: [listed(_pasteurId, 'Rue Pasteur', 3)],
                skippedStreets: 0,
              ),
            ),
          },
        );
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);

        expect(await notifier.add(), isNull);

        expect(
          stateOf(container).run,
          const AddFailed(1, problem: AddProblem.serviceError),
        );
      });

      test('should draw no zone and change no tick while adding', () async {
        final stored = Completer<void>();
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.tapMap(_onMorin);
        streets.holdAdds = stored;
        final adding = notifier.add();
        await pumpEventQueue();

        final answer = await notifier.drawZone(zone);
        notifier
          ..toggleZone()
          ..toggleZoneStreet(_morinId);

        expect(answer, const NothingToSay());
        // The tap asked for the roads under the finger, not the zone.
        expect(shapes.zonesAsked, isNot(contains(zone)));
        expect(stateOf(container).zoneMode, isTrue);
        expect(stateOf(container).picked, [morinRow]);
        stored.complete();
        await adding;
      });

      test('should tick nothing for a zone answered while adding', () async {
        shapes.roads = Ok([pasteurInZone]);
        final stored = Completer<void>();
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.tapMap(_onMorin);
        shapes.holdRoads();
        final drawing = notifier.drawZone(zone);
        await pumpEventQueue();
        streets.holdAdds = stored;
        final adding = notifier.add();
        await pumpEventQueue();

        shapes.releaseRoads();
        await drawing;

        expect(
          [for (final row in stateOf(container).picked) row.id],
          [_morinId],
        );
        expect(stateOf(container).run, const AddRunning(0, 1));
        stored.complete();
        await adding;
      });

      test('should keep a failure when a zone ticks nothing new', () async {
        directory = FakeAddressDirectory(
          communes: {
            '69264': Ok(
              CommuneStreets(
                commune: villefranche,
                streets: [listed(_pasteurId, 'Rue Pasteur', 3)],
                skippedStreets: 0,
              ),
            ),
          },
        );
        shapes.roads = Ok([pasteurInZone]);
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);
        await notifier.add();

        await notifier.drawZone(zone);

        expect(
          stateOf(container).run,
          const AddFailed(1, problem: AddProblem.serviceError),
        );
      });

      test('should forget a failure when a zone ticks a new street', () async {
        directory = FakeAddressDirectory(
          communes: {
            '69264': Ok(
              CommuneStreets(
                commune: villefranche,
                streets: [
                  listed(_pasteurId, 'Rue Pasteur', 3),
                  listed(saoneId, 'Quai de la Saône', 12),
                ],
                skippedStreets: 0,
              ),
            ),
          },
        );
        shapes.roads = Ok([pasteurInZone]);
        final container = await zoning();
        final notifier = notifierOf(container);
        await notifier.drawZone(zone);
        await notifier.add();
        shapes.roads = Ok([saoneInSouth]);

        await notifier.drawZone(southZone);

        expect(stateOf(container).run, const AddIdle());
      });
    });

    group('the communes', () {
      test('should match the streets in the nearest commune first', () async {
        // Around the centre of Gleizé, which the BAN fake does not list.
        final nearGleize = GeoBounds.of(
          south: 45.99,
          west: 4.68,
          north: 45.995,
          east: 4.69,
        )!;
        shapes.roads = Ok([
          NamedRoad(
            name: 'Rue Pierre Morin',
            shape: StreetShape([
              [at(45.992, 4.682), at(45.992, 4.686)],
            ]),
          ),
        ]);
        final container = await zoning();

        await notifierOf(container).drawZone(nearGleize);

        expect(directory.communesAsked, ['69092', '69264']);
      });

      test('should match last a commune without centre', () async {
        sectors.put(
          team(
            communes: [
              SectorCommune(commune: villefranche),
              gleizeCommune,
            ],
          ),
        );
        shapes.roads = Ok([halage]);
        final container = await zoning();
        await pumpEventQueue();

        await notifierOf(container).drawZone(zone);

        expect(directory.communesAsked, ['69092', '69264']);
      });

      test('should match in the communes of the streets for a secteur '
          'without commune', () async {
        sectors.put(team());
        final container = await zoning();
        await pumpEventQueue();

        await notifierOf(container).drawZone(zone);

        expect(directory.communesAsked, ['69264']);
      });
    });
  });
}
