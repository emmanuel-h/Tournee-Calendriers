// The screens built on the street storage follow a switch of tournée
// (PLAN §5.3: « map, panel and listeners follow it »): the composition root
// binds the storage to the open tournée, and nothing of the tournée left
// may show, or be undone, in the one opened.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_notifier.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/street/street_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_notifier.dart';

import '../application/use_cases/street_fixtures.dart';
import '../domain/tournee/my_tournees_fixtures.dart';
import '../domain/tournee/tournee_fixtures.dart';
import '../support/fakes/fake_my_tournees_store.dart';
import '../support/fakes/fake_ports.dart';
import '../support/fakes/fake_street_repository.dart';
import '../support/fakes/fake_street_view_preferences.dart';
import '../support/fakes/fake_tournee_repository.dart';
import '../support/results.dart';
import '../support/street_fixtures.dart' show n, villefranche;
import '../support/streets_of_the_open_tournee.dart';

void main() {
  /// Rue Gambetta, deleted by Léa.
  final gambetta = valueOf(
    Street.create(
      id: StreetId('gambetta'),
      name: 'Rue Gambetta',
      commune: villefranche,
    ),
  ).delete(by: leaId, at: DateTime.utc(2026, 11, 3, 18)).$1;

  late FakeStreetRepository phone;
  late FakeStreetRepository streets49;
  late FakeStreetRepository streets12;
  late FakeMyTourneesStore store;

  setUp(() {
    phone = FakeStreetRepository();
    // The 49 holds the Rue des Lilas and Rue Gambetta in its Corbeille;
    // the 12 holds a Rue des Lilas of the same id (moved from the same
    // phone), still untouched.
    streets49 = FakeStreetRepository([lilas, gambetta]);
    streets12 = FakeStreetRepository([lilas]);
    store = FakeMyTourneesStore(
      valueOf(
        MyTournees.none
            .remember(tournee49)
            .remember(tournee12)
            .open(tournee49.id),
      ),
    );
  });

  ProviderContainer leasPhone() {
    final container = ProviderContainer(
      overrides: [
        streetsOfTheOpenTournee(
          phone: phone,
          tournees: {tournee49.id: streets49, tournee12.id: streets12},
        ),
        myTourneesStoreProvider.overrideWithValue(store),
        tourneeRepositoryProvider.overrideWithValue(
          FakeTourneeRepository([team()]),
        ),
        streetViewPreferencesProvider.overrideWithValue(
          FakeStreetViewPreferences(),
        ),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 4))),
        identityProvider.overrideWithValue(FakeIdentity(leaId)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> openThe12() =>
      store.save(valueOf(store.myTournees.open(tournee12.id)));

  group('Mes rues', () {
    test('should show no street of the tournée left', () async {
      streets12 = FakeStreetRepository();
      final container = leasPhone();
      container.listen(streetListProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(streetListProvider).streetCount, 1);

      await openThe12();

      // Nothing until the 12's streets are read, then those.
      expect(container.read(streetListProvider).loading, isTrue);
      expect(container.read(streetListProvider).rows, isEmpty);
      await pumpEventQueue();
      expect(container.read(streetListProvider).loading, isFalse);
      expect(container.read(streetListProvider).streetCount, 0);
    });

    test('should show no street when they cannot be read', () async {
      streets49.watchError = StateError('permission-denied');
      final container = leasPhone();
      container.listen(streetListProvider, (_, _) {});
      await pumpEventQueue();

      final state = container.read(streetListProvider);
      expect(state.loading, isFalse);
      expect(state.isEmpty, isTrue);
    });
  });

  group('the street screen', () {
    test('should not undo in the tournée opened a change made in the one '
        'left', () async {
      final container = leasPhone();
      container.listen(streetProvider(lilasId), (_, _) {});
      await pumpEventQueue();
      await container.read(streetProvider(lilasId).notifier).cycle(n('7'));
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
    test('should show nothing of the tournée left', () async {
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
