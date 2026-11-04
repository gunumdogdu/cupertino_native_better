import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, LinearProgressIndicator;
import 'package:flutter/services.dart';

import '../channel/params.dart';
import '../style/control_size.dart';
import '../utils/modal_hide_mixin.dart';
import '../utils/optional_method_call.dart';
import '../utils/theme_helper.dart';
import '../utils/version_detector.dart';

/// How a [CNProgressIndicator] shows progress.
enum CNProgressStyle {
  /// A horizontal bar that fills from the leading edge.
  bar,

  /// A circular indicator: the spinning activity indicator, or on macOS a
  /// filling circle when the progress is known.
  spinner,
}

/// A native progress indicator: a bar that fills as work completes, or a
/// spinner for work of unknown length.
///
/// Pass a [value] from 0 to 1 when the progress is known (determinate), or
/// leave it null for an indeterminate indicator. Changes of [value] animate
/// natively.
///
/// | | macOS | iOS 26+ | iOS < 26 | other platforms |
/// |---|---|---|---|---|
/// | bar, value | `NSProgressIndicator` bar | `UIProgressView` | Flutter bar | `LinearProgressIndicator` |
/// | bar, no value | moving bar | `UIActivityIndicatorView` | `CupertinoActivityIndicator` | `LinearProgressIndicator` |
/// | spinner, value | filling circle | `UIActivityIndicatorView` | `CupertinoActivityIndicator` | `CircularProgressIndicator` |
/// | spinner, no value | spinning indicator | `UIActivityIndicatorView` | `CupertinoActivityIndicator` | `CircularProgressIndicator` |
///
/// On macOS (every supported version) the indicator is AppKit's, drawn by
/// SwiftUI's `ProgressView`, which also tints it. iOS has no indeterminate
/// bar and no filling circle, so there those show the activity indicator.
///
/// A bar takes the width of its parent (160 points when the parent is
/// unbounded) and the native height; a spinner is a fixed square.
///
/// VoiceOver reads [semanticLabel] with the progress as a percentage
/// ("Upload, 40 percent").
class CNProgressIndicator extends StatefulWidget {
  /// Creates a native progress indicator.
  const CNProgressIndicator({
    super.key,
    this.value,
    this.style = CNProgressStyle.bar,
    this.tint,
    this.size,
    this.semanticLabel,
    this.autoHideOnModal = true,
  });

  /// Progress from 0 to 1, or null when it is not known. Values outside
  /// 0..1 are clamped.
  final double? value;

  /// Bar or spinner.
  final CNProgressStyle style;

  /// Colour of the filled part of the bar and of the spinner. Null keeps the
  /// system colour (the accent colour for a bar, grey for a spinner).
  ///
  /// macOS tints the bar and the filling circle; its spinning indicator is
  /// always grey.
  final Color? tint;

  /// Size class of the indicator; null is [CNControlSize.regular].
  ///
  /// macOS uses it as `controlSize`. On iOS a spinner is the medium
  /// activity indicator up to [CNControlSize.regular] and the large one
  /// above it; a bar has one size.
  final CNControlSize? size;

  /// What VoiceOver reads for the indicator, before its progress.
  final String? semanticLabel;

  /// When true (default), replaces the native view with an empty box of the
  /// same size while a modal sheet covers it (Issue #53). Requires
  /// `CNTabBarRouteObserver()` in the app's `navigatorObservers`.
  final bool autoHideOnModal;

  @override
  State<CNProgressIndicator> createState() => _CNProgressIndicatorState();
}

/// Width of a bar whose parent gives it no width.
const double _kUnboundedBarWidth = 160;

/// Height of the box a native bar is centred in. macOS: the
/// `NSProgressIndicator` bar's own height for each control size. iOS: the
/// `UIProgressView` track.
double _barHeight(CNControlSize size) {
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    return size == CNControlSize.mini || size == CNControlSize.small ? 12 : 20;
  }
  return 4;
}

/// Side of a native spinner. macOS: `NSProgressIndicator`'s spinning sizes
/// (an indeterminate mini one is smaller than a determinate one). iOS:
/// `UIActivityIndicatorView` medium and large.
double _spinnerSide(CNControlSize size, {required bool determinate}) {
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    switch (size) {
      case CNControlSize.mini:
        return determinate ? 16 : 10;
      case CNControlSize.small:
        return 16;
      case CNControlSize.regular:
      case CNControlSize.large:
      case CNControlSize.extraLarge:
        return 32;
    }
  }
  return _iosLargeSpinner(size) ? 37 : 20;
}

bool _iosLargeSpinner(CNControlSize size) =>
    size == CNControlSize.large || size == CNControlSize.extraLarge;

class _CNProgressIndicatorState extends State<CNProgressIndicator>
    with ModalHideMixin<CNProgressIndicator> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;
  double? _lastValue;
  Map<String, Object?>? _lastConfig;
  bool? _lastIsDark;

  double? get _value => widget.value?.clamp(0.0, 1.0).toDouble();

  CNControlSize get _size => widget.size ?? CNControlSize.regular;

  bool get _useNative {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return apple && PlatformVersion.shouldUseNativeControls;
  }

  /// Whether the native view is a bar: iOS has no indeterminate bar and
  /// shows its activity indicator instead.
  bool get _nativeBar =>
      widget.style == CNProgressStyle.bar &&
      (defaultTargetPlatform == TargetPlatform.macOS || _value != null);

  /// The options that are not the value, sent whole when one changes.
  Map<String, Object?> _config(BuildContext context) => <String, Object?>{
    'style': widget.style.name,
    'tint': resolveColorToArgb(widget.tint, context),
    'controlSize': _size.name,
    'semanticLabel': widget.semanticLabel,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToNative();
  }

  @override
  void didUpdateWidget(covariant CNProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncToNative();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('CupertinoNativeProgressIndicator_$id');
    _lastValue = _value;
    _lastConfig = _config(context);
    _lastIsDark = ThemeHelper.isDark(context);
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
          .invokeOptionalMethod('setBrightness', {'isDark': isDark})
          .catchError((_) {});
    }
    final config = _config(context);
    if (!mapEquals(config, _lastConfig)) {
      _lastConfig = config;
      channel.invokeOptionalMethod('setConfig', config).catchError((_) {});
    }
    final value = _value;
    if (value != _lastValue) {
      _lastValue = value;
      channel
          .invokeOptionalMethod('setValue', {'value': value, 'animated': true})
          .catchError((_) {});
    }
  }

  /// The progress as VoiceOver reads it.
  String? get _semanticValue {
    final value = _value;
    return value == null ? null : '${(value * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    if (!_useNative) return _buildFallback(context);

    final determinate = _value != null;
    final Size size = _nativeBar
        ? Size(double.infinity, _barHeight(_size))
        : Size.square(_spinnerSide(_size, determinate: determinate));

    final hidden = maybeHiddenPlaceholder(
      height: size.height,
      width: size.width,
    );
    if (hidden != null) return _sized(size, hidden);

    final creationParams = <String, dynamic>{
      ..._config(context),
      'value': _value,
      'isDark': ThemeHelper.isDark(context),
    };

    final platformView = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: 'CupertinoNativeProgressIndicator',
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        : AppKitView(
            viewType: 'CupertinoNativeProgressIndicator',
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          );

    return wrapWithModalInteractionGuard(_sized(size, platformView));
  }

  /// Gives [child] the indicator's size; an infinite width becomes the
  /// parent's width, or [_kUnboundedBarWidth] in an unbounded parent.
  Widget _sized(Size size, Widget child) {
    final box = SizedBox(width: size.width, height: size.height, child: child);
    if (size.width.isFinite) return box;
    return LimitedBox(maxWidth: _kUnboundedBarWidth, child: box);
  }

  Widget _buildFallback(BuildContext context) {
    final value = _value;
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    final Widget indicator;
    if (!isApple) {
      indicator = widget.style == CNProgressStyle.bar
          ? _sized(
              const Size(double.infinity, 4),
              LinearProgressIndicator(value: value, color: widget.tint),
            )
          : SizedBox.square(
              dimension: _iosLargeSpinner(_size) ? 40 : 24,
              child: CircularProgressIndicator(
                value: value,
                color: widget.tint,
                strokeWidth: _iosLargeSpinner(_size) ? 4 : 3,
              ),
            );
    } else if (widget.style == CNProgressStyle.bar && value != null) {
      indicator = _sized(
        const Size(double.infinity, 4),
        _CupertinoProgressBar(
          value: value,
          color: widget.tint ?? ThemeHelper.getPrimaryColor(context),
        ),
      );
    } else {
      // As iOS: the activity indicator for every progress but a known bar.
      indicator = CupertinoActivityIndicator(
        radius: _iosLargeSpinner(_size) ? 18.5 : 10,
        color: widget.tint,
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      value: _semanticValue,
      child: ExcludeSemantics(child: indicator),
    );
  }
}

/// The iOS progress bar for iOS < 26: a rounded track that fills with
/// [color], animating changes as `UIProgressView.setProgress(_:animated:)`.
class _CupertinoProgressBar extends StatelessWidget {
  const _CupertinoProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final track = CupertinoColors.systemFill.resolveFrom(context);
    final radius = BorderRadius.circular(2);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      builder: (context, animated, _) => DecoratedBox(
        decoration: BoxDecoration(color: track, borderRadius: radius),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: animated,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: radius),
            ),
          ),
        ),
      ),
    );
  }
}
