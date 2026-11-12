// « À repasser » (PLAN §5.17, mockups HomeComeBack, ComeBackList,
// StreetRing): its row on Accueil, the list by day, and the street opened
// at the house, ringed. The critical interactions: open the list, open a
// house from it, open a door from it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';

import '../../domain/come_back/come_back_fixtures.dart';
import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart' show leaId, manuId, team;
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';

/// Saturday 24 October 2026 at 14 h on the phone's clock.
final _saturday2pm = DateTime(2026, 10, 24, 14);

final _byLea = ChangeStamp(by: leaId, at: twoPm);
final _byManu = ChangeStamp(by: manuId, at: twoPm);

/// Rue Nationale: 1 to 30, 12 « repasser » today at 19 h (Léa, on the
/// phone): far enough down the street to need a scroll.
final _nationale = valueOf(
  Street.create(
    id: nationaleId,
    name: 'Rue Nationale',
    commune: villefranche,
    houses: [
      for (var number = 1; number <= 30; number++)
        if (number == 24)
          House(
            number: n('$number'),
            status: VisitStatus.comeBack,
            comeBack: comeBack('2026-10-24', hour: 19),
            lastChange: _byLea,
          )
        else
          House(number: n('$number')),
    ],
  ),
);

/// Rue Pasteur: 5 yesterday at 18 h (Manu); door 51 of the building 8,
/// no time, set by Manu.
final _pasteur = valueOf(
  Street.create(
    id: pasteurId,
    name: 'Rue Pasteur',
    commune: villefranche,
    houses: [
      House(
        number: n('5'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-10-23', hour: 18),
        lastChange: _byManu,
      ),
      House(
        number: n('8'),
        building: valueOf(
          Building.create(
            style: DoorLabelStyle.floorAndNumber,
            staircases: [
              Staircase(
                name: escA,
                floors: [
                  Floor(
                    level: 5,
                    dwellings: [
                      Dwelling(
                        label: d('51'),
                        status: VisitStatus.comeBack,
                        lastChange: _byManu,
                      ),
                      Dwelling(label: d('52')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);

/// Allée des Pins: 3 tomorrow, no hour (Léa).
final _pins = valueOf(
  Street.create(
    id: pinsId,
    name: 'Allée des Pins',
    commune: villefranche,
    houses: [
      House(
        number: n('3'),
        status: VisitStatus.comeBack,
        comeBack: comeBack('2026-10-25'),
        lastChange: _byLea,
      ),
    ],
  ),
);

Finder _key(String key) => find.byKey(ValueKey(key));

/// Half a second of frames, as the phone draws them: the screen opens, the
/// street is read, the list scrolls, the sheet slides up. Short of the
/// ring's two seconds, which `pumpAndSettle` would wait out.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  /// Accueil of the 49 holding [streets], Léa on the phone, offline.
  Future<void> pumpHome(WidgetTester tester, List<Street> streets) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: FakeStreetRepository(streets),
          sectors: FakeSectorRepository([team()]),
          member: leaId,
          clock: FakeClock(_saturday2pm),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sector49.id)),
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(_key('home.comeBacks'));
    await tester.pumpAndSettle();
  }

  testWidgets('should show no row on Accueil without any « repasser »', (
    tester,
  ) async {
    await pumpHome(tester, [
      valueOf(
        Street.create(
          id: nationaleId,
          name: 'Rue Nationale',
          commune: villefranche,
          houses: [House(number: n('1'))],
        ),
      ),
    ]);

    expect(_key('home.comeBacks'), findsNothing);
  });

  testWidgets('should show the count and the next on Accueil', (tester) async {
    await pumpHome(tester, [_nationale, _pasteur, _pins]);

    expect(find.text('À repasser (4)'), findsOneWidget);
    expect(find.text('Prochain\u00a0: aujourd\'hui vers 19 h'), findsOneWidget);
    expect(find.bySemanticsLabel('À repasser, 4 maisons'), findsOneWidget);
  });

  testWidgets('should show no next when none has a day from today on', (
    tester,
  ) async {
    await pumpHome(tester, [_pasteur]);

    expect(find.text('À repasser (2)'), findsOneWidget);
    expect(_key('home.comeBacks.next'), findsNothing);
  });

  testWidgets('should list the « repasser » by day, the past at any time', (
    tester,
  ) async {
    await pumpHome(tester, [_nationale, _pasteur, _pins]);

    await openList(tester);

    expect(find.widgetWithText(AppBar, 'À repasser (4)'), findsOneWidget);
    expect(find.text('vous recevrez un rappel'), findsOneWidget);
    expect(find.text('AUJOURD\'HUI'), findsOneWidget);
    expect(find.text('DEMAIN'), findsOneWidget);
    expect(find.text('À TOUT MOMENT'), findsOneWidget);
    expect(find.text('19 h'), findsOneWidget);
    expect(find.text('24 Rue Nationale'), findsOneWidget);
    expect(find.text('par vous'), findsOneWidget);
    expect(find.text('3 Allée des Pins'), findsOneWidget);
    expect(find.text('par vous · pas d\'heure'), findsOneWidget);
    expect(find.text('5 Rue Pasteur'), findsOneWidget);
    expect(find.text('C\'était hier vers 18 h · par Manu'), findsOneWidget);
    expect(find.text('Porte 51 · 8 Rue Pasteur'), findsOneWidget);
    expect(find.text('par Manu'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Aujourd\'hui vers 19 h, 24 Rue Nationale, rappel prévu',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('5 Rue Pasteur, c\'était hier vers 18 h'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Porte 51 · 8 Rue Pasteur'), findsOneWidget);
    // Léa's two ring this phone; Manu's do not.
    expect(_key('comeBacks.bell'), findsNWidgets(2));
    expect(
      find.text('Touchez une maison pour la voir dans sa rue.'),
      findsOneWidget,
    );
  });

  testWidgets('should open the street at the house, ringed for a moment', (
    tester,
  ) async {
    await pumpHome(tester, [_nationale, _pasteur, _pins]);
    await openList(tester);

    await tester.tap(find.text('24 Rue Nationale'));
    await _pumpFrames(tester);

    expect(find.widgetWithText(AppBar, 'Rue Nationale'), findsOneWidget);
    // Scrolled down to it, ringed, its come-back in the pill.
    expect(_key('street.tile.24'), findsOneWidget);
    expect(_key('ringPulse.ring'), findsOneWidget);
    expect(
      find.text('N° 24 · repasser aujourd\'hui vers 19 h'),
      findsOneWidget,
    );
    expect(
      tester.getCenter(_key('street.tile.24')).dy,
      greaterThan(tester.getSize(find.byType(MaterialApp)).height / 3),
    );

    await tester.pump(const Duration(seconds: 2));

    expect(_key('ringPulse.ring'), findsNothing);
    // The pill keeps saying it until the first tap.
    expect(
      find.text('N° 24 · repasser aujourd\'hui vers 19 h'),
      findsOneWidget,
    );

    await tester.tap(_key('street.tile.23'));
    await tester.pumpAndSettle();

    expect(find.text('N° 24 · repasser aujourd\'hui vers 19 h'), findsNothing);
  });

  testWidgets('should say a day gone in the pill', (tester) async {
    await pumpHome(tester, [_pasteur]);
    await openList(tester);

    await tester.tap(find.text('5 Rue Pasteur'));
    await tester.pumpAndSettle();

    expect(find.text('N° 5 · c\'était hier vers 18 h'), findsOneWidget);
  });

  testWidgets('should open the building\'s grid at the door, ringed', (
    tester,
  ) async {
    await pumpHome(tester, [_pasteur]);
    await openList(tester);

    await tester.tap(find.text('Porte 51 · 8 Rue Pasteur'));
    await _pumpFrames(tester);

    expect(_key('grid.door.A5-51'), findsOneWidget);
    // The ring sits with the door it rings, and only there.
    expect(
      find.descendant(
        of: find
            .ancestor(of: _key('grid.door.A5-51'), matching: find.byType(Stack))
            .first,
        matching: _key('ringPulse.ring'),
      ),
      findsOneWidget,
    );
    expect(_key('ringPulse.ring'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(_key('ringPulse.ring'), findsNothing);
  });

  testWidgets('should say there is nothing left once all are cleared', (
    tester,
  ) async {
    final streets = FakeStreetRepository([_pins]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(
          streets: streets,
          member: leaId,
          clock: FakeClock(_saturday2pm),
          mySectors: FakeMySectorsStore(
            valueOf(MySectors.none.remember(sector49).open(sector49.id)),
          ),
        ),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    await openList(tester);

    await streets.purge(pinsId);
    await tester.pumpAndSettle();

    expect(find.text('Plus aucune maison à repasser.'), findsOneWidget);
    expect(find.text('vous recevrez un rappel'), findsNothing);
  });
}
