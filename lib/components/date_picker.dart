import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show MaterialLocalizations, TimeOfDay;
import 'package:flutter/services.dart';
import '../channel/params.dart';
import '../utils/version_detector.dart';
import '../utils/theme_helper.dart';
import '../utils/modal_hide_mixin.dart';

/// What a [CNDatePicker] lets the user pick.
enum CNDatePickerMode {
  /// A calendar day. The time of day of [CNDatePicker.value] is kept.
  date,

  /// A time of day, in hours and minutes. The day of [CNDatePicker.value] is
  /// kept.
  time,

  /// A day and a time of day.
  dateAndTime,

  /// A month and a year, with no day.
  ///
  /// `UIDatePicker` supports this mode (iOS 17.4+) only as wheels, so a picker
  /// in this mode is always shown as [CNDatePickerStyle.wheels], whatever its
  /// [CNDatePicker.style]. On macOS it shows the month and year fields of
  /// `NSDatePicker`, and the Flutter fallback uses
  /// [CupertinoDatePickerMode.monthYear]. [CNDatePicker.onChanged] gets the
  /// first day of the chosen month at midnight.
  yearAndMonth,
}

/// How a [CNDatePicker] is drawn.
///
/// On iOS these are the `UIDatePickerStyle` values. macOS has no wheels and
/// no compact pill; there [compact] and [wheels] use `NSDatePicker`'s text
/// field and stepper ([compact] with its calendar overlay), and [inline] its
/// clock and calendar.
enum CNDatePickerStyle {
  /// Lets the platform choose. For every [CNDatePickerMode] but
  /// [CNDatePickerMode.yearAndMonth] this is [compact], as it is in UIKit.
  automatic,

  /// A pill showing the value, which opens the picker in a popover when
  /// tapped. Below iOS 26 the pill opens a [CupertinoDatePicker] in a popup.
  compact,

  /// A calendar shown in place, with a time row below it in
  /// [CNDatePickerMode.dateAndTime]. It fills the width it is given, and its
  /// height follows that width (354 points at 362 wide on iOS 27). Below
  /// iOS 26 this is a [CupertinoDatePicker], as Flutter has no Cupertino
  /// calendar.
  inline,

  /// Spinning wheels, 216 points tall.
  wheels,
}

/// A Cupertino-native date and time picker rendered by the host platform.
///
/// On iOS 26+ this embeds a `UIDatePicker`, and on macOS 26+ an
/// `NSDatePicker`, through a platform view. Below 26 and on other platforms
/// it falls back to [CupertinoDatePicker]: as wheels for
/// [CNDatePickerStyle.wheels] and [CNDatePickerStyle.inline], and for
/// [CNDatePickerStyle.compact] as a pill that opens one in a popup.
///
/// ## Time zones
///
/// The picker shows and edits the wall-clock fields of [value] in the zone of
/// [value]: a local [DateTime] in the device's time zone, a UTC one
/// (`DateTime.utc`) in UTC. [onChanged] returns a [DateTime] in that same
/// zone, so `DateTime.utc(2026, 11, 3)` shows November 3 everywhere and
/// stays UTC. [minimumDate] and [maximumDate] are compared as instants,
/// whatever their zone.
///
/// ## Size
///
/// The compact pill and the wheels have the size the platform gives them;
/// the pill's width follows the value. An inline calendar fills the width it
/// is given, and its height follows that width; should a UIKit version
/// change it with the shown month's week rows, that is followed too. The
/// native view reports its size and this widget takes it, so the picker can
/// go in a [Row] or a [Column] without a fixed size. A compact picker in a box wider than its
/// pill, such as a [ListView] row, sits at the start of it.
class CNDatePicker extends StatefulWidget {
  /// Creates a Cupertino-native date picker.
  const CNDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.mode = CNDatePickerMode.date,
    this.style = CNDatePickerStyle.automatic,
    this.minimumDate,
    this.maximumDate,
    this.minuteInterval = 1,
    this.tint,
    this.enabled = true,
    this.locale,
    this.semanticLabel,
    this.autoHideOnModal = true,
  }) : assert(
         minuteInterval >= 1 &&
             minuteInterval <= 30 &&
             60 % minuteInterval == 0,
         'minuteInterval must be between 1 and 30 and divide 60',
       );

  /// The selected date and time.
  ///
  /// Its zone decides the zone the picker works in; see the class
  /// documentation.
  final DateTime value;

  /// Called when the user changes the value, with the new value in the zone
  /// of [value].
  ///
  /// In [CNDatePickerMode.date] the time of day of [value] is kept, in
  /// [CNDatePickerMode.time] its day; seconds are cleared in the modes that
  /// show a time.
  final ValueChanged<DateTime> onChanged;

  /// What the picker lets the user pick.
  final CNDatePickerMode mode;

  /// How the picker is drawn.
  ///
  /// [CNDatePickerMode.yearAndMonth] is always drawn as
  /// [CNDatePickerStyle.wheels].
  final CNDatePickerStyle style;

  /// The earliest value the user can pick, or null for no limit.
  ///
  /// In [CNDatePickerMode.time], use a limit on the same day as [value], as
  /// `UIDatePicker` and [CupertinoDatePicker] do.
  final DateTime? minimumDate;

  /// The latest value the user can pick, or null for no limit.
  final DateTime? maximumDate;

  /// The step of the minute wheel or field, from 1 to 30. It must divide 60.
  ///
  /// macOS has no minute step; there the value is rounded to it after each
  /// change.
  final int minuteInterval;

  /// Accent color of the picker: the selected day, the open pill and the
  /// calendar's arrows. Defaults to the theme's primary color.
  ///
  /// `NSDatePicker` has no accent of its own; on macOS it follows the
  /// system accent color.
  final Color? tint;

  /// Whether the user can change the value.
  final bool enabled;

  /// The locale the native picker formats in: month names, the order of the
  /// fields, and 12- or 24-hour time.
  ///
  /// Null (the default) follows the device, as a native picker does. Pass
  /// `Localizations.localeOf(context)` to follow the app's locale instead.
  /// The Flutter fallback always follows the app's [Localizations].
  final Locale? locale;

  /// What VoiceOver reads for the picker.
  ///
  /// The native picker reads its value by itself, but not what it is for.
  /// Pass the same text as its visible label, e.g. `'Birthday'`.
  final String? semanticLabel;

  /// When true (default), destroys the native picker's PlatformView while a
  /// modal sheet is presented above this widget's host route. Prevents the
  /// iOS hybrid-composition z-order bleed (Issue #53) where the host-page
  /// PlatformView's pixels leak through a sheet that also contains a
  /// PlatformView (CN-widget). Requires `CNTabBarRouteObserver()` to be
  /// registered in the app's `navigatorObservers`. No effect on non-iOS or
  /// iOS < 26 (Flutter fallback path).
  final bool autoHideOnModal;

  @override
  State<CNDatePicker> createState() => _CNDatePickerState();
}

/// The part of a value a fallback pill shows and edits.
enum _PillPart { date, time }

class _CNDatePickerState extends State<CNDatePicker>
    with ModalHideMixin<CNDatePicker> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;

  int? _lastValueMs;
  bool? _lastUtc;
  CNDatePickerMode? _lastMode;
  int? _lastMinimumMs;
  int? _lastMaximumMs;
  int? _lastMinuteInterval;
  bool? _lastEnabled;
  String? _lastSemanticLabel;
  String? _lastLocale;
  bool? _lastIsDark;
  int? _lastTint;
  bool get _isDark => ThemeHelper.isDark(context);

  /// The size the native view reported for itself, or null before it has.
  Size? _nativeSize;

  /// Bumped to rebuild the fallback [CupertinoDatePicker], which reads its
  /// initial value only once, when [CNDatePicker.value] changes from outside.
  int _fallbackGeneration = 0;

  /// The value the fallback picker shows, to tell outside changes from the
  /// ones it reported itself.
  DateTime? _fallbackShown;

  /// The fallback pill whose popup is open, drawn in the tint like the
  /// native pill.
  _PillPart? _openPill;

  Color? get _effectiveTint =>
      widget.tint ?? ThemeHelper.getPrimaryColor(context);

  bool get _utc => widget.value.isUtc;

  String? get _localeTag => widget.locale?.toLanguageTag();

  CNDatePickerStyle get _effectiveStyle => _styleOf(widget);

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CNDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleOf(oldWidget) != _effectiveStyle) {
      // A new style is a new platform view (see the key in build), created
      // with the current values and measuring itself again. The old view
      // gets no more calls, and its last size reports are not listened to.
      _nativeSize = null;
      _channel?.setMethodCallHandler(null);
      _channel = null;
    }
    _syncFallbackIfNeeded(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  /// The style [w] is drawn in: `automatic` resolved the way UIKit resolves
  /// it, and year-and-month forced to wheels, the only style UIKit allows
  /// for it.
  CNDatePickerStyle _styleOf(CNDatePicker w) {
    if (w.mode == CNDatePickerMode.yearAndMonth) {
      return CNDatePickerStyle.wheels;
    }
    if (w.style == CNDatePickerStyle.automatic) {
      return CNDatePickerStyle.compact;
    }
    return w.style;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.minimumDate == null ||
          widget.maximumDate == null ||
          !widget.minimumDate!.isAfter(widget.maximumDate!),
      'minimumDate must not be after maximumDate',
    );

    // Check if we should use native platform view
    final isIOSOrMacOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final shouldUseNative =
        isIOSOrMacOS && PlatformVersion.shouldUseNativeGlass;

    // Fallback to Flutter widgets for non-iOS/macOS or iOS/macOS < 26. Unlike
    // the switch and slider, the fallback stays Cupertino on every platform:
    // there is no Material date picker that can be shown in place.
    if (!shouldUseNative) {
      return _labelled(
        _effectiveStyle == CNDatePickerStyle.compact
            ? _buildFallbackPills(context)
            : _buildFallbackWheels(context),
      );
    }

    const viewType = 'CupertinoNativeDatePicker';
    final style = _effectiveStyle;

    // Issue #53 fix: when a modal is presented above our host route, destroy
    // the native UIDatePicker to remove its PlatformView from the shared iOS
    // PlatformView container. Otherwise hybrid-composition z-order desyncs
    // with the sheet's PlatformView during drag, causing visual bleed.
    final hidden = maybeHiddenPlaceholder(
      height: _nativeHeight(style),
      width: style == CNDatePickerStyle.compact
          ? _nativeWidth(style)
          : double.infinity,
    );
    if (hidden != null) return _sizeNative(style, hidden);

    final creationParams = <String, dynamic>{
      'value': widget.value.millisecondsSinceEpoch,
      'utc': _utc,
      'mode': widget.mode.name,
      'pickerStyle': style.name,
      if (widget.minimumDate != null)
        'minimumDate': widget.minimumDate!.millisecondsSinceEpoch,
      if (widget.maximumDate != null)
        'maximumDate': widget.maximumDate!.millisecondsSinceEpoch,
      'minuteInterval': widget.minuteInterval,
      'enabled': widget.enabled,
      if (_localeTag != null) 'locale': _localeTag,
      if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
      'isDark': _isDark,
      'style': encodeStyle(context, tint: _effectiveTint),
    };

    // Which drags reach the native picker: the wheels spin vertically, the
    // inline calendar pages sideways, and the compact pill only needs taps.
    final gestures = <Factory<OneSequenceGestureRecognizer>>{
      Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
      if (style == CNDatePickerStyle.wheels)
        Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
        ),
      if (style == CNDatePickerStyle.inline)
        Factory<HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
        ),
    };

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return wrapWithModalInteractionGuard(
        _sizeNative(
          style,
          ClipRect(
            child: UiKitView(
              // The style decides how the native view lays the picker out,
              // so a new style is a new view.
              key: ValueKey<CNDatePickerStyle>(style),
              viewType: viewType,
              creationParamsCodec: const StandardMessageCodec(),
              creationParams: creationParams,
              onPlatformViewCreated: _onPlatformViewCreated,
              gestureRecognizers: gestures,
            ),
          ),
        ),
      );
    }

    // macOS
    return _sizeNative(
      style,
      ClipRect(
        child: AppKitView(
          key: ValueKey<CNDatePickerStyle>(style),
          viewType: viewType,
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: creationParams,
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: gestures,
        ),
      ),
    );
  }

  /// Width of the native view until it reports its own. The estimates are
  /// what iOS 27 measures in English.
  double _nativeWidth(CNDatePickerStyle style) {
    final reported = _nativeSize?.width;
    if (reported != null && reported > 0) return reported;
    if (style != CNDatePickerStyle.compact) return 320;
    return switch (widget.mode) {
      CNDatePickerMode.time => 70,
      CNDatePickerMode.dateAndTime => 188,
      _ => 114,
    };
  }

  /// Height of the native view until it reports its own.
  double _nativeHeight(CNDatePickerStyle style) {
    final reported = _nativeSize?.height;
    if (reported != null && reported > 0) return reported;
    return switch (style) {
      CNDatePickerStyle.wheels => 216,
      CNDatePickerStyle.inline =>
        widget.mode == CNDatePickerMode.dateAndTime ? 464 : 354,
      _ => 36,
    };
  }

  /// Gives the platform view a finite size.
  ///
  /// Platform views expand to the biggest size in unconstrained axes, so in a
  /// Row the width could be Infinity. The pill gets the width the native view
  /// reported; wheels and calendars fill the width they are given, or the
  /// reported one where it is unbounded.
  Widget _sizeNative(CNDatePickerStyle style, Widget child) {
    final height = _nativeHeight(style);
    if (style == CNDatePickerStyle.compact) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox(
          width: _nativeWidth(style),
          height: height,
          child: child,
        ),
      );
    }
    return LimitedBox(
      maxWidth: _nativeWidth(style),
      child: SizedBox(width: double.infinity, height: height, child: child),
    );
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('CupertinoNativeDatePicker_$id');
    _channel = channel;
    channel.setMethodCallHandler(_onMethodCall);
    _cacheCurrentProps();
    _syncBrightnessIfNeeded();
    // The native view may have laid out before this handler was set, and its
    // first `sizeChanged` is then lost; ask once.
    _requestIntrinsicSize();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    final args = call.arguments as Map?;
    switch (call.method) {
      case 'valueChanged':
        final ms = (args?['value'] as num?)?.toInt();
        if (ms == null) return null;
        final picked = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: _utc);
        final value = _merge(picked, widget.mode);
        _lastValueMs = value.millisecondsSinceEpoch;
        _lastUtc = value.isUtc;
        widget.onChanged(value);
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
      // The native view is gone; a new one reports its own size.
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

  void _cacheCurrentProps() {
    _lastValueMs = widget.value.millisecondsSinceEpoch;
    _lastUtc = _utc;
    _lastMode = widget.mode;
    _lastMinimumMs = widget.minimumDate?.millisecondsSinceEpoch;
    _lastMaximumMs = widget.maximumDate?.millisecondsSinceEpoch;
    _lastMinuteInterval = widget.minuteInterval;
    _lastEnabled = widget.enabled;
    _lastSemanticLabel = widget.semanticLabel;
    _lastLocale = _localeTag;
    _lastIsDark = _isDark;
    _lastTint = resolveColorToArgb(_effectiveTint, context);
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;

    // Resolve theme-dependent values before awaiting.
    final int? tint = resolveColorToArgb(_effectiveTint, context);
    final valueMs = widget.value.millisecondsSinceEpoch;
    final minimumMs = widget.minimumDate?.millisecondsSinceEpoch;
    final maximumMs = widget.maximumDate?.millisecondsSinceEpoch;

    try {
      if (_lastEnabled != widget.enabled) {
        await channel.invokeMethod('setEnabled', {'enabled': widget.enabled});
        _lastEnabled = widget.enabled;
      }

      if (_lastSemanticLabel != widget.semanticLabel) {
        await channel.invokeMethod('setSemanticLabel', {
          'label': widget.semanticLabel,
        });
        _lastSemanticLabel = widget.semanticLabel;
      }

      if (_lastLocale != _localeTag) {
        await channel.invokeMethod('setLocale', {'locale': _localeTag});
        _lastLocale = _localeTag;
      }

      if (_lastMode != widget.mode) {
        await channel.invokeMethod('setMode', {'mode': widget.mode.name});
        _lastMode = widget.mode;
      }

      if (_lastMinuteInterval != widget.minuteInterval) {
        await channel.invokeMethod('setMinuteInterval', {
          'minuteInterval': widget.minuteInterval,
        });
        _lastMinuteInterval = widget.minuteInterval;
      }

      // The range goes before the value, so that a value inside the new
      // range is not clamped to the old one.
      if (_lastMinimumMs != minimumMs || _lastMaximumMs != maximumMs) {
        await channel.invokeMethod('setRange', {
          'minimumDate': minimumMs,
          'maximumDate': maximumMs,
        });
        _lastMinimumMs = minimumMs;
        _lastMaximumMs = maximumMs;
      }

      if (_lastValueMs != valueMs || _lastUtc != _utc) {
        await channel.invokeMethod('setValue', {
          'value': valueMs,
          'utc': _utc,
          'animated': true,
        });
        _lastValueMs = valueMs;
        _lastUtc = _utc;
      }

      // Style updates (e.g., tint color)
      if (_lastTint != tint && tint != null) {
        await channel.invokeMethod('setStyle', {'tint': tint});
        _lastTint = tint;
      }
    } catch (_) {
      // The native view is gone, e.g. hidden under a sheet; it is created
      // again with the current values.
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    final isDark = _isDark;
    final int? tint = resolveColorToArgb(_effectiveTint, context);

    try {
      if (_lastIsDark != isDark) {
        await channel.invokeMethod('setBrightness', {'isDark': isDark});
        _lastIsDark = isDark;
      }

      if (_lastTint != tint && tint != null) {
        await channel.invokeMethod('setStyle', {'tint': tint});
        _lastTint = tint;
      }
    } catch (_) {
      // The native view is gone, e.g. hidden under a sheet; it is created
      // again with the current brightness.
    }
  }

  // MARK: - Values

  /// Builds a [DateTime] in the picker's zone.
  DateTime _make(
    int year,
    int month, [
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) => _utc
      ? DateTime.utc(
          year,
          month,
          day,
          hour,
          minute,
          second,
          millisecond,
          microsecond,
        )
      : DateTime(
          year,
          month,
          day,
          hour,
          minute,
          second,
          millisecond,
          microsecond,
        );

  /// [d] in the picker's zone.
  DateTime _zoned(DateTime d) => _utc ? d.toUtc() : d.toLocal();

  /// Joins what the user [picked] in [mode] with the parts of the current
  /// value the mode does not show, and keeps the result inside the limits.
  ///
  /// This is what makes the native picker and the fallback report the same
  /// values: `UIDatePicker` keeps the time in date mode, while
  /// [CupertinoDatePicker] reports midnight.
  DateTime _merge(DateTime picked, CNDatePickerMode mode) {
    final p = _zoned(picked);
    final c = _zoned(widget.value);
    final merged = switch (mode) {
      CNDatePickerMode.date => _make(
        p.year,
        p.month,
        p.day,
        c.hour,
        c.minute,
        c.second,
        c.millisecond,
        c.microsecond,
      ),
      CNDatePickerMode.time => _make(c.year, c.month, c.day, p.hour, p.minute),
      CNDatePickerMode.dateAndTime => _make(
        p.year,
        p.month,
        p.day,
        p.hour,
        p.minute,
      ),
      CNDatePickerMode.yearAndMonth => _make(p.year, p.month),
    };
    return _clamp(merged);
  }

  DateTime _clamp(DateTime d) {
    final min = widget.minimumDate;
    final max = widget.maximumDate;
    if (min != null && d.isBefore(min)) return _zoned(min);
    if (max != null && d.isAfter(max)) return _zoned(max);
    return d;
  }

  // MARK: - Fallback

  /// [d]'s wall-clock fields in the picker's zone, as a local [DateTime]:
  /// the form [CupertinoDatePicker] works in.
  DateTime _toFields(DateTime d) {
    final z = _zoned(d);
    return DateTime(
      z.year,
      z.month,
      z.day,
      z.hour,
      z.minute,
      z.second,
      z.millisecond,
      z.microsecond,
    );
  }

  /// The inverse of [_toFields].
  DateTime _fromFields(DateTime f) => _make(
    f.year,
    f.month,
    f.day,
    f.hour,
    f.minute,
    f.second,
    f.millisecond,
    f.microsecond,
  );

  void _syncFallbackIfNeeded(CNDatePicker oldWidget) {
    final shown = _fallbackShown;
    final valueMoved =
        shown != null &&
        (shown.millisecondsSinceEpoch != widget.value.millisecondsSinceEpoch ||
            shown.isUtc != widget.value.isUtc);
    if (valueMoved ||
        oldWidget.minimumDate != widget.minimumDate ||
        oldWidget.maximumDate != widget.maximumDate ||
        oldWidget.minuteInterval != widget.minuteInterval) {
      _fallbackGeneration++;
    }
  }

  void _onFallbackChanged(DateTime pickedFields, CNDatePickerMode mode) {
    final value = _merge(_fromFields(pickedFields), mode);
    _fallbackShown = value;
    widget.onChanged(value);
  }

  /// The value a [CupertinoDatePicker] can start at: inside the limits and
  /// on the minute step, both of which it asserts.
  DateTime _fallbackInitial() {
    var initial = _toFields(_clamp(widget.value));
    final step = widget.minuteInterval;
    final off = initial.minute % step;
    if (off != 0) {
      initial = initial.subtract(Duration(minutes: off));
      final min = widget.minimumDate;
      if (min != null && initial.isBefore(_toFields(min))) {
        initial = initial.add(Duration(minutes: step));
      }
    }
    return initial;
  }

  CupertinoDatePicker _cupertinoPicker({
    required CupertinoDatePickerMode mode,
    required CNDatePickerMode reportAs,
  }) {
    _fallbackShown = widget.value;
    return CupertinoDatePicker(
      key: ValueKey<Object>((mode, _fallbackGeneration)),
      mode: mode,
      initialDateTime: _fallbackInitial(),
      minimumDate: widget.minimumDate == null
          ? null
          : _toFields(widget.minimumDate!),
      maximumDate: widget.maximumDate == null
          ? null
          : _toFields(widget.maximumDate!),
      minuteInterval: widget.minuteInterval,
      use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      onDateTimeChanged: (d) => _onFallbackChanged(d, reportAs),
    );
  }

  CupertinoDatePickerMode get _cupertinoMode => switch (widget.mode) {
    CNDatePickerMode.date => CupertinoDatePickerMode.date,
    CNDatePickerMode.time => CupertinoDatePickerMode.time,
    CNDatePickerMode.dateAndTime => CupertinoDatePickerMode.dateAndTime,
    CNDatePickerMode.yearAndMonth => CupertinoDatePickerMode.monthYear,
  };

  /// Wheels, for the wheels and inline styles.
  Widget _buildFallbackWheels(BuildContext context) {
    return LimitedBox(
      maxWidth: 320,
      child: SizedBox(
        width: double.infinity,
        height: 216,
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.4,
            child: _cupertinoPicker(
              mode: _cupertinoMode,
              reportAs: widget.mode,
            ),
          ),
        ),
      ),
    );
  }

  /// One pill per part, as iOS draws them: a date pill, a time pill, or both.
  Widget _buildFallbackPills(BuildContext context) {
    final showDate = widget.mode != CNDatePickerMode.time;
    final showTime =
        widget.mode == CNDatePickerMode.time ||
        widget.mode == CNDatePickerMode.dateAndTime;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDate) _pill(context, _PillPart.date),
          if (showDate && showTime) const SizedBox(width: 6),
          if (showTime) _pill(context, _PillPart.time),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, _PillPart part) {
    final text = part == _PillPart.date
        ? _formatDate(context, _zoned(widget.value))
        : _formatTime(context, _zoned(widget.value));
    final Color color;
    if (!widget.enabled) {
      color = CupertinoColors.tertiaryLabel.resolveFrom(context);
    } else if (_openPill == part) {
      color = CupertinoDynamicColor.resolve(
        _effectiveTint ?? CupertinoColors.systemBlue,
        context,
      );
    } else {
      color = CupertinoColors.label.resolveFrom(context);
    }
    return Semantics(
      button: true,
      enabled: widget.enabled,
      value: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? () => _openPopup(part) : null,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ExcludeSemantics(
            child: Text(
              text,
              style: TextStyle(
                inherit: false,
                fontFamily: CupertinoTheme.of(
                  context,
                ).textTheme.textStyle.fontFamily,
                fontSize: 17,
                letterSpacing: -0.4,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPopup(_PillPart part) async {
    setState(() => _openPill = part);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CupertinoPopupSurface(
            child: Container(
              height: 216,
              color: CupertinoColors.systemBackground.resolveFrom(popupContext),
              child: part == _PillPart.date
                  ? _cupertinoPicker(
                      mode: CupertinoDatePickerMode.date,
                      reportAs: CNDatePickerMode.date,
                    )
                  : _cupertinoPicker(
                      mode: CupertinoDatePickerMode.time,
                      reportAs: CNDatePickerMode.time,
                    ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _openPill = null);
  }

  /// "Nov 3, 2026" with Material localizations, else the month written out
  /// in the order of the Cupertino localizations.
  String _formatDate(BuildContext context, DateTime d) {
    final material = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );
    if (material != null) return material.formatShortDate(d);
    final c = CupertinoLocalizations.of(context);
    final month = c.datePickerMonth(d.month);
    final day = c.datePickerDayOfMonth(d.day);
    final year = c.datePickerYear(d.year);
    return switch (c.datePickerDateOrder) {
      DatePickerDateOrder.dmy => '$day $month $year',
      DatePickerDateOrder.ymd => '$year $month $day',
      DatePickerDateOrder.ydm => '$year $day $month',
      DatePickerDateOrder.mdy => '$month $day, $year',
    };
  }

  /// "9:41 AM", or "09:41" when the device uses 24-hour time.
  String _formatTime(BuildContext context, DateTime d) {
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final material = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );
    if (material != null) {
      return material.formatTimeOfDay(
        TimeOfDay.fromDateTime(d),
        alwaysUse24HourFormat: use24,
      );
    }
    final c = CupertinoLocalizations.of(context);
    final minute = c.datePickerMinute(d.minute);
    if (use24) return '${d.hour.toString().padLeft(2, '0')}:$minute';
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour < 12
        ? c.anteMeridiemAbbreviation
        : c.postMeridiemAbbreviation;
    return '${c.datePickerHour(hour)}:$minute $period';
  }

  /// Names the fallback picker with [CNDatePicker.semanticLabel]; its pills
  /// and wheels keep their own nodes, which read the value.
  Widget _labelled(Widget child) {
    final label = widget.semanticLabel;
    if (label == null) return child;
    return Semantics(container: true, label: label, child: child);
  }
}
