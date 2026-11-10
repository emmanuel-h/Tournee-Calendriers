import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/ui/components/street_card_sheet.dart';

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
}
