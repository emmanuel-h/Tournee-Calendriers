import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_state.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';
import 'package:tournee_calendriers/ui/screens/street_part/street_part_screen.dart';

import '../../support/geo_fixtures.dart';
import '../../support/street_fixtures.dart';
import '../support/fake_map_view.dart';
import '../support/test_app.dart';

// The Rue Nationale of Villefranche-sur-Saône, shorter than on the
// StreetPart mockup: 1, 3, 5, 7 north of a road running east, 2, 4, 6
// south; 9 typed by hand.

StreetPartChoice _choice({StreetShape? road, bool positions = true}) =>
    StreetPartChoice.start(
      numbers: [
        for (var k = 0; k < 4; k++)
          PartNumber(
            n('${2 * k + 1}'),
            position: positions ? at(45.98005, 4.72 + k * 1e-4) : null,
          ),
        for (var k = 0; k < 3; k++)
          PartNumber(
            n('${2 * k + 2}'),
            position: positions ? at(45.97995, 4.72 + k * 1e-4) : null,
          ),
        PartNumber(n('9')),
      ],
      road:
          road ??
          StreetShape([
            [at(45.98, 4.7195), at(45.98, 4.7210)],
          ]),
      part: StreetPart.whole,
    );

Finder _key(String key) => find.byKey(Key(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

void main() {
  /// What the screen gave back when it closed; null before it closed, or
  /// when it closed with nothing chosen.
  late StreetPart? chosen;
  late bool closed;

  /// Opens « Partie de la rue » on [choice] from a button, as the edit
  /// mode does.
  Future<void> open(WidgetTester tester, StreetPartChoice choice) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    closed = false;
    chosen = null;
    final request = StreetPartRequest(
      streetName: 'Rue Nationale',
      choice: choice,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streetPartMapViewProvider.overrideWithValue(FakePartMapView.new),
        ],
        child: testApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await showStreetPart(context, request);
                closed = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('should show the street, the part and how many numbers it '
      'keeps', (tester) async {
    await open(tester, _choice());

    expect(find.text('Partie de la rue'), findsOneWidget);
    expect(_text(tester, 'part.subtitle'), 'Rue Nationale · n° 1 à 9');
    expect(_text(tester, 'part.result'), 'Toute la rue');
    expect(_text(tester, 'part.count'), '8 numéros gardés sur 8');
    expect(find.text('Toute la rue'), findsNWidgets(2));
    expect(find.text('Rien'), findsOneWidget);
    expect(shownPartMap(tester).drawing.dots, hasLength(7));
  });

  testWidgets('should show the side chosen with its own quick buttons', (
    tester,
  ) async {
    await open(tester, _choice());

    await tester.tap(_key('part.sides.odd'));
    await tester.pumpAndSettle();
    expect(find.text('Tous les impairs'), findsOneWidget);
    expect(find.text('Aucun impair'), findsOneWidget);

    await tester.tap(_key('part.sides.even'));
    await tester.pumpAndSettle();
    expect(find.text('Tous les pairs'), findsOneWidget);
    expect(find.text('Aucun pair'), findsOneWidget);
  });

  testWidgets('should work the part out again when a mark moves', (
    tester,
  ) async {
    await open(tester, _choice());
    await tester.tap(_key('part.sides.odd'));
    await tester.pumpAndSettle();

    shownPartMap(tester).onMarkMoved(PartMark.first, 2);
    await tester.pumpAndSettle();

    expect(_text(tester, 'part.result'), 'Impairs 5–9 · tous les pairs');
    expect(_text(tester, 'part.count'), '6 numéros gardés sur 8');
  });

  testWidgets('should keep nothing of the side with its quick button, then '
      'all of it', (tester) async {
    await open(tester, _choice());
    await tester.tap(_key('part.sides.even'));
    await tester.pumpAndSettle();

    await tester.tap(_key('part.nothing'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'part.result'), 'Tous les impairs');
    expect(_text(tester, 'part.count'), '5 numéros gardés sur 8');

    await tester.tap(_key('part.all'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'part.result'), 'Toute la rue');
  });

  testWidgets('should give back the part chosen with « Valider »', (
    tester,
  ) async {
    await open(tester, _choice());
    await tester.tap(_key('part.nothing'));
    await tester.pumpAndSettle();

    await tester.tap(_key('part.validate'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(chosen, part(odd: SidePart.none, even: SidePart.none));
  });

  testWidgets('should give back nothing when left with ✕', (tester) async {
    await open(tester, _choice());
    await tester.tap(_key('part.nothing'));
    await tester.pumpAndSettle();

    await tester.tap(_key('part.close'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(chosen, isNull);
  });

  testWidgets('should give back nothing when left with back', (tester) async {
    await open(tester, _choice());

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(chosen, isNull);
  });

  group('a street without positions', () {
    testWidgets('should choose by number, without a map', (tester) async {
      await open(tester, _choice(positions: false));

      expect(find.byType(FakePartMapView), findsNothing);
      await tester.tap(_key('part.sides.odd'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: _key('part.from'),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.enterText(
        find.descendant(of: _key('part.to'), matching: find.byType(TextField)),
        '6',
      );
      await tester.pumpAndSettle();

      expect(_text(tester, 'part.result'), 'Impairs 3–5 · tous les pairs');
    });

    testWidgets('should fill the fields from the side chosen', (tester) async {
      await open(tester, _choice(positions: false));
      await tester.tap(_key('part.sides.odd'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: _key('part.from'),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.pumpAndSettle();

      await tester.tap(_key('part.sides.even'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsNothing);

      await tester.tap(_key('part.sides.odd'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('should empty the fields with a quick button', (tester) async {
      await open(tester, _choice(positions: false));
      await tester.tap(_key('part.sides.odd'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: _key('part.from'),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.pumpAndSettle();

      await tester.tap(_key('part.all'));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsNothing);
      expect(_text(tester, 'part.result'), 'Toute la rue');
    });

    testWidgets('should name only the street when it has no numbers', (
      tester,
    ) async {
      await open(
        tester,
        StreetPartChoice.start(
          numbers: const [],
          road: StreetShape.none,
          part: StreetPart.whole,
        ),
      );

      expect(_text(tester, 'part.subtitle'), 'Rue Nationale');
      expect(_text(tester, 'part.count'), 'Aucun numéro gardé sur 0');
    });
  });
}
