import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/building_icon.dart';
import 'package:tournee_calendriers/ui/components/open_chevron.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/components/status_tile.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
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
      isBuilding: false,
      glyph: StatusGlyphs.toDo,
      count: null,
      label: 'Numéro 1, à faire',
      background: colors.toDo,
    ),
    (
      name: 'done',
      number: '3',
      status: const DoneTile(),
      isBuilding: false,
      glyph: StatusGlyphs.done,
      count: null,
      label: 'Numéro 3, fait',
      background: colors.done,
    ),
    (
      name: 'nobody home',
      number: '3bis',
      status: const NobodyHomeTile(),
      isBuilding: false,
      glyph: StatusGlyphs.nobodyHome,
      count: null,
      label: 'Numéro 3bis, personne',
      background: colors.nobodyHome,
    ),
    (
      name: 'come back',
      number: '5',
      status: const ComeBackTile(),
      isBuilding: false,
      glyph: StatusGlyphs.comeBack,
      count: null,
      label: 'Numéro 5, repasser',
      background: colors.comeBack,
    ),
    (
      name: 'building partial',
      number: '8',
      status: const BuildingPartialTile(done: 7, total: 12),
      isBuilding: true,
      glyph: StatusGlyphs.buildingPartial,
      count: '7/12',
      label: 'Numéro 8, immeuble, 7 sur 12 faits, ouvrir',
      background: colors.buildingPartial,
    ),
    // A building whose doors are all to do, all done, or with its own
    // « repasser » takes the look of a house, but stays a building.
    (
      name: 'building to do',
      number: '10',
      status: const ToDoTile(),
      isBuilding: true,
      glyph: StatusGlyphs.toDo,
      count: null,
      label: 'Numéro 10, immeuble, à faire, ouvrir',
      background: colors.toDo,
    ),
    (
      name: 'building done',
      number: '12',
      status: const DoneTile(),
      isBuilding: true,
      glyph: StatusGlyphs.done,
      count: null,
      label: 'Numéro 12, immeuble, fait, ouvrir',
      background: colors.done,
    ),
    (
      name: 'building come back',
      number: '14',
      status: const ComeBackTile(),
      isBuilding: true,
      glyph: StatusGlyphs.comeBack,
      count: null,
      label: 'Numéro 14, immeuble, repasser, ouvrir',
      background: colors.comeBack,
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
                  isBuilding: c.isBuilding,
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
        final foreground = StatusLook.of(c.status, colors).foreground;
        final icon = find.byType(BuildingIcon);
        final chevron = find.byType(OpenChevron);
        if (c.isBuilding) {
          // ▦ before the number, › after everything else, in the text's
          // colour.
          expect(icon, findsOneWidget);
          expect(tester.widget<BuildingIcon>(icon).color, foreground);
          expect(
            tester.getRect(icon).right,
            lessThanOrEqualTo(tester.getRect(find.text(c.number)).left),
          );
          expect(chevron, findsOneWidget);
          expect(tester.widget<OpenChevron>(chevron).color, foreground);
          final trailing = c.count == null
              ? tester.getRect(glyph)
              : tester.getRect(find.text(c.count!));
          expect(
            tester.getRect(chevron).left,
            greaterThanOrEqualTo(trailing.right),
          );
          expect(
            tester.getRect(chevron).right,
            lessThanOrEqualTo(
              tester.getRect(find.byKey(const Key('tile'))).right,
            ),
          );
        } else {
          expect(icon, findsNothing);
          expect(chevron, findsNothing);
        }
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

  group('on a narrow phone', () {
    // The test font draws every character as a wide square: load the app's
    // real fonts so the widths measured are those of the phone.
    setUpAll(() async {
      final fonts = {
        AppFonts.text: [
          'assets/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.ttf',
        ],
        AppFonts.display: [
          'assets/fonts/barlow_condensed/BarlowCondensed-Bold.ttf',
        ],
      };
      for (final MapEntry(key: family, value: files) in fonts.entries) {
        final loader = FontLoader(family);
        for (final file in files) {
          loader.addFont(rootBundle.load(file));
        }
        await loader.load();
      }
    });

    // Half of a 360 dp wide street screen: the side margins and the gap
    // between the columns taken away.
    const halfColumn = (360 - 2 * AppSizes.gutter - AppSizes.columnGap) / 2;

    Future<void> pumpTile(
      WidgetTester tester, {
      required String number,
      required TileStatus status,
      required double textScale,
    }) => tester.pumpWidget(
      testApp(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Center(
            child: SizedBox(
              width: halfColumn,
              child: StatusTile(
                key: const Key('tile'),
                number: number,
                status: status,
                isBuilding: true,
              ),
            ),
          ),
        ),
      ),
    );

    for (final number in ['12bis', '1254']) {
      testWidgets(
        'should fit « $number » and « ◐ 12/120 » without overflow, keeping '
        'some of the number, when the text is 1.3× larger',
        (tester) async {
          await pumpTile(
            tester,
            number: number,
            status: const BuildingPartialTile(done: 12, total: 120),
            textScale: 1.3,
          );

          // An overflowing `Row` reports an error the test would rethrow.
          expect(tester.takeException(), isNull);
          final tile = tester.getRect(find.byKey(const Key('tile')));
          final count = tester.getRect(find.text('12/120'));
          final chevron = tester.getRect(find.byType(OpenChevron));
          expect(count.right, lessThanOrEqualTo(chevron.left));
          expect(chevron.right, lessThanOrEqualTo(tile.right));
          // The count shrinks before the number disappears.
          expect(
            tester.getRect(find.text(number)).width,
            greaterThanOrEqualTo(AppSizes.tileNumberMinWidth),
          );
          expect(
            tester.widget<Text>(find.text(number)).overflow,
            TextOverflow.ellipsis,
          );
        },
      );
    }

    testWidgets(
      'should keep the count at its full size when the number leaves room '
      'for it',
      (tester) async {
        await pumpTile(
          tester,
          number: '8',
          status: const BuildingPartialTile(done: 7, total: 12),
          textScale: 1,
        );

        expect(tester.takeException(), isNull);
        // `getRect` includes any scaling; `getSize` is the laid-out size.
        expect(
          tester.getRect(find.text('7/12')).width,
          moreOrLessEquals(tester.getSize(find.text('7/12')).width),
        );
        expect(
          tester.getRect(find.text('8')).right,
          lessThan(tester.getRect(find.byType(StatusGlyph)).left),
        );
      },
    );
  });
}
