// The open tournée is downloaded for offline use by the app itself, unseen
// (PLAN §7): when it is not yet, when its streets reach beyond the map
// kept, and the maps are refreshed otherwise; a failure waits two minutes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/application/use_cases/download_sector.dart';
import 'package:tournee_calendriers/application/use_cases/refresh_offline_maps.dart';
import 'package:tournee_calendriers/application/use_cases/sector_downloads.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/offline/offline_auto_download.dart';
import 'package:tournee_calendriers/presentation/offline/offline_map_upkeep.dart';

import '../../application/use_cases/offline_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show campaign2026;
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_offline_map_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_downloads.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_streets_download.dart';
import '../../support/results.dart';
import 'fake_schedule.dart';

/// A street of the 49 beyond [area49].
final _farStreet = placedStreet('Gare', 45.9990);

void main() {
  late FakeStreetsDownload streets;
  late FakeOfflineMapStore maps;
  late FakeSectorDownloads downloads;
  late FakeMySectorsStore mySectors;
  late FakeClock clock;
  late FakeSchedule schedule;
  final eightThirty = DateTime.utc(2026, 11, 2, 8, 30);

  setUp(() {
    streets = FakeStreetsDownload(Ok([nationale, paix]));
    maps = FakeOfflineMapStore();
    downloads = FakeSectorDownloads();
    mySectors = FakeMySectorsStore(MySectors.none.remember(sector49));
    clock = FakeClock(eightThirty);
    schedule = FakeSchedule();
  });

  OfflineAutoDownload auto({bool open = true}) => OfflineAutoDownload(
    open: open ? (t49, campaign2026) : null,
    download: DownloadSector(streets, maps, downloads, clock),
    downloads: ReadSectorDownloads(downloads),
    upkeep: OfflineMapUpkeep(
      RefreshOfflineMaps(maps, downloads),
      PruneSectorDownloads(
        mySectors,
        DeleteSectorDownload(maps, downloads),
        maps,
        downloads,
      ),
      clock,
    ),
    clock: clock,
    schedule: schedule.call,
  );

  test('should wait two minutes after a failure', () {
    expect(OfflineAutoDownload.retryDelay, const Duration(minutes: 2));
  });

  test('should download the open tournée when it is not yet', () async {
    await auto().check();

    expect(streets.asked, [(t49, campaign2026)]);
    expect(downloads.downloads, {
      t49: SectorDownload(
        sector: t49,
        downloadedAt: eightThirty,
        mapBytes: 7000000,
        area: area49,
      ),
    });
    expect(maps.current, [regionOf(1, t49, area49)]);
  });

  test('should refresh the other downloaded maps right after a '
      'download', () async {
    downloads = FakeSectorDownloads([downloadOf(t12, area12)]);
    maps = FakeOfflineMapStore([regionOf(50, t12, area12)]);

    await auto().check();

    expect(maps.log, ['create 1 t49', 'create 2 t12', 'delete 50']);
  });

  test('should only refresh the maps when the open tournée is downloaded '
      'and covers its streets', () async {
    downloads = FakeSectorDownloads([downloadOf(t49, area49)]);
    maps = FakeOfflineMapStore([regionOf(40, t49, area49)]);
    auto().streetsChanged([nationale, paix]);
    await _pumpUntil(() => maps.log.length == 2);

    expect(streets.asked, isEmpty);
    expect(maps.log, ['create 1 t49', 'delete 40']);
    expect(downloads.downloads, {t49: downloadOf(t49, area49)});
  });

  test('should download the tournée again when a street reaches beyond the '
      'map kept', () async {
    downloads = FakeSectorDownloads([downloadOf(t49, area49)]);
    maps = FakeOfflineMapStore([regionOf(40, t49, area49)]);
    streets.answer = Ok([nationale, paix, _farStreet]);
    final download = auto();
    await download.check();
    streets.asked.clear();

    download.streetsChanged([nationale, paix, _farStreet]);
    await pumpEventQueue();

    expect(streets.asked, [(t49, campaign2026)]);
    expect(
      downloads.downloads[t49]!.area,
      sectorArea([nationale, paix, _farStreet]),
    );
  });

  test('should only refresh the maps when no tournée is open', () async {
    downloads = FakeSectorDownloads([downloadOf(t12, area12)]);
    maps = FakeOfflineMapStore([regionOf(50, t12, area12)]);

    await auto(open: false).check();

    expect(streets.asked, isEmpty);
    expect(maps.log, ['create 1 t12', 'delete 50']);
  });

  group('after a failure', () {
    late OfflineAutoDownload download;

    setUp(() async {
      streets.answer = const Err(StreetsDownloadFailure.noNetwork);
      download = auto();
      await download.check();
    });

    test('should try again two minutes later', () async {
      expect(schedule.delays, [OfflineAutoDownload.retryDelay]);
      streets.answer = Ok([nationale, paix]);
      clock.time = eightThirty.add(OfflineAutoDownload.retryDelay);

      schedule.fire();
      await pumpEventQueue();

      expect(streets.asked, hasLength(2));
      expect(downloads.downloads.keys, [t49]);
    });

    test('should not try again before two minutes, whatever asks', () async {
      clock.time = eightThirty.add(
        OfflineAutoDownload.retryDelay - const Duration(seconds: 1),
      );

      await download.check();
      download.streetsChanged([nationale]);
      await pumpEventQueue();

      expect(streets.asked, hasLength(1));
    });

    test('should try again when asked two minutes later', () async {
      clock.time = eightThirty.add(OfflineAutoDownload.retryDelay);

      await download.check();

      expect(streets.asked, hasLength(2));
      expect(schedule.delays, hasLength(2));
      expect(schedule.waiting, 1);
    });

    test('should try again and again while it fails', () async {
      clock.time = eightThirty.add(OfflineAutoDownload.retryDelay);
      schedule.fire();
      await pumpEventQueue();

      expect(streets.asked, hasLength(2));
      expect(schedule.waiting, 1);
    });
  });

  test('should wait two minutes after a map refresh fails', () async {
    downloads = FakeSectorDownloads([downloadOf(t49, area49)]);
    maps = FakeOfflineMapStore([regionOf(40, t49, area49)]);
    maps.scripts.add(const [MapDownloadFailed()]);

    await auto().check();

    expect(maps.current, [regionOf(40, t49, area49)]);
    expect(schedule.delays, [OfflineAutoDownload.retryDelay]);
  });

  test('should wait two minutes when the map library fails', () async {
    downloads = FakeSectorDownloads([downloadOf(t49, area49)]);
    final failing = _FailingMapStore();
    final download = OfflineAutoDownload(
      open: (t49, campaign2026),
      download: DownloadSector(streets, failing, downloads, clock),
      downloads: ReadSectorDownloads(downloads),
      upkeep: OfflineMapUpkeep(
        RefreshOfflineMaps(failing, downloads),
        PruneSectorDownloads(
          mySectors,
          DeleteSectorDownload(failing, downloads),
          failing,
          downloads,
        ),
        clock,
      ),
      clock: clock,
      schedule: schedule.call,
    );

    await download.check();

    expect(schedule.delays, [OfflineAutoDownload.retryDelay]);
  });

  test('should wait two minutes when the download breaks', () async {
    final failing = _FailingMapStore();
    final download = OfflineAutoDownload(
      open: (t49, campaign2026),
      download: DownloadSector(streets, failing, downloads, clock),
      downloads: ReadSectorDownloads(downloads),
      upkeep: OfflineMapUpkeep(
        RefreshOfflineMaps(failing, downloads),
        PruneSectorDownloads(
          mySectors,
          DeleteSectorDownload(failing, downloads),
          failing,
          downloads,
        ),
        clock,
      ),
      clock: clock,
      schedule: schedule.call,
    );

    await download.check();

    expect(downloads.downloads, isEmpty);
    expect(schedule.delays, [OfflineAutoDownload.retryDelay]);
  });

  test('should run once more when asked during a run', () async {
    downloads = FakeSectorDownloads([downloadOf(t49, area49)]);
    maps = FakeOfflineMapStore([regionOf(40, t49, area49)]);
    streets.answer = Ok([nationale, paix, _farStreet]);
    final download = auto();

    final first = download.check();
    download.streetsChanged([nationale, paix, _farStreet]);
    await first;

    expect(streets.asked, [(t49, campaign2026)]);
    expect(downloads.downloads[t49]!.area, isNot(area49));
  });

  test('should stop the download and every check when disposed', () async {
    maps.scripts.add(null);
    final download = auto();
    final running = download.check();
    await _pumpUntil(() => maps.log.isNotEmpty);

    download.dispose();
    await running;
    await download.check();

    expect(maps.log, ['create 1 t49', 'cancel 1']);
    expect(downloads.downloads, isEmpty);
    expect(streets.asked, hasLength(1));
  });

  test('should not wait after a failure once disposed', () async {
    streets.answer = const Err(StreetsDownloadFailure.noNetwork);
    final download = auto()..dispose();

    await download.check();

    expect(schedule.delays, isEmpty);
  });

  test('should cancel the retry when disposed', () async {
    streets.answer = const Err(StreetsDownloadFailure.noNetwork);
    final download = auto();
    await download.check();

    download.dispose();

    expect(schedule.waiting, 0);
  });

  group('provider', () {
    late ProviderContainer container;
    late FakeStreetRepository streets49;

    setUp(() {
      streets49 = FakeStreetRepository([nationale, paix]);
      mySectors = FakeMySectorsStore(
        valueOf(MySectors.none.remember(sector49).remember(sector12).open(t49)),
      );
      container = ProviderContainer(
        overrides: [
          streetsDownloadProvider.overrideWithValue(streets),
          offlineMapStoreProvider.overrideWithValue(maps),
          sectorDownloadsProvider.overrideWithValue(downloads),
          mySectorsStoreProvider.overrideWithValue(mySectors),
          clockProvider.overrideWithValue(clock),
          streetRepositoryProvider.overrideWithValue(streets49),
          // « Mes tournées » follows the team of each tournée not open.
          sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
        ],
      );
      addTearDown(container.dispose);
    });

    /// Keeps the provider alive, as the composition root does.
    void follow() => container.listen(offlineAutoDownloadProvider, (_, _) {});

    test('should download the open tournée when built', () async {
      follow();
      await _pumpUntil(() => downloads.downloads.isNotEmpty);

      expect(streets.asked, [(t49, campaign2026)]);
      expect(downloads.downloads.keys, [t49]);
    });

    test('should stop the download of a tournée left and download the one '
        'opened', () async {
      maps.scripts.add(null);
      follow();
      await _pumpUntil(() => maps.log.isNotEmpty);

      await mySectors.save(valueOf(mySectors.mySectors.open(t12)));
      container.read(offlineAutoDownloadProvider);
      await _pumpUntil(() => downloads.downloads.isNotEmpty);

      expect(maps.log, ['create 1 t49', 'cancel 1', 'create 2 t12']);
      expect(downloads.downloads.keys, [t12]);
      expect(streets.asked, [(t49, campaign2026), (t12, campaign2026)]);
    });

    test('should download the tournée again when a teammate adds a street '
        'beyond the map', () async {
      follow();
      await _pumpUntil(() => downloads.downloads.isNotEmpty);
      streets.answer = Ok([nationale, paix, _farStreet]);

      await streets49.add(_farStreet);
      await _pumpUntil(() => streets.asked.length == 2);
      await _pumpUntil(() => downloads.downloads[t49]!.area != area49);

      expect(
        downloads.downloads[t49]!.area,
        sectorArea([nationale, paix, _farStreet]),
      );
    });

    test('should not download a tournée whose request waits', () async {
      mySectors.mySectors = MySectors.none.remember(
        summaryOf('t7', 7, status: MemberStatus.pending),
      );
      follow();
      await pumpEventQueue();

      expect(streets.asked, isEmpty);
    });

    test('should check again when asked', () async {
      follow();
      await _pumpUntil(() => downloads.downloads.isNotEmpty);
      clock.time = eightThirty.add(const Duration(hours: 13));

      await container.read(offlineAutoDownloadProvider).check();

      expect(maps.log.last, startsWith('delete'));
      expect(maps.downloadedBounds, hasLength(2));
    });
  });
}

/// Lets the event loop run until [done] holds.
Future<void> _pumpUntil(bool Function() done) async {
  for (var turn = 0; !done(); turn++) {
    if (turn > 1000) throw StateError('Never happened');
    await Future<void>.delayed(Duration.zero);
  }
}

/// A map library whose database fails on every call.
final class _FailingMapStore implements OfflineMapStore {
  @override
  Future<List<OfflineMapRegion>> regions() => Future.error(StateError('db'));

  @override
  Stream<MapDownloadEvent> download(_, _) => Stream.error(StateError('db'));

  @override
  Future<void> delete(OfflineMapRegion region) =>
      Future.error(StateError('db'));
}
