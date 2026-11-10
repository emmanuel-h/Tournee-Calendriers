import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/sector_downloads.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/all_sectors/all_sectors_screen.dart';
import 'package:tournee_calendriers/ui/screens/my_sectors/my_sectors_sheet.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/create_sector_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_sector_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/name_sheet.dart';
import 'package:tournee_calendriers/ui/screens/settings/settings_screen.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show nameOf, samId, team;
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/fakes/fake_sector_downloads.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_server_connection.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/large_text.dart';

/// The 49 (open), the 12 and the pending 7, all of the CS Villefranche.
MySectors _manusPhone() => valueOf(
  MySectors.none
      .remember(sector49)
      .remember(sector12)
      .remember(sector7)
      .open(sector49.id),
);

void main() {
  late FakeMySectorsStore store;
  late FakePhoneSettings settings;

  /// The app on a phone keeping [mine]; an admin's when [admin] says so.
  Future<void> pumpApp(
    WidgetTester tester,
    MySectors mine, {
    MemberName? name,
    FakeSectorRepository? sectors,
    bool admin = false,
    bool offline = false,
    Iterable<SectorId> downloaded = const [],
  }) async {
    store = FakeMySectorsStore(mine);
    settings = FakePhoneSettings(memberName: name);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          mySectors: store,
          settings: settings,
          sectors: sectors,
          admins: FakeAdminStatus(phoneIsAdmin: admin),
          account: FakeMemberAccount(signedInMember: samId),
          sectorDirectory: FakeSectorDirectory(),
          connection: FakeServerConnection(offline: offline),
          downloads: FakeSectorDownloads([
            for (final sector in downloaded)
              SectorDownload(
                sector: sector,
                downloadedAt: DateTime.utc(2026, 11, 2, 8, 12),
                mapBytes: 34000000,
                area: null,
              ),
          ]),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens « Mes secteurs » as a member does with a secteur open (#135):
  /// the title opens Secteur, whose first row is « Changer de secteur ».
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('home.sector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('team.changeSector')));
    await tester.pumpAndSettle();
  }

  /// From Secteur, where « Changer de secteur » is, back to Accueil.
  Future<void> backToAccueil(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'should show the open tournée and its centre as the title when the '
    'app starts',
    (tester) async {
      await pumpApp(tester, _manusPhone());

      expect(find.text('Secteur 49 · 2026'), findsOneWidget);
      expect(find.text('CS Villefranche'), findsOneWidget);
      expect(find.text('Tournée des calendriers'), findsNothing);
      expect(
        find.bySemanticsLabel('Secteur 49 · 2026, CS Villefranche'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'should list the open tournée, the others and the pending request '
    'when « Changer de secteur » is tapped',
    (tester) async {
      await pumpApp(tester, _manusPhone());

      await openSheet(tester);

      expect(find.byType(MySectorsSheet), findsOneWidget);
      expect(find.text('Mes secteurs'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Secteur 49 · 2026, CS Villefranche, secteur ouvert',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Secteur 12 · 2026, CS Villefranche, ouvrir'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Secteur 7 · 2026, CS Villefranche, votre demande est en attente',
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
    'should show a dot and the count on another tournée where a request '
    'waits',
    (tester) async {
      // The 49, with Julie's request waiting, is not the open one.
      await pumpApp(
        tester,
        valueOf(_manusPhone().open(sector12.id)),
        sectors: FakeSectorRepository([team()]),
      );

      await openSheet(tester);

      expect(
        find.text('CS Villefranche · 1 demande en attente'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Secteur 49 · 2026, CS Villefranche, 1 demande en attente, ouvrir',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mySectors.t49.dot')), findsOneWidget);
      expect(find.byKey(const Key('mySectors.t12.dot')), findsNothing);
    },
  );

  testWidgets(
    'should switch to the tournée tapped and keep it for the next launch',
    (tester) async {
      await pumpApp(tester, _manusPhone());
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('mySectors.t12')));
      await tester.pumpAndSettle();

      expect(find.byType(MySectorsSheet), findsNothing);
      expect(store.saves.single.current, sector12);
      await backToAccueil(tester);
      expect(find.text('Secteur 12 · 2026'), findsOneWidget);
      expect(find.text('Secteur 49 · 2026'), findsNothing);
    },
  );

  testWidgets('should close and keep the tournée when the open one is tapped', (
    tester,
  ) async {
    await pumpApp(tester, _manusPhone());
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('mySectors.t49')));
    await tester.pumpAndSettle();

    expect(find.byType(MySectorsSheet), findsNothing);
    expect(store.saves, isEmpty);
    await backToAccueil(tester);
    expect(find.text('Secteur 49 · 2026'), findsOneWidget);
  });

  testWidgets('should not open a tournée whose request is pending', (
    tester,
  ) async {
    await pumpApp(tester, _manusPhone());
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('mySectors.t7')));
    await tester.pumpAndSettle();

    expect(find.byType(MySectorsSheet), findsOneWidget);
    expect(store.saves, isEmpty);
  });

  group('offline (PLAN §5.3, #33)', () {
    const unavailable12 =
        'Secteur 12 · 2026, CS Villefranche, disponible avec réseau';

    testWidgets('should leave a tournée not downloaded as it is when online', (
      tester,
    ) async {
      await pumpApp(tester, _manusPhone());
      await openSheet(tester);

      expect(
        find.bySemanticsLabel('Secteur 12 · 2026, CS Villefranche, ouvrir'),
        findsOneWidget,
      );
      expect(find.textContaining('Disponible avec réseau'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('mySectors.t12')));
      await tester.pumpAndSettle();

      expect(store.saves.single.current, sector12);
    });

    testWidgets('should still open a downloaded tournée when offline', (
      tester,
    ) async {
      await pumpApp(
        tester,
        _manusPhone(),
        offline: true,
        downloaded: [sector12.id],
      );
      await openSheet(tester);

      expect(find.textContaining('Disponible avec réseau'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('mySectors.t12')));
      await tester.pumpAndSettle();

      expect(find.byType(MySectorsSheet), findsNothing);
      expect(store.saves.single.current, sector12);
    });

    testWidgets(
      'should grey a tournée not downloaded and not open it when offline',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpApp(tester, _manusPhone(), offline: true);
        await openSheet(tester);

        expect(
          find.text('CS Villefranche · Disponible avec réseau'),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(unavailable12)),
          isSemantics(
            label: unavailable12,
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        final title = tester.widget<Text>(find.text('Secteur 12 · 2026'));
        expect(title.style?.color, AppColors.light.unavailable);

        await tester.tap(find.byKey(const ValueKey('mySectors.t12')));
        await tester.pumpAndSettle();

        expect(find.byType(MySectorsSheet), findsOneWidget);
        expect(store.saves, isEmpty);
        semantics.dispose();
      },
    );

    testWidgets(
      'should grey a tournée where a request waits without its dot when '
      'offline',
      (tester) async {
        await pumpApp(
          tester,
          valueOf(_manusPhone().open(sector12.id)),
          sectors: FakeSectorRepository([team()]),
          offline: true,
        );
        await openSheet(tester);

        expect(
          find.bySemanticsLabel(
            'Secteur 49 · 2026, CS Villefranche, disponible avec réseau',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mySectors.t49.dot')), findsNothing);
      },
    );

    testWidgets(
      'should never grey the open tournée nor a pending request when offline',
      (tester) async {
        await pumpApp(tester, _manusPhone(), offline: true);
        await openSheet(tester);

        expect(
          find.bySemanticsLabel(
            'Secteur 49 · 2026, CS Villefranche, secteur ouvert',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Secteur 7 · 2026, CS Villefranche, votre demande est en attente',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Disponible avec réseau'),
          findsOneWidget, // the 12 only
        );
      },
    );
  });

  testWidgets(
    'should keep the app name as the title and still offer Paramètres '
    'when no tournée is open',
    (tester) async {
      await pumpApp(tester, MySectors.none);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Tournée des calendriers'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home.sector')), findsNothing);

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets('should say there is no tournée yet when the phone knows none', (
    tester,
  ) async {
    await pumpApp(tester, MySectors.none);
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings.mySectors')));
    await tester.pumpAndSettle();

    expect(find.text("Aucun secteur pour l'instant."), findsOneWidget);
  });

  testWidgets(
    'should open the sheet from the app\'s name when no tournée is open',
    (tester) async {
      await pumpApp(tester, MySectors.none);

      await tester.tap(find.byKey(const Key('home.appTitle')));
      await tester.pumpAndSettle();

      expect(find.byType(MySectorsSheet), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tournée des calendriers. Mes secteurs'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'should open « Nouveau secteur » from the sheet, the open tournée kept',
    (tester) async {
      await pumpApp(tester, _manusPhone(), name: nameOf('Manu'), admin: true);
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('mySectors.create')));
      await tester.pumpAndSettle();

      expect(find.byType(MySectorsSheet), findsNothing);
      expect(find.byType(CreateSectorScreen), findsOneWidget);
      expect(store.saves, isEmpty);
    },
  );

  testWidgets('should ask the name first when the phone has none, then open '
      '« Rejoindre un secteur »', (tester) async {
    await pumpApp(tester, _manusPhone());
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('mySectors.join')));
    await tester.pumpAndSettle();
    expect(find.byType(NameSheet), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name.field')), 'Manu');
    await tester.tap(find.byKey(const Key('name.save')));
    await tester.pumpAndSettle();

    expect(settings.names, [nameOf('Manu')]);
    expect(find.byType(JoinSectorScreen), findsOneWidget);
  });

  testWidgets('should open nothing when the name sheet is closed without one', (
    tester,
  ) async {
    await pumpApp(tester, _manusPhone(), admin: true);
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('mySectors.create')));
    await tester.pumpAndSettle();

    // A tap on the dimmed screen above the sheet closes it.
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(find.byType(NameSheet), findsNothing);
    expect(find.byType(CreateSectorScreen), findsNothing);
    expect(find.byType(TeamScreen), findsOneWidget);
  });

  group('admins (PLAN §5.12)', () {
    testWidgets('should offer neither « Créer » nor « Tous les secteurs » '
        'to a phone that is not an admin\'s', (tester) async {
      await pumpApp(tester, _manusPhone());
      await openSheet(tester);

      expect(find.byKey(const Key('mySectors.create')), findsNothing);
      expect(find.byKey(const Key('mySectors.all')), findsNothing);
      expect(find.byKey(const Key('mySectors.join')), findsOneWidget);
    });

    testWidgets('should open « Tous les secteurs » for an admin', (
      tester,
    ) async {
      await pumpApp(tester, _manusPhone(), name: nameOf('Sam'), admin: true);
      await openSheet(tester);

      expect(find.byKey(const Key('mySectors.create')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mySectors.all')));
      await tester.pumpAndSettle();

      expect(find.byType(AllSectorsScreen), findsOneWidget);
    });

    testWidgets('should show a visited tournée with a shield and '
        '« administrateur »', (tester) async {
      await pumpApp(
        tester,
        valueOf(
          MySectors.none
              .remember(sector49)
              .remember(summaryOf('t12', 12, status: MemberStatus.visiting))
              .open(sector49.id),
        ),
        admin: true,
      );
      await openSheet(tester);

      expect(find.text('CS Villefranche · administrateur'), findsOneWidget);
      expect(find.byKey(const Key('mySectors.t12.shield')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Secteur 12 · 2026, CS Villefranche, administrateur, ouvrir',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('mySectors.t12')));
      await tester.pumpAndSettle();

      expect(store.mySectors.currentId, sector12.id);
    });

    testWidgets(
      'should grey a visited tournée and its shield when offline and not '
      'downloaded',
      (tester) async {
        await pumpApp(
          tester,
          valueOf(
            MySectors.none
                .remember(sector49)
                .remember(summaryOf('t12', 12, status: MemberStatus.visiting))
                .open(sector49.id),
          ),
          admin: true,
          offline: true,
        );
        await openSheet(tester);

        expect(
          find.text('CS Villefranche · Disponible avec réseau'),
          findsOneWidget,
        );
        final shield = tester.widget<Icon>(
          find.byKey(const Key('mySectors.t12.shield')),
        );
        expect(shield.color, AppColors.light.unavailableMark);
      },
    );

    testWidgets('should say an open visited tournée is open', (tester) async {
      await pumpApp(
        tester,
        valueOf(
          MySectors.none
              .remember(summaryOf('t12', 12, status: MemberStatus.visiting))
              .open(sector12.id),
        ),
        admin: true,
      );
      await openSheet(tester);

      expect(
        find.bySemanticsLabel(
          'Secteur 12 · 2026, CS Villefranche, administrateur, secteur '
          'ouvert',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await pumpApp(tester, _manusPhone());
    await openSheet(tester);

    await expectAccessibleControls(tester);
  });
}
