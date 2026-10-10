import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/my_tournees/my_tournees_sheet.dart';
import 'package:tournee_calendriers/ui/screens/settings/privacy_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/navigation.dart';

void main() {
  late FakePhoneSettings settings;

  /// Paramètres over the start screen, on a phone where Manu has the 49
  /// open.
  Future<void> pumpSettings(WidgetTester tester) async {
    settings = FakePhoneSettings(memberName: nameOf('Manu'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          settings: settings,
          myTournees: FakeMyTourneesStore(
            valueOf(MyTournees.none.remember(tournee49).open(tournee49.id)),
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    unawaitedPush(
      GoRouter.of(tester.element(find.byType(Scaffold).first)),
      AppRoutes.settings,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('should show the name, the open tournée, the theme and the '
      'credits', (tester) async {
    await pumpSettings(tester);

    expect(find.widgetWithText(AppBar, 'Paramètres'), findsOneWidget);
    expect(find.bySemanticsLabel('Prénom, Manu'), findsOneWidget);
    expect(find.bySemanticsLabel('Mes tournées, 49 · 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Thème, Système'), findsOneWidget);
    expect(find.bySemanticsLabel('Confidentialité'), findsOneWidget);
    // The version of pubspec.yaml, which `flutter test` gives too.
    expect(
      find.bySemanticsLabel('Version 1.0.0, voir les licences'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Carte © contributeurs OpenStreetMap, OpenFreeMap. '
        'Adresses : Base Adresse Nationale.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('should keep the new name when saved', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings.name')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name.field')), ' Emmanuel ');
    await tester.tap(find.byKey(const Key('name.save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('name.field')), findsNothing);
    expect(find.bySemanticsLabel('Prénom, Emmanuel'), findsOneWidget);
    expect(settings.names, [nameOf('Emmanuel')]);
  });

  testWidgets('should say why and keep the sheet when the name is blank', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings.name')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name.field')), '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Écrivez votre prénom.'), findsOneWidget);
    expect(find.byKey(const Key('name.field')), findsOneWidget);
    expect(settings.names, isEmpty);

    await tester.enterText(find.byKey(const Key('name.field')), 'a' * 31);
    await tester.tap(find.byKey(const Key('name.save')));
    await tester.pumpAndSettle();

    expect(find.text('Prénom limité à 30 caractères.'), findsOneWidget);
    expect(find.text('Écrivez votre prénom.'), findsNothing);
    expect(settings.names, isEmpty);
  });

  testWidgets('should redraw the app in the theme chosen', (tester) async {
    await pumpSettings(tester);
    MaterialApp app() => tester.widget(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.system);

    for (final (key, mode, choice, label) in [
      ('theme.dark', ThemeMode.dark, ThemeChoice.dark, 'Thème, Sombre'),
      ('theme.light', ThemeMode.light, ThemeChoice.light, 'Thème, Clair'),
      ('theme.system', ThemeMode.system, ThemeChoice.system, 'Thème, Système'),
    ]) {
      await tester.tap(find.byKey(const Key('settings.theme')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();

      expect(app().themeMode, mode, reason: key);
      expect(settings.themes.last, choice, reason: key);
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: key);
    }
  });

  testWidgets('should open « Mes tournées » from its row', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings.myTournees')));
    await tester.pumpAndSettle();

    expect(find.byType(MyTourneesSheet), findsOneWidget);
  });

  testWidgets('should open the privacy page', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings.privacy')));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Confidentialité'), findsOneWidget);
    expect(find.text('DONNÉES ENREGISTRÉES'), findsOneWidget);
  });

  testWidgets('should open the licences from the version', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings.version')));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
