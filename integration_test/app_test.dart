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
import 'package:integration_test/integration_test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/bootstrap/bootstrap.dart';
import 'package:tournee_calendriers/bootstrap/firebase.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/main.dart' as app;
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/manual_street_screen.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

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

/// A fresh storage folder for one test, deleted after it.
Future<Directory> _freshStorage(String name) async {
  final storage = await Directory.systemTemp.createTemp(name);
  addTearDown(() => storage.delete(recursive: true));
  return storage;
}

/// A fresh storage folder of a phone that already knows a tournée, none of
/// them open: the app opens on « Mes rues » and the phone's own streets, as
/// on a phone of M1, rather than on « Bienvenue ». Nothing of it needs the
/// network.
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
    'should open the component gallery when the app is a debug build',
    (tester) async {
      await bootstrap(storage: await _knownPhone('gallery'));
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
    final storage = await _knownPhone('import_flow');
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
    'marked again and another tapped to come back tomorrow at 18 h, then '
    'found nobody home twice',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final storage = await _knownPhone('mark_flow');
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

      // Tap 34 three times (✓, ✗, ↻): the third opens its sheet by itself
      // (#81), where « Demain » and « 18 h » say when to come back; « OK »
      // closes it and the tile shows ↻.
      final other = find.byKey(const ValueKey('street.tile.34'));
      for (var tap = 0; tap < 3; tap++) {
        await tester.tap(other);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('house.ok')), findsOneWidget);
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
      await tester.tap(find.byKey(const Key('house.ok')));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(other).label, 'Numéro 34, repasser');
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
      final comingBack = find.byKey(const ValueKey('street.tile.34'));
      expect(tester.getSemantics(comingBack).label, 'Numéro 34, repasser');
      await tester.longPress(comingBack);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('house.comeBackSummary')))
            .data,
        'Demain vers 18 h',
      );

      // Came back, still nobody (#80): « personne », its second try (the ✗
      // of the taps was the first). Then 32, found nobody home by taps (✓,
      // ✗: its first try), held: once more, its second, which the tile now
      // says.
      await tester.tap(find.byKey(const Key('house.nobodyHomeAgain')));
      await tester.pumpAndSettle();
      expect(findArrowText('34 → Personne (2e passage)'), findsOneWidget);
      expect(
        tester.getSemantics(comingBack).label,
        'Numéro 34, personne, 2e passage',
      );
      final twice = find.byKey(const ValueKey('street.tile.32'));
      await tester.tap(twice);
      await tester.pumpAndSettle();
      await tester.tap(twice);
      await tester.pumpAndSettle();
      await tester.longPress(twice);
      await tester.pumpAndSettle();
      expect(find.text('1 passage sans personne'), findsOneWidget);
      await tester.tap(find.byKey(const Key('house.nobodyHomeAgain')));
      await tester.pumpAndSettle();
      expect(findArrowText('32 → Personne (2e passage)'), findsOneWidget);
      expect(
        tester.getSemantics(twice).label,
        'Numéro 32, personne, 2e passage',
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
      final storage = await _knownPhone('building_flow');
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

      await tester.tap(find.byKey(const Key('grid.close')));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(tile).label,
        'Numéro 34, immeuble, 1 sur 6 faits, ouvrir',
      );

      // ✏, tap 34, « Ouvrir l'immeuble »: its grid. « Gérer l'immeuble »,
      // « Modifier les étages »: a staircase more, the box unticked, B down
      // to the RdC alone. The grid has « Esc. B · 0/2 »; A keeps its door
      // 01, done.
      await tester.tap(find.byKey(const Key('street.edit')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('edit.tile.34')),
          matching: find.byKey(const Key('edit.tile.number')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('number.openBuilding')));
      await tester.pumpAndSettle();
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
    'with its mark when it is deleted and imported again',
    (tester) async {
      final storage = await _knownPhone('edit_flow');
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

      // 33 marked, then ✏ « Supprimer la rue »: « Mes rues » is empty.
      await tester.tap(find.byKey(const ValueKey('street.tile.33')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('street.edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit.deleteStreet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit.confirmDelete.ok')));
      await tester.pumpAndSettle();
      expect(find.text("Aucune rue pour l'instant"), findsOneWidget);

      // Imported again from « dans la Corbeille »: back with 33 done.
      await tester.tap(find.byKey(const Key('start.import')));
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
      await tester.tap(find.text('Importer 1 rue'));
      await tester.pumpAndSettle();
      expect(find.text('1 rue restaurée'), findsOneWidget);
      expect(find.text('1/8'), findsOneWidget);
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
    'should reopen the last tournée at launch and switch from the title',
    (tester) async {
      final storage = await _freshStorage('tournees_flow');
      // The 49's id is new at each run: the street typed in by hand below
      // waits in Firestore's offline cache, which outlives the run, and
      // must not show in the next one.
      final t49 = 't49-${storage.path.split('/').last}';
      // What « Créer » and « Rejoindre » will leave on the phone: two
      // tournées of the CS Villefranche, the 49 open. Nothing of it needs
      // the network.
      Map<String, Object?> tournee(String id, int number) => {
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
          'tournees': [tournee(t49, 49), tournee('t12', 12)],
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

      await bootstrap(storage: storage, communeSearch: communes);
      await tester.pumpAndSettle();
      expect(find.text('Tournée 49 · 2026'), findsOneWidget);
      expect(find.text('CS Villefranche'), findsOneWidget);

      // Accueil (#30), offline: the map of the tournée under the legend,
      // and the « Mes rues » panel. The tournée was never read, so it has
      // no street; a tap on the handle shows the whole list, another
      // brings the map back.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('home.map')), findsOneWidget);
      expect(find.byKey(const Key('map.legend')), findsOneWidget);
      expect(find.text('Mes rues · 0/0'), findsOneWidget);
      expect(
        find.text("Aucune rue dans la tournée pour l'instant."),
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

      // 👥 opens Équipe, which follows the tournée in Firestore (the first
      // use of the real database, with its offline settings), offline: the
      // phone never read it, so Équipe says it cannot show it, or is still
      // waiting; either way nothing breaks, and the phone keeps both
      // tournées.
      await tester.tap(find.byKey(const Key('home.team')));
      await tester.pumpAndSettle();
      expect(find.byType(TeamScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      // « Ajouter des rues » (#78, #31): « Carte | Liste », offline. The
      // map comes first, on France with MapLibre on the device: the
      // tournée was never read, so it has no commune.
      await tester.tap(find.byKey(const Key('start.import')));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AddStreetsScreen), findsOneWidget);
      expect(find.byKey(const Key('addStreets.map')), findsOneWidget);

      // « Saisir une rue à la main » works offline (#31): the commune is
      // searched (here without network), the street joins « Mes rues ».
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

      // The list still searches a commune: the tournée has none.
      await tester.tap(find.byKey(const Key('addStreets.tab.list')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import.commune')), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Mes rues · 0/5'), findsOneWidget);
      expect(find.text('Chemin des Vignes'), findsOneWidget);

      // « Mes tournées » offline (#33): the 12 was never downloaded on
      // this phone, so it is greyed and a tap leaves the sheet open. Once
      // it counts as downloaded, it opens as before. Firestore's network
      // is off for the whole suite, so « offline » is certain here.
      await tester.tap(find.byKey(const Key('home.tournee')));
      await tester.pumpAndSettle();
      expect(
        find.text('CS Villefranche · Disponible avec réseau'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('myTournees.t12')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('myTournees.t12')), findsOneWidget);
      final phone = ProviderScope.containerOf(
        tester.element(find.byType(TourneeApp)),
      );
      await phone
          .read(tourneeDownloadsProvider)
          .save(
            TourneeDownload(
              tournee: TourneeId('t12'),
              downloadedAt: DateTime.utc(2026, 11, 2, 8, 12),
              mapBytes: 0,
              area: null,
            ),
          );
      await tester.pumpAndSettle();
      expect(find.textContaining('Disponible avec réseau'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('myTournees.t12')));
      await tester.pumpAndSettle();
      expect(find.text('Tournée 12 · 2026'), findsOneWidget);

      // A restart opens the tournée chosen last.
      runApp(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bootstrap(storage: storage);
      await tester.pumpAndSettle();

      expect(find.text('Tournée 12 · 2026'), findsOneWidget);
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
      // « Créer une tournée » shows only on an admin's phone (PLAN §5.12),
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
      expect(find.text('Rejoindre une tournée'), findsOneWidget);
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
