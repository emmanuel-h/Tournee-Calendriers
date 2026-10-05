import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/arrow_text.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';

import '../support/test_app.dart';

void main() {
  const ink = Color(0xFF123456);
  const red = Color(0xFFFF0000);

  group('ArrowText', () {
    Future<void> pumpMessage(WidgetTester tester, String text) =>
        tester.pumpWidget(
          testApp(
            Center(
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 20, color: ink),
                child: ArrowText(text),
              ),
            ),
          ),
        );

    testWidgets(
      'should draw each arrow and keep the sentence as its label when the '
      'text has arrows',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpMessage(tester, 'N° 3 → 3bis → 3ter');

        final arrows = tester.widgetList<ArrowGlyph>(find.byType(ArrowGlyph));
        expect(arrows.map((a) => a.size), [20, 20]);
        expect(arrows.map((a) => a.color), [ink, ink]);
        final text = tester.widget<Text>(find.byType(Text));
        expect(text.textSpan!.toPlainText(), 'N° 3 ￼ 3bis ￼ 3ter');
        expect(find.bySemanticsLabel('N° 3 → 3bis → 3ter'), findsOneWidget);
        semantics.dispose();
      },
    );

    testWidgets('should show the text alone when it has no arrow', (
      tester,
    ) async {
      await pumpMessage(tester, 'Rue supprimée');

      expect(find.byType(ArrowGlyph), findsNothing);
      expect(find.text('Rue supprimée'), findsOneWidget);
    });

    testWidgets('should size the arrow like the given style', (tester) async {
      await tester.pumpWidget(
        testApp(const ArrowText('7 → Fait', style: TextStyle(fontSize: 13))),
      );

      expect(tester.widget<ArrowGlyph>(find.byType(ArrowGlyph)).size, 13);
    });
  });

  group('ArrowGlyph', () {
    testWidgets('should occupy a square of the size, grown with the text', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Center(child: ArrowGlyph(size: 16, color: red)),
          ),
        ),
      );

      expect(tester.getSize(find.byType(ArrowGlyph)), const Size(24, 24));
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(ArrowGlyph),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((paint.painter! as ArrowPainter).color, red);
    });
  });

  group('arrowShape', () {
    const size = 24.0;
    final shape = arrowShape(size);

    test('should point right, on the middle of its box', () {
      final bounds = shape.getBounds();

      expect(bounds.center.dy, size / 2);
      expect(bounds.center.dx, size / 2);
      expect(bounds.width, greaterThan(bounds.height));
    });

    test('should stay inside its box, a stroke included', () {
      final bounds = shape.getBounds().inflate(
        size * StatusGlyphShape.strokeRatio / 2,
      );

      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(size));
      expect(bounds.bottom, lessThanOrEqualTo(size));
    });

    test('should scale with the size', () {
      expect(
        arrowShape(12).getBounds().width * 2,
        closeTo(arrowShape(24).getBounds().width, 1e-9),
      );
    });
  });

  group('ArrowPainter', () {
    test('should repaint only when the colour changes', () {
      const painter = ArrowPainter(red);

      expect(const ArrowPainter(ink).shouldRepaint(painter), isTrue);
      expect(const ArrowPainter(red).shouldRepaint(painter), isFalse);
    });

    test('should stroke the arrow with round ends in its colour', () {
      final canvas = _RecordingCanvas();

      const ArrowPainter(red).paint(canvas, const Size(16, 16));

      expect(canvas.paints, hasLength(1));
      final paint = canvas.paints.single;
      expect(paint.color, red);
      expect(paint.style, PaintingStyle.stroke);
      expect(paint.strokeCap, StrokeCap.round);
      expect(paint.strokeJoin, StrokeJoin.round);
      // A Paint stores its width in single precision.
      expect(
        paint.strokeWidth,
        closeTo(16 * StatusGlyphShape.strokeRatio, 1e-6),
      );
    });
  });
}

/// Records the paints given to `drawPath`; any other call fails the test.
final class _RecordingCanvas implements Canvas {
  final paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected canvas call: ${invocation.memberName}',
  );
}
