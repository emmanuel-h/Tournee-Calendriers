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
import '../test/ui/support/finders.dart';

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
  testWidgets(
    'should keep the marks across a restart when a house is marked, undone, '
    'marked again and another held to come back',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final storage = await Directory.systemTemp.createTemp('mark_flow');
      addTearDown(() => storage.delete(recursive: true));
      final communes = FakeCommuneSearch(
        answers: {
          'Villef': Ok([
            CommuneMatch(commune: _villefranche, postcodes: const ['69400']),
          ]),
        },
      );
      await bootstrap(
        addressDirectory: _ban(),
        communeSearch: communes,
        storage: storage,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start.import')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('import.commune')), 'Villef');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('import.suggestion.69264')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('import.street.69264_1460')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importer 1 rue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rue Pierre Morin'));
      await tester.pumpAndSettle();
      final tile = find.byKey(const ValueKey('street.tile.33'));
      expect(tester.getSemantics(tile).label, 'Numéro 33, à faire');

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(tile).label, 'Numéro 33, fait');
      expect(findArrowText('33 → Fait'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(tile).label, 'Numéro 33, à faire');

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(tile).label, 'Numéro 33, fait');

      // Hold 34: its sheet opens; « Repasser » is ticked, the sheet closed
      // by a tap on the dimmed street, and the tile shows ↻.
      final other = find.byKey(const ValueKey('street.tile.34'));
      await tester.longPress(other);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('house.comeBack')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(other).label, 'Numéro 34, à faire, repasser');
      // The phone storage writes its file just after the tap: let it land.
      await Future<void>.delayed(const Duration(seconds: 1));

      // Offline cold start: the whole app goes away (a fresh ProviderScope,
      // nothing kept in memory), then starts again on the same folder, with
      // a BAN and a commune search that know nothing: none is needed.
      runApp(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bootstrap(
        addressDirectory: FakeAddressDirectory(),
        communeSearch: FakeCommuneSearch(),
        storage: storage,
      );
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
      await tester.tap(find.text('Rue Pierre Morin'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const ValueKey('street.tile.33'))).label,
        'Numéro 33, fait',
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('street.tile.34'))).label,
        'Numéro 34, à faire, repasser',
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'should show the building partly done on its tile and the door renamed '
    'in its grid when a house is made a building, a door marked and renamed',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final storage = await Directory.systemTemp.createTemp('building_flow');
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
      await tester.tap(find.byKey(const Key('start.import')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('import.commune')), 'Villef');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('import.suggestion.69264')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('import.street.69264_1460')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importer 1 rue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rue Pierre Morin'));
      await tester.pumpAndSettle();

      // Hold 34, « Transformer en immeuble… », « Valider » the default
      // (one staircase, RdC–2e, two doors a floor): its grid opens.
      final tile = find.byKey(const ValueKey('street.tile.34'));
      await tester.longPress(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('house.toBuilding')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup.validate')));
      await tester.pumpAndSettle();
      final count = find.byKey(const Key('grid.count'));
      expect(tester.getSemantics(count).label, '0 sur 6 logements faits');

      await tester.tap(find.byKey(const ValueKey('grid.door.A0-01')));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(count).label, '1 sur 6 logements faits');

      Navigator.of(tester.element(count)).pop();
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(tile).label,
        'Numéro 34, immeuble, 1 sur 6 faits',
      );

      // ✏, tap 34, « Ajuster les portes », rename door 01 « Gauche »: the
      // grid shows it, still done.
      await tester.tap(find.byKey(const Key('street.edit')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('edit.tile.34')),
          matching: find.byKey(const Key('edit.tile.number')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('number.adjustDoors')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('doors.door.A0-01')),
          matching: find.byKey(const Key('doors.door.rename')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('renameDoor.field')),
        'Gauche',
      );
      await tester.tap(find.byKey(const Key('renameDoor.rename')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('doors.ok')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit.ok')));
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('grid.door.A0-Gauche')))
            .label,
        'RdC, porte Gauche, fait',
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'should show added numbers on both sides when a number is removed, '
    'brought back and 21-25 added in edit mode',
    (tester) async {
      final storage = await Directory.systemTemp.createTemp('edit_flow');
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
      await tester.tap(find.byKey(const Key('start.import')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('import.commune')), 'Villef');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('import.suggestion.69264')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('import.street.69264_1460')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importer 1 rue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rue Pierre Morin'));
      await tester.pumpAndSettle();

      // ✏, then ✕ on 33 and « Annuler »: 33 is back.
      await tester.tap(find.byKey(const Key('street.edit')));
      await tester.pumpAndSettle();
      final tile33 = find.byKey(const ValueKey('edit.tile.33'));
      await tester.tap(
        find.descendant(
          of: tile33,
          matching: find.byKey(const Key('edit.tile.remove')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tile33, findsNothing);
      expect(find.text('N° 33 supprimé'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(tile33, findsOneWidget);

      // « + numéros », 21-25, « Ajouter », « OK »: the street screen shows
      // 21, 23, 25 with the odd numbers and 22, 24 with the even ones.
      await tester.tap(find.byKey(const ValueKey('edit.addNumbers.odd')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('numbers.field')), '21-25');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('numbers.add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit.ok')));
      await tester.pumpAndSettle();

      double sideOf(String number) =>
          tester.getCenter(find.byKey(ValueKey('street.tile.$number'))).dx;
      for (final odd in ['21', '23', '25']) {
        expect(sideOf(odd), sideOf('33'), reason: odd);
      }
      for (final even in ['22', '24']) {
        expect(sideOf(even), sideOf('32'), reason: even);
      }
      expect(sideOf('33'), lessThan(sideOf('32')));
    },
  );
}
