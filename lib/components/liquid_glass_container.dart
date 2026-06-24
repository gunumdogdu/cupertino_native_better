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
/// On iOS 26+ and macOS 26+, this uses native SwiftUI rendering to apply
/// the glass effect. On older versions or other platforms, the child is
/// returned unchanged.
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
  final bool autoHideOnModal;

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with ModalHideMixin<LiquidGlassContainer> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;
  bool? _lastIsDark;

  // Issue #29 halo containment via setTransitioning.
  Animation<double>? _secondaryRouteAnim;

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
    _attachSecondaryRouteAnim();
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
    _secondaryRouteAnim?.removeListener(_onSecondaryRouteAnimChanged);
    _secondaryRouteAnim = null;
    PlatformViewGuard.readyNotifier.removeListener(_onPlatformViewGuardReady);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  void _attachSecondaryRouteAnim() {
    final route = ModalRoute.of(context);
    final newAnim = route?.secondaryAnimation;
    if (identical(newAnim, _secondaryRouteAnim)) return;
    _secondaryRouteAnim?.removeListener(_onSecondaryRouteAnimChanged);
    _secondaryRouteAnim = newAnim;
    _secondaryRouteAnim?.addListener(_onSecondaryRouteAnimChanged);
    _onSecondaryRouteAnimChanged();
  }

  void _onSecondaryRouteAnimChanged() => _pushContainmentIfNeeded();

  void _pushContainmentIfNeeded() {
    final anim = _secondaryRouteAnim;
    final animating =
        anim?.status == AnimationStatus.forward ||
        anim?.status == AnimationStatus.reverse;
    final active = animating;
    final ch = _channel;
    if (ch == null) return;
    ch.invokeMethod('setTransitioning', {'active': active}).catchError((_) {});
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
    final shouldUseNative = isIOSOrMacOS && PlatformVersion.supportsLiquidGlass;

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

    // Convert config to creation params
    final creationParams = <String, dynamic>{
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
          Positioned.fill(child: IgnorePointer(child: platformView)),
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
    _pushContainmentIfNeeded();
  }

  Future<void> _updateConfig() async {
    final channel = _channel;
    if (channel == null) return;

    try {
      await channel.invokeMethod('updateConfig', {
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
