import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../components/tab_bar.dart' show CNTabBarRouteObserver;
import 'modal_geometry.dart' show globalBoundsOf;

/// Position-aware destroy-on-modal helper for PlatformView-based CN-widgets.
///
/// **The bug.** Flutter's iOS hybrid composition inserts every `UiKitView`
/// from every Flutter route into a single shared PlatformView container
/// under the one `FlutterView`. Modal sheets are Flutter overlay layers
/// (not UIKit presentations), so when a CN-widget sits on the host page
/// AND another CN-widget lives inside a modal sheet, Flutter's per-frame
/// overlay-quad recomputation can desync with iOS's layer-tree mutations
/// during the sheet's drag, leaking host-page PlatformView pixels through
/// the sheet's scrim (Issue #53).
///
/// **The fix.** Remove host-page PlatformViews while a sheet is up. To
/// avoid pointlessly destroying widgets that are nowhere near the sheet
/// (e.g. an `AppBar` button while a 30%-tall sheet is open), this mixin
/// is **position-aware**: only a widget whose rect the sheet covers is
/// removed ([CNTabBarRouteObserver.modalRect]).
///
/// **Where the sheet is.** `CNTabBarRouteObserver` measures what the top
/// modal route paints (its sheet, popup or dialog, not its barrier) after
/// every frame, whichever API opened it (#149). Sheets opened with
/// `CNBottomSheet`, or wrapped in `CNSheetGeometryProbe`, publish their
/// rect themselves ([CNTabBarRouteObserver.topModalRect]), which takes
/// precedence. When neither is known, the mixin falls back to "destroy
/// everything", the safe behavior that still kills the bleed.
///
/// **Mount-depth gate.** Widgets that are themselves rendered INSIDE a
/// sheet (e.g. a `CNSwitch` in the sheet's body) must not self-destroy.
/// The mixin captures `anyModalDepth` at mount time as `_mountDepth` and
/// only considers hiding when the live depth has grown PAST that snapshot.
///
/// **Usage.** Override [autoHideOnModal] to expose the widget's flag.
/// At the top of `build()` (right before constructing the `UiKitView`):
///
/// ```dart
/// final hidden = maybeHiddenPlaceholder(height: h, width: w);
/// if (hidden != null) return hidden;
/// ```
mixin ModalHideMixin<T extends StatefulWidget> on State<T> {
  int _mountDepth = 0;
  bool _modalUp = false;
  bool _modalAbove = false;

  /// Override to expose the widget's `autoHideOnModal` flag.
  bool get autoHideOnModal;

  /// Override to expose the per-instance `MethodChannel` for the
  /// underlying PlatformView so the mixin can call `setInteractive` on it
  /// when a modal opens/closes. Return null if no channel exists yet —
  /// the mixin then skips the native call (no harm; the AbsorbPointer
  /// wrap still runs as a no-op).
  ///
  /// The platform-side `MethodChannel` must implement a `"setInteractive"`
  /// handler that sets `view.isUserInteractionEnabled = interactive`
  /// (`{interactive: bool}`). This is the ONLY way to reliably block taps
  /// to a native iOS UIView during a Flutter modal — Flutter's
  /// `AbsorbPointer` does not propagate to native PlatformView touch
  /// handling.
  MethodChannel? get platformViewChannel => null;

  /// True iff this widget should currently render its hide placeholder
  /// (because a modal/sheet is covering its rect AND [autoHideOnModal]
  /// is true).
  bool get isHiddenForModal => _modalUp && autoHideOnModal;

  /// True iff a modal is currently presented above this widget's host
  /// route. Independent of geometry — covers widgets that stay visible
  /// (above the sheet) but should NOT be interactive while a sheet is up.
  /// Flutter's modal scrim doesn't block touches to native iOS PlatformView
  /// widgets, so we have to suppress interaction ourselves.
  bool get isAnyModalAbove => _modalAbove;

  @override
  void initState() {
    super.initState();
    _mountDepth = CNTabBarRouteObserver.anyModalDepth.value;
    _modalAbove = CNTabBarRouteObserver.anyModalDepth.value > _mountDepth;
    _modalUp = _computeShouldHide();
    CNTabBarRouteObserver.anyModalDepth.addListener(_onModalStateChanged);
    CNTabBarRouteObserver.topModalRect.addListener(_onModalStateChanged);
    CNTabBarRouteObserver.routeModalRect.addListener(_onModalStateChanged);
  }

  @override
  void dispose() {
    CNTabBarRouteObserver.anyModalDepth.removeListener(_onModalStateChanged);
    CNTabBarRouteObserver.topModalRect.removeListener(_onModalStateChanged);
    CNTabBarRouteObserver.routeModalRect.removeListener(_onModalStateChanged);
    super.dispose();
  }

  /// True iff a modal newer than this widget's host route is up AND either
  /// the sheet's rect isn't known (safe fallback: hide) OR this widget's own
  /// rect intersects it.
  bool _computeShouldHide() {
    final depth = CNTabBarRouteObserver.anyModalDepth.value;
    if (depth <= _mountDepth) return false;
    final sheetRect = CNTabBarRouteObserver.modalRect;
    if (sheetRect == null) {
      // Sheet geometry unknown. Fall back to the safe "destroy everything"
      // behavior so the bleed bug stays fixed.
      return true;
    }
    final myRect = _globalRect();
    // Can't measure (early frame, detached): be safe, destroy.
    if (myRect == null) return true;
    return myRect.overlaps(sheetRect);
  }

  /// This widget's global bounds, or null before it is laid out.
  Rect? _globalRect() {
    final ro = context.findRenderObject();
    if (ro is! RenderBox) return null;
    return globalBoundsOf(ro);
  }

  void _onModalStateChanged() {
    if (!mounted) return;
    // Schedule on post-frame so [_computeShouldHide] sees the latest layout,
    // and make sure that frame comes: the last rect of an animation arrives
    // after its last frame.
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final newAbove = CNTabBarRouteObserver.anyModalDepth.value > _mountDepth;
      final newHide = _computeShouldHide();
      // Capture the transition BEFORE setState (which would otherwise make
      // the diff always equal to itself, suppressing _applyNativeInteractive).
      final aboveChanged = newAbove != _modalAbove;
      final hideChanged = newHide != _modalUp;
      if (aboveChanged || hideChanged) {
        setState(() {
          _modalAbove = newAbove;
          _modalUp = newHide;
        });
      }
      // TAPPING-FIX REVERT: the native setInteractive channel call and
      // its caller _applyNativeInteractive are intentionally removed
      // here. We want to isolate whether the visible blink/rebuild
      // during sheet open/close is caused by the interaction-guard
      // wrap or by the position-aware hide path itself.
    });
  }

  /// Returns a same-sized [SizedBox] placeholder when [isHiddenForModal] is
  /// true, else null. Use as an early return at the top of `build()` so the
  /// live `UiKitView`/`AppKitView` is never constructed while a modal is
  /// up — that's what removes the PlatformView from the iOS shared
  /// container and fixes the bleed.
  Widget? maybeHiddenPlaceholder({double? height, double? width}) {
    if (!isHiddenForModal) return null;
    return SizedBox(height: height, width: width);
  }

  /// Wraps [liveChild] in a [Stack] with a transparent opaque [Listener]
  /// on top while any modal is above the host route. The Listener actively
  /// CLAIMS pointer events via Flutter's gesture arena, which is the only
  /// reliable Dart-side way to keep a tap from being forwarded to the
  /// native iOS PlatformView's gesture recognizers.
  ///
  /// Why this, and not [AbsorbPointer]:
  ///   `AbsorbPointer` marks the subtree non-hit-testable, but Flutter's
  ///   iOS hybrid-composition gesture-forwarder uses its own delaying
  ///   recognizers to ferry touches to the native UIView's
  ///   `gestureRecognizers`. That path runs even when `AbsorbPointer`
  ///   wraps the platform view, so on-device the native UIButton's press
  ///   animation still fires and (sometimes) the action runs too. A
  ///   Listener overlay sits as a sibling on top of the platform view in
  ///   the widget tree and HANDLES `onPointerDown`. Once handled, Flutter
  ///   considers the arena won and stops forwarding the gesture to the
  ///   platform view.
  ///
  /// The native `setInteractive` channel call (which also fires from the
  /// mixin) remains a belt-and-suspenders safety on top of this overlay,
  /// in case future Flutter releases change platform-view dispatch.
  ///
  /// TAPPING-FIX REVERT: this method is currently a passthrough so we
  /// can isolate the rebuild/blink issue. Each widget still calls it
  /// from build, but it does nothing extra. The previous Stack +
  /// IgnorePointer + Listener overlay (and its earlier AbsorbPointer
  /// variant) caused widget-tree-shape changes that triggered platform-
  /// view destroy/recreate on modal open/close. We'll reintroduce a
  /// gesture guard only after the blink source is identified.
  Widget wrapWithModalInteractionGuard(Widget liveChild) => liveChild;
}

/// Drives the native halo containment (`setTransitioning`) of an iOS 26
/// Liquid Glass platform view (Issues #29, #124, #156 and #159).
///
/// At rest the glass view is unclipped, so it can draw its full soft glow.
/// Flutter draws what lies over the view inside its bounds above it, but
/// past its bounds the glow would draw over a sheet or page coming over it.
/// So while a sheet, popup, dialog or page is within reach of the glow,
/// the native view hides the part of its glow under it (`cuts`) and keeps
/// its full glass everywhere else:
///
///  * while the host route animates, because a page is pushed over it,
///    popped off it, or dragged by the back gesture (#29, #159); and
///  * while a modal route (a dialog, popup or sheet) is over a widget that
///    stays mounted, and its sheet, popup or dialog is within reach of the
///    widget's glow (#124, #156). This rule also holds when the host route
///    transitions with the modal, so the modal moves its secondary
///    animation: a sheet package's sheet route over a page in a
///    `PageRouteBuilder`, or `showCupertinoSheet` (#161). What covers the
///    widget is the sheet, not the sheet route's whole box.
///
/// When the position of what covers it can't be told (no
/// `CNTabBarRouteObserver`, or a modal whose bounds aren't known yet), the
/// native view is clipped to its bounds and its shadow cleared instead
/// (`active`), which leaves the glass flat. So is it on macOS, where the
/// engine clips every platform view to its bounds anyway.
///
/// The modal's bounds are measured after every frame while it moves, and
/// lead its motion by a frame ([CNTabBarRouteObserver.modalRect]); so are a
/// moving page's ([CNTabBarRouteObserver.movingRouteRect]). A modal whose
/// sheet, popup or dialog stays elsewhere leaves the widget its full
/// glass, dimmed by the barrier like the rest of the page: at rest (#149),
/// while it fades in or out, and while it moves the page under it, as
/// sheet packages that scale the page down do, also for as long as a finger
/// holds their sheet mid-drag (#156). A widget that [ModalHideMixin]
/// removed while the modal is up needs nothing.
///
/// The glass view must not sit in a Flutter clip the size of the view (a
/// `ClipRect` around it): under a scaled page the engine can't always tell
/// that such a clip covers the view, and masks the view to its bounds,
/// which cuts the glow into a box (#156).
///
/// The modal rules read [CNTabBarRouteObserver.anyModalDepth],
/// [CNTabBarRouteObserver.modalBoundsPending] and
/// [CNTabBarRouteObserver.modalRect], so like `autoHideOnModal` they need a
/// `CNTabBarRouteObserver` in the navigator's `navigatorObservers`. They are
/// listened to directly, not after a frame: a modal that appears without an
/// entrance animation is contained against before its first frame, until
/// its bounds are known.
///
/// **Usage.** Mix in after [ModalHideMixin] and call
/// [resetHaloContainment] from `onPlatformViewCreated`, once
/// [ModalHideMixin.platformViewChannel] returns the new view's channel. The
/// native view must handle `setTransitioning` (`{active: bool, cuts:
/// [[left, top, right, bottom], ...]}`, the cuts in its own coordinates and
/// outside its bounds).
mixin HaloContainmentMixin<T extends StatefulWidget> on ModalHideMixin<T> {
  ModalRoute<dynamic>? _hostRoute;
  Animation<double>? _routeAnimation;
  bool _pageAwaited = false;
  bool? _sentContainment;
  List<double> _sentCuts = const <double>[];

  /// How far past its bounds the glass can draw its glow and shadow.
  static const double _haloReach = 24;

  /// How far past its bounds a cut reaches: well past the glow.
  static const double _cutReach = 160;

  /// Whether the native view hides only the covered part of its glow. On
  /// macOS the engine clips every platform view to its bounds.
  static bool get _cutsSupported => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether the native view was last told to clip to its bounds, its glass
  /// flat.
  bool get isHaloContained => _sentContainment ?? false;

  /// The containment now: clipped, or the global rect of what covers part of
  /// the glow, or neither. Null to keep what was sent.
  ({bool contained, Rect? cover})? _haloState() {
    const full = (contained: false, cover: null);
    const contained = (contained: true, cover: null);
    final status = _routeAnimation?.status;
    final host = _hostRoute;
    if ((status == AnimationStatus.forward ||
            status == AnimationStatus.reverse) &&
        // A sheet route the host transitions with moves its secondary
        // animation too, but the modal rules below measure its sheet; its
        // route's box is the whole screen (#161).
        !(host != null &&
            CNTabBarRouteObserver.secondaryAnimationFollowsModal(host))) {
      // The page moving over or off this one hides the glow it covers,
      // where it is now (#159). Only an observer of this navigator can tell
      // where that is.
      final navigator = _hostRoute?.navigator;
      final observed =
          navigator?.widget.observers.any((o) => o is CNTabBarRouteObserver) ??
          false;
      if (!_cutsSupported || !observed) return contained;
      final moving = CNTabBarRouteObserver.movingRoute;
      final page = CNTabBarRouteObserver.movingRouteRect.value;
      if (page == null ||
          moving == null ||
          identical(moving, _hostRoute) ||
          !identical(moving.navigator, navigator)) {
        // The route starts moving before the navigator tells its observers
        // about the push or pop, in the same call: wait for it, a frame at
        // most.
        if (_pageAwaited) return contained;
        _pageAwaited = true;
        _retryAfterFrame();
        return _sentContainment == null ? full : null;
      }
      _pageAwaited = false;
      if (page.isEmpty) return full;
      final mine = _globalRect();
      if (mine == null) return _retryAfterFrame();
      return mine.inflate(_haloReach).overlaps(page)
          ? (contained: false, cover: page)
          : full;
    }
    _pageAwaited = false;
    final modalAbove = CNTabBarRouteObserver.anyModalDepth.value > _mountDepth;
    if (!modalAbove || isHiddenForModal) return full;
    // A modal entering from nothing paints next to nothing in its first
    // frame: keep the glass as it is until its bounds are measured, so a
    // modal elsewhere doesn't clip it for that frame (#156).
    if (CNTabBarRouteObserver.modalBoundsPending.value) {
      return _sentContainment == null ? full : null;
    }
    // Where the sheet, popup or dialog is decides, while it moves too: a
    // barrier fading in or out dims the glass evenly, and a page the modal
    // moves carries the glass with it (#156).
    final sheet = CNTabBarRouteObserver.modalRect;
    if (sheet == null) return contained;
    // It paints nothing yet, as in the first frame of a sheet route's push.
    if (sheet.isEmpty) return full;
    final mine = _globalRect();
    if (mine == null) return _retryAfterFrame();
    if (!mine.inflate(_haloReach).overlaps(sheet)) return full;
    return _cutsSupported ? (contained: false, cover: sheet) : contained;
  }

  bool _retryArmed = false;

  /// Keeps what was sent while this widget isn't laid out where it is now,
  /// and decides again after the frame (#159). Nothing sent yet: contained.
  ({bool contained, Rect? cover})? _retryAfterFrame() {
    if (!_retryArmed) {
      _retryArmed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _retryArmed = false;
        syncHaloContainment();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    return _sentContainment == null ? (contained: true, cover: null) : null;
  }

  /// The parts of [cover] (global) that lie past the glass view's bounds and
  /// within reach of its glow, as `[left, top, right, bottom]` rects in the
  /// view's own coordinates: at most four, not overlapping. Inside its
  /// bounds Flutter draws what covers the view above it.
  List<List<double>> _cutsFor(Rect cover) {
    final box = _glassBox();
    if (box == null || globalBoundsOf(box) == null) {
      return const <List<double>>[];
    }
    final toLocal = Matrix4.tryInvert(box.getTransformTo(null));
    if (toLocal == null) return const <List<double>>[];
    final bounds = Offset.zero & box.size;
    final local = MatrixUtils.transformRect(toLocal, cover);
    if (!bounds.inflate(_haloReach).overlaps(local)) {
      return const <List<double>>[];
    }
    final c = local.intersect(bounds.inflate(_cutReach));
    final pieces = <Rect>[];
    if (!c.overlaps(bounds)) {
      pieces.add(c);
    } else {
      final top = math.max(c.top, bounds.top);
      final bottom = math.min(c.bottom, bounds.bottom);
      pieces
        ..add(Rect.fromLTRB(c.left, c.top, c.right, top))
        ..add(Rect.fromLTRB(c.left, bottom, c.right, c.bottom))
        ..add(Rect.fromLTRB(c.left, top, bounds.left, bottom))
        ..add(Rect.fromLTRB(bounds.right, top, c.right, bottom));
    }
    double round(double v) => (v * 2).roundToDouble() / 2;
    return <List<double>>[
      for (final p in pieces)
        if (p.width > 0 && p.height > 0)
          <double>[
            round(p.left),
            round(p.top),
            round(p.right),
            round(p.bottom),
          ],
    ];
  }

  /// The render box of the glass platform view: the first `UiKitView` under
  /// this widget, else the widget's own box.
  RenderBox? _glassBox() {
    final root = context.findRenderObject();
    if (root is! RenderBox || !root.attached || !root.hasSize) return null;
    RenderBox? found;
    var budget = 64;
    void visit(RenderObject ro) {
      if (found != null || --budget < 0) return;
      if (ro is RenderUiKitView) {
        found = ro;
        return;
      }
      ro.visitChildren(visit);
    }

    visit(root);
    final box = found ?? root;
    return box.hasSize ? box : null;
  }

  @override
  void initState() {
    super.initState();
    CNTabBarRouteObserver.anyModalDepth.addListener(syncHaloContainment);
    CNTabBarRouteObserver.modalBoundsPending.addListener(syncHaloContainment);
    CNTabBarRouteObserver.topModalRect.addListener(syncHaloContainment);
    CNTabBarRouteObserver.routeModalRect.addListener(syncHaloContainment);
    CNTabBarRouteObserver.movingRouteRect.addListener(syncHaloContainment);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hostRoute = ModalRoute.of(context);
    final animation = _hostRoute?.secondaryAnimation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
      _routeAnimation = animation;
      _routeAnimation?.addStatusListener(_onRouteAnimationStatus);
    }
    syncHaloContainment();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `autoHideOnModal` may have changed.
    syncHaloContainment();
  }

  @override
  void dispose() {
    CNTabBarRouteObserver.anyModalDepth.removeListener(syncHaloContainment);
    CNTabBarRouteObserver.modalBoundsPending.removeListener(
      syncHaloContainment,
    );
    CNTabBarRouteObserver.topModalRect.removeListener(syncHaloContainment);
    CNTabBarRouteObserver.routeModalRect.removeListener(syncHaloContainment);
    CNTabBarRouteObserver.movingRouteRect.removeListener(syncHaloContainment);
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation = null;
    _hostRoute = null;
    super.dispose();
  }

  void _onRouteAnimationStatus(AnimationStatus _) => syncHaloContainment();

  /// Sends the containment state to the native view if it changed since
  /// the last send.
  void syncHaloContainment() {
    if (!mounted) return;
    final channel = platformViewChannel;
    if (channel == null) return;
    final state = _haloState();
    if (state == null) return;
    final cover = state.cover;
    final cuts = cover == null ? const <List<double>>[] : _cutsFor(cover);
    final flat = <double>[for (final c in cuts) ...c];
    if (state.contained == _sentContainment && listEquals(flat, _sentCuts)) {
      return;
    }
    _sentContainment = state.contained;
    _sentCuts = flat;
    // Fire-and-forget from a listener. `catchError`, not try/catch, because
    // the error (e.g. MissingPluginException while the view is recreated)
    // arrives asynchronously.
    channel
        .invokeMethod<void>('setTransitioning', <String, Object?>{
          'active': state.contained,
          if (cuts.isNotEmpty) 'cuts': cuts,
        })
        .catchError((Object _) {});
  }

  /// Sends the current state to a newly created native view.
  void resetHaloContainment() {
    _sentContainment = null;
    _sentCuts = const <double>[];
    syncHaloContainment();
  }
}
