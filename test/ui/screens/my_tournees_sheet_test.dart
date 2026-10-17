import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/all_tournees/all_tournees_screen.dart';
import 'package:tournee_calendriers/ui/screens/my_tournees/my_tournees_sheet.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/create_tournee_screen.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/join_tournee_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/name_sheet.dart';
import 'package:tournee_calendriers/ui/screens/settings/settings_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart' show nameOf, samId, team;
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/fakes/fake_tournee_repository.dart';
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
  late FakePhoneSettings settings;

  /// The app on a phone keeping [mine]; an admin's when [admin] says so.
  Future<void> pumpApp(
    WidgetTester tester,
    MyTournees mine, {
    MemberName? name,
    FakeTourneeRepository? tournees,
    bool admin = false,
  }) async {
    store = FakeMyTourneesStore(mine);
    settings = FakePhoneSettings(memberName: name);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          myTournees: store,
          settings: settings,
          tournees: tournees,
          admins: FakeAdminStatus(phoneIsAdmin: admin),
          account: FakeMemberAccount(signedInMember: samId),
          tourneeDirectory: FakeTourneeDirectory(),
        ),
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
    'should show a dot and the count on another tournée where a request '
    'waits',
    (tester) async {
      // The 49, with Julie's request waiting, is not the open one.
      await pumpApp(
        tester,
        valueOf(_manusPhone().open(tournee12.id)),
        tournees: FakeTourneeRepository([team()]),
      );

      await openSheet(tester);

      expect(
        find.text('CS Villefranche · 1 demande en attente'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Tournée 49 · 2026, CS Villefranche, 1 demande en attente, ouvrir',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('myTournees.t49.dot')), findsOneWidget);
      expect(find.byKey(const Key('myTournees.t12.dot')), findsNothing);
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

  testWidgets(
    'should open the sheet from the app\'s name when no tournée is open',
    (tester) async {
      await pumpApp(tester, MyTournees.none);

      await tester.tap(find.byKey(const Key('home.appTitle')));
      await tester.pumpAndSettle();

      expect(find.byType(MyTourneesSheet), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tournée des calendriers. Mes tournées'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'should open « Nouvelle tournée » from the sheet, the open tournée kept',
    (tester) async {
      await pumpApp(tester, _manusPhone(), name: nameOf('Manu'), admin: true);
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('myTournees.create')));
      await tester.pumpAndSettle();

      expect(find.byType(MyTourneesSheet), findsNothing);
      expect(find.byType(CreateTourneeScreen), findsOneWidget);
      expect(store.saves, isEmpty);
    },
  );

  testWidgets('should ask the name first when the phone has none, then open '
      '« Rejoindre une tournée »', (tester) async {
    await pumpApp(tester, _manusPhone());
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('myTournees.join')));
    await tester.pumpAndSettle();
    expect(find.byType(NameSheet), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name.field')), 'Manu');
    await tester.tap(find.byKey(const Key('name.save')));
    await tester.pumpAndSettle();

    expect(settings.names, [nameOf('Manu')]);
    expect(find.byType(JoinTourneeScreen), findsOneWidget);
  });

  testWidgets('should open nothing when the name sheet is closed without one', (
    tester,
  ) async {
    await pumpApp(tester, _manusPhone(), admin: true);
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('myTournees.create')));
    await tester.pumpAndSettle();

    // A tap on the dimmed screen above the sheet closes it.
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(find.byType(NameSheet), findsNothing);
    expect(find.byType(CreateTourneeScreen), findsNothing);
    expect(find.text('Tournée 49 · 2026'), findsOneWidget);
  });

  group('admins (PLAN §5.12)', () {
    testWidgets('should offer neither « Créer » nor « Toutes les tournées » '
        'to a phone that is not an admin\'s', (tester) async {
      await pumpApp(tester, _manusPhone());
      await openSheet(tester);

      expect(find.byKey(const Key('myTournees.create')), findsNothing);
      expect(find.byKey(const Key('myTournees.all')), findsNothing);
      expect(find.byKey(const Key('myTournees.join')), findsOneWidget);
    });

    testWidgets('should open « Toutes les tournées » for an admin', (
      tester,
    ) async {
      await pumpApp(tester, _manusPhone(), name: nameOf('Sam'), admin: true);
      await openSheet(tester);

      expect(find.byKey(const Key('myTournees.create')), findsOneWidget);
      await tester.tap(find.byKey(const Key('myTournees.all')));
      await tester.pumpAndSettle();

      expect(find.byType(AllTourneesScreen), findsOneWidget);
    });

    testWidgets('should show a visited tournée with a shield and '
        '« administrateur »', (tester) async {
      await pumpApp(
        tester,
        valueOf(
          MyTournees.none
              .remember(tournee49)
              .remember(summaryOf('t12', 12, status: MemberStatus.visiting))
              .open(tournee49.id),
        ),
        admin: true,
      );
      await openSheet(tester);

      expect(find.text('CS Villefranche · administrateur'), findsOneWidget);
      expect(find.byKey(const Key('myTournees.t12.shield')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Tournée 12 · 2026, CS Villefranche, administrateur, ouvrir',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('myTournees.t12')));
      await tester.pumpAndSettle();

      expect(store.myTournees.currentId, tournee12.id);
    });

    testWidgets('should say an open visited tournée is open', (tester) async {
      await pumpApp(
        tester,
        valueOf(
          MyTournees.none
              .remember(summaryOf('t12', 12, status: MemberStatus.visiting))
              .open(tournee12.id),
        ),
        admin: true,
      );
      await openSheet(tester);

      expect(
        find.bySemanticsLabel(
          'Tournée 12 · 2026, CS Villefranche, administrateur, tournée '
          'ouverte',
        ),
        findsOneWidget,
      );
    });
  });
}
