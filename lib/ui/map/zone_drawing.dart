import 'package:flutter/widgets.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// Draws a zone with a finger over the map of « Ajouter des rues » (PLAN
/// §5.14, PickZone mockup), while [enabled]: a drag draws a rectangle (the
/// map around it dimmed, a dashed edge, a round handle at its bottom-right
/// corner), handed over on release as a rectangle of this widget's own
/// coordinates. A drag from the handle of the zone shown resizes it from
/// its opposite corner.
///
/// A [Listener], not a gesture detector: it sees the pointers without
/// taking part in the gesture arena, so the map under it still gets them.
/// The map must not pan meanwhile (`scrollGesturesEnabled` off), but a
/// pinch still zooms: a second finger down drops the drawing.
///
/// Only the drawing in progress is painted here, in screen coordinates;
/// once handed over, the zone is drawn by the map itself, so it follows the
/// map when it zooms.
final class ZoneDrawing extends StatefulWidget {
  const ZoneDrawing({
    super.key,
    required this.enabled,
    required this.onDrawn,
    required this.child,
    this.zoneOnScreen,
  });

  /// Whether a drag draws a zone; when false, pointers only reach [child].
  final bool enabled;

  /// The rectangle drawn, in this widget's coordinates, at least
  /// [AppSizes.zoneMinSide] on each side.
  final ValueChanged<Rect> onDrawn;

  /// Where the zone shown is on screen, read when a finger goes down to
  /// tell whether it took the handle; null when there is none.
  final ValueGetter<Rect?>? zoneOnScreen;

  /// The map.
  final Widget child;

  @override
  State<ZoneDrawing> createState() => _ZoneDrawingState();
}

final class _ZoneDrawingState extends State<ZoneDrawing> {
  /// The fingers on the screen, drawing or not.
  var _pointers = 0;

  /// The corner the drag holds still, and the one under the finger; null
  /// when nothing is being drawn.
  Offset? _anchor;
  Offset? _corner;

  void _down(PointerDownEvent event) {
    _pointers++;
    if (!widget.enabled || _pointers > 1) {
      // A second finger: a pinch, which zooms the map.
      _drop();
      return;
    }
    final finger = event.localPosition;
    final shown = widget.zoneOnScreen?.call();
    final onHandle =
        shown != null &&
        (finger - shown.bottomRight).distance <= AppSizes.zoneHandleReach;
    setState(() {
      _anchor = onHandle ? shown.topLeft : finger;
      _corner = finger;
    });
  }

  void _move(PointerMoveEvent event) {
    if (_anchor == null) return;
    setState(() => _corner = event.localPosition);
  }

  void _up(PointerUpEvent event) {
    _pointers--;
    final (anchor, corner) = (_anchor, _corner);
    _drop();
    if (anchor == null || corner == null) return;
    final drawn = Rect.fromPoints(anchor, corner);
    if (drawn.width < AppSizes.zoneMinSide ||
        drawn.height < AppSizes.zoneMinSide) {
      // A tap that slid a little: the map takes it as a tap.
      return;
    }
    widget.onDrawn(drawn);
  }

  void _cancel(PointerCancelEvent event) {
    _pointers--;
    _drop();
  }

  void _drop() {
    if (_anchor == null) return;
    setState(() {
      _anchor = null;
      _corner = null;
    });
  }

  @override
  void didUpdateWidget(ZoneDrawing oldWidget) {
    super.didUpdateWidget(oldWidget);
    // « Zone » turned off under the finger.
    if (!widget.enabled) {
      _anchor = null;
      _corner = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (anchor, corner) = (_anchor, _corner);
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      // The map is always the first child, so the native map view is never
      // built again when the drawing shows or goes.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const Key('zoneDrawing.paint'),
                painter: ZonePainter(
                  zone: anchor == null || corner == null
                      ? null
                      : Rect.fromPoints(anchor, corner),
                  colors: AppColors.of(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a zone being drawn as the map draws one (PickZone mockup): the
/// rest dimmed, a dashed edge, a round handle at the bottom-right corner.
/// Paints nothing without a [zone].
final class ZonePainter extends CustomPainter {
  const ZonePainter({required this.zone, required this.colors});

  final Rect? zone;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final zone = this.zone;
    if (zone == null) return;
    final ink = colors.mapSelectedCasing;
    // Even-odd: the zone inside the whole area is a hole in the shade.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(zone),
      Paint()..color = ink.withValues(alpha: AppSizes.zoneShadeOpacity),
    );
    final edge = Paint()
      ..color = ink
      ..strokeWidth = AppSizes.zoneEdgeWidth
      ..style = PaintingStyle.stroke;
    for (final (from, to) in [
      (zone.topLeft, zone.topRight),
      (zone.topRight, zone.bottomRight),
      (zone.bottomRight, zone.bottomLeft),
      (zone.bottomLeft, zone.topLeft),
    ]) {
      _dash(canvas, from, to, edge);
    }
    canvas
      ..drawCircle(
        zone.bottomRight,
        AppSizes.zoneHandleRadius,
        Paint()..color = colors.mapSelectedCore,
      )
      ..drawCircle(zone.bottomRight, AppSizes.zoneHandleRadius, edge);
  }

  /// A dashed line from [from] to [to].
  static void _dash(Canvas canvas, Offset from, Offset to, Paint paint) {
    final length = (to - from).distance;
    if (length == 0) return;
    final step = (to - from) / length;
    for (
      var at = 0.0;
      at < length;
      at += AppSizes.zoneDash + AppSizes.zoneGap
    ) {
      final end = at + AppSizes.zoneDash < length
          ? at + AppSizes.zoneDash
          : length;
      canvas.drawLine(from + step * at, from + step * end, paint);
    }
  }

  @override
  bool shouldRepaint(ZonePainter oldDelegate) =>
      oldDelegate.zone != zone || oldDelegate.colors != colors;
}
