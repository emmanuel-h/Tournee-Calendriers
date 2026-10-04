import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/placeholder_screen.dart';

import '../support/app_overrides.dart';

void main() {
  testWidgets(
    'should show the French screen name when each screen of PLAN §5 is opened',
    (tester) async {
      const expectedTitles = {
        AppRoutes.welcome: 'Bienvenue',
        AppRoutes.create: 'Nouvelle tournée',
        AppRoutes.join: 'Rejoindre une tournée',
        AppRoutes.joinPending: 'Demande envoyée',
        AppRoutes.addStreets: 'Ajouter des rues',
        AppRoutes.manualStreet: 'Rue à la main',
        AppRoutes.street: 'Rue',
        AppRoutes.editStreet: 'Modifier la rue',
        AppRoutes.team: 'Équipe',
        AppRoutes.settings: 'Paramètres',
        AppRoutes.newCampaign: 'Nouvelle campagne',
        AppRoutes.trash: 'Corbeille',
      };
      await tester.pumpWidget(
        ProviderScope(overrides: emptyPhone(), child: const TourneeApp()),
      );
      final router = GoRouter.of(tester.element(find.byType(Scaffold)));

      for (final MapEntry(key: path, value: title) in expectedTitles.entries) {
        router.go(path);
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(AppBar, title),
          findsOneWidget,
          reason: 'route $path',
        );
        expect(find.byType(PlaceholderScreen), findsOneWidget);
      }
    },
  );
}
