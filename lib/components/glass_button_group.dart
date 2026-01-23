import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../utils/version_detector.dart';
import '../utils/icon_renderer.dart';
import '../utils/theme_helper.dart';
import '../channel/params.dart';
import '../style/button_data.dart';
import '../style/image_placement.dart';
import 'button.dart';

/// A group of buttons that can be rendered together for proper Liquid Glass blending effects.
///
/// This widget renders all buttons in a single SwiftUI view, allowing them
/// to properly blend together when using glassEffectUnionId.
///
/// On iOS 26+ and macOS 26+, this uses native SwiftUI rendering for proper
/// Liquid Glass effects. For older versions, it falls back to Flutter widgets.
///
/// **Breaking Change in v1.1.0**: This widget now accepts [CNButtonData] models
/// instead of [CNButton] widgets. Use the [CNGlassButtonGroup.fromWidgets]
/// constructor for backward compatibility.
///
/// Example:
/// ```dart
/// CNGlassButtonGroup(
///   buttons: [
///     CNButtonData.icon(
///       icon: CNSFSymbol.house,
///       onPressed: () => print('Home'),
///     ),
///     CNButtonData.icon(
///       icon: CNSFSymbol.gear,
///       onPressed: () => print('Settings'),
///     ),
///     CNButtonData(
///       label: 'More',
///       icon: CNSFSymbol.ellipsis,
///       onPressed: () => print('More'),
///     ),
///   ],
///   axis: Axis.horizontal,
///   spacing: 8.0,
/// )
/// ```
class CNGlassButtonGroup extends StatefulWidget {
  /// Creates a group of glass buttons using data models.
  ///
  /// The [buttons] list contains button data models.
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
  }) : _buttonWidgets = null;

  /// Creates a group from existing CNButton widgets.
  ///
  /// This constructor provides backward compatibility with the pre-1.1.0 API.
  /// Prefer using the default constructor with [CNButtonData] for new code.
  ///
  /// @Deprecated('Use the default constructor with CNButtonData instead')
  const CNGlassButtonGroup.fromWidgets({
    super.key,
    required List<CNButton> buttonWidgets,
    this.axis = Axis.horizontal,
    this.spacing = 8.0,
    this.spacingForGlass = 40.0,
  }) : buttons = const [],
       _buttonWidgets = buttonWidgets;

  /// List of button data models.
  final List<CNButtonData> buttons;

  /// Internal: List of button widgets (for backward compatibility).
  final List<CNButton>? _buttonWidgets;

  /// Layout axis for buttons.
  final Axis axis;

  /// Spacing between buttons.
  final double spacing;

  /// Spacing value for Liquid Glass blending (affects how glass effects merge).
  final double spacingForGlass;

  /// Returns the effective button count (from data or widgets).
  int get _effectiveButtonCount =>
      _buttonWidgets != null ? _buttonWidgets.length : buttons.length;

  @override
  State<CNGlassButtonGroup> createState() => _CNGlassButtonGroupState();
}

class _CNGlassButtonGroupState extends State<CNGlassButtonGroup> {
  MethodChannel? _channel;
  List<_ButtonSnapshot>? _lastButtonSnapshots;
  Axis? _lastAxis;
  double? _lastSpacing;
  double? _lastSpacingForGlass;

  /// Whether we're using widget mode (backward compatibility).
  bool get _usingWidgets => widget._buttonWidgets != null;

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
      return _buildFlutterFallback(context);
    }

    return _buildNativeGroup(context);
  }

  Widget _buildNativeGroup(BuildContext context) {
    const viewType = 'CupertinoNativeGlassButtonGroup';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usingWidgets
          ? Future.wait(
              widget._buttonWidgets!.map(
                (button) => _buttonWidgetToMapAsync(button, context),
              ),
            )
          : Future.wait(
              widget.buttons.map(
                (button) => _buttonDataToMapAsync(button, context),
              ),
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

        if (widget.axis == Axis.horizontal) {
          final buttonHeight = _getEffectiveMinHeight();
          // Add 3px to height for badge overflow at top (badge is 18px tall, positioned at y=0)
          // Add 6px to width for badge overflow at right (badge extends 6px beyond last button)
          // Native side offsets buttons by 3px vertically to keep badge within bounds
          final totalHeight = buttonHeight + 3.0;
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.hasBoundedWidth) {
                return ClipRect(
                  child: SizedBox(
                    width:
                        constraints.maxWidth +
                        6.0, // Add 6px for badge overflow on right
                    height: totalHeight,
                    child: platformView,
                  ),
                );
              } else {
                final estimatedWidth =
                    widget._effectiveButtonCount * 44.0 +
                    ((widget._effectiveButtonCount - 1) * widget.spacing) +
                    6.0; // Add 6px for badge overflow on right
                return ClipRect(
                  child: SizedBox(
                    width: estimatedWidth,
                    height: totalHeight,
                    child: platformView,
                  ),
                );
              }
            },
          );
        } else {
          final buttonHeight = _getEffectiveMinHeight();
          final estimatedHeight =
              (widget._effectiveButtonCount * buttonHeight) +
              ((widget._effectiveButtonCount - 1) * widget.spacing) +
              3.0; // Add 3px for badge overflow at top
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

  double _getEffectiveMinHeight() {
    if (_usingWidgets && widget._buttonWidgets!.isNotEmpty) {
      return widget._buttonWidgets!.first.config.minHeight ?? 44.0;
    } else if (widget.buttons.isNotEmpty) {
      return widget.buttons.first.config.minHeight ?? 44.0;
    }
    return 44.0;
  }

  void _onCreated(int id) {
    final channel = MethodChannel('CupertinoNativeGlassButtonGroup_$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'buttonPressed') {
        final index = call.arguments['index'] as int?;
        if (index != null && index >= 0) {
          if (_usingWidgets && index < widget._buttonWidgets!.length) {
            widget._buttonWidgets![index].onPressed?.call();
          } else if (!_usingWidgets && index < widget.buttons.length) {
            widget.buttons[index].onPressed?.call();
          }
        }
      }
    });

    _lastButtonSnapshots = _usingWidgets
        ? widget._buttonWidgets!
              .map((b) => _ButtonSnapshot.fromButtonWidget(b))
              .toList()
        : widget.buttons.map((b) => _ButtonSnapshot.fromButtonData(b)).toList();
    _lastAxis = widget.axis;
    _lastSpacing = widget.spacing;
    _lastSpacingForGlass = widget.spacingForGlass;
  }

  Future<void> _syncButtonsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;

    // Capture context before any async operations
    final capturedContext = context;

    final currentSnapshots = _usingWidgets
        ? widget._buttonWidgets!
              .map((b) => _ButtonSnapshot.fromButtonWidget(b))
              .toList()
        : widget.buttons.map((b) => _ButtonSnapshot.fromButtonData(b)).toList();

    final buttonsChanged =
        _lastButtonSnapshots == null ||
        _lastButtonSnapshots!.length != currentSnapshots.length ||
        !_snapshotsEqual(_lastButtonSnapshots!, currentSnapshots);

    final axisChanged = _lastAxis != widget.axis;
    final spacingChanged = _lastSpacing != widget.spacing;
    final spacingForGlassChanged =
        _lastSpacingForGlass != widget.spacingForGlass;

    if (buttonsChanged) {
      if (_lastButtonSnapshots == null ||
          _lastButtonSnapshots!.length != currentSnapshots.length) {
        final buttonsData = _usingWidgets
            ? await Future.wait(
                widget._buttonWidgets!.map(
                  (button) => _buttonWidgetToMapAsync(button, capturedContext),
                ),
              )
            : await Future.wait(
                widget.buttons.map(
                  (button) => _buttonDataToMapAsync(button, capturedContext),
                ),
              );

        await ch.invokeMethod('updateButtons', {'buttons': buttonsData});
      } else {
        for (int i = 0; i < currentSnapshots.length; i++) {
          if (i >= _lastButtonSnapshots!.length ||
              !_lastButtonSnapshots![i].equals(currentSnapshots[i])) {
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            final buttonData = _usingWidgets
                // ignore: use_build_context_synchronously
                ? await _buttonWidgetToMapAsync(
                    widget._buttonWidgets![i],
                    // ignore: use_build_context_synchronously
                    capturedContext,
                  )
                // ignore: use_build_context_synchronously
                : await _buttonDataToMapAsync(
                    widget.buttons[i],
                    // ignore: use_build_context_synchronously
                    capturedContext,
                  );
            if (!mounted) return;
            await ch.invokeMethod('updateButton', {
              'index': i,
              'button': buttonData,
            });
          }
        }
      }
      _lastButtonSnapshots = currentSnapshots;
    }

    if (axisChanged || spacingChanged || spacingForGlassChanged) {
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
    final children = _usingWidgets
        ? _buildWidgetChildren()
        : _buildDataChildren();

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

  List<Widget> _buildWidgetChildren() {
    return widget._buttonWidgets!.map((button) {
      if (button.isIcon) {
        return CNButton.icon(
          icon: button.icon,
          customIcon: button.customIcon,
          imageAsset: button.imageAsset,
          onPressed: button.onPressed,
          enabled: button.enabled,
          tint: button.tint,
          badgeCount: button.badgeCount,
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
            interaction: button.config.interaction,
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
            interaction: button.config.interaction,
          ),
        );
      }
    }).toList();
  }

  List<Widget> _buildDataChildren() {
    return widget.buttons.map((data) {
      if (data.isIcon) {
        return CNButton.icon(
          icon: data.icon,
          customIcon: data.customIcon,
          imageAsset: data.imageAsset,
          onPressed: data.onPressed,
          enabled: data.enabled,
          tint: data.tint,
          badgeCount: data.badgeCount,
          config: CNButtonConfig(
            width: data.config.width,
            style: data.config.style,
            shrinkWrap: true,
            padding: data.config.padding,
            borderRadius: data.config.borderRadius,
            minHeight: data.config.minHeight,
            imagePadding: data.config.imagePadding,
            imagePlacement:
                data.config.imagePlacement ?? CNImagePlacement.leading,
            glassEffectUnionId: data.config.glassEffectUnionId,
            glassEffectId: data.config.glassEffectId,
            glassEffectInteractive: data.config.glassEffectInteractive,
            interaction: data.config.interaction,
          ),
        );
      } else {
        return CNButton(
          label: data.label!,
          icon: data.icon,
          customIcon: data.customIcon,
          imageAsset: data.imageAsset,
          onPressed: data.onPressed,
          enabled: data.enabled,
          tint: data.tint,
          config: CNButtonConfig(
            width: data.config.width,
            style: data.config.style,
            shrinkWrap: true,
            padding: data.config.padding,
            borderRadius: data.config.borderRadius,
            minHeight: data.config.minHeight,
            imagePadding: data.config.imagePadding,
            imagePlacement:
                data.config.imagePlacement ?? CNImagePlacement.leading,
            glassEffectUnionId: data.config.glassEffectUnionId,
            glassEffectId: data.config.glassEffectId,
            glassEffectInteractive: data.config.glassEffectInteractive,
            interaction: data.config.interaction,
          ),
        );
      }
    }).toList();
  }

  Future<Map<String, dynamic>> _buttonDataToMapAsync(
    CNButtonData button,
    BuildContext context,
  ) async {
    final iconColorArgb = button.imageAsset?.color != null
        ? resolveColorToArgb(button.imageAsset!.color, context)
        : (button.icon?.color != null
              ? resolveColorToArgb(button.icon!.color, context)
              : null);
    final tintArgb = button.tint != null
        ? resolveColorToArgb(button.tint, context)
        : null;

    Uint8List? iconBytes;
    if (button.customIcon != null) {
      iconBytes = await iconDataToImageBytes(
        button.customIcon!,
        size: button.icon?.size ?? 20.0,
      );
    }

    Uint8List? imageBytes;
    String? imageFormat;
    String? resolvedAssetPath;
    if (button.imageAsset != null) {
      resolvedAssetPath = await resolveAssetPathForPixelRatio(
        button.imageAsset!.assetPath,
      );
      imageBytes = button.imageAsset!.imageData;
      imageFormat =
          button.imageAsset!.imageFormat ??
          detectImageFormat(resolvedAssetPath, button.imageAsset!.imageData);
    }

    final iconSize = button.imageAsset?.size ?? button.icon?.size ?? 20.0;

    return {
      if (button.label != null) 'label': button.label,
      if (button.icon != null) 'iconName': button.icon!.name,
      if (button.icon != null) 'iconSize': button.icon!.size,
      if (button.imageAsset != null) 'iconSize': iconSize,
      if (iconColorArgb != null) 'iconColor': iconColorArgb,
      if (iconBytes != null) 'iconBytes': iconBytes,
      if (imageBytes != null) 'imageBytes': imageBytes,
      if (imageFormat != null) 'imageFormat': imageFormat,
      if (button.imageAsset != null && button.imageAsset!.assetPath.isNotEmpty)
        'assetPath': resolvedAssetPath ?? button.imageAsset!.assetPath,
      'enabled': button.enabled,
      if (tintArgb != null) 'tint': tintArgb,
      if (button.badgeCount != null) 'badgeCount': button.badgeCount,
      'minHeight': button.config.minHeight ?? 44.0,
      'style': button.config.style.name,
      if (button.config.glassEffectUnionId != null)
        'glassEffectUnionId': button.config.glassEffectUnionId,
      if (button.config.glassEffectId != null)
        'glassEffectId': button.config.glassEffectId,
      'glassEffectInteractive': button.config.glassEffectInteractive,
      'interaction': button.config.interaction,
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

  Future<Map<String, dynamic>> _buttonWidgetToMapAsync(
    CNButton button,
    BuildContext context,
  ) async {
    final iconColorArgb = button.imageAsset?.color != null
        ? resolveColorToArgb(button.imageAsset!.color, context)
        : (button.icon?.color != null
              ? resolveColorToArgb(button.icon!.color, context)
              : null);
    final tintArgb = button.tint != null
        ? resolveColorToArgb(button.tint, context)
        : null;

    Uint8List? iconBytes;
    if (button.customIcon != null) {
      iconBytes = await iconDataToImageBytes(
        button.customIcon!,
        size: button.icon?.size ?? 20.0,
      );
    }

    Uint8List? imageBytes;
    String? imageFormat;
    String? resolvedAssetPath;
    if (button.imageAsset != null) {
      resolvedAssetPath = await resolveAssetPathForPixelRatio(
        button.imageAsset!.assetPath,
      );
      imageBytes = button.imageAsset!.imageData;
      imageFormat =
          button.imageAsset!.imageFormat ??
          detectImageFormat(resolvedAssetPath, button.imageAsset!.imageData);
    }

    final iconSize = button.imageAsset?.size ?? button.icon?.size ?? 20.0;

    return {
      if (button.label != null) 'label': button.label,
      if (button.icon != null) 'iconName': button.icon!.name,
      if (button.icon != null) 'iconSize': button.icon!.size,
      if (button.imageAsset != null) 'iconSize': iconSize,
      if (iconColorArgb != null) 'iconColor': iconColorArgb,
      if (iconBytes != null) 'iconBytes': iconBytes,
      if (imageBytes != null) 'imageBytes': imageBytes,
      if (imageFormat != null) 'imageFormat': imageFormat,
      if (button.imageAsset != null && button.imageAsset!.assetPath.isNotEmpty)
        'assetPath': resolvedAssetPath ?? button.imageAsset!.assetPath,
      'enabled': button.enabled,
      if (tintArgb != null) 'tint': tintArgb,
      if (button.badgeCount != null) 'badgeCount': button.badgeCount,
      'minHeight': button.config.minHeight ?? 44.0,
      'style': button.config.style.name,
      if (button.config.glassEffectUnionId != null)
        'glassEffectUnionId': button.config.glassEffectUnionId,
      if (button.config.glassEffectId != null)
        'glassEffectId': button.config.glassEffectId,
      'glassEffectInteractive': button.config.glassEffectInteractive,
      'interaction': button.config.interaction,
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
  final bool interaction;
  final int? tint;
  final int? badgeCount;

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
    required this.interaction,
    this.tint,
    this.badgeCount,
  });

  factory _ButtonSnapshot.fromButtonWidget(CNButton button) {
    return _ButtonSnapshot(
      label: button.label,
      iconName: button.icon?.name,
      iconSize: button.icon?.size,
      iconColor: button.icon?.color?.toARGB32(),
      imageAssetPath: button.imageAsset?.assetPath,
      imageAssetDataLength: button.imageAsset?.imageData?.length,
      imageAssetSize: button.imageAsset?.size,
      imageAssetColor: button.imageAsset?.color?.toARGB32(),
      customIconHash: button.customIcon?.hashCode,
      style: button.config.style.name,
      enabled: button.enabled,
      interaction: button.config.interaction,
      tint: button.tint?.toARGB32(),
      badgeCount: button.badgeCount,
    );
  }

  factory _ButtonSnapshot.fromButtonData(CNButtonData button) {
    return _ButtonSnapshot(
      label: button.label,
      iconName: button.icon?.name,
      iconSize: button.icon?.size,
      iconColor: button.icon?.color?.toARGB32(),
      imageAssetPath: button.imageAsset?.assetPath,
      imageAssetDataLength: button.imageAsset?.imageData?.length,
      imageAssetSize: button.imageAsset?.size,
      imageAssetColor: button.imageAsset?.color?.toARGB32(),
      customIconHash: button.customIcon?.hashCode,
      style: button.config.style.name,
      enabled: button.enabled,
      interaction: button.config.interaction,
      tint: button.tint?.toARGB32(),
      badgeCount: button.badgeCount,
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
        interaction == other.interaction &&
        tint == other.tint &&
        badgeCount == other.badgeCount;
  }
}
