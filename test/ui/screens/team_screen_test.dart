import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/corbeille/corbeille_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_admin_status.dart';
import '../../support/fakes/fake_commune_search.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart' show villefranche;
import '../support/app_overrides.dart';
import '../support/buttons.dart';
import '../support/clipboard.dart';
import '../support/large_text.dart';
import '../support/navigation.dart';

/// Two minutes after Julie asked to join the 49.
final twoMinutesLater = DateTime.utc(2026, 11, 2, 8, 14);

/// A street of the 49 named [name], covered by [assignees].
Street _street(String name, Set<MemberId> assignees) => valueOf(
  Street.create(
    id: StreetId(name.toLowerCase().replaceAll(' ', '-')),
    name: name,
    commune: villefranche,
    assignees: assignees,
  ),
);

/// Léa's three streets of the Team mockup, one of them Manu's too.
List<Street> leasStreets() => [
  _street('Rue de Thizy', {leaId}),
  _street('Rue Nationale', {leaId, manuId}),
  _street('Place des Marais', {leaId}),
];

void main() {
  late FakeTourneeRepository tournees;
  late FakeMyTourneesStore store;

  /// Équipe over the start screen, on the phone of [member] where the 49
  /// of Manu, Léa and Julie (pending) is open. Manu and Sam are admins of
  /// the app; Sam is not in the 49, which his phone keeps as visited.
  Future<void> pumpTeam(
    WidgetTester tester,
    MemberId member, {
    List<TourneeCommune> communes = const [],
    FakeCommuneSearch? search,
    List<Street> streets = const [],
  }) async {
    // A phone's screen (the mockup's), so the buttons at the bottom show.
    tester.view
      ..physicalSize = const Size(393 * 3, 852 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tournees = FakeTourneeRepository([team(communes: communes)]);
    final kept = member == samId
        ? summaryOf('t49', 49, status: MemberStatus.visiting)
        : tournee49;
    store = FakeMyTourneesStore(
      valueOf(MyTournees.none.remember(kept).open(tournee49.id)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          myTournees: store,
          tournees: tournees,
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

    expect(find.text('Tournée 49'), findsOneWidget);
    expect(find.text('CS Villefranche · campagne 2026'), findsOneWidget);
    expect(find.text('K7P-2QX'), findsOneWidget);
    expect(
      find.bySemanticsLabel('QR code de la tournée, code K7P-2QX'),
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
      'commands, and « Retirer de Mes tournées » instead of « Quitter »', (
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

    expect(tournees.saved, isEmpty);
    expect(store.myTournees.tournees, isEmpty);
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

    final (_, change) = tournees.saved.single;
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

    expect(tournees.saved.single.$2, isA<MemberRefused>());
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

    expect(tournees.saved.single.$2, isA<MemberRemoved>());
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
    tournees.offline = true;

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
    tournees.notAdmin = true;

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
    expect(find.text('Supprimer la tournée 49 ?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team.confirmDelete.ok')));
    await tester.pumpAndSettle();

    expect(tournees.deleted, hasLength(1));
    expect(store.myTournees.tournees, isEmpty);
    expect(find.text('Tournée des calendriers'), findsOneWidget);
    expect(find.byKey(const Key('home.team')), findsNothing);
  });

  testWidgets('should keep the tournée when deleting is cancelled', (
    tester,
  ) async {
    await pumpTeam(tester, manuId);

    await tapVisible(tester, find.byKey(const Key('team.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team.confirmDelete.cancel')));
    await tester.pumpAndSettle();

    expect(tournees.deleted, isEmpty);
    expect(find.text('Tournée 49'), findsOneWidget);
  });

  testWidgets('should go back to the start screen once the member leaves', (
    tester,
  ) async {
    await pumpTeam(tester, leaId);

    await tapVisible(tester, find.byKey(const Key('team.leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team.confirmLeave.ok')));
    await tester.pumpAndSettle();

    expect(tournees.saved.single.$2, isA<MemberLeft>());
    expect(store.myTournees.tournees, isEmpty);
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

    expect(find.text('COMMUNES (2)'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer Villefranche-sur-Saône'));
    await tester.pumpAndSettle();

    expect(tournees.saved.single.$2, isA<CommuneRemoved>());
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
    expect(find.text('COMMUNES (0)'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('team.addCommune')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('communes.field')), 'Gleiz');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('communes.suggestion.69092')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('communes.field')), findsNothing);
    expect(tournees[tourneeId]!.communes, [gleizeCommune]);
    expect(find.byKey(const ValueKey('team.commune.69092')), findsOneWidget);
  });

  testWidgets('should open the Corbeille', (tester) async {
    await pumpTeam(tester, leaId);

    await tester.tap(find.byKey(const Key('team.corbeille')));
    await tester.pumpAndSettle();

    expect(find.byType(CorbeilleScreen), findsOneWidget);
  });

  testWidgets('should say so when the tournée cannot be read', (tester) async {
    await pumpTeam(tester, leaId);

    tournees.lose(tourneeId);
    await tester.pumpAndSettle();

    expect(
      find.text(
        "L'équipe ne peut pas être affichée : la tournée n'est pas "
        "sur ce téléphone, ou vous n'en faites plus partie.",
      ),
      findsOneWidget,
    );
  });

  group('streets per member', () {
    testWidgets('should show how many streets each member covers, folded', (
      tester,
    ) async {
      await pumpTeam(tester, manuId, streets: leasStreets());

      expect(inMember(manuId, find.text('1 rue')), findsOneWidget);
      expect(inMember(leaId, find.text('3 rues')), findsOneWidget);
      expect(inMember(leaId, find.text('▸')), findsOneWidget);
      expect(find.bySemanticsLabel('Léa, 3 rues, afficher les rues'), findsOne);
      expect(find.bySemanticsLabel('Manu, 1 rue, afficher les rues'), findsOne);
      expect(find.text('Rue de Thizy'), findsNothing);
      expect(find.byKey(const Key('team.member.streetList')), findsNothing);
    });

    testWidgets('should unfold the member\'s streets, in French order, when '
        'the count is tapped, and fold them on a second tap', (tester) async {
      await pumpTeam(tester, manuId, streets: leasStreets());

      await tester.tap(find.bySemanticsLabel('Léa, 3 rues, afficher les rues'));
      await tester.pumpAndSettle();

      final list = inMember(
        leaId,
        find.byKey(const Key('team.member.streetList')),
      );
      expect(list, findsOneWidget);
      final names = tester
          .widgetList<Text>(
            find.descendant(of: list, matching: find.byType(Text)),
          )
          .map((text) => text.data);
      expect(names, ['Place des Marais', 'Rue de Thizy', 'Rue Nationale']);
      expect(inMember(leaId, find.text('▾')), findsOneWidget);
      expect(inMember(leaId, find.text('▸')), findsNothing);
      expect(find.bySemanticsLabel('Léa, 3 rues, masquer les rues'), findsOne);
      expect(find.bySemanticsLabel('Rues de Léa'), findsOne);
      // Indented under the name, not under the avatar.
      expect(
        tester.getTopLeft(find.text('Rue de Thizy')).dx,
        tester.getTopLeft(inMember(leaId, find.text('Léa'))).dx,
      );

      await tester.tap(find.bySemanticsLabel('Léa, 3 rues, masquer les rues'));
      await tester.pumpAndSettle();

      expect(find.text('Rue de Thizy'), findsNothing);
      expect(inMember(leaId, find.text('▸')), findsOneWidget);
    });

    testWidgets('should keep several members unfolded at once', (tester) async {
      await pumpTeam(tester, manuId, streets: leasStreets());

      await tester.tap(find.bySemanticsLabel('Léa, 3 rues, afficher les rues'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Manu, 1 rue, afficher les rues'));
      await tester.pumpAndSettle();

      expect(inMember(manuId, find.text('Rue Nationale')), findsOneWidget);
      expect(inMember(leaId, find.text('Rue Nationale')), findsOneWidget);
      expect(inMember(leaId, find.text('Rue de Thizy')), findsOneWidget);
    });

    testWidgets('should show « 0 rue » with nothing to unfold for a member '
        'who covers none', (tester) async {
      await pumpTeam(tester, manuId);

      expect(inMember(manuId, find.text('0 rue')), findsOneWidget);
      expect(inMember(leaId, find.text('0 rue')), findsOneWidget);
      expect(find.text('▸'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('afficher les rues')), findsNothing);

      await tester.tap(inMember(leaId, find.text('0 rue')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('team.member.streetList')), findsNothing);
    });

    testWidgets('should give the count a 48 dp tap target', (tester) async {
      await pumpTeam(tester, manuId, streets: leasStreets());

      final count = inMember(
        leaId,
        find.byKey(const Key('team.member.streets')),
      );
      expect(tester.getSize(count).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(count).width, greaterThanOrEqualTo(48));
    });
  });

  group('pinned bottom buttons', () {
    /// Manu and Léa each cover [count] streets: a team longer than the
    /// screen once unfolded.
    List<Street> manyStreets(int count) => [
      for (var i = 1; i <= count; i++)
        _street('Rue numéro $i', {leaId, manuId}),
    ];

    testWidgets('should keep « Quitter » and « Supprimer » at the bottom, '
        'over a divider, while the rest scrolls', (tester) async {
      await pumpTeam(tester, manuId, streets: manyStreets(20));
      await tester.tap(
        find.bySemanticsLabel('Léa, 20 rues, afficher les rues'),
      );
      await tester.pumpAndSettle();
      final footer = find.byKey(const Key('team.footer'));
      final leave = find.byKey(const Key('team.leave'));
      final before = tester.getTopLeft(leave);
      final memberBefore = tester.getTopLeft(
        find.byKey(ValueKey('team.member.${leaId.value}')),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(leave), before);
      expect(find.byKey(const Key('team.delete')).hitTestable(), findsOne);
      expect(leave.hitTestable(), findsOne);
      expect(
        tester
            .getTopLeft(find.byKey(ValueKey('team.member.${leaId.value}')))
            .dy,
        lessThan(memberBefore.dy),
      );
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
      testWidgets('should show Équipe to $who with no overflow when the text '
          'is twice as large', (tester) async {
        useLargeText(tester);

        await pumpTeam(tester, member);

        expect(find.text('Tournée 49'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('should unfold a member\'s streets with no overflow when the '
        'text is twice as large', (tester) async {
      useLargeText(tester);

      await pumpTeam(tester, manuId, streets: leasStreets());
      // Below the code card and the request at this size.
      await tapVisible(
        tester,
        find.bySemanticsLabel('Léa, 3 rues, afficher les rues'),
      );
      await tester.pumpAndSettle();

      expect(inMember(leaId, find.text('Rue de Thizy')), findsOneWidget);
      expect(find.byKey(const Key('team.leave')).hitTestable(), findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await pumpTeam(tester, manuId, streets: leasStreets());
    await tester.tap(find.bySemanticsLabel('Léa, 3 rues, afficher les rues'));
    await tester.pumpAndSettle();

    await expectAccessibleControls(tester);
  });
}
