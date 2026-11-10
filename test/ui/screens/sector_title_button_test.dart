import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/screens/my_sectors/my_sectors_sheet.dart';
import 'package:tournee_calendriers/ui/screens/team/team_screen.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/results.dart';
import '../support/app_overrides.dart';

/// The 12 of the CS Villefranche, where Léa is too.
final Sector _sector12 = valueOf(
  Sector.create(
    id: SectorId('t12'),
    number: valueOf(SectorNumber.create(12)),
    centre: csVillefranche,
    joinCode: codeOf('M4R-8ZT'),
    createdBy: manuId,
    createdAt: createdAt,
    currentCampaign: campaign2026,
    members: [manu, lea],
  ),
);

void main() {
  late FakeSectorRepository sectors;
  late FakeMySectorsStore store;

  /// The start screen of Léa's phone, which keeps the 49 and the 12; the
  /// 49 ([stored], read from [readable] sectors) is open unless [noSector].
  /// [silent]: the secteurs are never read, as before Firestore answers.
  Future<void> pumpStart(
    WidgetTester tester, {
    Sector? stored,
    List<Sector>? readable,
    bool noSector = false,
    bool silent = false,
  }) async {
    sectors = FakeSectorRepository(readable ?? [stored ?? team(), _sector12])
      ..watchSilent = silent;
    store = FakeMySectorsStore(
      noSector
          ? MySectors.none
          : valueOf(
              MySectors.none
                  .remember(sector49)
                  .remember(sector12)
                  .open(sector49.id),
            ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(mySectors: store, sectors: sectors, member: leaId),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('the title of Accueil (PLAN §5.3, §5.14, #135)', () {
    testWidgets('should open « Mes secteurs » from the app\'s name when no '
        'secteur is open', (tester) async {
      await pumpStart(tester, noSector: true);

      await tapKey(tester, 'home.appTitle');

      expect(find.byType(MySectorsSheet), findsOneWidget);
      expect(find.byType(TeamScreen), findsNothing);
    });

    testWidgets('should open Secteur when the open secteur\'s title is '
        'tapped', (tester) async {
      await pumpStart(tester, stored: team(members: [manu, lea]));

      await tapKey(tester, 'home.sector');

      expect(find.byType(TeamScreen), findsOneWidget);
      expect(find.byType(MySectorsSheet), findsNothing);
      expect(find.text('Secteur 49'), findsOneWidget);
    });

    testWidgets('should have no Secteur button beside the title', (
      tester,
    ) async {
      await pumpStart(tester, stored: team(members: [manu, lea]));

      expect(find.byIcon(Icons.map_outlined), findsNothing);
      expect(find.byTooltip('Secteur'), findsNothing);
      expect(find.byKey(const Key('home.settings')), findsOneWidget);
    });

    testWidgets('should name the secteur and its centre, with no dot, when '
        'no request waits', (tester) async {
      await pumpStart(tester, stored: team(members: [manu, lea]));

      expect(
        find.bySemanticsLabel('Secteur 49 · 2026, CS Villefranche'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home.sector.dot')), findsNothing);
    });

    testWidgets('should put a dot on the title, and say it, while a request '
        'waits', (tester) async {
      await pumpStart(tester);

      expect(find.byKey(const Key('home.sector.dot')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Secteur 49 · 2026, CS Villefranche, 1 demande en attente',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should count the requests waiting', (tester) async {
      await pumpStart(
        tester,
        stored: team(
          members: [
            manu,
            lea,
            julie,
            Member(id: paulId, name: nameOf('Paul'), requestedAt: julieAskedAt),
          ],
        ),
      );

      expect(
        find.bySemanticsLabel(
          'Secteur 49 · 2026, CS Villefranche, 2 demandes en attente',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should take the dot off once the request is answered', (
      tester,
    ) async {
      await pumpStart(tester);

      sectors.put(team(members: [manu, lea]));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.sector.dot')), findsNothing);
      expect(
        find.bySemanticsLabel('Secteur 49 · 2026, CS Villefranche'),
        findsOneWidget,
      );
    });
  });

  group('« Changer de secteur » in Secteur (PLAN §5.8, #135)', () {
    testWidgets('should come first in Secteur, before the code', (
      tester,
    ) async {
      await pumpStart(tester, stored: team(members: [manu, lea]));
      await tapKey(tester, 'home.sector');

      final row = find.byKey(const Key('team.changeSector'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Changer de secteur')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.swap_horiz)),
        findsOneWidget,
      );
      expect(
        tester.getRect(row).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('K7P-2QX')).top),
      );
      expect(find.bySemanticsLabel('Changer de secteur'), findsOneWidget);
    });

    testWidgets('should open « Mes secteurs » over Secteur', (tester) async {
      await pumpStart(tester, stored: team(members: [manu, lea]));
      await tapKey(tester, 'home.sector');

      await tapKey(tester, 'team.changeSector');

      expect(find.byType(MySectorsSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('mySectors.t12')), findsOneWidget);
    });

    testWidgets('should show the secteur picked in Secteur, and on Accueil '
        'once back', (tester) async {
      await pumpStart(tester, stored: team(members: [manu, lea]));
      await tapKey(tester, 'home.sector');
      await tapKey(tester, 'team.changeSector');

      await tester.tap(find.byKey(const ValueKey('mySectors.t12')));
      await tester.pumpAndSettle();

      expect(find.byType(MySectorsSheet), findsNothing);
      expect(store.saves.single.current, sector12);
      expect(find.byType(TeamScreen), findsOneWidget);
      expect(find.text('Secteur 12'), findsOneWidget);
      expect(find.text('M4R-8ZT'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Secteur 12 · 2026'), findsOneWidget);
    });

    testWidgets('should offer it alone while the secteur is being read', (
      tester,
    ) async {
      await pumpStart(tester, silent: true);
      await tapKey(tester, 'home.sector');

      expect(find.byKey(const Key('team.list')), findsNothing);
      expect(find.byKey(const Key('team.message')), findsNothing);

      await tapKey(tester, 'team.changeSector');

      expect(find.byType(MySectorsSheet), findsOneWidget);
    });

    testWidgets('should still offer it when the secteur cannot be shown', (
      tester,
    ) async {
      // Neither secteur can be read: Secteur says so.
      await pumpStart(tester, readable: []);
      await tapKey(tester, 'home.sector');

      expect(find.byKey(const Key('team.message')), findsOneWidget);

      await tapKey(tester, 'team.changeSector');

      expect(find.byType(MySectorsSheet), findsOneWidget);
    });
  });
}
