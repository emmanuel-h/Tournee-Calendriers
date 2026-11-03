import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/choose_start_point.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';

void main() {
  /// Where a phone holding [mine] opens.
  Future<LaunchPlace> launchOf(MySectors mine) {
    final container = ProviderContainer(
      overrides: [
        mySectorsStoreProvider.overrideWithValue(FakeMySectorsStore(mine)),
      ],
    );
    addTearDown(container.dispose);
    return container.read(launchPlaceProvider.future);
  }

  test('should open « Bienvenue » on a phone holding nothing', () async {
    expect(await launchOf(MySectors.none), const LaunchOnWelcome());
  });

  test('should open the start screen on a phone knowing a secteur', () async {
    expect(
      await launchOf(MySectors.none.remember(sector12)),
      const LaunchOnStreets(),
    );
  });

  test('should open the request waiting on a phone holding only it', () async {
    expect(
      await launchOf(MySectors.none.remember(sector7)),
      LaunchOnRequest(sector7.id),
    );
  });

  group('launchPlaceOf', () {
    test('should show each start point on its screen', () {
      expect(launchPlaceOf(const StartOnStreets()), const LaunchOnStreets());
      expect(launchPlaceOf(const StartOnWelcome()), const LaunchOnWelcome());
      expect(
        launchPlaceOf(StartOnRequest(sector7)),
        LaunchOnRequest(SectorId('t7')),
      );
    });
  });

  test('should tell requests apart by their tournée', () {
    expect(LaunchOnRequest(SectorId('t7')), LaunchOnRequest(SectorId('t7')));
    expect(
      LaunchOnRequest(SectorId('t7')),
      isNot(LaunchOnRequest(SectorId('t8'))),
    );
    expect(
      LaunchOnRequest(SectorId('t7')).hashCode,
      LaunchOnRequest(SectorId('t7')).hashCode,
    );
    expect(LaunchOnRequest(SectorId('t7')).toString(), 'LaunchOnRequest(t7)');
  });
}
