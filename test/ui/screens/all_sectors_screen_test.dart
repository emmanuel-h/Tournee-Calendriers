// « Tous les secteurs » and the admin who opens a secteur they are not in
// (PLAN §5.12, AllSectors and HomeAdmin mockups).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/settings/name_sheet.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_sector_directory.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/large_text.dart';
import '../support/navigation.dart';

/// Secteur [number] of [centre] (a station of Villefranche).
SectorOverview overview(
  String id,
  int number, {
  String centre = 'CS Villefranche',
  int members = 3,
  int requests = 0,
  bool mine = false,
}) => SectorOverview(
  id: SectorId(id),
  number: valueOf(SectorNumber.create(number)),
  centre: valueOf(RescueCentre.create(centre)),
  campaign: valueOf(CampaignYear.create(2026)),
  activeMembers: members,
  pendingRequests: requests,
  callerIsActive: mine,
);

void main() {
  late FakeSectorDirectory directory;
  late FakeMySectorsStore store;
  late FakeSectorRepository sectors;

  /// Sam's phone (an admin), on the start screen with nothing open, then
  /// « Tous les secteurs » pushed over it.
  Future<void> pumpAll(
    WidgetTester tester, {
    List<SectorOverview> all = const [],
    bool offline = false,
    bool notAdmin = false,
    bool withName = true,
  }) async {
    directory = FakeSectorDirectory()
      ..overviews = all
      ..offline = offline
      ..notAdmin = notAdmin;
    store = FakeMySectorsStore();
    // The 49 of Manu, Léa and Julie, which Sam is not in.
    sectors = FakeSectorRepository([team()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          mySectors: store,
          sectorDirectory: directory,
          sectors: sectors,
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
      AppRoutes.allSectors,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('should list every secteur under its station with its team', (
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

    expect(find.text('Tous les secteurs'), findsOneWidget);
    expect(find.text('Administrateur · 3 secteurs'), findsOneWidget);
    expect(find.text('CS VILLEFRANCHE'), findsOneWidget);
    expect(find.text('CS VILLEFRANCHE EST'), findsOneWidget);
    expect(find.text('CS VILLEFRANCHE NORD'), findsOneWidget);
    expect(find.text('5 membres · vous en êtes membre'), findsOneWidget);
    expect(find.text('3 membres · 1 demande en attente'), findsOneWidget);
    expect(find.text('Aucun membre'), findsOneWidget);
    expect(find.byKey(const Key('allSectors.t12.dot')), findsOneWidget);
    expect(find.byKey(const Key('allSectors.t49.dot')), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Secteur 12 · 2026, 3 membres · 1 demande en attente, ouvrir',
      ),
      findsOneWidget,
    );
  });

  testWidgets('should say so when the app has no secteur', (tester) async {
    await pumpAll(tester);

    expect(find.byKey(const Key('allSectors.empty')), findsOneWidget);
    expect(find.text('Administrateur · aucun secteur'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('allSectors.retry')));
    await tester.pumpAndSettle();

    expect(find.text('CS VILLEFRANCHE'), findsOneWidget);
  });

  testWidgets('should say the phone is no longer an admin\'s when the server '
      'refuses the list, with nothing to try again', (tester) async {
    await pumpAll(tester, notAdmin: true);

    expect(find.text("Vous n'êtes plus administrateur."), findsOneWidget);
    expect(find.byKey(const Key('allSectors.notAdmin')), findsOneWidget);
    expect(find.byKey(const Key('allSectors.retry')), findsNothing);
  });

  testWidgets('should open a secteur the admin is not in on Accueil, under '
      'the banner, with « Rues »', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)]);

    await tester.tap(find.byKey(const ValueKey('allSectors.t49')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Secteur 49 · 2026'), findsOneWidget);
    expect(find.text('Administrateur · pas membre'), findsOneWidget);
    expect(find.text('Rues · 0/0'), findsOneWidget);
    expect(
      find.text("Vous n'êtes pas dans l'équipe de ce secteur."),
      findsOneWidget,
    );
    expect(store.mySectors.current!.isVisiting, isTrue);
  });

  testWidgets('should make the admin a member at once with « Rejoindre »', (
    tester,
  ) async {
    await pumpAll(tester, all: [overview('t49', 49)]);
    await tester.tap(find.byKey(const ValueKey('allSectors.t49')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();

    final (_, change) = sectors.saved.single;
    expect((change as AdminJoined).member.id, samId);
    expect(change.member.name, nameOf('Sam'));
    expect(store.mySectors.current, sector49.withMemberName(nameOf('Sam')));
    expect(find.byKey(const Key('home.adminBanner')), findsNothing);
  });

  testWidgets('should tell « Rejoindre » needs the network', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)]);
    await tester.tap(find.byKey(const ValueKey('allSectors.t49')));
    await tester.pumpAndSettle();
    sectors.offline = true;

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();

    expect(
      find.text('Pas de réseau. Réessayez une fois connecté.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home.adminBanner')), findsOneWidget);
  });

  testWidgets('should say « Rejoindre » is refused to a phone no longer an '
      'admin\'s', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)]);
    await tester.tap(find.byKey(const ValueKey('allSectors.t49')));
    await tester.pumpAndSettle();
    sectors.notAdmin = true;

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();

    expect(find.text("Vous n'êtes plus administrateur."), findsOneWidget);
    expect(find.byKey(const Key('home.adminBanner')), findsOneWidget);
  });

  testWidgets('should ask the first name before joining when the phone has '
      'none, then join under it', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)], withName: false);
    await tester.tap(find.byKey(const ValueKey('allSectors.t49')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();
    expect(find.byType(NameSheet), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name.field')), 'Samuel');
    await tester.tap(find.byKey(const Key('name.save')));
    await tester.pumpAndSettle();

    final (_, change) = sectors.saved.single;
    expect((change as AdminJoined).member.name, nameOf('Samuel'));
  });

  testWidgets('should join nothing when the name sheet is closed without '
      'one', (tester) async {
    await pumpAll(tester, all: [overview('t49', 49)], withName: false);
    await tester.tap(find.byKey(const ValueKey('allSectors.t49')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home.adminJoin')));
    await tester.pumpAndSettle();
    // A tap on the dimmed screen above the sheet closes it.
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(sectors.saved, isEmpty);
    expect(find.byKey(const Key('home.adminBanner')), findsOneWidget);
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await pumpAll(
      tester,
      all: [
        overview('t49', 49, members: 5, mine: true),
        overview('t12', 12, centre: 'CS Villefranche Nord', requests: 1),
      ],
    );

    await expectAccessibleControls(tester);
  });
}
