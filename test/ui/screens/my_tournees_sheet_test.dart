import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/my_tournees/my_tournees_sheet.dart';
import 'package:tournee_calendriers/ui/screens/settings/settings_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';

/// The 49 (open), the 12 and the pending 7, all of the CS Villefranche.
MyTournees _manusPhone() => valueOf(
  MyTournees.none
      .remember(tournee49)
      .remember(tournee12)
      .remember(tournee7)
      .open(tournee49.id),
);

void main() {
  late FakeMyTourneesStore store;

  Future<void> pumpApp(WidgetTester tester, MyTournees mine) async {
    store = FakeMyTourneesStore(mine);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(myTournees: store),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('home.tournee')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'should show the open tournée and its centre as the title when the '
    'app starts',
    (tester) async {
      await pumpApp(tester, _manusPhone());

      expect(find.text('Tournée 49 · 2026'), findsOneWidget);
      expect(find.text('CS Villefranche'), findsOneWidget);
      expect(find.text('Tournée des calendriers'), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Tournée 49 · 2026, CS Villefranche. Changer de tournée',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'should list the open tournée, the others and the pending request '
    'when the title is tapped',
    (tester) async {
      await pumpApp(tester, _manusPhone());

      await openSheet(tester);

      expect(find.byType(MyTourneesSheet), findsOneWidget);
      expect(find.text('Mes tournées'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Tournée 49 · 2026, CS Villefranche, tournée ouverte',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Tournée 12 · 2026, CS Villefranche, ouvrir'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Tournée 7 · 2026, CS Villefranche, votre demande est en attente',
        ),
        findsOneWidget,
      );
      expect(
        find.text('CS Villefranche · votre demande est en attente'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'should switch to the tournée tapped and keep it for the next launch',
    (tester) async {
      await pumpApp(tester, _manusPhone());
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('myTournees.t12')));
      await tester.pumpAndSettle();

      expect(find.byType(MyTourneesSheet), findsNothing);
      expect(find.text('Tournée 12 · 2026'), findsOneWidget);
      expect(find.text('Tournée 49 · 2026'), findsNothing);
      expect(store.saves.single.current, tournee12);
    },
  );

  testWidgets('should close and keep the tournée when the open one is tapped', (
    tester,
  ) async {
    await pumpApp(tester, _manusPhone());
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('myTournees.t49')));
    await tester.pumpAndSettle();

    expect(find.byType(MyTourneesSheet), findsNothing);
    expect(find.text('Tournée 49 · 2026'), findsOneWidget);
    expect(store.saves, isEmpty);
  });

  testWidgets('should not open a tournée whose request is pending', (
    tester,
  ) async {
    await pumpApp(tester, _manusPhone());
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('myTournees.t7')));
    await tester.pumpAndSettle();

    expect(find.byType(MyTourneesSheet), findsOneWidget);
    expect(store.saves, isEmpty);
  });

  testWidgets(
    'should keep the app name as the title and still offer Paramètres '
    'when no tournée is open',
    (tester) async {
      await pumpApp(tester, MyTournees.none);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Tournée des calendriers'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home.tournee')), findsNothing);

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets('should say there is no tournée yet when the phone knows none', (
    tester,
  ) async {
    await pumpApp(tester, MyTournees.none);
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings.myTournees')));
    await tester.pumpAndSettle();

    expect(find.text("Aucune tournée pour l'instant."), findsOneWidget);
  });
}
