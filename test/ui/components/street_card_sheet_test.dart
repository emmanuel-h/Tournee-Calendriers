import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/ui/components/street_card_sheet.dart';

import '../../support/street_fixtures.dart' show part, range;
import '../support/test_app.dart';

final _close = find.byKey(const Key('streetCard.close'));

void main() {
  late int closed;

  setUp(() {
    closed = 0;
  });

  Future<void> pumpCard(WidgetTester tester, StreetCardInSector card) {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      testApp(
        Align(
          alignment: Alignment.bottomCenter,
          child: StreetCardSheet(card: card, onClose: () => closed++),
        ),
      ),
    );
  }

  /// A street whose name fills more than a line.
  final longName = StreetCardInSector(
    id: StreetId('longue'),
    name: 'Avenue du Maréchal de Lattre de Tassigny prolongée',
    commune: 'Villefranche-sur-Saône',
    done: 3,
    total: 12,
  );

  testWidgets('should show a street of the secteur with its progress and '
      '« Ouvrir » only (PLAN §5.14)', (tester) async {
    await pumpCard(tester, longName);

    expect(find.text('3/12 faits'), findsOneWidget);
    expect(find.bySemanticsLabel('3 sur 12 faits'), findsOneWidget);
    expect(find.byKey(const Key('streetCard.chip.1')), findsNothing);
    expect(find.byKey(const Key('streetCard.open')), findsOneWidget);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('should close the card when its ✕ is tapped', (tester) async {
    await pumpCard(tester, longName);

    await tester.tap(_close);

    expect(closed, 1);
  });

  testWidgets('should keep a long street name clear of the ✕', (tester) async {
    await pumpCard(tester, longName);

    expect(
      tester.getTopRight(find.byKey(const Key('streetCard.name'))).dx,
      lessThanOrEqualTo(tester.getTopLeft(_close).dx),
    );
    expect(tester.getSize(_close), const Size(48, 48));
  });

  group('on « Ajouter des rues » (PLAN §5.19)', () {
    late int edited;
    late int deleted;

    Future<void> pumpToChange(WidgetTester tester, StreetCardInSector card) {
      edited = 0;
      deleted = 0;
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        testApp(
          Align(
            alignment: Alignment.bottomCenter,
            child: StreetCardSheet.toChange(
              card: card,
              onClose: () => closed++,
              onEdit: () => edited++,
              onDelete: () => deleted++,
            ),
          ),
        ),
      );
    }

    final pasteur = StreetCardInSector(
      id: StreetId('pasteur'),
      name: 'Rue Pasteur',
      commune: 'Villefranche-sur-Saône',
      done: 18,
      total: 18,
    );

    testWidgets('should say it is in the secteur, with its progress and its '
        'part, and offer to change or delete it', (tester) async {
      await pumpToChange(tester, pasteur);

      expect(find.text('Rue Pasteur'), findsOneWidget);
      expect(find.text('Villefranche-sur-Saône'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('streetCard.chip.0')),
                matching: find.byType(Text),
              ),
            )
            .data,
        'Dans le secteur',
      );
      expect(find.text('18/18 faits'), findsOneWidget);
      expect(find.bySemanticsLabel('18 sur 18 faits'), findsOneWidget);
      expect(find.text('Toute la rue'), findsOneWidget);
      expect(find.byKey(const Key('streetCard.chip.3')), findsNothing);
      expect(find.text('Modifier la rue'), findsOneWidget);
      expect(find.text('Supprimer la rue'), findsOneWidget);
      expect(find.byKey(const Key('streetCard.open')), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('streetCard.edit'))).height,
        52,
      );
      expect(
        tester.getSize(find.byKey(const Key('streetCard.delete'))).height,
        52,
      );
    });

    testWidgets('should name the part of a street held in part', (
      tester,
    ) async {
      await pumpToChange(
        tester,
        StreetCardInSector(
          id: StreetId('pasteur'),
          name: 'Rue Pasteur',
          commune: 'Villefranche-sur-Saône',
          done: 0,
          total: 15,
          part: part(odd: range(1, 57), even: range(2, 30)),
        ),
      );

      expect(find.text('Impairs 1–57 · pairs 2–30'), findsOneWidget);
      expect(find.text('Toute la rue'), findsNothing);
    });

    testWidgets('should send each button to its own action', (tester) async {
      await pumpToChange(tester, pasteur);

      await tester.tap(find.byKey(const Key('streetCard.edit')));
      expect((edited, deleted, closed), (1, 0, 0));

      await tester.tap(find.byKey(const Key('streetCard.delete')));
      expect((edited, deleted, closed), (1, 1, 0));

      await tester.tap(_close);
      expect((edited, deleted, closed), (1, 1, 1));
    });
  });
}
