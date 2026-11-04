import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../channel/params.dart';
import '../utils/version_detector.dart';
import '../utils/theme_helper.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/optional_method_call.dart';

/// Controller for a [CNSlider] allowing imperative changes to the native
/// NSSlider/UISlider instance.
class CNSliderController {
  MethodChannel? _channel;

  void _attach(MethodChannel channel) {
    _channel = channel;
  }

  void _detach() {
    _channel = null;
  }

  /// Sets the current slider [value]. When [animated] is true, animates to it.
  Future<void> setValue(double value, {bool animated = false}) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('setValue', {
      'value': value,
      'animated': animated,
    });
  }

  /// Sets the valid [min] and [max] range of the slider.
  Future<void> setRange({required double min, required double max}) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('setRange', {'min': min, 'max': max});
  }

  /// Enables or disables user interaction on the slider.
  Future<void> setEnabled(bool enabled) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.invokeMethod('setEnabled', {'enabled': enabled});
  }
}

/// How a [CNSlider] draws its track and thumb.
enum CNSliderStyle {
  /// The standard slider, with a thumb.
  standard,

  /// No thumb: a thicker track that fills up to the value, as in media
  /// players (`UISlider.Style.thumbless`, iOS 26+). `NSSlider` has no such
  /// style, so macOS keeps the thumb, as do the Flutter fallbacks.
  thumbless,
}

/// A Cupertino-native slider rendered by the host platform.
///
/// On iOS 26+ and on every macOS this embeds a `UISlider` / `NSSlider`
/// through a platform view. Below iOS 26 it is a [CupertinoSlider], and on
/// other platforms Flutter's [Slider].
///
/// The track can show tick marks ([numberOfTicks] or [tickValues]) and snap
/// to them ([allowsTickValuesOnly]) on iOS 26+ and on macOS, and fill from a
/// [neutralValue] on iOS 26+ and macOS 26+; iOS 26+ also has a
/// [CNSliderStyle.thumbless] [style].
///
/// On macOS the track takes [color] / [trackColor]; `NSSlider` has no thumb
/// colour and no colour for the unfilled track, so [thumbColor] and
/// [trackBackgroundColor] apply on iOS only.
class CNSlider extends StatefulWidget {
  /// Creates a Cupertino-native slider.
  const CNSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.enabled = true,
    this.controller,
    this.height = 44.0,
    this.color,
    this.thumbColor,
    this.trackColor,
    this.trackBackgroundColor,
    this.step,
    this.autoHideOnModal = true,
    this.semanticLabel,
    this.style = CNSliderStyle.standard,
    this.numberOfTicks,
    this.tickValues,
    this.allowsTickValuesOnly = true,
    this.neutralValue,
  }) : assert(
         numberOfTicks == null || tickValues == null,
         'Set numberOfTicks or tickValues, not both',
       ),
       assert(
         numberOfTicks == null || numberOfTicks > 1,
         'numberOfTicks needs at least the two ends of the track',
       );

  /// Current slider value.
  final double value;

  /// Minimum value.
  final double min;

  /// Maximum value.
  final double max;

  /// Whether the control is interactive.
  final bool enabled;

  /// Callback when the value changes due to user interaction.
  final ValueChanged<double> onChanged;

  /// Optional controller to imperatively interact with the native view.
  final CNSliderController? controller;

  /// Visual height of the embedded platform view.
  final double height;

  /// General accent/tint color for the control.
  final Color? color;

  /// Explicit thumb color; if null, uses the native default.
  final Color? thumbColor;

  /// Explicit active track color.
  final Color? trackColor;

  /// Explicit inactive track color.
  final Color? trackBackgroundColor;

  /// Optional step interval for discrete values.
  final double? step;

  /// When true (default), destroys the native slider's PlatformView while a
  /// modal sheet is presented above this widget's host route. Prevents the
  /// iOS hybrid-composition z-order bleed (Issue #53) where the host-page
  /// PlatformView's pixels leak through a sheet that also contains a
  /// PlatformView (CN-widget). Requires `CNTabBarRouteObserver()` to be
  /// registered in the app's `navigatorObservers`. No effect on non-iOS or
  /// iOS < 26 (Flutter fallback path).
  final bool autoHideOnModal;

  /// What VoiceOver reads for the slider.
  ///
  /// A native slider cannot borrow the text next to it the way a Flutter
  /// widget in `MergeSemantics` can, so without this VoiceOver announces it
  /// with no name. Pass the same text as its visible label, e.g. `'Volume'`.
  final String? semanticLabel;

  /// How the slider draws its track and thumb. [CNSliderStyle.thumbless]
  /// needs iOS 26+; elsewhere the slider keeps its thumb.
  final CNSliderStyle style;

  /// Draws this many evenly spaced tick marks along the track, the first at
  /// [min] and the last at [max] (`UISlider.TrackConfiguration
  /// (numberOfTicks:)` on iOS 26+, `NSSlider` tick marks on macOS).
  ///
  /// Below iOS 26 nothing is drawn, but with [allowsTickValuesOnly] the
  /// Flutter fallback snaps to the same values (`divisions`). UIKit draws no
  /// tick marks on a [CNSliderStyle.thumbless] slider.
  final int? numberOfTicks;

  /// Draws tick marks at these values, which need not be evenly spaced.
  /// Use this or [numberOfTicks], not both.
  ///
  /// On macOS, values evenly spaced from [min] to [max] are `NSSlider` tick
  /// marks; other values are drawn by the SwiftUI slider on macOS 26+, and
  /// below macOS 26 only snapped to. Below iOS 26 nothing is drawn, but with
  /// [allowsTickValuesOnly] the Flutter fallback snaps to the nearest of
  /// these values.
  final List<double>? tickValues;

  /// Whether the slider only settles on tick values. Like UIKit, defaults to
  /// true; it only applies when [numberOfTicks] or [tickValues] is set.
  final bool allowsTickValuesOnly;

  /// The value the filled part of the track starts from, so a slider from
  /// -10 to 10 can fill outward from 0 (iOS 26+, macOS 26+). Null fills from
  /// [min]. Older macOS and the Flutter fallbacks always fill from [min].
  final double? neutralValue;

  @override
  State<CNSlider> createState() => _CNSliderState();
}

class _CNSliderState extends State<CNSlider> with ModalHideMixin<CNSlider> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;

  double? _lastValue;
  double? _lastMin;
  double? _lastMax;
  bool? _lastEnabled;
  String? _lastSemanticLabel;
  bool? _lastIsDark;
  int? _lastTint;
  int? _lastThumbTint;
  int? _lastTrackTint;
  int? _lastTrackBgTint;
  double? _lastStep;
  CNSliderStyle? _lastStyle;
  Map<String, Object>? _lastTrackConfiguration;
  bool get _isDark => ThemeHelper.isDark(context);

  bool get _hasTicks =>
      widget.numberOfTicks != null || widget.tickValues != null;

  /// The tick and neutral-value options sent to the native slider. Empty
  /// when none is used.
  Map<String, Object> get _trackConfiguration => <String, Object>{
    if (widget.numberOfTicks != null) 'numberOfTicks': widget.numberOfTicks!,
    if (widget.tickValues != null) 'tickValues': widget.tickValues!,
    if (_hasTicks) 'allowsTickValuesOnly': widget.allowsTickValuesOnly,
    if (widget.neutralValue != null) 'neutralValue': widget.neutralValue!,
  };

  /// Compares two [_trackConfiguration]s, `tickValues` by content, so a
  /// list rebuilt with the same values is not sent again.
  static bool _sameTrackConfiguration(
    Map<String, Object>? a,
    Map<String, Object> b,
  ) {
    if (a == null || a.length != b.length) return false;
    for (final entry in b.entries) {
      final old = a[entry.key];
      final same = old is List<double> && entry.value is List<double>
          ? listEquals(old, entry.value as List<double>)
          : old == entry.value;
      if (!same) return false;
    }
    return true;
  }

  /// The tick values the Flutter fallback snaps to, or null when it does not
  /// snap.
  List<double>? get _fallbackSnapValues {
    if (!_hasTicks || !widget.allowsTickValuesOnly) return null;
    final explicit = widget.tickValues;
    if (explicit != null) {
      return explicit.isEmpty ? null : explicit;
    }
    final n = widget.numberOfTicks!;
    final span = widget.max - widget.min;
    return [for (var i = 0; i < n; i++) widget.min + span * i / (n - 1)];
  }

  /// `divisions` for the Flutter fallback: the number of gaps between
  /// evenly spaced ticks from [CNSlider.min] to [CNSlider.max], or null when
  /// the ticks are not spaced that way.
  int? get _fallbackDivisions {
    final values = _fallbackSnapValues;
    if (values == null || values.length < 2) return null;
    final sorted = [...values]..sort();
    final span = widget.max - widget.min;
    if (span <= 0) return null;
    final gap = span / (sorted.length - 1);
    const epsilon = 1e-9;
    for (var i = 0; i < sorted.length; i++) {
      if ((sorted[i] - (widget.min + gap * i)).abs() > epsilon * span.abs()) {
        return null;
      }
    }
    return sorted.length - 1;
  }

  /// The fallback's `onChanged`: snaps to the nearest tick value when the
  /// ticks are not evenly spaced (`divisions` covers the even case).
  ValueChanged<double> get _fallbackOnChanged {
    final values = _fallbackSnapValues;
    if (values == null || _fallbackDivisions != null) return widget.onChanged;
    return (v) {
      var nearest = values.first;
      for (final t in values) {
        if ((t - v).abs() < (nearest - v).abs()) nearest = t;
      }
      widget.onChanged(nearest);
    };
  }

  CNSliderController? _internalController;

  CNSliderController get _controller =>
      widget.controller ?? (_internalController ??= CNSliderController());

  // Default colors:
  // - Track: use explicit trackColor, otherwise widget.color, otherwise theme primaryColor.
  // - Thumb: only use explicit thumbColor; otherwise keep the native default.
  Color? get _effectiveTrackTint =>
      widget.trackColor ?? widget.color ?? ThemeHelper.getPrimaryColor(context);
  Color? get _effectiveThumbTint => widget.thumbColor;
  Color? get _effectiveTrackBgTint => widget.trackBackgroundColor;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _controller._detach();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CNSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme may have changed
    _syncBrightnessIfNeeded();
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
      // For non-iOS/macOS, use Material Slider
      if (!isIOSOrMacOS) {
        return _labelled(
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Slider(
              value: widget.value.clamp(widget.min, widget.max).toDouble(),
              min: widget.min,
              max: widget.max,
              divisions: _fallbackDivisions,
              onChanged: widget.enabled ? _fallbackOnChanged : null,
            ),
          ),
        );
      }

      // For iOS < 26, use CupertinoSlider
      return _labelled(
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CupertinoSlider(
            value: widget.value.clamp(widget.min, widget.max).toDouble(),
            min: widget.min,
            max: widget.max,
            divisions: _fallbackDivisions,
            onChanged: widget.enabled ? _fallbackOnChanged : null,
            activeColor: _effectiveTrackTint ?? CupertinoColors.activeBlue,
            thumbColor: _effectiveThumbTint ?? CupertinoColors.white,
          ),
        ),
      );
    }

    const viewType = 'CupertinoNativeSlider';

    // Issue #53 fix: when a modal is presented above our host route, destroy
    // the native UISlider to remove its PlatformView from the shared iOS
    // PlatformView container. Otherwise hybrid-composition z-order desyncs
    // with the sheet's PlatformView during drag, causing visual bleed.
    final hidden = maybeHiddenPlaceholder(
      height: widget.height,
      width: double.infinity,
    );
    if (hidden != null) return hidden;

    final creationParams = <String, dynamic>{
      'min': widget.min,
      'max': widget.max,
      'value': widget.value,
      'enabled': widget.enabled,
      if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
      'isDark': _isDark,
      'style': encodeStyle(
        context,
        // Do not provide a general 'tint' so the thumb color remains default.
        trackTint: _effectiveTrackTint,
        thumbTint: _effectiveThumbTint,
        trackBackgroundTint: _effectiveTrackBgTint,
      ),
      if (widget.step != null) 'step': widget.step,
      if (widget.style != CNSliderStyle.standard)
        'sliderStyle': widget.style.name,
      ..._trackConfiguration,
    };

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return wrapWithModalInteractionGuard(
        ClipRect(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: UiKitView(
              viewType: viewType,
              creationParamsCodec: const StandardMessageCodec(),
              creationParams: creationParams,
              onPlatformViewCreated: _onPlatformViewCreated,
              // Forward horizontal drags and taps to the native slider so it
              // works correctly inside Flutter scroll views.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                ),
                Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
              },
            ),
          ),
        ),
      );
    }

    // macOS
    return ClipRect(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        // AppKitView is available on macOS to host NSView platform views.
        child: AppKitView(
          viewType: viewType,
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: creationParams,
          onPlatformViewCreated: _onPlatformViewCreated,
          // Mirror iOS behavior: allow horizontal drag/tap gestures through.
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
            ),
            Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
          },
        ),
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('CupertinoNativeSlider_$id');
    _channel = channel;
    _controller._attach(channel);
    channel.setMethodCallHandler(_onMethodCall);
    _cacheCurrentProps();
    _syncBrightnessIfNeeded();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'valueChanged') {
      final args = call.arguments as Map?;
      final value = (args?['value'] as num?)?.toDouble();
      if (value != null) {
        widget.onChanged(value);
        _lastValue = value;
      }
    }
    return null;
  }

  void _cacheCurrentProps() {
    _lastValue = widget.value;
    _lastMin = widget.min;
    _lastMax = widget.max;
    _lastEnabled = widget.enabled;
    _lastSemanticLabel = widget.semanticLabel;
    _lastIsDark = _isDark;
    _lastTint = null; // Not using general tint to avoid coloring the thumb.
    _lastThumbTint = resolveColorToArgb(_effectiveThumbTint, context);
    _lastTrackTint = resolveColorToArgb(_effectiveTrackTint, context);
    _lastTrackBgTint = resolveColorToArgb(_effectiveTrackBgTint, context);
    _lastStep = widget.step;
    _lastStyle = widget.style;
    _lastTrackConfiguration = _trackConfiguration;
  }

  /// Joins [CNSlider.semanticLabel] to the fallback slider's own node, so it
  /// is read together with its value.
  Widget _labelled(Widget child) {
    final label = widget.semanticLabel;
    if (label == null) return child;
    return MergeSemantics(
      child: Semantics(label: label, child: child),
    );
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;

    // Resolve any context-dependent values before awaiting.
    final int? tint = null; // No general tint
    final int? thumb0 = resolveColorToArgb(_effectiveThumbTint, context);
    final int? track0 = resolveColorToArgb(_effectiveTrackTint, context);
    final int? trackBg0 = resolveColorToArgb(_effectiveTrackBgTint, context);

    if (_lastMin != widget.min || _lastMax != widget.max) {
      await channel.invokeMethod('setRange', {
        'min': widget.min,
        'max': widget.max,
      });
      _lastMin = widget.min;
      _lastMax = widget.max;
    }

    if (_lastEnabled != widget.enabled) {
      await channel.invokeMethod('setEnabled', {'enabled': widget.enabled});
      _lastEnabled = widget.enabled;
    }

    if (_lastSemanticLabel != widget.semanticLabel) {
      await channel.invokeOptionalMethod('setSemanticLabel', {
        'label': widget.semanticLabel,
      });
      _lastSemanticLabel = widget.semanticLabel;
    }

    final double clamped = widget.value
        .clamp(widget.min, widget.max)
        .toDouble();
    if (_lastValue != clamped) {
      await channel.invokeMethod('setValue', {
        'value': clamped,
        'animated': false,
      });
      _lastValue = clamped;
    }

    // Style updates (e.g., tint colors)
    final thumb = thumb0;
    final track = track0;
    final trackBg = trackBg0;
    final styleUpdate = <String, dynamic>{};
    if (_lastTint != tint && tint != null) {
      styleUpdate['tint'] = tint;
      _lastTint = tint;
    }
    if (_lastThumbTint != thumb && thumb != null) {
      styleUpdate['thumbTint'] = thumb;
      _lastThumbTint = thumb;
    }
    if (_lastTrackTint != track && track != null) {
      styleUpdate['trackTint'] = track;
      _lastTrackTint = track;
    }
    if (_lastTrackBgTint != trackBg && trackBg != null) {
      styleUpdate['trackBackgroundTint'] = trackBg;
      _lastTrackBgTint = trackBg;
    }
    if (styleUpdate.isNotEmpty) {
      await channel.invokeMethod('setStyle', styleUpdate);
    }

    if (_lastStep != widget.step && widget.step != null) {
      await channel.invokeMethod('setStep', {'step': widget.step});
      _lastStep = widget.step;
    }

    if (_lastStyle != widget.style) {
      _lastStyle = widget.style;
      await channel.invokeMethod('setSliderStyle', {
        'sliderStyle': widget.style.name,
      });
    }

    final trackConfig = _trackConfiguration;
    if (!_sameTrackConfiguration(_lastTrackConfiguration, trackConfig)) {
      _lastTrackConfiguration = trackConfig;
      // Sent whole, so removed options are cleared natively.
      await channel.invokeMethod('setTrackConfiguration', trackConfig);
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    // Resolve theme-dependent values before awaiting.
    final isDark = _isDark;
    final int? tint = null; // No general tint
    final int? thumb = resolveColorToArgb(_effectiveThumbTint, context);
    final int? track = resolveColorToArgb(_effectiveTrackTint, context);
    final int? trackBg = resolveColorToArgb(_effectiveTrackBgTint, context);

    if (_lastIsDark != isDark) {
      await channel.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }

    final styleUpdate = <String, dynamic>{};
    if (_lastTint != tint && tint != null) {
      styleUpdate['tint'] = tint;
      _lastTint = tint;
    }
    if (_lastThumbTint != thumb && thumb != null) {
      styleUpdate['thumbTint'] = thumb;
      _lastThumbTint = thumb;
    }
    if (_lastTrackTint != track && track != null) {
      styleUpdate['trackTint'] = track;
      _lastTrackTint = track;
    }
    if (_lastTrackBgTint != trackBg && trackBg != null) {
      styleUpdate['trackBackgroundTint'] = trackBg;
      _lastTrackBgTint = trackBg;
    }
    if (styleUpdate.isNotEmpty) {
      await channel.invokeMethod('setStyle', styleUpdate);
    }
  }
}
