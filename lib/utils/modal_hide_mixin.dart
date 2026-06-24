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
/// is **position-aware** when the sheet publishes its geometric rect via
/// [CNTabBarRouteObserver.topModalRect].
///
/// **How geometry is published.** Sheets opened with `CNBottomSheet.show`
/// inject a small probe widget into the sheet builder; the probe writes
/// the sheet's live global rect to `topModalRect` every frame (covers
/// drag-to-dismiss correctly). For sheets opened with raw
/// `showModalBottomSheet` / `showCupertinoSheet` (no probe), the rect
/// stays `null` and the mixin falls back to "destroy everything" — the
/// safe behavior that still kills the bleed.
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
  }

  @override
  void dispose() {
    CNTabBarRouteObserver.anyModalDepth.removeListener(_onModalStateChanged);
    CNTabBarRouteObserver.topModalRect.removeListener(_onModalStateChanged);
    super.dispose();
  }

  /// True iff a modal newer than this widget's host route is up AND either
  /// the sheet's geometric rect isn't known (safe fallback: hide) OR this
  /// widget's own rect intersects the sheet's published rect.
  bool _computeShouldHide() {
    final depth = CNTabBarRouteObserver.anyModalDepth.value;
    if (depth <= _mountDepth) return false;
    final sheetRect = CNTabBarRouteObserver.topModalRect.value;
    if (sheetRect == null) {
      // No probe published — sheet geometry unknown. Fall back to the safe
      // "destroy everything" behavior so the bleed bug stays fixed.
      return true;
    }
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      // Can't measure (early frame, detached) — be safe, destroy.
      return true;
    }
    final myRect = ro.localToGlobal(Offset.zero) & ro.size;
    return myRect.overlaps(sheetRect);
  }

  void _onModalStateChanged() {
    if (!mounted) return;
    // Schedule on post-frame so [_computeShouldHide] sees the latest layout.
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
