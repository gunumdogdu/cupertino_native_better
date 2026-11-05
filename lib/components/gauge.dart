import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';

/// How a [CNGauge] shows its value. Each style maps to the closest native
/// control on each platform:
///
/// | style | macOS | iOS 26+ |
/// |---|---|---|
/// | [capacity] | `NSLevelIndicator`, continuous capacity | SwiftUI `Gauge`, `.linearCapacity` |
/// | [discreteCapacity] | `NSLevelIndicator`, discrete capacity | `Gauge`, `.linearCapacity`, filled to whole units |
/// | [relevancy] | `NSLevelIndicator`, relevancy | `Gauge`, `.accessoryLinearCapacity` |
/// | [rating] | `NSLevelIndicator`, rating | a row of SF Symbol stars in SwiftUI |
/// | [circularCapacity] | `Gauge`, `.accessoryCircularCapacity` (macOS 13+) | `Gauge`, `.accessoryCircularCapacity` |
/// | [circular] | `Gauge`, `.accessoryCircular` (macOS 13+) | `Gauge`, `.accessoryCircular` |
/// | [linear] | `Gauge`, `.accessoryLinear` (macOS 13+) | `Gauge`, `.accessoryLinear` |
///
/// iOS has no segmented, relevancy or rating gauge: discrete capacity is a
/// capacity bar that fills whole units only, as the Mac segments do;
/// relevancy is the thin capacity bar; and rating is drawn with the system's
/// star symbols, as Apple's apps draw ratings. macOS 12 has no SwiftUI
/// `Gauge` and shows the three SwiftUI styles as a continuous capacity
/// `NSLevelIndicator`.
enum CNGaugeStyle {
  /// A bar that fills from the leading edge up to the value.
  capacity,

  /// A bar of segments, one for each whole unit from `min` to `max`, filled
  /// up to the value.
  discreteCapacity,

  /// A thin bar for a ranking, such as how well a search result matches.
  relevancy,

  /// A row of stars, one for each whole unit up to `max` (`min` is 0). With
  /// [CNGauge.onChanged] the user sets the rating.
  rating,

  /// A ring that fills up to the value, with the current value label inside.
  circularCapacity,

  /// An open ring with a marker at the value, as a speedometer, with the
  /// current value label inside and the bounds labels at its ends.
  circular,

  /// A thin line with a marker at the value.
  linear,
}

/// Where a [CNGauge] draws its tick marks (macOS).
enum CNGaugeTickMarkPosition {
  /// Under the bar.
  below,

  /// Over the bar.
  above,
}

/// A native gauge: a value in a range shown as a level, as Apple's gauges
/// and, on macOS, level indicators show it. Storage used, battery charge,
/// signal strength, a rating, a relevance.
///
/// ```dart
/// CNGauge(
///   value: 72,
///   max: 100,
///   warningValue: 75,
///   criticalValue: 90,
///   label: 'Storage',
///   currentValueLabel: '72 GB',
///   minimumValueLabel: '0',
///   maximumValueLabel: '100',
/// )
/// ```
///
/// See [CNGaugeStyle] for the native control behind each style.
///
/// **Warning and critical values.** With [warningValue] and
/// [criticalValue], the gauge turns [warningColor] once the value reaches the
/// warning value and [criticalColor] once it reaches the critical value, as
/// `NSLevelIndicator` does. Give a critical value below the warning value for
/// a scale where low is bad, such as a battery: then the gauge is critical
/// at or below the critical value and warning at or below the warning
/// value. The bar and ring styles change colour as a whole; the marker
/// styles ([circular], [linear]), which show the whole range, draw the zones
/// along it as a gradient. Relevancy has no colour on macOS.
///
/// **Labels.** [label], [currentValueLabel], [minimumValueLabel] and
/// [maximumValueLabel] are the SwiftUI `Gauge`'s labels, which it draws in
/// each style's own places. Around a macOS `NSLevelIndicator` and the iOS
/// stars they are laid out as the macOS `Gauge` lays out its linear ones:
/// the label above, the bounds at the ends and the current value below.
///
/// **Size.** The bar and line styles take the width of their parent (200
/// points when the parent is unbounded) and the height of the native
/// control and its labels; the ring styles and the rating take their native
/// size.
///
/// **Accessibility.** VoiceOver reads [semanticLabel] (or [label]) and the
/// value: [currentValueLabel], or "3 of 5" for a rating, or the percentage
/// of the range. An editable rating is adjustable: swipe up or down to
/// change it by one.
class CNGauge extends StatefulWidget {
  /// Creates a native gauge.
  const CNGauge({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.style = CNGaugeStyle.capacity,
    this.warningValue,
    this.criticalValue,
    this.tint,
    this.warningColor,
    this.criticalColor,
    this.label,
    this.currentValueLabel,
    this.minimumValueLabel,
    this.maximumValueLabel,
    this.tickMarkCount = 0,
    this.majorTickMarkCount = 0,
    this.tickMarkPosition = CNGaugeTickMarkPosition.below,
    this.onChanged,
    this.semanticLabel,
    this.autoHideOnModal = true,
  }) : assert(max > min, 'CNGauge needs max greater than min.'),
       assert(tickMarkCount >= 0 && majorTickMarkCount >= 0);

  /// The value, from [min] to [max]; values outside are clamped.
  final double value;

  /// The low end of the range.
  final double min;

  /// The high end of the range. For [CNGaugeStyle.rating] it is the number
  /// of stars; for [CNGaugeStyle.discreteCapacity] `max - min` is the
  /// number of segments.
  final double max;

  /// How the value is shown.
  final CNGaugeStyle style;

  /// The value from which the gauge shows [warningColor] (or up to which,
  /// when [criticalValue] is below it). Null for none.
  final double? warningValue;

  /// The value from which the gauge shows [criticalColor] (or up to which,
  /// when it is below [warningValue]). Null for none.
  final double? criticalValue;

  /// The colour of the fill, the ring, the stars, or of the normal zone when
  /// there are warning or critical values. Null keeps the native colour
  /// (green for a macOS level indicator and for any gauge with warning or
  /// critical values; the style's own colour otherwise).
  final Color? tint;

  /// The colour from [warningValue]. Null is the system yellow, as for
  /// `NSLevelIndicator`.
  final Color? warningColor;

  /// The colour from [criticalValue]. Null is the system red, as for
  /// `NSLevelIndicator`.
  final Color? criticalColor;

  /// What the gauge measures, drawn by the gauge and read by VoiceOver.
  final String? label;

  /// The current value as text, such as "72 GB".
  final String? currentValueLabel;

  /// Text for the low end of the range.
  final String? minimumValueLabel;

  /// Text for the high end of the range.
  final String? maximumValueLabel;

  /// Number of tick marks along a macOS level indicator (capacity,
  /// discrete capacity, relevancy and rating); 0 for none. iOS gauges have
  /// no tick marks.
  final int tickMarkCount;

  /// How many of the [tickMarkCount] tick marks are major (longer) ones.
  final int majorTickMarkCount;

  /// Whether the tick marks are below or above the bar.
  final CNGaugeTickMarkPosition tickMarkPosition;

  /// Makes a [CNGaugeStyle.rating] editable: called with the new rating (a
  /// whole number from 0 to [max]) when the user clicks or drags across the
  /// stars, or adjusts it with VoiceOver. The gauge is controlled: it shows
  /// the new rating once [value] changes to it. Ignored for the other
  /// styles, which are never editable.
  final ValueChanged<double>? onChanged;

  /// What VoiceOver reads for the gauge; null reads [label].
  final String? semanticLabel;

  /// When true (default), replaces the native view with an empty box of the
  /// same size while a modal sheet covers it (Issue #53). Requires
  /// `CNTabBarRouteObserver()` in the app's `navigatorObservers`.
  final bool autoHideOnModal;

  @override
  State<CNGauge> createState() => _CNGaugeState();
}

/// Width of a bar whose parent gives it no width.
const double _kUnboundedWidth = 200;

class _CNGaugeState extends State<CNGauge> with ModalHideMixin<CNGauge> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;
  double? _lastValue;
  Map<String, Object?>? _lastConfig;
  bool? _lastIsDark;
  Size? _nativeSize;

  bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  bool get _useNative {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return apple && PlatformVersion.shouldUseNativeControls;
  }

  double get _value => widget.value.clamp(widget.min, widget.max).toDouble();

  bool get _editable =>
      widget.style == CNGaugeStyle.rating && widget.onChanged != null;

  /// Whether the style takes the parent's width (bars and the line).
  bool get _fillsWidth => switch (widget.style) {
    CNGaugeStyle.capacity ||
    CNGaugeStyle.discreteCapacity ||
    CNGaugeStyle.relevancy ||
    CNGaugeStyle.linear => true,
    _ => false,
  };

  bool get _hasLabels =>
      _nonEmpty(widget.label) ||
      _nonEmpty(widget.currentValueLabel) ||
      _nonEmpty(widget.minimumValueLabel) ||
      _nonEmpty(widget.maximumValueLabel);

  static bool _nonEmpty(String? s) => s != null && s.isNotEmpty;

  /// What VoiceOver reads as the value.
  String get _semanticValue {
    final current = widget.currentValueLabel;
    if (_nonEmpty(current)) return current!;
    if (widget.style == CNGaugeStyle.rating) {
      return '${_formatNumber(_value)} of ${_formatNumber(widget.max)}';
    }
    final fraction = (_value - widget.min) / (widget.max - widget.min);
    return '${(fraction * 100).round()}%';
  }

  static String _formatNumber(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// The options that are not the value, sent whole when one changes.
  Map<String, Object?> _config(BuildContext context) => <String, Object?>{
    'style': widget.style.name,
    'min': widget.min,
    'max': widget.max,
    'warningValue': widget.warningValue,
    'criticalValue': widget.criticalValue,
    'tint': resolveColorToArgb(widget.tint, context),
    'warningColor': resolveColorToArgb(widget.warningColor, context),
    'criticalColor': resolveColorToArgb(widget.criticalColor, context),
    'label': widget.label,
    'currentValueLabel': widget.currentValueLabel,
    'minimumValueLabel': widget.minimumValueLabel,
    'maximumValueLabel': widget.maximumValueLabel,
    'tickMarkCount': widget.tickMarkCount,
    'majorTickMarkCount': widget.majorTickMarkCount,
    'tickMarkPosition': widget.tickMarkPosition.name,
    'editable': _editable,
    'semanticLabel': widget.semanticLabel ?? widget.label,
    'semanticValue': _semanticValue,
  };

  // MARK: Size

  /// The native view's size until it reports its own: what macOS 27 and
  /// iOS 27 measure in English, without labels unless noted.
  Size _estimatedSize() {
    final labels = _hasLabels;
    final ticks = widget.tickMarkCount > 0 ? 7.0 : 0.0;
    if (_isMac) {
      final labelRows =
          (_nonEmpty(widget.label) ? 18.0 : 0) +
          (_nonEmpty(widget.currentValueLabel) ? 18.0 : 0);
      return switch (widget.style) {
        CNGaugeStyle.capacity ||
        CNGaugeStyle.discreteCapacity => Size(0, 18 + ticks + labelRows),
        CNGaugeStyle.relevancy => Size(0, 12 + ticks + labelRows),
        CNGaugeStyle.rating => Size(
          12 * (widget.max - widget.min).clamp(1, 100),
          12 + ticks + labelRows,
        ),
        CNGaugeStyle.linear => Size(0, labels ? 34 : 12),
        _ => const Size(58, 58),
      };
    }
    return switch (widget.style) {
      CNGaugeStyle.capacity ||
      CNGaugeStyle.discreteCapacity => Size(0, labels ? 52 : 14),
      CNGaugeStyle.relevancy => Size(0, labels ? 44 : 6),
      CNGaugeStyle.linear => Size(0, labels ? 34 : 10),
      CNGaugeStyle.rating => Size(
        24 * (widget.max - widget.min).clamp(1, 100),
        22 + (labels ? 44 : 0),
      ),
      _ => const Size(58, 58),
    };
  }

  Size get _size {
    final reported = _nativeSize;
    final estimate = _estimatedSize();
    return Size(
      _fillsWidth ? double.infinity : (reported?.width ?? estimate.width),
      reported?.height ?? estimate.height,
    );
  }

  /// Gives [child] the gauge's size; an infinite width becomes the parent's
  /// width, or [_kUnboundedWidth] in an unbounded parent.
  Widget _sized(Size size, Widget child) {
    final box = SizedBox(width: size.width, height: size.height, child: child);
    if (size.width.isFinite) return box;
    return LimitedBox(maxWidth: _kUnboundedWidth, child: box);
  }

  // MARK: Lifecycle

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToNative();
  }

  @override
  void didUpdateWidget(covariant CNGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) _nativeSize = null;
    _syncToNative();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('CupertinoNativeGauge_$id');
    _channel = channel;
    channel.setMethodCallHandler(_onMethodCall);
    _lastValue = _value;
    _lastConfig = _config(context);
    _lastIsDark = ThemeHelper.isDark(context);
    // The native view may report its size before this handler is set.
    _requestIntrinsicSize();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    final args = call.arguments as Map?;
    switch (call.method) {
      case 'valueChanged':
        final value = (args?['value'] as num?)?.toDouble();
        if (value == null || !_editable) return null;
        // The native view shows the new rating already.
        _lastValue = value;
        if (value != _value) widget.onChanged?.call(value);
        // Back to [value] if the parent kept it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncToNative();
        });
        WidgetsBinding.instance.scheduleFrame();
      case 'sizeChanged':
        _applyNativeSize(args);
    }
    return null;
  }

  Future<void> _requestIntrinsicSize() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      _applyNativeSize(await channel.invokeMethod<Map>('getIntrinsicSize'));
    } catch (_) {
      // The view is gone; a new one reports its own size.
    }
  }

  void _applyNativeSize(Map? args) {
    final w = (args?['width'] as num?)?.toDouble();
    final h = (args?['height'] as num?)?.toDouble();
    if (w == null || h == null || w <= 0 || h <= 0 || !mounted) return;
    final size = Size(w, h);
    if (size == _nativeSize) return;
    setState(() => _nativeSize = size);
  }

  /// Sends what changed. A view hidden under a sheet answers with an error,
  /// which is ignored: it is created again with the current values.
  void _syncToNative() {
    final channel = _channel;
    if (channel == null) return;
    final isDark = ThemeHelper.isDark(context);
    if (_lastIsDark != isDark) {
      _lastIsDark = isDark;
      channel
          .invokeMethod('setBrightness', {'isDark': isDark})
          .catchError((_) {});
    }
    final config = _config(context);
    if (!mapEquals(config, _lastConfig)) {
      _lastConfig = config;
      _lastValue = _value;
      channel
          .invokeMethod('setConfig', {...config, 'value': _value})
          .catchError((_) {});
    } else if (_value != _lastValue) {
      _lastValue = _value;
      channel
          .invokeMethod('setValue', {'value': _value, 'animated': true})
          .catchError((_) {});
    }
  }

  // MARK: Build

  @override
  Widget build(BuildContext context) {
    if (!_useNative) return _buildFallback(context);

    final size = _size;
    final hidden = maybeHiddenPlaceholder(
      height: size.height,
      width: size.width,
    );
    if (hidden != null) return _sized(size, hidden);

    final creationParams = <String, Object?>{
      ..._config(context),
      'value': _value,
      'isDark': ThemeHelper.isDark(context),
    };

    const viewType = 'CupertinoNativeGauge';
    final Widget platformView;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformView = UiKitView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        // A gauge that only shows a value takes no touches: they reach the
        // widgets under it (a tappable row) and scroll a list. An editable
        // rating takes taps and horizontal drags; a vertical drag that
        // starts on it still scrolls.
        hitTestBehavior: _editable
            ? PlatformViewHitTestBehavior.opaque
            : PlatformViewHitTestBehavior.transparent,
        gestureRecognizers: _editable
            ? <Factory<OneSequenceGestureRecognizer>>{
                Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
                Factory<HorizontalDragGestureRecognizer>(
                  HorizontalDragGestureRecognizer.new,
                ),
              }
            : null,
      );
    } else {
      // The NSView takes clicks only when the rating is editable; otherwise
      // clicks and scrolls go to the Flutter view under it.
      platformView = AppKitView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        hitTestBehavior: _editable
            ? PlatformViewHitTestBehavior.opaque
            : PlatformViewHitTestBehavior.transparent,
      );
    }

    return wrapWithModalInteractionGuard(_sized(size, platformView));
  }

  // MARK: Fallback

  /// iOS below 26 and other platforms: the gauge drawn by Flutter in the
  /// shape of the iOS one.
  Widget _buildFallback(BuildContext context) {
    final semantics = widget.semanticLabel ?? widget.label;
    final Widget gauge = switch (widget.style) {
      CNGaugeStyle.rating => _FallbackRating(
        value: _value,
        max: widget.max,
        color: widget.tint,
        onChanged: _editable ? widget.onChanged : null,
      ),
      CNGaugeStyle.circular || CNGaugeStyle.circularCapacity => _FallbackRing(
        fraction: _fraction(_value),
        style: widget.style,
        colors: _zoneColors(context),
        current: widget.currentValueLabel,
        minLabel: widget.minimumValueLabel,
        maxLabel: widget.maximumValueLabel,
      ),
      _ => _FallbackBar(
        fraction: _fraction(_displayValue),
        style: widget.style,
        colors: _zoneColors(context),
      ),
    };
    final ringStyle =
        widget.style == CNGaugeStyle.circular ||
        widget.style == CNGaugeStyle.circularCapacity;
    final labelled = ringStyle ? gauge : _withLabels(context, gauge);
    return Semantics(
      label: semantics,
      value: _semanticValue,
      increasedValue: _editable && _value < widget.max
          ? _formatNumber(_value + 1)
          : null,
      decreasedValue: _editable && _value > 0
          ? _formatNumber(_value - 1)
          : null,
      onIncrease: _editable && _value < widget.max
          ? () => widget.onChanged?.call((_value + 1).floorToDouble())
          : null,
      onDecrease: _editable && _value > 0
          ? () => widget.onChanged?.call((_value - 1).ceilToDouble())
          : null,
      child: ExcludeSemantics(child: labelled),
    );
  }

  /// A discrete gauge fills whole units only.
  double get _displayValue => widget.style == CNGaugeStyle.discreteCapacity
      ? (widget.min + (_value - widget.min).floorToDouble())
      : _value;

  double _fraction(double v) =>
      ((v - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  /// The fill colour for the current value, and for the marker styles the
  /// zones along the range: (colour, from fraction).
  _ZoneColors _zoneColors(BuildContext context) {
    final warning =
        widget.warningColor ??
        CupertinoColors.systemYellow.resolveFrom(context);
    final critical =
        widget.criticalColor ?? CupertinoColors.systemRed.resolveFrom(context);
    final hasZones =
        widget.warningValue != null || widget.criticalValue != null;
    final normal =
        widget.tint ??
        (hasZones
            ? CupertinoColors.systemGreen.resolveFrom(context)
            : CupertinoColors.systemBlue.resolveFrom(context));
    final w = widget.warningValue;
    final c = widget.criticalValue;
    final v = _value;
    final descending = w != null && c != null && c < w;
    Color current = normal;
    if (descending) {
      if (v <= c) {
        current = critical;
      } else if (v <= w) {
        current = warning;
      }
    } else {
      if (c != null && v >= c) {
        current = critical;
      } else if (w != null && v >= w) {
        current = warning;
      }
    }
    final stops = <(Color, double)>[(normal, 0)];
    if (descending) {
      stops
        ..[0] = (critical, 0)
        ..add((warning, _fraction(c)))
        ..add((normal, _fraction(w)));
    } else {
      if (w != null) stops.add((warning, _fraction(w)));
      if (c != null) stops.add((critical, _fraction(c)));
    }
    return _ZoneColors(current: current, stops: stops);
  }

  Widget _withLabels(BuildContext context, Widget gauge) {
    if (!_hasLabels) return gauge;
    final secondary = TextStyle(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_nonEmpty(widget.label))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(widget.label!),
          ),
        Row(
          children: [
            if (_nonEmpty(widget.minimumValueLabel))
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Text(widget.minimumValueLabel!, style: secondary),
              ),
            if (widget.style == CNGaugeStyle.rating)
              gauge
            else
              Expanded(child: gauge),
            if (_nonEmpty(widget.maximumValueLabel))
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Text(widget.maximumValueLabel!, style: secondary),
              ),
          ],
        ),
        if (_nonEmpty(widget.currentValueLabel))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(widget.currentValueLabel!, style: secondary),
          ),
      ],
    );
  }
}

class _ZoneColors {
  const _ZoneColors({required this.current, required this.stops});

  /// The colour for the current value.
  final Color current;

  /// Each zone's colour and the fraction of the range it starts at.
  final List<(Color, double)> stops;

  Gradient gradient({required bool sweep}) {
    final colors = <Color>[];
    final positions = <double>[];
    for (var i = 0; i < stops.length; i++) {
      final (color, from) = stops[i];
      final to = i + 1 < stops.length ? stops[i + 1].$2 : 1.0;
      colors
        ..add(color)
        ..add(color);
      positions
        ..add(from)
        ..add(to);
    }
    if (sweep) {
      return SweepGradient(
        colors: colors,
        stops: positions,
        startAngle: 0,
        endAngle: math.pi * 1.5,
        transform: const GradientRotation(math.pi * 0.75),
      );
    }
    return LinearGradient(colors: colors, stops: positions);
  }
}

/// The bar and line styles for iOS < 26 and other platforms.
class _FallbackBar extends StatelessWidget {
  const _FallbackBar({
    required this.fraction,
    required this.style,
    required this.colors,
  });

  final double fraction;
  final CNGaugeStyle style;
  final _ZoneColors colors;

  @override
  Widget build(BuildContext context) {
    final track = CupertinoColors.systemFill.resolveFrom(context);
    if (style == CNGaugeStyle.linear) {
      return SizedBox(
        height: 10,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: colors.gradient(sweep: false),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Positioned(
                left: (c.maxWidth - 10) * fraction,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: CupertinoColors.label.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final height = style == CNGaugeStyle.relevancy ? 6.0 : 14.0;
    final radius = BorderRadius.circular(height / 2);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: track, borderRadius: radius),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.current,
                borderRadius: radius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring styles for iOS < 26 and other platforms.
class _FallbackRing extends StatelessWidget {
  const _FallbackRing({
    required this.fraction,
    required this.style,
    required this.colors,
    this.current,
    this.minLabel,
    this.maxLabel,
  });

  final double fraction;
  final CNGaugeStyle style;
  final _ZoneColors colors;
  final String? current;
  final String? minLabel;
  final String? maxLabel;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoColors.label.resolveFrom(context);
    return SizedBox.square(
      dimension: 58,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: fraction,
          open: style == CNGaugeStyle.circular,
          colors: colors,
          track: CupertinoColors.systemFill.resolveFrom(context),
          marker: label,
        ),
        child: Center(
          child: Text(
            current ?? '',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: label,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.open,
    required this.colors,
    required this.track,
    required this.marker,
  });

  final double fraction;
  final bool open;
  final _ZoneColors colors;
  final Color track;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (open) {
      const start = math.pi * 0.75;
      const sweep = math.pi * 1.5;
      paint.shader = colors.gradient(sweep: true).createShader(rect);
      canvas.drawArc(arc, start, sweep, false, paint);
      final angle = start + sweep * fraction;
      final center = arc.center;
      final r = arc.width / 2;
      final dot = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      canvas.drawCircle(dot, stroke / 2 + 1, Paint()..color = marker);
      return;
    }
    paint.color = track;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint);
    paint.color = colors.current;
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * fraction, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction ||
      old.open != open ||
      old.colors.current != colors.current ||
      old.track != track ||
      old.marker != marker;
}

/// The rating for iOS < 26 and other platforms: stars, editable by a tap
/// or a horizontal drag when [onChanged] is set.
class _FallbackRating extends StatelessWidget {
  const _FallbackRating({
    required this.value,
    required this.max,
    this.color,
    this.onChanged,
  });

  final double value;
  final double max;
  final Color? color;
  final ValueChanged<double>? onChanged;

  static const double _star = 22;
  static const double _gap = 2;

  int get _count => max.floor().clamp(1, 100);

  void _set(double dx) {
    final onChanged = this.onChanged;
    if (onChanged == null) return;
    final rating = (dx / (_star + _gap)).ceilToDouble().clamp(0.0, max);
    if (rating != value) onChanged(rating);
  }

  @override
  Widget build(BuildContext context) {
    final filled = color ?? CupertinoColors.secondaryLabel.resolveFrom(context);
    final empty = CupertinoColors.tertiaryLabel.resolveFrom(context);
    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _count; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(end: i < _count - 1 ? _gap : 0),
            child: Icon(
              value >= i + 1
                  ? CupertinoIcons.star_fill
                  : value >= i + 0.5
                  ? CupertinoIcons.star_lefthalf_fill
                  : CupertinoIcons.star,
              size: _star,
              color: value >= i + 0.5 ? filled : empty,
            ),
          ),
      ],
    );
    if (onChanged == null) return stars;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _set(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => _set(d.localPosition.dx),
      child: stars,
    );
  }
}
