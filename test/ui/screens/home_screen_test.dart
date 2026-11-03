import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/map/sector_area.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/screens/home/home_panel.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/street/street_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show team;
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_pending_sync.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/geo_fixtures.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/fake_map_view.dart';
import '../support/large_text.dart';

/// A street of Villefranche-sur-Saône with [total] houses, the first
/// [done] done.
Street _street(
  String id,
  String name, {
  int done = 0,
  int total = 1,
  StreetShape shape = StreetShape.none,
}) => valueOf(
  Street.create(
    id: StreetId(id),
    name: name,
    commune: villefranche,
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

/// Rue des Lilas (31 of 42 done), Allée des Pins (0 of 8), Rue Pasteur
/// (12 of 12) and Rue Carnot (0 of 38): 43 of 100 doors.
List<Street> _streets() => [
  _street('lilas', 'Rue des Lilas', done: 31, total: 42, shape: _lilasShape),
  _street('pins', 'Allée des Pins', total: 8),
  _street('pasteur', 'Rue Pasteur', done: 12, total: 12),
  _street('carnot', 'Rue Carnot', total: 38),
];

void main() {
  late FakePendingSync pending;

  /// Léa's phone, the size of the mockups' (390 × 844 dp), with [open]
  /// open (the 49 by default) holding [streets].
  Future<void> pumpHome(
    WidgetTester tester, {
    List<Street>? streets,
    SectorSummary? open,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    pending = FakePendingSync();
    final opened = open ?? sector49;
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: FakeStreetRepository(streets ?? _streets()),
          sectors: FakeSectorRepository([team()]),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(opened).open(opened.id)),
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
    testWidgets('should total every street of the secteur over the map '
        '(PLAN §5.14)', (tester) async {
      await pumpHome(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Secteur 49 · 2026'), findsOneWidget);
      expect(find.text('Rues · 43/100'), findsOneWidget);
      expect(find.bySemanticsLabel('Rues, 43 sur 100 faits'), findsOneWidget);
      expect(find.textContaining('Mes rues'), findsNothing);
      expect(find.textContaining('Équipe :'), findsNothing);
      expect(
        tester.getTopLeft(panel()).dy,
        greaterThan(tester.getTopLeft(find.byType(FakeMapView)).dy),
      );
    });

    testWidgets('should say nothing of the offline download (PLAN §5.3, #33)', (
      tester,
    ) async {
      await pumpHome(tester);

      // The tournée downloads itself, unseen: no banner, no button.
      expect(find.textContaining('élécharg'), findsNothing);
      expect(find.textContaining('hors ligne'), findsNothing);
      expect(find.textContaining('réseau'), findsNothing);
    });

    testWidgets('should list every street of the secteur in one list, in '
        'French order, with no section', (tester) async {
      await pumpHome(tester);
      await tester.drag(
        find.byKey(const Key('home.panel.handle')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      expect(top(row('pins')), lessThan(top(row('carnot'))));
      expect(top(row('carnot')), lessThan(top(row('lilas'))));
      expect(top(row('lilas')), lessThan(top(row('pasteur'))));
      expect(find.textContaining('AUTRES RUES'), findsNothing);
      expect(find.textContaining('Autres rues'), findsNothing);
    });

    testWidgets('should mark a complete street with ✓ next to its count, '
        'never colour alone, and keep each row 56 dp high', (tester) async {
      await pumpHome(tester);
      await tester.scrollUntilVisible(row('pasteur'), 100);

      // Rue Pasteur, 12 of 12: ✓ next to its count; Rue des Lilas, 31 of
      // 42: none.
      expect(
        find.descendant(of: row('pasteur'), matching: find.byType(StatusGlyph)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Rue Pasteur, terminée, 12 sur 12 faits'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('carnot'), matching: find.byType(StatusGlyph)),
        findsNothing,
      );
      expect(tester.getSize(row('carnot')).height, greaterThanOrEqualTo(56));
    });

    testWidgets('should open the street when its row is tapped', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(row('lilas'));
      await tester.pumpAndSettle();

      expect(find.byType(StreetScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Rue des Lilas'), findsOneWidget);
    });

    testWidgets('should open any street of the secteur from its row, '
        'with no card', (tester) async {
      await pumpHome(tester);
      await tester.scrollUntilVisible(row('pasteur'), 100);

      await tester.tap(row('pasteur'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.selected')), findsNothing);
      expect(find.byType(StreetScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Rue Pasteur'), findsOneWidget);
    });

    testWidgets('should close the card of a street with the back gesture, '
        'and stay on Accueil', (tester) async {
      await pumpHome(tester);
      shownMap(tester).onStreetTapped!(StreetId('carnot'));
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
      shownMap(tester).onStreetTapped!(StreetId('lilas'));
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

    testWidgets('should say when the secteur has no street', (tester) async {
      await pumpHome(tester, streets: []);

      expect(
        find.text('Aucune rue dans le secteur pour l\'instant.'),
        findsOneWidget,
      );
      expect(find.text('Rues · 0/0'), findsOneWidget);
    });

    testWidgets('should list every street under « Rues » for a visiting '
        'admin', (tester) async {
      await pumpHome(tester, open: sector12Visited);

      expect(find.text('Rues · 43/100'), findsOneWidget);
      expect(find.byKey(const Key('home.adminBanner')), findsOneWidget);
      expect(row('carnot'), findsOneWidget);
    });

    testWidgets('should end the list with the last street: « Ajouter des '
        'rues » is in Secteur', (tester) async {
      await pumpHome(tester);
      await tester.drag(
        find.byKey(const Key('home.panel.handle')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajouter des rues'), findsNothing);
      expect(
        find.descendant(of: panel(), matching: find.byIcon(Icons.add)),
        findsNothing,
      );
      expect(row('lilas'), findsOneWidget);
    });

    testWidgets('should say how many streets wait to be sent while some do, '
        'under the list', (tester) async {
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
      // At the bottom of the panel, under the list and its « Ajouter des
      // rues » row (Home mockup).
      expect(
        tester.getTopLeft(line).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byKey(const Key('home.panel.list'))).dy,
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
          label: 'Rues, 43 sur 100 faits',
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
      expect(find.text('Rues · 43/100'), findsOneWidget);
      expect(row('lilas'), findsNothing);
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
    testWidgets('should draw the secteur\'s streets and open on them', (
      tester,
    ) async {
      final streets = _streets();
      await pumpHome(tester, streets: streets);

      final map = shownMap(tester);

      expect(map.layers.lines.single.street, StreetId('lilas'));
      expect(map.area, sectorArea(streets));
    });

    testWidgets('should show the card of a street tapped on the map in '
        'place of the panel, with its progress and « Ouvrir » only', (
      tester,
    ) async {
      await pumpHome(tester);

      shownMap(tester).onStreetTapped!(StreetId('lilas'));
      await tester.pumpAndSettle();

      expect(panel(), findsNothing);
      expect(find.byKey(const Key('home.selected')), findsOneWidget);
      expect(find.byKey(const Key('streetCard.name')), findsOneWidget);
      expect(find.text('31/42 faits'), findsOneWidget);
      expect(find.bySemanticsLabel('31 sur 42 faits'), findsOneWidget);
      for (final gone in [
        'Libre',
        "Me l'attribuer",
        'La faire aussi',
        'Ne plus la faire',
        'Vous la faites',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }

      await tester.tap(find.byKey(const Key('streetCard.open')));
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

      for (final word in ['faite', 'en partie', 'à faire']) {
        expect(
          find.descendant(of: legend, matching: find.text(word)),
          findsOneWidget,
          reason: word,
        );
      }
      expect(find.text('libre'), findsNothing);
    });

    testWidgets('should explain the house dots from street zoom, and the '
        'streets again under it', (tester) async {
      await pumpHome(tester);

      shownMap(tester).onZoomChanged!(16);
      await tester.pumpAndSettle();

      for (final word in [
        'fait',
        'refusé',
        'personne',
        'repasser',
        'à faire',
      ]) {
        expect(
          find.descendant(of: legend, matching: find.text(word)),
          findsOneWidget,
          reason: word,
        );
      }
      expect(find.text('en partie'), findsNothing);

      shownMap(tester).onZoomChanged!(15.5);
      await tester.pumpAndSettle();

      expect(find.text('en partie'), findsOneWidget);
    });

    testWidgets('should fold into « Légende » on a tap, and unfold on '
        'another', (tester) async {
      await pumpHome(tester);

      await tester.tap(legend);
      await tester.pumpAndSettle();

      expect(find.text('Légende'), findsOneWidget);
      expect(find.text('en partie'), findsNothing);
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

      expect(find.text('en partie'), findsOneWidget);
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

  group('at 200 % text', () {
    setUpAll(loadAppFonts);

    testWidgets('should show Accueil with no overflow when the text is twice '
        'as large', (tester) async {
      useLargeText(tester);

      await pumpHome(tester);

      expect(panel(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('should fold the panel taller, still holding the totals, '
        'when the text is twice as large', (tester) async {
      useLargeText(tester);
      await pumpHome(tester);

      await tester.drag(
        find.byKey(const Key('home.panel.handle')),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      final folded = homePanelFoldedHeight(const TextScaler.linear(2));
      expect(folded, greaterThan(AppSizes.homePanelFolded + 20));
      expect(tester.getSize(panel()).height, folded);
      expect(find.text('Rues · 43/100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('should fold the panel to its mockup height when the text is not '
      'scaled', () {
    expect(
      homePanelFoldedHeight(TextScaler.noScaling),
      AppSizes.homePanelFolded,
    );
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await pumpHome(tester);

    await expectAccessibleControls(tester);
  });
}
