import 'package:flutter/widgets.dart';

/// The « › » at the right edge of a building tile: a tap opens something
/// (the building's grid) instead of changing a status.
///
/// Drawn rather than taken from the Material icon font: `Icons.chevron_right`
/// sits in a square box mostly empty on both sides, and a building tile of a
/// narrow phone has no width to spare. This box is half as wide as it is
/// tall, the chevron of the mockups' 24-unit icons centred in it.
///
/// Decoration only: the tile's label ends with « ouvrir ».
final class OpenChevron extends StatelessWidget {
  const OpenChevron({super.key, required this.height, required this.color});

  /// Height of the box, in dp; its width is half of it.
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: height / 2,
    height: height,
    child: CustomPaint(painter: _ChevronPainter(color)),
  );
}

final class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The mockups' SVG chevron (`M9 6l6 6-6 6`) on a 24-unit grid, moved
    // into a box 12 units wide; `u` scales those units to dp.
    final scale = size.height / 24;
    double u(double units) => units * scale;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = u(2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(u(3), u(6))
        ..lineTo(u(9), u(12))
        ..lineTo(u(3), u(18)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}
