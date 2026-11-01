// Which tournées are downloaded on this phone (PLAN §6.3), and forgetting
// the download of a tournée the phone forgot.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_offline_map_store.dart';
import '../../support/fakes/fake_tournee_downloads.dart';
import 'offline_fixtures.dart';

void main() {
  late FakeOfflineMapStore maps;
  late FakeTourneeDownloads downloads;

  setUp(() {
    maps = FakeOfflineMapStore([
      regionOf(40, t49, area49),
      regionOf(50, t12, area12),
      regionOf(41, t49, area49.expandedBy(1)),
    ]);
    downloads = FakeTourneeDownloads([
      downloadOf(t49, area49),
      downloadOf(t12, area12),
    ]);
  });

  group('ReadTourneeDownloads', () {
    test('should give the downloads kept on the phone', () {
      expect(ReadTourneeDownloads(downloads)(), {
        t49: downloadOf(t49, area49),
        t12: downloadOf(t12, area12),
      });
    });
  });

  group('ObserveTourneeDownloads', () {
    test('should give the downloads now, then after each change', () async {
      final seen = ObserveTourneeDownloads(downloads)().take(2).toList();
      await pumpEventQueue();

      await downloads.forget(t12);

      expect(await seen, [
        {t49: downloadOf(t49, area49), t12: downloadOf(t12, area12)},
        {t49: downloadOf(t49, area49)},
      ]);
    });
  });

  group('DeleteTourneeDownload', () {
    test('should forget the download and delete every region of the '
        'tournée', () async {
      await DeleteTourneeDownload(maps, downloads)(t49);

      expect(downloads.downloads, {t12: downloadOf(t12, area12)});
      expect(maps.log, ['delete 40', 'delete 41']);
      expect(maps.current, [regionOf(50, t12, area12)]);
    });
  });

  group('PruneTourneeDownloads', () {
    PruneTourneeDownloads prune(MyTournees mine) => PruneTourneeDownloads(
      FakeMyTourneesStore(mine),
      DeleteTourneeDownload(maps, downloads),
      maps,
      downloads,
    );

    test('should delete the download of a tournée no longer in « Mes '
        'tournées »', () async {
      await prune(MyTournees.none.remember(tournee12))();

      expect(downloads.downloads, {t12: downloadOf(t12, area12)});
      expect(maps.current, [regionOf(50, t12, area12)]);
    });

    test('should keep the downloads of the tournées still known', () async {
      await prune(MyTournees.none.remember(tournee49).remember(tournee12))();

      expect(downloads.downloads.keys, {t49, t12});
      expect(maps.log, isEmpty);
    });

    // A download killed before its end leaves a region and no record.
    test('should delete the regions of a forgotten tournée with no '
        'download kept', () async {
      downloads = FakeTourneeDownloads();

      await prune(MyTournees.none.remember(tournee12))();

      expect(maps.current, [regionOf(50, t12, area12)]);
    });

    test('should keep the regions of a known tournée with no download '
        'kept', () async {
      downloads = FakeTourneeDownloads();

      await prune(MyTournees.none.remember(tournee49).remember(tournee12))();

      expect(maps.log, isEmpty);
    });
  });
}
