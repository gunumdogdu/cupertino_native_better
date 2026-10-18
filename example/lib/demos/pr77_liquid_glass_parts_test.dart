import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #77 verification — two glass pills can match in shade or keep their
/// rim, never both.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/77
/// Reported by @johndavid92.
///
/// ### The claim
///
/// A bar made of a wide glass pill plus a lone glass circle beside it cannot
/// be built correctly today:
///
///  * **`two views`** — a `LiquidGlassContainer` per pill. Each is its own
///    platform view with its own `.glassEffect`, so each samples its own
///    backdrop, and over uneven content the two settle on visibly different
///    shades (the reporter measured 44/255 apart). Both keep a full rim.
///  * **`clipped`** — one rect `LiquidGlassContainer` with both pills cut out
///    of it by a Flutter `ClipPath`. One effect, one sample, so the shades
///    match — but `glassEffect(_:in:)` draws its rim on the shape it was
///    given, the rect, and the clip hides most of it. The circle's side that
///    faces the wide pill (and the wide pill's right end) has no rim.
///
/// The PR adds `LiquidGlassConfig.parts`: one effect whose shape is several
/// disjoint rounded rects. This page, on unpatched `main`, shows only the two
/// modes that exist today.
///
/// ### How this screen proves it
///
/// The bar has a fixed geometry (a 238 × 72 pill, a 10 pt gap, a 72 × 72
/// circle) so screenshots line up across builds. Backdrops:
///
///  * `split` — dark under the left 60 % of the wide pill, light under the
///    rest of the bar. The wide pill's own sample is then mostly dark and the
///    circle's all light, which is the case for two effects to disagree —
///    yet the wide pill's **right end** and the **circle** sit over the
///    *same* light block. Compare those two areas only: glass is
///    translucent, so anything over the dark block looks different from
///    anything over the light block in every mode, and proves nothing.
///  * `dark` — uniform dark. The size control for `two views` (glass also
///    adapts to element size, so the two pills must first be shown to match
///    over an identical backdrop) and the best backdrop for reading rims,
///    which show as a light edge highlight.
///  * `photo` — real imagery, the case the PR was motivated by.
///
/// The magenta rings are drawn **in Flutter**, 4 pt outside each pill, so
/// they mark where the pills are without covering the rim being judged;
/// turn them off (`none`) before zooming into a screenshot.
///
///  * **Limitation present (`two views`):** on `split`, the circle and the
///    wide pill's right end — same light block underneath — settle on
///    visibly different glass tones; on `split` in `clipped` (one effect)
///    and on `dark` in `two views` they match. That isolates the separate
///    sampling as the cause.
///  * **Limitation present (`clipped`):** on `dark`, the circle's right half
///    has the edge highlight but its left arc (facing the gap) is a hard cut
///    with none, and likewise the wide pill's right cap. If the wide pill's
///    right cap *does* keep a highlight in `clipped`, the claim is wrong.
///
/// Once the PR is applied a third mode, `parts`, joins this page: expected
/// to match `clipped` in tone on `split` **and** `two views` in rim on
/// `dark`.
class Pr77LiquidGlassPartsTestPage extends StatefulWidget {
  const Pr77LiquidGlassPartsTestPage({super.key});

  @override
  State<Pr77LiquidGlassPartsTestPage> createState() =>
      _Pr77LiquidGlassPartsTestPageState();
}

enum _Mode { clipped, twoViews }

enum _Backdrop { split, dark, photo }

class _Pr77LiquidGlassPartsTestPageState
    extends State<Pr77LiquidGlassPartsTestPage> {
  static const double _barHeight = 72;
  static const double _wideWidth = 238;
  static const double _gap = 10;
  static const double _circle = 72;
  static const double _barWidth = _wideWidth + _gap + _circle;

  static const Color _darkBlock = Color(0xFF1B2430);
  static const Color _lightBlock = Color(0xFFF2EDE4);

  /// The two pills, in the bar's own coordinates.
  static final List<RRect> _pills = <RRect>[
    RRect.fromLTRBR(
      0,
      0,
      _wideWidth,
      _barHeight,
      const Radius.circular(_barHeight / 2),
    ),
    RRect.fromLTRBR(
      _wideWidth + _gap,
      0,
      _barWidth,
      _barHeight,
      const Radius.circular(_barHeight / 2),
    ),
  ];

  _Mode _mode = _Mode.clipped;
  _Backdrop _backdrop = _Backdrop.split;
  bool _outlines = true;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #77 · glass parts'),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _controls(),
            Expanded(child: LayoutBuilder(builder: _stage)),
          ],
        ),
      ),
    );
  }

  /// Backdrop plus the bar, centred. The `split` boundary is placed 60 % of
  /// the way along the wide pill, in stage coordinates, so the pill's right
  /// end shares the light block with the circle.
  Widget _stage(BuildContext context, BoxConstraints constraints) {
    final double barLeft = (constraints.maxWidth - _barWidth) / 2;
    final double splitX = barLeft + _wideWidth * 0.6;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _backdropFill(splitX)),
        Center(
          child: SizedBox(
            width: _barWidth,
            height: _barHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                ..._bar(),
                if (_outlines)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _PillRings(_pills)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _backdropFill(double splitX) {
    switch (_backdrop) {
      case _Backdrop.split:
        // Stretch: a childless ColoredBox takes its smallest allowed size, so
        // under the Row's default loose height both blocks would be 0 pt tall.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: splitX,
              child: const ColoredBox(color: _darkBlock),
            ),
            const Expanded(child: ColoredBox(color: _lightBlock)),
          ],
        );
      case _Backdrop.dark:
        return const ColoredBox(color: _darkBlock);
      case _Backdrop.photo:
        return Image.asset('assets/home.jpg', fit: BoxFit.cover);
    }
  }

  List<Widget> _bar() {
    switch (_mode) {
      case _Mode.clipped:
        return <Widget>[
          const Positioned.fill(
            child: ClipPath(
              clipper: _PillsClipper(),
              child: LiquidGlassContainer(
                config: LiquidGlassConfig(
                  effect: CNGlassEffect.regular,
                  shape: CNGlassEffectShape.rect,
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ];
      case _Mode.twoViews:
        return const <Widget>[
          Positioned(
            left: 0,
            top: 0,
            width: _wideWidth,
            height: _barHeight,
            child: LiquidGlassContainer(
              config: LiquidGlassConfig(effect: CNGlassEffect.regular),
              child: SizedBox.expand(),
            ),
          ),
          Positioned(
            left: _wideWidth + _gap,
            top: 0,
            width: _circle,
            height: _barHeight,
            child: LiquidGlassContainer(
              config: LiquidGlassConfig(effect: CNGlassEffect.regular),
              child: SizedBox.expand(),
            ),
          ),
        ];
    }
  }

  Widget _controls() {
    final String backend = PlatformVersion.shouldUseNativeGlass
        ? 'native'
        : 'fallback';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _mode == _Mode.clipped
                ? 'clipped: on dark (rings off), the circle\'s left arc and '
                      'the wide pill\'s right cap are hard cuts with no edge '
                      'highlight. On split this is the one-effect control: '
                      'circle and pill right end match.'
                : 'two views: on split, compare the circle with the wide '
                      'pill\'s right end (same light block under both) — '
                      'different tones = separate sampling. On dark they '
                      'must match.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoSegmentedControl<_Mode>(
              groupValue: _mode,
              onValueChanged: (_Mode v) => setState(() => _mode = v),
              children: const <_Mode, Widget>{
                _Mode.clipped: Text('clipped', style: TextStyle(fontSize: 12)),
                _Mode.twoViews: Text(
                  'two views',
                  style: TextStyle(fontSize: 12),
                ),
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: CupertinoSegmentedControl<_Backdrop>(
                  groupValue: _backdrop,
                  onValueChanged: (_Backdrop v) =>
                      setState(() => _backdrop = v),
                  children: <_Backdrop, Widget>{
                    for (final _Backdrop b in _Backdrop.values)
                      b: Text(b.name, style: const TextStyle(fontSize: 12)),
                  },
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSegmentedControl<bool>(
                groupValue: _outlines,
                onValueChanged: (bool v) => setState(() => _outlines = v),
                children: const <bool, Widget>{
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('rings', style: TextStyle(fontSize: 12)),
                  ),
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('none', style: TextStyle(fontSize: 12)),
                  ),
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_mode == _Mode.clipped ? 'clipped' : 'two views'} · '
            '${_backdrop.name} · '
            '${_wideWidth.toInt()}+${_gap.toInt()}+${_circle.toInt()} × '
            '${_barHeight.toInt()} · $backend',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.white,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuts both pills out of the bar's rect.
class _PillsClipper extends CustomClipper<Path> {
  const _PillsClipper();

  @override
  Path getClip(Size size) {
    final Path path = Path();
    for (final RRect pill in _Pr77LiquidGlassPartsTestPageState._pills) {
      path.addRRect(pill);
    }
    return path;
  }

  @override
  bool shouldReclip(_PillsClipper oldClipper) => false;
}

/// Magenta rings 4 pt outside each pill — close enough to mark it, far
/// enough not to hide its rim.
class _PillRings extends CustomPainter {
  const _PillRings(this.pills);

  final List<RRect> pills;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFF00AA);
    for (final RRect pill in pills) {
      canvas.drawRRect(pill.inflate(4), paint);
    }
  }

  @override
  bool shouldRepaint(_PillRings oldDelegate) => false;
}
