import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/home/home_notifier.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_state.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart'
    show
        createdAt,
        gleizeCommune,
        julie,
        lea,
        manu,
        manuId,
        nameOf,
        team,
        tourneeId,
        villefrancheCommune;
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' hide lea;

final _lea = MemberId('lea');
final _paul = MemberId('paul');

/// Paul in the team, so the cards name him.
final _paulMember = Member(
  id: _paul,
  name: nameOf('Paul'),
  requestedAt: createdAt,
  acceptance: ChangeStamp(by: manuId, at: createdAt),
);

final _nationaleShape = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);

/// Rue Nationale: Léa's, on the map, 1 of 3 doors done.
final _nationale = valueOf(
  Street.create(
    id: StreetId('nationale'),
    name: 'Rue Nationale',
    commune: villefranche,
    shape: _nationaleShape,
    assignees: {_lea},
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

/// Allée Émile Zola: Léa's and Paul's, typed in by hand, 0 of 1.
final _emile = valueOf(
  Street.create(
    id: StreetId('emile'),
    name: 'Allée Émile Zola',
    commune: villefranche,
    assignees: {_lea, _paul},
    houses: [House(number: n('4'))],
  ),
);

/// Rue de la Paix: nobody's, 2 of 2 done.
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

/// Rue Victor Hugo: Paul's, 0 of 4.
final _hugo = valueOf(
  Street.create(
    id: StreetId('hugo'),
    name: 'Rue Victor Hugo',
    commune: villefranche,
    assignees: {_paul},
    houses: [
      for (final number in ['7', '8', '9', '10']) House(number: n(number)),
    ],
  ),
);

/// Rue Pierre Morin: nobody's, a single house on the map, far north.
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
  late FakeTourneeRepository tournees;
  late FakeStreetShapes shapes;

  /// Léa's phone with [open] open (the 49 by default), or none.
  ProviderContainer phone({TourneeSummary? open}) {
    final opened = open ?? tournee49;
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        tourneeRepositoryProvider.overrideWithValue(tournees),
        streetShapesProvider.overrideWithValue(shapes),
        clockProvider.overrideWithValue(FakeClock(createdAt)),
        identityProvider.overrideWithValue(FakeIdentity(_lea)),
        myTourneesStoreProvider.overrideWithValue(
          FakeMyTourneesStore(
            valueOf(MyTournees.none.remember(opened).open(opened.id)),
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
    tournees = FakeTourneeRepository([
      team(
        communes: [villefrancheCommune, gleizeCommune],
        members: [manu, lea, julie, _paulMember],
      ),
    ]);
  });

  group('panel', () {
    test(
      'should list « Mes rues » with their progress, in French order',
      () async {
        final container = phone();
        await pumpEventQueue();

        final state = container.read(homeProvider);

        expect(state.loading, isFalse);
        expect(state.visiting, isFalse);
        expect(state.mine, [_emileRow, _nationaleRow]);
      },
    );

    test('should list the other streets of the tournée, free or someone '
        'else\'s, in French order', () async {
      final container = phone();
      await pumpEventQueue();

      expect(container.read(homeProvider).others, [_paixRow, _hugoRow]);
    });

    test('should add up the doors of « Mes rues » and the team\'s share '
        'done', () async {
      final container = phone();
      await pumpEventQueue();

      final state = container.read(homeProvider);

      expect(state.done, 1);
      expect(state.total, 4);
      // 3 of the tournée's 10 doors.
      expect(state.teamPercent, 30);
      expect(state.hasNoStreet, isFalse);
    });

    test(
      'should list every street under « Rues » for a visiting admin',
      () async {
        final container = phone(open: tournee12Visited);
        await pumpEventQueue();

        final state = container.read(homeProvider);

        expect(state.visiting, isTrue);
        expect(state.mine, [_emileRow, _paixRow, _nationaleRow, _hugoRow]);
        expect(state.others, isEmpty);
        expect(state.done, 3);
        expect(state.total, 10);
        expect(state.teamPercent, 30);
      },
    );

    test('should follow the streets as the team changes them', () async {
      final container = phone();
      await pumpEventQueue();

      final (taken, change) = valueOf(_paix.take(_lea));
      await streets.save(taken, change);
      await pumpEventQueue();

      final state = container.read(homeProvider);
      expect(state.mine, [_emileRow, _paixRow, _nationaleRow]);
      expect(state.others, [_hugoRow]);
      expect(state.done, 3);
      expect(state.total, 6);
    });

    test('should be loading, with nothing, before the streets are read', () {
      streets.watchError = StateError('not yet');
      final container = phone();

      final state = container.read(homeProvider);

      expect(state.loading, isTrue);
      expect(state.hasNoStreet, isFalse);
      expect(state.mine, isEmpty);
      expect(state.others, isEmpty);
      expect(state.teamPercent, 0);
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

    test('should say the tournée has no street when it has none', () async {
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
    test('should draw every street of the tournée', () async {
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
      'should open on the streets when one has a place on the map',
      () async {
        final container = phone();
        await pumpEventQueue();

        expect(container.read(homeProvider).area, tourneeArea([_nationale]));
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
      expect(state.area, tourneeArea([_nationale]));
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

      expect(container.read(homeProvider).area, tourneeArea([_nationale]));
    });

    test('should open on the communes read after the streets', () async {
      streets = FakeStreetRepository([_emile]);
      tournees.put(team());
      final container = phone();
      await pumpEventQueue();
      expect(container.read(homeProvider).area, isNull);

      tournees.put(team(communes: [gleizeCommune]));
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
        StreetCardInTournee(
          id: StreetId('hugo'),
          name: 'Rue Victor Hugo',
          commune: 'Villefranche-sur-Saône',
          done: 0,
          total: 4,
          coverage: StreetCoverage.others,
          coveredBy: const ['Paul'],
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
      expect(state.area, tourneeArea([_nationale]));
    });

    test('should light up no line before a street is tapped', () async {
      final container = phone();
      await pumpEventQueue();

      expect(container.read(homeProvider).selectedRoad, StreetShape.none);
    });

    test('should show a street of the member\'s as theirs, naming who '
        'covers it too', () async {
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).select(StreetId('emile'));

      final card = container.read(homeProvider).card!;
      expect(card.coverage, StreetCoverage.mine);
      expect(card.coveredBy, ['Paul']);
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

    test('should give the street tapped to the member with « La faire '
        'aussi »', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = container.read(homeProvider.notifier);
      notifier.select(StreetId('hugo'));

      await notifier.take();
      await pumpEventQueue();

      expect(streets[StreetId('hugo')]!.assignees, {_paul, _lea});
      final card = container.read(homeProvider).card!;
      expect(card.coverage, StreetCoverage.mine);
      expect(card.coveredBy, ['Paul']);
    });

    test('should take the member off the street tapped with « Ne plus la '
        'faire »', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = container.read(homeProvider.notifier);
      notifier.select(StreetId('nationale'));

      await notifier.release();
      await pumpEventQueue();

      expect(streets[StreetId('nationale')]!.assignees, isEmpty);
      expect(container.read(homeProvider).card!.coverage, StreetCoverage.free);
    });

    test('should name nobody on the card when the team cannot be '
        'read', () async {
      tournees.watchError = StateError('removed');
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).select(StreetId('hugo'));

      final card = container.read(homeProvider).card!;
      expect(card.coverage, StreetCoverage.others);
      expect(card.coveredBy, isEmpty);
    });

    test('should take or release nothing while no street is tapped', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = container.read(homeProvider.notifier);

      await notifier.take();
      await notifier.release();

      expect(streets.saved, isEmpty);
    });
  });

  group('street tapped among « Autres rues de la tournée »', () {
    test('should show its card, as a tap on its line does', () async {
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).focus(StreetId('paix'));

      expect(
        container.read(homeProvider).card,
        StreetCardInTournee(
          id: StreetId('paix'),
          name: 'Rue de la Paix',
          commune: 'Villefranche-sur-Saône',
          done: 2,
          total: 2,
          coverage: StreetCoverage.free,
          coveredBy: const [],
        ),
      );
    });

    test('should move the map to its line and light it up', () async {
      final (free, change) = valueOf(_nationale.release(_lea));
      await streets.save(free, change);
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).focus(StreetId('nationale'));

      final state = container.read(homeProvider);
      expect(state.area, streetArea(free));
      expect(state.area, isNot(tourneeArea([free])));
      expect(state.selectedRoad, _nationaleShape);
    });

    test('should move the map to its houses when it has no line', () async {
      // The map knows no road of its name: it keeps no line.
      shapes = FakeStreetShapes();
      await streets.add(_morin);
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).focus(StreetId('morin'));

      final state = container.read(homeProvider);
      expect(state.area, streetArea(_morin));
      expect(state.area, isNotNull);
      expect(state.selectedRoad, StreetShape.none);
      expect(state.card!.name, 'Rue Pierre Morin');
    });

    test('should leave the map where it is when the street has no place '
        'on it', () async {
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).focus(StreetId('hugo'));

      final state = container.read(homeProvider);
      expect(state.area, tourneeArea([_nationale]));
      expect(state.card!.name, 'Rue Victor Hugo');
    });

    test('should keep the map on the street once its card is '
        'closed', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = container.read(homeProvider.notifier);
      notifier.focus(StreetId('nationale'));

      notifier.unselect();

      final state = container.read(homeProvider);
      expect(state.card, isNull);
      expect(state.selectedRoad, StreetShape.none);
      expect(state.area, streetArea(_nationale));
    });

    test('should give it to the member with « Me l\'attribuer »', () async {
      final container = phone();
      await pumpEventQueue();
      final notifier = container.read(homeProvider.notifier);
      notifier.focus(StreetId('paix'));

      await notifier.take();
      await pumpEventQueue();

      expect(streets[StreetId('paix')]!.assignees, {_lea});
      expect(container.read(homeProvider).card!.coverage, StreetCoverage.mine);
    });

    test('should change nothing when the street is gone', () async {
      final container = phone();
      await pumpEventQueue();

      container.read(homeProvider.notifier).focus(StreetId('gone'));

      final state = container.read(homeProvider);
      expect(state.card, isNull);
      expect(state.area, tourneeArea([_nationale]));
    });
  });

  test('should not follow any commune with no tournée open', () async {
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        tourneeRepositoryProvider.overrideWithValue(tournees),
        streetShapesProvider.overrideWithValue(shapes),
        clockProvider.overrideWithValue(FakeClock(createdAt)),
        identityProvider.overrideWithValue(FakeIdentity(_lea)),
        myTourneesStoreProvider.overrideWithValue(FakeMyTourneesStore()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(homeProvider, (_, _) {});
    await pumpEventQueue();

    expect(tournees.watched, isEmpty);
    expect(container.read(homeProvider).area, tourneeArea([_nationale]));
  });

  test('should follow the communes of the tournée open', () async {
    phone();
    await pumpEventQueue();

    expect(tournees.watched, contains(tourneeId));
  });
}
