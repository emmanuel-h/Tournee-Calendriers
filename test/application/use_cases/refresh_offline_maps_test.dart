// The silent map refresh (PLAN §7): the map's tiles change every week, and
// a region downloaded before a change can no longer be reached offline once
// the app has been online. So each downloaded tournée's map is downloaded
// again whenever the app is online: a new region first, the old one deleted
// only after it is complete.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/use_cases/refresh_offline_maps.dart';

import '../../support/fakes/fake_offline_map_store.dart';
import '../../support/fakes/fake_tournee_downloads.dart';
import 'offline_fixtures.dart';

void main() {
  late FakeOfflineMapStore maps;
  late FakeTourneeDownloads downloads;

  RefreshOfflineMaps refresh({
    Duration stallLimit = const Duration(minutes: 1),
  }) => RefreshOfflineMaps(maps, downloads, stallLimit: stallLimit);

  final old49 = regionOf(40, t49, area49);

  setUp(() {
    maps = FakeOfflineMapStore([old49]);
    downloads = FakeTourneeDownloads([downloadOf(t49, area49)]);
  });

  test('should download a new region first, then delete the old one', () async {
    final outcome = await refresh()();

    expect(outcome, MapRefreshOutcome.refreshed);
    expect(maps.downloadedBounds, [area49.expandedBy(1)]);
    expect(maps.log, ['create 1 t49', 'delete 40']);
    expect(maps.current, [regionOf(1, t49, area49.expandedBy(1))]);
  });

  test('should go back to the area itself at the next refresh', () async {
    await refresh()();

    await refresh()();

    expect(maps.downloadedBounds, [area49.expandedBy(1), area49]);
    expect(maps.current, [regionOf(2, t49, area49)]);
  });

  test('should keep the old region when the new one fails', () async {
    maps.scripts.add(const [
      MapDownloadProgress(fraction: 0.3, bytes: 100),
      MapDownloadFailed(),
    ]);

    final outcome = await refresh()();

    expect(outcome, MapRefreshOutcome.failed);
    expect(maps.current, [old49]);
    expect(maps.log, ['create 1 t49']);
  });

  test('should keep the old region and delete the half one when the new '
      'one stalls', () async {
    maps.scripts.add(null);

    final outcome = await refresh(
      stallLimit: const Duration(milliseconds: 1),
    )();

    expect(outcome, MapRefreshOutcome.failed);
    expect(maps.log, ['create 1 t49', 'cancel 1']);
    expect(maps.current, [old49]);
  });

  test('should keep the download as it was', () async {
    await refresh()();

    expect(downloads.downloads, {t49: downloadOf(t49, area49)});
  });

  test('should refresh every downloaded tournée, each deleting only its '
      'own old regions', () async {
    final old12 = regionOf(50, t12, area12);
    maps = FakeOfflineMapStore([old49, old12]);
    downloads = FakeTourneeDownloads([
      downloadOf(t49, area49),
      downloadOf(t12, area12),
    ]);

    await refresh()();

    expect(maps.log, [
      'create 1 t49',
      'delete 40',
      'create 2 t12',
      'delete 50',
    ]);
  });

  test('should stop at the first failure', () async {
    maps = FakeOfflineMapStore([old49, regionOf(50, t12, area12)]);
    downloads = FakeTourneeDownloads([
      downloadOf(t49, area49),
      downloadOf(t12, area12),
    ]);
    maps.scripts.add(const [MapDownloadFailed()]);

    final outcome = await refresh()();

    expect(outcome, MapRefreshOutcome.failed);
    expect(maps.log, ['create 1 t49']);
  });

  test('should skip a tournée downloaded with no map', () async {
    maps = FakeOfflineMapStore();
    downloads = FakeTourneeDownloads([downloadOf(t49, null)]);

    final outcome = await refresh()();

    expect(outcome, MapRefreshOutcome.refreshed);
    expect(maps.log, isEmpty);
  });

  test('should download the map again when its region went', () async {
    maps = FakeOfflineMapStore();

    await refresh()();

    expect(maps.current, [regionOf(1, t49, area49)]);
  });

  test('should leave the regions of a tournée not downloaded', () async {
    final half = regionOf(60, t12, area12);
    maps = FakeOfflineMapStore([half]);
    downloads = FakeTourneeDownloads();

    final outcome = await refresh()();

    expect(outcome, MapRefreshOutcome.refreshed);
    expect(maps.current, [half]);
  });

  test('should leave the map of the tournée just downloaded', () async {
    final old12 = regionOf(50, t12, area12);
    maps = FakeOfflineMapStore([old49, old12]);
    downloads = FakeTourneeDownloads([
      downloadOf(t49, area49),
      downloadOf(t12, area12),
    ]);

    final outcome = await refresh()(except: t49);

    expect(outcome, MapRefreshOutcome.refreshed);
    expect(maps.log, ['create 1 t12', 'delete 50']);
  });
}
