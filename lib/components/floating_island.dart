import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/glass_effect.dart';
import '../utils/version_detector.dart';
import 'liquid_glass_container.dart';
import 'tab_bar.dart' show CNTabBarRouteObserver;

/// Position for the floating island.
enum CNFloatingIslandPosition {
  /// Floating at the top of the screen.
  top,

  /// Floating at the bottom of the screen.
  bottom,
}

/// Controller for imperatively managing [CNFloatingIsland] state.
class CNFloatingIslandController {
  MethodChannel? _channel;
  VoidCallback? _onExpandChanged;
  bool _isExpanded = false;

  void _attach(MethodChannel channel) {
    _channel = channel;
  }

  void _detach() {
    _channel = null;
  }

  void _setExpandedState(bool expanded) {
    _isExpanded = expanded;
    _onExpandChanged?.call();
  }

  /// Whether the floating island is currently expanded.
  bool get isExpanded => _isExpanded;

  /// Expands the floating island to show expanded content.
  Future<void> expand({bool animated = true}) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('expand', {'animated': animated});
  }

  /// Collapses the floating island back to compact mode.
  Future<void> collapse({bool animated = true}) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('collapse', {'animated': animated});
  }

  /// Toggles between expanded and collapsed states.
  Future<void> toggle({bool animated = true}) async {
    if (_isExpanded) {
      await collapse(animated: animated);
    } else {
      await expand(animated: animated);
    }
  }

  /// Listen to expand/collapse state changes.
  set onExpandChanged(VoidCallback? callback) {
    _onExpandChanged = callback;
  }
}

/// A floating pill widget inspired by Apple's Dynamic Island.
///
/// The floating island can morph between a compact and expanded state with
/// smooth spring animations. It's perfect for notifications, music controls,
/// or any floating UI element.
///
/// Example:
/// ```dart
/// CNFloatingIsland(
///   collapsed: Row(
///     children: [
///       Icon(Icons.music_note),
///       SizedBox(width: 8),
///       Text('Now Playing'),
///     ],
///   ),
///   expanded: Column(
///     children: [
///       Image.asset('album_art.png'),
///       Text('Song Title'),
///       MusicControls(),
///     ],
///   ),
///   onTap: () => controller.toggle(),
/// )
/// ```
class CNFloatingIsland extends StatefulWidget {
  /// Creates a floating island.
  const CNFloatingIsland({
    super.key,
    required this.collapsed,
    this.expanded,
    this.isExpanded = false,
    this.onTap,
    this.onExpandStateChanged,
    this.position = CNFloatingIslandPosition.top,
    this.collapsedHeight = 44.0,
    this.collapsedWidth,
    this.expandedHeight,
    this.expandedWidth,
    this.cornerRadius,
    this.tint,
    this.animationDuration = const Duration(milliseconds: 400),
    this.springDamping = 0.8,
    this.springResponse = 0.4,
    this.margin = const EdgeInsets.all(16),
    this.controller,
  });

  /// Content shown when collapsed (compact mode).
  final Widget collapsed;

  /// Content shown when expanded. If null, only collapsed content is shown.
  final Widget? expanded;

  /// Whether the island is currently expanded.
  final bool isExpanded;

  /// Called when the island is tapped.
  final VoidCallback? onTap;

  /// Called when the expand state changes.
  final ValueChanged<bool>? onExpandStateChanged;

  /// Position of the floating island.
  final CNFloatingIslandPosition position;

  /// Height when collapsed.
  final double collapsedHeight;

  /// Width when collapsed. If null, uses intrinsic width.
  final double? collapsedWidth;

  /// Height when expanded. If null, uses intrinsic height.
  final double? expandedHeight;

  /// Width when expanded. If null, fills available width minus margins.
  final double? expandedWidth;

  /// Corner radius. Defaults to half of collapsedHeight for pill shape.
  final double? cornerRadius;

  /// Tint color for the glass effect.
  final Color? tint;

  /// Duration of the expand/collapse animation.
  final Duration animationDuration;

  /// Spring damping for the animation (0.0 - 1.0).
  final double springDamping;

  /// Spring response time for the animation.
  final double springResponse;

  /// Margin around the floating island.
  final EdgeInsets margin;

  /// Controller for programmatic control.
  final CNFloatingIslandController? controller;

  @override
  State<CNFloatingIsland> createState() => _CNFloatingIslandState();
}

class _CNFloatingIslandState extends State<CNFloatingIsland>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  CNFloatingIslandController? _internalController;
  bool _isExpanded = false;

  // Issue #29 halo containment state — toggled via setTransitioning on
  // the native channel while the enclosing route is animating or a modal
  // is above.
  Animation<double>? _secondaryRouteAnim;
  bool _modalAbove = false;

  CNFloatingIslandController get _controller =>
      widget.controller ??
      (_internalController ??= CNFloatingIslandController());

  double get _effectiveCornerRadius =>
      widget.cornerRadius ?? widget.collapsedHeight / 2;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _setupAnimations();

    if (_isExpanded) {
      _animationController.value = 1.0;
    }

    CNTabBarRouteObserver.anyModalDepth.addListener(_onAnyModalDepthChanged);
    _onAnyModalDepthChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachSecondaryRouteAnim();
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

  void _onAnyModalDepthChanged() {
    _modalAbove = CNTabBarRouteObserver.anyModalDepth.value > 0;
    _pushContainmentIfNeeded();
  }

  void _pushContainmentIfNeeded() {
    final anim = _secondaryRouteAnim;
    final animating =
        anim?.status == AnimationStatus.forward ||
        anim?.status == AnimationStatus.reverse;
    final active = animating || _modalAbove;
    final ch = _controller._channel;
    if (ch == null) return;
    try {
      ch.invokeMethod('setTransitioning', {'active': active});
    } catch (_) {}
  }

  void _setupAnimations() {
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(CNFloatingIsland oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isExpanded != oldWidget.isExpanded) {
      _setExpanded(widget.isExpanded);
    }

    if (widget.animationDuration != oldWidget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }
  }

  @override
  void dispose() {
    _secondaryRouteAnim?.removeListener(_onSecondaryRouteAnimChanged);
    _secondaryRouteAnim = null;
    CNTabBarRouteObserver.anyModalDepth.removeListener(_onAnyModalDepthChanged);
    _animationController.dispose();
    _controller._detach();
    super.dispose();
  }

  void _onCreationBumpContainment() {
    // Fire once after the platform view is created so the current
    // animating/modal state is reflected on native side from the first
    // frame (before that, the method channel was null).
    _pushContainmentIfNeeded();
  }

  void _onPlatformViewCreated(int id) {
    final ch = MethodChannel('CNFloatingIsland_$id');
    _controller._attach(ch);
    ch.setMethodCallHandler(_onMethodCall);
    _onCreationBumpContainment();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'expanded':
        _setExpanded(true);
        break;
      case 'collapsed':
        _setExpanded(false);
        break;
      case 'tapped':
        widget.onTap?.call();
        break;
    }
    return null;
  }

  void _setExpanded(bool expanded) {
    if (_isExpanded != expanded) {
      setState(() => _isExpanded = expanded);
      _controller._setExpandedState(expanded);
      widget.onExpandStateChanged?.call(expanded);

      if (expanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _onTap() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeGlass;

    if (shouldUseNative) {
      return _buildNativeFloatingIsland(context);
    }

    return _buildFlutterFloatingIsland(context);
  }

  Widget _buildNativeFloatingIsland(BuildContext context) {
    const viewType = 'CNFloatingIsland';
    final creationParams = <String, dynamic>{
      'isExpanded': _isExpanded,
      'position': widget.position.name,
      'collapsedHeight': widget.collapsedHeight,
      'collapsedWidth': widget.collapsedWidth,
      'expandedHeight': widget.expandedHeight,
      'expandedWidth': widget.expandedWidth,
      'cornerRadius': _effectiveCornerRadius,
      'tint': resolveColorToArgb(widget.tint, context),
      'springDamping': widget.springDamping,
      'springResponse': widget.springResponse,
      'isDark': Theme.of(context).brightness == Brightness.dark,
    };

    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        : AppKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          );

    return _buildPositionedContainer(
      child: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: platformView)),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildFlutterFloatingIsland(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth - widget.margin.horizontal;
        final collapsedWidth = widget.collapsedWidth ?? 160;
        final expandedWidth = widget.expandedWidth ?? maxWidth;
        final expandedHeight = widget.expandedHeight ?? 200;

        return AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            final currentWidth =
                collapsedWidth +
                (expandedWidth - collapsedWidth) * _expandAnimation.value;
            final currentHeight =
                widget.collapsedHeight +
                (expandedHeight - widget.collapsedHeight) *
                    _expandAnimation.value;
            final currentRadius =
                _effectiveCornerRadius +
                (24 - _effectiveCornerRadius) * _expandAnimation.value;

            return _buildPositionedContainer(
              child: GestureDetector(
                onTap: _onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: currentWidth,
                  height: currentHeight,
                  child: LiquidGlassContainer(
                    config: LiquidGlassConfig(
                      effect: CNGlassEffect.regular,
                      shape: CNGlassEffectShape.rect,
                      cornerRadius: currentRadius,
                      tint: widget.tint,
                      interactive: true,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(currentRadius),
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPositionedContainer({required Widget child}) {
    return Padding(
      padding: widget.margin,
      child: Align(
        alignment: widget.position == CNFloatingIslandPosition.top
            ? Alignment.topCenter
            : Alignment.bottomCenter,
        child: child,
      ),
    );
  }

  Widget _buildContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _isExpanded && widget.expanded != null
          ? KeyedSubtree(
              key: const ValueKey('expanded'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: widget.expanded!,
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('collapsed'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: widget.collapsed,
              ),
            ),
    );
  }
}
