import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../domain/round/round_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show team;
import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_open_round_store.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

// The calendars of a house or door done (#114, PLAN §5.6, RunStreet
// mockup): « 2 calendriers » and its « − » in the status picker, the round
// badge from two on the tile and on the door.

final _id = StreetId('lilas');

final _door = DwellingKey(escA, 0, d('01'));

/// 3 done with one calendar, 9 done with two, 7 to do; 8 a building whose
/// RdC door 01 is done with three calendars.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('3'), status: VisitStatus.done),
      House(number: n('7')),
      House(
        number: n('8'),
        building: building(topFloor: 0, doors: 2).withDwelling(
          escA,
          0,
          Dwelling(
            label: d('01'),
            status: VisitStatus.done,
            calendars: calendars(3),
          ),
        ),
      ),
      House(number: n('9'), status: VisitStatus.done, calendars: calendars(2)),
    ],
  ),
);

/// The 49's tournée with one don in it, 20 € by cheque.
Round _round() => Round.restore(
  id: roundId,
  sector: sector49Id,
  campaign: year2026,
  startedAt: startedAt,
  housesVisited: 3,
  donations: [cheque(2000)],
);

Finder _tile(String number) => find.byKey(ValueKey('street.tile.$number'));
Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  late FakeStreetRepository streets;
  late FakeOpenRoundStore rounds;

  /// The street screen of [_lilas] in the 49, open, with a tournée on: a
  /// house's picker opens only then (PLAN §5.14).
  Future<void> openStreet(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository([_lilas]);
    rounds = FakeOpenRoundStore(_round());
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          rounds: rounds,
          sectors: FakeSectorRepository([team()]),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sector49.id)),
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

  House stored(String number) =>
      streets[_id]!.houses.singleWhere((house) => house.number == n(number));

  Dwelling storedDoor() => stored('8').building!.dwellingAt(_door)!;

  List<Donation> dons() => rounds.openRound!.donations;

  IconButton minus(WidgetTester tester, String name) =>
      tester.widget<IconButton>(_key('$name.removeCalendar'));

  group('status picker', () {
    testWidgets('should take one calendar away with « − », the sheet open '
        'and the dons untouched', (tester) async {
      await openStreet(tester);
      await tap(tester, _tile('9'));
      expect(
        tester.widget<Text>(_key('house.calendars')).data,
        '2 calendriers',
      );
      expect(minus(tester, 'house').onPressed, isNotNull);
      expect(find.byTooltip('Enlever un calendrier'), findsOneWidget);

      await tap(tester, _key('house.removeCalendar'));

      expect(stored('9').calendars, calendars(1));
      expect(stored('9').lastChange, leaAtTwo);
      expect(tester.widget<Text>(_key('house.calendars')).data, '1 calendrier');
      expect(minus(tester, 'house').onPressed, isNull);
      expect(dons(), [cheque(2000)]);
      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('should show « 1 calendrier » with « − » disabled when the '
        'house took one', (tester) async {
      await openStreet(tester);

      await tap(tester, _tile('3'));

      expect(tester.widget<Text>(_key('house.calendars')).data, '1 calendrier');
      expect(minus(tester, 'house').onPressed, isNull);
    });

    testWidgets('should show no calendars on a house not done', (tester) async {
      await openStreet(tester);

      await tap(tester, _tile('7'));

      expect(_key('house.calendars'), findsNothing);
      expect(_key('house.removeCalendar'), findsNothing);
    });

    testWidgets('should take one calendar from a door with « − »', (
      tester,
    ) async {
      await openStreet(tester);
      await tap(tester, _tile('8'));
      await tap(tester, _key('grid.door.A0-01'));
      expect(tester.widget<Text>(_key('door.calendars')).data, '3 calendriers');

      await tap(tester, _key('door.removeCalendar'));

      expect(storedDoor().calendars, calendars(2));
      expect(dons(), [cheque(2000)]);
    });
  });

  group('badge', () {
    testWidgets('should show the calendars of a tile from two, and say '
        'them', (tester) async {
      await openStreet(tester);

      final nine = find.descendant(
        of: _tile('9'),
        matching: find.byKey(const Key('tile.calendars')),
      );
      expect(nine, findsOneWidget);
      expect(
        find.descendant(of: nine, matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(_tile('9')).label,
        'Numéro 9, fait, 2 calendriers, changer le statut',
      );
    });

    testWidgets('should show no badge on a tile that took one calendar', (
      tester,
    ) async {
      await openStreet(tester);

      expect(
        find.descendant(
          of: _tile('3'),
          matching: find.byKey(const Key('tile.calendars')),
        ),
        findsNothing,
      );
      expect(
        tester.getSemantics(_tile('3')).label,
        'Numéro 3, fait, changer le statut',
      );
    });

    testWidgets('should sit at the top right corner of its tile, half out', (
      tester,
    ) async {
      await openStreet(tester);

      final tile = tester.getRect(_tile('9'));
      final badge = tester.getRect(
        find.descendant(
          of: _tile('9'),
          matching: find.byKey(const Key('tile.calendars')),
        ),
      );
      expect(badge.top, tile.top - 7);
      expect(badge.right, tile.right + 7);
      expect(badge.height, 24);
    });

    testWidgets('should show the calendars of a door from two, and say '
        'them', (tester) async {
      await openStreet(tester);

      await tap(tester, _tile('8'));

      expect(
        find.descendant(
          of: _key('grid.door.A0-01'),
          matching: find.byKey(const Key('tile.calendars')),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(_key('grid.door.A0-01')).label,
        contains('fait, 3 calendriers'),
      );
    });
  });
}
