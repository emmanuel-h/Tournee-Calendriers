import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
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
      glyph: StatusGlyphs.toDo,
      count: null,
      label: 'Numéro 1, à faire',
      background: colors.toDo,
    ),
    (
      name: 'done',
      number: '3',
      status: const DoneTile(),
      glyph: StatusGlyphs.done,
      count: null,
      label: 'Numéro 3, fait',
      background: colors.done,
    ),
    (
      name: 'nobody home',
      number: '3bis',
      status: const NobodyHomeTile(),
      glyph: StatusGlyphs.nobodyHome,
      count: null,
      label: 'Numéro 3bis, personne',
      background: colors.nobodyHome,
    ),
    (
      name: 'come back',
      number: '5',
      status: const ComeBackTile(),
      glyph: StatusGlyphs.comeBack,
      count: null,
      label: 'Numéro 5, repasser',
      background: colors.comeBack,
    ),
    (
      name: 'building partial',
      number: '8',
      status: const BuildingPartialTile(done: 7, total: 12),
      glyph: StatusGlyphs.buildingPartial,
      count: '7/12',
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

        // The glyph is drawn, not written: find the icon by what it draws.
        final glyph = find.byType(StatusGlyph);
        expect(glyph, findsOneWidget);
        expect(tester.widget<StatusGlyph>(glyph).glyph, c.glyph);
        expect(
          tester.widget<StatusGlyph>(glyph).color,
          StatusLook.of(c.status, colors).foreground,
        );
        if (c.count case final count?) {
          expect(find.text(count), findsOneWidget);
          // The count sits right of the icon, centred on the same line.
          expect(
            tester.getCenter(find.text(count)).dx,
            greaterThan(tester.getCenter(glyph).dx),
          );
          expect(
            tester.getCenter(find.text(count)).dy,
            moreOrLessEquals(tester.getCenter(glyph).dy, epsilon: 1),
          );
        } else {
          // Only the number is text on a house tile.
          expect(find.byType(Text), findsOneWidget);
        }
        expect(find.text(c.number), findsOneWidget);
        expect(find.byKey(const Key('tile.note')), findsNothing);
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

  testWidgets('should show a dot and say so when the house has a note', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        Center(
          child: SizedBox(
            width: 170,
            child: StatusTile(
              key: const Key('tile'),
              number: '7',
              status: const DoneTile(),
              hasNote: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final dot = find.byKey(const Key('tile.note'));
    expect(dot, findsOneWidget);
    // In the top right corner, clear of the glyph.
    final tile = tester.getRect(find.byKey(const Key('tile')));
    final dotRect = tester.getRect(dot);
    expect(dotRect.top - tile.top, 8);
    expect(tile.right - dotRect.right, 8);
    expect(dotRect.size, const Size.square(8));
    expect(
      dotRect.bottom,
      lessThan(tester.getRect(find.byType(StatusGlyph)).top),
    );
    final decoration =
        tester
                .widget<Container>(
                  find.descendant(of: dot, matching: find.byType(Container)),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.color, AppColors.light.onDone);
    expect(
      tester.getSemantics(find.byKey(const Key('tile'))),
      matchesSemantics(
        label: 'Numéro 7, fait, avec une note',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

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
