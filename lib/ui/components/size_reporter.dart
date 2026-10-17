import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tells [onHeight] how tall its [child] is laid out, each time that
/// changes: the map keeps « Me localiser », its attribution and the area it
/// fits clear of the street card over it, whatever the card holds.
///
/// A widget cannot read its child's size while it builds (the size is
/// decided after); this one reads it right after layout, through its own
/// render object, and tells it once the frame is drawn.
final class SizeReporter extends SingleChildRenderObjectWidget {
  const SizeReporter({super.key, required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderSizeReporter).onHeight = onHeight;
}

final class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _told;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _told) return;
    _told = height;
    // After the frame: the listener may rebuild, which a layout must not.
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
