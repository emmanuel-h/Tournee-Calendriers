import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/add_streets/add_streets_screen.dart';
import 'package:tournee_calendriers/ui/screens/corbeille/corbeille_screen.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show villefranche;
import '../support/app_overrides.dart';
import '../support/buttons.dart';
import '../support/clipboard.dart';
import '../support/large_text.dart';
import '../support/navigation.dart';

/// Two minutes after Julie asked to join the 49.
final twoMinutesLater = DateTime.utc(2026, 11, 2, 8, 14);

/// Streets of the 49, as Accueil lists them.
List<Street> _streetsOf49() => [
  for (final name in ['Rue de Thizy', 'Rue Nationale', 'Place des Marais'])
    valueOf(
      Street.create(
        id: StreetId(name.toLowerCase().replaceAll(' ', '-')),
        name: name,
        commune: villefranche,
      ),
    ),
];

void main() {
  late FakeSectorRepository sectors;
  late FakeMySectorsStore store;

  /// Secteur over the start screen, on the phone of [member] where the 49
  /// of Manu, Léa and Julie (pending) is open. Manu and Sam are admins of
  /// the app; Sam is not in the 49, which his phone keeps as visited.
  Future<void> pumpTeam(
    WidgetTester tester,
    MemberId member, {
    List<SectorCommune> communes = const [],
    FakeCommuneSearch? search,
    List<Street> streets = const [],
  }) async {
    // A phone's screen (the mockup's), so the buttons at the bottom show.
    tester.view
      ..physicalSize = const Size(393 * 3, 852 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    sectors = FakeSectorRepository([team(communes: communes)]);
    final kept = member == samId
        ? summaryOf('t49', 49, status: MemberStatus.visiting)
        : sector49;
    store = FakeMySectorsStore(
      valueOf(MySectors.none.remember(kept).open(sector49.id)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          mySectors: store,
          sectors: sectors,
          streets: FakeStreetRepository(streets),
          member: member,
          now: twoMinutesLater,
          communes: search,
          admins: FakeAdminStatus(
            phoneIsAdmin: member == manuId || member == samId,
            admins: [manuId, samId],
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    unawaitedPush(
      GoRouter.of(tester.element(find.byType(Scaffold).first)),
      AppRoutes.team,
    );
    await tester.pumpAndSettle();
  }

  Finder inRequest(Finder finder) => find.descendant(
    of: find.byKey(const ValueKey('team.request.uid-julie')),
    matching: finder,
  );

  Finder inMember(MemberId member, Finder finder) => find.descendant(
    of: find.byKey(ValueKey('team.member.${member.value}')),
    matching: finder,
  );

  testWidgets('should show the code, the request and the members as an '
      'admin in the team sees them', (tester) async {
    await pumpTeam(tester, manuId);

    expect(find.text('Secteur 49'), findsOneWidget);
    expect(find.text('CS Villefranche · campagne 2026'), findsOneWidget);
    expect(find.text('K7P-2QX'), findsOneWidget);
    expect(
      find.bySemanticsLabel('QR code du secteur, code K7P-2QX'),
      findsOneWidget,
    );
    expect(find.text('EN ATTENTE (1)'), findsOneWidget);
    expect(inRequest(find.text('Julie')), findsOneWidget);
    expect(
      inRequest(find.text('a demandé à rejoindre · il y a 2 min')),
      findsOneWidget,
    );
    expect(find.text('MEMBRES (2)'), findsOneWidget);
    expect(find.text('Manu (vous) · admin'), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
    expect(find.bySemanticsLabel('Corbeille · vide'), findsOneWidget);
    expect(find.byKey(const Key('team.newCode')), findsOneWidget);
    expect(find.byTooltip('Options pour Léa'), findsOneWidget);
    expect(find.byKey(const Key('team.delete')), findsOneWidget);
    expect(find.byKey(const Key('team.leave')), findsOneWidget);
    expect(find.byKey(const Key('team.forgetVisit')), findsNothing);
  });

  testWidgets('should give an admin who is not in the team the admin\'s '
      'commands, and « Retirer de Mes secteurs » instead of « Quitter »', (
    tester,
  ) async {
    await pumpTeam(tester, samId);

    expect(find.text('MEMBRES (2)'), findsOneWidget);
    expect(find.text('Manu · admin'), findsOneWidget);
    expect(find.textContaining('(vous)'), findsNothing);
    expect(find.byKey(const Key('team.newCode')), findsOneWidget);
    expect(find.byTooltip('Options pour Manu'), findsOneWidget);
    expect(find.byTooltip('Options pour Léa'), findsOneWidget);
    expect(find.byKey(const Key('team.delete')), findsOneWidget);
    expect(find.byKey(const Key('team.leave')), findsNothing);
    expect(find.byKey(const Key('team.forgetVisit')), findsOneWidget);
  });

  testWidgets('should forget a visited tournée on the phone, writing '
      'nothing, and go back to the start screen', (tester) async {
    await pumpTeam(tester, samId);

    await tapVisible(tester, find.byKey(const Key('team.forgetVisit')));
    await tester.pumpAndSettle();

    expect(sectors.saved, isEmpty);
    expect(store.mySectors.sectors, isEmpty);
    expect(find.text('Tournée des calendriers'), findsOneWidget);
  });

  testWidgets('should put the code on the clipboard and say so when the '
      'copy button is tapped', (tester) async {
    await pumpTeam(tester, leaId);
    final clipboard = FakeClipboard.install(tester);

    final copy = find.byTooltip('Copier le code');
    expect(copy, findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('team.copy'))).height, 48);
    await tester.tap(copy);
    await tester.pumpAndSettle();

    expect(clipboard.text, 'K7P-2QX');
    expect(find.text('Code copié'), findsOneWidget);
  });

  testWidgets('should let the newcomer in when « Accepter » is tapped', (
    tester,
  ) async {
    await pumpTeam(tester, leaId);

    await tester.tap(find.bySemanticsLabel('Accepter Julie'));
    await tester.pumpAndSettle();

    final (_, change) = sectors.saved.single;
    expect(change, isA<MemberAccepted>());
    final accepted = (change as MemberAccepted).member;
    expect(accepted.id, julieId);
    expect(accepted.acceptance!.by, leaId);
    expect(accepted.acceptance!.at, twoMinutesLater);
    expect(find.byKey(const ValueKey('team.request.uid-julie')), findsNothing);
    expect(find.text('EN ATTENTE (1)'), findsNothing);
    expect(find.text('MEMBRES (3)'), findsOneWidget);
    expect(find.byKey(const ValueKey('team.member.uid-julie')), findsOneWidget);
  });

  testWidgets('should take the request out when « Refuser » is tapped', (
    tester,
  ) async {
    await pumpTeam(tester, leaId);

    await tester.tap(find.bySemanticsLabel('Refuser Julie'));
    await tester.pumpAndSettle();

    expect(sectors.saved.single.$2, isA<MemberRefused>());
    expect(find.text('Julie'), findsNothing);
  });

  testWidgets('should keep the admin\'s commands from a member who is not '
      'one, label the admins and offer to leave', (tester) async {
    await pumpTeam(tester, leaId);

    expect(find.text('Manu · admin'), findsOneWidget);
    expect(find.text('Léa (vous)'), findsOneWidget);
    expect(find.text('K7P-2QX'), findsOneWidget);
    expect(find.byKey(const Key('team.share')), findsOneWidget);
    expect(find.byKey(const Key('team.newCode')), findsNothing);
    expect(find.byKey(const Key('team.member.options')), findsNothing);
    expect(find.byKey(const Key('team.delete')), findsNothing);
    expect(find.byKey(const Key('team.leave')), findsOneWidget);
  });

  testWidgets('should remove a member once an admin confirms', (tester) async {
    await pumpTeam(tester, manuId);

    await tester.tap(find.byTooltip('Options pour Léa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('team.member.remove')));
    await tester.pumpAndSettle();
    expect(find.text('Retirer Léa ?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team.confirmRemove.ok')));
    await tester.pumpAndSettle();

    expect(sectors.saved.single.$2, isA<MemberRemoved>());
    expect(find.text('Léa'), findsNothing);
  });

  testWidgets('should show the new code when « Nouveau code » is tapped', (
    tester,
  ) async {
    await pumpTeam(tester, manuId);

    await tester.tap(find.byKey(const Key('team.newCode')));
    await tester.pumpAndSettle();

    expect(find.text('234-567'), findsOneWidget);
  });

  testWidgets('should tell a new code needs the network', (tester) async {
    await pumpTeam(tester, manuId);
    sectors.offline = true;

    await tester.tap(find.byKey(const Key('team.newCode')));
    await tester.pumpAndSettle();

    expect(
      find.text('Pas de réseau. Réessayez une fois connecté.'),
      findsOneWidget,
    );
    expect(find.text('K7P-2QX'), findsOneWidget);
  });

  testWidgets('should say the phone is no longer an admin\'s when the server '
      'refuses a new code', (tester) async {
    await pumpTeam(tester, manuId);
    sectors.notAdmin = true;

    await tester.tap(find.byKey(const Key('team.newCode')));
    await tester.pumpAndSettle();

    expect(find.text("Vous n'êtes plus administrateur."), findsOneWidget);
    expect(find.text('K7P-2QX'), findsOneWidget);
  });

  testWidgets('should go back to the start screen with no tournée open once '
      'an admin deletes it', (tester) async {
    await pumpTeam(tester, manuId);

    await tapVisible(tester, find.byKey(const Key('team.delete')));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer le secteur 49 ?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team.confirmDelete.ok')));
    await tester.pumpAndSettle();

    expect(sectors.deleted, hasLength(1));
    expect(store.mySectors.sectors, isEmpty);
    expect(find.text('Tournée des calendriers'), findsOneWidget);
    expect(find.byKey(const Key('home.sector')), findsNothing);
  });

  testWidgets('should keep the tournée when deleting is cancelled', (
    tester,
  ) async {
    await pumpTeam(tester, manuId);

    await tapVisible(tester, find.byKey(const Key('team.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team.confirmDelete.cancel')));
    await tester.pumpAndSettle();

    expect(sectors.deleted, isEmpty);
    expect(find.text('Secteur 49'), findsOneWidget);
  });

  testWidgets('should go back to the start screen once the member leaves', (
    tester,
  ) async {
    await pumpTeam(tester, leaId);

    await tapVisible(tester, find.byKey(const Key('team.leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team.confirmLeave.ok')));
    await tester.pumpAndSettle();

    expect(sectors.saved.single.$2, isA<MemberLeft>());
    expect(store.mySectors.sectors, isEmpty);
    expect(find.text('Tournée des calendriers'), findsOneWidget);
  });

  testWidgets('should list the communes, with ✕ but on the last one, and '
      'remove one', (tester) async {
    await pumpTeam(
      tester,
      leaId,
      communes: [villefrancheCommune, gleizeCommune],
    );
    final villefrancheRow = find.byKey(const ValueKey('team.commune.69264'));
    await tester.scrollUntilVisible(
      villefrancheRow,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Whole, not only its first pixels: it may stop at the very bottom of
    // the list.
    await tester.ensureVisible(villefrancheRow);
    await tester.pumpAndSettle();

    expect(find.text('COMMUNES (2)'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer Villefranche-sur-Saône'));
    await tester.pumpAndSettle();

    expect(sectors.saved.single.$2, isA<CommuneRemoved>());
    expect(find.text('COMMUNES (1)'), findsOneWidget);
    expect(find.byTooltip('Retirer Gleizé'), findsNothing);
  });

  testWidgets('should add the commune picked in the sheet of « Ajouter une '
      'commune », even to a tournée without any', (tester) async {
    await pumpTeam(
      tester,
      leaId,
      search: FakeCommuneSearch(
        answers: {
          'Gleiz': Ok([
            CommuneMatch(
              commune: gleizeCommune.commune,
              postcodes: const ['69400'],
              centre: gleizeCommune.centre,
            ),
          ]),
        },
      ),
    );
    // Under « RUES »: built, maybe below the fold.
    expect(find.text('COMMUNES (0)', skipOffstage: false), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('team.addCommune')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('communes.field')), 'Gleiz');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('communes.suggestion.69092')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('communes.field')), findsNothing);
    expect(sectors[sectorId]!.communes, [gleizeCommune]);
    expect(find.byKey(const ValueKey('team.commune.69092')), findsOneWidget);
  });

  testWidgets('should open the Corbeille', (tester) async {
    await pumpTeam(tester, leaId);

    await tapVisible(tester, find.byKey(const Key('team.corbeille')));
    await tester.pumpAndSettle();

    expect(find.byType(CorbeilleScreen), findsOneWidget);
  });

  group('« RUES » (PLAN §5.14)', () {
    /// The top of [finder] on the screen, built but maybe out of sight.
    double topOf(WidgetTester tester, Finder finder) =>
        tester.getTopLeft(finder).dy;

    testWidgets('should come after the members, « Ajouter des rues » then '
        'the Corbeille, before the communes', (tester) async {
      await pumpTeam(
        tester,
        leaId,
        streets: _streetsOf49(),
        communes: [villefrancheCommune],
      );
      final members = find.text('MEMBRES (2)', skipOffstage: false);
      final streets = find.text('RUES (3)', skipOffstage: false);
      final add = find.byKey(const Key('team.addStreets'), skipOffstage: false);
      final corbeille = find.byKey(
        const Key('team.corbeille'),
        skipOffstage: false,
      );
      final communes = find.text('COMMUNES (1)', skipOffstage: false);

      expect(streets, findsOneWidget);
      expect(topOf(tester, members), lessThan(topOf(tester, streets)));
      expect(topOf(tester, streets), lessThan(topOf(tester, add)));
      expect(topOf(tester, add), lessThan(topOf(tester, corbeille)));
      expect(topOf(tester, corbeille), lessThan(topOf(tester, communes)));
      expect(
        find.descendant(of: add, matching: find.text('Ajouter des rues')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: add,
          matching: find.text('Sur la carte ou depuis la liste des communes'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: add, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Ajouter des rues, Sur la carte ou depuis la liste des communes',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(tester.getSize(add).height, greaterThanOrEqualTo(56));
    });

    testWidgets('should count no street in a secteur without any', (
      tester,
    ) async {
      await pumpTeam(tester, leaId);

      expect(find.text('RUES (0)', skipOffstage: false), findsOneWidget);
    });

    testWidgets('should open « Ajouter des rues », whose ✕ comes back to '
        'Secteur', (tester) async {
      await pumpTeam(tester, leaId);

      await tapVisible(tester, find.byKey(const Key('team.addStreets')));
      await tester.pumpAndSettle();
      expect(find.byType(AddStreetsScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      expect(find.byType(AddStreetsScreen), findsNothing);
      expect(find.byType(TeamScreen), findsOneWidget);
    });

    testWidgets('should show to an admin outside the team', (tester) async {
      await pumpTeam(tester, samId);

      expect(
        find.byKey(const Key('team.addStreets'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('should not show to a member still pending', (tester) async {
      await pumpTeam(tester, julieId);

      expect(find.text('Secteur 49'), findsOneWidget);
      expect(find.textContaining('RUES', skipOffstage: false), findsNothing);
      expect(
        find.byKey(const Key('team.addStreets'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const Key('team.corbeille'), skipOffstage: false),
        findsNothing,
      );
    });
  });

  testWidgets('should say so when the tournée cannot be read', (tester) async {
    await pumpTeam(tester, leaId);

    sectors.lose(sectorId);
    await tester.pumpAndSettle();

    expect(
      find.text(
        "L'équipe ne peut pas être affichée : le secteur n'est pas "
        "sur ce téléphone, ou vous n'en faites plus partie.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('should name nobody\'s streets on the member rows (PLAN '
      '§5.14)', (tester) async {
    await pumpTeam(tester, manuId, streets: _streetsOf49());

    for (final member in [manuId, leaId]) {
      expect(inMember(member, find.textContaining('rue')), findsNothing);
      expect(inMember(member, find.text('▸')), findsNothing);
    }
    expect(find.bySemanticsLabel(RegExp('afficher les rues')), findsNothing);
    expect(find.text('Rue de Thizy'), findsNothing);
  });

  group('pinned bottom buttons', () {
    testWidgets('should keep « Quitter » and « Supprimer » at the bottom, '
        'over a divider, while the rest scrolls', (tester) async {
      // Twice as large, the screen is longer than the phone's.
      useLargeText(tester);
      await pumpTeam(tester, manuId);
      final footer = find.byKey(const Key('team.footer'));
      final leave = find.byKey(const Key('team.leave'));
      final before = tester.getTopLeft(leave);
      ScrollPosition scrolled() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(scrolled().pixels, 0);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(leave), before);
      expect(find.byKey(const Key('team.delete')).hitTestable(), findsOne);
      expect(leave.hitTestable(), findsOne);
      // The list moved under the buttons, which stayed.
      expect(scrolled().pixels, greaterThan(0));
      // The footer sits at the very bottom, under the scrolling list.
      expect(tester.getBottomLeft(footer).dy, 852);
      expect(
        tester.getBottomLeft(find.byType(CustomScrollView)).dy,
        tester.getTopLeft(footer).dy,
      );
      final decoration =
          tester.widget<Container>(footer).decoration! as BoxDecoration;
      expect((decoration.border! as Border).top.width, greaterThan(0));
    });

    testWidgets('should keep the buttons at the bottom when the team is '
        'short', (tester) async {
      await pumpTeam(tester, leaId);

      expect(
        tester.getBottomLeft(find.byKey(const Key('team.footer'))).dy,
        852,
      );
      expect(find.byKey(const Key('team.leave')).hitTestable(), findsOne);
    });
  });

  group('at 200 % text', () {
    setUpAll(loadAppFonts);

    for (final (member, who) in [(manuId, 'an admin'), (leaId, 'a member')]) {
      testWidgets('should show Secteur to $who with no overflow when the text '
          'is twice as large', (tester) async {
        useLargeText(tester);

        await pumpTeam(tester, member);

        expect(find.text('Secteur 49'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await pumpTeam(tester, manuId);

    await expectAccessibleControls(tester);
  });
}
