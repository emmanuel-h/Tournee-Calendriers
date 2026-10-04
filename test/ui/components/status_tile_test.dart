import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/status_tile.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

import '../support/test_app.dart';

void main() {
  const colors = AppColors.light;

  // One case per status: what the tile must show, say and be tinted with.
  final cases = [
    (
      name: 'to do',
      number: '1',
      status: const ToDoTile(),
      glyph: '○',
      label: 'Numéro 1, à faire',
      background: colors.toDo,
    ),
    (
      name: 'done',
      number: '3',
      status: const DoneTile(),
      glyph: '✓',
      label: 'Numéro 3, fait',
      background: colors.done,
    ),
    (
      name: 'nobody home',
      number: '3bis',
      status: const NobodyHomeTile(),
      glyph: '✗',
      label: 'Numéro 3bis, personne',
      background: colors.nobodyHome,
    ),
    (
      name: 'come back',
      number: '5',
      status: const ComeBackTile(),
      glyph: '↻',
      label: 'Numéro 5, à faire, repasser',
      background: colors.comeBack,
    ),
    (
      name: 'building partial',
      number: '8',
      status: const BuildingPartialTile(done: 7, total: 12),
      glyph: '◐ 7/12',
      label: 'Numéro 8, immeuble, 7 sur 12 faits',
      background: colors.buildingPartial,
    ),
  ];

  for (final c in cases) {
    testWidgets(
      'should show its glyph, French label and tint, at least 56 dp high, '
      'when the status is ${c.name}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          testApp(
            Center(
              child: SizedBox(
                width: 170,
                child: StatusTile(
                  key: const Key('tile'),
                  number: c.number,
                  status: c.status,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text(c.glyph), findsOneWidget);
        expect(find.text(c.number), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('tile'))),
          matchesSemantics(label: c.label, isButton: true, hasTapAction: true),
        );
        expect(
          tester.getSize(find.byKey(const Key('tile'))).height,
          greaterThanOrEqualTo(56),
        );
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byKey(const Key('tile')),
            matching: find.byType(Material),
          ),
        );
        expect(material.color, c.background);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'should report tap and hold separately when the tile is touched',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        testApp(
          StatusTile(
            number: '7',
            status: const ToDoTile(),
            onTap: () => calls.add('tap'),
            onLongPress: () => calls.add('hold'),
          ),
        ),
      );

      await tester.tap(find.byType(StatusTile));
      await tester.longPress(find.byType(StatusTile));

      expect(calls, ['tap', 'hold']);
    },
  );
}
