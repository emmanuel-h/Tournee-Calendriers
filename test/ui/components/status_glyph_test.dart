import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

import '../support/test_app.dart';

void main() {
  const red = Color(0xFFFF0000);

  group('StatusGlyph widget', () {
    for (final glyph in StatusGlyphs.values) {
      testWidgets(
        'should occupy a square of the requested size when the glyph is '
        '${glyph.name}',
        (tester) async {
          await tester.pumpWidget(
            testApp(
              Center(
                child: StatusGlyph(
                  glyph,
                  size: 22,
                  color: red,
                  key: const Key('glyph'),
                ),
              ),
            ),
          );

          expect(
            tester.getSize(find.byKey(const Key('glyph'))),
            const Size(22, 22),
          );
          final paint = tester.widget<CustomPaint>(
            find.descendant(
              of: find.byKey(const Key('glyph')),
              matching: find.byType(CustomPaint),
            ),
          );
          final painter = paint.painter! as StatusGlyphPainter;
          expect(painter.glyph, glyph);
          expect(painter.color, red);
        },
      );
    }

    testWidgets(
      'should take the colour of the surrounding text when none is given',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const DefaultTextStyle(
              style: TextStyle(color: Color(0xFF123456)),
              child: Center(child: StatusGlyph(StatusGlyphs.done, size: 17)),
            ),
          ),
        );

        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(StatusGlyph),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(
          (paint.painter! as StatusGlyphPainter).color,
          const Color(0xFF123456),
        );
        expect(tester.getSize(find.byType(StatusGlyph)), const Size(17, 17));
      },
    );

    testWidgets(
      'should grow with the text when the phone uses a larger text size',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Center(child: StatusGlyph(StatusGlyphs.toDo, size: 22)),
            ),
          ),
        );

        expect(tester.getSize(find.byType(StatusGlyph)), const Size(33, 33));
      },
    );
  });

  group('glyph geometry', () {
    const size = 22.0;

    // What the painter draws, as one rectangle: the shapes plus half a
    // stroke on every side, since a stroke is centred on its path.
    Rect inkBounds(StatusGlyphs glyph) {
      final shape = StatusGlyphShape.of(glyph, size);
      var bounds = _tightBounds(shape.stroke).inflate(shape.strokeWidth / 2);
      if (shape.fill case final fill?) {
        bounds = bounds.expandToInclude(fill.getBounds());
      }
      return bounds;
    }

    for (final glyph in StatusGlyphs.values) {
      test('should stay inside its box when the glyph is ${glyph.name}', () {
        final bounds = inkBounds(glyph);

        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size));
        expect(bounds.bottom, lessThanOrEqualTo(size));
      });

      test('should fill at least 60 % of its box in both directions when '
          'the glyph is ${glyph.name}', () {
        final bounds = inkBounds(glyph);

        expect(bounds.width, greaterThanOrEqualTo(size * 0.6));
        expect(bounds.height, greaterThanOrEqualTo(size * 0.6));
      });
    }

    test('should draw every glyph with the same stroke weight', () {
      final widths = {
        for (final glyph in StatusGlyphs.values)
          StatusGlyphShape.of(glyph, size).strokeWidth,
      };

      expect(widths, {size * StatusGlyphShape.strokeRatio});
    });

    test('should scale the shape and stroke with the size', () {
      final small = StatusGlyphShape.of(StatusGlyphs.toDo, 12);
      final large = StatusGlyphShape.of(StatusGlyphs.toDo, 24);

      expect(large.strokeWidth, small.strokeWidth * 2);
      expect(
        large.stroke.getBounds().width,
        closeTo(small.stroke.getBounds().width * 2, 1e-9),
      );
    });

    test('should fill only the half disc and the arrowhead', () {
      expect(StatusGlyphShape.of(StatusGlyphs.toDo, size).fill, isNull);
      expect(StatusGlyphShape.of(StatusGlyphs.done, size).fill, isNull);
      expect(StatusGlyphShape.of(StatusGlyphs.nobodyHome, size).fill, isNull);
      expect(StatusGlyphShape.of(StatusGlyphs.comeBack, size).fill, isNotNull);

      // ◐: the filled half is the left one.
      final half = StatusGlyphShape.of(
        StatusGlyphs.buildingPartial,
        size,
      ).fill!.getBounds();
      expect(half.right, closeTo(size / 2, 0.01));
      expect(half.left, lessThan(size / 2));
    });

    test('should give each glyph a distinct shape', () {
      final outlines = {
        for (final glyph in StatusGlyphs.values)
          StatusGlyphShape.of(glyph, size).stroke.getBounds(),
      };
      // ○ and ◐ share their outline circle; the fill tells them apart.
      expect(outlines.length, StatusGlyphs.values.length - 1);
    });
  });

  group('StatusGlyphPainter', () {
    const painter = StatusGlyphPainter(StatusGlyphs.done, red);

    test('should repaint when the glyph changes', () {
      expect(
        const StatusGlyphPainter(StatusGlyphs.toDo, red).shouldRepaint(painter),
        isTrue,
      );
    });

    test('should repaint when the colour changes', () {
      expect(
        const StatusGlyphPainter(
          StatusGlyphs.done,
          Color(0xFF000000),
        ).shouldRepaint(painter),
        isTrue,
      );
    });

    test('should not repaint when nothing changes', () {
      expect(
        const StatusGlyphPainter(StatusGlyphs.done, red).shouldRepaint(painter),
        isFalse,
      );
    });

    test('should paint the outline and the fill with the glyph colour', () {
      final canvas = _RecordingCanvas();

      const StatusGlyphPainter(
        StatusGlyphs.buildingPartial,
        red,
      ).paint(canvas, const Size(22, 22));

      expect(canvas.paints.map((p) => p.style), [
        PaintingStyle.stroke,
        PaintingStyle.fill,
      ]);
      expect(canvas.paints.map((p) => p.color), [red, red]);
      // A Paint stores its width in single precision.
      expect(
        canvas.paints.first.strokeWidth,
        closeTo(22 * StatusGlyphShape.strokeRatio, 1e-6),
      );
      expect(canvas.paints.first.strokeCap, StrokeCap.round);
    });

    test('should paint only the outline when the glyph has no fill', () {
      final canvas = _RecordingCanvas();

      const StatusGlyphPainter(
        StatusGlyphs.nobodyHome,
        red,
      ).paint(canvas, const Size(22, 22));

      expect(canvas.paints.map((p) => p.style), [PaintingStyle.stroke]);
    });
  });
}

/// The smallest rectangle around the points of [path]. `Path.getBounds` may
/// be larger: it includes the control points of curves, which lie outside
/// an arc.
Rect _tightBounds(Path path) {
  Rect? bounds;
  for (final metric in path.computeMetrics()) {
    for (var at = 0.0; at <= metric.length; at += 0.05) {
      final point = metric.getTangentForOffset(at)!.position;
      final dot = Rect.fromLTWH(point.dx, point.dy, 0, 0);
      bounds = bounds?.expandToInclude(dot) ?? dot;
    }
  }
  return bounds!;
}

/// A canvas that only records the paints given to `drawPath`: the glyph
/// painter must draw paths and nothing else. `noSuchMethod` makes any other
/// call (text, images…) fail the test.
final class _RecordingCanvas implements Canvas {
  final paints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => paints.add(paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected canvas call: ${invocation.memberName}',
  );
}
