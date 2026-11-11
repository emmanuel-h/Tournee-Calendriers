import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/map/held_stretch.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/home/home_notifier.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart'
    show
        createdAt,
        gleizeCommune,
        julie,
        lea,
        manu,
        team,
        sectorId,
        villefrancheCommune;
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' hide lea;

final _lea = MemberId('lea');

final _nationaleShape = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);

/// Rue Nationale: on the map, 1 of 3 doors done.
final _nationale = valueOf(
  Street.create(
    id: StreetId('nationale'),
    name: 'Rue Nationale',
    commune: villefranche,
    shape: _nationaleShape,
    houses: [
      House(
        number: n('1'),
        status: VisitStatus.done,
        position: at(45.98920, 4.71860),
      ),
      House(number: n('2'), status: VisitStatus.nobodyHome),
      House(number: n('3')),
    ],
  ),
);

/// Allée Émile Zola: typed in by hand, 0 of 1.
final _emile = valueOf(
  Street.create(
    id: StreetId('emile'),
    name: 'Allée Émile Zola',
    commune: villefranche,
    houses: [House(number: n('4'))],
  ),
);

/// Rue de la Paix: 2 of 2 done.
final _paix = valueOf(
  Street.create(
    id: StreetId('paix'),
    name: 'Rue de la Paix',
    commune: villefranche,
    houses: [
      House(number: n('5'), status: VisitStatus.done),
      House(number: n('6'), status: VisitStatus.done),
    ],
  ),
);

/// Rue Victor Hugo: 0 of 4.
final _hugo = valueOf(
  Street.create(
    id: StreetId('hugo'),
    name: 'Rue Victor Hugo',
    commune: villefranche,
    houses: [
      for (final number in ['7', '8', '9', '10']) House(number: n(number)),
    ],
  ),
);

/// Rue Pierre Morin: a single house on the map, far north.
final _morin = valueOf(
  Street.create(
    id: StreetId('morin'),
    name: 'Rue Pierre Morin',
    commune: villefranche,
    houses: [House(number: n('11'), position: at(46.0100, 4.7300))],
  ),
);

/// The road of Rue Pierre Morin, as the map draws it.
final _morinRoad = StreetShape([
  [at(46.0095, 4.7300), at(46.0105, 4.7300)],
]);

/// Rue des Lilas, held « impairs 5–7 » only: the map draws the stretch
/// around its houses 5 and 7, not the whole road.
final _lilas = valueOf(
  Street.create(
    id: StreetId('lilas'),
    name: 'Rue des Lilas',
    commune: villefranche,
    shape: StreetShape([
      [at(45.98, 4.7200), at(45.98, 4.7210)],
    ]),
    part: part(odd: range(5, 7), even: SidePart.none),
    houses: [
      House(number: n('5'), position: at(45.98002, 4.7204)),
      House(number: n('7'), position: at(45.98002, 4.7206)),
    ],
  ),
);

final _nationaleRow = StreetRow(
  id: StreetId('nationale'),
  name: 'Rue Nationale',
  done: 1,
  total: 3,
);
final _emileRow = StreetRow(
  id: StreetId('emile'),
  name: 'Allée Émile Zola',
  done: 0,
  total: 1,
);
final _paixRow = StreetRow(
  id: StreetId('paix'),
  name: 'Rue de la Paix',
  done: 2,
  total: 2,
);
final _hugoRow = StreetRow(
  id: StreetId('hugo'),
  name: 'Rue Victor Hugo',
  done: 0,
  total: 4,
);

void main() {
  late FakeStreetRepository streets;
  late FakeSectorRepository sectors;
  late FakeStreetShapes shapes;

  /// Léa's phone with [open] open (the 49 by default), or none.
  ProviderContainer phone({SectorSummary? open}) {
    final opened = open ?? sector49;
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        sectorRepositoryProvider.overrideWithValue(sectors),
        streetShapesProvider.overrideWithValue(shapes),
        clockProvider.overrideWithValue(FakeClock(createdAt)),
        identityProvider.overrideWithValue(FakeIdentity(_lea)),
        mySectorsStoreProvider.overrideWithValue(
          FakeMySectorsStore(
            valueOf(MySectors.none.remember(opened).open(opened.id)),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // An `autoDispose` provider lives only while someone listens to it:
    // the test listens as the screen would.
    container.listen(homeProvider, (_, _) {});
    return container;
  }

  setUp(() {
    streets = FakeStreetRepository([_nationale, _emile, _paix, _hugo]);
    shapes = FakeStreetShapes(Ok(_morinRoad));
    sectors = FakeSectorRepository([
      team(
        communes: [villefrancheCommune, gleizeCommune],
        members: [manu, lea, julie],
      ),
    ]);
  });

  group('panel', () {
    test('should list every street of the secteur with its progress, in '
        'French order', () async {
      final container = phone();
      await pumpEventQueue();

      final state = container.read(homeProvider);

      expect(state.loading, isFalse);
      expect(state.streets, [_emileRow, _paixRow, _nationaleRow, _hugoRow]);
      expect(state.hasNoStreet, isFalse);
    });

    test('should add up the doors of every street', () async {
      final container = phone();
      await pumpEventQueue();

      final state = container.read(homeProvider);

      expect(state.done, 3);
      expect(state.total, 10);
    });

    test('should count the refused doors as visited', () async {
      final (refusing, change) = valueOf(
        _nationale.markHouse(
          n('3'),
          VisitStatus.refused,
          by: _lea,
          at: createdAt,
        ),
      );
      await streets.save(refusing, change);
      final container = phone();
      await pumpEventQueue();

      final state = container.read(homeProvider);

      expect(state.done, 4);
      expect(state.total, 10);
    });

    test('should list every street for a visiting admin too', () async {
      final container = phone(open: sector12Visited);
      await pumpEventQueue();

      final state = container.read(homeProvider);

      expect(state.streets, [_emileRow, _paixRow, _nationaleRow, _hugoRow]);
      expect(state.done, 3);
      expect(state.total, 10);
    });

    test('should follow the streets as the team changes them', () async {
      final container = phone();
      await pumpEventQueue();

      final (marked, change) = valueOf(
        _hugo.markHouse(n('7'), VisitStatus.done, by: _lea, at: twoPm),
      );
      await streets.save(marked, change);
      await pumpEventQueue();

      final state = container.read(homeProvider);
      expect(
        state.streets.last,
        StreetRow(id: _hugo.id, name: 'Rue Victor Hugo', done: 1, total: 4),
      );
      expect(state.done, 4);
      expect(state.total, 10);
    });

    test('should leave out a street sent to the Corbeille', () async {
      final container = phone();
      await pumpEventQueue();

      final (deleted, change) = _paix.delete(by: _lea, at: twoPm);
      await streets.save(deleted, change);
      await pumpEventQueue();

      final state = container.read(homeProvider);
      expect(state.streets, [_emileRow, _nationaleRow, _hugoRow]);
      expect(state.done, 1);
      expect(state.total, 8);
    });

    test('should be loading, with nothing, before the streets are read', () {
      streets.watchError = StateError('not yet');
      final container = phone();

      final state = container.read(homeProvider);

      expect(state.loading, isTrue);
      expect(state.hasNoStreet, isFalse);
      expect(state.streets, isEmpty);
      expect(state.done, 0);
      expect(state.total, 0);
    });

    test('should show no street once the streets cannot be read', () async {
      streets.watchError = StateError('removed');
      final container = phone();
      await pumpEventQueue();

      final state = container.read(homeProvider);

      expect(state.loading, isFalse);
      expect(state.hasNoStreet, isTrue);
      expect(state.layers.lines, isEmpty);
    });

    test('should say the secteur has no street when it has none', () async {
      streets = FakeStreetRepository();
      final container = phone();
      await pumpEventQueue();

      final state = container.read(homeProvider);

      expect(state.hasNoStreet, isTrue);
      expect(state.done, 0);
      expect(state.total, 0);
    });
  });

  group('map', () {
    test('should draw every street of the secteur', () async {
      final container = phone();
      await pumpEventQueue();

      final layers = container.read(homeProvider).layers;

      expect(layers.lines, [
        StreetLine(
          street: StreetId('nationale'),
          shape: _nationaleShape,
          level: ProgressLevel.partial,
        ),
      ]);
      expect(layers.dots.single.street, StreetId('nationale'));
    });

    test(
      'should draw only the stretch held of a street held in part',
      () async {
        streets = FakeStreetRepository([_lilas]);
        final container = phone();
        await pumpEventQueue();

        final line = container.read(homeProvider).layers.lines.single;

        expect(line.shape, heldStretchOf(_lilas));
        expect(line.shape, isNot(_lilas.shape));
      },
    );

    test('should keep the layers when a street is tapped, the streets being '
        'the same', () async {
      final container = phone();
      await pumpEventQueue();
      final before = container.read(homeProvider).layers;

      container.read(homeProvider.notifier).select(StreetId('nationale'));

      expect(container.read(homeProvider).layers, same(before));
    });

    test(
      'should open on the streets when one has a place on the map',
      () async {
        final container = phone();
        await pumpEventQueue();

        expect(container.read(homeProvider).area, sectorArea([_nationale]));
      },
    );

    test('should open on the communes while no street has a place', () async {
      streets = FakeStreetRepository([_emile, _paix]);
      final container = phone();
      await pumpEventQueue();

      expect(
        container.read(homeProvider).area,
        communesArea([villefrancheCommune, gleizeCommune]),
      );
    });

    test('should not move the map when a street is added', () async {
      final container = phone();
      await pumpEventQueue();

      await streets.add(_morin);
      await pumpEventQueue();

      final state = container.read(homeProvider);
      expect(state.area, sectorArea([_nationale]));
      expect(state.layers.dots, hasLength(2));
    });

    test('should wait for the streets before choosing where to open', () async {
      final hold = streets.holdWatches = Completer();
      final container = phone();
      await pumpEventQueue();
      // The communes were read, not the streets: the map stays put.
      expect(container.read(homeProvider).area, isNull);

      hold.complete();
      await pumpEventQueue();

      expect(container.read(homeProvider).area, sectorArea([_nationale]));
    });

    test('should still show the streets when the secteur can no longer be '
        'read', () async {
      sectors.watchError = StateError('removed');
      final container = phone();
      await pumpEventQueue();

      final state = container.read(homeProvider);
      expect(state.streets, [_emileRow, _paixRow, _nationaleRow, _hugoRow]);
      expect(state.area, sectorArea([_nationale]));
    });

    test('should open on the communes read after the streets', () async {
      streets = FakeStreetRepository([_emile]);
      sectors.put(team());
      final container = phone();
      await pumpEventQueue();
      expect(container.read(homeProvider).area, isNull);

      sectors.put(team(communes: [gleizeCommune]));
      await pumpEventQueue();

      expect(container.read(homeProvider).area, communesArea([gleizeCommune]));
    });
  });

  group('lines on the map', () {
    test('should give a street without a line its road, in the '
        'background', () async {
      await streets.add(_morin);
      final container = phone();
      await pumpEventQueue();

      expect(shapes.askedNames, ['Rue Pierre Morin']);
      expect(streets[_morin.id]!.shape, _morinRoad);
      expect(
        container.read(homeProvider).layers.lines.map((line) => line.shape),
        containsAll([_nationaleShape, _morinRoad]),
      );
    });

    test('should ask nothing when every street has its line or no '
        'house on the map', () async {
      phone();
      await pumpEventQueue();

      expect(shapes.asked, isEmpty);
    });
  });

  group('street tapped on the map', () {
    test('should show the card of the street tapped', () async {
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).select(StreetId('hugo'));

      expect(
        container.read(homeProvider).card,
        StreetCardInSector(
          id: StreetId('hugo'),
          name: 'Rue Victor Hugo',
          commune: 'Villefranche-sur-Saône',
          done: 0,
          total: 4,
        ),
      );
    });

    test('should light up the line of the street tapped, and leave the '
        'map where it is', () async {
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).select(StreetId('nationale'));

      final state = container.read(homeProvider);
      expect(state.selectedRoad, _nationaleShape);
      expect(state.area, sectorArea([_nationale]));
    });

    test(
      'should light up only the stretch held of a street held in part',
      () async {
        streets = FakeStreetRepository([_lilas]);
        final container = phone();
        await pumpEventQueue();

        container.read(homeProvider.notifier).select(StreetId('lilas'));

        expect(
          container.read(homeProvider).selectedRoad,
          heldStretchOf(_lilas),
        );
      },
    );

    test('should light up no line before a street is tapped', () async {
      final container = phone();
      await pumpEventQueue();

      expect(container.read(homeProvider).selectedRoad, StreetShape.none);
    });

    test('should show nothing once the map is tapped elsewhere', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = container.read(homeProvider.notifier);
      notifier.select(StreetId('hugo'));

      notifier.unselect();

      expect(container.read(homeProvider).card, isNull);
    });

    test('should follow the progress of the street tapped', () async {
      final container = phone();
      await pumpEventQueue();
      container.read(homeProvider.notifier).select(StreetId('emile'));

      final (marked, change) = valueOf(
        _emile.markHouse(n('4'), VisitStatus.done, by: _lea, at: twoPm),
      );
      await streets.save(marked, change);
      await pumpEventQueue();

      final card = container.read(homeProvider).card!;
      expect(card.done, 1);
      expect(card.total, 1);
    });

    test('should show nothing when the street tapped is gone', () async {
      final container = phone();
      await pumpEventQueue();
      container.read(homeProvider.notifier).select(StreetId('hugo'));

      final (deleted, change) = _hugo.delete(by: _lea, at: twoPm);
      await streets.save(deleted, change);
      await pumpEventQueue();

      expect(container.read(homeProvider).card, isNull);
    });
  });

  test('should not follow any commune with no secteur open', () async {
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        sectorRepositoryProvider.overrideWithValue(sectors),
        streetShapesProvider.overrideWithValue(shapes),
        clockProvider.overrideWithValue(FakeClock(createdAt)),
        identityProvider.overrideWithValue(FakeIdentity(_lea)),
        mySectorsStoreProvider.overrideWithValue(FakeMySectorsStore()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(homeProvider, (_, _) {});
    await pumpEventQueue();

    expect(sectors.watched, isEmpty);
    expect(container.read(homeProvider).area, sectorArea([_nationale]));
  });

  test('should follow the communes of the secteur open', () async {
    phone();
    await pumpEventQueue();

    expect(sectors.watched, contains(sectorId));
  });
}
