import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../utils/version_detector.dart';
import '../utils/icon_renderer.dart';
import '../utils/theme_helper.dart';
import '../channel/params.dart';
import 'button.dart';

/// A group of buttons that can be rendered together for proper Liquid Glass blending effects.
///
/// This widget renders all buttons in a single SwiftUI view, allowing them
/// to properly blend together when using glassEffectUnionId.
///
/// On iOS 26+ and macOS 26+, this uses native SwiftUI rendering for proper
/// Liquid Glass effects. For older versions, it falls back to Flutter widgets.
class CNGlassButtonGroup extends StatefulWidget {
  /// Creates a group of glass buttons.
  ///
  /// The [buttons] list contains the button widgets.
  /// The [axis] determines whether buttons are laid out horizontally (Axis.horizontal)
  /// or vertically (Axis.vertical).
  /// The [spacing] controls the spacing between buttons in the layout (HStack/VStack).
  /// The [spacingForGlass] controls how Liquid Glass effects blend together.
  /// For proper blending, [spacingForGlass] should be larger than [spacing] so that
  /// glass effects merge when buttons are close together.
  const CNGlassButtonGroup({
    super.key,
    required this.buttons,
    this.axis = Axis.horizontal,
    this.spacing = 8.0,
    this.spacingForGlass = 40.0,
  });

  /// List of buttons.
  final List<CNButton> buttons;

  /// Layout axis for buttons.
  final Axis axis;

  /// Spacing between buttons.
  final double spacing;

  /// Spacing value for Liquid Glass blending (affects how glass effects merge).
  final double spacingForGlass;

  @override
  State<CNGlassButtonGroup> createState() => _CNGlassButtonGroupState();
}

class _CNGlassButtonGroupState extends State<CNGlassButtonGroup> {
  MethodChannel? _channel;
  List<_ButtonSnapshot>? _lastButtonSnapshots;
  Axis? _lastAxis;
  double? _lastSpacing;
  double? _lastSpacingForGlass;

  @override
  void didUpdateWidget(covariant CNGlassButtonGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncButtonsToNativeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeGlass;

    if (!shouldUseNative) {
      // Fallback to Flutter widgets
      return _buildFlutterFallback(context);
    }

    // For iOS 26+ and macOS 26+, use native GlassButtonGroup
    return _buildNativeGroup(context);
  }

  Widget _buildNativeGroup(BuildContext context) {
    const viewType = 'CupertinoNativeGlassButtonGroup';

    // Convert buttons to maps asynchronously if needed
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(
        widget.buttons.map((button) => _buttonToMapAsync(button, context)),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final creationParams = <String, dynamic>{
          'buttons': snapshot.data!,
          'axis': widget.axis == Axis.horizontal ? 'horizontal' : 'vertical',
          'spacing': widget.spacing,
          'spacingForGlass': widget.spacingForGlass,
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

        // For horizontal layout, use fixed height
        if (widget.axis == Axis.horizontal) {
          // Use config minHeight if available, otherwise default to 44.0
          final buttonHeight = widget.buttons.isNotEmpty
              ? (widget.buttons.first.config.minHeight ?? 44.0)
              : 44.0;
          return LayoutBuilder(
            builder: (context, constraints) {
              // If width is unbounded (e.g., in a Row), don't constrain width
              // Otherwise, use full width
              if (constraints.hasBoundedWidth) {
                return ClipRect(
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: buttonHeight,
                    child: platformView,
                  ),
                );
              } else {
                // Unbounded width - let platform view size itself
                // Estimate width based on button count and sizes
                final estimatedWidth =
                    widget.buttons.length * 44.0 +
                    ((widget.buttons.length - 1) * widget.spacing);
                return ClipRect(
                  child: SizedBox(
                    width: estimatedWidth,
                    height: buttonHeight,
                    child: platformView,
                  ),
                );
              }
            },
          );
        } else {
          // For vertical layout, calculate approximate height based on button count
          // Each button is ~44px + spacing
          // Use config minHeight if available, otherwise default to 44.0
          final buttonHeight = widget.buttons.isNotEmpty
              ? (widget.buttons.first.config.minHeight ?? 44.0)
              : 44.0;
          final estimatedHeight =
              (widget.buttons.length * buttonHeight) +
              ((widget.buttons.length - 1) * widget.spacing);
          return ClipRect(
            child: LimitedBox(
              maxHeight: estimatedHeight.clamp(44.0, 400.0),
              child: SizedBox(width: double.infinity, child: platformView),
            ),
          );
        }
      },
    );
  }

  void _onCreated(int id) {
    // Set up method channel to receive button press events and send updates
    final channel = MethodChannel('CupertinoNativeGlassButtonGroup_$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'buttonPressed') {
        final index = call.arguments['index'] as int?;
        if (index != null && index >= 0 && index < widget.buttons.length) {
          final button = widget.buttons[index];
          button.onPressed?.call();
        }
      }
    });
    // Cache initial state
    _lastButtonSnapshots = widget.buttons
        .map((b) => _ButtonSnapshot.fromButton(b))
        .toList();
    _lastAxis = widget.axis;
    _lastSpacing = widget.spacing;
    _lastSpacingForGlass = widget.spacingForGlass;
  }

  Future<void> _syncButtonsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;

    // Create snapshots of current buttons
    final currentSnapshots = widget.buttons
        .map((b) => _ButtonSnapshot.fromButton(b))
        .toList();

    // Check if buttons changed
    final buttonsChanged =
        _lastButtonSnapshots == null ||
        _lastButtonSnapshots!.length != currentSnapshots.length ||
        !_snapshotsEqual(_lastButtonSnapshots!, currentSnapshots);

    // Check if layout parameters changed
    final axisChanged = _lastAxis != widget.axis;
    final spacingChanged = _lastSpacing != widget.spacing;
    final spacingForGlassChanged =
        _lastSpacingForGlass != widget.spacingForGlass;

    // If buttons changed, update all buttons
    if (buttonsChanged) {
      // Check if it's a full replacement or individual changes
      if (_lastButtonSnapshots == null ||
          _lastButtonSnapshots!.length != currentSnapshots.length) {
        // Full replacement - update all buttons
        final buttonsData = await Future.wait(
          widget.buttons.map((button) => _buttonToMapAsync(button, context)),
        );

        await ch.invokeMethod('updateButtons', {'buttons': buttonsData});
      } else {
        // Individual button changes - update only changed buttons
        for (int i = 0; i < currentSnapshots.length; i++) {
          if (i >= _lastButtonSnapshots!.length ||
              !_lastButtonSnapshots![i].equals(currentSnapshots[i])) {
            // This button changed, update it
            final buttonData = await _buttonToMapAsync(
              widget.buttons[i],
              context,
            );
            await ch.invokeMethod('updateButton', {
              'index': i,
              'button': buttonData,
            });
          }
        }
      }
      _lastButtonSnapshots = currentSnapshots;
    }

    // Update layout parameters if changed (these would require full rebuild, but for now just track)
    if (axisChanged || spacingChanged || spacingForGlassChanged) {
      // For layout changes, we'd need to rebuild, but let's just track for now
      _lastAxis = widget.axis;
      _lastSpacing = widget.spacing;
      _lastSpacingForGlass = widget.spacingForGlass;
    }
  }

  bool _snapshotsEqual(List<_ButtonSnapshot> a, List<_ButtonSnapshot> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!a[i].equals(b[i])) return false;
    }
    return true;
  }

  Widget _buildFlutterFallback(BuildContext context) {
    // Just return the buttons directly - they're already CNButton widgets
    final children = widget.buttons.map((button) {
      // Create a new button with shrinkWrap enabled for proper layout in group
      if (button.isIcon) {
        return CNButton.icon(
          icon: button.icon,
          customIcon: button.customIcon,
          imageAsset: button.imageAsset,
          onPressed: button.onPressed,
          enabled: button.enabled,
          tint: button.tint,
          config: CNButtonConfig(
            width: button.config.width,
            style: button.config.style,
            shrinkWrap: true,
            padding: button.config.padding,
            borderRadius: button.config.borderRadius,
            minHeight: button.config.minHeight,
            imagePadding: button.config.imagePadding,
            imagePlacement: button.config.imagePlacement,
            glassEffectUnionId: button.config.glassEffectUnionId,
            glassEffectId: button.config.glassEffectId,
            glassEffectInteractive: button.config.glassEffectInteractive,
          ),
        );
      } else {
        return CNButton(
          label: button.label!,
          customIcon: button.customIcon,
          imageAsset: button.imageAsset,
          onPressed: button.onPressed,
          enabled: button.enabled,
          tint: button.tint,
          config: CNButtonConfig(
            width: button.config.width,
            style: button.config.style,
            shrinkWrap: true,
            padding: button.config.padding,
            borderRadius: button.config.borderRadius,
            minHeight: button.config.minHeight,
            imagePadding: button.config.imagePadding,
            imagePlacement: button.config.imagePlacement,
            glassEffectUnionId: button.config.glassEffectUnionId,
            glassEffectId: button.config.glassEffectId,
            glassEffectInteractive: button.config.glassEffectInteractive,
          ),
        );
      }
    }).toList();

    if (widget.axis == Axis.horizontal) {
      return Wrap(
        spacing: widget.spacing,
        runSpacing: widget.spacing,
        children: children,
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: children
            .map(
              (child) => Padding(
                padding: EdgeInsets.only(bottom: widget.spacing),
                child: child,
              ),
            )
            .toList(),
      );
    }
  }

  Future<Map<String, dynamic>> _buttonToMapAsync(
    CNButton button,
    BuildContext context,
  ) async {
    // Capture context-dependent values before async operations
    // Priority: imageAsset.color > icon.color (for customIcon, icon.color is used)
    final iconColorArgb = button.imageAsset?.color != null
        ? resolveColorToArgb(button.imageAsset!.color, context)
        : (button.icon?.color != null
              ? resolveColorToArgb(button.icon!.color, context)
              : null);
    final tintArgb = button.tint != null
        ? resolveColorToArgb(button.tint, context)
        : null;

    // Helper to convert button to map
    Uint8List? iconBytes;

    // Convert custom icon to bytes if provided
    if (button.customIcon != null) {
      iconBytes = await iconDataToImageBytes(
        button.customIcon!,
        size: button.icon?.size ?? 20.0,
      );
    }

    // Convert image asset to bytes if provided
    Uint8List? imageBytes;
    String? imageFormat;
    String? resolvedAssetPath;
    if (button.imageAsset != null) {
      // Resolve asset path based on device pixel ratio
      resolvedAssetPath = await resolveAssetPathForPixelRatio(
        button.imageAsset!.assetPath,
      );
      imageBytes = button.imageAsset!.imageData;
      // Auto-detect format if not provided (use resolved path)
      imageFormat =
          button.imageAsset!.imageFormat ??
          detectImageFormat(resolvedAssetPath, button.imageAsset!.imageData);
    }

    // Determine icon size - priority: imageAsset > icon > default
    final iconSize = button.imageAsset?.size ?? button.icon?.size ?? 20.0;

    return {
      if (button.label != null) 'label': button.label,
      if (button.icon != null) 'iconName': button.icon!.name,
      if (button.icon != null) 'iconSize': button.icon!.size,
      // Use iconSize from imageAsset if available, otherwise from icon
      if (button.imageAsset != null) 'iconSize': iconSize,
      if (iconColorArgb != null) 'iconColor': iconColorArgb,
      if (iconBytes != null) 'iconBytes': iconBytes,
      if (imageBytes != null) 'imageBytes': imageBytes,
      if (imageFormat != null) 'imageFormat': imageFormat,
      if (button.imageAsset != null && button.imageAsset!.assetPath.isNotEmpty)
        'assetPath': resolvedAssetPath ?? button.imageAsset!.assetPath,
      'enabled': button.enabled,
      if (tintArgb != null) 'tint': tintArgb,
      'minHeight': button.config.minHeight ?? 44.0,
      'style': button.config.style.name,
      if (button.config.glassEffectUnionId != null)
        'glassEffectUnionId': button.config.glassEffectUnionId,
      if (button.config.glassEffectId != null)
        'glassEffectId': button.config.glassEffectId,
      'glassEffectInteractive': button.config.glassEffectInteractive,
      if (button.config.borderRadius != null)
        'borderRadius': button.config.borderRadius,
      if (button.config.padding != null) ...{
        if (button.config.padding!.top != 0.0)
          'paddingTop': button.config.padding!.top,
        if (button.config.padding!.bottom != 0.0)
          'paddingBottom': button.config.padding!.bottom,
        if (button.config.padding!.left != 0.0)
          'paddingLeft': button.config.padding!.left,
        if (button.config.padding!.right != 0.0)
          'paddingRight': button.config.padding!.right,
        // Support horizontal/vertical as convenience
        if (button.config.padding!.left == button.config.padding!.right &&
            button.config.padding!.left != 0.0)
          'paddingHorizontal': button.config.padding!.left,
        if (button.config.padding!.top == button.config.padding!.bottom &&
            button.config.padding!.top != 0.0)
          'paddingVertical': button.config.padding!.top,
      },
      if (button.config.minHeight != null) 'minHeight': button.config.minHeight,
      if (button.config.imagePadding != null)
        'imagePadding': button.config.imagePadding,
    };
  }
}

/// Snapshot of button properties for change detection
class _ButtonSnapshot {
  final String? label;
  final String? iconName;
  final double? iconSize;
  final int? iconColor;
  final String? imageAssetPath;
  final int? imageAssetDataLength;
  final double? imageAssetSize;
  final int? imageAssetColor;
  final int? customIconHash;
  final String style;
  final bool enabled;
  final int? tint;

  _ButtonSnapshot({
    this.label,
    this.iconName,
    this.iconSize,
    this.iconColor,
    this.imageAssetPath,
    this.imageAssetDataLength,
    this.imageAssetSize,
    this.imageAssetColor,
    this.customIconHash,
    required this.style,
    required this.enabled,
    this.tint,
  });

  factory _ButtonSnapshot.fromButton(CNButton button) {
    return _ButtonSnapshot(
      label: button.label,
      iconName: button.icon?.name,
      iconSize: button.icon?.size,
      iconColor: button.icon?.color?.value,
      imageAssetPath: button.imageAsset?.assetPath,
      imageAssetDataLength: button.imageAsset?.imageData?.length,
      imageAssetSize: button.imageAsset?.size,
      imageAssetColor: button.imageAsset?.color?.value,
      customIconHash: button.customIcon?.hashCode,
      style: button.config.style.name,
      enabled: button.enabled,
      tint: button.tint?.value,
    );
  }

  bool equals(_ButtonSnapshot other) {
    return label == other.label &&
        iconName == other.iconName &&
        iconSize == other.iconSize &&
        iconColor == other.iconColor &&
        imageAssetPath == other.imageAssetPath &&
        imageAssetDataLength == other.imageAssetDataLength &&
        imageAssetSize == other.imageAssetSize &&
        imageAssetColor == other.imageAssetColor &&
        customIconHash == other.customIconHash &&
        style == other.style &&
        enabled == other.enabled &&
        tint == other.tint;
  }
}
