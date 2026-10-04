// Instrumented suite: end-to-end flows run inside the real app on an Android
// emulator or phone (`flutter test integration_test -d <device>`).
//
// Unlike `test/`, these tests start the actual app with the real
// composition root, so they catch what unit and widget tests cannot: wiring,
// platform plugins, startup. The suite stays small on purpose (≤ 10 tests).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/bootstrap/bootstrap.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/main.dart' as app;

import '../test/support/fakes/fake_address_directory.dart';
import '../test/support/fakes/fake_commune_search.dart';

/// The value of [result], which the test data guarantees.
T _ok<T, F>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('$failure'),
};

final _villefranche = _ok(
  Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
);
final _morin = BanStreetId('69264_1460');
final _bonnet = BanStreetId('69264_0682');

/// A BAN that knows two streets of Villefranche-sur-Saône (from the
/// fixtures of test/fixtures/ban/), so the import needs no network.
FakeAddressDirectory _ban() => FakeAddressDirectory(
  communes: {
    '69264': Ok(
      CommuneStreets(
        commune: _villefranche,
        streets: [
          DirectoryStreet(
            id: _morin,
            name: _ok(StreetName.create('Rue Pierre Morin')),
            numberCount: 3,
          ),
          DirectoryStreet(
            id: _bonnet,
            name: _ok(StreetName.create('Rue des Frères Bonnet')),
            numberCount: 2,
          ),
        ],
        skippedStreets: 0,
      ),
    ),
  },
  streets: {
    _morin: Ok(
      StreetNumbers(
        id: _morin,
        name: _ok(StreetName.create('Rue Pierre Morin')),
        commune: _villefranche,
        numbers: [
          for (final number in [32, 33, 34])
            DirectoryNumber(number: _ok(HouseNumber.create(number))),
        ],
        invalidNumbers: 0,
        duplicateNumbers: 0,
      ),
    ),
  },
);

void main() {
  // Connects the test to the device so results are reported back to
  // `flutter test`.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('should show the French title when the app starts', (
    tester,
  ) async {
    // The app reads its storage before the first frame: wait for it.
    await app.main();
    // Waits until the first frames are drawn and no animation is running.
    await tester.pumpAndSettle();

    expect(find.text('Tournée des calendriers'), findsOneWidget);
  });

  testWidgets(
    'should open the component gallery when the app is a debug build',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home.gallery')));
      await tester.pumpAndSettle();

      expect(find.text('Composants'), findsOneWidget);
      expect(find.bySemanticsLabel('Numéro 3bis, personne'), findsOneWidget);
    },
  );

  testWidgets('should import a street of a commune and open it from the list', (
    tester,
  ) async {
    // A fresh folder: the app starts with no street.
    final storage = await Directory.systemTemp.createTemp('import_flow');
    addTearDown(() => storage.delete(recursive: true));
    await bootstrap(
      addressDirectory: _ban(),
      communeSearch: FakeCommuneSearch(
        answers: {
          'Villef': Ok([
            CommuneMatch(commune: _villefranche, postcodes: const ['69400']),
          ]),
        },
      ),
      storage: storage,
    );
    await tester.pumpAndSettle();
    expect(find.text("Aucune rue pour l'instant"), findsOneWidget);

    await tester.tap(find.byKey(const Key('start.import')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import.commune')), 'Villef');
    // The search waits for a pause in the typing.
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('import.suggestion.69264')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import.street.69264_1460')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importer 1 rue'));
    await tester.pumpAndSettle();

    expect(find.text('Mes rues · 1'), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);

    await tester.tap(find.text('Rue Pierre Morin'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Rue Pierre Morin'), findsOneWidget);
  });
}
