import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/map/tournee_area.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/street/street_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart' show manuId, team;
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_pending_sync.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/fake_map_view.dart';

/// A street of Villefranche-sur-Saône with [total] houses, the first
/// [done] done, covered by [assignees].
Street _street(
  String id,
  String name, {
  int done = 0,
  int total = 1,
  Set<MemberId> assignees = const {},
  StreetShape shape = StreetShape.none,
}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: name,
    commune: villefranche,
    assignees: assignees,
    shape: shape,
    houses: [
      for (var i = 1; i <= total; i++)
        House(
          number: n('$i'),
          status: i <= done ? VisitStatus.done : VisitStatus.toDo,
        ),
    ],
  ),
);

final _lilasShape = StreetShape([
  [at(45.98915, 4.71862), at(45.99210, 4.71705)],
]);

/// Léa covers Rue des Lilas (31 of 42 done) and Allée des Pins (0 of 8);
/// Rue Pasteur (12 of 12) is nobody's, Rue Carnot (0 of 38) Paul's.
List<Street> _streets() => [
  _street(
    'lilas',
    'Rue des Lilas',
    done: 31,
    total: 42,
    assignees: {lea},
    shape: _lilasShape,
  ),
  _street('pins', 'Allée des Pins', total: 8, assignees: {lea}),
  _street('pasteur', 'Rue Pasteur', done: 12, total: 12),
  _street('carnot', 'Rue Carnot', total: 38, assignees: {paul}),
];

void main() {
  late FakePendingSync pending;

  /// Léa's phone, the size of the mockups' (390 × 844 dp), with [open]
  /// open (the 49 by default) holding [streets].
  Future<void> pumpHome(
    WidgetTester tester, {
    List<Street>? streets,
    TourneeSummary? open,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    pending = FakePendingSync();
    final opened = open ?? tournee49;
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: FakeStreetRepository(streets ?? _streets()),
          tournees: FakeTourneeRepository([team()]),
          myTournees: FakeMyTourneesStore(
            valueOf(MyTournees.none.remember(opened).open(opened.id)),
          ),
          pending: pending,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder panel() => find.byKey(const Key('home.panel'));
  Finder row(String id) => find.byKey(ValueKey('home.street.$id'));

  group('panel', () {
    testWidgets('should total « Mes rues » and the team over the map', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Tournée 49 · 2026'), findsOneWidget);
      expect(find.text('Mes rues · 31/50'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Mes rues, 31 sur 50 faits')),
        findsOneWidget,
      );
      // 43 of the tournée's 100 doors.
      expect(find.text('Équipe : 43 %'), findsOneWidget);
      expect(
        tester.getTopLeft(panel()).dy,
        greaterThan(tester.getTopLeft(find.byType(FakeMapView)).dy),
      );
    });

    testWidgets('should list « Mes rues », then the other streets of the '
        'tournée under their header', (tester) async {
      await pumpHome(tester);

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      expect(top(row('pins')), lessThan(top(row('lilas'))));
      expect(
        find.text('Autres rues de la tournée (2)'.toUpperCase()),
        findsOneWidget,
      );
      expect(
        top(row('lilas')),
        lessThan(top(find.byKey(const Key('home.others')))),
      );
      await tester.scrollUntilVisible(row('pasteur'), 100);
      expect(
        top(find.byKey(const Key('home.others'))),
        lessThan(top(row('carnot'))),
      );
      expect(top(row('carnot')), lessThan(top(row('pasteur'))));
      expect(find.text('Vous n\'avez pas encore de rue.'), findsNothing);
    });

    testWidgets('should open the street when one of « Mes rues » is tapped', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(row('lilas'));
      await tester.pumpAndSettle();

      expect(find.byType(StreetScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Rue des Lilas'), findsOneWidget);
    });

    testWidgets('should show the card of a street tapped among the others '
        'in place of the panel, and take it with « Me l\'attribuer »', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.scrollUntilVisible(row('pasteur'), 100);

      await tester.tap(row('pasteur'));
      await tester.pumpAndSettle();

      expect(find.byType(StreetScreen), findsNothing);
      expect(panel(), findsNothing);
      expect(find.byKey(const Key('home.selected')), findsOneWidget);
      expect(find.text('Rue Pasteur'), findsOneWidget);
      expect(find.text('Libre'), findsOneWidget);

      await tester.tap(find.text("Me l'attribuer"));
      await tester.pumpAndSettle();

      expect(find.text('Vous la faites'), findsOneWidget);
    });

    testWidgets('should move the map to a street tapped among the others, '
        'its line lit up', (tester) async {
      final lilas = _street(
        'lilas',
        'Rue des Lilas',
        total: 42,
        shape: _lilasShape,
      );
      await pumpHome(tester, streets: [lilas]);

      await tester.tap(row('lilas'));
      await tester.pumpAndSettle();

      final map = shownMap(tester);
      expect(map.area, streetArea(lilas));
      expect(map.selectedRoad, _lilasShape);
    });

    testWidgets('should close the card of a street with the back gesture, '
        'and stay on Accueil', (tester) async {
      await pumpHome(tester);
      await tester.scrollUntilVisible(row('carnot'), 100);
      await tester.tap(row('carnot'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home.selected')), findsOneWidget);

      // Android's back button or gesture.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.selected')), findsNothing);
      expect(panel(), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(shownMap(tester).selectedRoad, StreetShape.none);
    });

    testWidgets('should close the card of a street with its ✕, '
        'and bring the list back', (tester) async {
      final lilas = _street(
        'lilas',
        'Rue des Lilas',
        total: 42,
        shape: _lilasShape,
      );
      await pumpHome(tester, streets: [lilas]);
      await tester.tap(row('lilas'));
      await tester.pumpAndSettle();
      expect(shownMap(tester).selectedRoad, _lilasShape);
      final close = find.byKey(const Key('streetCard.close'));
      expect(tester.getSize(close), const Size(48, 48));
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(close).tooltip, 'Fermer');
      semantics.dispose();
      // Level with the grabber, and the name keeps clear of it.
      final cardTop = tester.getTopLeft(find.byKey(const Key('streetCard'))).dy;
      expect(tester.getTopLeft(close).dy, cardTop + 6);
      expect(
        tester.getTopRight(find.byKey(const Key('streetCard.name'))).dx,
        lessThanOrEqualTo(tester.getTopLeft(close).dx),
      );

      await tester.tap(close);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Fermer'), findsNothing);
      expect(find.byKey(const Key('home.selected')), findsNothing);
      expect(panel(), findsOneWidget);
      expect(shownMap(tester).selectedRoad, StreetShape.none);
    });

    testWidgets('should keep every street of the tournée reachable when the '
        'member covers none', (tester) async {
      await pumpHome(
        tester,
        streets: [
          _street('pasteur', 'Rue Pasteur', done: 12, total: 12),
          _street('carnot', 'Rue Carnot', total: 38),
        ],
      );

      expect(find.text('Mes rues · 0/0'), findsOneWidget);
      expect(find.text('Vous n\'avez pas encore de rue.'), findsOneWidget);
      expect(row('carnot'), findsOneWidget);
      expect(row('pasteur'), findsOneWidget);
    });

    testWidgets('should say when the tournée has no street', (tester) async {
      await pumpHome(tester, streets: []);

      expect(
        find.text('Aucune rue dans la tournée pour l\'instant.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home.others')), findsNothing);
      expect(find.text('Vous n\'avez pas encore de rue.'), findsNothing);
    });

    testWidgets('should list every street under « Rues » for a visiting '
        'admin', (tester) async {
      await pumpHome(tester, open: tournee12Visited);

      expect(find.text('Rues · 43/100'), findsOneWidget);
      expect(find.byKey(const Key('home.adminBanner')), findsOneWidget);
      expect(row('carnot'), findsOneWidget);
      expect(find.byKey(const Key('home.others')), findsNothing);
    });

    testWidgets('should open « Ajouter des rues » from its button', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const Key('start.import')));
      await tester.pumpAndSettle();

      expect(find.byType(AddStreetsScreen), findsOneWidget);
    });

    testWidgets('should say how many streets wait to be sent while some do, '
        'above « Ajouter des rues »', (tester) async {
      await pumpHome(tester);
      final line = find.byKey(const Key('start.pendingSync'));
      expect(line, findsNothing);

      pending.unsent(2);
      await tester.pumpAndSettle();

      expect(
        find.text("Modifications de 2 rues en attente d'envoi"),
        findsOneWidget,
      );
      // A glyph next to the text, and the text read out: never a colour.
      expect(
        find.descendant(of: line, matching: find.byIcon(Icons.cloud_outlined)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Modifications de 2 rues en attente d'envoi"),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(line).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byKey(const Key('start.import'))).dy,
        ),
      );

      pending.unsent(1);
      await tester.pumpAndSettle();
      expect(
        find.text("Modifications d'une rue en attente d'envoi"),
        findsOneWidget,
      );

      pending.unsent(0);
      await tester.pumpAndSettle();
      expect(line, findsNothing);
    });
  });

  group('dragging the panel', () {
    final handle = find.byKey(const Key('home.panel.handle'));

    testWidgets('should rest on half the room under the top bar', (
      tester,
    ) async {
      await pumpHome(tester);

      final room = tester.getSize(find.byType(FakeMapView)).height;
      expect(tester.getSize(panel()).height, room * 0.5);
      // « Me localiser » and the attribution keep clear of it.
      expect(shownMap(tester).padding.bottom, room * 0.5);
    });

    testWidgets('should show the whole list when dragged up, and come back '
        'to rest on a tap of its handle', (tester) async {
      await pumpHome(tester);
      final room = tester.getSize(find.byType(FakeMapView)).height;

      await tester.drag(handle, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getSize(panel()).height, room);
      expect(row('pasteur'), findsOneWidget);
      expect(
        tester.getSemantics(handle),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          onTapHint: 'Réduire la liste',
          label: 'Mes rues, 31 sur 50 faits\nÉquipe : 43 %',
        ),
      );

      await tester.tap(handle);
      await tester.pumpAndSettle();

      expect(tester.getSize(panel()).height, room * 0.5);
    });

    testWidgets('should leave only the handle and the totals when dragged '
        'down', (tester) async {
      await pumpHome(tester);

      await tester.drag(handle, const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(tester.getSize(panel()).height, AppSizes.homePanelFolded);
      expect(find.text('Mes rues · 31/50'), findsOneWidget);
      expect(row('lilas'), findsNothing);
      expect(find.byKey(const Key('start.import')), findsNothing);
      expect(shownMap(tester).padding.bottom, AppSizes.homePanelFolded);
    });

    testWidgets('should show the whole list on a tap of the handle at rest', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(handle);
      await tester.pumpAndSettle();

      expect(
        tester.getSize(panel()).height,
        tester.getSize(find.byType(FakeMapView)).height,
      );
    });
  });

  group('map', () {
    testWidgets('should draw the tournée\'s streets and open on them', (
      tester,
    ) async {
      final streets = _streets();
      await pumpHome(tester, streets: streets);

      final map = shownMap(tester);

      expect(map.layers.lines.single.street, StreetId('lilas'));
      expect(map.area, tourneeArea(streets));
    });

    testWidgets('should show the card of a street tapped on the map in '
        'place of the panel, and take it with « La faire aussi »', (
      tester,
    ) async {
      await pumpHome(
        tester,
        streets: [
          ..._streets().where((street) => street.id != StreetId('carnot')),
          // Manu is in the team: he covers Rue Carnot.
          _street('carnot', 'Rue Carnot', total: 38, assignees: {manuId}),
        ],
      );

      shownMap(tester).onStreetTapped!(StreetId('carnot'));
      await tester.pumpAndSettle();

      expect(panel(), findsNothing);
      expect(find.byKey(const Key('home.selected')), findsOneWidget);
      expect(find.text('Rue Carnot'), findsOneWidget);
      expect(find.text('0/38 faits'), findsOneWidget);
      expect(find.text('Faite par Manu'), findsOneWidget);

      await tester.tap(find.text('La faire aussi'));
      await tester.pumpAndSettle();

      expect(find.text('Vous la faites avec Manu'), findsOneWidget);
      expect(find.text('Ne plus la faire'), findsOneWidget);
    });

    testWidgets('should show « Libre » the card of a street whose only '
        'assignee left the team, and take it with « Me l\'attribuer » '
        '(#91)', (tester) async {
      // Paul covers Rue Carnot but is no longer in the team.
      await pumpHome(tester);

      shownMap(tester).onStreetTapped!(StreetId('carnot'));
      await tester.pumpAndSettle();

      expect(find.text('Rue Carnot'), findsOneWidget);
      expect(find.text('Libre'), findsOneWidget);
      expect(find.text('La faire aussi'), findsNothing);

      await tester.tap(find.byKey(const Key('streetCard.take')));
      await tester.pumpAndSettle();

      expect(find.text('Vous la faites'), findsOneWidget);
      expect(find.text('Ne plus la faire'), findsOneWidget);
    });

    testWidgets('should release a street of the member\'s from its card, '
        'and open a street from it', (tester) async {
      await pumpHome(tester);
      shownMap(tester).onStreetTapped!(StreetId('lilas'));
      await tester.pumpAndSettle();
      expect(find.text('31/42 faits'), findsOneWidget);
      expect(find.bySemanticsLabel('31 sur 42 faits'), findsOneWidget);

      await tester.tap(find.text('Ne plus la faire'));
      await tester.pumpAndSettle();
      expect(find.text('Libre'), findsOneWidget);
      expect(find.text("Me l'attribuer"), findsOneWidget);

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Rue des Lilas'), findsOneWidget);
    });

    testWidgets('should keep the map clear of the card, and bring the list '
        'back when the map is tapped away from the streets', (tester) async {
      await pumpHome(tester);
      shownMap(tester).onStreetTapped!(StreetId('carnot'));
      await tester.pumpAndSettle();
      expect(
        shownMap(tester).padding.bottom,
        tester.getSize(find.byKey(const Key('home.selected'))).height,
      );

      shownMap(tester).onMapTapped!(townHallDoor);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.selected')), findsNothing);
      expect(panel(), findsOneWidget);
    });
  });

  group('legend', () {
    final legend = find.byKey(const Key('map.legend'));

    testWidgets('should explain the street colours at city zoom', (
      tester,
    ) async {
      await pumpHome(tester);

      for (final word in ['faite', 'en partie', 'à faire', 'libre']) {
        expect(
          find.descendant(of: legend, matching: find.text(word)),
          findsOneWidget,
          reason: word,
        );
      }
    });

    testWidgets('should explain the house dots from street zoom, and the '
        'streets again under it', (tester) async {
      await pumpHome(tester);

      shownMap(tester).onZoomChanged!(16);
      await tester.pumpAndSettle();

      for (final word in ['fait', 'personne', 'repasser', 'à faire']) {
        expect(
          find.descendant(of: legend, matching: find.text(word)),
          findsOneWidget,
          reason: word,
        );
      }
      expect(find.text('libre'), findsNothing);

      shownMap(tester).onZoomChanged!(15.5);
      await tester.pumpAndSettle();

      expect(find.text('libre'), findsOneWidget);
    });

    testWidgets('should fold into « Légende » on a tap, and unfold on '
        'another', (tester) async {
      await pumpHome(tester);

      await tester.tap(legend);
      await tester.pumpAndSettle();

      expect(find.text('Légende'), findsOneWidget);
      expect(find.text('libre'), findsNothing);
      expect(
        tester.getSemantics(legend),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          onTapHint: 'Afficher la légende',
          label: 'Légende',
        ),
      );
      expect(tester.getSize(legend).height, greaterThanOrEqualTo(48));

      await tester.tap(legend);
      await tester.pumpAndSettle();

      expect(find.text('libre'), findsOneWidget);
    });
  });

  group('snapPanel', () {
    PanelSize snap(double height, double velocity) =>
        snapPanel(height, velocity, folded: 76, rest: 300, full: 600);

    test('should go to the nearest height on a slow release', () {
      expect(snap(180, 0), PanelSize.folded);
      expect(snap(195, 0), PanelSize.rest);
      expect(snap(440, 0), PanelSize.rest);
      expect(snap(460, 0), PanelSize.full);
    });

    test('should go one step up on a quick flick up', () {
      expect(snap(100, -701), PanelSize.rest);
      expect(snap(300, -701), PanelSize.full);
      expect(snap(100, -700), PanelSize.folded);
    });

    test('should go one step down on a quick flick down', () {
      expect(snap(550, 701), PanelSize.rest);
      expect(snap(300, 701), PanelSize.folded);
      expect(snap(550, 700), PanelSize.full);
    });
  });
}
