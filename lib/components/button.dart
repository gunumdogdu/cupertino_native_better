/// Native Cupertino button component with Liquid Glass support.
///
/// This library provides [CNButton], a Flutter widget that renders native
/// iOS/macOS buttons with full support for Liquid Glass effects on iOS 26+.
///
/// {@category Components}
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/button_style.dart';
import '../style/image_placement.dart';
import '../style/sf_symbol.dart';
import '../utils/icon_renderer.dart';
import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';
import 'icon.dart';

/// Configuration for CNButton with default values.
class CNButtonConfig {
  /// Padding for button content.
  /// If null, uses default EdgeInsets(top: 8.0, leading: 12.0, bottom: 8.0, trailing: 12.0).
  final EdgeInsets? padding;

  /// Border radius for button corners.
  /// If null, uses capsule shape (always round).
  final double? borderRadius;

  /// Minimum height for the button.
  final double? minHeight;

  /// Padding between image and text (spacing in HStack).
  final double? imagePadding;

  /// Image placement relative to text when both are present.
  final CNImagePlacement imagePlacement;

  /// Visual style to apply.
  final CNButtonStyle style;

  /// Fixed width used in icon/round mode.
  final double? width;

  /// If true, sizes the control to its intrinsic width.
  final bool shrinkWrap;

  /// Optional ID for glass effect union.
  ///
  /// When multiple buttons share the same `glassEffectUnionId`, they will
  /// be combined into a single unified Liquid Glass effect. This is useful
  /// for creating grouped button effects that appear as one cohesive shape.
  ///
  /// Only applies on iOS 26+ and macOS 26+ when using glass styles.
  final String? glassEffectUnionId;

  /// Optional ID for glass effect morphing transitions.
  ///
  /// When a button with a `glassEffectId` appears or disappears within a
  /// glass effect container, it will morph into/out of other buttons with
  /// the same ID or nearby buttons. This enables smooth transitions.
  ///
  /// Only applies on iOS 26+ and macOS 26+ when using glass styles.
  final String? glassEffectId;

  /// Whether to make the glass effect interactive.
  ///
  /// Interactive glass effects respond to touch and pointer interactions
  /// in real time, providing the same responsive reactions that glass
  /// provides to standard buttons.
  ///
  /// Only applies on iOS 26+ and macOS 26+ when using glass styles.
  final bool glassEffectInteractive;

  /// Maximum number of lines for button text.
  ///
  /// Defaults to 1 to prevent text wrapping. Set to null for unlimited lines.
  /// When limited, text will be truncated with ellipsis if too long.
  final int? maxLines;

  /// Size for custom icons (when using [customIcon]).
  ///
  /// If null, defaults to 20.0 points.
  /// This only affects custom icons from IconData (CupertinoIcons, Icons, etc.).
  /// For SF Symbols, use [CNSymbol.size]. For image assets, use [CNImageAsset.size].
  final double? customIconSize;

  /// Whether the button responds to user interaction.
  ///
  /// When false, the button will not be tappable or respond to touches,
  /// but will maintain its normal visual appearance (no opacity change).
  /// This is different from [CNButton.enabled] which also applies
  /// the system's disabled visual styling.
  ///
  /// Defaults to true.
  final bool interaction;

  /// Creates a configuration for [CNButton].
  const CNButtonConfig({
    this.padding,
    this.borderRadius,
    this.minHeight,
    this.imagePadding,
    this.imagePlacement = CNImagePlacement.leading,
    this.style = CNButtonStyle.glass,
    this.width,
    this.shrinkWrap = false,
    this.glassEffectUnionId,
    this.glassEffectId,
    this.glassEffectInteractive = true,
    this.maxLines = 1,
    this.customIconSize,
    this.interaction = true,
  });
}

/// A Cupertino-native push button.
///
/// Embeds a native UIButton/NSButton for authentic visuals and behavior on
/// iOS and macOS. Falls back to [CupertinoButton] on other platforms.
///
/// All buttons are round by default. Use [config] to customize appearance.
class CNButton extends StatefulWidget {
  /// Creates a text button variant of [CNButton].
  ///
  /// Can optionally include an [icon] to create a button with both text and icon.
  const CNButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.enabled = true,
    this.tint,
    this.customIcon,
    this.imageAsset,
    this.config = const CNButtonConfig(),
  }) : badgeCount = null,
       super();

  /// Creates a round, icon-only variant of [CNButton].
  ///
  /// When padding, width, and minHeight are not provided in [config],
  /// the button will be automatically sized to be circular based on the icon size.
  ///
  /// At least one of [icon], [customIcon], or [imageAsset] must be provided.
  ///
  /// Optionally, a [badgeCount] can be provided to display a notification badge
  /// on the button (displayed as "99+" for counts > 99).
  const CNButton.icon({
    super.key,
    this.icon,
    this.customIcon,
    this.imageAsset,
    this.onPressed,
    this.enabled = true,
    this.tint,
    this.badgeCount,
    this.config = const CNButtonConfig(style: CNButtonStyle.glass),
  }) : label = null,
       assert(
         icon != null || customIcon != null || imageAsset != null,
         'At least one of icon, customIcon, or imageAsset must be provided',
       ),
       super();

  /// Button text (null in icon-only mode).
  final String? label; // null in icon-only mode
  /// Optional button icon (SF Symbol).
  /// Can be used together with [label] to create a button with both text and icon.
  /// Priority: [imageAsset] > [customIcon] > [icon]
  final CNSymbol? icon;

  /// Optional custom icon from CupertinoIcons, Icons, or any IconData.
  /// If provided, this takes precedence over [icon] but not [imageAsset].
  final IconData? customIcon;

  /// Optional image asset (SVG, PNG, etc.) for the button icon.
  /// If provided, this takes precedence over [icon] and [customIcon].
  final CNImageAsset? imageAsset;

  /// Callback when pressed.
  final VoidCallback? onPressed;

  /// Whether the control is interactive and tappable.
  final bool enabled;

  /// Accent/tint color.
  final Color? tint;

  /// Optional badge count to display on icon buttons.
  ///
  /// Displays a notification badge with the count on the top-right corner
  /// of the button. Counts > 99 are displayed as "99+".
  /// Only applicable to icon-only buttons (CNButton.icon).
  final int? badgeCount;

  /// Button configuration.
  final CNButtonConfig config;

  /// Whether this instance is configured as the icon variant.
  bool get isIcon => icon != null || customIcon != null || imageAsset != null;

  /// Whether the button is round (always true).
  bool get round => true;

  @override
  State<CNButton> createState() => _CNButtonState();
}

class _CNButtonState extends State<CNButton> {
  MethodChannel? _channel;
  bool? _lastIsDark;
  int? _lastTint;
  String? _lastTitle;
  String? _lastIconName;
  double? _lastIconSize;
  int? _lastIconColor;
  double? _intrinsicWidth;
  double? _intrinsicHeight;
  CNButtonStyle? _lastStyle;
  CNImagePlacement? _lastImagePlacement;
  double? _lastImagePadding;
  EdgeInsets? _lastPadding;
  String? _lastImageAssetPath;
  Uint8List? _lastImageAssetData;
  IconData? _lastCustomIcon;
  int? _lastBadgeCount;
  bool? _lastInteraction;
  Offset? _downPosition;
  bool _pressed = false;

  bool get _isDark => ThemeHelper.isDark(context);

  Color? get _effectiveTint =>
      widget.tint ?? ThemeHelper.getPrimaryColor(context);

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CNButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
    _syncPropsToNativeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    // Check if we should use native platform view
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeGlass;

    // Fallback to Flutter implementation for non-iOS/macOS or iOS/macOS < 26
    if (!shouldUseNative) {
      // For non-iOS/macOS, use Material design fallback
      if (!isIOSOrMacOS) {
        return _buildMaterialFallback(context);
      }

      // For iOS/macOS < 26, use Cupertino widgets
      return _buildCupertinoFallback(context);
    }

    // Priority: imageAsset > customIcon > icon

    // Handle image asset (highest priority)
    if (widget.imageAsset != null) {
      return FutureBuilder<String>(
        future: resolveAssetPathForPixelRatio(widget.imageAsset!.assetPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            final defaultHeight = widget.config.minHeight ?? 44.0;
            return SizedBox(
              height: defaultHeight,
              width: widget.config.width ?? defaultHeight,
            );
          }
          // Create a new CNImageAsset with resolved path
          final resolvedImageAsset = CNImageAsset(
            snapshot.data!,
            size: widget.imageAsset!.size,
            color: widget.imageAsset!.color,
            imageFormat: widget.imageAsset!.imageFormat,
            imageData: widget.imageAsset!.imageData,
            mode: widget.imageAsset!.mode,
            gradient: widget.imageAsset!.gradient,
          );
          return _buildNativeButton(context, imageAsset: resolvedImageAsset);
        },
      );
    }

    // Handle custom icon (medium priority)
    if (widget.customIcon != null) {
      final customIconSize = widget.config.customIconSize ?? 20.0;
      return FutureBuilder<Uint8List?>(
        future: iconDataToImageBytes(widget.customIcon!, size: customIconSize),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            final defaultHeight = widget.config.minHeight ?? 44.0;
            return SizedBox(
              height: defaultHeight,
              width: widget.config.width ?? defaultHeight,
            );
          }
          return _buildNativeButton(context, customIconBytes: snapshot.data);
        },
      );
    }

    // Handle SF Symbol (lowest priority)
    return _buildNativeButton(context, customIconBytes: null);
  }

  Widget _buildNativeButton(
    BuildContext context, {
    Uint8List? customIconBytes,
    CNImageAsset? imageAsset,
  }) {
    const viewType = 'CupertinoNativeButton';

    // Determine which source to use and build parameters accordingly
    String iconName = '';
    Uint8List? imageData;
    String? imageFormat;
    String? assetPath;
    double iconSize = 20.0;
    Color? iconColor;
    CNSymbolRenderingMode? iconMode;
    bool? iconGradient;
    List<Color>? paletteColors;

    if (imageAsset != null) {
      // Image asset takes precedence
      // Asset path is already resolved by FutureBuilder
      assetPath = imageAsset.assetPath;
      imageData = imageAsset.imageData;
      // Auto-detect format if not provided
      imageFormat =
          imageAsset.imageFormat ??
          detectImageFormat(imageAsset.assetPath, imageAsset.imageData);
      iconSize = imageAsset.size;
      iconColor = imageAsset.color;
      iconMode = imageAsset.mode;
      iconGradient = imageAsset.gradient;
    } else if (customIconBytes != null) {
      // Custom icon bytes
      imageData = customIconBytes;
      imageFormat = 'png'; // IconData is rendered as PNG
      iconSize = widget.config.customIconSize ?? 20.0;
      iconColor = widget.icon?.color;
      iconMode = widget.icon?.mode;
      iconGradient = widget.icon?.gradient;
      paletteColors = widget.icon?.paletteColors;
    } else if (widget.icon != null) {
      // SF Symbol
      iconName = widget.icon!.name;
      iconSize = widget.icon!.size;
      iconColor = widget.icon!.color;
      iconMode = widget.icon!.mode;
      iconGradient = widget.icon!.gradient;
      paletteColors = widget.icon!.paletteColors;
    }

    // Calculate padding for icon buttons when not provided
    // Apple HIG specifies minimum touch target of 44×44 points
    const double kMinimumTouchTarget = 44.0;
    final isIconButton = widget.isIcon && widget.label == null;
    EdgeInsets? effectivePadding = widget.config.padding;
    if (isIconButton &&
        effectivePadding == null &&
        widget.config.width == null &&
        widget.config.minHeight == null) {
      // Calculate padding to make button circular: iconSize * 0.5 on each side
      // Ensure minimum size of 44 points per Apple HIG
      final calculatedSize = iconSize + (iconSize * 0.5) * 2;
      final finalSize = calculatedSize.clamp(
        kMinimumTouchTarget,
        double.infinity,
      );
      // Adjust padding to maintain circular shape while respecting minimum size
      final calculatedPadding = (finalSize - iconSize) / 2;
      effectivePadding = EdgeInsets.all(calculatedPadding);
    }

    final creationParams = <String, dynamic>{
      if (widget.label != null) 'buttonTitle': widget.label,
      if (customIconBytes != null) 'buttonCustomIconBytes': customIconBytes,
      if (imageAsset != null) ...{
        if (assetPath != null) 'buttonAssetPath': assetPath,
        if (imageData != null) 'buttonImageData': imageData,
        if (imageFormat != null) 'buttonImageFormat': imageFormat,
      },
      if (iconName.isNotEmpty) 'buttonIconName': iconName,
      'buttonIconSize': iconSize,
      if (iconColor != null)
        'buttonIconColor': resolveColorToArgb(iconColor, context),
      if (iconMode != null) 'buttonIconRenderingMode': iconMode.name,
      if (paletteColors != null)
        'buttonIconPaletteColors': paletteColors
            .map((c) => resolveColorToArgb(c, context))
            .toList(),
      if (iconGradient != null) 'buttonIconGradientEnabled': iconGradient,
      'round': true, // Always round
      'buttonStyle': widget.config.style.name,
      'enabled': (widget.enabled && widget.onPressed != null),
      'isDark': _isDark,
      'style': encodeStyle(context, tint: _effectiveTint),
      'imagePlacement': widget.config.imagePlacement.name,
      if (widget.config.imagePadding != null)
        'imagePadding': widget.config.imagePadding,
      if (effectivePadding != null) ...{
        if (effectivePadding.top != 0.0) 'paddingTop': effectivePadding.top,
        if (effectivePadding.bottom != 0.0)
          'paddingBottom': effectivePadding.bottom,
        if (effectivePadding.left != 0.0) 'paddingLeft': effectivePadding.left,
        if (effectivePadding.right != 0.0)
          'paddingRight': effectivePadding.right,
        // Support horizontal/vertical as convenience
        if (effectivePadding.left == effectivePadding.right &&
            effectivePadding.left != 0.0)
          'paddingHorizontal': effectivePadding.left,
        if (effectivePadding.top == effectivePadding.bottom &&
            effectivePadding.top != 0.0)
          'paddingVertical': effectivePadding.top,
      },
      if (widget.config.borderRadius != null)
        'borderRadius': widget.config.borderRadius,
      if (widget.config.minHeight != null) 'minHeight': widget.config.minHeight,
      if (widget.config.glassEffectUnionId != null)
        'glassEffectUnionId': widget.config.glassEffectUnionId,
      if (widget.config.glassEffectId != null)
        'glassEffectId': widget.config.glassEffectId,
      'glassEffectInteractive': widget.config.glassEffectInteractive,
      if (widget.badgeCount != null) 'badgeCount': widget.badgeCount,
      'interaction': widget.config.interaction,
    };

    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              // Forward taps to native; let Flutter keep drags for scrolling.
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            },
          )
        : AppKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            },
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.hasBoundedWidth;
        final preferIntrinsic = widget.config.shrinkWrap || !hasBoundedWidth;
        double? width;
        // For icon-only buttons, use fixed width/height
        // For buttons with label (with or without icon), use intrinsic width
        final isIconButton = widget.isIcon && widget.label == null;

        // Calculate circular dimensions for icon buttons when padding/width/minHeight not provided
        // Apple HIG specifies minimum touch target of 44×44 points
        const double kMinimumTouchTarget = 44.0;
        double? calculatedSize;
        if (isIconButton &&
            widget.config.padding == null &&
            widget.config.width == null &&
            widget.config.minHeight == null) {
          // Get icon size
          double iconSize = 20.0;
          if (imageAsset != null) {
            iconSize = imageAsset.size;
          } else if (widget.icon != null) {
            iconSize = widget.icon!.size;
          } else if (widget.customIcon != null) {
            iconSize = widget.config.customIconSize ?? 20.0;
          }
          // Calculate circular size: icon size + padding on all sides
          // Use a padding of iconSize * 0.5 on each side for a nice circular appearance
          // Ensure minimum size of 44 points per Apple HIG
          calculatedSize = (iconSize + (iconSize * 0.5) * 2).clamp(
            kMinimumTouchTarget,
            double.infinity,
          );
        }

        final defaultHeight = widget.config.minHeight ?? calculatedSize ?? 44.0;
        if (isIconButton) {
          width = widget.config.width ?? calculatedSize ?? defaultHeight;
        } else if (preferIntrinsic) {
          width = _intrinsicWidth ?? 80.0;
        }
        // Use intrinsic height when image is top/bottom to prevent cropping
        final needsDynamicHeight =
            widget.imageAsset != null ||
            widget.customIcon != null ||
            widget.icon != null;
        final isVerticalPlacement =
            widget.config.imagePlacement == CNImagePlacement.top ||
            widget.config.imagePlacement == CNImagePlacement.bottom;
        final height =
            (needsDynamicHeight &&
                isVerticalPlacement &&
                _intrinsicHeight != null)
            ? _intrinsicHeight!
            : defaultHeight;
        final buttonWidget = Listener(
          onPointerDown: (e) {
            if (!widget.config.interaction) return;
            _downPosition = e.position;
            _setPressed(true);
          },
          onPointerMove: (e) {
            if (!widget.config.interaction) return;
            final start = _downPosition;
            if (start != null && _pressed) {
              final moved = (e.position - start).distance;
              if (moved > kTouchSlop) {
                _setPressed(false);
              }
            }
          },
          onPointerUp: (_) {
            if (!widget.config.interaction) return;
            _setPressed(false);
            _downPosition = null;
          },
          onPointerCancel: (_) {
            if (!widget.config.interaction) return;
            _setPressed(false);
            _downPosition = null;
          },
          child: ClipRect(
            child: SizedBox(height: height, width: width, child: platformView),
          ),
        );

        // Wrap in IgnorePointer when interaction is disabled to absorb all touches
        if (!widget.config.interaction) {
          return IgnorePointer(
            ignoring: true,
            child: buttonWidget,
          );
        }

        return buttonWidget;
      },
    );
  }

  void _onCreated(int id) {
    final ch = MethodChannel('CupertinoNativeButton_$id');
    _channel = ch;
    ch.setMethodCallHandler(_onMethodCall);
    // Clear previous intrinsic dimensions when view is recreated
    _intrinsicWidth = null;
    _intrinsicHeight = null;
    _lastTint = resolveColorToArgb(_effectiveTint, context);
    _lastIsDark = _isDark;
    _lastTitle = widget.label;
    _lastIconName = widget.icon?.name;
    _lastIconSize = widget.icon?.size;
    _lastIconColor = resolveColorToArgb(widget.icon?.color, context);
    _lastStyle = widget.config.style;
    _lastImagePlacement = widget.config.imagePlacement;
    _lastImagePadding = widget.config.imagePadding;
    _lastPadding = widget.config.padding;
    _lastImageAssetPath = widget.imageAsset?.assetPath;
    _lastImageAssetData = widget.imageAsset?.imageData;
    _lastCustomIcon = widget.customIcon;
    _lastBadgeCount = widget.badgeCount;
    _lastInteraction = widget.config.interaction;
    // Always request intrinsic size to get both width and height
    // Use a small delay to ensure native view has finished layout
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted && _channel != null) {
        _requestIntrinsicSize();
      }
    });
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'pressed':
        if (widget.enabled && widget.config.interaction && widget.onPressed != null) {
          widget.onPressed!();
        }
        break;
    }
    return null;
  }

  Future<void> _requestIntrinsicSize() async {
    final ch = _channel;
    if (ch == null) return;
    try {
      final size = await ch.invokeMethod<Map>('getIntrinsicSize');
      final w = (size?['width'] as num?)?.toDouble();
      final h = (size?['height'] as num?)?.toDouble();
      if (mounted) {
        setState(() {
          if (w != null) _intrinsicWidth = w;
          if (h != null) _intrinsicHeight = h;
        });
      }
    } catch (_) {}
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    // Capture all context-derived values before any async operations
    final tint = resolveColorToArgb(_effectiveTint, context);
    final preIconName = widget.icon?.name;
    final preIconSize = widget.icon?.size;
    final preIconColor = resolveColorToArgb(widget.icon?.color, context);
    final preImageAssetColor = resolveColorToArgb(
      widget.imageAsset?.color,
      context,
    );

    if (_lastTint != tint && tint != null) {
      await ch.invokeMethod('setStyle', {'tint': tint});
      _lastTint = tint;
    }
    if (_lastStyle != widget.config.style) {
      await ch.invokeMethod('setStyle', {
        'buttonStyle': widget.config.style.name,
      });
      _lastStyle = widget.config.style;
    }
    // Enabled state
    await ch.invokeMethod('setEnabled', {
      'enabled': (widget.enabled && widget.onPressed != null),
    });
    if (_lastTitle != widget.label && widget.label != null) {
      await ch.invokeMethod('setButtonTitle', {'title': widget.label});
      _lastTitle = widget.label;
      _requestIntrinsicSize();
    }

    // Sync imagePlacement
    if (_lastImagePlacement != widget.config.imagePlacement) {
      await ch.invokeMethod('setImagePlacement', {
        'placement': widget.config.imagePlacement.name,
      });
      _lastImagePlacement = widget.config.imagePlacement;
      // Request intrinsic size when placement changes (affects layout)
      _requestIntrinsicSize();
    }

    // Sync imagePadding
    if (_lastImagePadding != widget.config.imagePadding) {
      if (widget.config.imagePadding != null) {
        await ch.invokeMethod('setImagePadding', {
          'padding': widget.config.imagePadding,
        });
      } else {
        await ch.invokeMethod('setImagePadding', null);
      }
      _lastImagePadding = widget.config.imagePadding;
      // Request intrinsic size when padding changes (affects layout)
      _requestIntrinsicSize();
    }

    // Sync padding
    if (_lastPadding != widget.config.padding) {
      // Padding is handled via creationParams, so we need to rebuild the view
      // This is a limitation - in a production app, you might want to handle this differently
      _requestIntrinsicSize();
      _lastPadding = widget.config.padding;
    }

    // Sync icon properties if icon is present (works for both icon-only and label+icon buttons)
    if (widget.icon != null ||
        widget.imageAsset != null ||
        widget.customIcon != null) {
      final iconName = preIconName;
      final iconSize = preIconSize;
      final iconColor = preIconColor;
      final updates = <String, dynamic>{};

      // Check if imageAsset path or data changed
      final imageAssetPathChanged =
          _lastImageAssetPath != widget.imageAsset?.assetPath;
      final imageAssetDataChanged =
          _lastImageAssetData != widget.imageAsset?.imageData;
      final customIconChanged = _lastCustomIcon != widget.customIcon;

      // Check if we switched from one icon type to another
      final hadImageAsset = _lastImageAssetPath != null;
      final hasImageAsset = widget.imageAsset != null;
      final hadCustomIcon = _lastCustomIcon != null;
      final hasCustomIcon = widget.customIcon != null;
      final iconTypeChanged =
          (hadImageAsset != hasImageAsset) || (hadCustomIcon != hasCustomIcon);

      // Handle imageAsset (takes precedence over SF Symbol)
      if (widget.imageAsset != null) {
        // Update if path/data changed OR if we switched from another icon type
        if (imageAssetPathChanged || imageAssetDataChanged || iconTypeChanged) {
          // Resolve asset path based on device pixel ratio
          final resolvedAssetPath = await resolveAssetPathForPixelRatio(
            widget.imageAsset!.assetPath,
          );
          if (!mounted) return;

          updates['buttonAssetPath'] = resolvedAssetPath;
          updates['buttonImageData'] = widget.imageAsset!.imageData;
          // Auto-detect format if not provided (use resolved path)
          updates['buttonImageFormat'] =
              widget.imageAsset!.imageFormat ??
              detectImageFormat(
                resolvedAssetPath,
                widget.imageAsset!.imageData,
              );
          updates['buttonIconSize'] = widget.imageAsset!.size;
          if (widget.imageAsset!.color != null) {
            if (mounted) {
              updates['buttonIconColor'] = resolveColorToArgb(
                widget.imageAsset!.color,
                context,
              );
            }
          }
          if (widget.imageAsset!.mode != null) {
            updates['buttonIconRenderingMode'] = widget.imageAsset!.mode!.name;
          }
          if (widget.imageAsset!.gradient != null) {
            updates['buttonIconGradientEnabled'] = widget.imageAsset!.gradient;
          }
          // Update tracking variables
          _lastImageAssetPath = widget.imageAsset!.assetPath;
          _lastImageAssetData = widget.imageAsset!.imageData;
          _lastCustomIcon = null; // Clear custom icon tracking
        } else {
          // Even if path didn't change, check if other imageAsset properties changed
          final sizeChanged = _lastIconSize != widget.imageAsset!.size;
          final colorChanged = _lastIconColor != preImageAssetColor;

          if (sizeChanged || colorChanged) {
            updates['buttonIconSize'] = widget.imageAsset!.size;
            if (widget.imageAsset!.color != null &&
                preImageAssetColor != null) {
              updates['buttonIconColor'] = preImageAssetColor;
            }
            if (widget.imageAsset!.mode != null) {
              updates['buttonIconRenderingMode'] =
                  widget.imageAsset!.mode!.name;
            }
            if (widget.imageAsset!.gradient != null) {
              updates['buttonIconGradientEnabled'] =
                  widget.imageAsset!.gradient;
            }
            // Always include asset path when updating other properties
            final resolvedAssetPath = await resolveAssetPathForPixelRatio(
              widget.imageAsset!.assetPath,
            );
            if (!mounted) return;

            updates['buttonAssetPath'] = resolvedAssetPath;
            updates['buttonImageData'] = widget.imageAsset!.imageData;
            updates['buttonImageFormat'] =
                widget.imageAsset!.imageFormat ??
                detectImageFormat(
                  resolvedAssetPath,
                  widget.imageAsset!.imageData,
                );
          }
        }
      } else if (widget.customIcon != null) {
        // Handle custom icon - update if changed OR if we switched from another icon type
        if (customIconChanged || iconTypeChanged) {
          // Handle custom icon change - need to render it first
          final customIconSize = widget.config.customIconSize ?? 20.0;
          final customIconBytes = await iconDataToImageBytes(
            widget.customIcon!,
            size: customIconSize,
          );
          if (customIconBytes != null) {
            updates['buttonCustomIconBytes'] = customIconBytes;
            updates['buttonIconSize'] = customIconSize;
            if (widget.icon?.color != null) {
              if (mounted) {
                updates['buttonIconColor'] = resolveColorToArgb(
                  widget.icon!.color,
                  context,
                );
              }
            }
            if (widget.icon?.mode != null) {
              updates['buttonIconRenderingMode'] = widget.icon!.mode!.name;
            }
            if (widget.icon?.paletteColors != null) {
              updates['buttonIconPaletteColors'] = widget.icon!.paletteColors!
                  .map((c) => resolveColorToArgb(c, context))
                  .toList();
            }
            if (widget.icon?.gradient != null) {
              updates['buttonIconGradientEnabled'] = widget.icon!.gradient;
            }
            _lastCustomIcon = widget.customIcon;
            _lastImageAssetPath = null; // Clear imageAsset tracking
            _lastImageAssetData = null;
          }
        }
      } else {
        // Fallback to SF Symbol
        // Check if any SF Symbol properties changed OR if we switched from another icon type
        bool hasChanges = false;

        if (_lastIconName != iconName && iconName != null) {
          hasChanges = true;
          _lastIconName = iconName;
        }
        if (_lastIconSize != iconSize && iconSize != null) {
          hasChanges = true;
          _lastIconSize = iconSize;
        }
        if (_lastIconColor != iconColor && iconColor != null) {
          hasChanges = true;
          _lastIconColor = iconColor;
        }

        // If any property changed OR icon type changed, include the icon source
        if ((hasChanges || iconTypeChanged) && iconName != null) {
          updates['buttonIconName'] = iconName;
          if (iconSize != null) {
            updates['buttonIconSize'] = iconSize;
          }
          if (iconColor != null) {
            updates['buttonIconColor'] = iconColor;
          }
          if (widget.icon?.mode != null) {
            updates['buttonIconRenderingMode'] = widget.icon!.mode!.name;
          }
          if (widget.icon?.paletteColors != null) {
            updates['buttonIconPaletteColors'] = widget.icon!.paletteColors!
                .map((c) => resolveColorToArgb(c, context))
                .toList();
          }
          if (widget.icon?.gradient != null) {
            updates['buttonIconGradientEnabled'] = widget.icon!.gradient;
          }
          // Clear imageAsset and customIcon tracking when using SF Symbol
          if (iconTypeChanged) {
            _lastImageAssetPath = null;
            _lastImageAssetData = null;
            _lastCustomIcon = null;
          }
        }
      }

      if (updates.isNotEmpty) {
        await ch.invokeMethod('setButtonIcon', updates);
        // Request intrinsic size when icon changes (affects layout)
        _requestIntrinsicSize();
      }
    }

    // Sync badge count
    if (_lastBadgeCount != widget.badgeCount) {
      await ch.invokeMethod('setBadgeCount', {'badgeCount': widget.badgeCount});
      _lastBadgeCount = widget.badgeCount;
    }

    // Sync interaction state
    if (_lastInteraction != widget.config.interaction) {
      await ch.invokeMethod(
        'setInteraction',
        {'interaction': widget.config.interaction},
      );
      _lastInteraction = widget.config.interaction;
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    // Capture context-derived values before any awaits
    final isDark = _isDark;
    final tint = resolveColorToArgb(_effectiveTint, context);
    if (_lastIsDark != isDark) {
      await ch.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }
    // Also propagate theme-driven tint changes (e.g., accent color changes)
    if (_lastTint != tint && tint != null) {
      await ch.invokeMethod('setStyle', {'tint': tint});
      _lastTint = tint;
    }
  }

  Future<void> _setPressed(bool pressed) async {
    final ch = _channel;
    if (ch == null) return;
    if (_pressed == pressed) return;
    _pressed = pressed;
    try {
      await ch.invokeMethod('setPressed', {'pressed': pressed});
    } catch (_) {}
  }

  Widget _buildCupertinoFallback(BuildContext context) {
    // For iOS/macOS < 26, use CupertinoButton with appropriate styling
    Widget? iconWidget;
    if (widget.imageAsset != null) {
      // Use CNIcon to properly render the image asset
      iconWidget = CNIcon(
        imageAsset: widget.imageAsset,
        size: widget.imageAsset!.size,
      );
    } else if (widget.customIcon != null) {
      iconWidget = Icon(
        widget.customIcon,
        size: widget.config.customIconSize ?? 20.0,
      );
    } else if (widget.icon != null) {
      // Use CNIcon to properly render SF Symbols (instead of placeholder)
      iconWidget = CNIcon(
        symbol: widget.icon,
        size: widget.icon!.size,
        color: widget.icon!.color,
      );
    }

    Widget child;
    // Check for icon-only button (has icon but no label)
    final isIconOnlyButton = widget.isIcon && widget.label == null;
    if (isIconOnlyButton) {
      child = iconWidget ?? const SizedBox.shrink();
    } else {
      if (iconWidget != null && widget.label != null) {
        // Handle image placement
        switch (widget.config.imagePlacement) {
          case CNImagePlacement.leading:
            child = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                if (widget.config.imagePadding != null)
                  SizedBox(width: widget.config.imagePadding!),
                Text(
                  widget.label ?? '',
                  maxLines: widget.config.maxLines,
                  overflow: widget.config.maxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                ),
              ],
            );
            break;
          case CNImagePlacement.trailing:
            child = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label ?? '',
                  maxLines: widget.config.maxLines,
                  overflow: widget.config.maxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                ),
                if (widget.config.imagePadding != null)
                  SizedBox(width: widget.config.imagePadding!),
                iconWidget,
              ],
            );
            break;
          case CNImagePlacement.top:
            child = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                if (widget.config.imagePadding != null)
                  SizedBox(height: widget.config.imagePadding!),
                Text(
                  widget.label ?? '',
                  maxLines: widget.config.maxLines,
                  overflow: widget.config.maxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                ),
              ],
            );
            break;
          case CNImagePlacement.bottom:
            child = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label ?? '',
                  maxLines: widget.config.maxLines,
                  overflow: widget.config.maxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                ),
                if (widget.config.imagePadding != null)
                  SizedBox(height: widget.config.imagePadding!),
                iconWidget,
              ],
            );
            break;
        }
      } else {
        child = Text(
          widget.label ?? '',
          maxLines: widget.config.maxLines,
          overflow: widget.config.maxLines != null
              ? TextOverflow.ellipsis
              : null,
        );
      }
    }

    // Calculate circular dimensions for icon buttons when padding/width/minHeight not provided
    // Apple HIG specifies minimum touch target of 44×44 points
    const double kMinimumTouchTarget = 44.0;
    double? calculatedSize;
    EdgeInsets? effectivePadding = widget.config.padding;
    if (widget.isIcon &&
        widget.label == null &&
        effectivePadding == null &&
        widget.config.width == null &&
        widget.config.minHeight == null) {
      // Get icon size
      double iconSize = 20.0;
      if (widget.imageAsset != null) {
        iconSize = widget.imageAsset!.size;
      } else if (widget.icon != null) {
        iconSize = widget.icon!.size;
      } else if (widget.customIcon != null) {
        iconSize = widget.config.customIconSize ?? 20.0;
      }
      // Calculate circular size: icon size + padding on all sides
      // Ensure minimum size of 44 points per Apple HIG
      final calculatedSizeValue = iconSize + (iconSize * 0.5) * 2;
      calculatedSize = calculatedSizeValue.clamp(
        kMinimumTouchTarget,
        double.infinity,
      );
      // Adjust padding to maintain circular shape while respecting minimum size
      final calculatedPadding = (calculatedSize - iconSize) / 2;
      effectivePadding = EdgeInsets.all(calculatedPadding);
    }

    final defaultHeight = widget.config.minHeight ?? calculatedSize ?? 44.0;
    final buttonWidth = widget.isIcon
        ? (widget.config.width ?? calculatedSize ?? defaultHeight)
        : null;
    final buttonPadding = widget.isIcon
        ? (effectivePadding ?? const EdgeInsets.all(8))
        : (widget.config.padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8));
    final borderRadius = widget.config.borderRadius ?? defaultHeight / 2;

    final button = SizedBox(
      height: defaultHeight,
      width: buttonWidth,
      child: CupertinoButton(
        // ignore: deprecated_member_use
        minSize:
            0, // Disable built-in minimum size to prevent conflicts with SizedBox
        padding: buttonPadding,
        borderRadius: BorderRadius.circular(borderRadius),
        pressedOpacity: 0.4, // Explicit press feedback
        color: _getCupertinoButtonColor(context),
        onPressed: (widget.enabled && widget.config.interaction && widget.onPressed != null)
            ? widget.onPressed
            : null,
        child: child,
      ),
    );

    // Wrap in IgnorePointer when interaction is disabled
    Widget result = button;
    if (!widget.config.interaction) {
      result = IgnorePointer(ignoring: true, child: button);
    }

    // Add badge if badgeCount is provided
    if (widget.badgeCount != null && widget.badgeCount! > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [result, _buildBadge(widget.badgeCount!)],
      );
    }

    return result;
  }

  Widget _buildMaterialFallback(BuildContext context) {
    // For non-iOS/macOS, use Material design buttons
    Widget? iconWidget;
    if (widget.imageAsset != null) {
      // Use CNIcon for proper rendering
      iconWidget = CNIcon(
        imageAsset: widget.imageAsset,
        size: widget.imageAsset!.size,
      );
    } else if (widget.customIcon != null) {
      iconWidget = Icon(
        widget.customIcon,
        size: widget.config.customIconSize ?? 20.0,
      );
    } else if (widget.icon != null) {
      // Use CNIcon for SF Symbols
      iconWidget = CNIcon(
        symbol: widget.icon,
        size: widget.icon!.size,
        color: widget.icon!.color,
      );
    }

    Widget child;
    // Check for icon-only button (has icon but no label)
    final isIconOnlyButton = widget.isIcon && widget.label == null;
    if (isIconOnlyButton) {
      child = iconWidget ?? const SizedBox.shrink();
    } else {
      if (iconWidget != null && widget.label != null) {
        switch (widget.config.imagePlacement) {
          case CNImagePlacement.leading:
            child = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                if (widget.config.imagePadding != null)
                  SizedBox(width: widget.config.imagePadding!),
                Text(
                  widget.label ?? '',
                  maxLines: widget.config.maxLines,
                  overflow: widget.config.maxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                ),
              ],
            );
            break;
          case CNImagePlacement.trailing:
            child = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label ?? '',
                  maxLines: widget.config.maxLines,
                  overflow: widget.config.maxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                ),
                if (widget.config.imagePadding != null)
                  SizedBox(width: widget.config.imagePadding!),
                iconWidget,
              ],
            );
            break;
          case CNImagePlacement.top:
            child = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                if (widget.config.imagePadding != null)
                  SizedBox(height: widget.config.imagePadding!),
                Text(
                  widget.label ?? '',
                  maxLines: widget.config.maxLines,
                  overflow: widget.config.maxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                ),
              ],
            );
            break;
          case CNImagePlacement.bottom:
            child = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label ?? '',
                  maxLines: widget.config.maxLines,
                  overflow: widget.config.maxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                ),
                if (widget.config.imagePadding != null)
                  SizedBox(height: widget.config.imagePadding!),
                iconWidget,
              ],
            );
            break;
        }
      } else {
        child = Text(
          widget.label ?? '',
          maxLines: widget.config.maxLines,
          overflow: widget.config.maxLines != null
              ? TextOverflow.ellipsis
              : null,
        );
      }
    }

    // Import material package - need to check if it's available
    // For now, use a simple Container with ElevatedButton-like appearance
    // Calculate circular dimensions for icon buttons when padding/width/minHeight not provided
    // Apple HIG specifies minimum touch target of 44×44 points
    const double kMinimumTouchTarget = 44.0;
    double? calculatedSize;
    EdgeInsets? effectivePadding = widget.config.padding;
    if (widget.isIcon &&
        widget.label == null &&
        effectivePadding == null &&
        widget.config.width == null &&
        widget.config.minHeight == null) {
      // Get icon size
      double iconSize = 20.0;
      if (widget.imageAsset != null) {
        iconSize = widget.imageAsset!.size;
      } else if (widget.icon != null) {
        iconSize = widget.icon!.size;
      } else if (widget.customIcon != null) {
        iconSize = widget.config.customIconSize ?? 20.0;
      }
      // Calculate circular size: icon size + padding on all sides
      // Ensure minimum size of 44 points per Apple HIG
      final calculatedSizeValue = iconSize + (iconSize * 0.5) * 2;
      calculatedSize = calculatedSizeValue.clamp(
        kMinimumTouchTarget,
        double.infinity,
      );
      // Adjust padding to maintain circular shape while respecting minimum size
      final calculatedPadding = (calculatedSize - iconSize) / 2;
      effectivePadding = EdgeInsets.all(calculatedPadding);
    }

    final defaultHeight = widget.config.minHeight ?? calculatedSize ?? 44.0;
    final button = SizedBox(
      height: defaultHeight,
      width: widget.isIcon
          ? (widget.config.width ?? calculatedSize ?? defaultHeight)
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (widget.enabled && widget.config.interaction && widget.onPressed != null)
              ? widget.onPressed
              : null,
          borderRadius: BorderRadius.circular(defaultHeight / 2),
          child: Container(
            padding: widget.isIcon
                ? (effectivePadding ?? const EdgeInsets.all(4))
                : (widget.config.padding ??
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
            decoration: BoxDecoration(
              color: _getMaterialButtonColor(context),
              borderRadius: BorderRadius.circular(defaultHeight / 2),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );

    // Wrap in IgnorePointer when interaction is disabled
    Widget result = button;
    if (!widget.config.interaction) {
      result = IgnorePointer(ignoring: true, child: button);
    }

    // Add badge if badgeCount is provided
    if (widget.badgeCount != null && widget.badgeCount! > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [result, _buildBadge(widget.badgeCount!)],
      );
    }

    return result;
  }

  Color? _getCupertinoButtonColor(BuildContext context) {
    switch (widget.config.style) {
      case CNButtonStyle.filled:
      case CNButtonStyle.borderedProminent:
      case CNButtonStyle.prominentGlass:
        return _effectiveTint;
      case CNButtonStyle.glass:
        // For iOS < 26, approximate glass with tinted appearance
        return _effectiveTint?.withValues(alpha: 0.1);
      default:
        return null;
    }
  }

  Color? _getMaterialButtonColor(BuildContext context) {
    switch (widget.config.style) {
      case CNButtonStyle.filled:
      case CNButtonStyle.borderedProminent:
      case CNButtonStyle.prominentGlass:
        return _effectiveTint ?? Theme.of(context).primaryColor;
      case CNButtonStyle.glass:
        return Theme.of(context).primaryColor.withValues(alpha: 0.1);
      default:
        return Colors.transparent;
    }
  }

  Widget _buildBadge(int count) {
    // Format badge text (show "99+" for counts > 99)
    final badgeText = count > 99 ? '99+' : count.toString();

    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed,
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Center(
          child: Text(
            badgeText,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
