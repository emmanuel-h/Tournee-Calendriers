import 'package:flutter/rendering.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// Draws a dashed rounded outline of [color] around what it paints over:
/// building tiles of the street screen, numbers of the edit mode.
///
/// Flutter borders are always solid, so the outline is painted by hand
/// (`CustomPaint(foregroundPainter: DashedOutlinePainter(…))`).
final class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter(this.color, {this.radius = AppSizes.tileRadius});

  final Color color;
  final double radius;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = AppSizes.borderWidth / 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(inset),
          Radius.circular(radius - inset),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.borderWidth;
    // Walks along the outline and keeps one dash every `_dash + _gap` pixels.
    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += _dash + _gap) {
        canvas.drawPath(metric.extractPath(start, start + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
