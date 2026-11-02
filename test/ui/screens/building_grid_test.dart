import 'dart:ui' show Tristate;

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
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

import '../../support/building_fixtures.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/finders.dart';
import '../support/large_text.dart';

final _id = StreetId('lilas');

/// 7: a single house. 8: two staircases, RdC–1er, two doors a floor; A 11
/// done, B 01 done: 2 of 8 doors done; A 01 nobody home twice. 10: the RdC
/// alone, two doors, no mark.
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
            )
            .withDwelling(
              escA,
              0,
              Dwelling(
                label: d('01'),
                status: VisitStatus.nobodyHome,
                tries: tries(2),
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

  /// Taps the door [id], then [status] in its picker.
  Future<void> markDoor(
    WidgetTester tester,
    String id,
    VisitStatus status,
  ) async {
    await tester.tap(_door(id));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('door.status.${status.name}')));
    await tester.pumpAndSettle();
  }

  List<String> announcements(WidgetTester tester) => [
    for (final announcement in tester.takeAnnouncements()) announcement.message,
  ];

  testWidgets(
    'should open the picker of a door on a tap, store the status chosen, '
    'count it and put it back with « Annuler »',
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
      expect(
        tester.widget<Text>(find.byKey(const Key('grid.hint'))).data,
        'Appuyez sur une porte pour changer son statut',
      );

      await tester.tap(_door('A1-12'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('door.number'))).data,
        'Porte 12 · À faire',
      );
      expect(
        tester.getSemantics(_door('A1-12')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('door.status.done')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('door.number')), findsNothing);
      expect(
        labelOf(tester, _door('A1-12')),
        'Escalier A, 1er, porte 12, fait',
      );
      expect(labelOf(tester, _count), '3 sur 8 logements faits');
      expect(announcements(tester), ['Escalier A, 1er, porte 12, fait']);
      expect(findArrowText('Porte 12\u00a0: fait'), findsOneWidget);
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
    'name the staircase in the picker of its door',
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

      await tester.tap(_door('B0-01'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('door.number'))).data,
        'Porte 01 · Fait',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('door.place'))).data,
        'Esc. B · RdC · 8 Rue des Lilas',
      );
      // No free note on a door: too sensitive (PLAN §8.3).
      expect(find.byKey(const Key('door.note.field')), findsNothing);
      expect(find.byKey(const Key('house.toBuilding')), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'should make a house a building from edit mode, then open its grid',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      await tester.tap(find.byKey(const Key('street.edit')));
      await tester.pumpAndSettle();
      Future<void> tapNumber() async {
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('edit.tile.7')),
            matching: find.byKey(const Key('edit.tile.number')),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tapNumber();
      await tester.tap(find.byKey(const Key('number.toBuilding')));
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

      // Back in edit mode (PLAN §5.5); its number opens the grid.
      expect(find.text("Décrire l'immeuble"), findsNothing);
      await tapNumber();
      await tester.tap(find.byKey(const Key('number.openBuilding')));
      await tester.pumpAndSettle();
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

    expect(stored('8').comeBack, ComeBack.withoutTime);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('building.comeBackSummary')))
          .data,
      'Pas de jour choisi',
    );

    await tester.tap(
      find.byKey(const ValueKey('building.comeBackDay.2026-11-03')),
    );
    await tester.pumpAndSettle();

    expect(stored('8').comeBack, comeBack('2026-11-03'));
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

  testWidgets('should close the grid, keeping the door just marked, when the '
      '✕ is tapped', (tester) async {
    final semantics = tester.ensureSemantics();
    await openStreet(tester);
    await tester.tap(_tile('8'));
    await tester.pumpAndSettle();
    await markDoor(tester, 'A1-12', VisitStatus.done);
    expect(
      tester.getSemantics(find.byKey(const Key('grid.close'))).tooltip,
      'Fermer',
    );

    await tester.tap(find.byKey(const Key('grid.close')));
    await tester.pumpAndSettle();

    expect(_count, findsNothing);
    expect(findArrowText('Porte 12\u00a0: fait'), findsNothing);
    expect(find.textContaining('changé en maison'), findsNothing);
    expect(_tile('8'), findsOneWidget);
    expect(storedDoor(DwellingKey(escA, 1, d('12'))).status, VisitStatus.done);
    semantics.dispose();
  });

  testWidgets('should still close the grid when it is swiped down', (
    tester,
  ) async {
    await openStreet(tester);
    await tester.tap(_tile('8'));
    await tester.pumpAndSettle();

    await tester.fling(_count, const Offset(0, 800), 2000);
    await tester.pumpAndSettle();

    expect(_count, findsNothing);
    expect(find.byKey(const Key('grid.close')), findsNothing);
    expect(_tile('8'), findsOneWidget);
    expect(find.textContaining('changé en maison'), findsNothing);
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

  testWidgets(
    'should count one more try with « De nouveau personne » on a door nobody '
    'was home at, then put it back with « Annuler »',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      await tester.tap(_tile('8'));
      await tester.pumpAndSettle();
      expect(
        labelOf(tester, _door('A0-01')),
        'Escalier A, RdC, porte 01, personne, 2e passage',
      );
      expect(
        find.descendant(of: _door('A0-01'), matching: find.text('×2')),
        findsOneWidget,
      );

      await tester.tap(_door('A0-01'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('door.tries'))).data,
        '2 passages sans personne',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('door.status.nobodyHome')))
            .label,
        'De nouveau personne',
      );
      await tester.tap(find.byKey(const ValueKey('door.status.nobodyHome')));
      await tester.pumpAndSettle();

      // Back on the grid, which tells what changed.
      expect(find.byKey(const Key('door.number')), findsNothing);
      final key = DwellingKey(escA, 0, d('01'));
      expect(storedDoor(key).tries, tries(3));
      expect(
        findArrowText('Porte 01\u00a0: personne (3e passage)'),
        findsOneWidget,
      );
      expect(announcements(tester), [
        'Escalier A, RdC, porte 01, personne, 3e passage',
      ]);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(storedDoor(key).tries, tries(2));
      semantics.dispose();
    },
  );

  testWidgets('should have no status, nor « De nouveau personne », on the '
      'building own sheet', (tester) async {
    await openStreet(tester);
    await tester.tap(_tile('8'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('grid.details')));
    await tester.pumpAndSettle();

    // No status of its own: its doors carry them.
    expect(find.byKey(const ValueKey('building.status.done')), findsNothing);
    expect(find.text('De nouveau personne'), findsNothing);
    expect(find.byKey(const Key('building.number')), findsOneWidget);
  });

  testWidgets(
    'should ask when to come back to a door after « Repasser », then put it '
    'back as it was with « Annuler »',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openStreet(tester);
      await tester.tap(_tile('8'));
      await tester.pumpAndSettle();
      final key = DwellingKey(escA, 0, d('01'));

      await markDoor(tester, 'A0-01', VisitStatus.comeBack);

      expect(storedDoor(key).status, VisitStatus.comeBack);
      expect(
        tester.widget<Text>(find.byKey(const Key('door.comeBackTitle'))).data,
        'Porte 01 · quand repasser\u00a0?',
      );
      await tester.tap(
        find.byKey(const ValueKey('door.comeBackDay.2026-11-03')),
      );
      await tester.pumpAndSettle();
      expect(storedDoor(key).comeBack, comeBack('2026-11-03'));
      await tester.tap(find.byKey(const Key('door.validate')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('door.comeBackTitle')), findsNothing);
      expect(findArrowText('Porte 01\u00a0: repasser'), findsOneWidget);
      expect(announcements(tester), [
        'Escalier A, RdC, porte 01, repasser, 2 passages sans personne',
      ]);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(storedDoor(key).status, VisitStatus.nobodyHome);
      expect(storedDoor(key).comeBack, isNull);
      expect(storedDoor(key).tries, tries(2));
      expect(
        labelOf(tester, _door('A0-01')),
        'Escalier A, RdC, porte 01, personne, 2e passage',
      );
      semantics.dispose();
    },
  );

  group('buttons with the app fonts (#35)', () {
    setUpAll(loadAppFonts);

    final manage = find.byKey(const Key('grid.manage'));
    final details = find.byKey(const Key('grid.details'));

    testWidgets('should put « Gérer l\'immeuble » and « Repasser » side by '
        'side when the text is at its normal size', (tester) async {
      usePhoneScreen(tester);
      await openStreet(tester);

      await tester.tap(_tile('8'));
      await tester.pumpAndSettle();

      final manageBox = tester.getRect(manage);
      final detailsBox = tester.getRect(details);
      expect(find.byKey(const Key('grid.actions.row')), findsOneWidget);
      expect(detailsBox.top, manageBox.top);
      expect(detailsBox.left, greaterThan(manageBox.right));
      expect(detailsBox.width, moreOrLessEquals(manageBox.width));
    });

    testWidgets('should stack the two buttons full width when the text is '
        'twice as large', (tester) async {
      await openStreet(tester);
      useLargeText(tester);
      await tester.pumpAndSettle();

      await tester.tap(_tile('8'));
      await tester.pumpAndSettle();

      final manageBox = tester.getRect(manage);
      final detailsBox = tester.getRect(details);
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(find.byKey(const Key('grid.actions.column')), findsOneWidget);
      expect(detailsBox.top, greaterThan(manageBox.bottom));
      expect(manageBox.left, AppSizes.gutter);
      expect(
        manageBox.width,
        moreOrLessEquals(screenWidth - 2 * AppSizes.gutter),
      );
      expect(detailsBox.width, manageBox.width);
      // « Gérer l'immeuble » on one line: as tall as « Repasser », which
      // full width cannot wrap.
      Finder label(Finder button) =>
          find.descendant(of: button, matching: find.byType(Text));
      expect(
        tester.getSize(label(manage)).height,
        tester.getSize(label(details)).height,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('at 200 % text', () {
    setUpAll(loadAppFonts);

    testWidgets('should show the grid and a door picker with no overflow when '
        'the text is twice as large', (tester) async {
      await openStreet(tester);
      useLargeText(tester);
      await tester.pumpAndSettle();

      await tester.tap(_tile('8'));
      await tester.pumpAndSettle();
      expect(_count, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(_door('A0-01'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('door.number')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await openStreet(tester);
    await tester.tap(_tile('8'));
    await tester.pumpAndSettle();

    await expectAccessibleControls(tester);
  });
}
