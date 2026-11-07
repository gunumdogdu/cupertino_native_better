import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../channel/params.dart';
import '../style/glass_effect.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/theme_helper.dart';
import '../utils/platform_view_guard.dart';
import '../utils/version_detector.dart';

/// A container that applies Liquid Glass effects to its child widget.
///
/// On iOS 26+ this uses native SwiftUI rendering to apply the glass effect,
/// on macOS 26+ AppKit's `NSGlassEffectView`, and on macOS 12–15 an
/// `NSVisualEffectView`, the translucent material that preceded Liquid
/// Glass. On older iOS and other platforms, the child is returned unchanged.
///
/// The glass takes the size of [child]: in a parent that stretches its
/// children, such as a [ListView], wrap it in an [Align] to keep it to the
/// child's own width.
class LiquidGlassContainer extends StatefulWidget {
  /// Creates a Liquid Glass container.
  ///
  /// The [child] is the widget to apply the glass effect to.
  /// The [config] contains the glass effect configuration.
  const LiquidGlassContainer({
    super.key,
    required this.child,
    required this.config,
    this.autoHideOnModal = true,
  });

  /// The child widget to apply the glass effect to.
  final Widget child;

  /// The glass effect configuration.
  final LiquidGlassConfig config;

  /// When true (default), destroys the native container's PlatformView while
  /// a modal sheet is presented above this widget's host route. Prevents the
  /// iOS hybrid-composition z-order bleed (Issue #53) where host-page
  /// PlatformView pixels leak through a sheet that also contains a
  /// CN-widget. Requires `CNTabBarRouteObserver()` to be registered in the
  /// app's `navigatorObservers`. No effect on iOS < 26 / non-iOS (fallback
  /// path returns the child unchanged).
  ///
  /// When false, the native view stays while a modal (a dialog, popup or
  /// sheet) is up, and its Liquid Glass glow is clipped to the view's bounds
  /// from the modal's push until its exit animation ends, so no box shows
  /// around it through the modal's barrier (Issue #124).
  final bool autoHideOnModal;

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with
        ModalHideMixin<LiquidGlassContainer>,
        HaloContainmentMixin<LiquidGlassContainer> {
  static const double _macShadowOutset = 12;

  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;
  bool? _lastIsDark;

  // Halo containment (Issues #29 and #124) is driven by
  // HaloContainmentMixin.

  bool get _isDark => ThemeHelper.isDark(context);

  @override
  void initState() {
    super.initState();
    if (!PlatformViewGuard.isReady) {
      PlatformViewGuard.ensureScheduled();
      PlatformViewGuard.readyNotifier.addListener(_onPlatformViewGuardReady);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  @override
  void didUpdateWidget(LiquidGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _updateConfig();
    }
  }

  @override
  void dispose() {
    PlatformViewGuard.readyNotifier.removeListener(_onPlatformViewGuardReady);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  void _onPlatformViewGuardReady() {
    if (!mounted) return;
    PlatformViewGuard.readyNotifier.removeListener(_onPlatformViewGuardReady);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    // Liquid Glass on iOS 26+ and macOS 26+; before macOS 26 the macOS view
    // is the translucent material that preceded it.
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeControls;

    if (!shouldUseNative) {
      return widget.child;
    }

    if (!PlatformViewGuard.isReady) {
      PlatformViewGuard.ensureScheduled();
      return widget.child;
    }

    return _buildNativeContainer(context);
  }

  Widget _buildNativeContainer(BuildContext context) {
    const viewType = 'CupertinoNativeLiquidGlassContainer';

    // Issue #53 fix: when a modal is presented above our host route, destroy
    // the native container's PlatformView so it's removed from the shared
    // iOS PlatformView container — otherwise its glass-effect background
    // bleeds through the sheet's scrim. Size unknown (this container is
    // sized by its child), so leave height/width null; the resulting
    // SizedBox collapses to zero and the child still renders on top via
    // the Stack below.
    final hidden = maybeHiddenPlaceholder();
    if (hidden != null) {
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [hidden, widget.child],
      );
    }

    // AppKit draws the glass's shadow outside its shape, and a platform view
    // is clipped to its bounds. On macOS the view is larger than the child by
    // this much on each side, and the glass inset by as much, so the shadow
    // that outlines light glass on a light background stays visible.
    final outset = defaultTargetPlatform == TargetPlatform.macOS
        ? _macShadowOutset
        : 0.0;

    // Convert config to creation params
    final creationParams = <String, dynamic>{
      if (outset > 0) 'inset': outset,
      'effect': widget.config.effect.name,
      'shape': widget.config.shape.name,
      if (widget.config.cornerRadius != null)
        'cornerRadius': widget.config.cornerRadius,
      if (widget.config.tint != null)
        'tint': resolveColorToArgb(widget.config.tint!, context),
      'interactive': widget.config.interactive,
      'isDark': ThemeHelper.isDark(context),
    };

    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          )
        : AppKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          );

    // Use a Stack where the child determines the size
    // The platform view fills the child's bounds exactly
    // StackFit.passthrough sizes the Stack to match the non-positioned child
    // This allows parent widgets to control alignment via Center, Align, etc.
    return wrapWithModalInteractionGuard(
      Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          // Glass effect background from native view - sized to match child
          // Wrap in IgnorePointer so the platform view never intercepts touches
          Positioned(
            left: -outset,
            top: -outset,
            right: -outset,
            bottom: -outset,
            child: IgnorePointer(child: platformView),
          ),
          // Child content rendered on top - determines the size
          // This will size the Stack, and Positioned.fill will match it
          widget.child,
        ],
      ),
    );
  }

  void _onCreated(int id) {
    _channel = MethodChannel('CupertinoNativeLiquidGlassContainer_$id');
    _channel!.setMethodCallHandler((call) async {
      // Handle any method calls from native side if needed
      return null;
    });
    _lastIsDark = _isDark;
    resetHaloContainment();
  }

  Future<void> _updateConfig() async {
    final channel = _channel;
    if (channel == null) return;

    try {
      await channel.invokeMethod('updateConfig', {
        if (defaultTargetPlatform == TargetPlatform.macOS)
          'inset': _macShadowOutset,
        'effect': widget.config.effect.name,
        'shape': widget.config.shape.name,
        if (widget.config.cornerRadius != null)
          'cornerRadius': widget.config.cornerRadius,
        if (widget.config.tint != null)
          'tint': resolveColorToArgb(widget.config.tint!, context),
        'interactive': widget.config.interactive,
        'isDark': _isDark,
      });
    } catch (e) {
      // Ignore errors - view might not be ready yet
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;

    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      _lastIsDark = isDark;
      // Trigger a view refresh to pick up the new system appearance
      await _updateConfig();
    }
  }
}
