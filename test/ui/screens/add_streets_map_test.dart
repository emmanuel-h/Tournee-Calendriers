// The « Carte » tab of « Ajouter des rues » (PLAN §5.14, Pick mockup):
// streets ticked on the map, the selection sheet, adding them at once, what
// a tap says in a snackbar, the search and « Saisir une rue à la main ».
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/street_shapes.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/picked_road.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/manual_street_screen.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' hide lea;
import '../support/app_overrides.dart';
import '../support/fake_map_view.dart';
import '../support/large_text.dart';
import '../support/navigation.dart';

final _bordelanId = BanStreetId('69264_0246');
final _gareId = BanStreetId('69264_0800');
final _brokenId = BanStreetId('69264_9999');

/// Where the finger taps on Petit Chemin de Bordelan, not in the secteur.
final _onBordelan = at(45.98850, 4.72500);

/// Where the finger taps on Rue de la Gare, not in the secteur either.
final _onGare = at(45.98700, 4.72000);

/// Where the finger taps on Rue Brisée, whose numbers the BAN gives twice.
final _onBroken = at(45.98600, 4.71900);

/// Where the finger taps on two more streets to add, Rue Victor Hugo and
/// Rue Paul Bert.
final _moreStreets = [at(45.98300, 4.71600), at(45.98200, 4.71500)];
final _hugoId = BanStreetId('69264_1100');
final _bertId = BanStreetId('69264_1300');

/// Where the finger taps on a street whose numbers the BAN fails to give.
final _onFailing = at(45.98400, 4.71700);
final _failingId = BanStreetId('69264_0900');

/// Where the finger taps on Rue des Lilas, in the secteur.
final _onLilas = at(45.98950, 4.71800);

/// Where the BAN cannot be reached, and where it knows no street.
final _offline = at(45.99000, 4.72000);
final _nowhere = at(45.99500, 4.73000);

final _bordelanMatch = StreetMatch(
  id: _bordelanId,
  name: streetName('Petit Chemin de Bordelan'),
  commune: villefranche,
  position: _onBordelan,
);

StreetMatch _matchOf(BanStreetId id, String name, GeoPoint position) =>
    StreetMatch(
      id: id,
      name: streetName(name),
      commune: villefranche,
      position: position,
    );

StreetNumbers _numbersOf(BanStreetId id, String name, List<String> numbers) =>
    StreetNumbers(
      id: id,
      name: streetName(name),
      commune: villefranche,
      numbers: [
        for (final number in numbers) DirectoryNumber(number: n(number)),
      ],
      invalidNumbers: 0,
      duplicateNumbers: 0,
    );

final _road = StreetShape([
  [at(45.98800, 4.72500), at(45.98900, 4.72500)],
]);

final _lilasId = BanStreetId('69264_0500');

/// A street of the secteur with 2 doors, the first done.
Street _street(String id, String name, {BanStreetId? banId}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: name,
    commune: villefranche,
    banId: banId,
    houses: [
      House(number: n('1'), status: VisitStatus.done),
      House(number: n('2')),
    ],
  ),
);

void main() {
  late FakeStreetRepository streets;
  late FakeAddressDirectory directory;
  late FakeStreetShapes shapes;

  /// « Ajouter des rues » on Léa's phone, the size of the mockups'; the
  /// 49 is open, with Manu, Léa and Julie. Rue Pierre Morin is free, Rue
  /// des Lilas Léa's and Manu's, Rue Carnot Manu's.
  Future<void> pumpMap(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository([
      _street('morin', 'Rue Pierre Morin'),
      _street('lilas', 'Rue des Lilas', banId: _lilasId),
      _street('carnot', 'Rue Carnot'),
    ]);
    directory = FakeAddressDirectory(
      communes: {
        '69264': Ok(
          CommuneStreets(
            commune: villefranche,
            streets: [
              for (final (id, name, count) in [
                (_bordelanId, 'Petit Chemin de Bordelan', 1),
                (_gareId, 'Rue de la Gare', 3),
                (_lilasId, 'Rue des Lilas', 2),
              ])
                DirectoryStreet(
                  id: id,
                  name: streetName(name),
                  numberCount: count,
                ),
            ],
            skippedStreets: 0,
          ),
        ),
      },
      places: {
        _onBordelan: Ok(_bordelanMatch),
        _onGare: Ok(_matchOf(_gareId, 'Rue de la Gare', _onGare)),
        _onBroken: Ok(_matchOf(_brokenId, 'Rue Brisée', _onBroken)),
        _onLilas: Ok(_matchOf(_lilasId, 'Rue des Lilas', _onLilas)),
        _onFailing: Ok(_matchOf(_failingId, 'Rue du Port', _onFailing)),
        _moreStreets[0]: Ok(
          _matchOf(_hugoId, 'Rue Victor Hugo', _moreStreets[0]),
        ),
        _moreStreets[1]: Ok(
          _matchOf(_bertId, 'Rue Paul Bert', _moreStreets[1]),
        ),
        _offline: const Err(AddressDirectoryFailure.noNetwork),
      },
      streets: {
        _bordelanId: Ok(
          _numbersOf(_bordelanId, 'Petit Chemin de Bordelan', ['1']),
        ),
        _gareId: Ok(_numbersOf(_gareId, 'Rue de la Gare', ['1', '2', '3'])),
        _brokenId: Ok(_numbersOf(_brokenId, 'Rue Brisée', ['1', '1'])),
        _failingId: const Err(AddressDirectoryFailure.serviceError),
        _hugoId: Ok(_numbersOf(_hugoId, 'Rue Victor Hugo', ['2'])),
        _bertId: Ok(_numbersOf(_bertId, 'Rue Paul Bert', ['4'])),
      },
      searches: {
        'bordelan': Ok([_bordelanMatch]),
        'offline': const Err(AddressDirectoryFailure.noNetwork),
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          directory: directory,
          shapes: shapes = FakeStreetShapes()
            ..answers['Petit Chemin de Bordelan'] = Ok(_road),
          member: leaId,
          sectors: FakeSectorRepository([
            team(communes: [villefrancheCommune]),
          ]),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sectorId)),
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    // From Secteur, as the member would (PLAN §5.14).
    await openAddStreets(tester);
  }

  Future<void> tapRoad(WidgetTester tester, GeoPoint point) async {
    shownMap(tester).onMapTapped!(point);
    await tester.pumpAndSettle();
  }

  Future<void> tapStreet(WidgetTester tester, String id) async {
    shownMap(tester).onStreetTapped!(StreetId(id));
    await tester.pumpAndSettle();
  }

  Finder sheet() => find.byKey(const Key('addStreets.sheet'));
  Finder row(BanStreetId id) =>
      find.byKey(ValueKey('addStreets.row.${id.value}'));

  testWidgets('should open on the map under the search box, with the sheet '
      'saying what to do', (tester) async {
    await pumpMap(tester);

    expect(find.byType(AddStreetsScreen), findsOneWidget);
    expect(find.byType(FakeMapView), findsOneWidget);
    expect(find.text('Rechercher une rue'), findsOneWidget);
    expect(
      find.text('Touchez les rues à ajouter ou tracez une zone.'),
      findsOneWidget,
    );
    expect(
      find.text('Rue absente de la carte ? Saisir à la main'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('addStreets.add')), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(shownMap(tester).pickedRoads, isEmpty);
  });

  testWidgets('should tick the road tapped, on the map and in the '
      'sheet', (tester) async {
    await pumpMap(tester);

    await tapRoad(tester, _onBordelan);

    expect(find.text('1 rue sélectionnée'), findsOneWidget);
    expect(
      find.descendant(
        of: row(_bordelanId),
        matching: find.text('Petit Chemin de Bordelan'),
      ),
      findsOneWidget,
    );
    expect(find.text('Villefranche-sur-Saône · 1 numéro'), findsOneWidget);
    expect(find.text('Ajouter 1 rue'), findsOneWidget);
    expect(shownMap(tester).pickedRoads, [
      PickedRoad(street: _bordelanId, road: _road, mark: _onBordelan),
    ]);
    expect(shownMap(tester).selectedPoint, isNull);
  });

  testWidgets('should add the streets ticked at once, then go back to '
      'Secteur and say how many', (tester) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBordelan);
    await tapRoad(tester, _onGare);
    expect(find.text('2 rues sélectionnées'), findsOneWidget);

    await tester.tap(find.text('Ajouter 2 rues'));
    await tester.pumpAndSettle();

    expect(find.byType(AddStreetsScreen), findsNothing);
    expect(find.byType(TeamScreen), findsOneWidget);
    expect(find.text('2 rues ajoutées au secteur'), findsOneWidget);
    expect(
      [for (final street in streets.added) street.name.text],
      ['Petit Chemin de Bordelan', 'Rue de la Gare'],
    );
  });

  testWidgets('should tell the progress while the streets are '
      'added', (tester) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBordelan);
    await tapRoad(tester, _onGare);
    final stored = Completer<void>();
    streets.holdAdds = stored;

    await tester.tap(find.text('Ajouter 2 rues'));
    await tester.pump();

    expect(find.text('Ajout en cours… 0/2'), findsOneWidget);
    expect(find.byKey(const Key('addStreets.add')), findsNothing);

    // No way back meanwhile.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AddStreetsScreen), findsOneWidget);

    stored.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AddStreetsScreen), findsNothing);
  });

  testWidgets('should keep a street that failed ticked, and say why', (
    tester,
  ) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBroken);
    await tapRoad(tester, _onBordelan);

    await tester.tap(find.text('Ajouter 2 rues'));
    await tester.pumpAndSettle();

    expect(find.byType(AddStreetsScreen), findsOneWidget);
    expect(find.text('1 rue sélectionnée'), findsOneWidget);
    expect(row(_brokenId), findsOneWidget);
    expect(row(_bordelanId), findsNothing);
    expect(
      find.text(
        "1 rue n'a pas pu être ajoutée : la Base Adresse Nationale "
        'donne des numéros incohérents. Saisissez-la à la main.',
      ),
      findsOneWidget,
    );
    expect(streets.added.single.banId, _bordelanId);
  });

  testWidgets('should untick a ticked road tapped again', (tester) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBordelan);

    shownMap(tester).onPickTapped!(_bordelanId);
    await tester.pumpAndSettle();

    expect(shownMap(tester).pickedRoads, isEmpty);
    expect(
      find.text('Touchez les rues à ajouter ou tracez une zone.'),
      findsOneWidget,
    );
  });

  testWidgets('should untick a street with its ✕, and all of them with '
      '« Tout décocher »', (tester) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBordelan);
    await tapRoad(tester, _onGare);

    await tester.tap(find.byTooltip('Retirer Petit Chemin de Bordelan'));
    await tester.pumpAndSettle();

    expect(row(_bordelanId), findsNothing);
    expect(row(_gareId), findsOneWidget);

    await tester.tap(find.text('Tout décocher'));
    await tester.pumpAndSettle();

    expect(row(_gareId), findsNothing);
    expect(
      find.text('Touchez les rues à ajouter ou tracez une zone.'),
      findsOneWidget,
    );
  });

  testWidgets('should say a street of the secteur is in it already, from '
      'its line or from the map', (tester) async {
    await pumpMap(tester);

    await tapStreet(tester, 'carnot');

    expect(find.text('Rue Carnot est déjà dans le secteur.'), findsOneWidget);

    await tapRoad(tester, _onLilas);

    expect(
      find.text('Rue des Lilas est déjà dans le secteur.'),
      findsOneWidget,
    );
    expect(shownMap(tester).pickedRoads, isEmpty);
  });

  testWidgets('should say a connection is needed offline, and offer the '
      'manual entry', (tester) async {
    await pumpMap(tester);

    await tapRoad(tester, _offline);

    expect(
      find.text('Connexion nécessaire pour ajouter une rue.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Saisir à la main'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualStreetScreen), findsOneWidget);
  });

  testWidgets('should say when the BAN knows no street there', (tester) async {
    await pumpMap(tester);

    await tapRoad(tester, _nowhere);

    expect(find.text('Aucune rue connue ici.'), findsOneWidget);
    expect(find.text('Saisir à la main'), findsOneWidget);
  });

  testWidgets('should say when the address service fails', (tester) async {
    await pumpMap(tester);

    await tapRoad(tester, _onFailing);

    expect(find.text('Le service des adresses ne répond pas.'), findsOneWidget);
  });

  testWidgets('should keep the map clear of the sheet', (tester) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBordelan);

    expect(shownMap(tester).padding.bottom, tester.getSize(sheet()).height);
  });

  testWidgets('should fold the sheet to its title, and unfold it', (
    tester,
  ) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBordelan);
    final unfolded = tester.getSize(sheet()).height;

    await tester.fling(
      find.byKey(const Key('addStreets.sheet.handle')),
      const Offset(0, 200),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 rue sélectionnée'), findsOneWidget);
    expect(row(_bordelanId), findsNothing);
    expect(find.text('Ajouter 1 rue'), findsNothing);
    expect(tester.getSize(sheet()).height, lessThan(unfolded));
    expect(shownMap(tester).padding.bottom, tester.getSize(sheet()).height);

    await tester.tap(find.text('1 rue sélectionnée'));
    await tester.pumpAndSettle();

    expect(row(_bordelanId), findsOneWidget);
    expect(find.text('Ajouter 1 rue'), findsOneWidget);
  });

  testWidgets('should scroll the rows past four streets', (tester) async {
    await pumpMap(tester);
    for (final point in [_onBordelan, _onGare, _onBroken, ..._moreStreets]) {
      await tapRoad(tester, point);
    }
    expect(find.text('5 rues sélectionnées'), findsOneWidget);

    final rows = find.byKey(const Key('addStreets.rows'));
    expect(tester.getSize(rows).height, 4 * 52.0);
    expect(
      tester
          .state<ScrollableState>(
            find.descendant(of: rows, matching: find.byType(Scrollable)),
          )
          .position
          .maxScrollExtent,
      greaterThan(0),
    );
  });

  testWidgets('should keep the ticks while « Liste » shows', (tester) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBordelan);

    await tester.tap(find.byKey(const Key('addStreets.tab.list')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addStreets.tab.map')));
    await tester.pumpAndSettle();

    expect(row(_bordelanId), findsOneWidget);
  });

  testWidgets('should go back to Secteur on the back gesture', (tester) async {
    await pumpMap(tester);
    await tapRoad(tester, _onBordelan);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AddStreetsScreen), findsNothing);
    expect(find.byType(TeamScreen), findsOneWidget);
  });

  group('search', () {
    Future<void> search(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('addStreets.search')), text);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    testWidgets('should list the streets found, and tick the one picked, '
        'the map around it', (tester) async {
      await pumpMap(tester);

      await search(tester, 'bordelan');

      expect(find.text('Petit Chemin de Bordelan'), findsOneWidget);
      expect(directory.searchesAsked, [('bordelan', '69264')]);

      await tester.tap(
        find.byKey(ValueKey('addStreets.found.${_bordelanId.value}')),
      );
      await tester.pumpAndSettle();

      expect(row(_bordelanId), findsOneWidget);
      expect(
        shownMap(tester).area,
        GeoBounds.around([_onBordelan])!.expandedBy(200),
      );
    });

    testWidgets('should say when no street is found', (tester) async {
      await pumpMap(tester);

      await search(tester, 'zzz');

      expect(find.text('Aucune rue trouvée.'), findsOneWidget);
    });

    testWidgets('should say a connection is needed offline', (tester) async {
      await pumpMap(tester);

      await search(tester, 'offline');

      expect(
        find.text('Connexion nécessaire pour chercher une rue.'),
        findsOneWidget,
      );
    });

    testWidgets('should empty the box and close the list with ✕', (
      tester,
    ) async {
      await pumpMap(tester);
      await search(tester, 'zzz');

      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune rue trouvée.'), findsNothing);
      expect(find.text('zzz'), findsNothing);
    });
  });

  testWidgets('should open « Rue à la main » from the sheet\'s link', (
    tester,
  ) async {
    await pumpMap(tester);

    await tester.tap(find.byKey(const Key('addStreets.manual')));
    await tester.pumpAndSettle();

    expect(find.byType(ManualStreetScreen), findsOneWidget);
    expect(find.text('Rue à la main'), findsOneWidget);
  });

  testWidgets('should label every control and make it 48 dp at least, '
      'streets ticked or not', (tester) async {
    await pumpMap(tester);

    await expectAccessibleControls(tester);

    await tapRoad(tester, _onBordelan);

    await expectAccessibleControls(tester);
    expect(find.byTooltip('Retirer Petit Chemin de Bordelan'), findsOneWidget);
  });

  group('large text', () {
    setUpAll(loadAppFonts);

    testWidgets('should hold the sheet with streets ticked at 200 %', (
      tester,
    ) async {
      await pumpMap(tester);
      useLargeText(tester);
      await tester.pumpAndSettle();

      await tapRoad(tester, _onBordelan);
      await tapRoad(tester, _onGare);

      expect(find.text('2 rues sélectionnées'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('zone', () {
    final zone = GeoBounds.of(
      south: 45.98,
      west: 4.71,
      north: 45.99,
      east: 4.73,
    )!;

    /// A road across the zone at [latitude].
    NamedRoad road(String name, double latitude) => NamedRoad(
      name: name,
      shape: StreetShape([
        [at(latitude, 4.712), at(latitude, 4.716)],
      ]),
    );

    Finder zonePill() => find.byKey(const Key('addStreets.zone'));
    Finder zoneRow(String key) =>
        find.byKey(ValueKey('addStreets.zoneRow.$key'));

    /// « Zone » on, then a zone drawn at [zoom] with the Gare, the Lilas
    /// and the Chemin de Halage in it.
    Future<void> drawZone(WidgetTester tester, {double zoom = 16}) async {
      shapes.roads = Ok([
        road('Rue de la Gare', 45.985),
        road('Rue des Lilas', 45.986),
        road('Chemin de Halage', 45.987),
      ]);
      await tester.tap(zonePill());
      await tester.pumpAndSettle();
      shownMap(tester).onZoneDrawn!(zone, zoom);
      await tester.pumpAndSettle();
    }

    testWidgets('should turn « Zone » on next to the search, and say how '
        'to draw one', (tester) async {
      await pumpMap(tester);
      expect(find.bySemanticsLabel('Sélectionner une zone'), findsOneWidget);
      expect(shownMap(tester).zoneMode, isFalse);

      await tester.tap(zonePill());
      await tester.pumpAndSettle();

      expect(shownMap(tester).zoneMode, isTrue);
      expect(find.bySemanticsLabel('Zone en cours, annuler'), findsOneWidget);
      expect(
        find.text('Faites glisser le doigt sur la carte pour tracer une zone.'),
        findsOneWidget,
      );
    });

    testWidgets('should list the streets of the zone drawn, those to add '
        'ticked, the others greyed', (tester) async {
      await pumpMap(tester);

      await drawZone(tester);

      expect(find.byKey(const Key('addStreets.zoneSheet')), findsOneWidget);
      expect(find.text('3 rues dans la zone'), findsOneWidget);
      expect(
        find.descendant(
          of: zoneRow(_gareId.value),
          matching: find.text('3 numéros'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: zoneRow(_lilasId.value),
          matching: find.text('Déjà dans le secteur'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: zoneRow('Chemin de Halage'),
          matching: find.text('Aucune adresse connue'),
        ),
        findsOneWidget,
      );
      expect(find.text('Ajouter 1 rue'), findsOneWidget);
      expect(shownMap(tester).zone, zone);
      expect(shownMap(tester).pickedRoads.single.street, _gareId);
      expect(
        tester.getSemantics(zoneRow(_gareId.value)),
        isSemantics(isChecked: true, isEnabled: true),
      );
      expect(
        tester.getSemantics(zoneRow(_lilasId.value)),
        isSemantics(isChecked: false, isEnabled: false),
      );
    });

    testWidgets('should untick a street of the zone with its checkbox, and '
        'tick nothing on a greyed one', (tester) async {
      await pumpMap(tester);
      await drawZone(tester);

      await tester.tap(zoneRow(_gareId.value));
      await tester.pumpAndSettle();
      await tester.tap(zoneRow(_lilasId.value));
      await tester.pumpAndSettle();

      expect(shownMap(tester).pickedRoads, isEmpty);
      final add = tester.widget<PrimaryButton>(
        find.byKey(const Key('addStreets.add')),
      );
      expect(add.label, 'Ajouter');
      expect(add.onPressed, isNull);
    });

    testWidgets('should add the streets of a zone and those tapped at once, '
        'then go back to Secteur', (tester) async {
      await pumpMap(tester);
      await tapRoad(tester, _onBordelan);
      await drawZone(tester);

      await tester.tap(find.text('Ajouter 2 rues'));
      await tester.pumpAndSettle();

      expect(find.byType(TeamScreen), findsOneWidget);
      expect(find.text('2 rues ajoutées au secteur'), findsOneWidget);
      expect(
        [for (final street in streets.added) street.name.text],
        ['Petit Chemin de Bordelan', 'Rue de la Gare'],
      );
    });

    testWidgets('should say why the streets of a zone could not be added '
        'offline', (tester) async {
      await pumpMap(tester);
      await drawZone(tester);
      // Offline once the zone is listed: the numbers cannot be read.
      directory.streets[_gareId] = const Err(AddressDirectoryFailure.noNetwork);

      await tester.tap(find.text('Ajouter 1 rue'));
      await tester.pumpAndSettle();

      expect(find.byType(AddStreetsScreen), findsOneWidget);
      expect(
        find.text("1 rue n'a pas pu être ajoutée : connexion nécessaire."),
        findsOneWidget,
      );
      expect(find.text('Ajouter 1 rue'), findsOneWidget);
    });

    testWidgets('should leave the zone and keep its ticks when « Zone » goes '
        'off', (tester) async {
      await pumpMap(tester);
      await drawZone(tester);

      await tester.tap(zonePill());
      await tester.pumpAndSettle();

      expect(shownMap(tester).zoneMode, isFalse);
      expect(shownMap(tester).zone, isNull);
      expect(find.byKey(const Key('addStreets.zoneSheet')), findsNothing);
      expect(find.text('1 rue sélectionnée'), findsOneWidget);
      expect(row(_gareId), findsOneWidget);
    });

    testWidgets('should show the zone while its streets are looked for', (
      tester,
    ) async {
      await pumpMap(tester);
      shapes.holdRoads();
      await tester.tap(zonePill());
      await tester.pumpAndSettle();

      shownMap(tester).onZoneDrawn!(zone, 16);
      await tester.pump();

      expect(find.text('Recherche des rues de la zone…'), findsOneWidget);
      expect(shownMap(tester).zone, zone);
      shapes.releaseRoads();
      await tester.pumpAndSettle();
      expect(find.text('Aucune rue dans la zone'), findsOneWidget);
    });

    testWidgets('should ask to zoom in under zoom 15', (tester) async {
      await pumpMap(tester);

      await drawZone(tester, zoom: 14);

      expect(find.text('Zoomez pour tracer une zone.'), findsOneWidget);
      expect(shownMap(tester).zone, isNull);
    });

    testWidgets('should say a zone of more than 50 streets is too large', (
      tester,
    ) async {
      await pumpMap(tester);
      await tester.tap(zonePill());
      await tester.pumpAndSettle();
      shapes.roads = Ok([
        for (var i = 0; i < 51; i++) road('Chemin $i', 45.981 + i * 0.0001),
      ]);

      shownMap(tester).onZoneDrawn!(zone, 16);
      await tester.pumpAndSettle();

      expect(find.text('Zone trop grande : 50 rues au plus.'), findsOneWidget);
    });

    testWidgets('should label the zone\'s controls and make them 48 dp at '
        'least', (tester) async {
      await pumpMap(tester);
      await drawZone(tester);

      await expectAccessibleControls(tester);
    });

    testWidgets('should hold the zone\'s sheet at 200 %', (tester) async {
      await loadAppFonts();
      await pumpMap(tester);
      useLargeText(tester);
      await tester.pumpAndSettle();

      await drawZone(tester);

      expect(find.text('3 rues dans la zone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
