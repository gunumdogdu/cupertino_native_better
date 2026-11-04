import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/sf_symbol.dart';
import '../style/symbol_effect.dart';
import '../utils/icon_renderer.dart';
import '../utils/theme_helper.dart';
import '../utils/platform_view_guard.dart';
import '../utils/version_detector.dart';

/// A platform-rendered SF Symbol icon, custom image asset, or IconData.
///
/// Renders an `SFSymbol` on iOS/macOS using native APIs for best fidelity,
/// displays a custom image asset, or renders IconData.
///
/// SF Symbols can animate with Apple's symbol effects: [effect] runs while it
/// is set, [triggeredEffect] plays once each time [effectTrigger] changes, and
/// [replaceTransition] animates a change of [CNSymbol.name]. See
/// [CNSymbolEffect].
class CNIcon extends StatefulWidget {
  /// Creates a platform-rendered SF Symbol icon.
  const CNIcon({
    super.key,
    this.symbol,
    this.imageAsset,
    this.customIcon,
    this.size,
    this.color,
    this.mode,
    this.gradient,
    this.height,
    this.effect,
    this.triggeredEffect,
    this.effectTrigger,
    this.replaceTransition,
  }) : assert(
         symbol != null || imageAsset != null || customIcon != null,
         'At least one of symbol, imageAsset, or customIcon must be provided',
       );

  /// The SF Symbol to render.
  /// Priority: [imageAsset] > [customIcon] > [symbol]
  final CNSymbol? symbol;

  /// Custom image asset (SVG, PNG, etc.) to render.
  /// If provided, this takes precedence over [symbol] and [customIcon].
  final CNImageAsset? imageAsset;

  /// Optional custom icon from CupertinoIcons, Icons, or any IconData.
  /// If provided, this takes precedence over [symbol] but not [imageAsset].
  final IconData? customIcon;

  /// Overrides the symbol's size.
  final double? size;

  /// Overrides the symbol's color for monochrome/hierarchical modes.
  ///
  /// Without one, a monochrome icon takes the theme's label color: black in
  /// a light theme, white in a dark one.
  final Color? color;

  /// Overrides the rendering mode.
  final CNSymbolRenderingMode? mode;

  /// Whether to enable the system gradient when available.
  final bool? gradient;

  /// Optional fixed height; defaults to the icon's size.
  final double? height;

  /// A symbol effect that runs for as long as it is set, such as
  /// `CNSymbolEffect.pulse()` while recording. Set it to null to stop it, or
  /// to another effect to switch.
  ///
  /// Switching between [CNSymbolEffect.drawOff] and [CNSymbolEffect.drawOn]
  /// draws the symbol out and back in.
  ///
  /// Applies to SF Symbols on iOS 17+ and macOS 14+; each effect's own
  /// minimum is listed on [CNSymbolEffectType]. Elsewhere the icon stays
  /// still.
  final CNSymbolEffect? effect;

  /// The effect played once each time [effectTrigger] changes. Defaults to
  /// `CNSymbolEffect.bounce()`.
  ///
  /// [CNSymbolEffect.scale] and [CNSymbolEffect.drawOff] have no one-shot
  /// form and do nothing here; use them as [effect].
  final CNSymbolEffect? triggeredEffect;

  /// Plays [triggeredEffect] once whenever this value changes, compared with
  /// `==`, from one build to the next — for example a counter of new
  /// messages. The value the icon is first built with plays nothing.
  final Object? effectTrigger;

  /// How the icon animates to a new symbol when [CNSymbol.name] changes.
  ///
  /// Null (the default) swaps the symbol without animation. Applies to SF
  /// Symbols on iOS 17+ and macOS 14+.
  final CNSymbolReplaceTransition? replaceTransition;

  @override
  State<CNIcon> createState() => _CNIconState();
}

class _CNIconState extends State<CNIcon> {
  MethodChannel? _channel;
  bool? _lastIsDark;
  String? _lastName;
  double? _lastSize;
  int? _lastColor;
  String? _lastMode;
  bool? _lastGradient;
  CNSymbolEffect? _lastEffect;
  Object? _lastEffectTrigger;
  CNSymbolReplaceTransition? _lastReplaceTransition;

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
    // The default colour and dynamic colours resolve against the theme.
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CNIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void dispose() {
    PlatformViewGuard.readyNotifier.removeListener(_onPlatformViewGuardReady);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewGuardReady() {
    if (!mounted) return;
    PlatformViewGuard.readyNotifier.removeListener(_onPlatformViewGuardReady);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shouldUseNative = PlatformVersion.supportsSFSymbols;

    if (!shouldUseNative) {
      return _buildFlutterIcon(context);
    }

    if (!PlatformViewGuard.isReady) {
      PlatformViewGuard.ensureScheduled();
      if (widget.customIcon != null && widget.imageAsset == null) {
        return _buildFlutterIcon(context);
      }
      // Leave the slot empty: `_buildFlutterIcon`'s circle placeholder shows
      // as a black dot for the guard's debug-only 500 ms on iOS < 26.
      final size =
          widget.size ?? widget.imageAsset?.size ?? widget.symbol?.size ?? 24.0;
      return SizedBox(width: size, height: widget.height ?? size);
    }

    // Priority: imageAsset > customIcon > symbol

    // Handle image asset (highest priority)
    if (widget.imageAsset != null) {
      return FutureBuilder<String>(
        future: resolveAssetPathForPixelRatio(widget.imageAsset!.assetPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            final defaultSize =
                widget.size ?? (widget.imageAsset?.size ?? 24.0);
            return SizedBox(
              width: defaultSize,
              height: widget.height ?? defaultSize,
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
          return _buildNativeIcon(context, imageAsset: resolvedImageAsset);
        },
      );
    }

    // Handle custom icon (medium priority)
    if (widget.customIcon != null) {
      final iconSize = widget.size ?? widget.symbol?.size ?? 24.0;
      return FutureBuilder<Uint8List?>(
        future: iconDataToImageBytes(widget.customIcon!, size: iconSize),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return SizedBox(width: iconSize, height: widget.height ?? iconSize);
          }
          return _buildNativeIcon(context, customIconBytes: snapshot.data);
        },
      );
    }

    // Handle SF Symbol (lowest priority)
    return _buildNativeIcon(context, customIconBytes: null);
  }

  Widget _buildNativeIcon(
    BuildContext context, {
    Uint8List? customIconBytes,
    CNImageAsset? imageAsset,
  }) {
    const viewType = 'CupertinoNativeIcon';

    // Determine which source to use and build parameters accordingly
    String name = '';
    Uint8List? imageData;
    String? imageFormat;
    String? assetPath;
    double size = 24.0;
    Color? color;
    CNSymbolRenderingMode? mode;
    bool? gradient;
    List<Color>? paletteColors;

    if (imageAsset != null) {
      // Image asset takes precedence
      assetPath = imageAsset.assetPath;
      imageData = imageAsset.imageData;
      // Auto-detect format if not provided
      imageFormat =
          imageAsset.imageFormat ??
          detectImageFormat(imageAsset.assetPath, imageAsset.imageData);
      size = widget.size ?? imageAsset.size;
      color = widget.color ?? imageAsset.color;
      mode = widget.mode ?? imageAsset.mode;
      gradient = widget.gradient ?? imageAsset.gradient;
    } else if (customIconBytes != null) {
      // Custom icon bytes
      imageData = customIconBytes;
      imageFormat = 'png'; // IconData is rendered as PNG
      size = widget.size ?? widget.symbol?.size ?? 24.0;
      color = widget.color ?? widget.symbol?.color;
      mode = widget.mode ?? widget.symbol?.mode;
      gradient = widget.gradient ?? widget.symbol?.gradient;
      paletteColors = widget.symbol?.paletteColors;
    } else if (widget.symbol != null) {
      // SF Symbol
      name = widget.symbol!.name;
      size = widget.size ?? widget.symbol!.size;
      color = widget.color ?? widget.symbol!.color;
      mode = widget.mode ?? widget.symbol!.mode;
      gradient = widget.gradient ?? widget.symbol!.gradient;
      paletteColors = widget.symbol!.paletteColors;
    }

    final creationParams = <String, dynamic>{
      'name': name,
      if (assetPath != null) 'assetPath': assetPath,
      if (imageData != null) 'imageData': imageData,
      if (imageFormat != null) 'imageFormat': imageFormat,
      'isDark': _isDark,
      'style': <String, dynamic>{
        'iconSize': size,
        if (_withDefaultColor(resolveColorToArgb(color, context), mode?.name)
            case final argb?)
          'iconColor': argb,
        if (mode != null) 'iconRenderingMode': mode.name,
        if (gradient != null) 'iconGradientEnabled': gradient == true,
        if (paletteColors != null)
          'iconPaletteColors': paletteColors
              .map((c) => resolveColorToArgb(c, context))
              .toList(),
      },
      if (widget.effect != null) 'symbolEffect': widget.effect!.toMap(),
      if (widget.replaceTransition != null)
        'replaceTransition': widget.replaceTransition!.name,
    };

    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: viewType,
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: creationParams,
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        : AppKitView(
            viewType: viewType,
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: creationParams,
            onPlatformViewCreated: _onPlatformViewCreated,
          );

    // Ensure the platform view always has finite constraints
    final fallbackSize =
        widget.size ?? (imageAsset?.size ?? widget.symbol?.size ?? 24.0);
    final h = widget.height ?? fallbackSize;
    final w = fallbackSize;
    // AbsorbPointer keeps the icon's hit area for ancestors but keeps the
    // UIKit view out of the gesture arena, where it would otherwise win the
    // sweep and cancel an enclosing button's tap.
    return ClipRect(
      child: SizedBox(
        width: w,
        height: h,
        child: AbsorbPointer(child: platformView),
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('CupertinoNativeIcon_$id')
      ..setMethodCallHandler(_onMethodCall);
    _cacheCurrentProps();
    _syncBrightnessIfNeeded();
    // No intrinsic measurement needed.
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    return null;
  }

  void _cacheCurrentProps() {
    _lastIsDark = _isDark;
    _lastEffect = widget.effect;
    _lastEffectTrigger = widget.effectTrigger;
    _lastReplaceTransition = widget.replaceTransition;

    // Determine current source and cache accordingly
    if (widget.imageAsset != null) {
      _lastName = widget.imageAsset!.assetPath;
      _lastSize = widget.size ?? widget.imageAsset!.size;
      _lastColor = resolveColorToArgb(
        widget.color ?? widget.imageAsset!.color,
        context,
      );
      _lastMode = (widget.mode ?? widget.imageAsset!.mode)?.name;
      _lastGradient = widget.gradient ?? widget.imageAsset!.gradient;
    } else if (widget.symbol != null) {
      _lastName = widget.symbol!.name;
      _lastSize = widget.size ?? widget.symbol!.size;
      _lastColor = resolveColorToArgb(
        widget.color ?? widget.symbol!.color,
        context,
      );
      _lastMode = (widget.mode ?? widget.symbol!.mode)?.name;
      _lastGradient = widget.gradient ?? widget.symbol!.gradient;
    } else {
      // Custom icon case
      _lastName = '';
      _lastSize = widget.size ?? 24.0;
      _lastColor = resolveColorToArgb(widget.color, context);
      _lastMode = widget.mode?.name;
      _lastGradient = widget.gradient;
    }
    _lastColor = _withDefaultColor(_lastColor, _lastMode);
  }

  /// Without a colour the native view draws the icon black, which a dark
  /// theme hides; use the theme's label colour, as a native button does.
  int? _withDefaultColor(int? argb, String? mode) =>
      argb ??
      (mode == null || mode == CNSymbolRenderingMode.monochrome.name
          ? resolveColorToArgb(CupertinoColors.label, context)
          : null);

  Future<void> _syncPropsToNativeIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;

    // Symbol animation values, read before any await so that overlapping
    // syncs see each change once.
    final effect = widget.effect;
    final effectChanged = _lastEffect != effect;
    _lastEffect = effect;
    final triggered = _lastEffectTrigger != widget.effectTrigger;
    _lastEffectTrigger = widget.effectTrigger;
    final transition = widget.replaceTransition;
    if (_lastReplaceTransition != transition) {
      _lastReplaceTransition = transition;
      // Sent before `setSymbol` so a name change in the same build animates.
      await channel.invokeMethod('setReplaceTransition', {
        'transition': transition?.name,
      });
      if (!mounted) return;
    }

    // Determine current source and resolve values
    String name = '';
    double size = 24.0;
    int? color;
    String? mode;
    bool? gradient;

    if (widget.imageAsset != null) {
      // Resolve asset path based on device pixel ratio
      final resolvedAssetPath = await resolveAssetPathForPixelRatio(
        widget.imageAsset!.assetPath,
      );
      if (!mounted) return;

      name = resolvedAssetPath;
      size = widget.size ?? widget.imageAsset!.size;
      color = resolveColorToArgb(
        widget.color ?? widget.imageAsset!.color,
        context,
      );
      mode = (widget.mode ?? widget.imageAsset!.mode)?.name;
      gradient = widget.gradient ?? widget.imageAsset!.gradient;
    } else if (widget.symbol != null) {
      name = widget.symbol!.name;
      size = widget.size ?? widget.symbol!.size;
      color = resolveColorToArgb(widget.color ?? widget.symbol!.color, context);
      mode = (widget.mode ?? widget.symbol!.mode)?.name;
      gradient = widget.gradient ?? widget.symbol!.gradient;
    } else {
      // Custom icon case
      size = widget.size ?? 24.0;
      color = resolveColorToArgb(widget.color, context);
      mode = widget.mode?.name;
      gradient = widget.gradient;
    }

    color = _withDefaultColor(color, mode);

    if (_lastName != name) {
      final symbolArgs = <String, dynamic>{'name': name};

      // Add imageAsset properties if using imageAsset
      if (widget.imageAsset != null) {
        symbolArgs['assetPath'] = widget.imageAsset!.assetPath;
        symbolArgs['imageData'] = widget.imageAsset!.imageData;
        // Auto-detect format if not provided
        symbolArgs['imageFormat'] =
            widget.imageAsset!.imageFormat ??
            detectImageFormat(
              widget.imageAsset!.assetPath,
              widget.imageAsset!.imageData,
            );
      }

      await channel.invokeMethod('setSymbol', symbolArgs);
      _lastName = name;
    }

    // Track if any style properties changed
    bool hasStyleChanges = false;
    final style = <String, dynamic>{};

    if (_lastSize != size) {
      style['iconSize'] = size;
      _lastSize = size;
      hasStyleChanges = true;
    }
    if (_lastColor != color) {
      if (color != null) {
        style['iconColor'] = color;
      }
      _lastColor = color;
      hasStyleChanges = true;
    }
    if (_lastMode != mode) {
      if (mode != null) {
        style['iconRenderingMode'] = mode;
      }
      _lastMode = mode;
      hasStyleChanges = true;
    }
    if (_lastGradient != gradient) {
      if (gradient != null) {
        style['iconGradientEnabled'] = gradient;
      }
      _lastGradient = gradient;
      hasStyleChanges = true;
    }

    // If any style changed, include the icon source to prevent disappearing icons
    if (hasStyleChanges) {
      // Add imageAsset properties if using imageAsset
      if (widget.imageAsset != null) {
        style['assetPath'] = widget.imageAsset!.assetPath;
        style['imageData'] = widget.imageAsset!.imageData;
        // Auto-detect format if not provided
        style['imageFormat'] =
            widget.imageAsset!.imageFormat ??
            detectImageFormat(
              widget.imageAsset!.assetPath,
              widget.imageAsset!.imageData,
            );
      } else if (widget.symbol != null) {
        // Include the symbol name so native side knows what to render
        style['name'] = widget.symbol!.name;
      }
    }

    if (style.isNotEmpty) {
      await channel.invokeMethod('setStyle', style);
    }

    if (effectChanged) {
      await channel.invokeMethod('setSymbolEffect', {
        'effect': effect?.toMap(),
      });
    }
    if (triggered) {
      await channel.invokeMethod('playSymbolEffect', {
        'effect': (widget.triggeredEffect ?? const CNSymbolEffect.bounce())
            .toMap(),
      });
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      await channel.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }
  }

  Widget _buildFlutterIcon(BuildContext context) {
    // For fallback, use Flutter Icon widget
    Widget? iconWidget;

    if (widget.imageAsset != null) {
      // For image assets in fallback, use a placeholder
      iconWidget = Icon(
        CupertinoIcons.circle_fill,
        size: widget.imageAsset!.size,
        color: widget.imageAsset!.color ?? widget.color,
      );
    } else if (widget.customIcon != null) {
      iconWidget = Icon(
        widget.customIcon,
        size: widget.size ?? widget.symbol?.size ?? 24.0,
        color: widget.color,
      );
    } else if (widget.symbol != null) {
      // For SF Symbols, use a placeholder Cupertino icon
      iconWidget = Icon(
        CupertinoIcons.circle_fill,
        size: widget.size ?? widget.symbol!.size,
        color: widget.color ?? widget.symbol?.color,
      );
    } else {
      // Fallback to a generic icon
      iconWidget = Icon(
        CupertinoIcons.circle_fill,
        size: widget.size ?? 24.0,
        color: widget.color,
      );
    }

    final h = widget.height ?? widget.size ?? 24.0;
    final w = widget.size ?? 24.0;
    return SizedBox(width: w, height: h, child: iconWidget);
  }
}
