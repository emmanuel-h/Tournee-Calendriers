import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// A status glyph (○ ✓ ✗ ↻ ◐) drawn as a vector shape in a square box.
///
/// Drawing the shapes instead of typing characters gives every glyph the
/// same size and stroke weight on every phone, whatever its fonts.
///
/// The glyph is decoration: it has no semantics of its own, so the widget
/// that shows it (a tile, a count, a segment) must carry the French label.
///
/// Next to text, put it in a `Row` (centred by default) or, inside a
/// sentence, in a `WidgetSpan` with `alignment: PlaceholderAlignment.middle`
/// so it sits on the middle of the line rather than on the baseline.
final class StatusGlyph extends StatelessWidget {
  const StatusGlyph(this.glyph, {super.key, required this.size, this.color});

  final StatusGlyphs glyph;

  /// Side of the square box at the default text size, in dp. The box grows
  /// with the phone's text size setting, like the text next to it.
  final double size;

  /// Defaults to the colour of the surrounding text, so a glyph placed next
  /// to a label matches it without being told.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.textScalerOf(context).scale(size);
    final ink =
        color ??
        DefaultTextStyle.of(context).style.color ??
        IconTheme.of(context).color!;
    return SizedBox.square(
      dimension: side,
      child: CustomPaint(painter: StatusGlyphPainter(glyph, ink)),
    );
  }
}

/// The paths of one glyph at one size: what [StatusGlyphPainter] draws,
/// kept apart from the canvas so tests can measure it.
@immutable
final class StatusGlyphShape {
  const StatusGlyphShape._({
    required this.stroke,
    required this.strokeWidth,
    this.fill,
  });

  /// Draws [glyph] in a square of side [size], starting at the origin.
  ///
  /// The shapes are designed on a 24 × 24 grid (the usual icon grid) and
  /// scaled: `u(4)` is 4 grid units at the requested size. They leave a
  /// small margin, like font glyphs do, so a glyph never touches its
  /// neighbour.
  factory StatusGlyphShape.of(StatusGlyphs glyph, double size) {
    final scale = size / _grid;
    double u(double units) => units * scale;
    Offset p(double x, double y) => Offset(u(x), u(y));
    final strokeWidth = size * strokeRatio;

    return switch (glyph) {
      StatusGlyphs.toDo => StatusGlyphShape._(
        stroke: Path()..addOval(_circle(p(12, 12), u(8.5))),
        strokeWidth: strokeWidth,
      ),
      StatusGlyphs.done => StatusGlyphShape._(
        stroke: Path()
          ..moveTo(u(4.5), u(12))
          ..lineTo(u(9.5), u(17.5))
          ..lineTo(u(19.5), u(5.5)),
        strokeWidth: strokeWidth,
      ),
      StatusGlyphs.nobodyHome => StatusGlyphShape._(
        stroke: Path()
          ..moveTo(u(5.75), u(5.75))
          ..lineTo(u(18.25), u(18.25))
          ..moveTo(u(18.25), u(5.75))
          ..lineTo(u(5.75), u(18.25)),
        strokeWidth: strokeWidth,
      ),
      StatusGlyphs.comeBack => _comeBack(p, u, strokeWidth),
      StatusGlyphs.buildingPartial => StatusGlyphShape._(
        stroke: Path()..addOval(_circle(p(12, 12), u(8.5))),
        strokeWidth: strokeWidth,
        // The left half disc: from the bottom, clockwise through the left,
        // to the top, then closed along the vertical diameter.
        fill: Path()
          ..arcTo(_circle(p(12, 12), u(8.5)), math.pi / 2, math.pi, true)
          ..close(),
      ),
    };
  }

  /// ↻: an open circle running clockwise from the upper right round to the
  /// top, where a filled arrowhead points right, into the gap.
  static StatusGlyphShape _comeBack(
    Offset Function(double, double) p,
    double Function(double) u,
    double strokeWidth,
  ) {
    const radius = 8.0;
    // Angles are clockwise from 3 o'clock, since the y axis points down.
    const tail = -math.pi / 6;
    const head = -math.pi / 2;
    return StatusGlyphShape._(
      stroke: Path()
        ..arcTo(
          _circle(p(12, 12), u(radius)),
          tail,
          head + 2 * math.pi - tail,
          true,
        ),
      strokeWidth: strokeWidth,
      // The arc ends at the top of the circle, (12, 4), heading right.
      fill: Path()
        ..moveTo(u(15), u(12 - radius))
        ..lineTo(u(11), u(12 - radius - 3))
        ..lineTo(u(11), u(12 - radius + 3))
        ..close(),
    );
  }

  static Rect _circle(Offset centre, double radius) =>
      Rect.fromCircle(center: centre, radius: radius);

  static const double _grid = 24;

  /// Stroke width as a fraction of the box: the same for every glyph, close
  /// to the weight of the bold text next to it.
  static const double strokeRatio = 2.6 / _grid;

  /// Lines drawn with round ends and corners.
  final Path stroke;

  final double strokeWidth;

  /// Areas painted solid (◐'s half disc, ↻'s arrowhead), if any.
  final Path? fill;
}

/// Paints a [StatusGlyphShape] in one colour.
final class StatusGlyphPainter extends CustomPainter {
  const StatusGlyphPainter(this.glyph, this.color);

  final StatusGlyphs glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = StatusGlyphShape.of(glyph, size.shortestSide);
    canvas.drawPath(
      shape.stroke,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = shape.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (shape.fill case final fill?) {
      canvas.drawPath(
        fill,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  /// Flutter calls this when the widget rebuilds with a new painter: redraw
  /// only if what it draws has changed.
  @override
  bool shouldRepaint(StatusGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
