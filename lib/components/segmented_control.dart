import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/sf_symbol.dart';
import '../utils/layout_direction.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/optional_method_call.dart';
import '../utils/version_detector.dart';
import '../utils/theme_helper.dart';

/// A Cupertino-native segmented control.
///
/// Embeds a native `UISegmentedControl` on iOS 26+ and an
/// `NSSegmentedControl` on every macOS. Below iOS 26 and on other platforms
/// it is a [CupertinoSegmentedControl].
///
/// The control fills the width it is given, with equal segments, unless
/// [shrinkWrap] is set; that holds on iOS and macOS alike. On macOS the
/// control keeps the system height and is centred in [height].
class CNSegmentedControl extends StatefulWidget {
  /// Creates a Cupertino-native segmented control.
  const CNSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onValueChanged,
    this.enabled = true,
    this.color,
    this.height = 32.0,
    this.shrinkWrap = false,
    this.sfSymbols,
    this.iconSize,
    this.iconColor,
    this.iconPaletteColors,
    this.iconGradientEnabled,
    this.iconRenderingMode,
    this.autoHideOnModal = true,
    this.semanticLabel,
    this.labelFontFamily,
    this.labelFontSize,
    this.labelFontWeight,
    this.labelColor,
    this.selectedLabelFontFamily,
    this.selectedLabelFontWeight,
    this.selectedLabelColor,
    this.textDirection,
  });

  /// Segment labels to display, in order.
  final List<String> labels;

  /// The index of the selected segment.
  final int selectedIndex;

  /// Called when the user selects a segment.
  final ValueChanged<int> onValueChanged;

  /// Whether the control is interactive.
  final bool enabled;

  /// Accent/tint color used for the control.
  final Color? color;

  /// Control height.
  final double height;

  /// If true, sizes the control to its intrinsic width.
  final bool shrinkWrap;

  /// Optional SF Symbols for segments; complements [labels].
  final List<CNSymbol>? sfSymbols;

  /// Overrides the symbol size (for all segments).
  final double? iconSize;

  /// Global icon color override.
  final Color? iconColor;

  /// Global icon palette colors override.
  final List<Color>? iconPaletteColors;

  /// Enables gradient rendering where supported.
  final bool? iconGradientEnabled;

  /// Global icon rendering mode.
  final CNSymbolRenderingMode? iconRenderingMode;

  /// When true (default), destroys the native segmented control's PlatformView
  /// while a modal sheet is presented above this widget's host route. Fixes
  /// the iOS hybrid-composition z-order bleed (Issue #53). Requires
  /// `CNTabBarRouteObserver()` to be registered in the app's
  /// `navigatorObservers`. No effect on iOS < 26 / non-iOS (Flutter fallback).
  final bool autoHideOnModal;

  /// What VoiceOver reads for the control as a whole, e.g. `'Appearance'`.
  ///
  /// Each segment already reads its own label; this names the group, which a
  /// native control cannot take from the text next to it. Pass the same
  /// text as its visible label.
  final String? semanticLabel;

  /// The font family of the segment titles, e.g. a font declared under
  /// `fonts:` in `pubspec.yaml`, which the package registers with the
  /// system the first time it is used (#143). It applies to this control
  /// only, and changes reach the control without recreating it.
  final String? labelFontFamily;

  /// The size of the segment titles, in points (about 13 by default).
  final double? labelFontSize;

  /// The weight of the titles of the segments that are not selected.
  final FontWeight? labelFontWeight;

  /// The colour of the titles of the segments that are not selected.
  final Color? labelColor;

  /// The font family of the selected segment's title. Null uses
  /// [labelFontFamily].
  final String? selectedLabelFontFamily;

  /// The weight of the selected segment's title. Null draws it semibold (or
  /// [labelFontWeight] when that is heavier), as the system does.
  final FontWeight? selectedLabelFontWeight;

  /// The colour of the selected segment's title. Null uses [labelColor].
  final Color? selectedLabelColor;

  /// The direction the segments are laid out in: the first on the right for
  /// [TextDirection.rtl]. Null takes the ambient [Directionality] (#142).
  final TextDirection? textDirection;

  @override
  State<CNSegmentedControl> createState() => _CNSegmentedControlState();
}

class _CNSegmentedControlState extends State<CNSegmentedControl>
    with ModalHideMixin<CNSegmentedControl> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;

  int? _lastSelected;
  bool? _lastEnabled;
  bool? _lastIsDark;
  int? _lastTint;
  String? _lastSemanticLabel;
  double? _intrinsicWidth;
  String? _lastItemsKey;
  Map<String, Object>? _lastLabelStyle;
  bool? _lastRtl;

  bool get _isDark => ThemeHelper.isDark(context);

  /// Taps and horizontal drags go to the native control, so a press on one
  /// segment can slide to another, as in UIKit (#120). A vertical drag that
  /// starts on the control still scrolls a parent list.
  static final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers =
      <Factory<OneSequenceGestureRecognizer>>{
        Factory<HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
        ),
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
      };

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CNSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
    // A new Directionality or text scale.
    _syncPropsToNativeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    // Check if we should use native platform view
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeControls;

    // Fallback to Flutter widgets for non-Apple platforms and iOS < 26
    if (!shouldUseNative) {
      // For non-Apple platforms and iOS < 26, use CupertinoSegmentedControl
      return _labelled(
        SizedBox(
          height: widget.height,
          child: CupertinoSegmentedControl<int>(
            // The default, primaryContrastingColor, is white in a dark theme too.
            unselectedColor: CupertinoColors.systemBackground.resolveFrom(
              context,
            ),
            children: {
              for (var i = 0; i < widget.labels.length; i++)
                i: Text(
                  widget.labels[i],
                  style: _fallbackLabelStyle(i == widget.selectedIndex),
                ),
            },
            groupValue: widget.selectedIndex,
            onValueChanged: widget.enabled
                ? (i) => widget.onValueChanged(i)
                : (_) {},
          ),
        ),
      );
    }

    // Placeholder width MUST mirror the live build's footprint:
    //   - shrinkWrap path renders inside a Center{SizedBox(width: _intrinsicWidth)},
    //     which (until first measurement) stretches to full width then collapses
    //     to the measured intrinsic. Use the cached intrinsic if available so
    //     surrounding layout doesn't reflow when the placeholder swaps in.
    //   - non-shrinkWrap path renders inside a SizedBox(height: ...) that takes
    //     all available width (double.infinity).
    final hidden = maybeHiddenPlaceholder(
      height: widget.height,
      width: widget.shrinkWrap ? _intrinsicWidth : double.infinity,
    );
    if (hidden != null) return hidden;

    const viewType = 'CupertinoNativeSegmentedControl';
    final creationParams = <String, dynamic>{
      ..._itemParams(context),
      if (_labelStyle(context).isNotEmpty) 'labelStyle': _labelStyle(context),
      'rtl': ?nativeRtl(context, widget.textDirection),
      'selectedIndex': widget.selectedIndex,
      'enabled': widget.enabled,
      if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
      'isDark': _isDark,
      'style': encodeStyle(context, tint: widget.color)
        ..addAll({
          if (widget.iconSize != null) 'iconSize': widget.iconSize,
          if (widget.iconColor != null)
            'iconColor': resolveColorToArgb(widget.iconColor, context),
          if (widget.iconPaletteColors != null)
            'iconPaletteColors': widget.iconPaletteColors!
                .map((c) => resolveColorToArgb(c, context))
                .toList(),
          if (widget.iconGradientEnabled != null)
            'iconGradientEnabled': widget.iconGradientEnabled,
          if (widget.iconRenderingMode != null)
            'iconRenderingMode': widget.iconRenderingMode!.name,
        }),
    };

    Widget platformView;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformView = UiKitView(
        viewType: viewType,
        creationParamsCodec: const StandardMessageCodec(),
        creationParams: creationParams,
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: _gestureRecognizers,
      );
    } else {
      platformView = AppKitView(
        viewType: viewType,
        creationParamsCodec: const StandardMessageCodec(),
        creationParams: creationParams,
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: _gestureRecognizers,
      );
    }

    if (widget.shrinkWrap) {
      final width = _intrinsicWidth;
      return wrapWithModalInteractionGuard(
        Center(
          child: ClipRect(
            child: SizedBox(
              height: widget.height,
              width: width, // if null, stretches initially until measured
              child: platformView,
            ),
          ),
        ),
      );
    }

    return wrapWithModalInteractionGuard(
      ClipRect(
        child: SizedBox(height: widget.height, child: platformView),
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('CupertinoNativeSegmentedControl_$id');
    _channel = channel;
    channel.setMethodCallHandler(_onMethodCall);
    _cacheCurrentProps();
    _syncBrightnessIfNeeded();
    _requestIntrinsicSize();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'valueChanged') {
      final args = call.arguments as Map?;
      final idx = (args?['index'] as num?)?.toInt();
      if (idx != null) {
        widget.onValueChanged(idx);
        _lastSelected = idx;
      }
    }
    return null;
  }

  /// The labels and symbols, as created and as `setItems` sends them.
  Map<String, dynamic> _itemParams(BuildContext context) => <String, dynamic>{
    'labels': widget.labels,
    if (widget.sfSymbols != null) ...{
      'sfSymbols': widget.sfSymbols!.map((e) => e.name).toList(),
      'sfSymbolSizes': widget.sfSymbols!.map((e) => e.size).toList(),
      'sfSymbolColors': widget.sfSymbols!
          .map((e) => resolveColorToArgb(e.color, context))
          .toList(),
      'sfSymbolPaletteColors': widget.sfSymbols!
          .map(
            (e) => (e.paletteColors ?? [])
                .map((c) => resolveColorToArgb(c, context))
                .toList(),
          )
          .toList(),
      'sfSymbolRenderingModes': widget.sfSymbols!
          .map((e) => e.mode?.name)
          .toList(),
      'sfSymbolGradientEnabled': widget.sfSymbols!
          .map((e) => e.gradient)
          .toList(),
    },
  };

  /// What decides whether the items changed: their labels and symbols.
  String _itemsKey(BuildContext context) => _itemParams(context).toString();

  /// The label style the native control takes (#143); empty for none.
  Map<String, Object> _labelStyle(BuildContext context) => <String, Object>{
    'fontFamily': ?widget.labelFontFamily,
    'fontSize': ?widget.labelFontSize,
    'fontWeight': ?widget.labelFontWeight?.value,
    'color': ?resolveColorToArgb(widget.labelColor, context),
    'selectedFontFamily': ?widget.selectedLabelFontFamily,
    'selectedFontWeight': ?widget.selectedLabelFontWeight?.value,
    'selectedColor': ?resolveColorToArgb(widget.selectedLabelColor, context),
  };

  /// The label style of the fallback control's titles.
  TextStyle? _fallbackLabelStyle(bool selected) {
    final family = selected
        ? widget.selectedLabelFontFamily ?? widget.labelFontFamily
        : widget.labelFontFamily;
    final weight = selected
        ? widget.selectedLabelFontWeight ?? widget.labelFontWeight
        : widget.labelFontWeight;
    final color = selected
        ? widget.selectedLabelColor ?? widget.labelColor
        : widget.labelColor;
    if (family == null &&
        weight == null &&
        color == null &&
        widget.labelFontSize == null) {
      return null;
    }
    return TextStyle(
      fontFamily: family,
      fontSize: widget.labelFontSize,
      fontWeight: weight,
      color: color,
    );
  }

  void _cacheCurrentProps() {
    _lastItemsKey = _itemsKey(context);
    _lastLabelStyle = _labelStyle(context);
    _lastRtl = nativeRtl(context, widget.textDirection);
    _lastSelected = widget.selectedIndex;
    _lastEnabled = widget.enabled;
    _lastIsDark = _isDark;
    _lastTint = resolveColorToArgb(widget.color, context);
    _lastSemanticLabel = widget.semanticLabel;
  }

  /// Names the fallback control with [CNSegmentedControl.semanticLabel].
  Widget _labelled(Widget child) {
    final label = widget.semanticLabel;
    if (label == null) return child;
    return Semantics(container: true, label: label, child: child);
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;

    final tint = resolveColorToArgb(widget.color, context);
    final itemsKey = _itemsKey(context);
    final items = _itemParams(context);
    final labelStyle = _labelStyle(context);
    final rtl = nativeRtl(context, widget.textDirection);

    if (_lastItemsKey != itemsKey) {
      // Labels changed after creation, e.g. on a language switch (#143).
      _lastItemsKey = itemsKey;
      _lastSelected = widget.selectedIndex;
      await channel.invokeOptionalMethod('setItems', {
        ...items,
        'selectedIndex': widget.selectedIndex,
      });
      _requestIntrinsicSize();
    }
    if (!mapEquals(_lastLabelStyle, labelStyle)) {
      _lastLabelStyle = labelStyle;
      await channel.invokeOptionalMethod('setLabelStyle', labelStyle);
      _requestIntrinsicSize();
    }
    if (_lastRtl != rtl && rtl != null) {
      _lastRtl = rtl;
      await channel.invokeOptionalMethod('setLayoutDirection', {'rtl': rtl});
    }

    if (_lastEnabled != widget.enabled) {
      await channel.invokeMethod('setEnabled', {'enabled': widget.enabled});
      _lastEnabled = widget.enabled;
    }
    if (_lastSelected != widget.selectedIndex) {
      await channel.invokeMethod('setSelectedIndex', {
        'index': widget.selectedIndex,
      });
      _lastSelected = widget.selectedIndex;
    }
    if (_lastTint != tint && tint != null) {
      await channel.invokeMethod('setStyle', {'tint': tint});
      _lastTint = tint;
    }
    if (_lastSemanticLabel != widget.semanticLabel) {
      _lastSemanticLabel = widget.semanticLabel;
      await channel.invokeOptionalMethod('setSemanticLabel', {
        'label': widget.semanticLabel,
      });
    }
  }

  Future<void> _requestIntrinsicSize() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      final size = await channel.invokeMethod<Map>('getIntrinsicSize');
      final w = (size?['width'] as num?)?.toDouble();
      if (w != null && mounted) {
        setState(() => _intrinsicWidth = w);
      }
    } catch (_) {}
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    final isDark = _isDark;
    final tint = resolveColorToArgb(widget.color, context);
    if (_lastIsDark != isDark) {
      await channel.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }
    if (_lastTint != tint && tint != null) {
      await channel.invokeMethod('setStyle', {'tint': tint});
      _lastTint = tint;
    }
  }
}
