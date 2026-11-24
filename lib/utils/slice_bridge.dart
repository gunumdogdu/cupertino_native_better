import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Keeps the Flutter content a modal paints after a native view of its own
/// on screen (#192).
///
/// **The bug.** On iOS the engine draws Flutter content painted above a
/// platform view into an overlay layer: the content painted after each
/// platform view, where it touches that view or one painted before it, goes
/// into one overlay, sized to the bounding box of those places. That box is
/// then cut out of the base Flutter layer for the rest of the frame.
///
/// A modal's barrier covers the whole screen. When two native views stay
/// live under it (a `CNTabBar` and a `CNSwitch` with
/// `autoHideOnModal: false`, say), the barrier touches both, so its overlay
/// spans from the top one to the bottom one. Content the modal paints after
/// a native view of its own (a `CNSearchBar`, a glass `CNButton`) goes to
/// the base layer when it touches no native view, and inside that span it
/// is cut out: a Save button under a search bar in a sheet, or text under a
/// glass button in a dialog, isn't painted (it still takes taps).
///
/// **The fix.** Right after the native view, this draws a hairline just
/// outside the screen's edges. No pixel on screen changes, but the engine
/// sees a draw as big as the screen, which touches every native view below.
/// So the content painted after the native view gets an overlay over the
/// same span, and all of it is painted there.
///
/// A clip around the native view (a dialog with rounded corners, say) clips
/// that draw too, so the view also draws it from the route's overlay, above
/// the whole route and outside every clip. That reaches the content after
/// the route's last native view; content between two native views inside
/// such a clip relies on the clipped draw.
///
/// It draws only on iOS, in a modal route that shows the page under it (not
/// [ModalRoute.opaque]), and while at least two native views of this
/// package are live in other routes: with one, there is no span to fall
/// into.
class CNSliceBridge extends StatefulWidget {
  /// Wraps the native view [child].
  const CNSliceBridge({super.key, required this.child});

  /// The platform view.
  final Widget child;

  /// The live native views, by the route they are in, so each knows how
  /// many are live in other routes.
  static final Map<_CNSliceBridgeState, ModalRoute<dynamic>?> _live = {};
  static final ValueNotifier<int> _changes = ValueNotifier<int>(0);
  static bool _changePending = false;

  /// The number of native views being tracked, for tests.
  @visibleForTesting
  static int get debugLiveCount => _live.length;

  /// Whether [ro] is the draw this paints in a route's overlay: it paints
  /// nothing on screen, so the modal measure leaves it out.
  static bool isOverlayBridge(RenderObject ro) => ro is _RenderOverlayBridge;

  static void _changed() {
    // Once per frame, after it: the bridges listening rebuild.
    if (_changePending) return;
    _changePending = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _changePending = false;
        _changes.value++;
      })
      ..ensureVisualUpdate();
  }

  @override
  State<CNSliceBridge> createState() => _CNSliceBridgeState();
}

class _CNSliceBridgeState extends State<CNSliceBridge> {
  ModalRoute<dynamic>? _route;

  /// Set on the first build when the view is in a modal route that shows
  /// the page under it, with an overlay to draw in.
  OverlayPortalController? _portal;
  bool _portalDecided = false;

  @override
  void initState() {
    super.initState();
    CNSliceBridge._changes.addListener(_onChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!CNSliceBridge._live.containsKey(this) || route != _route) {
      _route = route;
      CNSliceBridge._live[this] = route;
      CNSliceBridge._changed();
    }
    if (!_portalDecided) {
      // Decided once: adding or removing the portal later would create the
      // native view again.
      _portalDecided = true;
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          route != null &&
          !route.opaque &&
          Overlay.maybeOf(context) != null) {
        _portal = OverlayPortalController()..show();
      }
    }
  }

  @override
  void dispose() {
    CNSliceBridge._changes.removeListener(_onChanged);
    CNSliceBridge._live.remove(this);
    CNSliceBridge._changed();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _bridges {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    final route = _route;
    if (route == null || route.opaque) return false;
    var below = 0;
    for (final other in CNSliceBridge._live.values) {
      if (other != route && ++below >= 2) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final view = View.maybeOf(context);
    final screen = view == null
        ? Size.zero
        : view.physicalSize / view.devicePixelRatio;
    final bridges = _bridges && !screen.isEmpty;
    final Widget child = _SliceBridge(
      bridges: bridges,
      screen: screen,
      child: widget.child,
    );
    final portal = _portal;
    if (portal == null) return child;
    return OverlayPortal(
      controller: portal,
      overlayChildBuilder: (_) =>
          _OverlayBridge(bridges: bridges, screen: screen),
      child: child,
    );
  }
}

/// Draws a hairline just outside [screen]'s edges, in [box]'s coordinates:
/// nothing on screen, but a draw as big as the screen for the engine.
void _drawScreenBridge(
  RenderBox box,
  PaintingContext context,
  Offset offset,
  Size screen,
) {
  final toLocal = box.getTransformTo(null);
  if (toLocal.invert() == 0) return;
  final rect = MatrixUtils.transformRect(
    toLocal,
    (Offset.zero & screen).inflate(4),
  );
  context.canvas.drawRect(rect.shift(offset), _bridgePaint);
}

final Paint _bridgePaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1
  ..color = const Color(0x01000000);

class _SliceBridge extends SingleChildRenderObjectWidget {
  const _SliceBridge({
    required this.bridges,
    required this.screen,
    required super.child,
  });

  final bool bridges;
  final Size screen;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSliceBridge(bridges: bridges, screen: screen);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliceBridge renderObject,
  ) {
    renderObject
      ..bridges = bridges
      ..screen = screen;
  }
}

class _RenderSliceBridge extends RenderProxyBox {
  _RenderSliceBridge({required bool bridges, required Size screen})
    : _bridges = bridges,
      _screen = screen;

  bool _bridges;
  set bridges(bool value) {
    if (value == _bridges) return;
    _bridges = value;
    markNeedsPaint();
  }

  Size _screen;
  set screen(Size value) {
    if (value == _screen) return;
    _screen = value;
    if (_bridges) markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // After the native view: in the content painted after it.
    if (_bridges) _drawScreenBridge(this, context, offset, _screen);
  }
}

class _OverlayBridge extends LeafRenderObjectWidget {
  const _OverlayBridge({required this.bridges, required this.screen});

  final bool bridges;
  final Size screen;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOverlayBridge(bridges: bridges, screen: screen);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOverlayBridge renderObject,
  ) {
    renderObject
      ..bridges = bridges
      ..screen = screen;
  }
}

/// The draw in the route's overlay: no size, no hits, no semantics.
class _RenderOverlayBridge extends RenderBox {
  _RenderOverlayBridge({required bool bridges, required Size screen})
    : _bridges = bridges,
      _screen = screen;

  bool _bridges;
  set bridges(bool value) {
    if (value == _bridges) return;
    _bridges = value;
    markNeedsPaint();
  }

  Size _screen;
  set screen(Size value) {
    if (value == _screen) return;
    _screen = value;
    if (_bridges) markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_bridges) _drawScreenBridge(this, context, offset, _screen);
  }
}
