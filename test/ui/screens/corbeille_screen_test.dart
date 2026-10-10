import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../application/use_cases/street_fixtures.dart';
import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show n, villefranche;
import '../support/app_overrides.dart';
import '../support/navigation.dart';

/// Wednesday 4 November 2026, 10:00 on the phone's clock.
final now = DateTime(2026, 11, 4, 10);

/// The Rue des Lilas with its number 7 removed by Léa ten minutes ago.
Street lilasWithoutSeven() => valueOf(
  lilas.removeNumber(
    n('7'),
    by: leaId,
    at: now.subtract(const Duration(minutes: 10)),
  ),
).$1;

/// Rue Gambetta (two numbers), deleted on 3 October by Paul, who has left
/// the team since.
Street gambettaDeleted() => valueOf(
  Street.create(
    id: StreetId('gambetta'),
    name: 'Rue Gambetta',
    commune: villefranche,
    houses: lilas.houses.take(2),
  ),
).delete(by: paulId, at: DateTime(2026, 10, 3, 18)).$1;

void main() {
  late FakeStreetRepository streets;

  /// The Corbeille, opened from Équipe of the 49, on Manu's phone holding
  /// [stored].
  Future<void> pumpCorbeille(
    WidgetTester tester,
    Iterable<Street> stored,
  ) async {
    streets = FakeStreetRepository(stored);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          myTournees: FakeMyTourneesStore(
            valueOf(MyTournees.none.remember(tournee49).open(tournee49.id)),
          ),
          tournees: FakeTourneeRepository([team()]),
          member: manuId,
          now: now,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaitedPush(router, AppRoutes.team);
    await tester.pumpAndSettle();
    unawaitedPush(router, AppRoutes.trash);
    await tester.pumpAndSettle();
  }

  Finder row(String key) => find.byKey(ValueKey('corbeille.$key'));

  testWidgets('should list the deleted street and number with who deleted '
      'them and when, the latest first', (tester) async {
    await pumpCorbeille(tester, [gambettaDeleted(), lilasWithoutSeven()]);

    expect(find.widgetWithText(AppBar, 'Corbeille'), findsOneWidget);
    expect(
      find.text(
        'Les rues et numéros supprimés sont gardés 30 jours avec leurs '
        'statuts, puis supprimés définitivement.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row('rue-des-lilas.7'),
        matching: find.text('7 Rue des Lilas'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row('rue-des-lilas.7'),
        matching: find.text('supprimé par Léa · il y a 10 min'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('gambetta'), matching: find.text('Rue Gambetta')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row('gambetta'),
        matching: find.text('2 numéros · supprimée par un membre · 3 oct.'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(row('rue-des-lilas.7')).dy,
      lessThan(tester.getTopLeft(row('gambetta')).dy),
    );
  });

  testWidgets('should bring the number back with its marks when « Restaurer » '
      'is tapped', (tester) async {
    await pumpCorbeille(tester, [lilasWithoutSeven()]);

    await tester.tap(find.bySemanticsLabel('Restaurer 7 Rue des Lilas'));
    await tester.pumpAndSettle();

    final (restored, change) = streets.saved.single;
    expect(change, isA<NumberRestored>());
    expect((change as NumberRestored).number, n('7'));
    expect(restored.houseAt(n('7')), lilas.houseAt(n('7')));
    expect(row('rue-des-lilas.7'), findsNothing);
    expect(find.text('La corbeille est vide.'), findsOneWidget);
  });

  testWidgets('should bring the street back when « Restaurer » is tapped', (
    tester,
  ) async {
    await pumpCorbeille(tester, [gambettaDeleted()]);

    await tester.tap(find.bySemanticsLabel('Restaurer Rue Gambetta'));
    await tester.pumpAndSettle();

    expect(
      streets.saved.single.$2,
      StreetRestored(streetId: StreetId('gambetta')),
    );
    expect(streets[StreetId('gambetta')]!.isDeleted, isFalse);
    expect(row('gambetta'), findsNothing);
  });

  testWidgets('should count the items in Équipe', (tester) async {
    await pumpCorbeille(tester, [gambettaDeleted(), lilasWithoutSeven()]);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Corbeille · 2 éléments'), findsOneWidget);
  });
}
