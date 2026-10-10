import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../../domain/tournee/my_tournees_fixtures.dart';
import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';

void main() {
  late FakeTourneeRepository tournees;

  /// The start screen of Léa's phone; the 49 ([stored]) is open unless
  /// [noTournee].
  Future<void> pumpStart(
    WidgetTester tester, {
    Tournee? stored,
    bool noTournee = false,
  }) async {
    tournees = FakeTourneeRepository([stored ?? team()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          myTournees: FakeMyTourneesStore(
            noTournee
                ? MyTournees.none
                : valueOf(
                    MyTournees.none.remember(tournee49).open(tournee49.id),
                  ),
          ),
          tournees: tournees,
          member: leaId,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('should have no 👥 when no tournée is open', (tester) async {
    await pumpStart(tester, noTournee: true);

    expect(find.byKey(const Key('home.team')), findsNothing);
  });

  testWidgets('should show a dot on 👥, and say it, while a request '
      'waits', (tester) async {
    await pumpStart(tester);

    expect(find.byKey(const Key('home.team.dot')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Équipe, 1 demande en attente'),
      findsOneWidget,
    );
  });

  testWidgets('should take the dot off once the request is answered', (
    tester,
  ) async {
    await pumpStart(tester);

    tournees.put(team(members: [manu, lea]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home.team.dot')), findsNothing);
    expect(find.bySemanticsLabel('Équipe'), findsOneWidget);
  });

  testWidgets('should open Équipe when 👥 is tapped', (tester) async {
    await pumpStart(tester, stored: team(members: [manu, lea]));

    await tester.tap(find.byKey(const Key('home.team')));
    await tester.pumpAndSettle();

    expect(find.byType(TeamScreen), findsOneWidget);
    expect(find.text('Tournée 49'), findsOneWidget);
  });
}
