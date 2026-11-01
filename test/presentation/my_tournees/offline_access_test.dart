import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_state.dart';
import 'package:tournee_calendriers/presentation/my_tournees/offline_access.dart';

import '../../support/fakes/fake_server_connection.dart';
import '../../support/fakes/fake_tournee_downloads.dart';

final _t12 = TourneeId('t12');
final _t23 = TourneeId('t23');

/// The tournée [id], downloaded on the phone.
TourneeDownload _downloaded(TourneeId id) => TourneeDownload(
  tournee: id,
  downloadedAt: DateTime.utc(2026, 11, 2, 8, 12),
  mapBytes: 34000000,
  area: null,
);

/// The row of « Tournée 23 · 2026 », CS Limas, [status].
TourneeRow _row(TourneeId id, TourneeRowStatus status) => TourneeRow(
  id: id,
  number: 23,
  campaign: 2026,
  centre: 'CS Limas',
  status: status,
);

// « Disponible avec réseau » in « Mes tournées » (PLAN §5.3, #33).
void main() {
  group('OfflineAccess', () {
    final offline = OfflineAccess(offline: true, downloaded: {_t12});

    test('should say a tournée not downloaded cannot open when offline', () {
      expect(
        offline.isUnavailable(_row(_t23, TourneeRowStatus.closed)),
        isTrue,
      );
    });

    test('should let a downloaded tournée open when offline', () {
      expect(
        offline.isUnavailable(_row(_t12, TourneeRowStatus.closed)),
        isFalse,
      );
    });

    test('should let any tournée open when online', () {
      final online = OfflineAccess(offline: false, downloaded: {_t12});

      expect(
        online.isUnavailable(_row(_t23, TourneeRowStatus.closed)),
        isFalse,
      );
    });

    test('should never grey the open tournée', () {
      expect(offline.isUnavailable(_row(_t23, TourneeRowStatus.open)), isFalse);
    });

    test('should leave a pending request its own look', () {
      expect(
        offline.isUnavailable(_row(_t23, TourneeRowStatus.pending)),
        isFalse,
      );
    });

    test('should compare by offline and downloaded tournées', () {
      expect(OfflineAccess(offline: true, downloaded: {_t12}), offline);
      expect(
        OfflineAccess(offline: true, downloaded: {_t12}).hashCode,
        offline.hashCode,
      );
      expect(
        OfflineAccess(offline: false, downloaded: {_t12}) == offline,
        isFalse,
      );
      expect(
        OfflineAccess(offline: true, downloaded: {_t12, _t23}) == offline,
        isFalse,
      );
      expect(OfflineAccess(offline: true, downloaded: {}) == offline, isFalse);
    });

    test('should name what it holds in test failures', () {
      expect('$offline', 'OfflineAccess(offline: true, {TourneeId(t12)})');
    });

    test('should keep its downloaded tournées from being changed', () {
      expect(() => offline.downloaded.add(_t23), throwsUnsupportedError);
    });
  });

  group('offlineAccessProvider', () {
    late FakeServerConnection connection;
    late FakeTourneeDownloads downloads;
    late ProviderContainer container;
    late ProviderSubscription<OfflineAccess> sheet;
    late OfflineAccess first;

    setUp(() {
      connection = FakeServerConnection(offline: true);
      downloads = FakeTourneeDownloads([_downloaded(_t12)]);
      container = ProviderContainer(
        overrides: [
          serverConnectionProvider.overrideWithValue(connection),
          tourneeDownloadsProvider.overrideWithValue(downloads),
        ],
      );
      // `listen` keeps the autoDispose notifier alive, as the open sheet
      // watching it does.
      sheet = container.listen(offlineAccessProvider, (_, _) {});
      // Read before any answer of the connection can arrive.
      first = container.read(offlineAccessProvider);
    });

    tearDown(() => container.dispose());

    test(
      'should know the downloaded tournées at once and say online until told',
      () {
        expect(first, OfflineAccess(offline: false, downloaded: {_t12}));
      },
    );

    test('should follow the phone going offline and back online', () async {
      await pumpEventQueue();
      expect(container.read(offlineAccessProvider).offline, isTrue);

      connection.reach(offline: false);
      await pumpEventQueue();

      expect(container.read(offlineAccessProvider).offline, isFalse);
    });

    test('should follow a tournée downloaded meanwhile', () async {
      await pumpEventQueue();
      await downloads.save(_downloaded(_t23));
      await pumpEventQueue();

      expect(
        container.read(offlineAccessProvider),
        OfflineAccess(offline: true, downloaded: {_t12, _t23}),
      );
    });

    test('should follow a download forgotten meanwhile', () async {
      await pumpEventQueue();
      await downloads.forget(_t12);
      await pumpEventQueue();

      expect(
        container.read(offlineAccessProvider),
        OfflineAccess(offline: true, downloaded: const {}),
      );
    });

    test(
      'should say online when the connection can no longer be told',
      () async {
        await pumpEventQueue();

        connection.fail(StateError('permission-denied'));
        await pumpEventQueue();

        expect(container.read(offlineAccessProvider).offline, isFalse);
      },
    );

    test('should stop following once the sheet is closed', () async {
      await pumpEventQueue();
      expect(connection.isFollowed, isTrue);

      sheet.close();
      await pumpEventQueue();

      expect(connection.isFollowed, isFalse);
    });
  });
}
