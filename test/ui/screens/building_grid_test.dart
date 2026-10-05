import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
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
import '../support/finders.dart';

final _id = StreetId('lilas');

/// 7: a single house. 8: two staircases, RdC–1er, two doors a floor; A 11
/// done, B 01 done: 2 of 8 doors done. 10: the RdC alone, two
/// doors, no mark.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('7')),
      House(number: n('10'), building: building(topFloor: 0, doors: 2)),
      House(
        number: n('8'),
        building: building(staircases: 2, topFloor: 1, doors: 2)
            .withDwelling(
              escA,
              1,
              Dwelling(label: d('11'), status: VisitStatus.done),
            )
            .withDwelling(
              escB,
              0,
              Dwelling(label: d('01'), status: VisitStatus.done),
            ),
      ),
    ],
  ),
);

Finder _tile(String number) => find.byKey(ValueKey('street.tile.$number'));
Finder _door(String id) => find.byKey(ValueKey('grid.door.$id'));
final _count = find.byKey(const Key('grid.count'));

void main() {
  late FakeStreetRepository streets;

  /// Opens the street screen of [_lilas] on a phone-sized screen.
  Future<void> openStreet(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
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
    router.push<void>(AppRoutes.streetOf(_id)).ignore();
    await tester.pumpAndSettle();
  }

  /// « Gérer l'immeuble » under the grid, then the menu's [action].
  Future<void> manage(WidgetTester tester, String action) async {
    await tester.tap(find.byKey(const Key('grid.manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('buildingMenu.$action')));
    await tester.pumpAndSettle();
  }

  House stored(String number) =>
      streets[_id]!.houses.singleWhere((house) => house.number == n(number));

  String labelOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).label;

  Dwelling storedDoor(DwellingKey key) => streets[_id]!.houses
      .singleWhere((house) => house.number == n('8'))
      .building!
      .dwellingAt(key)!;

  testWidgets(
    'should cycle a door and update the header count when a door is tapped',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      await tester.tap(_tile('8'));
      await tester.pumpAndSettle();
      expect(labelOf(tester, _count), '2 sur 8 logements faits');
      expect(
        labelOf(tester, _door('A1-12')),
        'Escalier A, 1er, porte 12, à faire',
      );
      expect(find.byKey(const Key('grid.hint')), findsOneWidget);

      await tester.tap(_door('A1-12'));
      await tester.pumpAndSettle();

      expect(
        labelOf(tester, _door('A1-12')),
        'Escalier A, 1er, porte 12, fait',
      );
      expect(labelOf(tester, _count), '3 sur 8 logements faits');
      expect(
        tester.takeAnnouncements().map((announcement) => announcement.message),
        ['Escalier A, 1er, porte 12, fait'],
      );
      expect(findArrowText('12 → Fait'), findsOneWidget);
      expect(find.byKey(const Key('grid.hint')), findsNothing);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(labelOf(tester, _count), '2 sur 8 logements faits');
      expect(
        storedDoor(DwellingKey(escA, 1, d('12'))),
        Dwelling(label: d('12')),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'should show the floors of the other staircase when it is chosen, and '
    'open a door sheet on a hold',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      await tester.tap(_tile('8'));
      await tester.pumpAndSettle();
      expect(find.text('Esc. A · 1/4'), findsOneWidget);
      expect(find.text('Esc. B · 1/4'), findsOneWidget);
      expect(_door('B0-01'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('grid.staircase.B')));
      await tester.pumpAndSettle();

      expect(_door('A1-11'), findsNothing);
      expect(
        labelOf(tester, _door('B0-01')),
        'Escalier B, RdC, porte 01, fait',
      );
      // The count covers the whole building, whatever staircase shows.
      expect(labelOf(tester, _count), '2 sur 8 logements faits');

      await tester.longPress(_door('B0-01'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('door.number')), findsOneWidget);
      expect(find.text('Esc. B · RdC · 8 Rue des Lilas'), findsOneWidget);
      // No free note on a door: too sensitive (PLAN §8.3).
      expect(find.byKey(const Key('door.note.field')), findsNothing);
      expect(find.byKey(const Key('house.toBuilding')), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'should open the grid of the new building when a house is described '
    'and validated',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      await tester.longPress(_tile('7'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('house.toBuilding')));
      await tester.pumpAndSettle();

      expect(find.text("Décrire l'immeuble"), findsOneWidget);
      expect(find.text('APERÇU · 6 LOGEMENTS'), findsOneWidget);
      expect(find.text('RdC 01–02, 1er 11–12, 2e 21–22'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('setup.doors.fewer')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('setup.doors.fewer')));
      await tester.pump();
      expect(find.text('Au moins 1 porte par étage.'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('setup.doors.value')))
            .data,
        '1',
      );

      await tester.tap(find.byKey(const ValueKey('setup.floors.more')));
      await tester.tap(find.byKey(const ValueKey('setup.staircases.more')));
      await tester.pump();
      expect(find.text('Au moins 1 porte par étage.'), findsNothing);
      expect(find.text('RdC–3e'), findsOneWidget);
      expect(
        find.text('Esc. A et B\u00a0: RdC 01, 1er 11 … 3e 31'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('setup.validate')));
      await tester.pumpAndSettle();

      expect(find.text("Décrire l'immeuble"), findsNothing);
      expect(labelOf(tester, _count), '0 sur 8 logements faits');
      expect(_door('A3-31'), findsOneWidget);
      expect(streets[_id]!.houses.first.building!.progress.total, 8);
      semantics.dispose();
    },
  );

  testWidgets(
    'should ask before a new layout drops a marked door, and keep it when '
    'not confirmed',
    (tester) async {
      await openStreet(tester);
      await tester.tap(_tile('8'));
      await tester.pumpAndSettle();
      await manage(tester, 'editFloors');
      expect(find.text('RdC–1er'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('setup.floors.fewer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('setup.validate')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier les étages\u00a0?'), findsOneWidget);
      expect(
        find.text(
          "1 porte marquée n'existe plus dans ce plan\u00a0: son statut et son "
          '«\u00a0repasser\u00a0» seront perdus.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('setup.confirm.cancel')));
      await tester.pumpAndSettle();

      expect(find.text("Décrire l'immeuble"), findsOneWidget);
      expect(streets.saved, isEmpty);

      await tester.tap(find.byKey(const Key('setup.validate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup.confirm.ok')));
      await tester.pumpAndSettle();

      expect(find.text("Décrire l'immeuble"), findsNothing);
      expect(_door('A1-11'), findsNothing);
      expect(find.text('Esc. A · 0/2'), findsOneWidget);
    },
  );

  testWidgets('should offer the three changes of the building under '
      '« Gérer l\'immeuble »', (tester) async {
    await openStreet(tester);
    await tester.tap(_tile('8'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('grid.details')),
        matching: find.text('Repasser'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('grid.manage')));
    await tester.pumpAndSettle();

    expect(find.text("Gérer l'immeuble"), findsNWidgets(2));
    for (final action in ['editFloors', 'adjustDoors', 'backToHouse']) {
      final row = find.byKey(ValueKey('buildingMenu.$action'));
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
    }

    await tester.tap(find.byKey(const ValueKey('buildingMenu.adjustDoors')));
    await tester.pumpAndSettle();

    expect(find.text('Modifier les portes'), findsOneWidget);
    expect(find.byKey(const ValueKey('doors.door.A1-11')), findsOneWidget);
  });

  testWidgets('should open the building own « Repasser », without a note, '
      'from the button under the grid', (tester) async {
    await openStreet(tester);
    await tester.tap(_tile('8'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('grid.details')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('building.number')), findsOneWidget);
    expect(find.byKey(const Key('building.note.field')), findsNothing);
    expect(find.textContaining('Note'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('building.comeBack')));
    await tester.pumpAndSettle();

    expect(stored('8').comeBack, ComeBack.withoutHint);
  });

  testWidgets('should ask before a building with marks becomes a house, then '
      'close the grid and offer Annuler', (tester) async {
    await openStreet(tester);
    await tester.tap(_tile('8'));
    await tester.pumpAndSettle();
    await manage(tester, 'backToHouse');

    expect(find.text('Changer en maison ?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('grid.confirmBackToHouse.cancel')),
    );
    await tester.pumpAndSettle();
    expect(_count, findsOneWidget);
    expect(stored('8').isBuilding, isTrue);

    await manage(tester, 'backToHouse');
    await tester.tap(find.byKey(const ValueKey('grid.confirmBackToHouse.ok')));
    await tester.pumpAndSettle();

    expect(_count, findsNothing);
    expect(stored('8').isBuilding, isFalse);
    expect(find.text('N° 8 changé en maison'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(
      stored('8'),
      _lilas.houses.singleWhere((house) => house.number == n('8')),
    );
  });

  testWidgets('should make a building without marks a house at once', (
    tester,
  ) async {
    await openStreet(tester);
    await tester.tap(_tile('10'));
    await tester.pumpAndSettle();

    await manage(tester, 'backToHouse');

    expect(find.text('Changer en maison ?'), findsNothing);
    expect(_count, findsNothing);
    expect(stored('10').isBuilding, isFalse);
  });

  testWidgets('should give staircase B its own floors and doors when the box '
      'is unticked', (tester) async {
    final semantics = tester.ensureSemantics();
    await openStreet(tester);
    await tester.tap(_tile('8'));
    await tester.pumpAndSettle();
    await manage(tester, 'editFloors');
    final box = find.byKey(const Key('setup.sameForEach'));
    expect(tester.widget<CheckboxListTile>(box).value, isTrue);
    expect(find.text('ESC. B'), findsNothing);

    await tester.tap(box);
    await tester.pump();

    expect(tester.widget<CheckboxListTile>(box).value, isFalse);
    expect(find.text('ESC. A'), findsOneWidget);
    expect(find.text('ESC. B'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('setup.B.floors.fewer'))),
      matchesSemantics(
        label: 'Un étage de moins, escalier B',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('setup.B.floors.fewer')),
    );
    await tester.tap(find.byKey(const ValueKey('setup.B.floors.fewer')));
    await tester.tap(find.byKey(const ValueKey('setup.B.doors.more')));
    await tester.pump();

    String valueOf(String key) =>
        tester.widget<Text>(find.byKey(ValueKey('setup.$key.value'))).data!;
    expect(valueOf('A.floors'), 'RdC–1er');
    expect(valueOf('A.doors'), '2');
    expect(valueOf('B.floors'), 'RdC');
    expect(valueOf('B.doors'), '3');
    expect(find.text('APERÇU · 7 LOGEMENTS'), findsOneWidget);
    expect(
      find.text('Esc. A : RdC 01–02, 1er 11–12\nEsc. B : RdC 01–03'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('setup.validate')));
    await tester.tap(find.byKey(const Key('setup.validate')));
    await tester.pumpAndSettle();

    expect(find.text("Décrire l'immeuble"), findsNothing);
    expect(find.text('Esc. B · 1/3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grid.staircase.B')));
    await tester.pumpAndSettle();
    expect(_door('B0-03'), findsOneWidget);
    expect(_door('B1-11'), findsNothing);
    semantics.dispose();
  });

  testWidgets('should open the grid from a building\'s number in edit mode, '
      'and come back to it a house', (tester) async {
    await openStreet(tester);
    await tester.tap(find.byKey(const Key('street.edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('edit.tile.10')),
        matching: find.byKey(const Key('edit.tile.number')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('number.renumber')), findsOneWidget);
    expect(find.byKey(const Key('number.toBuilding')), findsNothing);

    await tester.tap(find.byKey(const Key('number.openBuilding')));
    await tester.pumpAndSettle();

    expect(_door('A0-01'), findsOneWidget);

    await manage(tester, 'backToHouse');

    expect(_count, findsNothing);
    expect(find.byKey(const Key('edit.ok')), findsOneWidget);
    expect(find.text('N° 10 changé en maison'), findsOneWidget);
    expect(stored('10').isBuilding, isFalse);
  });
}
