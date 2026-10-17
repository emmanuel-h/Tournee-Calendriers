// « Toutes les tournées » and the admin who opens a tournée they are not in
// (PLAN §5.12, AllTournees and HomeAdmin mockups).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/settings/name_sheet.dart';
import 'package:tournee_calendriers/ui/screens/start/start_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/navigation.dart';

/// Tournée [number] of [centre] (a station of Villefranche).
TourneeOverview overview(
  String id,
  int number, {
  String centre = 'CS Villefranche',
  int members = 3,
  int requests = 0,
  bool mine = false,
}) => TourneeOverview(
  id: TourneeId(id),
  number: valueOf(TourneeNumber.create(number)),
  centre: valueOf(RescueCentre.create(centre)),
  campaign: valueOf(CampaignYear.create(2026)),
  activeMembers: members,
  pendingRequests: requests,
  callerIsActive: mine,
);

void main() {
  late FakeTourneeDirectory directory;
  late FakeMyTourneesStore store;
  late FakeTourneeRepository tournees;

  /// Sam's phone (an admin), on the start screen with nothing open, then
  /// « Toutes les tournées » pushed over it.
  Future<void> pumpAll(
    WidgetTester tester, {
    List<TourneeOverview> all = const [],
    bool offline = false,
    bool withName = true,
  }) async {
    directory = FakeTourneeDirectory()
      ..overviews = all
      ..offline = offline;
    store = FakeMyTourneesStore();
    // The 49 of Manu, Léa and Julie, which Sam is not in.
    tournees = FakeTourneeRepository([team()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          myTournees: store,
          tourneeDirectory: directory,
          tournees: tournees,
          member: samId,
          settings: FakePhoneSettings(
            memberName: withName ? nameOf('Sam') : null,
          ),
          account: FakeMemberAccount(signedInMember: samId),
          admins: FakeAdminStatus(phoneIsAdmin: true, admins: [manuId, samId]),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    unawaitedPush(
      GoRouter.of(tester.element(find.byType(Scaffold).first)),
      AppRoutes.allTournees,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('should list every tournée under its station with its team', (
    tester,
  ) async {
    await pumpAll(
      tester,
      all: [
        overview('t49', 49, members: 5, mine: true),
        overview('t12', 12, centre: 'CS Villefranche Nord', requests: 1),
        overview('t7', 7, centre: 'CS Villefranche Est', members: 0),
      ],
    );

    expect(find.text('Toutes les tournées'), findsOneWidget);
    expect(find.text('Administrateur · 3 tournées'), findsOneWidget);
    expect(find.text('CS VILLEFRANCHE'), findsOneWidget);
    expect(find.text('CS VILLEFRANCHE EST'), findsOneWidget);
    expect(find.text('CS VILLEFRANCHE NORD'), findsOneWidget);
    expect(find.text('5 membres · vous en êtes membre'), findsOneWidget);
    expect(find.text('3 membres · 1 demande en attente'), findsOneWidget);
    expect(find.text('Aucun membre'), findsOneWidget);
    expect(find.byKey(const Key('allTournees.t12.dot')), findsOneWidget);
    expect(find.byKey(const Key('allTournees.t49.dot')), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Tournée 12 · 2026, 3 membres · 1 demande en attente, ouvrir',
      ),
      findsOneWidget,
    );
  });

  testWidgets('should say so when the app has no tournée', (tester) async {
    await pumpAll(tester);

    expect(find.byKey(const Key('allTournees.empty')), findsOneWidget);
    expect(find.text('Administrateur · aucune tournée'), findsOneWidget);
  });

  testWidgets('should say the list needs the network, then try again', (
    tester,
  ) async {
    await pumpAll(tester, offline: true);

    expect(
      find.text('Pas de réseau : la liste ne peut pas être affichée.'),
      findsOneWidget,
    );

    directory
      ..offline = false
      ..overviews = [overview('t49', 49)];
    await tester.tap(find.byKey(const Key('allTournees.retry')));
    await tester.pumpAndSettle();

    expect(find.text('CS VILLEFRANCHE'), findsOneWidget);
  });

  testWidgets('should open a tournée the admin is not in on Accueil, under '
      'the banner, with « Rues »', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)]);

    await tester.tap(find.byKey(const ValueKey('allTournees.t49')));
    await tester.pumpAndSettle();

    expect(find.byType(StartScreen), findsOneWidget);
    expect(find.text('Tournée 49 · 2026'), findsOneWidget);
    expect(find.text('Administrateur · pas membre'), findsOneWidget);
    expect(
      find.text("Vous n'êtes pas dans l'équipe de cette tournée."),
      findsOneWidget,
    );
    expect(store.myTournees.current!.isVisiting, isTrue);
  });

  testWidgets('should make the admin a member at once with « Rejoindre »', (
    tester,
  ) async {
    await pumpAll(tester, all: [overview('t49', 49)]);
    await tester.tap(find.byKey(const ValueKey('allTournees.t49')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();

    final (_, change) = tournees.saved.single;
    expect((change as AdminJoined).member.id, samId);
    expect(change.member.name, nameOf('Sam'));
    expect(store.myTournees.current, tournee49);
    expect(find.byKey(const Key('home.adminBanner')), findsNothing);
  });

  testWidgets('should tell « Rejoindre » needs the network', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)]);
    await tester.tap(find.byKey(const ValueKey('allTournees.t49')));
    await tester.pumpAndSettle();
    tournees.offline = true;

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();

    expect(
      find.text('Pas de réseau. Réessayez une fois connecté.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home.adminBanner')), findsOneWidget);
  });

  testWidgets('should ask the first name before joining when the phone has '
      'none, then join under it', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)], withName: false);
    await tester.tap(find.byKey(const ValueKey('allTournees.t49')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();
    expect(find.byType(NameSheet), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name.field')), 'Samuel');
    await tester.tap(find.byKey(const Key('name.save')));
    await tester.pumpAndSettle();

    final (_, change) = tournees.saved.single;
    expect((change as AdminJoined).member.name, nameOf('Samuel'));
  });

  testWidgets('should join nothing when the name sheet is closed without '
      'one', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)], withName: false);
    await tester.tap(find.byKey(const ValueKey('allTournees.t49')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();
    // A tap on the dimmed screen above the sheet closes it.
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(tournees.saved, isEmpty);
    expect(find.byKey(const Key('home.adminBanner')), findsOneWidget);
  });
}
