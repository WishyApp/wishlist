import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports the size of [child] after each layout that changes it, for a
/// widget that must make room for another one it does not lay out (a list
/// scrolling under a fixed header).
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({
    super.key,
    required this.onChange,
    required Widget super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

/// Render object of [MeasureSize]
class RenderMeasureSize extends RenderProxyBox {
  RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size;
    if (newSize == null || newSize == _lastSize) {
      return;
    }
    _lastSize = newSize;
    // Reported after the frame: the owner rebuilds with it, which it cannot
    // do during layout
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}
