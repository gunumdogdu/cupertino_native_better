import 'dart:math' as math;
import 'dart:ui' show ColorSpace;

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../utils/version_detector.dart';
import '../utils/theme_helper.dart';
import '../utils/modal_hide_mixin.dart';

/// A Cupertino-native colour well: a round swatch of the selected colour that
/// opens the system colour picker when tapped.
///
/// On iOS 26+ this embeds a `UIColorWell`, which presents
/// `UIColorPickerViewController` (grid, spectrum and sliders, the
/// eyedropper, saved colours) by itself. On macOS 26+ it embeds an
/// `NSColorWell` in its minimal style, which opens the system colour popover.
/// Below iOS/macOS 26 and on other platforms it draws a round swatch that
/// opens a sheet with a palette of system colours.
///
/// ```dart
/// CNColorWell(
///   color: accent,
///   title: 'Accent Color',
///   semanticLabel: 'Accent color',
///   onChanged: (c) => setState(() => accent = c),
/// )
/// ```
///
/// On iOS the well also takes a colour dragged onto it, which is reported
/// through [onChanged] like a picked one. The picker is presented by the
/// app's root view controller, so it follows the system appearance rather
/// than the app's [CupertinoThemeData.brightness].
///
/// ## Colour space
///
/// Colours cross the platform channel as 8-bit sRGB (`0xAARRGGBB`). The
/// picker can produce colours outside sRGB (its Display P3 sliders, or the
/// eyedropper on a P3 photo); those are converted to sRGB and clipped to its
/// gamut, so [onChanged] always receives an sRGB [Color]. A [color] in
/// another colour space (e.g. `ColorSpace.displayP3`) is converted to sRGB
/// before it is shown.
class CNColorWell extends StatefulWidget {
  /// Creates a Cupertino-native colour well.
  const CNColorWell({
    super.key,
    required this.color,
    required this.onChanged,
    this.supportsAlpha = true,
    this.title,
    this.supportsEyedropper = true,
    this.enabled = true,
    this.size = 32.0,
    this.autoHideOnModal = true,
    this.semanticLabel,
  });

  /// The selected colour shown in the well.
  final Color color;

  /// Called with each colour the user picks. The native picker reports
  /// colours continuously while the user drags in it.
  final ValueChanged<Color> onChanged;

  /// Whether the user can pick a transparent colour. When false, the picker
  /// hides its opacity slider and every colour is opaque. Defaults to true,
  /// as `UIColorWell`. On macOS this needs macOS 14+.
  final bool supportsAlpha;

  /// Title of the colour picker, e.g. `'Stroke Color'`. iOS shows it at the
  /// top of the picker and the fallback at the top of its sheet;
  /// `NSColorWell` has no picker title, so it is ignored on macOS.
  final String? title;

  /// Whether the picker offers the eyedropper. Applies on iOS 26+ only
  /// (`UIColorWell.supportsEyedropper` is new in iOS 26); macOS always
  /// offers it, and the fallback has none.
  final bool supportsEyedropper;

  /// Whether the control is interactive.
  final bool enabled;

  /// Width and height of the well on iOS and in the fallback. The macOS well
  /// keeps the system size.
  final double size;

  /// When true (default), destroys the native colour well's PlatformView
  /// while a modal sheet is presented above this widget's host route.
  /// Prevents the iOS hybrid-composition z-order bleed (Issue #53) where the
  /// host-page PlatformView's pixels leak through a sheet that also contains
  /// a PlatformView (CN-widget). Requires `CNTabBarRouteObserver()` to be
  /// registered in the app's `navigatorObservers`. No effect on non-iOS or
  /// iOS < 26 (Flutter fallback path).
  ///
  /// The colour picker the well opens is a UIKit presentation, not a Flutter
  /// route, so it does not hide the well.
  final bool autoHideOnModal;

  /// What VoiceOver reads for the well, e.g. `'Accent color'`.
  ///
  /// A native control cannot borrow the text next to it the way a Flutter
  /// widget in `MergeSemantics` can, so without this VoiceOver announces
  /// only "Color well". Pass the same text as its visible label.
  final String? semanticLabel;

  @override
  State<CNColorWell> createState() => _CNColorWellState();
}

/// Converts [color] to 8-bit sRGB ARGB (`0xAARRGGBB`), first converting it
/// from its colour space and clipping components outside sRGB.
int _srgbArgb(Color color) {
  final c = color.colorSpace == ColorSpace.sRGB
      ? color
      : color.withValues(colorSpace: ColorSpace.sRGB);
  int channel(double v) => (v.clamp(0.0, 1.0) * 255.0).round();
  return (channel(c.a) << 24) |
      (channel(c.r) << 16) |
      (channel(c.g) << 8) |
      channel(c.b);
}

/// Size of the box an `NSColorWell` in the minimal style fills on macOS.
const Size _kMacOSColorWellSize = Size(44, 24);

class _CNColorWellState extends State<CNColorWell>
    with ModalHideMixin<CNColorWell> {
  @override
  bool get autoHideOnModal => widget.autoHideOnModal;

  @override
  MethodChannel? get platformViewChannel => _channel;

  MethodChannel? _channel;

  int? _lastColor;
  bool? _lastSupportsAlpha;
  bool? _lastSupportsEyedropper;
  String? _lastTitle;
  bool? _lastEnabled;
  String? _lastSemanticLabel;
  bool? _lastIsDark;
  bool get _isDark => ThemeHelper.isDark(context);

  /// The colour as sent to the native well. A [CupertinoDynamicColor] is
  /// resolved for the current brightness first.
  int get _colorArgb =>
      _srgbArgb(CupertinoDynamicColor.maybeResolve(widget.color, context)!);

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CNColorWell oldWidget) {
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
        isIOSOrMacOS && PlatformVersion.shouldUseNativeGlass;

    if (!shouldUseNative) {
      return _CNFallbackColorWell(
        color: widget.color,
        onChanged: widget.onChanged,
        supportsAlpha: widget.supportsAlpha,
        title: widget.title,
        enabled: widget.enabled,
        size: widget.size,
        semanticLabel: widget.semanticLabel,
      );
    }

    const viewType = 'CupertinoNativeColorWell';
    // A fixed size, so the well also works in a Row, where a platform view
    // would otherwise try to grow to an infinite width.
    final size = defaultTargetPlatform == TargetPlatform.macOS
        ? _kMacOSColorWellSize
        : Size.square(widget.size);

    // Issue #53 fix: when a modal is presented above our host route, destroy
    // the native UIColorWell to remove its PlatformView from the shared iOS
    // PlatformView container.
    final hidden = maybeHiddenPlaceholder(
      height: size.height,
      width: size.width,
    );
    if (hidden != null) return hidden;

    final creationParams = <String, dynamic>{
      'color': _colorArgb,
      'supportsAlpha': widget.supportsAlpha,
      'supportsEyedropper': widget.supportsEyedropper,
      if (widget.title != null) 'title': widget.title,
      'enabled': widget.enabled,
      if (widget.semanticLabel != null) 'semanticLabel': widget.semanticLabel,
      'isDark': _isDark,
    };

    final gestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
      Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
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
    final channel = MethodChannel('CupertinoNativeColorWell_$id');
    _channel = channel;
    channel.setMethodCallHandler(_onMethodCall);
    _cacheCurrentProps();
    _syncBrightnessIfNeeded();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'colorChanged') {
      final args = call.arguments as Map?;
      final argb = (args?['color'] as num?)?.toInt();
      if (argb != null) {
        // Remember it first, so the rebuild the parent does in onChanged
        // does not send the colour back to the picker the user is in.
        _lastColor = argb;
        widget.onChanged(Color(argb));
      }
    }
    return null;
  }

  void _cacheCurrentProps() {
    _lastColor = _colorArgb;
    _lastSupportsAlpha = widget.supportsAlpha;
    _lastSupportsEyedropper = widget.supportsEyedropper;
    _lastTitle = widget.title;
    _lastEnabled = widget.enabled;
    _lastSemanticLabel = widget.semanticLabel;
    _lastIsDark = _isDark;
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
    final color = _colorArgb;

    if (_lastColor != color) {
      _lastColor = color;
      await _invoke(channel, 'setColor', {'color': color});
    }

    if (_lastSupportsAlpha != widget.supportsAlpha ||
        _lastSupportsEyedropper != widget.supportsEyedropper ||
        _lastTitle != widget.title) {
      _lastSupportsAlpha = widget.supportsAlpha;
      _lastSupportsEyedropper = widget.supportsEyedropper;
      _lastTitle = widget.title;
      await _invoke(channel, 'setOptions', {
        'supportsAlpha': widget.supportsAlpha,
        'supportsEyedropper': widget.supportsEyedropper,
        'title': widget.title,
      });
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
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final channel = _channel;
    if (channel == null) return;
    final isDark = _isDark;
    final color = _colorArgb;

    if (_lastIsDark != isDark) {
      _lastIsDark = isDark;
      await _invoke(channel, 'setBrightness', {'isDark': isDark});
    }

    // A dynamic colour resolves differently in the new brightness.
    if (_lastColor != color) {
      _lastColor = color;
      await _invoke(channel, 'setColor', {'color': color});
    }
  }
}

/// The system colours the fallback palette offers, with the names VoiceOver
/// reads for them.
const List<(String, Color)> _kPalette = <(String, Color)>[
  ('Red', CupertinoColors.systemRed),
  ('Orange', CupertinoColors.systemOrange),
  ('Yellow', CupertinoColors.systemYellow),
  ('Green', CupertinoColors.systemGreen),
  ('Mint', CupertinoColors.systemMint),
  ('Teal', CupertinoColors.systemTeal),
  ('Cyan', CupertinoColors.systemCyan),
  ('Blue', CupertinoColors.systemBlue),
  ('Indigo', CupertinoColors.systemIndigo),
  ('Purple', CupertinoColors.systemPurple),
  ('Pink', CupertinoColors.systemPink),
  ('Brown', CupertinoColors.systemBrown),
  ('Gray', CupertinoColors.systemGrey),
  ('Black', CupertinoColors.black),
  ('White', CupertinoColors.white),
];

/// The name of the palette colour [argb] is (ignoring opacity), or null.
String? _paletteName(int argb, BuildContext context) {
  for (final (name, color) in _kPalette) {
    final resolved = CupertinoDynamicColor.resolve(color, context);
    if (_srgbArgb(resolved) & 0xFFFFFF == argb & 0xFFFFFF) return name;
  }
  return null;
}

/// The colour well drawn in Flutter: the selected colour inside a spectrum
/// ring, like `UIColorWell`. Tapping it opens [_CNColorPaletteSheet].
class _CNFallbackColorWell extends StatelessWidget {
  const _CNFallbackColorWell({
    required this.color,
    required this.onChanged,
    required this.supportsAlpha,
    required this.title,
    required this.enabled,
    required this.size,
    required this.semanticLabel,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final bool supportsAlpha;
  final String? title;
  final bool enabled;
  final double size;
  final String? semanticLabel;

  void _open(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _CNColorPaletteSheet(
        initial: CupertinoDynamicColor.resolve(color, context),
        title: title,
        supportsAlpha: supportsAlpha,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(color, context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      value: _paletteName(_srgbArgb(resolved), context),
      onTap: enabled ? () => _open(context) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: enabled ? () => _open(context) : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.4,
            child: SizedBox.square(
              dimension: size,
              child: CustomPaint(painter: _ColorWellPainter(resolved)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a spectrum ring with [color] in a circle inside it. A transparent
/// colour shows over a half-white, half-black disc, as `UIColorWell` does.
class _ColorWellPainter extends CustomPainter {
  const _ColorWellPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ring = radius * 0.12;
    final rect = Rect.fromCircle(center: center, radius: radius - ring / 2);
    canvas.drawCircle(
      center,
      radius - ring / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring
        ..shader = const SweepGradient(
          // Clockwise from the top, in the order UIColorWell's ring has.
          colors: <Color>[
            Color(0xFFFFCC00),
            Color(0xFFFF9500),
            Color(0xFFFF3B30),
            Color(0xFFFF2D55),
            Color(0xFFAF52DE),
            Color(0xFF007AFF),
            Color(0xFF32ADE6),
            Color(0xFF34C759),
            Color(0xFFFFCC00),
          ],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
    final inner = radius - ring * 2;
    if (color.a < 1.0) {
      final disc = Rect.fromCircle(center: center, radius: inner);
      canvas.drawArc(
        disc,
        math.pi / 2,
        math.pi,
        true,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawArc(
        disc,
        -math.pi / 2,
        math.pi,
        true,
        Paint()..color = const Color(0xFF000000),
      );
    }
    canvas.drawCircle(center, inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ColorWellPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The fallback picker: a sheet with the system colours and, when alpha is
/// supported, an opacity slider. Each pick is reported right away, like the
/// native picker; the sheet closes with its × or a tap outside.
class _CNColorPaletteSheet extends StatefulWidget {
  const _CNColorPaletteSheet({
    required this.initial,
    required this.title,
    required this.supportsAlpha,
    required this.onChanged,
  });

  final Color initial;
  final String? title;
  final bool supportsAlpha;
  final ValueChanged<Color> onChanged;

  @override
  State<_CNColorPaletteSheet> createState() => _CNColorPaletteSheetState();
}

class _CNColorPaletteSheetState extends State<_CNColorPaletteSheet> {
  late Color _color = Color(_srgbArgb(widget.initial));

  void _pick(Color color) {
    setState(() => _color = color);
    widget.onChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      CupertinoColors.systemGroupedBackground,
      context,
    );
    final selected = _srgbArgb(_color) & 0xFFFFFF;
    final dismissLabel = CupertinoLocalizations.of(
      context,
    ).modalBarrierDismissLabel;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? '',
                      style: CupertinoTheme.of(
                        context,
                      ).textTheme.navTitleTextStyle,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: dismissLabel,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const _CloseGlyph(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                // Spread the swatches across the row: five a row (three
                // full rows) where they fit, fewer on a narrow screen.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const swatch = 44.0;
                    final width = constraints.maxWidth;
                    final fit = ((width + 8) / (swatch + 8)).floor();
                    final columns = fit >= 5 ? 5 : math.max(1, fit);
                    final spacing = columns > 1
                        ? (width - columns * swatch) / (columns - 1)
                        : 0.0;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: 12,
                      children: [
                        for (final (name, color) in _kPalette)
                          _swatch(
                            name,
                            CupertinoDynamicColor.resolve(color, context),
                            selected,
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (widget.supportsAlpha) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: 'Opacity',
                          child: CupertinoSlider(
                            value: _color.a,
                            onChanged: (a) =>
                                _pick(_color.withValues(alpha: a)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: Text(
                          '${(_color.a * 100).round()}%',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatch(String name, Color color, int selected) {
    final isSelected = _srgbArgb(color) & 0xFFFFFF == selected;
    final ring = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      child: GestureDetector(
        onTap: () => _pick(color.withValues(alpha: _color.a)),
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? ring : const Color(0x00000000),
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.separator,
                  context,
                ),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An × in a grey circle, like the close button of the iOS colour picker,
/// drawn with boxes so it needs no icon font.
class _CloseGlyph extends StatelessWidget {
  const _CloseGlyph();

  @override
  Widget build(BuildContext context) {
    final fill = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiarySystemFill,
      context,
    );
    final glyph = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final bar = SizedBox(
      width: 12,
      height: 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: glyph,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(angle: math.pi / 4, child: bar),
          Transform.rotate(angle: -math.pi / 4, child: bar),
        ],
      ),
    );
  }
}
