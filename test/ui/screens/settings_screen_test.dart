import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/my_sectors/my_sectors_sheet.dart';
import 'package:tournee_calendriers/ui/screens/settings/changelog.dart';
import 'package:tournee_calendriers/ui/screens/settings/changelog_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/privacy_screen.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_reminders.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/clipboard.dart';
import '../support/large_text.dart';
import '../support/navigation.dart';

void main() {
  late FakePhoneSettings settings;
  late FakeSectorRepository sectors;
  late FakeReminderScheduler reminders;
  late FakeReminderPreferences reminderPreferences;

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
    bool notificationsAllowed = true,
  }) async {
    settings = FakePhoneSettings(memberName: nameOf('Manu'));
    reminders = FakeReminderScheduler(allowed: notificationsAllowed);
    reminderPreferences = FakeReminderPreferences();
    // The 49 of Manu, Léa and Julie, Manu on the phone.
    sectors = FakeSectorRepository([team()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakePhone(
            settings: settings,
            sectors: sectors,
            member: manuId,
            account: account,
            admins: FakeAdminStatus(phoneIsAdmin: admin),
            reminders: reminders,
            reminderPreferences: reminderPreferences,
            mySectors: FakeMySectorsStore(
              valueOf(MySectors.none.remember(sector49).open(sector49.id)),
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

  testWidgets('should show the name, the open secteur, the theme and the '
      'credits', (tester) async {
    await pumpSettings(tester);

    expect(find.widgetWithText(AppBar, 'Paramètres'), findsOneWidget);
    expect(find.bySemanticsLabel('Prénom, Manu'), findsOneWidget);
    expect(find.bySemanticsLabel('Mes secteurs, 49 · 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Thème, Système'), findsOneWidget);
    expect(find.bySemanticsLabel('Confidentialité'), findsOneWidget);
    // The version of pubspec.yaml, which `flutter test` gives too.
    expect(
      find.bySemanticsLabel('Version 0.17.0, voir les nouveautés'),
      findsOneWidget,
    );
    // « RAPPELS » (#82) pushed the credits below the screen's edge.
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.credits')),
      100,
    );
    expect(
      find.text(
        'Carte © contributeurs OpenStreetMap, OpenFreeMap. '
        'Adresses : Base Adresse Nationale.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'should say the app works offline under « Mes secteurs », with nothing '
    'to download',
    (tester) async {
      await pumpSettings(tester);

      final line = find.byKey(const Key('settings.offlineLine'));
      expect(
        tester.widget<Text>(line).data,
        "L'application fonctionne sans réseau\u00a0; les modifications sont "
        "envoyées dès qu'il revient.",
      );
      final mySectors = tester.getRect(
        find.byKey(const Key('settings.mySectors')),
      );
      final application = tester.getRect(find.text('APPLICATION'));
      expect(
        tester.getTopLeft(line).dy,
        greaterThanOrEqualTo(mySectors.bottom),
      );
      expect(tester.getBottomLeft(line).dy, lessThan(application.top));
      // The download runs by itself (PLAN §7): no section, no button.
      expect(find.text('HORS-LIGNE'), findsNothing);
      expect(find.text('Mettre à jour'), findsNothing);
      expect(find.text('Supprimer'), findsNothing);
    },
  );

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

  group('a name per secteur', () {
    /// Opens « Prénom », types [name] and saves it.
    Future<void> rename(WidgetTester tester, String name) async {
      await tester.tap(find.byKey(const Key('settings.name')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('name.field')), name);
      await tester.tap(find.byKey(const Key('name.save')));
      await tester.pumpAndSettle();
    }

    testWidgets('should list no names per secteur while each secteur knows '
        'the prénom', (tester) async {
      await pumpSettings(tester);

      expect(find.text('VOS NOMS PAR SECTEUR'), findsNothing);
    });

    testWidgets('should keep the old name where the new one is taken, say so, '
        'then give the name typed for that secteur', (tester) async {
      await pumpSettings(tester);

      // Léa is in the 49.
      await rename(tester, 'LÉA');

      expect(
        find.text(
          '«\u00a0LÉA\u00a0» est déjà pris dans le secteur 49\u00a0: vous y '
          'gardez «\u00a0Manu\u00a0». Il est enregistré partout ailleurs.',
        ),
        findsOneWidget,
      );
      expect(find.text('Votre nom dans le secteur 49'), findsOneWidget);
      final field = find.byKey(const ValueKey('name.sector.t49'));
      expect(tester.widget<TextField>(field).controller!.text, 'Manu');
      expect(settings.names, [nameOf('LÉA')]);

      await tester.enterText(field, 'Manu D.');
      await tester.tap(find.byKey(const Key('name.save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('name.field')), findsNothing);
      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Manu D.'));
      expect(find.text('VOS NOMS PAR SECTEUR'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Secteur 49 · CS Villefranche, Manu D.'),
        findsOneWidget,
      );
    });

    testWidgets('should say when the name typed for the secteur is taken '
        'too, until the next edit', (tester) async {
      await pumpSettings(tester);
      await rename(tester, 'LÉA');
      final field = find.byKey(const ValueKey('name.sector.t49'));

      await tester.enterText(field, 'julie');
      await tester.tap(find.byKey(const Key('name.save')));
      await tester.pumpAndSettle();

      const taken = '«\u00a0julie\u00a0» est déjà pris dans le secteur 49.';
      expect(find.text(taken), findsOneWidget);
      expect(field, findsOneWidget);

      await tester.enterText(field, 'Manu D.');
      await tester.pumpAndSettle();

      expect(find.text(taken), findsNothing);
    });

    testWidgets('should close when the secteur\'s name is left as it '
        'was', (tester) async {
      await pumpSettings(tester);
      await rename(tester, 'LÉA');

      await tester.tap(find.byKey(const Key('name.save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('name.field')), findsNothing);
      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Manu'));
    });

    testWidgets('should say a name for the secteur that cannot be one, and '
        'give the prénom again when it is changed', (tester) async {
      await pumpSettings(tester);
      await rename(tester, 'LÉA');

      await tester.enterText(
        find.byKey(const ValueKey('name.sector.t49')),
        '  ',
      );
      await tester.tap(find.byKey(const Key('name.save')));
      await tester.pumpAndSettle();

      expect(find.text('Écrivez votre prénom.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('name.field')), 'Emmanuel');
      await tester.tap(find.byKey(const Key('name.save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('name.field')), findsNothing);
      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Emmanuel'));
    });

    testWidgets('should say offline and keep the sheet when no secteur can '
        'be reached', (tester) async {
      await pumpSettings(tester);
      sectors.offline = true;

      await rename(tester, 'Emmanuel');

      expect(
        find.text('Pas de réseau. Réessayez une fois connecté.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('name.field')), findsOneWidget);
      expect(settings.names, isEmpty);
    });

    testWidgets('should say offline under the secteur\'s field', (
      tester,
    ) async {
      await pumpSettings(tester);
      await rename(tester, 'LÉA');
      sectors.offline = true;

      await tester.enterText(
        find.byKey(const ValueKey('name.sector.t49')),
        'Manu D.',
      );
      await tester.tap(find.byKey(const Key('name.save')));
      await tester.pumpAndSettle();

      expect(
        find.text('Pas de réseau. Réessayez une fois connecté.'),
        findsOneWidget,
      );
    });

    testWidgets('should close once the member left the secteur', (
      tester,
    ) async {
      await pumpSettings(tester);
      await rename(tester, 'LÉA');
      sectors.lose(sectorId);

      await tester.enterText(
        find.byKey(const ValueKey('name.sector.t49')),
        'Manu D.',
      );
      await tester.tap(find.byKey(const Key('name.save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('name.field')), findsNothing);
    });
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

  testWidgets('should open « Mes secteurs » from its row', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings.mySectors')));
    await tester.pumpAndSettle();

    expect(find.byType(MySectorsSheet), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.licences')),
      100,
    );
    await tester.ensureVisible(find.byKey(const Key('settings.licences')));
    await tester.pumpAndSettle();

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
            'Un bouton copie le code du secteur.',
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
      'Un bouton copie le code du secteur.',
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

    expect(find.bySemanticsLabel('0.17.0 · 13 nov. 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('0.16.1 · 13 nov. 2026'), findsOneWidget);
    // A lazy list: the older versions are built once scrolled to.
    for (final label in [
      '0.16.0 · 12 nov. 2026',
      '0.15.0 · 12 nov. 2026',
      '0.14.0 · 11 nov. 2026',
      '0.13.0 · 11 nov. 2026',
      '0.12.0 · 10 nov. 2026',
      '0.11.0 · 10 nov. 2026',
      '0.10.1 · 3 nov. 2026',
      '0.10.0 · 3 nov. 2026',
    ]) {
      await tester.scrollUntilVisible(find.bySemanticsLabel(label), 100);
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(
      find.bySemanticsLabel(
        "La zone de l'équipe s'appelle maintenant un « secteur » ; une "
        '« tournée » est une sortie dans ce secteur.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Confidentialité : le texte dit aussi ce qui est gardé des '
        'tournées, des dons et des calendriers.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('0.9.0 · 2 nov. 2026'),
      100,
    );
    expect(find.bySemanticsLabel('0.9.0 · 2 nov. 2026'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('0.8.0 · 2 nov. 2026'),
      100,
    );
    expect(find.bySemanticsLabel('0.8.0 · 2 nov. 2026'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel(
        "Paramètres rappelle que l'application fonctionne sans réseau.",
      ),
      100,
    );
    expect(find.bySemanticsLabel('0.7.0 · 2 nov. 2026'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel("La fiche d'une rue sur la carte se ferme avec ✕."),
      100,
    );
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('0.5.1 · 18 oct. 2026'),
      100,
    );
    expect(
      find.bySemanticsLabel(
        'Ajouter une rue depuis la carte est immédiat, et la route touchée '
        "s'allume tout de suite.",
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('0.4.0 · 17 oct. 2026'),
      100,
    );
    expect(find.bySemanticsLabel('0.4.0 · 17 oct. 2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Les fiches des maisons et des portes disent qui les a modifiées en '
        'dernier\u00a0: «\u00a0Modifié par Léa · 14:02\u00a0».',
      ),
      findsOneWidget,
    );
    // The older versions are below the fold once the list grows.
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('0.2.0 · 17 oct. 2026'),
      100,
    );
    expect(find.bySemanticsLabel('0.3.0 · 17 oct. 2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'L\'identifiant de l\'appareil s\'affiche en entier dans '
        'Paramètres et sur l\'écran de bienvenue.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('0.2.0 · 17 oct. 2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Seuls les administrateurs créent un secteur\u00a0; les autres le '
        'rejoignent avec un code.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Première version de test.'),
      100,
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

  group('at 200 % text', () {
    setUpAll(loadAppFonts);

    testWidgets('should show Paramètres with no overflow when the text is '
        'twice as large', (tester) async {
      useLargeText(tester);

      await pumpSettings(tester);

      expect(find.text('Paramètres'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await pumpSettings(tester);

    await expectAccessibleControls(tester);
  });

  group('RAPPELS', () {
    Finder reminderRow() => find.byKey(const Key('settings.reminders'));

    Future<void> showReminders(WidgetTester tester) async {
      await tester.scrollUntilVisible(reminderRow(), 100);
      await tester.pumpAndSettle();
    }

    testWidgets('should show the switch on, and when they ring', (
      tester,
    ) async {
      await pumpSettings(tester);
      await showReminders(tester);

      expect(find.text('RAPPELS'), findsOneWidget);
      expect(find.text('Rappels pour repasser'), findsOneWidget);
      expect(
        find.text(
          '15 min avant l\'heure\u00a0; à 9 h quand il n\'y a pas d\'heure. '
          'Seulement les vôtres.',
        ),
        findsOneWidget,
      );
      final toggle = tester.widget<Switch>(
        find.byKey(const Key('settings.reminders.switch')),
      );
      expect(toggle.value, isTrue);
    });

    testWidgets('should turn them off and keep it', (tester) async {
      await pumpSettings(tester);
      await showReminders(tester);

      await tester.tap(find.byKey(const Key('settings.reminders.switch')));
      await tester.pumpAndSettle();

      expect(reminderPreferences.switched, [false]);
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('settings.reminders.switch')))
            .value,
        isFalse,
      );
      // Nothing rings any more.
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('should say blocked by Android and open its settings', (
      tester,
    ) async {
      await pumpSettings(tester, notificationsAllowed: false);
      await showReminders(tester);

      expect(find.text('Bloqués par Android'), findsOneWidget);
      expect(find.byKey(const Key('settings.reminders.switch')), findsNothing);

      await tester.tap(
        find.byKey(const Key('settings.reminders.openSettings')),
      );
      await tester.pumpAndSettle();

      expect(reminders.settingsOpened, 1);
    });

    testWidgets('should ask Android again back from its settings', (
      tester,
    ) async {
      await pumpSettings(tester, notificationsAllowed: false);
      await showReminders(tester);
      reminders.allowed = true;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Bloqués par Android'), findsNothing);
      expect(
        find.byKey(const Key('settings.reminders.switch')),
        findsOneWidget,
      );
    });
  });
}
