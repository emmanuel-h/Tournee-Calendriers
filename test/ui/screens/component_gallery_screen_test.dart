import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/components/status_tile.dart';
import 'package:tournee_calendriers/ui/screens/component_gallery_screen.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

import '../support/finders.dart';
import '../support/test_app.dart';

void main() {
  // A tall surface so the whole gallery is built without scrolling.
  Future<void> pumpGallery(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const ComponentGalleryScreen()));
  }

  testWidgets(
    'should render buttons, section headers and every tile when the gallery opens',
    (tester) async {
      await pumpGallery(tester);

      // Section headers: written normally, shown in capitals.
      expect(find.byType(SectionHeader), findsNWidgets(3));
      expect(find.text('BOUTONS'), findsOneWidget);
      expect(find.text('TUILES DE STATUT'), findsOneWidget);

      // Buttons: 56 dp, or 52 dp when compact; null `onPressed` disables.
      expect(
        tester.getSize(find.widgetWithText(PrimaryButton, 'Bouton principal')),
        isA<Size>().having((s) => s.height, 'height', 56),
      );
      expect(
        tester.getSize(
          find.widgetWithText(SecondaryButton, 'Bouton secondaire'),
        ),
        isA<Size>().having((s) => s.height, 'height', 56),
      );
      expect(
        tester.getSize(find.widgetWithText(PrimaryButton, 'Bouton compact')),
        isA<Size>().having((s) => s.height, 'height', 52),
      );
      expect(
        tester.getSize(find.widgetWithText(SecondaryButton, 'Bouton compact')),
        isA<Size>().having((s) => s.height, 'height', 52),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Bouton désactivé'),
            )
            .enabled,
        isFalse,
      );

      // One tile per status.
      expect(find.byType(StatusTile), findsNWidgets(5));
      expect(
        tester
            .widgetList<StatusGlyph>(find.byType(StatusGlyph))
            .map((g) => g.glyph),
        StatusGlyphs.values,
      );
      expect(find.text('7/12'), findsOneWidget);
    },
  );

  testWidgets(
    'should open the sample sheet and the undo snackbar when their buttons are tapped',
    (tester) async {
      await pumpGallery(tester);

      await tester.tap(find.byKey(const Key('gallery.showSheet')));
      await tester.pumpAndSettle();

      expect(find.byType(SheetScaffold), findsOneWidget);
      expect(find.text('Rue des Lilas'), findsOneWidget);
      expect(
        find.text('Le contenu de la feuille se place ici.'),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SheetScaffold),
          matching: find.byType(PrimaryButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SheetScaffold), findsNothing);

      await tester.tap(find.byKey(const Key('gallery.showSnackBar')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: findArrowText('7 → Personne'),
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(SnackBarAction, 'Annuler'), findsOneWidget);

      // Gone after its 4 s, although it has an action.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );
}
