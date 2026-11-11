import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../components/tab_bar.dart' show CNTabBarRouteObserver;

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
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return MatrixUtils.transformRect(
      ro.getTransformTo(null),
      Offset.zero & ro.size,
    );
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
/// Liquid Glass platform view (Issues #29 and #124).
///
/// At rest the glass view is unclipped, so it can draw its full soft glow.
/// While that glow could show past the view's bounds, the native side clips
/// the view and clears its shadow instead. This mixin turns that
/// containment on:
///
///  * while the host route animates, because a page is pushed over it or
///    popped off it (#29); and
///  * while a modal route (a dialog, popup or sheet) is over a widget that
///    stays mounted, and its sheet, popup or dialog is within reach of the
///    widget's glow, or its bounds aren't known yet, so the glow isn't
///    drawn over it (#124). A modal doesn't move the host route's secondary
///    animation, so the first rule never fires for it.
///
///  * while a modal route moves the page under it as it comes or goes, as
///    sheet packages that scale the page down do.
///
/// The modal's bounds are measured after every frame while it moves, and
/// lead its motion by a frame ([CNTabBarRouteObserver.modalRect]). A modal
/// whose sheet, popup or dialog stays elsewhere leaves the widget its full
/// glass, dimmed by the barrier like the rest of the page, at rest (#149)
/// and while it fades in or out (#156). A widget that [ModalHideMixin]
/// removed while the modal is up needs nothing.
///
/// The modal rules read [CNTabBarRouteObserver.anyModalDepth],
/// [CNTabBarRouteObserver.modalAnimating],
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
/// native view must handle `setTransitioning` (`{active: bool}`).
mixin HaloContainmentMixin<T extends StatefulWidget> on ModalHideMixin<T> {
  Animation<double>? _routeAnimation;
  bool? _sentContainment;

  /// How far past its bounds the glass can draw its glow and shadow.
  static const double _haloReach = 24;

  /// Where the widget was while the modal over it was last still (or when
  /// it was pushed), and whether the widget has moved since while the modal
  /// animates: some sheets move the page under them (#156).
  Rect? _stillRect;
  bool _movedWithModal = false;

  /// Whether containment should be on now.
  bool get isHaloContained {
    final status = _routeAnimation?.status;
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      return true;
    }
    final modalAbove = CNTabBarRouteObserver.anyModalDepth.value > _mountDepth;
    if (!modalAbove || isHiddenForModal) return false;
    // A modal entering from nothing paints next to nothing in its first
    // frame: keep the glass as it is until its bounds are measured, so a
    // modal elsewhere doesn't clip it for that frame (#156).
    if (CNTabBarRouteObserver.modalBoundsPending.value) {
      return _sentContainment ?? false;
    }
    // A sheet that moves the page under it as it comes and goes (a sheet
    // package scaling the page down) would show the glow's box: contained
    // while it does (#29).
    if (_movedWithModal) return true;
    // Otherwise where the sheet, popup or dialog is decides, while it moves
    // too: a barrier fading in or out dims the glass evenly (#156).
    final sheet = CNTabBarRouteObserver.modalRect;
    final mine = _globalRect();
    if (sheet == null || mine == null) return true;
    return mine.inflate(_haloReach).overlaps(sheet);
  }

  /// Follows whether the widget moves while a modal over it animates.
  void _trackMotionWithModal() {
    if (CNTabBarRouteObserver.anyModalDepth.value <= _mountDepth) {
      _stillRect = null;
      _movedWithModal = false;
      return;
    }
    final mine = _globalRect();
    final still = _stillRect;
    // The first call for a modal comes from its push, before its first
    // frame: the widget is where it was.
    if (still == null || !CNTabBarRouteObserver.modalAnimating.value) {
      _stillRect = mine;
      _movedWithModal = false;
      return;
    }
    if (mine != null &&
        ((mine.topLeft - still.topLeft).distance > 0.5 ||
            (mine.bottomRight - still.bottomRight).distance > 0.5)) {
      _movedWithModal = true;
    }
  }

  @override
  void initState() {
    super.initState();
    CNTabBarRouteObserver.anyModalDepth.addListener(syncHaloContainment);
    CNTabBarRouteObserver.modalAnimating.addListener(syncHaloContainment);
    CNTabBarRouteObserver.modalBoundsPending.addListener(syncHaloContainment);
    CNTabBarRouteObserver.modalFrame.addListener(syncHaloContainment);
    CNTabBarRouteObserver.topModalRect.addListener(syncHaloContainment);
    CNTabBarRouteObserver.routeModalRect.addListener(syncHaloContainment);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.secondaryAnimation;
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
    CNTabBarRouteObserver.modalAnimating.removeListener(syncHaloContainment);
    CNTabBarRouteObserver.modalBoundsPending.removeListener(
      syncHaloContainment,
    );
    CNTabBarRouteObserver.modalFrame.removeListener(syncHaloContainment);
    CNTabBarRouteObserver.topModalRect.removeListener(syncHaloContainment);
    CNTabBarRouteObserver.routeModalRect.removeListener(syncHaloContainment);
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation = null;
    super.dispose();
  }

  void _onRouteAnimationStatus(AnimationStatus _) => syncHaloContainment();

  /// Sends the containment state to the native view if it changed since
  /// the last send.
  void syncHaloContainment() {
    if (!mounted) return;
    _trackMotionWithModal();
    final channel = platformViewChannel;
    if (channel == null) return;
    final contained = isHaloContained;
    if (contained == _sentContainment) return;
    _sentContainment = contained;
    // Fire-and-forget from a listener. `catchError`, not try/catch, because
    // the error (e.g. MissingPluginException while the view is recreated)
    // arrives asynchronously.
    channel
        .invokeMethod<void>('setTransitioning', <String, Object?>{
          'active': contained,
        })
        .catchError((Object _) {});
  }

  /// Sends the current state to a newly created native view.
  void resetHaloContainment() {
    _sentContainment = null;
    syncHaloContainment();
  }
}
