import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tab_bar.dart' show CNTabBarRouteObserver;

/// Drop-in wrappers for Flutter's modal sheets that opt the CN-widget
/// family into **position-aware hide-on-modal** behavior.
///
/// **What it does.** When you open a sheet with `CNBottomSheet.show` (or
/// `CNBottomSheet.showCupertino`), a tiny invisible probe is injected into
/// the sheet's builder. The probe captures the sheet body's live global
/// rect each frame and publishes it to [CNTabBarRouteObserver.topModalRect].
/// Any CN-widget on the host page consuming `ModalHideMixin` then only
/// destroys its native PlatformView IF its own rect geometrically
/// intersects that published sheet rect.
///
/// **Why this matters.** Without geometry, every CN-widget on the host
/// page has to assume the worst and destroy itself while any sheet is up
/// (the only way to keep the iOS hybrid-composition bleed bug from
/// triggering — Issue #53). That's fine for sheets that cover most of the
/// screen, but for a small 30% sheet it wastefully destroys widgets in
/// your AppBar that are clearly not behind it. The geometry probe gives
/// each CN-widget a way to ask "am I actually behind the sheet?" and only
/// hide when the answer is yes.
///
/// **API parity.** Every parameter of `showModalBottomSheet` /
/// `showCupertinoSheet` is forwarded unchanged. Your `builder` receives a
/// regular `BuildContext` and can return any Flutter widget tree you
/// want — exactly like the underlying APIs. The probe is invisible: it
/// neither adds UI nor changes layout.
///
/// **Fallback for raw sheets.** If you use raw `showModalBottomSheet`
/// instead of `CNBottomSheet.show`, `topModalRect` stays null and
/// `ModalHideMixin` falls back to destroying every CN-widget on the host
/// page (safe but blunt). Migrate your sheet call sites to `CNBottomSheet`
/// to get position-aware behavior.
class CNBottomSheet {
  CNBottomSheet._();

  /// Position-aware wrapper for [showModalBottomSheet].
  ///
  /// All parameters are forwarded verbatim. Inside the sheet's builder the
  /// only change is that your widget is wrapped in an invisible probe
  /// publishing live geometry — no impact on appearance, layout, or
  /// gestures.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Color? backgroundColor,
    String? barrierLabel,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    Color? barrierColor,
    bool isScrollControlled = false,
    double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool? showDragHandle,
    bool useSafeArea = false,
    RouteSettings? routeSettings,
    AnimationController? transitionAnimationController,
    Offset? anchorPoint,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      barrierLabel: barrierLabel,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: barrierColor,
      isScrollControlled: isScrollControlled,
      scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      routeSettings: routeSettings,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
      builder: (ctx) => CNSheetGeometryProbe(child: builder(ctx)),
    );
  }

  /// Position-aware wrapper for [showCupertinoSheet] — the iOS 26
  /// native-style stacked-card sheet. Same probe injection.
  static Future<T?> showCupertino<T>({
    required BuildContext context,
    required WidgetBuilder pageBuilder,
    bool useNestedNavigation = false,
    bool enableDrag = true,
  }) {
    return showCupertinoSheet<T>(
      context: context,
      useNestedNavigation: useNestedNavigation,
      enableDrag: enableDrag,
      scrollableBuilder: (ctx, scrollController) =>
          CNSheetGeometryProbe(child: pageBuilder(ctx)),
    );
  }

  /// Position-aware wrapper for [showCupertinoModalPopup] — the iOS
  /// action-sheet style popup that animates up from the bottom. Same
  /// probe injection. Even though the popup is short, it's still a
  /// PlatformView container conflict source, so wrapping is worth it.
  static Future<T?> showModalPopup<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    ImageFilter? filter,
    Color? barrierColor,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
    bool semanticsDismissible = false,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      filter: filter,
      barrierColor: barrierColor ?? kCupertinoModalBarrierColor,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      semanticsDismissible: semanticsDismissible,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
      builder: (ctx) => CNSheetGeometryProbe(child: builder(ctx)),
    );
  }
}

/// Invisible probe that lives at the root of a `CNBottomSheet` builder and
/// publishes the sheet body's live global rect every frame.
///
/// Implementation: `findRenderObject` -> `RenderBox.localToGlobal` each
/// frame via a self-rescheduling post-frame callback. Drag-to-dismiss
/// updates the rect within one frame (post-frame schedules at end of
/// layout, fires after paint — the rect published reflects the just-
/// rendered frame; consumers via `ValueNotifier` see it on the next
/// frame). On dispose, clears the published rect to null.
/// Invisible widget that publishes its own global rect to
/// [CNTabBarRouteObserver.topModalRect] each frame, then clears it on
/// dispose. Use this manually inside any sheet/popup builder that
/// [CNBottomSheet] doesn't wrap (e.g. `Scaffold.showBottomSheet` for
/// persistent sheets) to opt that sheet into position-aware host-page
/// CN-widget hiding.
class CNSheetGeometryProbe extends StatefulWidget {
  /// Wraps [child] with a transparent per-frame geometry publisher.
  const CNSheetGeometryProbe({super.key, required this.child});

  /// The sheet body. Untouched — the probe adds no UI, constraints, or
  /// gestures.
  final Widget child;

  @override
  State<CNSheetGeometryProbe> createState() => _CNSheetGeometryProbeState();
}

class _CNSheetGeometryProbeState extends State<CNSheetGeometryProbe> {
  Rect? _lastPublished;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void dispose() {
    // Clear the published rect so host-page CN-widgets re-evaluate (and
    // remount, if appropriate) once the sheet is gone.
    if (CNTabBarRouteObserver.topModalRect.value == _lastPublished) {
      CNTabBarRouteObserver.publishTopModalRect(null);
    }
    super.dispose();
  }

  void _scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _measure();
      // Re-arm for the next frame so we keep tracking drag updates.
      _scheduleMeasure();
    });
  }

  void _measure() {
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    final rect = ro.localToGlobal(Offset.zero) & ro.size;
    if (rect != _lastPublished) {
      _lastPublished = rect;
      CNTabBarRouteObserver.publishTopModalRect(rect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
