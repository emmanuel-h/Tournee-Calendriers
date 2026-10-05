import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/keyboard.dart';
import '../support/navigation.dart';

final _id = StreetId('lilas');

/// 1 and 3bis to do, 3 done; 2 to do.
final _lilas = valueOf(
  Street.create(
    id: _id,
    name: 'Rue des Lilas',
    commune: villefranche,
    houses: [
      House(number: n('1')),
      House(number: n('3'), status: VisitStatus.done),
      House(number: n('3bis')),
      House(number: n('2')),
    ],
  ),
);

Finder _tile(String number) => find.byKey(ValueKey('edit.tile.$number'));

Finder _remove(String number) => find.descendant(
  of: _tile(number),
  matching: find.byKey(const Key('edit.tile.remove')),
);

void main() {
  late FakeStreetRepository streets;

  /// Starts the app with the Rue des Lilas on the phone, opens its street
  /// screen, then its edit mode with ✏, on a tall phone so every row of
  /// the test street is built.
  Future<void> openEditMode(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393 * 3, 1100 * 3)
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
    unawaitedPush(router, AppRoutes.streetOf(_id));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('street.edit')));
    await tester.pumpAndSettle();
  }

  List<String> storedNumbers() => [
    for (final house in streets[_id]!.houses) house.number.label,
  ];

  testWidgets('should remove a number at once and bring it back when Annuler '
      'is tapped', (tester) async {
    await openEditMode(tester);

    await tester.tap(_remove('3bis'));
    await tester.pumpAndSettle();

    expect(_tile('3bis'), findsNothing);
    expect(find.text('N° 3bis supprimé'), findsOneWidget);
    expect(storedNumbers(), ['1', '2', '3']);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(_tile('3bis'), findsOneWidget);
    expect(storedNumbers(), ['1', '2', '3', '3bis']);
  });

  testWidgets('should ask first when the number removed has a mark', (
    tester,
  ) async {
    await openEditMode(tester);

    await tester.tap(_remove('3'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer le n° 3\u00a0?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit.confirmRemove.cancel')));
    await tester.pumpAndSettle();
    expect(_tile('3'), findsOneWidget);
    expect(find.text('N° 3 supprimé'), findsNothing);
    expect(streets.saved, isEmpty);

    await tester.tap(_remove('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit.confirmRemove.ok')));
    await tester.pumpAndSettle();

    expect(_tile('3'), findsNothing);
    expect(find.text('N° 3 supprimé'), findsOneWidget);
    expect(streets[_id]!.removedHouses.single.house.status, VisitStatus.done);
  });

  testWidgets('should put each added number on its side when 21-25 is added', (
    tester,
  ) async {
    await openEditMode(tester);

    await tester.tap(find.byKey(const ValueKey('edit.addNumbers.even')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('numbers.field')), '21-25');
    await tester.pump();

    expect(find.text('APERÇU · 5 NUMÉROS'), findsOneWidget);
    expect(find.text('21, 22, 23, 24, 25'), findsOneWidget);

    await tester.tap(find.byKey(const Key('numbers.add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('numbers.field')), findsNothing);
    final oddSide = tester.getCenter(_tile('1')).dx;
    final evenSide = tester.getCenter(_tile('2')).dx;
    expect(oddSide, lessThan(evenSide));
    for (final odd in ['21', '23', '25']) {
      expect(tester.getCenter(_tile(odd)).dx, oddSide, reason: odd);
    }
    for (final even in ['22', '24']) {
      expect(tester.getCenter(_tile(even)).dx, evenSide, reason: even);
    }
  });

  testWidgets('should keep a blank name out and rename the street when OK is '
      'tapped', (tester) async {
    await openEditMode(tester);

    await tester.enterText(find.byKey(const Key('edit.name')), '  ');
    await tester.tap(find.byKey(const Key('edit.ok')));
    await tester.pumpAndSettle();

    expect(
      find.text('Le nom de la rue ne peut pas être vide.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('edit.tiles')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('edit.name')), 'Rue des Iris');
    await tester.tap(find.byKey(const Key('edit.ok')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Rue des Iris'), findsOneWidget);
    expect(streets[_id]!.name, 'Rue des Iris');
  });

  testWidgets('should keep the focus on a refused name submitted with the '
      'keyboard, and let it go once a name is kept', (tester) async {
    await openEditMode(tester);
    final field = find.byKey(const Key('edit.name'));

    await typeAndSubmit(tester, field, '  ');

    expect(find.byKey(const Key('edit.nameRefusal')), findsOneWidget);
    expect(hasFocus(tester, field), isTrue);

    await typeAndSubmit(tester, field, 'Rue des Iris');

    expect(find.byKey(const Key('edit.nameRefusal')), findsNothing);
    expect(hasFocus(tester, field), isFalse);
    expect(streets[_id]!.name, 'Rue des Iris');
  });

  testWidgets('should keep the focus on a refused number submitted with the '
      'keyboard', (tester) async {
    await openEditMode(tester);
    await tester.tap(
      find.descendant(
        of: _tile('1'),
        matching: find.byKey(const Key('edit.tile.number')),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('number.field'));

    await typeAndSubmit(tester, field, '3');

    expect(find.byKey(const Key('number.refusal')), findsOneWidget);
    expect(hasFocus(tester, field), isTrue);
    expect(storedNumbers(), ['1', '2', '3', '3bis']);
  });

  testWidgets('should keep the focus on refused numbers submitted with the '
      'keyboard', (tester) async {
    await openEditMode(tester);
    await tester.tap(find.byKey(const ValueKey('edit.addNumbers.even')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('numbers.field'));

    await typeAndSubmit(tester, field, 'abc');

    expect(find.byKey(const Key('numbers.refusal')), findsOneWidget);
    expect(hasFocus(tester, field), isTrue);
    expect(storedNumbers(), ['1', '2', '3', '3bis']);
  });

  /// The app goes to the background, as before Android may kill it, one
  /// state at a time as on a phone (a lifecycle listener refuses a jump);
  /// it comes back to the foreground after the test.
  void hideApp(WidgetTester tester) {
    void moveThrough(List<AppLifecycleState> states) {
      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    addTearDown(
      () =>
          moveThrough([AppLifecycleState.inactive, AppLifecycleState.resumed]),
    );
    moveThrough([AppLifecycleState.inactive, AppLifecycleState.hidden]);
  }

  testWidgets('should rename the street when the app is hidden with a new '
      'name typed', (tester) async {
    await openEditMode(tester);

    await tester.enterText(find.byKey(const Key('edit.name')), 'Rue des Iris');
    hideApp(tester);
    await tester.pumpAndSettle();

    expect(streets[_id]!.name, 'Rue des Iris');
    expect(find.byKey(const Key('edit.tiles')), findsOneWidget);
  });

  testWidgets('should keep a blank name in the field and store nothing when '
      'the app is hidden', (tester) async {
    await openEditMode(tester);

    await tester.enterText(find.byKey(const Key('edit.name')), '  ');
    hideApp(tester);
    await tester.pumpAndSettle();

    expect(streets[_id]!.name, 'Rue des Lilas');
    expect(
      find.text('Le nom de la rue ne peut pas être vide.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('edit.name')))
          .controller!
          .text,
      '  ',
    );
  });

  testWidgets('should go back to Mes rues without the street when it is '
      'deleted', (tester) async {
    await openEditMode(tester);

    await tester.tap(find.byKey(const Key('edit.deleteStreet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit.confirmDelete.ok')));
    await tester.pumpAndSettle();

    expect(find.text("Aucune rue pour l'instant"), findsOneWidget);
    expect(streets[_id]!.isDeleted, isTrue);
  });
}
