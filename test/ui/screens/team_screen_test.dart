import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_change.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/corbeille/corbeille_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';
import '../support/navigation.dart';

/// Two minutes after Julie asked to join the 49.
final twoMinutesLater = DateTime.utc(2026, 11, 2, 8, 14);

void main() {
  late FakeTourneeRepository tournees;
  late FakeMyTourneesStore store;

  /// Équipe over the start screen, on the phone of [member] where the 49
  /// of Manu, Léa and Julie (pending) is open.
  Future<void> pumpTeam(WidgetTester tester, MemberId member) async {
    // A phone's screen (the mockup's), so the buttons at the bottom show.
    tester.view
      ..physicalSize = const Size(393 * 3, 852 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tournees = FakeTourneeRepository([team()]);
    store = FakeMyTourneesStore(
      valueOf(MyTournees.none.remember(tournee49).open(tournee49.id)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          myTournees: store,
          tournees: tournees,
          member: member,
          now: twoMinutesLater,
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

  testWidgets('should show the code, the request and the members as the '
      'creator sees them', (tester) async {
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
    expect(find.text('Manu (vous) · créateur'), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
    expect(find.bySemanticsLabel('Corbeille · vide'), findsOneWidget);
    expect(find.byKey(const Key('team.newCode')), findsOneWidget);
    expect(find.byTooltip('Options pour Léa'), findsOneWidget);
    expect(find.byKey(const Key('team.delete')), findsOneWidget);
    expect(find.byKey(const Key('team.leave')), findsNothing);
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

  testWidgets('should keep the creator\'s commands from another member and '
      'offer to leave', (tester) async {
    await pumpTeam(tester, leaId);

    expect(find.text('Manu · créateur'), findsOneWidget);
    expect(find.text('Léa (vous)'), findsOneWidget);
    expect(find.text('K7P-2QX'), findsOneWidget);
    expect(find.byKey(const Key('team.share')), findsOneWidget);
    expect(find.byKey(const Key('team.newCode')), findsNothing);
    expect(find.byKey(const Key('team.member.options')), findsNothing);
    expect(find.byKey(const Key('team.delete')), findsNothing);
    expect(find.byKey(const Key('team.leave')), findsOneWidget);
  });

  testWidgets('should remove a member once the creator confirms', (
    tester,
  ) async {
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

  testWidgets('should go back to the start screen with no tournée open once '
      'the creator deletes it', (tester) async {
    await pumpTeam(tester, manuId);

    await tester.tap(find.byKey(const Key('team.delete')));
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

    await tester.tap(find.byKey(const Key('team.delete')));
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

    await tester.tap(find.byKey(const Key('team.leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team.confirmLeave.ok')));
    await tester.pumpAndSettle();

    expect(tournees.saved.single.$2, isA<MemberLeft>());
    expect(store.myTournees.tournees, isEmpty);
    expect(find.text('Tournée des calendriers'), findsOneWidget);
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
}
