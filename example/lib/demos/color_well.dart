import 'dart:async';
import 'dart:ui' show ColorSpace;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

/// CNColorWell: a well that colours a preview, one without opacity or the
/// eyedropper, and a disabled one, each with its colour written next to it.
///
/// [autoCycle] changes the colours on a timer, including a Display P3 colour
/// and a translucent one, so the page can be checked from screenshots
/// without tapping (`PROBE=colorwell`). [openPicker] taps the first well
/// once, to show the Flutter fallback's palette sheet (synthesised taps do
/// not reach a native platform view).
class ColorWellDemoPage extends StatefulWidget {
  const ColorWellDemoPage({
    super.key,
    this.autoCycle = false,
    this.openPicker = false,
  });

  /// Changes the colours every 1.5 s.
  final bool autoCycle;

  /// Taps the first well a second after the page appears.
  final bool openPicker;

  @override
  State<ColorWellDemoPage> createState() => _ColorWellDemoPageState();
}

class _ColorWellDemoPageState extends State<ColorWellDemoPage> {
  static final List<Color> _cycle = <Color>[
    CupertinoColors.systemPink,
    CupertinoColors.systemTeal,
    // Outside sRGB: shown clipped to the nearest sRGB green.
    const Color.from(
      alpha: 1,
      red: 0,
      green: 1,
      blue: 0,
      colorSpace: ColorSpace.displayP3,
    ),
    const Color(0x80FF9500),
  ];

  Color _accent = CupertinoColors.systemIndigo;
  Color _opaque = CupertinoColors.systemOrange;
  bool _enabled = true;
  int _tick = 0;
  Timer? _timer;
  final GlobalKey _firstWell = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.openPicker) {
      Timer(const Duration(seconds: 1), _tapFirstWell);
    } else if (widget.autoCycle) {
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        setState(() {
          _accent = _cycle[_tick % _cycle.length];
          _opaque = _cycle[(_tick + 1) % _cycle.length].withValues(alpha: 1);
          _enabled = !_enabled;
          _tick++;
        });
      });
    }
  }

  void _tapFirstWell() {
    final box = _firstWell.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    GestureBinding.instance
      ..handlePointerEvent(PointerDownEvent(position: center))
      ..handlePointerEvent(PointerUpEvent(position: center));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// `#RRGGBB` and the opacity, in sRGB.
  String _describe(Color color) {
    final c = CupertinoDynamicColor.resolve(
      color,
      context,
    ).withValues(colorSpace: ColorSpace.sRGB);
    String hex(double v) =>
        (v.clamp(0.0, 1.0) * 255).round().toRadixString(16).padLeft(2, '0');
    final rgb = '#${hex(c.r)}${hex(c.g)}${hex(c.b)}'.toUpperCase();
    final alpha = (c.a * 100).round();
    return alpha == 100 ? rgb : '$rgb, $alpha% opacity';
  }

  Widget _row(String label, String value, Widget well) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          well,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Color Well')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // The picked colour fills this preview.
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Preview',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _row(
              'Accent',
              _describe(_accent),
              CNColorWell(
                key: _firstWell,
                color: _accent,
                title: 'Accent Color',
                semanticLabel: 'Accent color',
                onChanged: (c) => setState(() => _accent = c),
              ),
            ),
            _row(
              'Opaque, no eyedropper',
              _describe(_opaque),
              CNColorWell(
                color: _opaque,
                supportsAlpha: false,
                supportsEyedropper: false,
                title: 'Fill Color',
                semanticLabel: 'Fill color',
                onChanged: (c) => setState(() => _opaque = c),
              ),
            ),
            _row(
              'Large',
              _describe(_accent),
              CNColorWell(
                color: _accent,
                size: 44,
                semanticLabel: 'Accent color, large',
                onChanged: (c) => setState(() => _accent = c),
              ),
            ),
            _row(
              'Disabled',
              _describe(CupertinoColors.systemGreen),
              CNColorWell(
                color: CupertinoColors.systemGreen,
                enabled: false,
                semanticLabel: 'Disabled color',
                onChanged: (_) {},
              ),
            ),
            if (widget.autoCycle)
              _row(
                'Enabled changes',
                _enabled ? 'enabled' : 'disabled',
                CNColorWell(
                  color: _opaque,
                  enabled: _enabled,
                  semanticLabel: 'Toggled color',
                  onChanged: (c) => setState(() => _opaque = c),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
