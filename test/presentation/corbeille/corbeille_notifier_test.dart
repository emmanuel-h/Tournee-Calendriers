import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/corbeille.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_notifier.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/shared/recent_time.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show n, streetName, villefranche;

/// Wednesday 4 November 2026, 10:00 on the phone's clock.
final now = DateTime(2026, 11, 4, 10);

/// The Rue des Lilas with its number 7 removed by Léa ten minutes ago.
Street lilasWithoutSeven() => valueOf(
  lilas.removeNumber(
    n('7'),
    by: leaId,
    at: now.subtract(const Duration(minutes: 10)),
  ),
).$1;

/// Rue Gambetta (one number), deleted by [by] yesterday.
Street gambettaDeleted({MemberId? by}) => valueOf(
  Street.create(
    id: StreetId('gambetta'),
    name: 'Rue Gambetta',
    commune: villefranche,
    houses: [lilas.houses.first],
  ),
).delete(by: by ?? paulId, at: DateTime(2026, 11, 3, 18)).$1;

void main() {
  late FakeStreetRepository streets;

  /// Manu's phone; the 49 is open unless [noTournee].
  ProviderContainer phone(Iterable<Street> stored, {bool noTournee = false}) {
    streets = FakeStreetRepository(stored);
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        tourneeRepositoryProvider.overrideWithValue(
          // Manu, Léa and Julie: Paul is no longer in the team.
          FakeTourneeRepository([team()]),
        ),
        myTourneesStoreProvider.overrideWithValue(
          FakeMyTourneesStore(
            noTournee
                ? MyTournees.none
                : valueOf(
                    MyTournees.none.remember(tournee49).open(tournee49.id),
                  ),
          ),
        ),
        identityProvider.overrideWithValue(FakeIdentity(manuId)),
        clockProvider.overrideWithValue(FakeClock(now)),
      ],
    );
    addTearDown(container.dispose);
    // `listen` keeps the auto-disposed providers alive, as a screen does.
    container.listen(corbeilleProvider, (_, _) {});
    return container;
  }

  test('should be loading until the streets are read', () {
    final container = phone([lilas]);

    final state = container.read(corbeilleProvider);

    expect(state.loading, isTrue);
    expect(state.rows, isEmpty);
    expect(state.count, 0);
  });

  test('should list the deleted streets and removed numbers with who did it '
      'and when, the latest first', () async {
    final container = phone([lilasWithoutSeven(), gambettaDeleted(by: leaId)]);
    await pumpEventQueue();

    final state = container.read(corbeilleProvider);

    expect(state.loading, isFalse);
    expect(state.count, 2);
    expect(state.rows, [
      CorbeilleRow(
        item: RemovedNumber(
          streetId: lilasId,
          streetName: streetName('Rue des Lilas'),
          removal: ChangeStamp(
            by: leaId,
            at: now.subtract(const Duration(minutes: 10)),
          ),
          number: n('7'),
        ),
        removedBy: 'Léa',
        removedAt: const MinutesAgo(10),
      ),
      CorbeilleRow(
        item: DeletedStreet(
          streetId: StreetId('gambetta'),
          streetName: streetName('Rue Gambetta'),
          removal: ChangeStamp(by: leaId, at: DateTime(2026, 11, 3, 18)),
          numberCount: 1,
        ),
        removedBy: 'Léa',
        removedAt: const Yesterday(),
      ),
    ]);
  });

  test('should name nobody for a member no longer in the team', () async {
    final container = phone([gambettaDeleted(by: paulId)]);
    await pumpEventQueue();

    expect(container.read(corbeilleProvider).rows.single.removedBy, isNull);
  });

  test('should name nobody when no tournée is open', () async {
    final container = phone([gambettaDeleted(by: leaId)], noTournee: true);
    await pumpEventQueue();

    expect(container.read(corbeilleProvider).rows.single.removedBy, isNull);
  });

  test('should bring a deleted street back', () async {
    final container = phone([gambettaDeleted()]);
    await pumpEventQueue();
    final row = container.read(corbeilleProvider).rows.single;

    await container.read(corbeilleProvider.notifier).restore(row);
    await pumpEventQueue();

    expect(
      streets.saved.single.$2,
      StreetRestored(streetId: StreetId('gambetta')),
    );
    expect(container.read(corbeilleProvider).rows, isEmpty);
  });

  test('should bring a removed number back with its marks', () async {
    final container = phone([lilasWithoutSeven()]);
    await pumpEventQueue();
    final row = container.read(corbeilleProvider).rows.single;

    await container.read(corbeilleProvider.notifier).restore(row);
    await pumpEventQueue();

    final (_, change) = streets.saved.single;
    expect((change as NumberRestored).removed.number, n('7'));
    expect(streets[lilasId]!.houseAt(n('7')), lilas.houseAt(n('7')));
    expect(container.read(corbeilleProvider).rows, isEmpty);
  });

  test('should compare rows by value', () {
    CorbeilleRow row({String? by = 'Léa', RecentTime? at, int count = 1}) =>
        CorbeilleRow(
          item: DeletedStreet(
            streetId: StreetId('gambetta'),
            streetName: streetName('Rue Gambetta'),
            removal: ChangeStamp(by: leaId, at: now),
            numberCount: count,
          ),
          removedBy: by,
          removedAt: at ?? const JustNow(),
        );

    expect(row(), row());
    expect(row().hashCode, row().hashCode);
    expect(row(count: 2), isNot(row()));
    expect(row(by: null), isNot(row()));
    expect(row(at: const Yesterday()), isNot(row()));
  });

  test('should compare states by value', () {
    CorbeilleState state({bool loading = false, String? by = 'Léa'}) =>
        CorbeilleState(
          loading: loading,
          rows: [
            CorbeilleRow(
              item: RemovedNumber(
                streetId: lilasId,
                streetName: streetName('Rue des Lilas'),
                removal: ChangeStamp(by: leaId, at: now),
                number: n('7'),
              ),
              removedBy: by,
              removedAt: const JustNow(),
            ),
          ],
        );

    expect(state(), state());
    expect(state().hashCode, state().hashCode);
    expect(state(loading: true), isNot(state()));
    expect(state(by: 'Paul'), isNot(state()));
    expect(CorbeilleState.waiting.loading, isTrue);
    expect(CorbeilleState.waiting.rows, isEmpty);
  });
}
