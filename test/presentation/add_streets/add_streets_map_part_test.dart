// The part of each street ticked on « Carte » (PLAN §5.15 « When
// adding »): « Toute la rue › » opens « Partie de la rue », the part chosen
// goes with the tick, and « Ajouter N rues » stores only its numbers.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
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

final _tilleulsId = BanStreetId('69264_2010');

/// Where the finger taps on Impasse des Tilleuls, not yet in the secteur.
final _onTilleuls = at(45.98850, 4.72500);

final _tilleulsMatch = StreetMatch(
  id: _tilleulsId,
  name: streetName('Impasse des Tilleuls'),
  commune: villefranche,
  position: _onTilleuls,
);

/// Impasse des Tilleuls: 1 to 4, the 1 and the 2 with an entrance.
final _tilleulsNumbers = StreetNumbers(
  id: _tilleulsId,
  name: streetName('Impasse des Tilleuls'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('1'), position: at(45.98810, 4.72500)),
    DirectoryNumber(number: n('2'), position: at(45.98820, 4.72500)),
    DirectoryNumber(number: n('3')),
    DirectoryNumber(number: n('4')),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

/// Its road as the map draws it.
final _tilleulsRoad = StreetShape([
  [at(45.98800, 4.72500), at(45.98900, 4.72500)],
]);

/// The even numbers only: the 2 and the 4 of the four.
final _evens = part(odd: SidePart.none, even: SidePart.all);

/// A zone around Impasse des Tilleuls.
final _zone = GeoBounds.of(south: 45.98, west: 4.71, north: 45.99, east: 4.73)!;

void main() {
  late FakeStreetRepository streets;
  late FakeAddressDirectory directory;
  late FakeStreetShapes shapes;

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
        streetShapesProvider.overrideWithValue(shapes),
        identityProvider.overrideWithValue(FakeIdentity(streets_fixtures.lea)),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('street')),
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

  /// The request of [opening], which must be one.
  StreetPartChoice choiceOf(PartOpening opening) =>
      (opening as PartToChoose).request.choice;

  setUp(() {
    streets = FakeStreetRepository();
    directory = FakeAddressDirectory(
      places: {_onTilleuls: Ok(_tilleulsMatch)},
      streets: {_tilleulsId: Ok(_tilleulsNumbers)},
    );
    shapes = FakeStreetShapes()
      ..answers['Impasse des Tilleuls'] = Ok(_tilleulsRoad);
  });

  /// Léa's phone, Impasse des Tilleuls ticked by a tap, its road found.
  Future<ProviderContainer> tapped() async {
    final container = phone();
    await pumpEventQueue();
    await notifierOf(container).tapMap(_onTilleuls);
    await pumpEventQueue();
    return container;
  }

  group('a street ticked by a tap', () {
    test('should hold the whole street at first', () async {
      final container = await tapped();

      expect(stateOf(container).picked, [
        PickedStreetRow(
          id: _tilleulsId,
          name: 'Impasse des Tilleuls',
          commune: 'Villefranche-sur-Saône',
          numberCount: 4,
        ),
      ]);
    });

    test('should open « Partie de la rue » on its numbers and road, with '
        'no new read', () async {
      final container = await tapped();

      final opening = await notifierOf(container).openPart(_tilleulsId);

      final request = (opening as PartToChoose).request;
      expect(request.streetName, 'Impasse des Tilleuls');
      expect(request.choice.numbers, [
        PartNumber(n('1'), position: at(45.98810, 4.72500)),
        PartNumber(n('2'), position: at(45.98820, 4.72500)),
        PartNumber(n('3')),
        PartNumber(n('4')),
      ]);
      expect(request.choice.road, _tilleulsRoad);
      expect(request.choice.part, StreetPart.whole);
      expect(directory.streetsAsked, [_tilleulsId]);
    });

    test('should show the part chosen and how many numbers it '
        'keeps', () async {
      final container = await tapped();

      notifierOf(container).choosePart(_tilleulsId, _evens);

      expect(stateOf(container).picked, [
        PickedStreetRow(
          id: _tilleulsId,
          name: 'Impasse des Tilleuls',
          commune: 'Villefranche-sur-Saône',
          numberCount: 4,
          part: _evens,
          keptCount: 2,
        ),
      ]);
    });

    test('should open again on the part chosen', () async {
      final container = await tapped();
      final notifier = notifierOf(container)..choosePart(_tilleulsId, _evens);

      final opening = await notifier.openPart(_tilleulsId);

      expect(choiceOf(opening).part, _evens);
      expect(choiceOf(opening).keptCount, 2);
    });

    test('should forget the part once the whole street is chosen '
        'again', () async {
      final container = await tapped();
      notifierOf(container)
        ..choosePart(_tilleulsId, _evens)
        ..choosePart(_tilleulsId, StreetPart.whole);

      final row = stateOf(container).picked.single;
      expect(row.part, StreetPart.whole);
      expect(row.keptCount, isNull);
    });

    test('should keep the road found after the part was chosen', () async {
      final road = Completer<void>();
      shapes.whileAsked = () => road.future;
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container);
      await notifier.tapMap(_onTilleuls);
      notifier.choosePart(_tilleulsId, _evens);

      road.complete();
      await pumpEventQueue();

      expect(stateOf(container).pickedRoads.single.road, _tilleulsRoad);
      expect(stateOf(container).picked.single.part, _evens);
      expect(stateOf(container).keepInView, isNotNull);
    });

    test('should add only the numbers of the part, with the part', () async {
      final container = await tapped();
      final notifier = notifierOf(container)..choosePart(_tilleulsId, _evens);

      expect(await notifier.add(), 1);

      final added = streets.added.single;
      expect(added.part, _evens);
      expect(added.houses, [
        House(number: n('2'), position: at(45.98820, 4.72500)),
        House(number: n('4')),
      ]);
      expect(added.shape, _tilleulsRoad);
    });

    test('should keep the part of a street that failed to be '
        'added', () async {
      // The BAN gives the 2 twice, which no street can take: the street
      // stays ticked, its part with it.
      directory.streets[_tilleulsId] = Ok(
        StreetNumbers(
          id: _tilleulsId,
          name: streetName('Impasse des Tilleuls'),
          commune: villefranche,
          numbers: [
            DirectoryNumber(number: n('2')),
            DirectoryNumber(number: n('2')),
          ],
          invalidNumbers: 0,
          duplicateNumbers: 0,
        ),
      );
      final container = await tapped();
      final notifier = notifierOf(container)..choosePart(_tilleulsId, _evens);

      expect(await notifier.add(), isNull);

      expect(stateOf(container).picked.single.part, _evens);
    });

    test('should drop the part with the tick', () async {
      final container = await tapped();
      final notifier = notifierOf(container)
        ..choosePart(_tilleulsId, _evens)
        ..untick(_tilleulsId);

      await notifier.tapMap(_onTilleuls);

      expect(stateOf(container).picked.single.part, StreetPart.whole);
    });

    test('should open nothing for a street not ticked', () async {
      final container = phone();
      await pumpEventQueue();

      expect(
        await notifierOf(container).openPart(_tilleulsId),
        const PartNotOpened(),
      );
    });

    test('should change nothing for a street not ticked', () async {
      final container = phone();
      await pumpEventQueue();

      notifierOf(container).choosePart(_tilleulsId, _evens);

      expect(stateOf(container).picked, isEmpty);
    });

    test('should neither open nor change a part while the streets are '
        'added', () async {
      final container = await tapped();
      final notifier = notifierOf(container);
      final hold = Completer<void>();
      streets.holdAdds = hold;
      final adding = notifier.add();
      await pumpEventQueue();

      expect(await notifier.openPart(_tilleulsId), const PartNotOpened());
      notifier.choosePart(_tilleulsId, _evens);
      hold.complete();
      await adding;

      expect(streets.added.single.part, StreetPart.whole);
    });
  });

  group('a street of the Corbeille', () {
    setUp(() async {
      final kept = valueOf(
        Street.create(
          id: StreetId('tilleuls'),
          name: 'Impasse des Tilleuls',
          commune: villefranche,
          banId: _tilleulsId,
          houses: [House(number: n('1'))],
        ),
      );
      final (deleted, _) = kept.delete(by: streets_fixtures.lea, at: twoPm);
      streets = FakeStreetRepository([deleted]);
    });

    test('should say it comes from the Corbeille, with no part to '
        'choose', () async {
      final container = await tapped();

      expect(stateOf(container).picked.single.fromCorbeille, isTrue);
      expect(
        await notifierOf(container).openPart(_tilleulsId),
        const PartNotOpened(),
      );
    });
  });

  group('a street ticked in a zone', () {
    setUp(() {
      directory = FakeAddressDirectory(
        communes: {
          '69264': Ok(
            CommuneStreets(
              commune: villefranche,
              streets: [
                DirectoryStreet(
                  id: _tilleulsId,
                  name: streetName('Impasse des Tilleuls'),
                  numberCount: 5,
                ),
              ],
              skippedStreets: 0,
            ),
          ),
        },
        streets: {_tilleulsId: Ok(_tilleulsNumbers)},
      );
      shapes.roads = Ok([
        NamedRoad(name: 'Impasse des Tilleuls', shape: _tilleulsRoad),
      ]);
    });

    Future<ProviderContainer> zoned() async {
      final container = phone();
      await pumpEventQueue();
      final notifier = notifierOf(container)..toggleZone();
      await notifier.drawZone(_zone);
      return container;
    }

    ZoneStreetRow rowOf(ProviderContainer container) =>
        (stateOf(container).zone as ZoneStreetsFound).rows.single;

    test('should read its numbers to open « Partie de la rue », the row '
        'waiting meanwhile', () async {
      final container = await zoned();
      directory.holdStreet(_tilleulsId);

      final opening = notifierOf(container).openPart(_tilleulsId);
      await pumpEventQueue();

      expect(rowOf(container).readingPart, isTrue);
      expect(stateOf(container).picked.single.readingPart, isTrue);
      directory.releaseStreet(_tilleulsId);
      final choice = choiceOf(await opening);
      expect(choice.numberCount, 4);
      expect(choice.road, _tilleulsRoad);
      expect(rowOf(container).readingPart, isFalse);
      expect(directory.streetsAsked, [_tilleulsId]);
    });

    test('should keep the count the zone listed until a part is '
        'chosen', () async {
      final container = await zoned();

      await notifierOf(container).openPart(_tilleulsId);

      expect(rowOf(container).numberCount, 5);
      expect(rowOf(container).keptCount, isNull);
      expect(stateOf(container).picked.single.numberCount, 4);
    });

    test('should say a street of the Corbeille has no part to '
        'choose', () async {
      final kept = valueOf(
        Street.create(
          id: StreetId('tilleuls'),
          name: 'Impasse des Tilleuls',
          commune: villefranche,
          banId: _tilleulsId,
        ),
      );
      final (deleted, _) = kept.delete(by: streets_fixtures.lea, at: twoPm);
      streets = FakeStreetRepository([deleted]);
      final container = await zoned();

      expect(rowOf(container).fromCorbeille, isTrue);
      expect(stateOf(container).picked.single.fromCorbeille, isTrue);
      expect(
        await notifierOf(container).openPart(_tilleulsId),
        const PartNotOpened(),
      );
      expect(directory.streetsAsked, isEmpty);
    });

    test('should say an unticked street of the Corbeille has no part to '
        'choose either', () async {
      final kept = valueOf(
        Street.create(
          id: StreetId('tilleuls'),
          name: 'Impasse des Tilleuls',
          commune: villefranche,
          banId: _tilleulsId,
        ),
      );
      final (deleted, _) = kept.delete(by: streets_fixtures.lea, at: twoPm);
      streets = FakeStreetRepository([deleted]);
      final container = await zoned();

      notifierOf(container).untick(_tilleulsId);

      expect(rowOf(container).ticked, isFalse);
      expect(rowOf(container).fromCorbeille, isTrue);
    });

    test('should open nothing once the screen is closed', () async {
      final container = await zoned();
      directory.holdStreet(_tilleulsId);
      final opening = notifierOf(container).openPart(_tilleulsId);
      await pumpEventQueue();

      container.dispose();
      directory.releaseStreet(_tilleulsId);

      expect(await opening, const PartNotOpened());
    });

    test('should not open twice while its numbers are read', () async {
      final container = await zoned();
      directory.holdStreet(_tilleulsId);
      final notifier = notifierOf(container);

      final first = notifier.openPart(_tilleulsId);
      final second = await notifier.openPart(_tilleulsId);
      directory.releaseStreet(_tilleulsId);
      await first;

      expect(second, const PartNotOpened());
      expect(directory.streetsAsked, [_tilleulsId]);
    });

    test('should show the part chosen in the zone and the selection, '
        'counting the numbers read', () async {
      final container = await zoned();
      final notifier = notifierOf(container);
      await notifier.openPart(_tilleulsId);

      notifier.choosePart(_tilleulsId, _evens);

      expect(
        rowOf(container),
        ZoneStreetRow(
          kind: ZoneRowKind.toAdd,
          name: 'Impasse des Tilleuls',
          id: _tilleulsId,
          numberCount: 4,
          ticked: true,
          part: _evens,
          keptCount: 2,
        ),
      );
      expect(stateOf(container).picked.single.keptCount, 2);
      expect(stateOf(container).picked.single.numberCount, 4);
    });

    test('should add it with its part without reading its numbers '
        'again', () async {
      final container = await zoned();
      final notifier = notifierOf(container);
      await notifier.openPart(_tilleulsId);
      notifier.choosePart(_tilleulsId, _evens);

      await notifier.add();

      expect(directory.streetsAsked, [_tilleulsId]);
      expect(streets.added.single.part, _evens);
      expect(streets.added.single.houses.map((house) => house.number), [
        n('2'),
        n('4'),
      ]);
      expect(streets.added.single.shape, StreetShape.none);
    });

    test('should open nothing once unticked while its numbers were '
        'read', () async {
      final container = await zoned();
      directory.holdStreet(_tilleulsId);
      final notifier = notifierOf(container);

      final opening = notifier.openPart(_tilleulsId);
      notifier.untick(_tilleulsId);
      directory.releaseStreet(_tilleulsId);

      expect(await opening, const PartNotOpened());
      expect(stateOf(container).picked, isEmpty);
    });

    test('should say offline when its numbers cannot be read', () async {
      final container = await zoned();
      directory.streets[_tilleulsId] = const Err(
        AddressDirectoryFailure.noNetwork,
      );

      final opening = await notifierOf(container).openPart(_tilleulsId);

      expect(opening, const PartUnreadable(PartReadProblem.noNetwork));
      expect(rowOf(container).readingPart, isFalse);
      expect(rowOf(container).part, StreetPart.whole);
    });

    test('should say the service failed when the BAN answers with an error '
        'or no longer knows the street', () async {
      final container = await zoned();
      final notifier = notifierOf(container);
      directory.streets[_tilleulsId] = const Err(
        AddressDirectoryFailure.serviceError,
      );
      final failed = await notifier.openPart(_tilleulsId);
      directory.streets[_tilleulsId] = const Err(
        AddressDirectoryFailure.notFound,
      );
      final unknown = await notifier.openPart(_tilleulsId);

      expect(failed, const PartUnreadable(PartReadProblem.unavailable));
      expect(unknown, const PartUnreadable(PartReadProblem.unavailable));
    });

    test('should say so when a teammate added it meanwhile', () async {
      final container = await zoned();
      await streets.add(
        valueOf(
          Street.create(
            id: StreetId('tilleuls-by-paul'),
            name: 'Impasse des Tilleuls',
            commune: villefranche,
            banId: _tilleulsId,
          ),
        ),
      );

      final opening = await notifierOf(container).openPart(_tilleulsId);

      expect(opening, const PartOfStreetInSector('Impasse des Tilleuls'));
    });

    test('should open nothing when the streets started being added while '
        'its numbers were read', () async {
      final container = await zoned();
      directory.holdStreet(_tilleulsId);
      final notifier = notifierOf(container);

      final opening = notifier.openPart(_tilleulsId);
      await pumpEventQueue();
      final adding = notifier.add();
      directory.releaseStreet(_tilleulsId);

      expect(await opening, const PartNotOpened());
      await adding;
    });
  });
}
