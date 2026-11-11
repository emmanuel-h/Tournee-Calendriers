import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/ui/map/part_marks.dart';

import '../../support/geo_fixtures.dart';
import '../../support/street_fixtures.dart';
import '../support/test_app.dart';

/// 1, 3, 5, 7 along a road of Villefranche-sur-Saône running east, the
/// odd side shown: places 0 to 4.
PartDrawing _drawing(StreetPart part) => StreetPartChoice.start(
  numbers: [
    for (var k = 0; k < 4; k++)
      PartNumber(n('${2 * k + 1}'), position: at(45.98005, 4.72 + k * 1e-4)),
  ],
  road: StreetShape([
    [at(45.98, 4.7195), at(45.98, 4.7210)],
  ]),
  part: part,
).withSide(Sides.odd).drawing!;

/// The places on screen: 60 dp apart along a line 300 dp down.
final _places = [for (var i = 0; i < 5; i++) Offset(60.0 + 60 * i, 300)];

void main() {
  group('nearestPlace', () {
    test('should pick the place nearest to the finger', () {
      expect(nearestPlace(_places, const Offset(170, 250)), 2);
      expect(nearestPlace(_places, const Offset(0, 300)), 0);
      expect(nearestPlace(_places, const Offset(900, 300)), 4);
    });

    test('should keep the first of two places as near', () {
      expect(nearestPlace(_places, const Offset(90, 300)), 0);
    });
  });

  group('markToMove', () {
    test('should move the mark grabbed when the marks stand apart', () {
      expect(
        markToMove(grabbed: PartMark.last, first: 1, last: 3, gap: 0),
        PartMark.last,
      );
      expect(
        markToMove(grabbed: PartMark.first, first: 1, last: 3, gap: 4),
        PartMark.first,
      );
    });

    test('should move the first mark towards the start when they stand '
        'together', () {
      expect(
        markToMove(grabbed: PartMark.last, first: 2, last: 2, gap: 1),
        PartMark.first,
      );
    });

    test('should move the last mark towards the end when they stand '
        'together', () {
      expect(
        markToMove(grabbed: PartMark.first, first: 2, last: 2, gap: 3),
        PartMark.last,
      );
    });
  });

  group('PartMarks', () {
    late List<(PartMark, int)> moves;

    Future<void> show(WidgetTester tester, StreetPart part) async {
      moves = [];
      await tester.pumpWidget(
        testApp(
          PartMarks(
            drawing: _drawing(part),
            places: _places,
            onMoved: (mark, gap) => moves.add((mark, gap)),
          ),
        ),
      );
    }

    Finder mark(PartMark mark) =>
        find.byKey(ValueKey('part.mark.${mark.name}'));

    testWidgets('should label each mark with its place', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, part(odd: range(3, 5), even: SidePart.all));

      expect(find.text('entre 1 et 3'), findsOneWidget);
      expect(find.text('entre 5 et 7'), findsOneWidget);
      expect(
        tester.getSemantics(mark(PartMark.first)).label,
        'Première marque, entre 1 et 3',
      );
      expect(
        tester.getSemantics(mark(PartMark.last)).label,
        'Dernière marque, entre 5 et 7',
      );
      semantics.dispose();
    });

    testWidgets('should snap a dragged mark to the nearest place', (
      tester,
    ) async {
      await show(tester, part(odd: range(3, 5), even: SidePart.all));
      // The handle of the first mark stands at place 1, (120, 300).
      final gesture = await tester.startGesture(const Offset(120, 300));

      await gesture.moveBy(const Offset(10, 0));
      await gesture.moveBy(const Offset(50, 0));
      await gesture.moveBy(const Offset(-110, -20));
      await gesture.up();

      expect(moves, [(PartMark.first, 2), (PartMark.first, 0)]);
    });

    testWidgets('should part two marks together, and keep moving the one '
        'that left', (tester) async {
      await show(tester, part(odd: SidePart.none, even: SidePart.all));
      // Both marks at place 0; then the last mark, drawn on top, is grabbed.
      final gesture = await tester.startGesture(const Offset(60, 300));

      await gesture.moveBy(const Offset(125, 0));
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.up();

      // The drag keeps moving the mark it started with.
      expect(moves, [(PartMark.last, 2), (PartMark.last, 1)]);
    });

    testWidgets('should move a mark one place with the screen reader\'s '
        'swipes', (tester) async {
      await show(tester, part(odd: range(3, 5), even: SidePart.all));

      final semantics = tester.ensureSemantics();
      void perform(PartMark which, SemanticsAction action) {
        final node = tester.getSemantics(mark(which));
        node.owner!.performAction(node.id, action);
      }

      perform(PartMark.first, SemanticsAction.increase);
      perform(PartMark.last, SemanticsAction.decrease);

      expect(moves, [(PartMark.first, 2), (PartMark.last, 2)]);
      semantics.dispose();
    });

    testWidgets('should not move a mark past the ends with the screen '
        'reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, StreetPart.whole);

      final first = tester
          .getSemantics(mark(PartMark.first))
          .getSemanticsData();
      final last = tester.getSemantics(mark(PartMark.last)).getSemanticsData();

      expect(first.hasAction(SemanticsAction.decrease), isFalse);
      expect(first.hasAction(SemanticsAction.increase), isTrue);
      expect(last.hasAction(SemanticsAction.increase), isFalse);
      expect(last.hasAction(SemanticsAction.decrease), isTrue);
      semantics.dispose();
    });

    testWidgets('should show no mark on a side without dots', (tester) async {
      moves = [];
      final drawing = StreetPartChoice.start(
        numbers: [
          PartNumber(n('1'), position: at(45.98005, 4.72)),
          PartNumber(n('2')),
        ],
        road: StreetShape([
          [at(45.98, 4.7195), at(45.98, 4.7210)],
        ]),
        part: StreetPart.whole,
      ).withSide(Sides.even).drawing!;
      await tester.pumpWidget(
        testApp(
          PartMarks(drawing: drawing, places: const [], onMoved: (_, _) {}),
        ),
      );

      expect(mark(PartMark.first), findsNothing);
      expect(mark(PartMark.last), findsNothing);
    });
  });
}
