// The Play Store phone screenshots, made from the real app's screens.
//
// NOT part of the instrumented suite: run it only through
// `tool/store_screenshots.sh`, which sets the device up (2:1 screen, clean
// status bar), takes each screenshot with `adb screencap` when this test
// asks for it, and writes them to store/screenshots/fr-FR/phone-1.png …
// phone-5.png. Run alone, it waits for screenshots nobody takes and fails.
//
// The app runs on in-memory fakes seeded with a made-up round in
// Villefranche-sur-Saône (`store_screenshots_data.dart`): nothing is read
// from or written to Firebase. Only the map's background needs the
// network (OpenFreeMap tiles).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/ui/app.dart';

import '../test/domain/sector/sector_fixtures.dart' show nameOf;
import '../test/support/fakes/fake_my_sectors_store.dart';
import '../test/support/fakes/fake_phone_settings.dart';
import '../test/support/fakes/fake_sector_repository.dart';
import '../test/support/fakes/fake_street_repository.dart';
import '../test/support/results.dart';
import '../test/ui/support/app_overrides.dart';
import 'store_screenshots_data.dart';

/// What the test prints when a screen is ready; the script watches for it.
const _marker = 'STORE_SCREENSHOT';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Every frame the app asks for is drawn, as in the app: the map tells
  // its zoom, and the screen redraws, without the test pumping.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  /// Lets the app run in real time for [seconds] (the map's tiles load),
  /// then asks the script for the screenshot [name] and waits until it
  /// says it took it, by creating `<name>.done` in the app's temporary
  /// folder (`adb shell run-as … touch`).
  Future<void> capture(
    WidgetTester tester,
    String name, {
    int seconds = 2,
  }) async {
    await tester.pumpAndSettle();
    await Future<void>.delayed(Duration(seconds: seconds));
    await tester.pump();
    final done = File('${Directory.systemTemp.path}/$name.done');
    if (done.existsSync()) done.deleteSync();
    debugPrint('$_marker $name ${done.path}');
    for (var i = 0; i < 300 && !done.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(
      done.existsSync(),
      isTrue,
      reason: 'nobody took $name: run tool/store_screenshots.sh',
    );
    done.deleteSync();
  }

  testWidgets('should show the five screens of the store listing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          nativeMap: true,
          member: leaOnPhone,
          now: storeNow,
          streets: FakeStreetRepository(storeStreets()),
          sectors: FakeSectorRepository([storeSector]),
          mySectors: FakeMySectorsStore(
            valueOf(
              MySectors.none
                  .remember(storeSectorSummary)
                  .open(storeSectorSummary.id),
            ),
          ),
          settings: FakePhoneSettings(
            memberName: nameOf('Léa'),
            theme: ThemeChoice.light,
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );

    // 1. Accueil: the map of the tournée, the panel folded down to its
    // totals (a flick down from rest). Folded at once, before the map's
    // style has loaded: the map fits the streets into the room the panel
    // leaves it when the style is ready, and only then.
    final handle = find.byKey(const Key('home.panel.handle'));
    while (handle.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.fling(handle, const Offset(0, 300), 2000);
    await capture(tester, 'phone-1', seconds: 8);

    // 2. Rue de Thizy, from « Mes rues » (a tap on the handle shows them
    // all).
    await tester.tap(handle);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('home.street.${rueDeThizy.value}')));
    await capture(tester, 'phone-2');

    // 3. The sheet of the house to come back to, held.
    await tester.longPress(
      find.byKey(const ValueKey('street.tile.$comeBackHouse')),
    );
    await capture(tester, 'phone-3');
    // A tap above the sheet closes it.
    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();

    // 4. The grid of the immeuble, tapped.
    await tester.tap(find.byKey(const ValueKey('street.tile.$buildingHouse')));
    await capture(tester, 'phone-4');
    await tester.tap(find.byKey(const Key('grid.close')));
    await tester.pumpAndSettle();

    // 5. Équipe, from Accueil.
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home.team')));
    await tester.pumpAndSettle();
    // Léa's own streets unfolded under her row (#105).
    await tester.tap(find.byKey(const Key('team.member.streets')).at(1));
    await capture(tester, 'phone-5');
  });
}
