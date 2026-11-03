import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';

void main() {
  late FakeSectorRepository sectors;

  /// The start screen of Léa's phone; the 49 ([stored]) is open unless
  /// [noSector].
  Future<void> pumpStart(
    WidgetTester tester, {
    Sector? stored,
    bool noSector = false,
  }) async {
    sectors = FakeSectorRepository([stored ?? team()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          mySectors: FakeMySectorsStore(
            noSector
                ? MySectors.none
                : valueOf(MySectors.none.remember(sector49).open(sector49.id)),
          ),
          sectors: sectors,
          member: leaId,
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('should have no Secteur button when no secteur is open', (
    tester,
  ) async {
    await pumpStart(tester, noSector: true);

    expect(find.byKey(const Key('home.sectorButton')), findsNothing);
  });

  testWidgets('should show the folded map, said « Secteur », when no '
      'request waits', (tester) async {
    await pumpStart(tester, stored: team(members: [manu, lea]));

    final button = find.byKey(const Key('home.sectorButton'));
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.map_outlined)),
      findsOneWidget,
    );
    expect(find.byTooltip('Secteur'), findsOneWidget);
    expect(find.bySemanticsLabel('Secteur'), findsOneWidget);
    expect(find.byKey(const Key('home.sectorButton.dot')), findsNothing);
  });

  testWidgets('should show a dot on the Secteur button, and say it, while a '
      'request waits', (tester) async {
    await pumpStart(tester);

    expect(find.byKey(const Key('home.sectorButton.dot')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Secteur, 1 demande en attente'),
      findsOneWidget,
    );
  });

  testWidgets('should take the dot off once the request is answered', (
    tester,
  ) async {
    await pumpStart(tester);

    sectors.put(team(members: [manu, lea]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home.sectorButton.dot')), findsNothing);
    expect(find.bySemanticsLabel('Secteur'), findsOneWidget);
  });

  testWidgets('should open Secteur when the Secteur button is tapped', (
    tester,
  ) async {
    await pumpStart(tester, stored: team(members: [manu, lea]));

    await tester.tap(find.byKey(const Key('home.sectorButton')));
    await tester.pumpAndSettle();

    expect(find.byType(TeamScreen), findsOneWidget);
    expect(find.text('Secteur 49'), findsOneWidget);
  });
}
