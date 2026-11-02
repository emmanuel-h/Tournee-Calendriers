// The composition root keeps the open tournée downloaded while the app
// runs, and checks again when the app comes back to the foreground
// (PLAN §7). Nothing shows.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/streets_download.dart';
import 'package:tournee_calendriers/bootstrap/offline_upkeep.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

import '../application/use_cases/offline_fixtures.dart';
import '../domain/sector/my_sectors_fixtures.dart';
import '../support/fakes/fake_my_sectors_store.dart';
import '../support/fakes/fake_offline_map_store.dart';
import '../support/fakes/fake_ports.dart';
import '../support/fakes/fake_sector_downloads.dart';
import '../support/fakes/fake_sector_repository.dart';
import '../support/fakes/fake_street_repository.dart';
import '../support/fakes/fake_streets_download.dart';
import '../support/results.dart';

void main() {
  late FakeStreetsDownload streets;
  late FakeSectorDownloads downloads;
  late FakeClock clock;

  setUp(() {
    streets = FakeStreetsDownload(const Err(StreetsDownloadFailure.noNetwork));
    downloads = FakeSectorDownloads();
    clock = FakeClock(morning);
  });

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        streetsDownloadProvider.overrideWithValue(streets),
        offlineMapStoreProvider.overrideWithValue(FakeOfflineMapStore()),
        sectorDownloadsProvider.overrideWithValue(downloads),
        mySectorsStoreProvider.overrideWithValue(
          FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(t49)),
          ),
        ),
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
        streetRepositoryProvider.overrideWithValue(
          FakeStreetRepository([nationale, paix]),
        ),
        clockProvider.overrideWithValue(clock),
      ],
      child: const OfflineUpkeep(child: SizedBox(key: Key('app'))),
    ),
  );

  testWidgets('should show the app and download the open tournée', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pump();

    expect(find.byKey(const Key('app')), findsOneWidget);
    expect(streets.asked, hasLength(1));
  });

  testWidgets('should check again when the app comes back to the '
      'foreground', (tester) async {
    await pumpApp(tester);
    await tester.pump();
    streets.answer = Ok([nationale, paix]);
    clock.time = morning.add(const Duration(minutes: 3));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(streets.asked, hasLength(2));
    expect(downloads.downloads.keys, [t49]);
    // Stops the retry timer the first check left.
    await tester.pumpWidget(const SizedBox());
  });
}
