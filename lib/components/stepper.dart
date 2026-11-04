import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../channel/params.dart';
import '../utils/version_detector.dart';
import '../utils/theme_helper.dart';
import '../utils/modal_hide_mixin.dart';

/// A Cupertino-native stepper: a − / + control that changes a number by a
/// fixed [step].
///
/// On iOS 26+ this embeds the system stepper through a platform view, as a
/// SwiftUI `Stepper`: it draws the same control as `UIStepper`, which on
/// iOS 26+ ignores a tint and has no disabled look. On every macOS it
/// embeds an `NSStepper` (the small up/down arrows that sit next to a text
/// field). Below iOS 26 and on other platforms it draws a Flutter stepper
/// shaped like the iOS 18 `UIStepper`.
///
/// The stepper shows no number of its own; put the value in a label next to
/// it, as iOS does:
///
/// ```dart
/// Row(
///   children: [
///     Text('Guests: ${guests.toInt()}'),
///     const Spacer(),
///     CNStepper(
///       value: guests,
///       min: 1,
///       max: 12,
///       semanticLabel: 'Guests',
///       onChanged: (v) => setState(() => guests = v),
///     ),
///   ],
/// )
/// ```
///
/// VoiceOver reads the stepper as one adjustable element, its
/// [semanticLabel] followed by the value ("Guests, 3"); swiping up or down
/// changes the value by [step].
class CNStepper extends StatefulWidget {
  /// Creates a Cupertino-native stepper.
  const CNStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 100.0,
    this.step = 1.0,
    this.wraps = false,
    this.autorepeat = true,
    this.enabled = true,
    this.color,
    this.autoHideOnModal = true,
    this.semanticLabel,
  }) : assert(min < max, 'CNStepper.min must be less than max'),
       assert(step > 0, 'CNStepper.step must be greater than 0');

  /// Current value. Values outside [min]..[max] are clamped.
  final double value;

  /// Called with the new value when the user taps − or +.
  final ValueChanged<double> onChanged;

  /// Lowest value. Must be less than [max]. Defaults to 0, as `UIStepper`.
  final double min;

  /// Highest value. Must be greater than [min]. Defaults to 100, as
  /// `UIStepper`.
  final double max;

  /// Amount one tap adds or subtracts. Must be greater than 0.
  final double step;

  /// When true, + at [max] goes to [min] and − at [min] goes to [max].
  /// When false (default), the button at the limit is disabled.
  final bool wraps;

  /// When true (default), holding − or + keeps changing the value while it
  /// is held. When false, each press changes it once.
  final bool autorepeat;

  /// Whether the control is interactive.
  final bool enabled;

  /// Tint of the stepper. Null keeps the system colours.
  ///
  /// On iOS 26+ it colours the − and + symbols and gives the capsule a light
  /// wash of the colour; the Flutter fallback colours the symbols.
  /// `NSStepper` has no tint, so it is ignored on macOS.
  final Color? color;

  /// When true (default), destroys the native stepper's PlatformView while a
  /// modal sheet is presented above this widget's host route. Prevents the
  /// iOS hybrid-composition z-order bleed (Issue #53) where the host-page
  /// PlatformView's pixels leak through a sheet that also contains a
  /// PlatformView (CN-widget). Requires `CNTabBarRouteObserver()` to be
  /// registered in the app's `navigatorObservers`. No effect on non-iOS or
  /// iOS < 26 (Flutter fallback path).
  final bool autoHideOnModal;

  /// What VoiceOver reads for the stepper, before its value.
  ///
  /// A native stepper cannot borrow the text next to it the way a Flutter
  /// widget in `MergeSemantics` can, so without this VoiceOver announces only
  /// the number. Pass the same text as its visible label, e.g. `'Guests'`.
  final String? semanticLabel;

  @override
  State<CNStepper> createState() => _CNStepperState();
}

/// Size of the iOS stepper, in logical pixels: the native one on iOS 26+
/// (about 92 x 32) and the iOS 18 one the fallback copies.
const Size _kIOSStepperSize = Size(94, 32);

/// Size of the box an `NSStepper` is centred in on macOS.
const Size _kMacOSStepperSize = Size(24, 28);

class _CNStepperState extends State<CNStepper> with ModalHideMixin<CNStepper> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;

  double? _lastValue;
  double? _lastMin;
  double? _lastMax;
  double? _lastStep;
  bool? _lastWraps;
  bool? _lastAutorepeat;
  bool? _lastEnabled;
  String? _lastSemanticLabel;
  bool? _lastIsDark;
  int? _lastTint;
  bool get _isDark => ThemeHelper.isDark(context);

  double get _clampedValue =>
      widget.value.clamp(widget.min, widget.max).toDouble();

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CNStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeControls;

    // Flutter has no stepper, so every platform without the native one gets
    // the same Cupertino-shaped fallback.
    if (!shouldUseNative) {
      return _CNFallbackStepper(
        value: _clampedValue,
        min: widget.min,
        max: widget.max,
        step: widget.step,
        wraps: widget.wraps,
        autorepeat: widget.autorepeat,
        enabled: widget.enabled,
        color: widget.color,
        semanticLabel: widget.semanticLabel,
        onChanged: widget.onChanged,
      );
    }

    const viewType = 'CupertinoNativeStepper';
    // Platform views expand to the biggest size in unconstrained axes, so a
    // stepper in a Row would try to grow to Infinity. The native stepper has
    // a fixed size; give the view that size.
    final size = defaultTargetPlatform == TargetPlatform.macOS
        ? _kMacOSStepperSize
        : _kIOSStepperSize;

    // Issue #53 fix: when a modal is presented above our host route, destroy
    // the native stepper to remove its PlatformView from the shared iOS
    // PlatformView container.
    final hidden = maybeHiddenPlaceholder(
      height: size.height,
      width: size.width,
    );
    if (hidden != null) return hidden;

    final creationParams = <String, dynamic>{
      'value': _clampedValue,
      'min': widget.min,
      'max': widget.max,
      'step': widget.step,
      'wraps': widget.wraps,
      'autorepeat': widget.autorepeat,
      'enabled': widget.enabled,
      if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
      'isDark': _isDark,
      'style': encodeStyle(context, tint: widget.color),
    };

    // Taps only: a stepper has no drag, and claiming horizontal drags would
    // stop a surrounding horizontal scroll view.
    final gestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
      Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
      // Press-and-hold autorepeat needs the touch to stay with the stepper.
      Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer()),
    };

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return wrapWithModalInteractionGuard(
        ClipRect(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: UiKitView(
              viewType: viewType,
              creationParamsCodec: const StandardMessageCodec(),
              creationParams: creationParams,
              onPlatformViewCreated: _onPlatformViewCreated,
              gestureRecognizers: gestureRecognizers,
            ),
          ),
        ),
      );
    }

    // macOS
    return ClipRect(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: AppKitView(
          viewType: viewType,
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: creationParams,
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: gestureRecognizers,
        ),
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('CupertinoNativeStepper_$id');
    _channel = channel;
    channel.setMethodCallHandler(_onMethodCall);
    _cacheCurrentProps();
    _syncBrightnessIfNeeded();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'valueChanged') {
      final args = call.arguments as Map?;
      final value = (args?['value'] as num?)?.toDouble();
      if (value != null) {
        // Remember it first, so the rebuild the parent does in onChanged
        // does not send the same value back.
        _lastValue = value;
        widget.onChanged(value);
      }
    }
    return null;
  }

  void _cacheCurrentProps() {
    _lastValue = _clampedValue;
    _lastMin = widget.min;
    _lastMax = widget.max;
    _lastStep = widget.step;
    _lastWraps = widget.wraps;
    _lastAutorepeat = widget.autorepeat;
    _lastEnabled = widget.enabled;
    _lastSemanticLabel = widget.semanticLabel;
    _lastIsDark = _isDark;
    _lastTint = resolveColorToArgb(widget.color, context);
  }

  /// Sends [method] to the native view, ignoring the error a view that has
  /// just been destroyed (e.g. hidden under a sheet) answers with. A view
  /// created again gets the current values from its creation params.
  Future<void> _invoke(
    MethodChannel channel,
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      await channel.invokeMethod(method, args);
    } catch (_) {}
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;

    // Resolve theme-dependent values before awaiting.
    final int? tint = resolveColorToArgb(widget.color, context);
    final double value = _clampedValue;

    // The range goes first, so the value is not clamped to the old one.
    if (_lastMin != widget.min || _lastMax != widget.max) {
      _lastMin = widget.min;
      _lastMax = widget.max;
      await _invoke(channel, 'setRange', {
        'min': widget.min,
        'max': widget.max,
      });
    }

    if (_lastStep != widget.step) {
      _lastStep = widget.step;
      await _invoke(channel, 'setStep', {'step': widget.step});
    }

    if (_lastWraps != widget.wraps || _lastAutorepeat != widget.autorepeat) {
      _lastWraps = widget.wraps;
      _lastAutorepeat = widget.autorepeat;
      await _invoke(channel, 'setOptions', {
        'wraps': widget.wraps,
        'autorepeat': widget.autorepeat,
      });
    }

    if (_lastValue != value) {
      _lastValue = value;
      await _invoke(channel, 'setValue', {'value': value});
    }

    if (_lastEnabled != widget.enabled) {
      _lastEnabled = widget.enabled;
      await _invoke(channel, 'setEnabled', {'enabled': widget.enabled});
    }

    if (_lastSemanticLabel != widget.semanticLabel) {
      _lastSemanticLabel = widget.semanticLabel;
      await _invoke(channel, 'setSemanticLabel', {
        'label': widget.semanticLabel,
      });
    }

    // A null tint restores the system colour.
    if (_lastTint != tint) {
      _lastTint = tint;
      await _invoke(channel, 'setStyle', {'tint': tint});
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    final isDark = _isDark;
    final int? tint = resolveColorToArgb(widget.color, context);

    if (_lastIsDark != isDark) {
      _lastIsDark = isDark;
      await _invoke(channel, 'setBrightness', {'isDark': isDark});
    }

    // A dynamic colour resolves differently in the new brightness.
    if (_lastTint != tint) {
      _lastTint = tint;
      await _invoke(channel, 'setStyle', {'tint': tint});
    }
  }
}

/// Formats a stepper value for reading aloud: no decimals for whole steps,
/// otherwise as many as [step] has.
String _formatStepperValue(double value, double step) {
  var decimals = 0;
  var scaled = step;
  while (decimals < 6 && (scaled - scaled.roundToDouble()).abs() > 1e-9) {
    scaled *= 10;
    decimals++;
  }
  return value.toStringAsFixed(decimals);
}

/// The stepper drawn in Flutter, shaped like the iOS 18 `UIStepper`: a
/// rounded grey box split into − and + halves.
class _CNFallbackStepper extends StatefulWidget {
  const _CNFallbackStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.wraps,
    required this.autorepeat,
    required this.enabled,
    required this.color,
    required this.semanticLabel,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final bool wraps;
  final bool autorepeat;
  final bool enabled;
  final Color? color;
  final String? semanticLabel;
  final ValueChanged<double> onChanged;

  @override
  State<_CNFallbackStepper> createState() => _CNFallbackStepperState();
}

class _CNFallbackStepperState extends State<_CNFallbackStepper> {
  /// -1 while − is held, 1 while + is held, 0 otherwise.
  int _pressed = 0;
  Timer? _repeat;
  int _repeats = 0;

  /// The value autorepeat continues from. The parent rebuilds with each new
  /// value, but it may do so a frame late, so it is not read from [widget].
  double _current = 0;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  bool _canStep(int direction) {
    if (!widget.enabled) return false;
    if (widget.wraps) return true;
    return direction < 0
        ? widget.value > widget.min
        : widget.value < widget.max;
  }

  /// The value one step from [from] in [direction], wrapped or clamped like
  /// `UIStepper`.
  double _next(double from, int direction) {
    var next = from + direction * widget.step;
    if (next > widget.max) return widget.wraps ? widget.min : widget.max;
    if (next < widget.min) return widget.wraps ? widget.max : widget.min;
    // Drop floating-point noise, so 0.1 + 0.2 stays 0.3, as on iOS.
    next = (next * 1e9).roundToDouble() / 1e9;
    return next;
  }

  void _stepOnce(int direction) {
    final next = _next(_current, direction);
    if (next == _current) return;
    _current = next;
    widget.onChanged(next);
  }

  void _onDown(int direction) {
    if (!_canStep(direction)) return;
    setState(() => _pressed = direction);
    _current = widget.value;
    _stepOnce(direction);
    if (!widget.autorepeat) return;
    // Like UIStepper: start repeating after half a second, then speed up.
    _repeats = 0;
    _repeat = Timer(const Duration(milliseconds: 500), () => _tick(direction));
  }

  void _tick(int direction) {
    if (!mounted || _pressed != direction) return;
    _stepOnce(direction);
    _repeats++;
    final interval = _repeats < 10
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 50);
    _repeat = Timer(interval, () => _tick(direction));
  }

  void _onUp() {
    _repeat?.cancel();
    _repeat = null;
    if (_pressed != 0) setState(() => _pressed = 0);
  }

  Widget _half(int direction) {
    final enabled = _canStep(direction);
    final glyphColor = enabled
        ? (widget.color ?? CupertinoColors.label)
        : CupertinoColors.tertiaryLabel;
    // Like UIStepper, the value changes on touch down and keeps changing
    // while the finger stays. No long-press recognizer here: it would win
    // the arena after half a second and cancel the tap that drives the
    // repeat. A surrounding scroll view that takes the drag cancels it too.
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onDown(direction),
        onTapUp: (_) => _onUp(),
        onTapCancel: _onUp,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // The held half darkens, as on iOS 18.
            color: _pressed == direction
                ? CupertinoDynamicColor.resolve(
                    CupertinoColors.tertiarySystemFill,
                    context,
                  )
                : null,
            borderRadius: direction < 0
                ? const BorderRadius.horizontal(left: Radius.circular(8))
                : const BorderRadius.horizontal(right: Radius.circular(8)),
          ),
          child: Center(
            child: _StepperGlyph(
              plus: direction > 0,
              color: CupertinoDynamicColor.resolve(glyphColor, context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemFill,
      context,
    );
    final divider = CupertinoDynamicColor.resolve(
      CupertinoColors.separator,
      context,
    );
    final text = _formatStepperValue(widget.value, widget.step);
    final canDecrease = _canStep(-1);
    final canIncrease = _canStep(1);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: text,
      enabled: widget.enabled,
      increasedValue: canIncrease
          ? _formatStepperValue(_next(widget.value, 1), widget.step)
          : null,
      decreasedValue: canDecrease
          ? _formatStepperValue(_next(widget.value, -1), widget.step)
          : null,
      onIncrease: canIncrease
          ? () => widget.onChanged(_next(widget.value, 1))
          : null,
      onDecrease: canDecrease
          ? () => widget.onChanged(_next(widget.value, -1))
          : null,
      child: ExcludeSemantics(
        child: Container(
          width: _kIOSStepperSize.width,
          height: _kIOSStepperSize.height,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _half(-1),
              Container(width: 1, height: 18, color: divider),
              _half(1),
            ],
          ),
        ),
      ),
    );
  }
}

/// A − or + drawn with boxes, so it needs no icon font.
class _StepperGlyph extends StatelessWidget {
  const _StepperGlyph({required this.plus, required this.color});

  final bool plus;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: 14, height: 2, child: bar),
          if (plus) SizedBox(width: 2, height: 14, child: bar),
        ],
      ),
    );
  }
}
