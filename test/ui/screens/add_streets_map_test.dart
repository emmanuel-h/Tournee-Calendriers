// The « Carte » tab of « Ajouter des rues » (PLAN §5.4, Pick mockup): the
// street card in its four states, its loading and failures, the search and
// « Saisir une rue à la main ».
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/manual_street_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_street_shapes.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' hide lea;
import '../support/app_overrides.dart';
import '../support/fake_map_view.dart';

final _bordelanId = BanStreetId('69264_0246');

/// Where the finger taps on Petit Chemin de Bordelan, not in the tournée.
final _onBordelan = at(45.98850, 4.72500);

/// Where the BAN cannot be reached, and where it knows no street.
final _offline = at(45.99000, 4.72000);
final _nowhere = at(45.99500, 4.73000);

final _bordelanMatch = StreetMatch(
  id: _bordelanId,
  name: streetName('Petit Chemin de Bordelan'),
  commune: villefranche,
  position: _onBordelan,
);

final _road = StreetShape([
  [at(45.98800, 4.72500), at(45.98900, 4.72500)],
]);

/// A street of the tournée with 2 doors, the first done, covered by
/// [assignees].
Street _street(String id, String name, Set<MemberId> assignees) => valueOf(
  Street.create(
    id: StreetId(id),
    name: name,
    commune: villefranche,
    assignees: assignees,
    houses: [
      House(number: n('1'), status: VisitStatus.done),
      House(number: n('2')),
    ],
  ),
);

void main() {
  late FakeStreetRepository streets;
  late FakeAddressDirectory directory;

  /// « Ajouter des rues » on Léa's phone, the size of the mockups'; the
  /// 49 is open, with Manu, Léa and Julie. Rue Pierre Morin is free, Rue
  /// des Lilas Léa's and Manu's, Rue Carnot Manu's.
  Future<void> pumpMap(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository([
      _street('morin', 'Rue Pierre Morin', {}),
      _street('lilas', 'Rue des Lilas', {leaId, manuId}),
      _street('carnot', 'Rue Carnot', {manuId}),
    ]);
    directory = FakeAddressDirectory(
      places: {
        _onBordelan: Ok(_bordelanMatch),
        _offline: const Err(AddressDirectoryFailure.noNetwork),
      },
      streets: {
        _bordelanId: Ok(
          StreetNumbers(
            id: _bordelanId,
            name: streetName('Petit Chemin de Bordelan'),
            commune: villefranche,
            numbers: [DirectoryNumber(number: n('1'))],
            invalidNumbers: 0,
            duplicateNumbers: 0,
          ),
        ),
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
          shapes: FakeStreetShapes(Ok(_road)),
          member: leaId,
          tournees: FakeTourneeRepository([
            team(communes: [villefrancheCommune]),
          ]),
          myTournees: FakeMyTourneesStore(
            valueOf(MyTournees.none.remember(tournee49).open(tourneeId)),
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start.import')));
    await tester.pumpAndSettle();
  }

  Future<void> tapRoad(WidgetTester tester, GeoPoint point) async {
    shownMap(tester).onMapTapped!(point);
    await tester.pumpAndSettle();
  }

  Future<void> tapStreet(WidgetTester tester, String id) async {
    shownMap(tester).onStreetTapped!(StreetId(id));
    await tester.pumpAndSettle();
  }

  Finder card() => find.byKey(const Key('streetCard'));
  Finder button(String key) => find.byKey(Key('streetCard.$key'));

  testWidgets('should open on the map, under the search box and « Saisir '
      'une rue à la main »', (tester) async {
    await pumpMap(tester);

    expect(find.byType(AddStreetsScreen), findsOneWidget);
    expect(find.byType(FakeMapView), findsOneWidget);
    expect(find.text('Rechercher une rue'), findsOneWidget);
    expect(find.text('Saisir une rue à la main'), findsOneWidget);
    expect(card(), findsNothing);
  });

  group('street card', () {
    testWidgets('should offer to add a street the tournée does not have, '
        'and add it for the member', (tester) async {
      await pumpMap(tester);

      await tapRoad(tester, _onBordelan);

      expect(find.text('Petit Chemin de Bordelan'), findsOneWidget);
      expect(find.text('Villefranche-sur-Saône'), findsOneWidget);
      expect(find.text('1 numéro'), findsOneWidget);
      expect(find.text('Pas encore dans la tournée'), findsOneWidget);
      expect(find.text("Ajouter sans m'attribuer"), findsOneWidget);
      expect(
        find.text('Rue absente de la carte ? Saisir à la main'),
        findsOneWidget,
      );
      expect(shownMap(tester).selectedRoad, _road);
      expect(shownMap(tester).selectedPoint, _onBordelan);

      await tester.tap(find.text("Ajouter et me l'attribuer"));
      await tester.pumpAndSettle();

      final added = streets.added.single;
      expect(added.banId, _bordelanId);
      expect(added.assignees, {leaId});
      expect(find.text('Vous la faites'), findsOneWidget);
      expect(find.text('0/1 faits'), findsOneWidget);
    });

    testWidgets('should add a street free with « Ajouter sans '
        'm\'attribuer »', (tester) async {
      await pumpMap(tester);
      await tapRoad(tester, _onBordelan);

      await tester.tap(button('addFree'));
      await tester.pumpAndSettle();

      expect(streets.added.single.assignees, isEmpty);
      expect(find.text('Libre'), findsOneWidget);
    });

    testWidgets('should offer « Me l\'attribuer » and « Ouvrir » for a free '
        'street', (tester) async {
      await pumpMap(tester);

      await tapStreet(tester, 'morin');

      expect(find.text('Rue Pierre Morin'), findsOneWidget);
      expect(find.text('1/2 faits'), findsOneWidget);
      expect(find.text('Libre'), findsOneWidget);
      expect(find.text('Ouvrir'), findsOneWidget);

      await tester.tap(find.text("Me l'attribuer"));
      await tester.pumpAndSettle();

      expect(streets[StreetId('morin')]!.assignees, {leaId});
      expect(find.text('Vous la faites'), findsOneWidget);
    });

    testWidgets('should offer « Ouvrir » and « Ne plus la faire » for a '
        'street of the member\'s, naming who covers it too', (tester) async {
      await pumpMap(tester);

      await tapStreet(tester, 'lilas');

      expect(find.text('Vous la faites avec Manu'), findsOneWidget);
      expect(find.text('Ne plus la faire'), findsOneWidget);

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Rue des Lilas'), findsOneWidget);
    });

    testWidgets('should offer « La faire aussi » and « Ouvrir » for someone '
        'else\'s street, naming who covers it', (tester) async {
      await pumpMap(tester);

      await tapStreet(tester, 'carnot');

      expect(find.text('Faite par Manu'), findsOneWidget);
      expect(button('open'), findsOneWidget);

      await tester.tap(find.text('La faire aussi'));
      await tester.pumpAndSettle();

      expect(streets[StreetId('carnot')]!.assignees, {manuId, leaId});
      expect(find.text('Vous la faites avec Manu'), findsOneWidget);

      await tester.tap(find.text('Ne plus la faire'));
      await tester.pumpAndSettle();

      expect(find.text('Faite par Manu'), findsOneWidget);
    });

    testWidgets('should keep the map clear of the card', (tester) async {
      await pumpMap(tester);

      await tapStreet(tester, 'carnot');

      expect(shownMap(tester).padding.bottom, tester.getSize(card()).height);
    });

    testWidgets('should say a connection is needed offline, and offer the '
        'manual entry', (tester) async {
      await pumpMap(tester);

      await tapRoad(tester, _offline);

      expect(
        find.text('Connexion nécessaire pour ajouter une rue'),
        findsOneWidget,
      );
      await tester.tap(button('manual'));
      await tester.pumpAndSettle();

      expect(find.byType(ManualStreetScreen), findsOneWidget);
    });

    testWidgets('should say when the BAN knows no street there', (
      tester,
    ) async {
      await pumpMap(tester);

      await tapRoad(tester, _nowhere);

      expect(find.text('Aucune rue connue ici'), findsOneWidget);
      expect(button('manual'), findsOneWidget);
    });

    testWidgets('should close the card with its ✕ and stay on the '
        'screen', (tester) async {
      await pumpMap(tester);
      await tapRoad(tester, _onBordelan);
      expect(shownMap(tester).selectedRoad, _road);
      expect(shownMap(tester).selectedPoint, _onBordelan);

      // « Fermer » is the screen's ✕ too: the card's is found by its key.
      await tester.tap(button('close'));
      await tester.pumpAndSettle();

      expect(card(), findsNothing);
      expect(find.byType(AddStreetsScreen), findsOneWidget);
      expect(shownMap(tester).selectedRoad, StreetShape.none);
      expect(shownMap(tester).selectedPoint, isNull);
    });

    testWidgets('should close the card on the back gesture, then the '
        'screen', (tester) async {
      await pumpMap(tester);
      await tapStreet(tester, 'carnot');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(card(), findsNothing);
      expect(find.byType(AddStreetsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AddStreetsScreen), findsNothing);
    });

    testWidgets('should close the screen with ✕ while a card shows', (
      tester,
    ) async {
      await pumpMap(tester);
      await tapStreet(tester, 'carnot');

      // The top bar's ✕, not the card's (also « Fermer »).
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Fermer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AddStreetsScreen), findsNothing);
    });
  });

  group('search', () {
    Future<void> search(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('addStreets.search')), text);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    testWidgets('should list the streets found, and show the one picked on '
        'the map with its card', (tester) async {
      await pumpMap(tester);

      await search(tester, 'bordelan');

      expect(find.text('Petit Chemin de Bordelan'), findsOneWidget);
      expect(directory.searchesAsked, [('bordelan', '69264')]);

      await tester.tap(
        find.byKey(ValueKey('addStreets.found.${_bordelanId.value}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pas encore dans la tournée'), findsOneWidget);
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

  testWidgets('should open « Rue à la main » from its button', (tester) async {
    await pumpMap(tester);

    await tester.tap(find.byKey(const Key('addStreets.manual')));
    await tester.pumpAndSettle();

    expect(find.byType(ManualStreetScreen), findsOneWidget);
    expect(find.text('Rue à la main'), findsOneWidget);
  });
}
