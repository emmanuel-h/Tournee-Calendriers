import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import '../support/finders.dart';

final _id = StreetId('lilas');

/// 7: a single house. 8: two staircases, RdC–1er, two doors a floor; A 11
/// done, B 01 done with a note: 2 of 8 doors done.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('7')),
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
              Dwelling(
                label: d('01'),
                status: VisitStatus.done,
                note: note('digicode'),
              ),
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
        'Escalier B, RdC, porte 01, fait, avec une note',
      );
      // The count covers the whole building, whatever staircase shows.
      expect(labelOf(tester, _count), '2 sur 8 logements faits');

      await tester.longPress(_door('B0-01'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('door.number')), findsOneWidget);
      expect(find.text('Esc. B · RdC · 8 Rue des Lilas'), findsOneWidget);
      expect(find.text('digicode'), findsOneWidget);
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
      expect(find.text('Esc. A et B : RdC 01, 1er 11 … 3e 31'), findsOneWidget);

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
      await tester.tap(find.byKey(const Key('grid.editFloors')));
      await tester.pumpAndSettle();
      expect(find.text('RdC–1er'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('setup.floors.fewer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('setup.validate')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier les étages ?'), findsOneWidget);
      expect(
        find.text(
          "1 porte marquée n'existe plus dans ce plan : son statut, sa note "
          'et son « repasser » seront perdus.',
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
}
