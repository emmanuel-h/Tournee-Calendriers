// The message the app shows over the next screen when the member lost one
// of their tournées (PLAN §5.3): removed by an admin, the tournée deleted,
// or (a tournée only visited) the phone no longer an admin (PLAN §5.12).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_loss.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../domain/sector/my_sectors_fixtures.dart';
import '../domain/sector/sector_fixtures.dart';
import '../support/fakes/fake_member_account.dart';
import '../support/fakes/fake_my_sectors_store.dart';
import '../support/fakes/fake_sector_directory.dart';
import '../support/results.dart';
import 'support/app_overrides.dart';

/// The 49 (open) and the 12, both of the CS Villefranche.
MySectors _manusPhone() => valueOf(
  MySectors.none.remember(sector49).remember(sector12).open(sector49.id),
);

void main() {
  late FakeSectorDirectory directory;

  Future<void> pumpApp(WidgetTester tester) async {
    directory = FakeSectorDirectory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          mySectors: FakeMySectorsStore(_manusPhone()),
          sectorDirectory: directory,
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

      directory.lose(sector49.id, SectorLoss.removed);
      await tester.pumpAndSettle();

      expect(find.text('Vous avez été retiré du secteur 49.'), findsOneWidget);
      expect(find.byType(TeamScreen), findsNothing);
      expect(find.text('Secteur 49 · 2026'), findsNothing);
      expect(find.byKey(const Key('home.team')), findsNothing);
    },
  );

  testWidgets(
    'should say another tournée was deleted and stay on the open one',
    (tester) async {
      await pumpApp(tester);

      directory.lose(sector12.id, SectorLoss.deleted);
      await tester.pumpAndSettle();

      expect(find.text('Le secteur 12 a été supprimé.'), findsOneWidget);
      expect(find.text('Secteur 49 · 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'should say the phone is no longer an admin when a visited tournée is '
    'forgotten',
    (tester) async {
      await pumpApp(tester);

      directory.lose(sector12.id, SectorLoss.adminRevoked);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Vous n\'êtes plus administrateur\u00a0: le secteur 12 est '
          'retiré de Mes secteurs.',
        ),
        findsOneWidget,
      );
      expect(find.text('Secteur 49 · 2026'), findsOneWidget);
    },
  );
}
