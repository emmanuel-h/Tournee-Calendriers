import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/choose_start_point.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/launch/launch_place.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';

void main() {
  /// Where a phone holding [mine] and the phone [streets] opens.
  Future<LaunchPlace> launchOf(
    MyTournees mine, [
    FakeStreetRepository? streets,
  ]) {
    final container = ProviderContainer(
      overrides: [
        myTourneesStoreProvider.overrideWithValue(FakeMyTourneesStore(mine)),
        phoneStreetRepositoryProvider.overrideWithValue(
          streets ?? FakeStreetRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(launchPlaceProvider.future);
  }

  test('should open « Bienvenue » on a phone holding nothing', () async {
    expect(await launchOf(MyTournees.none), const LaunchOnWelcome());
  });

  test('should open the streets on a phone holding streets', () async {
    expect(
      await launchOf(MyTournees.none, FakeStreetRepository([lilas])),
      const LaunchOnStreets(),
    );
  });

  test('should open the request waiting on a phone holding only it', () async {
    expect(
      await launchOf(MyTournees.none.remember(tournee7)),
      LaunchOnRequest(tournee7.id),
    );
  });

  group('launchPlaceOf', () {
    test('should show each start point on its screen', () {
      expect(launchPlaceOf(const StartOnStreets()), const LaunchOnStreets());
      expect(launchPlaceOf(const StartOnWelcome()), const LaunchOnWelcome());
      expect(
        launchPlaceOf(StartOnRequest(tournee7)),
        LaunchOnRequest(TourneeId('t7')),
      );
    });
  });

  test('should tell requests apart by their tournée', () {
    expect(LaunchOnRequest(TourneeId('t7')), LaunchOnRequest(TourneeId('t7')));
    expect(
      LaunchOnRequest(TourneeId('t7')),
      isNot(LaunchOnRequest(TourneeId('t8'))),
    );
    expect(
      LaunchOnRequest(TourneeId('t7')).hashCode,
      LaunchOnRequest(TourneeId('t7')).hashCode,
    );
    expect(LaunchOnRequest(TourneeId('t7')).toString(), 'LaunchOnRequest(t7)');
  });
}
