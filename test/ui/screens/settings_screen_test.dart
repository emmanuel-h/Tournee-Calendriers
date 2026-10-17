import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/my_tournees/my_tournees_sheet.dart';
import 'package:tournee_calendriers/ui/screens/settings/changelog.dart';
import 'package:tournee_calendriers/ui/screens/settings/changelog_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/privacy_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/clipboard.dart';
import '../support/navigation.dart';

void main() {
  late FakePhoneSettings settings;

  /// Paramètres over the start screen, on a phone where Manu has the 49
  /// open.
  ///
  /// [releases] replaces the versions shipped with the app in
  /// « Nouveautés ».
  Future<void> pumpSettings(
    WidgetTester tester, {
    List<Release>? releases,
    FakeMemberAccount? account,
    bool admin = false,
  }) async {
    settings = FakePhoneSettings(memberName: nameOf('Manu'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakePhone(
            settings: settings,
            account: account,
            admins: FakeAdminStatus(phoneIsAdmin: admin),
            myTournees: FakeMyTourneesStore(
              valueOf(MyTournees.none.remember(tournee49).open(tournee49.id)),
            ),
          ),
          if (releases != null) changelogProvider.overrideWithValue(releases),
        ],
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
      find.bySemanticsLabel('Version 0.2.0, voir les nouveautés'),
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

  testWidgets('should open the licences from their own row', (tester) async {
    await pumpSettings(tester);

    expect(find.bySemanticsLabel('Licences'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings.licences')));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.byType(ChangelogScreen), findsNothing);
  });

  testWidgets('should open « Nouveautés » with the newest version first '
      'when the version is tapped', (tester) async {
    await pumpSettings(
      tester,
      releases: [
        Release(
          version: '1.2.0',
          date: DateTime(2027, 3, 5),
          notes: (_) => ['Une rue se partage en deux.'],
        ),
        Release(
          version: '1.1.0',
          date: DateTime(2026, 11, 20),
          notes: (_) => [
            'Un bouton copie le code de la tournée.',
            "Le nombre de passages s'affiche pour chaque rue.",
          ],
        ),
        Release(
          version: '1.0.0',
          date: DateTime(2026, 10, 16),
          notes: (_) => ['Première version.'],
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('settings.version')));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsNothing);
    expect(find.widgetWithText(AppBar, 'Nouveautés'), findsOneWidget);
    // Top to bottom: each version, its date, then its lines.
    final shown = [
      '1.2.0 · 5 mars 2027',
      'Une rue se partage en deux.',
      '1.1.0 · 20 nov. 2026',
      'Un bouton copie le code de la tournée.',
      "Le nombre de passages s'affiche pour chaque rue.",
      '1.0.0 · 16 oct. 2026',
      'Première version.',
    ];
    final tops = [
      for (final text in shown)
        tester.getTopLeft(find.bySemanticsLabel(text)).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: shown[i]);
    }
  });

  testWidgets('should list the versions shipped with the app', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings.version')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('0.2.0 · 17 oct. 2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Seuls les administrateurs créent une tournée\u00a0; les autres la '
        'rejoignent avec un code.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('0.1.0 · 16 oct. 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Première version de test.'), findsOneWidget);
  });

  group('Identifiant de l\'appareil (PLAN §5.12)', () {
    final uid = MemberId('x7FqA1b2C3d4E5f6G7h8I9j0k9kP2');
    final row = find.byKey(const Key('settings.deviceId'));

    Future<void> scrollToIt(WidgetTester tester) async {
      // The screen's list: the selectable uid has a scrollable of its own.
      await tester.scrollUntilVisible(
        row,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('should show the whole device id and copy it', (tester) async {
      final clipboard = FakeClipboard.install(tester);
      await pumpSettings(
        tester,
        account: FakeMemberAccount(signedInMember: uid),
      );
      await scrollToIt(tester);

      expect(find.text(uid.value), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings.copyDeviceId')));
      await tester.pump();

      expect(clipboard.text, uid.value);
      expect(find.text('Identifiant copié'), findsOneWidget);
    });

    testWidgets('should say administrateur on an admin\'s phone', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        account: FakeMemberAccount(signedInMember: uid),
        admin: true,
      );
      await scrollToIt(tester);

      expect(find.text(uid.value), findsOneWidget);
      expect(find.text('Administrateur'), findsOneWidget);
    });

    testWidgets('should sign in when it opens, then show the device id', (
      tester,
    ) async {
      final account = FakeMemberAccount(nextMember: uid);
      await pumpSettings(tester, account: account);
      await scrollToIt(tester);

      expect(account.signInCalls, greaterThanOrEqualTo(1));
      expect(find.text(uid.value), findsOneWidget);
    });

    testWidgets('should say there is no account yet offline, with nothing '
        'to copy', (tester) async {
      await pumpSettings(tester, account: FakeMemberAccount());
      await scrollToIt(tester);

      expect(
        find.text('Pas encore de compte\u00a0: connectez-vous au réseau.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings.copyDeviceId')), findsNothing);
    });

    testWidgets('should say it is signing in while the sign-in is on its '
        'way', (tester) async {
      final account = FakeMemberAccount(nextMember: uid)
        ..gate = Completer<void>();
      await pumpSettings(tester, account: account);
      await scrollToIt(tester);

      expect(find.text('Connexion au serveur…'), findsOneWidget);
      account.gate.complete();
      await tester.pumpAndSettle();
    });
  });
}
