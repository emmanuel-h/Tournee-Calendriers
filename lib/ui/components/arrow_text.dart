import 'package:flutter/widgets.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';

/// One line of text whose « → » are drawn as vector arrows, like
/// « 7 → Personne » in the undo snackbar.
///
/// The bundled fonts have no → character, so the phone would draw it with
/// a fallback font: smaller than the text and low on the line. The copy
/// stays in `app_fr.arb` with its « → »; this widget only swaps each one for
/// an [ArrowGlyph] when it lays the text out.
///
/// Screen readers hear [text] as it is written: the glyphs are decoration.
final class ArrowText extends StatelessWidget {
  const ArrowText(this.text, {super.key, this.style});

  /// The message, « → » included.
  final String text;

  /// Merged over the surrounding `DefaultTextStyle`, as `Text` does. The
  /// arrows take its size and colour.
  final TextStyle? style;

  /// The character drawn as an arrow.
  static const arrow = '→';

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final parts = text.split(arrow);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: parts.first),
            for (final part in parts.skip(1)) ...[
              // 14 is the size Flutter gives text that sets none.
              arrowSpan(size: effective.fontSize ?? 14, color: effective.color),
              TextSpan(text: part),
            ],
          ],
        ),
        style: style,
      ),
    );
  }
}

/// An [ArrowGlyph] to put inside a sentence (`Text.rich`), centred on the
/// line like the status glyphs.
WidgetSpan arrowSpan({required double size, Color? color}) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: ArrowGlyph(size: size, color: color),
);

/// « → » drawn as a vector shape in a square box, with the stroke weight of
/// the status glyphs (`StatusGlyph`).
final class ArrowGlyph extends StatelessWidget {
  const ArrowGlyph({super.key, required this.size, this.color});

  /// Side of the box at the default text size, in dp: the font size of the
  /// text around it. The box grows with the phone's text size setting.
  final double size;

  /// Defaults to the colour of the surrounding text.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.textScalerOf(context).scale(size);
    final ink = color ?? DefaultTextStyle.of(context).style.color!;
    return SizedBox.square(
      dimension: side,
      child: CustomPaint(painter: ArrowPainter(ink)),
    );
  }
}

/// The arrow in a square of side [size]: a shaft along the middle line and
/// a two-stroke head at the right, on the 24 × 24 grid of the status
/// glyphs, with the same margin so it never touches the next letter.
Path arrowShape(double size) {
  double u(double units) => units * size / 24;
  return Path()
    ..moveTo(u(4), u(12))
    ..lineTo(u(20), u(12))
    ..moveTo(u(14.5), u(6.5))
    ..lineTo(u(20), u(12))
    ..lineTo(u(14.5), u(17.5));
}

/// Strokes [arrowShape] in one colour.
final class ArrowPainter extends CustomPainter {
  const ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.drawPath(
      arrowShape(side),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * StatusGlyphShape.strokeRatio
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Redraw only when the colour changed: the shape follows the box.
  @override
  bool shouldRepaint(ArrowPainter oldDelegate) => oldDelegate.color != color;
}
