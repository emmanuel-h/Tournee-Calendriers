import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show team;
import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_server_connection.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

// Houses are marked only during a tournée (PLAN §5.14, « Marking only in a
// tournée », mockup StreetIdle): with none on, the street screen and the
// building grid show their marks, but a tap opens no picker and says why.

final _id = StreetId('lilas');

/// 7 a house to do; 8 a building, its RdC with two doors to do.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('7')),
      House(number: n('8'), building: building(topFloor: 0, doors: 2)),
    ],
  ),
);

const _needsRound = 'Commencez une tournée pour marquer les maisons.';
const _membersOnly = 'Seuls les membres en tournée marquent les maisons.';

Finder _tile(String number) => find.byKey(ValueKey('street.tile.$number'));
Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  late FakeStreetRepository streets;
  late FakeOpenRoundStore rounds;

  /// The street screen of [_lilas], offline, with [open] the secteur shown
  /// (the 49, where Léa is a member, by default) and [round] on the phone
  /// (none by default).
  Future<void> openStreet(
    WidgetTester tester, {
    SectorSummary? open,
    Round? round,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final opened = open ?? sector49;
    streets = FakeStreetRepository([_lilas]);
    rounds = FakeOpenRoundStore(round);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          rounds: rounds,
          connection: FakeServerConnection(offline: true),
          sectors: FakeSectorRepository([team()]),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(opened).open(opened.id)),
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push<void>(AppRoutes.streetOf(_id)).ignore();
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('should open no picker and say to start a tournée, with '
      '« Commencer », when a house is tapped with none on', (tester) async {
    await openStreet(tester);
    expect(_key('street.hint'), findsNothing);

    await tap(tester, _tile('7'));

    expect(_key('house.number'), findsNothing);
    expect(find.text(_needsRound), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Commencer'), findsOneWidget);
    expect(streets[_id], _lilas);
    expect(rounds.openRound, isNull);
  });

  testWidgets('should start the tournée offline with « Commencer », stay on '
      'the street, and open the picker on the next tap', (tester) async {
    await openStreet(tester);
    await tap(tester, _tile('7'));

    await tap(tester, find.widgetWithText(SnackBarAction, 'Commencer'));

    expect(rounds.openRound!.sector, sector49Id);
    expect(rounds.openRound!.startedAt, twoPm);
    expect(find.text(_needsRound), findsNothing);
    expect(_key('street.tiles'), findsOneWidget);
    expect(_key('round.band'), findsOneWidget);
    expect(_key('street.hint'), findsOneWidget);

    await tap(tester, _tile('7'));

    expect(_key('house.number'), findsOneWidget);
  });

  testWidgets('should say a tournée is on in another secteur when '
      '« Commencer » is tapped then', (tester) async {
    final elsewhere = Round.start(
      id: roundId,
      sector: SectorId('t12'),
      campaign: year2026,
      at: startedAt,
    );
    await openStreet(tester, round: elsewhere);
    await tap(tester, _tile('7'));

    await tap(tester, find.widgetWithText(SnackBarAction, 'Commencer'));

    expect(
      find.text('Une tournée est déjà en cours dans un autre secteur.'),
      findsOneWidget,
    );
    expect(rounds.openRound, elsewhere);
    expect(_key('house.number'), findsNothing);
  });

  testWidgets('should tell an admin visiting the secteur that only members '
      'on a tournée mark houses, with no action', (tester) async {
    await openStreet(tester, open: sector12Visited);

    await tap(tester, _tile('7'));

    expect(_key('house.number'), findsNothing);
    expect(find.text(_membersOnly), findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
    expect(_key('street.hint'), findsNothing);
  });

  testWidgets('should open a building grid with none on, but no door picker '
      'nor the building « Repasser »', (tester) async {
    await openStreet(tester);

    await tap(tester, _tile('8'));

    expect(_key('grid.count'), findsOneWidget);
    expect(_key('grid.hint'), findsNothing);

    await tap(tester, _key('grid.door.A0-01'));

    expect(_key('door.number'), findsNothing);
    expect(find.text(_needsRound), findsOneWidget);

    await tap(tester, _key('grid.details'));

    expect(_key('building.number'), findsNothing);
    expect(find.text(_needsRound), findsOneWidget);
    expect(streets[_id], _lilas);
  });

  testWidgets('should open the door picker once « Commencer » of the grid '
      'started the tournée', (tester) async {
    await openStreet(tester);
    await tap(tester, _tile('8'));
    await tap(tester, _key('grid.door.A0-01'));

    await tap(tester, find.widgetWithText(SnackBarAction, 'Commencer'));
    expect(_key('grid.hint'), findsOneWidget);
    await tap(tester, _key('grid.door.A0-01'));

    expect(rounds.openRound!.sector, sector49Id);
    expect(_key('door.number'), findsOneWidget);
  });

  testWidgets('should keep « Modifier la rue » with none on: that is '
      'preparation', (tester) async {
    await openStreet(tester);

    await tap(tester, _key('street.edit'));

    expect(find.widgetWithText(AppBar, 'Modifier la rue'), findsOneWidget);
  });
}
