import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' hide lea;
import '../../support/street_fixtures.dart' as streets_fixtures show lea;

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

final _morinMatch = _match(_morinId, 'Rue Pierre Morin', _onMorin);
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

/// Allée Émile Zola, typed in by hand, the member's.
final _emile = valueOf(
  Street.create(
    id: StreetId('emile'),
    name: 'Allée Émile Zola',
    commune: villefranche,
    assignees: {_me},
    houses: [House(number: n('4'))],
  ),
);

void main() {
  late FakeStreetRepository streets;
  late FakeTourneeRepository tournees;
  late FakeAddressDirectory directory;
  late FakeStreetShapes shapes;

  /// Léa's phone with the 49 open, or none when [open] is false.
  ProviderContainer phone({bool open = true}) {
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        tourneeRepositoryProvider.overrideWithValue(tournees),
        addressDirectoryProvider.overrideWithValue(directory),
        streetShapesProvider.overrideWithValue(shapes),
        identityProvider.overrideWithValue(FakeIdentity(_me)),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
        myTourneesStoreProvider.overrideWithValue(
          FakeMyTourneesStore(
            open
                ? valueOf(MyTournees.none.remember(tournee49).open(tourneeId))
                : MyTournees.none,
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
    tournees = FakeTourneeRepository([
      team(communes: [villefrancheCommune, gleizeCommune]),
    ]);
    directory = FakeAddressDirectory(
      places: {_onMorin: Ok(_morinMatch), _onNationale: Ok(_nationaleMatch)},
      streets: {_morinId: Ok(_morinNumbers)},
    );
    shapes = FakeStreetShapes(Ok(_morinRoad));
  });

  group('map', () {
    test('should draw the streets and open on the communes', () async {
      final container = phone();
      await pumpEventQueue();

      final state = stateOf(container);

      expect(state.layers.lines.single.street, StreetId('nationale'));
      expect(state.layers.dots.single.street, StreetId('nationale'));
      expect(state.area, communesArea([villefrancheCommune, gleizeCommune]));
      expect(state.card, isNull);
      expect(state.selectedRoad, StreetShape.none);
      expect(state.selectedPoint, isNull);
      expect(state.search, const NoStreetSearch());
    });

    test('should open on the streets for a tournée without commune', () async {
      tournees.put(team());
      final container = phone();
      await pumpEventQueue();

      expect(stateOf(container).area, tourneeArea([_nationale, _emile]));
    });

    test('should follow the communes as they change', () async {
      final container = phone();
      await pumpEventQueue();

      tournees.put(team(communes: [gleizeCommune]));
      await pumpEventQueue();

      expect(stateOf(container).area, communesArea([gleizeCommune]));
    });

    test('should open on the streets with no tournée open', () async {
      final container = phone(open: false);
      await pumpEventQueue();

      expect(stateOf(container).area, tourneeArea([_nationale, _emile]));
      expect(tournees.watched, isEmpty);
    });

    test('should draw nothing and show France before anything is read', () {
      streets.watchError = StateError('not yet');
      tournees.put(team());
      final container = phone();

      final state = stateOf(container);

      expect(state.layers.lines, isEmpty);
      expect(state.layers.dots, isEmpty);
      expect(state.area, isNull);
    });

    test('should draw no street once the streets cannot be read', () async {
      streets.watchError = StateError('removed');
      tournees.put(team());
      final container = phone();
      await pumpEventQueue();

      final state = stateOf(container);

      expect(state.layers.dots, isEmpty);
      expect(state.area, isNull);
    });
  });

  test('should keep showing the map when the tournée can no longer be '
      'read', () async {
    tournees.watchError = StateError('removed');
    final container = phone();
    await pumpEventQueue();

    notifierOf(container).tapStreet(StreetId('emile'));

    final card = stateOf(container).card! as StreetCardInTournee;
    expect(card.coverage, StreetCoverage.mine);
    expect(stateOf(container).area, tourneeArea([_nationale, _emile]));
  });

  group('a road tapped', () {
    test('should show the card loading and mark the point', () async {
      final container = phone();
      await pumpEventQueue();

      unawaited(notifierOf(container).tapMap(_onMorin));

      expect(stateOf(container).card, const StreetCardLoading());
      expect(stateOf(container).selectedPoint, _onMorin);
      expect(directory.pointsAsked, [_onMorin]);
    });

    test('should show the card of a street to add, with its numbers', () async {
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);

      expect(
        stateOf(container).card,
        const StreetCardToAdd(
          name: 'Rue Pierre Morin',
          commune: 'Villefranche-sur-Saône',
          numberCount: 2,
        ),
      );
      expect(directory.streetsAsked, [_morinId]);
    });

    test('should highlight the road once OpenStreetMap tells it', () async {
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);
      await pumpEventQueue();

      expect(stateOf(container).selectedRoad, _morinRoad);
      expect(stateOf(container).selectedPoint, _onMorin);
      expect(shapes.asked, [('Rue Pierre Morin', '69264')]);
    });

    test('should mark only the point while OpenStreetMap does not '
        'answer', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);
      await pumpEventQueue();

      expect(stateOf(container).selectedRoad, StreetShape.none);
      expect(stateOf(container).selectedPoint, _onMorin);
      answer.complete();
    });

    test('should mark only the point when OpenStreetMap fails', () async {
      shapes.answer = const Err(StreetShapesFailure.serviceError);
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);
      await pumpEventQueue();

      expect(stateOf(container).selectedRoad, StreetShape.none);
      expect(stateOf(container).selectedPoint, _onMorin);
    });

    test('should show the card of the tournée\'s street at the point, with '
        'its road', () async {
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onNationale);

      final state = stateOf(container);
      final card = state.card! as StreetCardInTournee;
      expect(card.id, StreetId('nationale'));
      expect(card.coverage, StreetCoverage.free);
      expect(state.selectedRoad, _nationaleRoad);
      expect(shapes.asked, isEmpty);
    });

    test('should say a connection is needed when offline', () async {
      directory = FakeAddressDirectory(
        places: {_onMorin: const Err(AddressDirectoryFailure.noNetwork)},
      );
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);

      expect(
        stateOf(container).card,
        const StreetCardFailed(LookUpProblem.noNetwork),
      );
      expect(stateOf(container).selectedPoint, _onMorin);
    });

    test('should say the BAN knows no street there', () async {
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_nowhere);

      expect(
        stateOf(container).card,
        const StreetCardFailed(LookUpProblem.noStreetHere),
      );
    });

    test('should say the address service failed', () async {
      directory = FakeAddressDirectory(
        places: {_onMorin: Ok(_morinMatch)},
        streets: {_morinId: const Err(AddressDirectoryFailure.serviceError)},
      );
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).tapMap(_onMorin);

      expect(
        stateOf(container).card,
        const StreetCardFailed(LookUpProblem.serviceError),
      );
    });

    test('should keep the last card asked when an earlier answer comes '
        'late', () async {
      directory.holdStreet(_morinId);
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      final late = notifier.tapMap(_onMorin);
      await pumpEventQueue();

      notifier.tapStreet(StreetId('emile'));
      directory.releaseStreet(_morinId);
      await late;

      final card = stateOf(container).card! as StreetCardInTournee;
      expect(card.id, StreetId('emile'));
      expect(shapes.asked, isEmpty);
    });

    test('should drop the road of a card replaced meanwhile', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);

      notifier.tapStreet(StreetId('emile'));
      answer.complete();
      await pumpEventQueue();

      expect(stateOf(container).selectedRoad, StreetShape.none);
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

        await expectLater(late, completes);
      },
    );
  });

  group('a street of the tournée tapped', () {
    test('should show its card at once, with its road', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container).tapStreet(StreetId('nationale'));

      final state = stateOf(container);
      expect(
        state.card,
        StreetCardInTournee(
          id: StreetId('nationale'),
          name: 'Rue Nationale',
          commune: 'Villefranche-sur-Saône',
          done: 0,
          total: 1,
          coverage: StreetCoverage.free,
          coveredBy: const [],
        ),
      );
      expect(state.selectedRoad, _nationaleRoad);
      expect(state.selectedPoint, isNull);
      expect(directory.pointsAsked, isEmpty);
    });

    test('should show nothing for a street no longer on the phone', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container).tapStreet(StreetId('gone'));

      expect(stateOf(container).card, isNull);
    });

    test('should give it to the member with « Me l\'attribuer »', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container)..tapStreet(StreetId('nationale'));

      await notifier.take();
      await pumpEventQueue();

      expect(streets[StreetId('nationale')]!.assignees, {_me});
      expect(
        (stateOf(container).card! as StreetCardInTournee).coverage,
        StreetCoverage.mine,
      );
    });

    test('should take the member off it with « Ne plus la faire »', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container)..tapStreet(StreetId('emile'));

      await notifier.release();
      await pumpEventQueue();

      expect(streets[StreetId('emile')]!.assignees, isEmpty);
      expect(
        (stateOf(container).card! as StreetCardInTournee).coverage,
        StreetCoverage.free,
      );
    });

    test('should take or release nothing without a street of the '
        'tournée\'s card', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);

      await notifier.take();
      await notifier.release();

      expect(streets.saved, isEmpty);
    });

    test('should close the card once the street went to the '
        'Corbeille', () async {
      final container = phone();
      await pumpEventQueue();
      notifierOf(container).tapStreet(StreetId('emile'));

      final (deleted, change) = _emile.delete(by: _me, at: twoPm);
      await streets.save(deleted, change);
      await pumpEventQueue();

      expect(stateOf(container).card, isNull);
    });

    test('should keep the card when another street changes', () async {
      final container = phone();
      await pumpEventQueue();
      notifierOf(container).tapStreet(StreetId('emile'));

      final (deleted, change) = _nationale.delete(by: _me, at: twoPm);
      await streets.save(deleted, change);
      await pumpEventQueue();

      expect(
        (stateOf(container).card! as StreetCardInTournee).id,
        StreetId('emile'),
      );
    });
  });

  test('should close the card, its road and its point', () async {
    final container = phone();
    await pumpEventQueue();
    final notifier = notifierOf(container);
    await notifier.tapMap(_onMorin);
    await pumpEventQueue();

    notifier.closeCard();

    final state = stateOf(container);
    expect(state.card, isNull);
    expect(state.selectedRoad, StreetShape.none);
    expect(state.selectedPoint, isNull);
  });

  group('adding the street of the card', () {
    test('should add it for the member with « Ajouter et me '
        'l\'attribuer », with the road found', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);

      await notifier.add(assignToMe: true);
      await pumpEventQueue();

      final added = streets.added.single;
      expect(added.banId, _morinId);
      expect(added.assignees, {_me});
      expect(added.shape, _morinRoad);
      // Asked once, for the card; the street was stored with it.
      expect(shapes.asked, hasLength(1));
      final card = stateOf(container).card! as StreetCardInTournee;
      expect(card.id, added.id);
      expect(card.coverage, StreetCoverage.mine);
      expect(stateOf(container).selectedRoad, _morinRoad);
    });

    test('should add it free with « Ajouter sans m\'attribuer »', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);

      await notifier.add(assignToMe: false);
      await pumpEventQueue();

      expect(streets.added.single.assignees, isEmpty);
      expect(
        (stateOf(container).card! as StreetCardInTournee).coverage,
        StreetCoverage.free,
      );
    });

    test('should show the street being added while its road is '
        'awaited', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);

      final adding = notifier.add(assignToMe: true);
      await pumpEventQueue();

      expect(
        stateOf(container).card,
        const StreetCardToAdd(
          name: 'Rue Pierre Morin',
          commune: 'Villefranche-sur-Saône',
          numberCount: 2,
          adding: true,
        ),
      );
      expect(streets.added, isEmpty);

      // A second tap on the button adds nothing more.
      await notifier.add(assignToMe: true);
      answer.complete();
      await adding;

      expect(streets.added, hasLength(1));
      expect(shapes.asked, hasLength(1));
    });

    test('should ask OpenStreetMap again when it failed for the '
        'card', () async {
      shapes.answer = const Err(StreetShapesFailure.noNetwork);
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      await pumpEventQueue();
      shapes.answer = Ok(_morinRoad);

      await notifier.add(assignToMe: true);

      expect(shapes.asked, hasLength(2));
      expect(streets.added.single.shape, _morinRoad);
    });

    test('should show the tournée\'s street when a teammate added it '
        'meanwhile', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      final teammates = valueOf(
        Street.create(
          id: StreetId('by-paul'),
          name: 'Rue Pierre Morin',
          commune: villefranche,
          banId: _morinId,
          assignees: {paul},
        ),
      );
      await streets.add(teammates);

      await notifier.add(assignToMe: true);

      final card = stateOf(container).card! as StreetCardInTournee;
      expect(card.id, StreetId('by-paul'));
      expect(card.coverage, StreetCoverage.others);
      expect(streets.added, [teammates]);
    });

    test('should say so when the numbers cannot make a street', () async {
      directory = FakeAddressDirectory(
        places: {_onMorin: Ok(_morinMatch)},
        streets: {
          _morinId: Ok(
            StreetNumbers(
              id: _morinId,
              name: streetName('Rue Pierre Morin'),
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
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);

      await notifier.add(assignToMe: true);

      expect(
        stateOf(container).card,
        const StreetCardToAdd(
          name: 'Rue Pierre Morin',
          commune: 'Villefranche-sur-Saône',
          numberCount: 2,
          addFailed: true,
        ),
      );
      expect(streets.added, isEmpty);
    });

    test('should add nothing without a street to add on the card', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container)..tapStreet(StreetId('nationale'));

      await notifier.add(assignToMe: true);

      expect(streets.added, isEmpty);
    });

    test('should keep another card asked while the street was '
        'added', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      final adding = notifier.add(assignToMe: true);
      await pumpEventQueue();

      notifier.tapStreet(StreetId('emile'));
      answer.complete();
      await adding;

      expect(streets.added, hasLength(1));
      expect(
        (stateOf(container).card! as StreetCardInTournee).id,
        StreetId('emile'),
      );
    });

    test('should still add the street when the screen closes', () async {
      final answer = Completer<void>();
      shapes.whileAsked = () => answer.future;
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      final adding = notifier.add(assignToMe: true);
      await pumpEventQueue();

      container.dispose();
      answer.complete();
      await adding;

      expect(streets.added, hasLength(1));
    });
  });

  group('search', () {
    final pasteurId = BanStreetId('69264_1200');
    final pasteurMatch = _match(
      pasteurId,
      'Rue Pasteur',
      at(45.98700, 4.72000),
    );

    test('should list the streets found in the tournée\'s communes', () async {
      directory = FakeAddressDirectory(
        searches: {
          'rue p': Ok([_morinMatch, pasteurMatch]),
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
            id: pasteurId,
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

    test('should search the communes of the streets for a tournée without '
        'commune', () async {
      tournees.put(team());
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
      directory = FakeAddressDirectory(
        places: {_onMorin: Ok(_morinMatch)},
        streets: {_morinId: Ok(_morinNumbers)},
        searches: {
          'morin': Ok([_morinMatch]),
        },
      );
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');

      await notifier.tapMap(_onMorin);

      expect(stateOf(container).search, const NoStreetSearch());
    });

    test('should close the list when a street of the tournée is '
        'tapped', () async {
      directory = FakeAddressDirectory(
        searches: {
          'morin': Ok([_morinMatch]),
        },
      );
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');

      notifier.tapStreet(StreetId('emile'));

      expect(stateOf(container).search, const NoStreetSearch());
    });

    test('should move the map to the street picked and show its '
        'card', () async {
      directory = FakeAddressDirectory(
        streets: {_morinId: Ok(_morinNumbers)},
        searches: {
          'morin': Ok([_morinMatch]),
        },
      );
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');

      await notifier.pick(_morinId);

      final state = stateOf(container);
      expect(state.search, const NoStreetSearch());
      expect(state.area, GeoBounds.around([_onMorin])!.expandedBy(200));
      expect(state.selectedPoint, _onMorin);
      expect((state.card! as StreetCardToAdd).name, 'Rue Pierre Morin');
      // The street is known: no point to look up.
      expect(directory.pointsAsked, isEmpty);
    });

    test('should keep the map on the street picked as the team adds '
        'streets', () async {
      directory = FakeAddressDirectory(
        streets: {_morinId: Ok(_morinNumbers)},
        searches: {
          'morin': Ok([_morinMatch]),
        },
      );
      tournees.put(team());
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('morin');
      await notifier.pick(_morinId);

      await notifier.add(assignToMe: true);
      await pumpEventQueue();

      expect(
        stateOf(container).area,
        GeoBounds.around([_onMorin])!.expandedBy(200),
      );
    });

    test('should do nothing for a street not among the results', () async {
      final container = phone();
      await pumpEventQueue();

      await notifierOf(container).pick(_morinId);

      expect(stateOf(container).card, isNull);
      expect(directory.streetsAsked, isEmpty);
    });
  });
}
