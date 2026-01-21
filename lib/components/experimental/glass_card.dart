import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../style/glass_effect.dart';
import '../../style/spotlight_mode.dart';
import '../../channel/params.dart';
import '../../utils/version_detector.dart';
import '../liquid_glass_container.dart';

/// EXPERIMENTAL: A card widget with Liquid Glass effects, breathing animation,
/// and spotlight effect that follows touch or responds to device tilt.
///
/// This widget is currently experimental and API may change.
class CNGlassCard extends StatefulWidget {
  /// Creates a glass card.
  const CNGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.cornerRadius = 16.0,
    this.tint,
    this.interactive = true,
    this.breathing = false,
    this.spotlight = CNSpotlightMode.none,
    this.spotlightColor,
    this.spotlightIntensity = 0.3,
    this.spotlightRadius = 0.5,
  });

  /// Child widget to display inside the card.
  final Widget child;

  /// Padding around the child.
  final EdgeInsetsGeometry padding;

  /// Corner radius of the card.
  final double cornerRadius;

  /// Tint color for the glass effect.
  final Color? tint;

  /// Whether the card responds to touches.
  final bool interactive;

  /// Whether to enable a subtle breathing animation (glow).
  final bool breathing;

  /// Spotlight mode for dynamic lighting effect.
  ///
  /// - [CNSpotlightMode.none]: No spotlight effect
  /// - [CNSpotlightMode.touch]: Spotlight follows touch/pointer position
  /// - [CNSpotlightMode.gyroscope]: Spotlight responds to device tilt (iOS only)
  /// - [CNSpotlightMode.both]: Combines touch and gyroscope inputs
  final CNSpotlightMode spotlight;

  /// Color for the spotlight effect. Defaults to [tint] or white.
  final Color? spotlightColor;

  /// Intensity of the spotlight effect (0.0 - 1.0). Defaults to 0.3.
  final double spotlightIntensity;

  /// Radius of the spotlight gradient (0.0 - 1.0). Defaults to 0.5.
  final double spotlightRadius;

  @override
  State<CNGlassCard> createState() => _CNGlassCardState();
}

class _CNGlassCardState extends State<CNGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Spotlight state
  Offset? _touchPosition;
  Offset _gyroOffset = Offset.zero;
  Size _cardSize = Size.zero;
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.breathing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CNGlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breathing != oldWidget.breathing) {
      if (widget.breathing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }

    // Update spotlight mode on native side if changed
    if (widget.spotlight != oldWidget.spotlight) {
      _updateSpotlightMode();
    }
  }

  void _onPlatformViewCreated(int id) {
    final ch = MethodChannel('CNGlassCard_$id');
    _channel = ch;
    ch.setMethodCallHandler(_onMethodCall);
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'gyroUpdate':
        // Receive gyroscope updates from native side
        final args = call.arguments as Map<dynamic, dynamic>;
        final x = (args['x'] as num?)?.toDouble() ?? 0.0;
        final y = (args['y'] as num?)?.toDouble() ?? 0.0;
        if (mounted) {
          setState(() {
            _gyroOffset = Offset(x, y);
          });
        }
        break;
    }
    return null;
  }

  void _updateSpotlightMode() {
    _channel?.invokeMethod('setSpotlightMode', {'mode': widget.spotlight.name});
  }

  void _updateTouchPosition(Offset localPosition) {
    if (widget.spotlight == CNSpotlightMode.touch ||
        widget.spotlight == CNSpotlightMode.both) {
      setState(() {
        _touchPosition = localPosition;
      });

      // Send to native for iOS 26+ glass effect integration
      _channel?.invokeMethod('updateSpotlight', {
        'x': localPosition.dx / _cardSize.width,
        'y': localPosition.dy / _cardSize.height,
      });
    }
  }

  void _clearTouchPosition() {
    if (widget.spotlight == CNSpotlightMode.touch) {
      setState(() {
        _touchPosition = null;
      });
      _channel?.invokeMethod('clearSpotlight', null);
    }
  }

  Offset? get _effectiveSpotlightPosition {
    if (widget.spotlight == CNSpotlightMode.none) return null;

    if (widget.spotlight == CNSpotlightMode.both) {
      // Combine touch and gyro
      if (_touchPosition != null) {
        return Offset(
          _touchPosition!.dx + _gyroOffset.dx * 20,
          _touchPosition!.dy + _gyroOffset.dy * 20,
        );
      }
      // Fall back to center + gyro
      return Offset(
        _cardSize.width / 2 + _gyroOffset.dx * 50,
        _cardSize.height / 2 + _gyroOffset.dy * 50,
      );
    }

    if (widget.spotlight == CNSpotlightMode.touch) {
      return _touchPosition;
    }

    if (widget.spotlight == CNSpotlightMode.gyroscope) {
      return Offset(
        _cardSize.width / 2 + _gyroOffset.dx * 50,
        _cardSize.height / 2 + _gyroOffset.dy * 50,
      );
    }

    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeGlass;

    // Use native implementation for iOS 26+ with spotlight support
    if (shouldUseNative && widget.spotlight != CNSpotlightMode.none) {
      return _buildNativeGlassCard(context);
    }

    // Use Flutter implementation
    return _buildFlutterGlassCard(context);
  }

  Widget _buildNativeGlassCard(BuildContext context) {
    final effectiveSpotlightColor =
        widget.spotlightColor ?? widget.tint ?? Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) => _updateTouchPosition(details.localPosition),
          onPanUpdate: (details) => _updateTouchPosition(details.localPosition),
          onPanEnd: (_) => _clearTouchPosition(),
          child: MouseRegion(
            onHover: (event) => _updateTouchPosition(event.localPosition),
            onExit: (_) => _clearTouchPosition(),
            child: _buildCardWithMeasurement(
              child: _buildNativePlatformView(context, effectiveSpotlightColor),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNativePlatformView(BuildContext context, Color spotlightColor) {
    const viewType = 'CNGlassCardWithSpotlight';
    final creationParams = <String, dynamic>{
      'cornerRadius': widget.cornerRadius,
      'tint': resolveColorToArgb(widget.tint, context),
      'interactive': widget.interactive,
      'breathing': widget.breathing,
      'spotlightMode': widget.spotlight.name,
      'spotlightColor': resolveColorToArgb(spotlightColor, context),
      'spotlightIntensity': widget.spotlightIntensity,
      'spotlightRadius': widget.spotlightRadius,
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

    // Use StackFit.passthrough so the Stack sizes to the child content
    // This allows parent widgets to control alignment via Center, Align, etc.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: IgnorePointer(child: platformView)),
        Padding(padding: widget.padding, child: widget.child),
      ],
    );
  }

  Widget _buildCardWithMeasurement({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final newSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (_cardSize != newSize) {
              setState(() {
                _cardSize = newSize;
              });
            }
          }
        });
        return child;
      },
    );
  }

  Widget _buildFlutterGlassCard(BuildContext context) {
    // Use LiquidGlassContainer for the base effect
    final card = LiquidGlassContainer(
      config: LiquidGlassConfig(
        effect: CNGlassEffect.regular,
        shape: CNGlassEffectShape.rect,
        cornerRadius: widget.cornerRadius,
        tint: widget.tint,
        interactive: widget.interactive,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    // Wrap with spotlight if enabled
    Widget result = card;
    if (widget.spotlight != CNSpotlightMode.none) {
      result = _buildFlutterSpotlight(card);
    }

    // Add breathing effect if enabled
    if (widget.breathing) {
      result = _buildBreathingEffect(result);
    }

    return result;
  }

  Widget _buildFlutterSpotlight(Widget card) {
    final effectiveColor = widget.spotlightColor ?? widget.tint ?? Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final newSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (_cardSize != newSize) {
              setState(() {
                _cardSize = newSize;
              });
            }
          }
        });

        return GestureDetector(
          onPanStart: (details) => _updateTouchPosition(details.localPosition),
          onPanUpdate: (details) => _updateTouchPosition(details.localPosition),
          onPanEnd: (_) => _clearTouchPosition(),
          child: MouseRegion(
            onHover: (event) => _updateTouchPosition(event.localPosition),
            onExit: (_) => _clearTouchPosition(),
            child: Stack(
              children: [
                card,
                if (_effectiveSpotlightPosition != null && _cardSize.width > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.cornerRadius,
                          ),
                          gradient: RadialGradient(
                            center: Alignment(
                              (_effectiveSpotlightPosition!.dx /
                                          _cardSize.width) *
                                      2 -
                                  1,
                              (_effectiveSpotlightPosition!.dy /
                                          _cardSize.height) *
                                      2 -
                                  1,
                            ),
                            radius: widget.spotlightRadius,
                            colors: [
                              effectiveColor.withValues(
                                alpha: widget.spotlightIntensity,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreathingEffect(Widget child) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, animChild) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.cornerRadius),
            boxShadow: [
              BoxShadow(
                color: (widget.tint ?? CupertinoColors.systemBlue).withValues(
                  alpha: 0.3 * _animation.value,
                ),
                blurRadius: 20 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
          child: animChild,
        );
      },
      child: child,
    );
  }
}
