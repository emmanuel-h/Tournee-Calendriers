// The 30-day purge runs by itself on the streets bound: at start, and again
// for each tournée opened (PLAN §5.11: the first member's app online purges).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_purge.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../../support/streets_of_the_open_sector.dart';

final _now = DateTime.utc(2026, 11, 20, 8);

/// A street [id] deleted by Léa [days] days before [_now].
Street _deleted(String id, int days) =>
    valueOf(
          Street.create(
            id: StreetId(id),
            name: 'Rue $id',
            commune: villefranche,
          ),
        )
        .delete(
          by: lea,
          at: _now.subtract(Duration(days: days)),
        )
        .$1;

void main() {
  late FakeStreetRepository phone;
  late FakeStreetRepository streets49;
  late FakeStreetRepository streets12;
  late FakeMySectorsStore store;

  setUp(() {
    phone = FakeStreetRepository([_deleted('Thiers', 31)]);
    streets49 = FakeStreetRepository([
      _deleted('Gambetta', 31),
      _deleted('Pasteur', 30),
    ]);
    streets12 = FakeStreetRepository([_deleted('Lilas', 40)]);
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
          phone: phone,
          sectors: {sector49.id: streets49, sector12.id: streets12},
        ),
        mySectorsStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(FakeClock(_now)),
        // « Mes secteurs » follows the teams of the tournées not open.
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('should purge the Corbeille of the open tournée', () async {
    final container = leasPhone();

    final purged = await container.read(corbeillePurgeProvider.future);

    expect(purged, (streets: 1, numbers: 0));
    expect(streets49.purged, [StreetId('Gambetta')]);
    expect(await streets49.find(StreetId('Pasteur')), isNotNull);
    expect(phone.purged, isEmpty);
    expect(streets12.purged, isEmpty);
  });

  test('should purge the Corbeille of each tournée opened', () async {
    final container = leasPhone();
    container.listen(corbeillePurgeProvider, (_, _) {});
    await container.read(corbeillePurgeProvider.future);

    await store.save(valueOf(store.mySectors.open(sector12.id)));
    await container.read(corbeillePurgeProvider.future);

    expect(streets12.purged, [StreetId('Lilas')]);
    expect(streets49.purged, [StreetId('Gambetta')]);
  });

  test(
    "should purge the phone's own streets while no tournée is open",
    () async {
      store = FakeMySectorsStore();
      final container = leasPhone();

      await container.read(corbeillePurgeProvider.future);

      expect(phone.purged, [StreetId('Thiers')]);
    },
  );

  test(
    'should settle on the failure when the streets cannot be read',
    () async {
      streets49.watchError = StateError('no access');
      final container = leasPhone();

      await expectLater(
        container.read(corbeillePurgeProvider.future),
        throwsStateError,
      );
      expect(container.read(corbeillePurgeProvider).hasError, isTrue);
    },
  );
}
