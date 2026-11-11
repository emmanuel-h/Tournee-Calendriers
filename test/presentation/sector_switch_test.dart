// The screens built on the street storage follow a switch of secteur
// (PLAN §5.3: « map, panel and listeners follow it »): the composition root
// binds the storage to the open secteur, and nothing of the secteur left
// may show, or be undone, in the one opened.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_notifier.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/home/home_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

import '../application/use_cases/street_fixtures.dart';
import '../domain/sector/my_sectors_fixtures.dart';
import '../domain/sector/sector_fixtures.dart';
import '../support/fakes/fake_admin_status.dart';
import '../support/fakes/fake_my_sectors_store.dart';
import '../support/fakes/fake_open_round_store.dart';
import '../support/fakes/fake_ports.dart';
import '../support/fakes/fake_sector_repository.dart';
import '../support/fakes/fake_street_repository.dart';
import '../support/fakes/fake_street_shapes.dart';
import '../support/fakes/fake_street_view_preferences.dart';
import '../support/fakes/fake_unreadable_streets.dart';
import '../support/results.dart';
import '../support/street_fixtures.dart' show n, villefranche;
import '../support/streets_of_the_open_sector.dart';

void main() {
  /// Rue Gambetta, deleted by Léa.
  final gambetta = valueOf(
    Street.create(
      id: StreetId('gambetta'),
      name: 'Rue Gambetta',
      commune: villefranche,
    ),
  ).delete(by: leaId, at: DateTime.utc(2026, 11, 3, 18)).$1;

  late FakeStreetRepository none;
  late FakeStreetRepository streets49;
  late FakeStreetRepository streets12;
  late FakeMySectorsStore store;

  setUp(() {
    none = FakeStreetRepository();
    // The 49 holds the Rue des Lilas and Rue Gambetta in its Corbeille;
    // the 12 holds a Rue des Lilas of the same id, still untouched.
    streets49 = FakeStreetRepository([lilas, gambetta]);
    streets12 = FakeStreetRepository([lilas]);
    store = FakeMySectorsStore(
      valueOf(
        MySectors.none.remember(sector49).remember(sector12).open(sector49.id),
      ),
    );
  });

  ProviderContainer leasPhone() {
    final container = ProviderContainer(
      overrides: [
        streetsOfTheOpenSector(
          none: none,
          sectors: {sector49.id: streets49, sector12.id: streets12},
        ),
        mySectorsStoreProvider.overrideWithValue(store),
        sectorRepositoryProvider.overrideWithValue(
          FakeSectorRepository([team()]),
        ),
        streetViewPreferencesProvider.overrideWithValue(
          FakeStreetViewPreferences(),
        ),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 4))),
        identityProvider.overrideWithValue(FakeIdentity(leaId)),
        openRoundStoreProvider.overrideWithValue(FakeOpenRoundStore()),
        adminStatusProvider.overrideWithValue(FakeAdminStatus()),
        streetShapesProvider.overrideWithValue(FakeStreetShapes()),
        unreadableStreetsProvider.overrideWithValue(FakeUnreadableStreets()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> openThe12() =>
      store.save(valueOf(store.mySectors.open(sector12.id)));

  group('Accueil', () {
    test('should show no street of the secteur left', () async {
      streets12 = FakeStreetRepository();
      final container = leasPhone();
      container.listen(homeProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(homeProvider).streets, hasLength(1));

      await openThe12();

      // Nothing until the 12's streets are read, then those.
      expect(container.read(homeProvider).loading, isTrue);
      expect(container.read(homeProvider).streets, isEmpty);
      await pumpEventQueue();
      expect(container.read(homeProvider).loading, isFalse);
      expect(container.read(homeProvider).hasNoStreet, isTrue);
    });

    test('should show no street when they cannot be read', () async {
      streets49.watchError = StateError('permission-denied');
      final container = leasPhone();
      container.listen(homeProvider, (_, _) {});
      await pumpEventQueue();

      final state = container.read(homeProvider);
      expect(state.loading, isFalse);
      expect(state.hasNoStreet, isTrue);
    });
  });

  group('the street screen', () {
    test('should not undo in the secteur opened a change made in the one '
        'left', () async {
      final container = leasPhone();
      container.listen(streetProvider(lilasId), (_, _) {});
      await pumpEventQueue();
      final house = (street: lilasId, number: n('7'));
      container.listen(houseSheetProvider(house), (_, _) {});
      await pumpEventQueue();
      final stored = await container
          .read(houseSheetProvider(house).notifier)
          .setStatus(VisitStatus.done);
      container
          .read(streetProvider(lilasId).notifier)
          .keepForUndo(stored!.change);
      expect(streets49.saved, hasLength(1));

      await openThe12();
      await pumpEventQueue();
      await container.read(streetProvider(lilasId).notifier).undo();

      expect(streets12.saved, isEmpty);
      expect(streets49.saved, hasLength(1));
      // The street of the 12 shows, house 7 still to do.
      final shown = container.read(streetProvider(lilasId)) as StreetShown;
      expect(
        shown.odd.singleWhere((tile) => tile.number == n('7')).mark,
        isA<ToDoMark>(),
      );
    });

    test('should show the street as gone when it cannot be read', () async {
      streets49.watchError = StateError('permission-denied');
      final container = leasPhone();
      container.listen(streetProvider(lilasId), (_, _) {});
      await pumpEventQueue();

      expect(container.read(streetProvider(lilasId)), const StreetGone());
    });
  });

  group('the Corbeille', () {
    test('should show nothing of the secteur left', () async {
      final container = leasPhone();
      container.listen(corbeilleProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(corbeilleProvider).count, 1);

      await openThe12();

      // Waiting for the 12's streets, not the 49's Corbeille.
      expect(container.read(corbeilleProvider), CorbeilleState.waiting);
      await pumpEventQueue();
      expect(container.read(corbeilleProvider).loading, isFalse);
      expect(container.read(corbeilleProvider).count, 0);
    });
  });
}
