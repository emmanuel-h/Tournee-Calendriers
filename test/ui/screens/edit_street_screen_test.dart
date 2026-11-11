import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/ui/app.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import '../support/app_overrides.dart';
import '../support/keyboard.dart';
import '../support/large_text.dart';
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
  /// [street] replaces the Rue des Lilas as it is stored.
  Future<void> openEditMode(
    WidgetTester tester, {
    Street? street,
    FakeAddressDirectory? directory,
  }) async {
    tester.view
      ..physicalSize = const Size(393 * 3, 1100 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    streets = FakeStreetRepository([street ?? _lilas]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakePhone(streets: streets, directory: directory),
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
    expect(streets[_id]!.name.text, 'Rue des Iris');
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
    expect(streets[_id]!.name.text, 'Rue des Iris');
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

    expect(streets[_id]!.name.text, 'Rue des Iris');
    expect(find.byKey(const Key('edit.tiles')), findsOneWidget);
  });

  testWidgets('should keep a blank name in the field and store nothing when '
      'the app is hidden', (tester) async {
    await openEditMode(tester);

    await tester.enterText(find.byKey(const Key('edit.name')), '  ');
    hideApp(tester);
    await tester.pumpAndSettle();

    expect(streets[_id]!.name.text, 'Rue des Lilas');
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

  testWidgets('should go back to the start screen without the street when '
      'it is deleted', (tester) async {
    await openEditMode(tester);

    await tester.tap(find.byKey(const Key('edit.deleteStreet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit.confirmDelete.ok')));
    await tester.pumpAndSettle();

    // No secteur is open on this phone: the start screen says so.
    expect(find.byKey(const Key('noSector.panel')), findsOneWidget);
    expect(find.byKey(const Key('edit.name')), findsNothing);
    expect(streets[_id]!.isDeleted, isTrue);
  });

  testWidgets('should offer only « Supprimer la rue » at the bottom, never '
      '« Ne plus la faire » (PLAN §5.14)', (tester) async {
    await openEditMode(tester);

    expect(find.text('Ne plus la faire'), findsNothing);
    expect(find.text('Supprimer la rue'), findsOneWidget);
  });

  testWidgets('should label every control and make it 48 dp at least', (
    tester,
  ) async {
    await openEditMode(tester);

    await expectAccessibleControls(tester);
  });

  group('Partie de la rue', () {
    Future<void> openPart(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('edit.part')));
      await tester.pumpAndSettle();
    }

    String partText(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('edit.partText'))).data!;

    testWidgets('should say the part held under the name', (tester) async {
      await openEditMode(tester);

      expect(partText(tester), 'Toute la rue');
      expect(
        tester.getSemantics(find.byKey(const Key('edit.part'))).label,
        'Partie de la rue\u00a0: Toute la rue',
      );
    });

    testWidgets('should give the street the part chosen and send the numbers '
        'left out to the Corbeille', (tester) async {
      await openEditMode(tester);
      await openPart(tester);
      expect(find.text('Rue des Lilas · n° 1 à 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('part.sides.even')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.nothing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.validate')));
      await tester.pumpAndSettle();

      expect(partText(tester), 'Tous les impairs');
      expect(streets[_id]!.part, part(odd: SidePart.all, even: SidePart.none));
      expect(storedNumbers(), ['1', '3', '3bis']);
      expect(_tile('2'), findsNothing);
    });

    testWidgets('should change nothing when « Partie de la rue » is left '
        'with ✕', (tester) async {
      await openEditMode(tester);
      await openPart(tester);

      await tester.tap(find.byKey(const Key('part.nothing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.close')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier la rue'), findsOneWidget);
      expect(streets.saved, isEmpty);
      expect(partText(tester), 'Toute la rue');
    });

    testWidgets('should ask first when numbers with marks would leave', (
      tester,
    ) async {
      await openEditMode(tester);
      await openPart(tester);
      await tester.tap(find.byKey(const Key('part.sides.odd')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.nothing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.validate')));
      await tester.pumpAndSettle();

      // 3 is done.
      expect(
        find.text('1 numéro a des marques. Il part avec elles à la Corbeille.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('edit.confirmPart.cancel')));
      await tester.pumpAndSettle();
      expect(streets.saved, isEmpty);
      expect(partText(tester), 'Toute la rue');

      await openPart(tester);
      await tester.tap(find.byKey(const Key('part.sides.odd')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.nothing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('part.validate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit.confirmPart.ok')));
      await tester.pumpAndSettle();

      expect(partText(tester), 'Tous les pairs');
      expect(storedNumbers(), ['2']);
      expect(
        streets[_id]!.removedHouses
            .singleWhere((removed) => removed.number == n('3'))
            .house
            .status,
        VisitStatus.done,
      );
    });

    group('of a street from the BAN', () {
      final ban = BanStreetId('69264_0420');
      final fromBan = valueOf(
        Street.create(
          id: _id,
          name: 'Rue des Lilas',
          commune: villefranche,
          banId: ban,
          part: part(odd: SidePart.all, even: SidePart.none),
          houses: [House(number: n('1'))],
        ),
      );

      testWidgets('should say the numbers need the network', (tester) async {
        await openEditMode(
          tester,
          street: fromBan,
          directory: FakeAddressDirectory(
            streets: {ban: const Err(AddressDirectoryFailure.noNetwork)},
          ),
        );

        await openPart(tester);

        expect(find.text('Partie de la rue'), findsOneWidget);
        expect(
          find.text('Connexion nécessaire pour lire les numéros de la rue.'),
          findsOneWidget,
        );
      });

      testWidgets('should say the BAN did not answer', (tester) async {
        await openEditMode(
          tester,
          street: fromBan,
          directory: FakeAddressDirectory(
            streets: {ban: const Err(AddressDirectoryFailure.serviceError)},
          ),
        );

        await openPart(tester);

        expect(
          find.text(
            'Impossible de lire les numéros de la rue pour l\'instant. '
            'Réessayez plus tard.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('should wait for the numbers with a spinner, then add the '
          'ones the part brings in', (tester) async {
        final directory = FakeAddressDirectory(
          streets: {
            ban: Ok(
              StreetNumbers(
                id: ban,
                name: streetName('Rue des Lilas'),
                commune: villefranche,
                numbers: [
                  DirectoryNumber(number: n('1')),
                  DirectoryNumber(number: n('2')),
                ],
                invalidNumbers: 0,
                duplicateNumbers: 0,
              ),
            ),
          },
        )..holdStreet(ban);
        await openEditMode(tester, street: fromBan, directory: directory);

        await tester.tap(find.byKey(const Key('edit.part')));
        await tester.pump();
        expect(find.byKey(const Key('edit.partReading')), findsOneWidget);
        // A second tap while the numbers are read opens nothing more.
        await tester.tap(find.byKey(const Key('edit.part')));
        directory.releaseStreet(ban);
        await tester.pumpAndSettle();
        expect(directory.streetsAsked, [ban]);

        await tester.tap(find.byKey(const Key('part.all')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('part.validate')));
        await tester.pumpAndSettle();

        expect(partText(tester), 'Toute la rue');
        expect(storedNumbers(), ['1', '2']);
      });

      testWidgets('should say the numbers need the network when the part '
          'grows offline', (tester) async {
        final directory = FakeAddressDirectory(
          streets: {
            ban: Ok(
              StreetNumbers(
                id: ban,
                name: streetName('Rue des Lilas'),
                commune: villefranche,
                numbers: [DirectoryNumber(number: n('1'))],
                invalidNumbers: 0,
                duplicateNumbers: 0,
              ),
            ),
          },
        );
        await openEditMode(tester, street: fromBan, directory: directory);
        await openPart(tester);
        await tester.tap(find.byKey(const Key('part.all')));
        await tester.pumpAndSettle();
        // The network goes while the part is chosen.
        directory.streets[ban] = const Err(AddressDirectoryFailure.noNetwork);

        await tester.tap(find.byKey(const Key('part.validate')));
        await tester.pumpAndSettle();

        expect(
          find.text('Connexion nécessaire pour lire les numéros de la rue.'),
          findsOneWidget,
        );
        expect(partText(tester), 'Tous les impairs');
      });
    });
  });
}
