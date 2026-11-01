// Downloading a tournée for a day offline (PLAN §7): every street read from
// the server, then the map of its area, then the date and size kept.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/offline_map_store.dart';
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/application/use_cases/download_tournee.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

import '../../domain/tournee/tournee_fixtures.dart' show campaign2026;
import '../../support/fakes/fake_offline_map_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_streets_download.dart';
import '../../support/fakes/fake_tournee_downloads.dart';
import '../../support/street_fixtures.dart' show lea;
import 'offline_fixtures.dart';

void main() {
  late FakeStreetsDownload streets;
  late FakeOfflineMapStore maps;
  late FakeTourneeDownloads downloads;
  late DownloadTournee download;
  final eightThirty = DateTime.utc(2026, 11, 2, 8, 30);

  void build({Duration stallLimit = DownloadTournee.defaultStallLimit}) {
    download = DownloadTournee(
      streets,
      maps,
      downloads,
      FakeClock(eightThirty),
      stallLimit: stallLimit,
    );
  }

  setUp(() {
    streets = FakeStreetsDownload(Ok([nationale, paix]));
    maps = FakeOfflineMapStore();
    downloads = FakeTourneeDownloads();
    build();
  });

  test('should give up on a map download silent for a minute', () {
    expect(DownloadTournee.defaultStallLimit, const Duration(minutes: 1));
  });

  test('should read the streets, then download the map, telling the '
      'progress', () async {
    maps.scripts.add(const [
      MapDownloadProgress(fraction: 0.25, bytes: 1000),
      MapDownloadProgress(fraction: 0.75, bytes: 5000),
      MapDownloadDone(bytes: 6600000),
    ]);

    final progress = await download(t49, campaign2026).toList();

    final saved = TourneeDownload(
      tournee: t49,
      downloadedAt: eightThirty,
      mapBytes: 6600000,
      area: area49,
    );
    expect(progress, [
      const DownloadingStreets(),
      const DownloadingMap(fraction: 0.25, bytes: 1000),
      const DownloadingMap(fraction: 0.75, bytes: 5000),
      Downloaded(saved),
    ]);
    expect(streets.asked, [(t49, campaign2026)]);
    expect(maps.downloadedBounds, [area49]);
    expect(maps.log, ['create 1 t49']);
    expect(downloads.downloads, {t49: saved});
  });

  test('should keep the map of the streets in the Corbeille', () async {
    final (deleted, _) = placedStreet(
      'Gare',
      45.9800,
    ).delete(by: lea, at: morning);
    streets.answer = Ok([nationale, deleted]);

    await download(t49, campaign2026).toList();

    expect(maps.downloadedBounds, [
      tourneeArea([nationale, deleted]),
    ]);
  });

  test('should tell and keep nothing when the server cannot be '
      'reached', () async {
    streets.answer = const Err(StreetsDownloadFailure.noNetwork);

    final progress = await download(t49, campaign2026).toList();

    expect(progress, [
      const DownloadingStreets(),
      const DownloadFailed(DownloadFailure.noNetwork),
    ]);
    expect(maps.log, isEmpty);
    expect(downloads.downloads, isEmpty);
  });

  test('should tell when the server refuses the streets', () async {
    streets.answer = const Err(StreetsDownloadFailure.serviceError);

    final progress = await download(t49, campaign2026).toList();

    expect(progress.last, const DownloadFailed(DownloadFailure.serviceError));
    expect(downloads.downloads, isEmpty);
  });

  test('should tell and keep no download when the map fails', () async {
    maps.scripts.add(const [
      MapDownloadProgress(fraction: 0.5, bytes: 3000),
      MapDownloadFailed(),
    ]);

    final progress = await download(t49, campaign2026).toList();

    expect(progress, [
      const DownloadingStreets(),
      const DownloadingMap(fraction: 0.5, bytes: 3000),
      const DownloadFailed(DownloadFailure.mapUnavailable),
    ]);
    expect(maps.current, isEmpty);
    expect(downloads.downloads, isEmpty);
  });

  test('should fail and delete the half region when the map download '
      'stalls', () async {
    maps.scripts.add(null);
    build(stallLimit: const Duration(milliseconds: 1));

    final progress = await download(t49, campaign2026).toList();

    expect(progress.last, const DownloadFailed(DownloadFailure.mapUnavailable));
    expect(maps.log, ['create 1 t49', 'cancel 1']);
    expect(maps.current, isEmpty);
    expect(downloads.downloads, isEmpty);
  });

  test('should fail when the map download ends without completing', () async {
    maps.scripts.add(const [MapDownloadProgress(fraction: 0.5, bytes: 3000)]);

    final progress = await download(t49, campaign2026).toList();

    expect(progress.last, const DownloadFailed(DownloadFailure.mapUnavailable));
    expect(downloads.downloads, isEmpty);
  });

  test('should keep the download, with no map, when no street has a place '
      'on the map', () async {
    streets.answer = Ok([placedStreet('Zola')]);

    final progress = await download(t49, campaign2026).toList();

    final saved = TourneeDownload(
      tournee: t49,
      downloadedAt: eightThirty,
      mapBytes: 0,
      area: null,
    );
    expect(progress, [const DownloadingStreets(), Downloaded(saved)]);
    expect(maps.log, isEmpty);
    expect(downloads.downloads, {t49: saved});
  });

  group('update', () {
    test('should download the new map first, then delete the old one, '
        'and keep the new date and size', () async {
      maps = FakeOfflineMapStore([regionOf(40, t49, area49)]);
      downloads = FakeTourneeDownloads([downloadOf(t49, area49)]);
      maps.defaultBytes = 7100000;
      build();

      final progress = await download(t49, campaign2026).toList();

      final saved = TourneeDownload(
        tournee: t49,
        downloadedAt: eightThirty,
        mapBytes: 7100000,
        area: area49,
      );
      expect(progress.last, Downloaded(saved));
      // The old region has the same bounds: the new one is 1 m wider, so
      // the map library does not delete the old one first.
      expect(maps.downloadedBounds, [area49.expandedBy(1)]);
      expect(maps.log, ['create 1 t49', 'delete 40']);
      expect(maps.current, [regionOf(1, t49, area49.expandedBy(1))]);
      expect(downloads.downloads, {t49: saved});
    });

    test('should keep the old map and download when the new map '
        'fails', () async {
      final old = regionOf(40, t49, area49);
      maps = FakeOfflineMapStore([old]);
      downloads = FakeTourneeDownloads([downloadOf(t49, area49)]);
      maps.scripts.add(const [MapDownloadFailed()]);
      build();

      await download(t49, campaign2026).toList();

      expect(maps.current, [old]);
      expect(downloads.downloads, {t49: downloadOf(t49, area49)});
    });

    test('should delete every old region of the tournée and only '
        'its', () async {
      final half = regionOf(41, t49, area49.expandedBy(1));
      final other = regionOf(50, t12, area12);
      maps = FakeOfflineMapStore([regionOf(40, t49, area49), other, half]);
      build();

      await download(t49, campaign2026).toList();

      expect(maps.downloadedBounds, [area49.expandedBy(2)]);
      expect(maps.log, ['create 1 t49', 'delete 40', 'delete 41']);
      expect(maps.current, [other, regionOf(1, t49, area49.expandedBy(2))]);
    });

    test('should delete the old map when no street has a place on the map '
        'any more', () async {
      maps = FakeOfflineMapStore([regionOf(40, t49, area49)]);
      streets.answer = Ok([placedStreet('Zola')]);
      build();

      await download(t49, campaign2026).toList();

      expect(maps.log, ['delete 40']);
      expect(downloads.downloads[t49]!.area, isNull);
    });
  });

  test('should delete the half region and keep nothing when the download '
      'is cancelled', () async {
    maps.scripts.add(null);

    final subscription = download(t49, campaign2026).listen((_) {});
    await pumpUntil(() => maps.log.isNotEmpty);
    await subscription.cancel();

    expect(maps.log, ['create 1 t49', 'cancel 1']);
    expect(downloads.downloads, isEmpty);
  });

  test('should end with the error of a port that throws', () async {
    maps.regionsError = StateError('db');

    final progress = download(t49, campaign2026);

    await expectLater(
      progress,
      emitsInOrder([const DownloadingStreets(), emitsError(isStateError)]),
    );
    expect(downloads.downloads, isEmpty);
  });

  test('should have each progress equal by value', () {
    expect(const DownloadingStreets(), const DownloadingStreets());
    expect(
      const DownloadingMap(fraction: 0.5, bytes: 1).hashCode,
      const DownloadingMap(fraction: 0.5, bytes: 1).hashCode,
    );
    expect(
      const DownloadingMap(fraction: 0.5, bytes: 1),
      isNot(const DownloadingMap(fraction: 0.5, bytes: 2)),
    );
    expect(
      const DownloadingMap(fraction: 0.5, bytes: 1),
      isNot(const DownloadingMap(fraction: 0.6, bytes: 1)),
    );
    expect(
      const DownloadFailed(DownloadFailure.noNetwork),
      isNot(const DownloadFailed(DownloadFailure.mapUnavailable)),
    );
    expect(
      const DownloadFailed(DownloadFailure.noNetwork).hashCode,
      const DownloadFailed(DownloadFailure.noNetwork).hashCode,
    );
    expect(
      const DownloadingStreets().hashCode,
      const DownloadingStreets().hashCode,
    );
    final done = Downloaded(downloadOf(t49, area49));
    expect(done, Downloaded(downloadOf(t49, area49)));
    expect(done.hashCode, Downloaded(downloadOf(t49, area49)).hashCode);
    expect(done, isNot(Downloaded(downloadOf(t12, area49))));
  });

  test('should print each progress', () {
    expect(
      '${const DownloadingMap(fraction: 0.5, bytes: 1)}',
      'DownloadingMap(0.5, 1)',
    );
    expect(
      '${const DownloadFailed(DownloadFailure.noNetwork)}',
      'DownloadFailed(DownloadFailure.noNetwork)',
    );
    expect(
      '${Downloaded(downloadOf(t49, null))}',
      'Downloaded(${downloadOf(t49, null)})',
    );
  });
}

/// Lets the event loop run until [done] holds.
Future<void> pumpUntil(bool Function() done) async {
  while (!done()) {
    await Future<void>.delayed(Duration.zero);
  }
}
