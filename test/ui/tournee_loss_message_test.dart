// The message the app shows over the next screen when the member lost one
// of their tournées (PLAN §5.3): removed by an admin, the tournée deleted,
// or (a tournée only visited) the phone no longer an admin (PLAN §5.12).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../domain/tournee/my_tournees_fixtures.dart';
import '../domain/tournee/tournee_fixtures.dart';
import '../support/fakes/fake_member_account.dart';
import '../support/fakes/fake_my_tournees_store.dart';
import '../support/fakes/fake_tournee_directory.dart';
import '../support/results.dart';
import 'support/app_overrides.dart';

/// The 49 (open) and the 12, both of the CS Villefranche.
MyTournees _manusPhone() => valueOf(
  MyTournees.none.remember(tournee49).remember(tournee12).open(tournee49.id),
);

void main() {
  late FakeTourneeDirectory directory;

  Future<void> pumpApp(WidgetTester tester) async {
    directory = FakeTourneeDirectory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          myTournees: FakeMyTourneesStore(_manusPhone()),
          tourneeDirectory: directory,
          account: FakeMemberAccount(signedInMember: manuId),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'should say the member was removed from the open tournée and go back '
    'to the start screen with none open',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('home.team')));
      await tester.pumpAndSettle();
      expect(find.byType(TeamScreen), findsOneWidget);

      directory.lose(tournee49.id, TourneeLoss.removed);
      await tester.pumpAndSettle();

      expect(
        find.text('Vous avez été retiré de la tournée 49.'),
        findsOneWidget,
      );
      expect(find.byType(TeamScreen), findsNothing);
      expect(find.text('Tournée 49 · 2026'), findsNothing);
      expect(find.byKey(const Key('home.team')), findsNothing);
    },
  );

  testWidgets(
    'should say another tournée was deleted and stay on the open one',
    (tester) async {
      await pumpApp(tester);

      directory.lose(tournee12.id, TourneeLoss.deleted);
      await tester.pumpAndSettle();

      expect(find.text('La tournée 12 a été supprimée.'), findsOneWidget);
      expect(find.text('Tournée 49 · 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'should say the phone is no longer an admin when a visited tournée is '
    'forgotten',
    (tester) async {
      await pumpApp(tester);

      directory.lose(tournee12.id, TourneeLoss.adminRevoked);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Vous n\'êtes plus administrateur\u00a0: la tournée 12 est '
          'retirée de Mes tournées.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tournée 49 · 2026'), findsOneWidget);
    },
  );
}
