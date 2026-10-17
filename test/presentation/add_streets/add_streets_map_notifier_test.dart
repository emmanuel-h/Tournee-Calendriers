import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// Rue Pierre Morin, with one house placed on the map.
final _morin = valueOf(
  Street.create(
    id: StreetId('morin'),
    name: 'Rue Pierre Morin',
    commune: villefranche,
    houses: [House(number: n('1'), position: townHallDoor)],
  ),
);

void main() {
  late FakeStreetRepository streets;
  late FakeTourneeRepository tournees;

  /// The phone with the 49 open, or none when [open] is false.
  ProviderContainer phone({bool open = true}) {
    final container = ProviderContainer(
      overrides: [
        streetRepositoryProvider.overrideWithValue(streets),
        tourneeRepositoryProvider.overrideWithValue(tournees),
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
    container.listen(addStreetsMapProvider, (_, _) {});
    return container;
  }

  setUp(() {
    streets = FakeStreetRepository([_morin]);
    tournees = FakeTourneeRepository([
      team(communes: [villefrancheCommune, gleizeCommune]),
    ]);
  });

  test('should draw the streets and open on the communes', () async {
    final container = phone();
    await pumpEventQueue();

    final state = container.read(addStreetsMapProvider);

    expect(state.layers.dots.single.street, StreetId('morin'));
    expect(state.area, communesArea([villefrancheCommune, gleizeCommune]));
  });

  test('should open on the streets for a tournée without commune', () async {
    tournees.put(team());
    final container = phone();
    await pumpEventQueue();

    expect(container.read(addStreetsMapProvider).area, tourneeArea([_morin]));
  });

  test('should follow the communes as they change', () async {
    final container = phone();
    await pumpEventQueue();

    tournees.put(team(communes: [gleizeCommune]));
    await pumpEventQueue();

    expect(
      container.read(addStreetsMapProvider).area,
      communesArea([gleizeCommune]),
    );
  });

  test('should open on the streets with no tournée open', () async {
    final container = phone(open: false);
    await pumpEventQueue();

    expect(container.read(addStreetsMapProvider).area, tourneeArea([_morin]));
    expect(tournees.watched, isEmpty);
  });

  test('should draw nothing and show France before anything is read', () {
    streets.watchError = StateError('not yet');
    tournees.put(team());
    final container = phone();

    final state = container.read(addStreetsMapProvider);

    expect(state.layers.lines, isEmpty);
    expect(state.layers.dots, isEmpty);
    expect(state.area, isNull);
  });

  test('should draw no street once the streets cannot be read', () async {
    streets.watchError = StateError('removed');
    tournees.put(team());
    final container = phone();
    await pumpEventQueue();

    final state = container.read(addStreetsMapProvider);

    expect(state.layers.dots, isEmpty);
    expect(state.area, isNull);
  });
}
