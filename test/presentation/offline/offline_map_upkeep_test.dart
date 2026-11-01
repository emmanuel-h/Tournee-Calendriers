// Keeping the downloaded maps usable offline, unseen (PLAN §7): the silent
// refresh, at most twice a day, and the downloads of forgotten tournées
// deleted.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/use_cases/refresh_offline_maps.dart';
import 'package:tournee_calendriers/application/use_cases/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/offline/offline_map_upkeep.dart';

import '../../application/use_cases/offline_fixtures.dart';
import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_offline_map_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_tournee_downloads.dart';

void main() {
  late FakeOfflineMapStore maps;
  late FakeTourneeDownloads downloads;
  late FakeMyTourneesStore myTournees;
  late FakeClock clock;
  late OfflineMapUpkeep upkeep;

  setUp(() {
    maps = FakeOfflineMapStore([regionOf(40, t49, area49)]);
    downloads = FakeTourneeDownloads([downloadOf(t49, area49)]);
    myTournees = FakeMyTourneesStore(MyTournees.none.remember(tournee49));
    clock = FakeClock(morning);
    upkeep = OfflineMapUpkeep(
      RefreshOfflineMaps(maps, downloads),
      PruneTourneeDownloads(
        myTournees,
        DeleteTourneeDownload(maps, downloads),
        maps,
        downloads,
      ),
      clock,
    );
  });

  test('should refresh at most every 12 hours', () {
    expect(OfflineMapUpkeep.refreshInterval, const Duration(hours: 12));
  });

  group('refreshIfDue', () {
    test('should refresh the maps the first time', () async {
      expect(await upkeep.refreshIfDue(), MapRefreshOutcome.refreshed);

      expect(maps.log, ['create 1 t49', 'delete 40']);
    });

    test('should not refresh again within 12 hours of a refresh that '
        'worked', () async {
      await upkeep.refreshIfDue();
      clock.time = morning.add(const Duration(hours: 11, minutes: 59));

      expect(await upkeep.refreshIfDue(), MapRefreshOutcome.refreshed);

      expect(maps.downloadedBounds, hasLength(1));
    });

    test('should refresh again 12 hours after', () async {
      await upkeep.refreshIfDue();
      clock.time = morning.add(const Duration(hours: 12));

      await upkeep.refreshIfDue();

      expect(maps.downloadedBounds, hasLength(2));
    });

    test('should refresh again at once after a failure', () async {
      maps.scripts.add(const [MapDownloadFailed()]);
      expect(await upkeep.refreshIfDue(), MapRefreshOutcome.failed);

      expect(await upkeep.refreshIfDue(), MapRefreshOutcome.refreshed);

      expect(maps.downloadedBounds, hasLength(2));
    });

    test('should share the refresh going with a call made meanwhile', () async {
      final first = upkeep.refreshIfDue();
      final second = upkeep.refreshIfDue();

      expect(await Future.wait([first, second]), [
        MapRefreshOutcome.refreshed,
        MapRefreshOutcome.refreshed,
      ]);
      expect(maps.downloadedBounds, hasLength(1));
    });
  });

  group('refreshAllBut', () {
    test('should refresh the others even right after a refresh', () async {
      downloads = FakeTourneeDownloads([
        downloadOf(t49, area49),
        downloadOf(t12, area12),
      ]);
      upkeep = OfflineMapUpkeep(
        RefreshOfflineMaps(maps, downloads),
        PruneTourneeDownloads(
          myTournees,
          DeleteTourneeDownload(maps, downloads),
          maps,
          downloads,
        ),
        clock,
      );
      await upkeep.refreshIfDue();
      maps.log.clear();

      expect(await upkeep.refreshAllBut(t49), MapRefreshOutcome.refreshed);

      expect(maps.log, ['create 3 t12', 'delete 2']);
    });

    test('should wait for the refresh going', () async {
      final going = upkeep.refreshIfDue();

      await upkeep.refreshAllBut(t12);

      await going;
      expect(maps.downloadedBounds, [area49.expandedBy(1), area49]);
    });

    test('should count as a refresh for the next 12 hours', () async {
      await upkeep.refreshAllBut(t12);

      await upkeep.refreshIfDue();

      expect(maps.downloadedBounds, hasLength(1));
    });
  });

  group('prune', () {
    test('should delete the downloads of forgotten tournées', () async {
      myTournees.myTournees = MyTournees.none;

      await upkeep.prune();

      expect(downloads.downloads, isEmpty);
      expect(maps.current, isEmpty);
    });

    test('should prune once more when asked while pruning', () async {
      final first = upkeep.prune();
      myTournees.myTournees = MyTournees.none;
      final second = upkeep.prune();

      await Future.wait([first, second]);

      expect(downloads.downloads, isEmpty);
      expect(maps.log, ['delete 40']);
    });
  });

  group('provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          offlineMapStoreProvider.overrideWithValue(maps),
          tourneeDownloadsProvider.overrideWithValue(downloads),
          myTourneesStoreProvider.overrideWithValue(myTournees),
          clockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(container.dispose);
    });

    test('should prune when built', () async {
      myTournees.myTournees = MyTournees.none;

      container.read(offlineMapUpkeepProvider);
      await pumpEventQueue();

      expect(downloads.downloads, isEmpty);
    });

    test('should prune when the phone forgets a tournée', () async {
      container.read(offlineMapUpkeepProvider);
      await pumpEventQueue();
      expect(downloads.downloads.keys, [t49]);

      await myTournees.save(MyTournees.none);
      await pumpEventQueue();

      expect(downloads.downloads, isEmpty);
      expect(maps.current, isEmpty);
    });

    test('should refresh through the bound ports', () async {
      await container.read(offlineMapUpkeepProvider).refreshIfDue();

      expect(maps.log, ['create 1 t49', 'delete 40']);
    });
  });
}
