import 'package:flutter/widgets.dart';

/// The outlined building of « Transformer en immeuble… » (House mockup):
/// a tall rectangle with three rows of two windows, drawn so it matches the
/// mockup's line icon, which the Material icon font does not have.
///
/// Decoration only: the button's label names the action.
final class BuildingIcon extends StatelessWidget {
  const BuildingIcon({super.key, required this.size, this.color});

  final double size;

  /// Defaults to the colour of the button's text and icons.
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _BuildingPainter(color ?? IconTheme.of(context).color!),
    ),
  );
}

final class _BuildingPainter extends CustomPainter {
  const _BuildingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The mockup's SVG is drawn on a 24 × 24 grid; `u` scales its units.
    final scale = size.shortestSide / 24;
    double u(double units) => units * scale;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = u(2)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(u(5), u(3), u(14), u(18)),
        Radius.circular(u(1)),
      ),
      paint,
    );
    final windows = Path();
    for (final y in const [7.0, 11.0, 15.0]) {
      for (final x in const [9.0, 13.0]) {
        windows
          ..moveTo(u(x), u(y))
          ..lineTo(u(x + 2), u(y));
      }
    }
    canvas.drawPath(windows, paint);
  }

  @override
  bool shouldRepaint(_BuildingPainter oldDelegate) =>
      oldDelegate.color != color;
}
