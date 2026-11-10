// Instrumented suite: end-to-end flows run inside the real app on an Android
// emulator or phone (`flutter test integration_test -d <device>`).
//
// Unlike `test/`, these tests start the actual app with the real
// composition root, so they catch what unit and widget tests cannot: wiring,
// platform plugins, startup. The suite stays small on purpose (≤ 10 tests).
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/bootstrap/bootstrap.dart';
import 'package:tournee_calendriers/bootstrap/firebase.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/street_json_mapper.dart';
import 'package:tournee_calendriers/main.dart' as app;
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/map/sector_map.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/manual_street_screen.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../test/support/fakes/fake_address_directory.dart';
import '../test/support/fakes/fake_commune_search.dart';
import '../test/support/fakes/fake_street_shapes.dart';
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

/// A point on Rue Pierre Morin, where « Ajouter des rues » is tapped.
final _onMorin = _ok(GeoPoint.create(latitude: 45.98850, longitude: 4.72500));
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
  places: {
    _onMorin: Ok(
      StreetMatch(
        id: _morin,
        name: _ok(StreetName.create('Rue Pierre Morin')),
        commune: _villefranche,
        position: _onMorin,
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

/// A fresh storage folder for one test, deleted after it.
Future<Directory> _freshStorage(String name) async {
  final storage = await Directory.systemTemp.createTemp(name);
  addTearDown(() => storage.delete(recursive: true));
  return storage;
}

/// A fresh storage folder of a phone that already knows a secteur, none
/// open: the app opens on « Aucun secteur ouvert » (PLAN §5.0) rather than
/// on « Bienvenue ». Nothing of it needs the network.
Future<Directory> _knownPhone(String name) async {
  final storage = await _freshStorage(name);
  File('${storage.path}/my_tournees.json').writeAsStringSync(
    jsonEncode({
      'version': 1,
      'open': null,
      'tournees': [
        {
          'id': 't12',
          'number': 12,
          'centre': 'CS Villefranche',
          'campaign': 2026,
          'status': 'active',
        },
      ],
    }),
  );
  return storage;
}

/// A fresh storage folder of a phone where the 49 of the CS Villefranche
/// is open, as « Rejoindre » leaves it. Its id is new at each run: what the
/// test writes waits in Firestore's offline cache, which outlives the run,
/// and must not show in the next one. Nothing of it needs the network.
Future<Directory> _phoneInSector(String name) async {
  final storage = await _freshStorage(name);
  final id = 't49-${storage.path.split('/').last}';
  File('${storage.path}/my_tournees.json').writeAsStringSync(
    jsonEncode({
      'version': 1,
      'open': id,
      'tournees': [
        {
          'id': id,
          'number': 49,
          'centre': 'CS Villefranche',
          'campaign': 2026,
          'status': 'active',
        },
      ],
    }),
  );
  return storage;
}

/// The commune search the « Liste » tab needs, without the network: the
/// secteur was never read on this phone, so it has no commune and the tab
/// searches one (PLAN §5.4).
FakeCommuneSearch _communes() => FakeCommuneSearch(
  answers: {
    'Villef': Ok([
      CommuneMatch(commune: _villefranche, postcodes: const ['69400']),
    ]),
  },
);

/// Opens « Ajouter des rues » over Accueil by the route its row in Secteur
/// pushes (PLAN §5.14). Secteur shows the row once it has read the secteur
/// from Firestore, and these phones never did (Firestore is offline for the
/// whole suite): there Secteur says it cannot show the team. The row
/// itself is tested in `test/ui/screens/team_screen_test.dart` and in the
/// admin flow of `admin_test.dart`, which has the emulators.
Future<void> _openAddStreets(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(HomeScreen)))
      .push<void>(AppRoutes.addStreets)
      .ignore();
  // The map comes first, with MapLibre on the device: it may never settle.
  await tester.pump(const Duration(seconds: 2));
}

/// From Accueil, « Ajouter des rues », « Liste », Villefranche-sur-Saône,
/// then the street [banId] ticked and added (« Ajouter 1 rue »): back on
/// Accueil. All offline: the BAN and the commune search are fakes, and
/// Firestore queues the street.
Future<void> _addFromList(WidgetTester tester, BanStreetId banId) async {
  await _openAddStreets(tester);
  await tester.tap(find.byKey(const Key('addStreets.tab.list')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('import.commune')), 'Villef');
  // The search waits for a pause in the typing.
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(const ValueKey('import.suggestion.69264')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('import.street.${banId.value}')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajouter 1 rue'));
  await tester.pumpAndSettle();
}

/// On Accueil, opens the Rue Pierre Morin, just added, from its row: every
/// street of the secteur is in the one list (PLAN §5.14).
Future<void> _openMorin(WidgetTester tester) async {
  await tester.tap(find.text('Rue Pierre Morin'));
  await tester.pumpAndSettle();
}

void main() {
  // Connects the test to the device so results are reported back to
  // `flutter test`.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Firestore offline for the whole suite (the sign-in keeps the network):
  // the tournées the tests leave on the phone do not exist on the real
  // server, which would rightly make the app forget them (« La tournée 12
  // a été supprimée. »). Offline, the phone keeps them: what an offline
  // start must do (PLAN §7). The settings come first, as in the app.
  setUpAll(() async {
    await startFirebase();
    await offlineFirestore().disableNetwork();
  });
  tearDownAll(() => offlineFirestore().enableNetwork());

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
    'should open on « Aucun secteur ouvert » with none open, and open the '
    'component gallery when the app is a debug build',
    (tester) async {
      await bootstrap(storage: await _knownPhone('gallery'));
      await tester.pumpAndSettle();
      // No secteur open (#119): the map, « Aucun secteur ouvert » and the
      // way in, « Rejoindre un secteur »; no street of the phone's own.
      expect(find.byKey(const Key('noSector.map')), findsOneWidget);
      expect(find.text('Aucun secteur ouvert'), findsOneWidget);
      expect(find.byKey(const Key('noSector.join')), findsOneWidget);
      expect(find.byKey(const Key('home.sectorButton')), findsNothing);

      await tester.tap(find.byKey(const Key('home.gallery')));
      await tester.pumpAndSettle();

      expect(find.text('Composants'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Numéro 3bis, personne, changer le statut'),
        findsOneWidget,
      );
    },
  );

  testWidgets('should add a street of a commune to the secteur from the list '
      'and open it from Accueil', (tester) async {
    await bootstrap(
      addressDirectory: _ban(),
      communeSearch: _communes(),
      storage: await _phoneInSector('import_flow'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Aucune rue dans le secteur pour l'instant."),
      findsOneWidget,
    );

    await _addFromList(tester, _morin);

    expect(find.text('1 rue ajoutée au secteur'), findsOneWidget);
    expect(find.text('Rues · 0/3'), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);

    await _openMorin(tester);

    expect(find.widgetWithText(AppBar, 'Rue Pierre Morin'), findsOneWidget);
  });
  testWidgets(
    'should keep the marks across a restart when a tournée is started from '
    'the street, a house is marked in its picker, undone, marked again and '
    'another to come back tomorrow at 18 h, then found nobody home twice',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final storage = await _phoneInSector('mark_flow');
      await bootstrap(
        addressDirectory: _ban(),
        communeSearch: _communes(),
        storage: storage,
      );
      await tester.pumpAndSettle();
      await _addFromList(tester, _morin);
      await _openMorin(tester);
      // A tap on a house opens its status picker (PLAN §5.6); one tap on a
      // status stores it and closes, with « Annuler » in the snackbar.
      Future<void> mark(Finder tile, String status) async {
        await tester.tap(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('house.status.$status')));
        await tester.pumpAndSettle();
      }

      // « Fait » asks for the don of the tournée: a calendar offered.
      Future<void> markDone(Finder tile) async {
        await mark(tile, 'done');
        await tester.tap(find.byKey(const ValueKey('house.freeCalendar')));
        await tester.pumpAndSettle();
      }

      final tile = find.byKey(const ValueKey('street.tile.33'));
      expect(
        tester.getSemantics(tile).label,
        'Numéro 33, à faire, changer le statut',
      );

      // No tournée yet: a tap opens no picker but offers to start one
      // (PLAN §5.14); « Commencer » starts it, offline, on the street.
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('house.number')), findsNothing);
      expect(
        find.text('Commencez une tournée pour marquer les maisons.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(SnackBarAction, 'Commencer'));
      await tester.pumpAndSettle();
      // The « En tournée » band above the street's top bar (PLAN §5.14).
      expect(find.byKey(const Key('round.band')), findsOneWidget);

      await markDone(tile);
      expect(
        tester.getSemantics(tile).label,
        'Numéro 33, fait, changer le statut',
      );
      expect(findArrowText('N° 33 fait · calendrier offert'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(tile).label,
        'Numéro 33, à faire, changer le statut',
      );

      await markDone(tile);
      expect(
        tester.getSemantics(tile).label,
        'Numéro 33, fait, changer le statut',
      );

      // 34 « Repasser »: the picker then asks when (#81), « Demain » and
      // « 18 h »; « Valider » closes it and the tile shows ↻.
      final other = find.byKey(const ValueKey('street.tile.34'));
      await mark(other, 'comeBack');
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      String two(int value) => '$value'.padLeft(2, '0');
      await tester.tap(
        find.byKey(
          ValueKey(
            'house.comeBackDay.${tomorrow.year}-${two(tomorrow.month)}-'
            '${two(tomorrow.day)}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('house.comeBackHour')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18 h').last);
      await tester.pumpAndSettle();
      final summary = find.byKey(const Key('house.comeBackSummary'));
      expect(tester.widget<Text>(summary).data, 'Demain vers 18 h');
      await tester.tap(find.byKey(const Key('house.validate')));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(other).label,
        'Numéro 34, repasser, changer le statut',
      );
      // Firestore keeps the marks in its cache just after the tap: let them
      // land.
      await Future<void>.delayed(const Duration(seconds: 1));

      // Offline cold start: the whole app goes away (a fresh ProviderScope,
      // nothing kept in memory), then starts again on the same folder, with
      // a BAN and a commune search that know nothing: none is needed. The
      // secteur's streets come from Firestore's copy on the phone.
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
        'Numéro 33, fait, changer le statut',
      );
      final comingBack = find.byKey(const ValueKey('street.tile.34'));
      expect(
        tester.getSemantics(comingBack).label,
        'Numéro 34, repasser, changer le statut',
      );
      // « Repasser » again opens its day, as it was left.
      await mark(comingBack, 'comeBack');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('house.comeBackSummary')))
            .data,
        'Demain vers 18 h',
      );
      await tester.tap(find.byKey(const Key('house.close')));
      await tester.pumpAndSettle();

      // Came back, nobody (#80): « Personne » is its first try; the next
      // time it reads « De nouveau personne », its second try.
      await mark(comingBack, 'nobodyHome');
      expect(findArrowText('N° 34\u00a0: personne'), findsOneWidget);
      await tester.tap(comingBack);
      await tester.pumpAndSettle();
      expect(find.text('1 passage sans personne'), findsOneWidget);
      expect(find.text('De nouveau personne'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('house.status.nobodyHome')));
      await tester.pumpAndSettle();
      expect(
        findArrowText('N° 34\u00a0: personne (2e passage)'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(comingBack).label,
        'Numéro 34, personne, 2e passage, changer le statut',
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'should show the building partly done on its tile and the door renamed '
    'in its grid when a house is made a building, a door marked and renamed, '
    'and staircase B made smaller',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await bootstrap(
        addressDirectory: _ban(),
        communeSearch: _communes(),
        storage: await _phoneInSector('building_flow'),
      );
      await tester.pumpAndSettle();
      await _addFromList(tester, _morin);
      // Doors are marked only during a tournée (PLAN §5.14).
      await tester.tap(find.byKey(const Key('round.start')));
      await tester.pumpAndSettle();
      await _openMorin(tester);

      // ✏, tap 34, « Transformer en immeuble… », « Valider » the default
      // (one staircase, RdC–2e, two doors a floor): back in edit mode.
      final tile = find.byKey(const ValueKey('street.tile.34'));
      await tester.tap(find.byKey(const Key('street.edit')));
      await tester.pumpAndSettle();
      Future<void> tapNumber() async {
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('edit.tile.34')),
            matching: find.byKey(const Key('edit.tile.number')),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tapNumber();
      await tester.tap(find.byKey(const Key('number.toBuilding')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup.validate')));
      await tester.pumpAndSettle();

      // Tap 34 again, « Ouvrir l'immeuble »: its grid, where door 01 is
      // marked done in its picker, a calendar offered.
      await tapNumber();
      await tester.tap(find.byKey(const Key('number.openBuilding')));
      await tester.pumpAndSettle();
      final count = find.byKey(const Key('grid.count'));
      expect(tester.getSemantics(count).label, '0 sur 6 logements faits');
      await tester.tap(find.byKey(const ValueKey('grid.door.A0-01')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('door.status.done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('door.freeCalendar')));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(count).label, '1 sur 6 logements faits');
      expect(
        findArrowText('Porte 01\u00a0: fait · calendrier offert'),
        findsOneWidget,
      );

      // « Gérer l'immeuble », « Modifier les étages »: a staircase more,
      // the box unticked, B down to the RdC alone. The grid has « Esc. B ·
      // 0/2 »; A keeps its door 01, done.
      Future<void> manage(String action) async {
        await tester.tap(find.byKey(const Key('grid.manage')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('buildingMenu.$action')));
        await tester.pumpAndSettle();
      }

      await manage('editFloors');
      await tester.tap(find.byKey(const ValueKey('setup.staircases.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup.sameForEach')));
      await tester.pumpAndSettle();
      final fewerB = find.byKey(const ValueKey('setup.B.floors.fewer'));
      await tester.ensureVisible(fewerB);
      await tester.pumpAndSettle();
      await tester.tap(fewerB);
      await tester.pumpAndSettle();
      await tester.tap(fewerB);
      await tester.pumpAndSettle();
      final validate = find.byKey(const Key('setup.validate'));
      await tester.ensureVisible(validate);
      await tester.pumpAndSettle();
      await tester.tap(validate);
      await tester.pumpAndSettle();
      expect(find.text('Esc. B · 0/2'), findsOneWidget);
      expect(tester.getSemantics(count).label, '1 sur 8 logements faits');

      // « Gérer l'immeuble », « Modifier les portes », rename door 01
      // « Gauche » (with « Annuler » offered): back on the grid, it is
      // still done.
      await manage('adjustDoors');
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
      expect(findArrowText('Porte 01 → Gauche'), findsOneWidget);
      await tester.tap(find.byKey(const Key('doors.ok')));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('grid.door.A0-Gauche')))
            .label,
        'Escalier A, RdC, porte Gauche, fait',
      );

      // Closed with its ✕, the grid leaves the edit mode; « OK » the street, where
      // the tile counts every door.
      await tester.tap(find.byKey(const Key('grid.close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit.ok')));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(tile).label,
        'Numéro 34, immeuble, 1 sur 8 faits, ouvrir',
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'should show added numbers on both sides when a number is removed, '
    'brought back and 21-25 added in edit mode, and bring the street back '
    'with its mark when it is deleted and added again',
    (tester) async {
      await bootstrap(
        addressDirectory: _ban(),
        communeSearch: _communes(),
        storage: await _phoneInSector('edit_flow'),
      );
      await tester.pumpAndSettle();
      await _addFromList(tester, _morin);
      // A tournée for the mark of 33 below (PLAN §5.14); editing the street
      // needs none.
      await tester.tap(find.byKey(const Key('round.start')));
      await tester.pumpAndSettle();
      await _openMorin(tester);

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

      // 33 marked, then ✏ « Supprimer la rue »: the secteur has no street.
      await tester.tap(find.byKey(const ValueKey('street.tile.33')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('house.status.done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('house.freeCalendar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('street.edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit.deleteStreet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit.confirmDelete.ok')));
      await tester.pumpAndSettle();
      expect(
        find.text("Aucune rue dans le secteur pour l'instant."),
        findsOneWidget,
      );

      // Added again from « dans la Corbeille »: back with 33 done.
      await _openAddStreets(tester);
      await tester.tap(find.byKey(const Key('addStreets.tab.list')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('import.commune')), 'Villef');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('import.suggestion.69264')));
      await tester.pumpAndSettle();
      final morin = find.byKey(const ValueKey('import.street.69264_1460'));
      expect(
        find.descendant(of: morin, matching: find.text('dans la Corbeille')),
        findsOneWidget,
      );
      await tester.tap(morin);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter 1 rue'));
      await tester.pumpAndSettle();
      expect(find.text('1 rue restaurée'), findsOneWidget);
      // Back on Accueil, the street came back with its mark.
      expect(find.text('Rues · 1/8'), findsOneWidget);
    },
  );

  testWidgets(
    'should stamp changes with the Firebase uid, the same after a restart',
    (tester) async {
      final storage = await _freshStorage('identity_flow');
      ProviderContainer app() =>
          ProviderScope.containerOf(tester.element(find.byType(TourneeApp)));
      MemberId member() => app().read(identityProvider).currentMember;

      await bootstrap(storage: storage);
      await tester.pumpAndSettle();
      // The first sign-in runs in the background and needs the network
      // (the emulator has it): wait for it, at most 10 s.
      for (
        var i = 0;
        i < 100 && FirebaseAuth.instance.currentUser == null;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      expect(uid, isNotNull, reason: 'the anonymous sign-in did not finish');
      expect(FirebaseAuth.instance.currentUser!.isAnonymous, isTrue);
      expect(member(), MemberId(uid!));
      // « Créer » / « Rejoindre » get the same account, without waiting.
      expect(app().read(memberAccountProvider).signedInMember, member());

      // A restart reads the session Firebase kept on the phone.
      runApp(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bootstrap(storage: storage);
      await tester.pumpAndSettle();

      expect(member(), MemberId(uid));
    },
  );

  testWidgets(
    'should reopen the last tournée at launch, count a tournée\'s don and '
    'validate it, and switch from the title',
    (tester) async {
      final storage = await _freshStorage('sectors_flow');
      // The 49's id is new at each run: the street typed in by hand below
      // waits in Firestore's offline cache, which outlives the run, and
      // must not show in the next one.
      final t49 = 't49-${storage.path.split('/').last}';
      // What « Créer » and « Rejoindre » will leave on the phone: two
      // tournées of the CS Villefranche, the 49 open. Nothing of it needs
      // the network.
      Map<String, Object?> sector(String id, int number) => {
        'id': id,
        'number': number,
        'centre': 'CS Villefranche',
        'campaign': 2026,
        'status': 'active',
      };
      File('${storage.path}/my_tournees.json').writeAsStringSync(
        jsonEncode({
          'version': 1,
          'open': t49,
          'tournees': [sector(t49, 49), sector('t12', 12)],
        }),
      );
      // The commune of the street typed in by hand, found without network.
      final communes = FakeCommuneSearch(
        answers: {
          'Villef': Ok([
            CommuneMatch(commune: _villefranche, postcodes: const ['69400']),
          ]),
        },
      );

      await bootstrap(
        storage: storage,
        communeSearch: communes,
        addressDirectory: _ban(),
        // The map's roads in the zone drawn below (#125), offline.
        streetShapes: FakeStreetShapes()
          ..roads = Ok([
            NamedRoad(
              name: 'Rue Pierre Morin',
              shape: StreetShape([
                [
                  _ok(GeoPoint.create(latitude: 45.9883, longitude: 4.7245)),
                  _onMorin,
                ],
              ]),
            ),
          ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Secteur 49 · 2026'), findsOneWidget);
      expect(find.text('CS Villefranche'), findsOneWidget);

      // Accueil (#30), offline: the map of the tournée under the legend,
      // and the « Rues » panel. The secteur was never read, so it has
      // no street; a tap on the handle shows the whole list, another
      // brings the map back.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('home.map')), findsOneWidget);
      expect(find.byKey(const Key('map.legend')), findsOneWidget);
      expect(find.text('Rues · 0/0'), findsOneWidget);
      expect(
        find.text("Aucune rue dans le secteur pour l'instant."),
        findsOneWidget,
      );
      final panel = find.byKey(const Key('home.panel'));
      final atRest = tester.getSize(panel).height;
      await tester.tap(find.byKey(const Key('home.panel.handle')));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, greaterThan(atRest));
      await tester.tap(find.byKey(const Key('home.panel.handle')));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, atRest);

      // The Secteur button (a folded map, PLAN §5.14) opens Secteur, which
      // follows the secteur in Firestore (the first use of the real
      // database, with its offline settings), offline: the phone never read
      // it, so Secteur says it cannot show it, or is still waiting; either
      // way nothing breaks, and the phone keeps both secteurs. Accueil has
      // no « Ajouter des rues » row any more.
      expect(find.text('Ajouter des rues'), findsNothing);
      await tester.tap(find.byKey(const Key('home.sectorButton')));
      await tester.pumpAndSettle();
      expect(find.byType(TeamScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      // « Ajouter des rues » (#78, #124): « Carte | Liste », offline. The
      // map comes first, on France with MapLibre on the device: the
      // secteur was never read, so it has no commune. The selection sheet
      // says what to do.
      await _openAddStreets(tester);
      expect(find.byType(AddStreetsScreen), findsOneWidget);
      expect(find.byKey(const Key('addStreets.map')), findsOneWidget);
      expect(
        find.text('Touchez les rues à ajouter ou tracez une zone.'),
        findsOneWidget,
      );

      // A road tapped (#124) is ticked, on the real MapLibre map: its ✓
      // and, once known, its road are sent to the map. The tap is handed
      // to the map's callback: a test's tap does not reach the native view
      // (only real touches do, with `shouldPropagateDevicePointerEvents`).
      // The BAN and the map's roads are fakes, so no network is needed;
      // the fake map has no road for it. « Tout décocher » empties the
      // sheet again.
      tester.widget<SectorMap>(find.byType(SectorMap).last).onMapTapped!(
        _onMorin,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('1 rue sélectionnée'), findsOneWidget);
      expect(
        tester.widget<SectorMap>(find.byType(SectorMap).last).pickedRoads,
        hasLength(1),
      );
      await tester.tap(find.byKey(const Key('addStreets.untickAll')));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Touchez les rues à ajouter ou tracez une zone.'),
        findsOneWidget,
      );

      // « Rue absente de la carte ? Saisir à la main », at the bottom of
      // the sheet, works offline (#31): the commune is searched (here
      // without network), the street joins the secteur.
      await tester.tap(find.byKey(const Key('addStreets.manual')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('communes.field')), 'Villef');
      // The search waits for a pause in the typing.
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('communes.suggestion.69264')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('manual.name')),
        'Chemin des Vignes',
      );
      await tester.enterText(find.byKey(const Key('manual.from')), '1');
      await tester.enterText(find.byKey(const Key('manual.to')), '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1, 2, 3, 4, 5'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ManualStreetScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('manual.add')));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AddStreetsScreen), findsOneWidget);

      // « Zone » (#125), on the real MapLibre map: the drag is handed to
      // the map's callback, as the tap above. The secteur has a street of
      // Villefranche-sur-Saône now, so the road of the zone is matched in
      // its commune, ticked, and the zone sent to the map. « Zone » off
      // keeps the tick; « Tout décocher » drops it.
      await tester.tap(find.byKey(const Key('addStreets.zone')));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<SectorMap>(find.byType(SectorMap).last).zoneMode,
        isTrue,
      );
      final zone = GeoBounds.of(
        south: 45.9870,
        west: 4.7230,
        north: 45.9900,
        east: 4.7270,
      )!;
      tester.widget<SectorMap>(find.byType(SectorMap).last).onZoneDrawn!(
        zone,
        16,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('1 rue dans la zone'), findsOneWidget);
      expect(find.text('Ajouter 1 rue'), findsOneWidget);
      expect(tester.widget<SectorMap>(find.byType(SectorMap).last).zone, zone);
      await tester.tap(find.byKey(const Key('addStreets.zone')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1 rue sélectionnée'), findsOneWidget);
      await tester.tap(find.byKey(const Key('addStreets.untickAll')));
      await tester.pump(const Duration(seconds: 1));

      // The list still searches a commune: the tournée has none.
      await tester.tap(find.byKey(const Key('addStreets.tab.list')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import.commune')), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Rues · 0/5'), findsOneWidget);
      expect(find.text('Chemin des Vignes'), findsOneWidget);

      // Killed in the middle of a new street's writes (#104): the street
      // was kept on the phone before them, and none reached Firestore. At
      // the next start, offline, it is written again whole, then
      // forgotten from the phone storage.
      final ecoles = _ok(
        Street.create(
          id: StreetId('ecoles-${storage.path.split('/').last}'),
          name: 'Rue des Écoles',
          commune: _villefranche,
          houses: [
            for (final number in [1, 2, 3])
              House(number: _ok(HouseNumber.create(number))),
          ],
        ),
      );
      final unfinished = Directory(
        '${storage.path}/unfinished_streets/${Uri.encodeComponent(t49)}/2026',
      )..createSync(recursive: true);
      File('${unfinished.path}/${Uri.encodeComponent(ecoles.id.value)}.json')
          .writeAsStringSync(jsonEncode(streetToJson(ecoles)));
      runApp(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bootstrap(storage: storage, communeSearch: communes);
      await tester.pumpAndSettle();
      // The forget is written just after the last write: let it land.
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('home.panel.handle')));
      await tester.pumpAndSettle();
      // Its 3 houses count with the 5 of Chemin des Vignes.
      expect(find.text('Rues · 0/8'), findsOneWidget);
      expect(
        find.byKey(ValueKey('home.street.${ecoles.id.value}')),
        findsOneWidget,
      );
      expect(unfinished.listSync(), isEmpty);
      await tester.tap(find.byKey(const Key('home.panel.handle')));
      await tester.pumpAndSettle();

      // A tournée (#109), offline: « Commencer une tournée », « Fait » on
      // the 1 with 10 € in cash, « Terminer », « Valider »: Accueil offers
      // a new one, and the summary waits on the phone for the secteur.
      await tester.tap(find.byKey(const Key('round.start')));
      await tester.pumpAndSettle();
      // The band takes the top bar's place: no ⚙ until the tournée ends.
      expect(find.text("En tournée · moins d'une minute"), findsOneWidget);
      expect(find.byKey(const Key('home.settings')), findsNothing);
      await tester.tap(find.text('Chemin des Vignes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('street.tile.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('house.status.done')));
      await tester.pumpAndSettle();
      expect(find.text('Montant du don'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('house.give.1000')));
      await tester.pumpAndSettle();
      expect(findArrowText('N° 1 fait · 10\u00a0€ en espèces'), findsOneWidget);
      expect(find.text('1\u00a0don · 10\u00a0€ ›'), findsOneWidget);
      // A second calendar for the 1 (#114): « + Ajouter un don », offered;
      // the tile shows its badge « 2 », and « − » takes it away again.
      await tester.tap(find.byKey(const ValueKey('street.tile.1')));
      await tester.pumpAndSettle();
      expect(find.text('1 calendrier'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('house.addDonation')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('house.freeCalendar')));
      await tester.pumpAndSettle();
      expect(findArrowText('N° 1 · calendrier offert ajouté'), findsOneWidget);
      final badge = find.descendant(
        of: find.byKey(const ValueKey('street.tile.1')),
        matching: find.byKey(const Key('tile.calendars')),
      );
      expect(find.descendant(of: badge, matching: find.text('2')), findsOne);
      await tester.tap(find.byKey(const ValueKey('street.tile.1')));
      await tester.pumpAndSettle();
      expect(find.text('2 calendriers'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('house.removeCalendar')));
      await tester.pumpAndSettle();
      expect(find.text('1 calendrier'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('house.close')));
      await tester.pumpAndSettle();
      expect(badge, findsNothing);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('round.finish')));
      await tester.pumpAndSettle();
      expect(find.text('Bilan de la tournée'), findsOneWidget);
      expect(find.text('maison visitée'), findsOneWidget);
      expect(find.text('10\u00a0€'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('recap.validate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recap.confirm.ok')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('round.start')), findsOneWidget);
      expect(find.byKey(const Key('round.band')), findsNothing);
      expect(find.byKey(const Key('home.settings')), findsOneWidget);
      // The summary is in Firestore's offline queue, and its copy shows it
      // at once (#110): what « Collecte » reads, offline too.
      final phone = ProviderScope.containerOf(
        tester.element(find.byType(TourneeApp)),
      );
      final validated = await phone
          .read(roundLedgerProvider)
          .watch(SectorId(t49), _ok(CampaignYear.create(2026)))
          .first;
      expect(validated, hasLength(1));
      expect(validated.single.housesVisited, 1);
      expect(
        validated.single.totals,
        DonationTotals(
          cash: MethodTotal(count: 1, cents: 1000),
          cheque: MethodTotal.none,
          card: MethodTotal.none,
          // The calendar given with « + Ajouter un don »: « − » only took
          // the house's calendar back, never a don.
          free: 1,
        ),
      );

      // « Collecte 2026 » (#111) reads that copy, offline. Secteur, which
      // leads there, cannot show the 49 (never read on this phone), so the
      // screen is opened by its route.
      GoRouter.of(tester.element(find.byType(HomeScreen)))
          .push<void>(AppRoutes.collecte)
          .ignore();
      await tester.pumpAndSettle();
      expect(find.text('Collecte 2026'), findsOneWidget);
      expect(find.text('Secteur 49 · tournées validées'), findsOneWidget);
      expect(find.text('TOTAL DE LA TOURNÉE'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('collecte.total')),
          matching: find.text('10\u00a0€'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      // « Mes secteurs » offline (#33): the 12 was never downloaded on
      // this phone, so it is greyed and a tap leaves the sheet open. Once
      // it counts as downloaded, it opens as before. Firestore's network
      // is off for the whole suite, so « offline » is certain here.
      await tester.tap(find.byKey(const Key('home.sector')));
      await tester.pumpAndSettle();
      expect(
        find.text('CS Villefranche · Disponible avec réseau'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('mySectors.t12')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mySectors.t12')), findsOneWidget);
      await phone
          .read(sectorDownloadsProvider)
          .save(
            SectorDownload(
              sector: SectorId('t12'),
              downloadedAt: DateTime.utc(2026, 11, 2, 8, 12),
              mapBytes: 0,
              area: null,
            ),
          );
      await tester.pumpAndSettle();
      expect(find.textContaining('Disponible avec réseau'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mySectors.t12')));
      await tester.pumpAndSettle();
      expect(find.text('Secteur 12 · 2026'), findsOneWidget);

      // A restart opens the tournée chosen last.
      runApp(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bootstrap(storage: storage);
      await tester.pumpAndSettle();

      expect(find.text('Secteur 12 · 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'should open « Bienvenue » on a new phone, keep its buttons disabled '
    'until a name is typed, and keep the name',
    (tester) async {
      final storage = await _freshStorage('welcome_flow');
      Finder button(String key) => find.byKey(Key(key));
      bool enabled(String key) => tester
          .widget<ButtonStyleButton>(
            find.descendant(
              of: button(key),
              matching: find.bySubtype<ButtonStyleButton>(),
            ),
          )
          .enabled;

      await bootstrap(storage: storage);
      await tester.pumpAndSettle();
      expect(find.text('Visible par votre équipe.'), findsOneWidget);
      // « Créer un secteur » shows only on an admin's phone (PLAN §5.12),
      // which depends on the real project: only « Rejoindre » is checked.
      expect(enabled('welcome.join'), isFalse);

      await tester.enterText(find.byKey(const Key('welcome.name')), 'Léa');
      // « OK » on the keyboard, which then leaves the buttons in sight.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(enabled('welcome.join'), isTrue);

      // « Rejoindre » asks the server nothing until a code is typed: no
      // request reaches the real project.
      await tester.ensureVisible(button('welcome.join'));
      await tester.pumpAndSettle();
      await tester.tap(button('welcome.join'));
      await tester.pumpAndSettle();
      expect(find.text('Rejoindre un secteur'), findsOneWidget);
      expect(find.byKey(const Key('join.first')), findsOneWidget);
      // The settings file is written just after the tap: let it land.
      await Future<void>.delayed(const Duration(seconds: 1));

      // A restart: still nothing but a name, so « Bienvenue » again, with
      // the name kept.
      runApp(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bootstrap(storage: storage);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Léa'), findsOneWidget);
      expect(enabled('welcome.join'), isTrue);
    },
  );
}
