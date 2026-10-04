import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/component_gallery_screen.dart';

import 'support/app_overrides.dart';

void main() {
  testWidgets(
    'should start on home with the French title, theme and locale when the app starts',
    (tester) async {
      // Widgets that read providers need a ProviderScope above them, exactly as
      // bootstrap provides in the real app.
      await tester.pumpWidget(
        ProviderScope(overrides: emptyPhone(), child: const TourneeApp()),
      );

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Tournée des calendriers'),
        ),
        findsOneWidget,
      );
      // The task-switcher title, produced by `onGenerateTitle` from the ARB.
      expect(
        tester.widget<Title>(find.byType(Title)).title,
        'Tournée des calendriers',
      );
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, isFalse);
      expect(app.locale, const Locale('fr'));
      expect(app.supportedLocales, [const Locale('fr')]);
      expect(app.theme!.scaffoldBackgroundColor, const Color(0xFFF3F1EC));
    },
  );

  testWidgets(
    'should open the component gallery from home when the build is a debug build',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: emptyPhone(),
          child: const TourneeApp(showGallery: true),
        ),
      );

      await tester.tap(find.byKey(const Key('home.gallery')));
      await tester.pumpAndSettle();

      expect(find.byType(ComponentGalleryScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Composants'), findsOneWidget);
      // Pushed on top of home, so the app bar offers the way back.
      expect(find.byType(BackButton), findsOneWidget);
    },
  );

  testWidgets(
    'should offer no gallery, not even by its path, when the build is a release build',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: emptyPhone(),
          child: const TourneeApp(showGallery: false),
        ),
      );

      expect(find.byKey(const Key('home.gallery')), findsNothing);

      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go(AppRoutes.gallery);
      await tester.pumpAndSettle();

      expect(find.byType(ComponentGalleryScreen), findsNothing);
    },
  );
}
