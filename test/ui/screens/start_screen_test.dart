import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_screen.dart';
import 'package:tournee_calendriers/ui/screens/placeholder_screen.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

Street _street(String id, String name, {int done = 0, int total = 1}) =>
    valueOf(
      Street.create(
        id: StreetId(id),
        name: name,
        commune: villefranche,
        houses: [
          for (var i = 1; i <= total; i++)
            House(
              number: n('$i'),
              status: i <= done ? VisitStatus.done : VisitStatus.toDo,
            ),
        ],
      ),
    );

void main() {
  Future<void> pumpApp(WidgetTester tester, List<Street> streets) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(streets: FakeStreetRepository(streets)),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'should invite to import and open the import screen when no street is on the phone',
    (tester) async {
      await pumpApp(tester, []);

      expect(find.text("Aucune rue pour l'instant"), findsOneWidget);
      expect(
        find.text(
          "Importez les rues d'une commune pour commencer. Il faut le réseau "
          'une fois ; ensuite tout fonctionne hors ligne.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('start.import')));
      await tester.pumpAndSettle();

      expect(find.byType(ImportScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Importer des rues'), findsOneWidget);
    },
  );

  testWidgets(
    'should list the streets in French order with their progress when some are imported',
    (tester) async {
      await pumpApp(tester, [
        _street('nationale', 'Rue Nationale', done: 31, total: 40),
        _street('morin', 'Rue Pierre Morin', total: 3),
        _street('eglise', "Place de l'Église", done: 8, total: 8),
      ]);

      expect(find.text('Mes rues · 3'), findsOneWidget);
      expect(find.text('Villefranche-sur-Saône'), findsOneWidget);
      expect(find.text("Aucune rue pour l'instant"), findsNothing);
      final rows = [
        "Place de l'Église, terminée, 8 sur 8 faits",
        'Rue Nationale, 31 sur 40 faits',
        'Rue Pierre Morin, 0 sur 3 faits',
      ].map((label) => tester.getTopLeft(find.bySemanticsLabel(label)).dy);
      expect(rows.toList(), orderedEquals(rows.toList()..sort()));
      expect(find.text('31/40'), findsOneWidget);
      // Complete: the ✓ glyph next to the count, never colour alone.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('start.street.eglise')),
          matching: find.byType(StatusGlyph),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('start.street.nationale')),
          matching: find.byType(StatusGlyph),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('start.street.morin'))).height,
        greaterThanOrEqualTo(56),
      );
    },
  );

  testWidgets(
    'should keep only the matching streets when a filter is typed without accents',
    (tester) async {
      await pumpApp(tester, [
        _street('nationale', 'Rue Nationale'),
        _street('eglise', "Place de l'Église"),
      ]);

      await tester.enterText(find.byKey(const Key('start.filter')), 'eglise');
      await tester.pump();

      expect(find.text("Place de l'Église"), findsOneWidget);
      expect(find.text('Rue Nationale'), findsNothing);

      await tester.enterText(find.byKey(const Key('start.filter')), 'lilas');
      await tester.pump();

      expect(
        find.text('Aucune rue ne correspond à « lilas ».'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'should open the street with its name as title when a row is tapped',
    (tester) async {
      await pumpApp(tester, [_street('nationale', 'Rue Nationale')]);

      await tester.tap(find.byKey(const ValueKey('start.street.nationale')));
      await tester.pumpAndSettle();

      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Rue Nationale'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    },
  );
}
