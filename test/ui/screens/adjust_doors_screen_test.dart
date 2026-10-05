import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/navigation.dart';

final _id = StreetId('lilas');

/// 8: one staircase, RdC and 1er, two « Libres » doors a floor (1 and 2);
/// door 1 of the 1er is done.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('1')),
      House(
        number: n('8'),
        building: building(topFloor: 1, doors: 2, style: DoorLabelStyle.free)
            .withDwelling(
              escA,
              1,
              Dwelling(label: d('1'), status: VisitStatus.done),
            ),
      ),
    ],
  ),
);

Finder _door(String id) => find.byKey(ValueKey('doors.door.$id'));

Finder _part(String id, String part) => find.descendant(
  of: _door(id),
  matching: find.byKey(Key('doors.door.$part')),
);

void main() {
  late FakeStreetRepository streets;

  /// Starts the app with the Rue des Lilas on the phone, opens its edit
  /// mode, taps 8 and « Ajuster les portes ».
  Future<void> openAdjustDoors(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393 * 3, 852 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository([_lilas]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(streets: streets),
        child: const TourneeApp(showGallery: false),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaitedPush(router, AppRoutes.editStreetOf(_id));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('edit.tile.8')),
        matching: find.byKey(const Key('edit.tile.number')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('number.adjustDoors')));
    await tester.pumpAndSettle();
  }

  /// The building as stored now.
  Building stored() =>
      streets[_id]!.houses.firstWhere((house) => house.isBuilding).building!;

  /// The labels of the floor at [level], as stored.
  List<String> labelsAt(int level) => [
    for (final dwelling in stored().staircases.single.floor(level)!.dwellings)
      dwelling.label.text,
  ];

  Future<void> rename(WidgetTester tester, String id, String name) async {
    await tester.tap(_part(id, 'rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('renameDoor.field')), name);
    await tester.tap(find.byKey(const Key('renameDoor.rename')));
    await tester.pumpAndSettle();
  }

  testWidgets('should rename a door Gauche on two floors and refuse it twice '
      'on one', (tester) async {
    await openAdjustDoors(tester);
    expect(find.text('8 Rue des Lilas'), findsOneWidget);

    await tester.tap(_part('A1-1', 'rename'));
    await tester.pumpAndSettle();
    expect(find.text('Porte 1'), findsOneWidget);
    expect(find.text('1er · 8 Rue des Lilas'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('renameDoor.field')), 'Gauche');
    await tester.tap(find.byKey(const Key('renameDoor.rename')));
    await tester.pumpAndSettle();
    await rename(tester, 'A0-1', 'Gauche');

    expect(_door('A1-Gauche'), findsOneWidget);
    expect(_door('A0-Gauche'), findsOneWidget);
    expect(labelsAt(1), ['Gauche', '2']);
    expect(labelsAt(0), ['Gauche', '2']);
    expect(
      stored().dwellingAt(DwellingKey(escA, 1, d('Gauche')))!.status,
      VisitStatus.done,
    );

    await rename(tester, 'A1-2', 'Gauche');

    expect(find.text('Ce nom est déjà pris à cet étage.'), findsOneWidget);
    expect(labelsAt(1), ['Gauche', '2']);
  });

  testWidgets('should add and remove a door on one floor and keep the marks '
      'of the others', (tester) async {
    await openAdjustDoors(tester);

    await tester.tap(find.byKey(const ValueKey('doors.add.1')));
    await tester.pumpAndSettle();

    expect(_door('A1-3'), findsOneWidget);
    expect(labelsAt(1), ['1', '2', '3']);

    await tester.tap(_part('A1-2', 'remove'));
    await tester.pumpAndSettle();

    expect(_door('A1-2'), findsNothing);
    expect(find.text('Porte 2 supprimée'), findsOneWidget);
    expect(labelsAt(1), ['1', '3']);
    expect(labelsAt(0), ['1', '2']);
    expect(
      stored().dwellingAt(DwellingKey(escA, 1, d('1')))!.status,
      VisitStatus.done,
    );

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(labelsAt(1), ['1', '2', '3']);
  });

  testWidgets('should ask before removing a door with a mark', (tester) async {
    await openAdjustDoors(tester);

    await tester.tap(_part('A1-1', 'remove'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer la porte 1 ?'), findsOneWidget);
    expect(find.text('Garder'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('doors.confirmRemove.cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Garder'), findsNothing);
    expect(labelsAt(1), ['1', '2']);
    expect(streets.saved, isEmpty);

    await tester.tap(_part('A1-1', 'remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doors.confirmRemove.ok')));
    await tester.pumpAndSettle();

    expect(_door('A1-1'), findsNothing);
    expect(find.text('Porte 1 supprimée'), findsOneWidget);
    expect(labelsAt(1), ['2']);
  });
}
