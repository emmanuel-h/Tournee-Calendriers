// The card of a street of the secteur tapped on « Carte » (PLAN §5.19,
// PickInSector mockup): it shows in place of the selection sheet, from the
// phone's copy, leaves the ticks alone, and sends the street to the
// Corbeille as edit mode does.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/held_stretch.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_part_index.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' as streets_fixtures show lea;
import '../../support/street_fixtures.dart' hide lea;

final _morinId = BanStreetId('69264_1460');
final _nationaleId = BanStreetId('69264_1781');

/// Where the finger taps on Rue Pierre Morin, not yet in the secteur.
final _onMorin = at(45.98850, 4.72500);

/// Where the finger taps on Rue Nationale, in the secteur, away from its
/// line (the BAN tells which street it is).
final _nearNationale = at(45.98915, 4.71862);

/// Where the finger touches Rue Nationale's line.
final _onNationaleLine = at(45.99000, 4.71800);

final _morinMatch = StreetMatch(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  position: _onMorin,
);

final _nationaleMatch = StreetMatch(
  id: _nationaleId,
  name: streetName('Rue Nationale'),
  commune: villefranche,
  position: _nearNationale,
);

final _morinNumbers = StreetNumbers(
  id: _morinId,
  name: streetName('Rue Pierre Morin'),
  commune: villefranche,
  numbers: [DirectoryNumber(number: n('1'), position: _onMorin)],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

final _nationaleRoad = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);

/// Rue Nationale, in the secteur: 1 of its 2 doors done.
final _nationale = valueOf(
  Street.create(
    id: StreetId('nationale'),
    name: 'Rue Nationale',
    commune: villefranche,
    banId: _nationaleId,
    shape: _nationaleRoad,
    houses: [
      House(number: n('1'), position: townHallDoor, status: VisitStatus.done),
      House(number: n('2')),
    ],
  ),
);

/// Rue des Lilas, held « impairs 5–7 » only.
final _lilasPart = part(odd: range(5, 7), even: SidePart.none);
final _lilas = valueOf(
  Street.create(
    id: StreetId('lilas'),
    name: 'Rue des Lilas',
    commune: villefranche,
    shape: StreetShape([
      [at(45.98, 4.7200), at(45.98, 4.7210)],
    ]),
    part: _lilasPart,
    houses: [
      House(number: n('5'), position: at(45.98002, 4.7204)),
      House(number: n('7'), position: at(45.98002, 4.7206)),
    ],
  ),
);

final _nationaleCard = StreetCardInSector(
  id: StreetId('nationale'),
  name: 'Rue Nationale',
  commune: 'Villefranche-sur-Saône',
  done: 1,
  total: 2,
);

final _twoPm = DateTime.utc(2026, 11, 14, 14);

void main() {
  late FakeStreetRepository streets;
  late FakeAddressDirectory directory;

  ProviderContainer phone() {
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        sectorRepositoryProvider.overrideWithValue(
          FakeSectorRepository([
            team(communes: [villefrancheCommune]),
          ]),
        ),
        addressDirectoryProvider.overrideWithValue(directory),
        streetShapesProvider.overrideWithValue(FakeStreetShapes()),
        streetPartIndexProvider.overrideWithValue(FakeStreetPartIndex()),
        identityProvider.overrideWithValue(FakeIdentity(streets_fixtures.lea)),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
        clockProvider.overrideWithValue(FakeClock(_twoPm)),
        mySectorsStoreProvider.overrideWithValue(
          FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sectorId)),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The screen listens to the `autoDispose` provider: so does the test.
    container.listen(addStreetsMapProvider, (_, _) {});
    return container;
  }

  AddStreetsMapState stateOf(ProviderContainer container) =>
      container.read(addStreetsMapProvider);

  AddStreetsMapNotifier notifierOf(ProviderContainer container) =>
      container.read(addStreetsMapProvider.notifier);

  setUp(() {
    streets = FakeStreetRepository([_nationale, _lilas]);
    directory = FakeAddressDirectory(
      places: {_onMorin: Ok(_morinMatch), _nearNationale: Ok(_nationaleMatch)},
      streets: {_morinId: Ok(_morinNumbers)},
      searches: {
        'nationale': Ok([_nationaleMatch]),
      },
    );
  });

  group('a street of the secteur tapped', () {
    test('should show its card at once, its line lit up and the point '
        'tapped marked, asking nothing of the network', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container)
          .tapStreet(StreetId('nationale'), at: _onNationaleLine);

      final state = stateOf(container);
      expect(state.card, _nationaleCard);
      expect(state.cardRoad, _nationaleRoad);
      expect(state.cardPoint, _onNationaleLine);
      expect(state.selectedPoint, _onNationaleLine);
      expect(state.picked, isEmpty);
      expect(directory.pointsAsked, isEmpty);
    });

    test('should show the part of a street held in part, and light up only '
        'its stretch', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container).tapStreet(StreetId('lilas'));

      final state = stateOf(container);
      expect(state.card?.part, _lilasPart);
      expect(state.cardRoad, heldStretchOf(_lilas));
      expect(state.cardPoint, isNull);
    });

    test('should leave the streets ticked as they are', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      final picked = stateOf(container).picked;
      final roads = stateOf(container).pickedRoads;

      notifier.tapStreet(StreetId('nationale'), at: _onNationaleLine);

      expect(stateOf(container).picked, picked);
      expect(stateOf(container).pickedRoads, roads);
      expect(stateOf(container).picked.single.id, _morinId);
    });

    test('should show no card for a street no longer on the phone', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      notifier.tapStreet(StreetId('nationale'));

      notifier.tapStreet(StreetId('gone'));

      expect(stateOf(container).card, isNull);
      expect(stateOf(container).cardRoad, StreetShape.none);
    });

    test('should show the card of the street tapped next', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      notifier.tapStreet(StreetId('nationale'));

      notifier.tapStreet(StreetId('lilas'));

      expect(stateOf(container).card?.id, StreetId('lilas'));
    });

    test('should show no card while the streets are being added', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      streets.holdAdds = Completer();
      final adding = notifier.add();
      await pumpEventQueue();

      notifier.tapStreet(StreetId('nationale'));

      expect(stateOf(container).card, isNull);
      streets.holdAdds!.complete();
      await adding;
    });
  });

  group('a look-up finding a street of the secteur', () {
    test('should show its card from a tap beside its line', () async {
      final container = phone();
      await pumpEventQueue();

      final answer = await notifierOf(container).tapMap(_nearNationale);

      final state = stateOf(container);
      expect(answer, const NothingToSay());
      expect(state.card, _nationaleCard);
      expect(state.cardPoint, _nearNationale);
      expect(state.lookingAt, isNull);
      expect(state.picked, isEmpty);
    });

    test('should show its card when picked among the search results', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.search('nationale');

      final answer = await notifier.pick(_nationaleId);

      expect(answer, const NothingToSay());
      expect(stateOf(container).card, _nationaleCard);
      expect(stateOf(container).cardPoint, _nearNationale);
    });

    test('should show no card once closed before the answer came', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      final answer = notifier.tapMap(_nearNationale);

      notifier.closeCard();
      await answer;

      expect(stateOf(container).card, isNull);
    });
  });

  group('the card closed', () {
    test('should go with its ✕ or the back gesture, the ticks kept', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      notifier.tapStreet(StreetId('nationale'), at: _onNationaleLine);

      notifier.closeCard();

      final state = stateOf(container);
      expect(state.card, isNull);
      expect(state.cardRoad, StreetShape.none);
      expect(state.cardPoint, isNull);
      expect(state.selectedPoint, isNull);
      expect(state.picked.single.id, _morinId);
    });

    test('should go with a tap on another road, which is ticked', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      notifier.tapStreet(StreetId('nationale'));

      await notifier.tapMap(_onMorin);

      expect(stateOf(container).card, isNull);
      expect(stateOf(container).picked.single.id, _morinId);
    });

    test('should go with « Zone » turned on', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      notifier.tapStreet(StreetId('nationale'));

      notifier.toggleZone();

      expect(stateOf(container).card, isNull);
      expect(stateOf(container).zoneMode, isTrue);
    });

    test('should go with a zone drawn', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      notifier.toggleZone();
      notifier.tapStreet(StreetId('nationale'));

      unawaited(
        notifier.drawZone(GeoBounds.around([_onMorin, _nearNationale])!),
      );

      expect(stateOf(container).card, isNull);
    });

    test('should go when a teammate deletes the street, and not come back '
        'when it is restored', () async {
      final container = phone();
      await pumpEventQueue();
      notifierOf(container).tapStreet(StreetId('nationale'));
      final (deleted, deleting) = _nationale.delete(
        by: streets_fixtures.lea,
        at: _twoPm,
      );

      await streets.save(deleted, deleting);
      await pumpEventQueue();
      expect(stateOf(container).card, isNull);

      final (restored, restoring) = deleted.restore();
      await streets.save(restored, restoring);
      await pumpEventQueue();
      expect(stateOf(container).card, isNull);
    });
  });

  group('« Supprimer la rue »', () {
    test('should send the street to the Corbeille as edit mode does, and '
        'close the card', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onMorin);
      notifier.tapStreet(StreetId('nationale'));

      final name = await notifier.deleteShownStreet();
      await pumpEventQueue();

      expect(name, 'Rue Nationale');
      final (stored, change) = streets.saved.single;
      expect(stored.id, StreetId('nationale'));
      expect(stored.isDeleted, isTrue);
      expect(
        change,
        StreetDeleted(
          streetId: StreetId('nationale'),
          deletion: ChangeStamp(by: streets_fixtures.lea, at: _twoPm),
        ),
      );
      final state = stateOf(container);
      expect(state.card, isNull);
      expect(state.layers.lines.map((line) => line.street), [
        StreetId('lilas'),
      ]);
      expect(state.picked.single.id, _morinId);
    });

    test('should delete nothing with no card', () async {
      final container = phone();
      await pumpEventQueue();

      final name = await notifierOf(container).deleteShownStreet();

      expect(name, isNull);
      expect(streets.saved, isEmpty);
    });

    test('should say nothing when the street went meanwhile', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      notifier.tapStreet(StreetId('nationale'));
      // Gone from the phone before the map heard of it.
      unawaited(streets.purge(StreetId('nationale')));

      final name = await notifier.deleteShownStreet();

      expect(name, isNull);
      expect(streets.saved, isEmpty);
      expect(stateOf(container).card, isNull);
    });
  });
}
