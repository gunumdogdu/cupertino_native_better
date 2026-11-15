import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lets a platform view take only the pointers that land in [regions], given
/// in its own coordinates. Any other pointer goes on to the widgets behind
/// it, as a touch passes a native view that takes no touches there (#162).
///
/// With null [regions] the view takes every pointer on it.
class PlatformViewTouchRegions extends SingleChildRenderObjectWidget {
  /// Creates a touch filter for a platform view.
  const PlatformViewTouchRegions({
    super.key,
    required this.regions,
    required Widget super.child,
  });

  /// Where the native view takes touches, or null for everywhere.
  final List<Rect>? regions;

  @override
  RenderPlatformViewTouchRegions createRenderObject(BuildContext context) =>
      RenderPlatformViewTouchRegions(regions);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPlatformViewTouchRegions renderObject,
  ) {
    renderObject.regions = regions;
  }
}

/// The render object of [PlatformViewTouchRegions].
class RenderPlatformViewTouchRegions extends RenderProxyBox {
  /// Creates the render object with the given [regions].
  RenderPlatformViewTouchRegions(this._regions);

  List<Rect>? _regions;

  /// Where the native view takes touches, or null for everywhere. Read at
  /// each hit test, so a change needs no layout or paint.
  List<Rect>? get regions => _regions;
  set regions(List<Rect>? value) {
    if (listEquals(value, _regions)) return;
    _regions = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final regions = _regions;
    if (regions != null && !regions.any((r) => r.contains(position))) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}
