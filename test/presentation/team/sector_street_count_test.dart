import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/team/sector_street_count.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show villefranche;

/// A street of the secteur by the name [name].
Street street(String id, String name) =>
    valueOf(Street.create(id: StreetId(id), name: name, commune: villefranche));

void main() {
  late FakeStreetRepository streets;

  ProviderContainer phone(FakeStreetRepository stored) {
    streets = stored;
    final container = ProviderContainer(
      overrides: [streetRepositoryProvider.overrideWithValue(streets)],
    );
    addTearDown(container.dispose);
    // `listen` keeps the auto-disposed provider alive, as a screen does.
    container.listen(sectorStreetCountProvider, (_, _) {});
    return container;
  }

  test('should know no count until the streets are read', () {
    final container = phone(FakeStreetRepository([lilas]));

    expect(container.read(sectorStreetCountProvider).value, isNull);
  });

  test(
    'should count the streets of the secteur outside the Corbeille',
    () async {
      final container = phone(
        FakeStreetRepository([
          lilas,
          street('gambetta', 'Rue Gambetta'),
          street(
            'thizy',
            'Rue de Thizy',
          ).delete(by: leaId, at: DateTime(2026, 11, 3, 18)).$1,
        ]),
      );
      await pumpEventQueue();

      expect(container.read(sectorStreetCountProvider).value, 2);
    },
  );

  test('should follow a street added', () async {
    final container = phone(FakeStreetRepository([lilas]));
    await pumpEventQueue();

    await streets.add(street('gambetta', 'Rue Gambetta'));
    await pumpEventQueue();

    expect(container.read(sectorStreetCountProvider).value, 2);
  });
}
