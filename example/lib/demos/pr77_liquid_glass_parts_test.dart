import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #77 verification — `LiquidGlassConfig.parts`: one glass effect shaped as several disjoint
/// rounded rects.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/77
/// Reported by @johndavid92.
///
/// ### The problem this solves
///
/// A bar of two glass pills — a wide one and a lone circle beside it — can be built two ways today,
/// and both are wrong in a different way.
///
///  * **A container per pill.** Each is its own platform view with its own `.glassEffect`, so each
///    samples its own backdrop. Over uneven content the two settle on visibly different shades: on
///    the reporter's nav bar they measured **44/255** apart. Both pills do keep their rim.
///  * **One container, clipped in Flutter.** A single rect of glass with the two pills cut out of it
///    with `ClipPath`. One effect means one sample, so the shades match — but `glassEffect(_:in:)`
///    draws its rim on *the shape it was handed*, which is the rect. The clip then hides almost all
///    of it. On the reporter's bar the circle kept a rim from 270° round to 90° — the half that
///    happens to lie on the rect's own right edge — and had none from 105° to 255°.
///
/// So the choice was matching colour or a complete rim, never both.
///
/// ### The fix
///
/// `Shape` is free to return a path with more than one subpath, and `glassEffect(_:in:)` accepts any
/// `Shape`. So `parts` builds one `Path` holding a rounded rect per part and hands that to a single
/// `.glassEffect`. One effect — one sample, so the parts cannot drift apart — and the rim follows
/// every part's own outline, because that is what the path is.
///
/// ### How this screen proves it
///
/// The backdrop is deliberately uneven: a dark block under the left of the bar and a light one under
/// the right, so the wide pill and the circle sit over different content. That is the case that makes
/// two containers disagree.
///
/// The **magenta outlines are drawn in Flutter** on the same rects the glass is given. Flutter always
/// lays those out correctly, so they mark where each pill truly is.
///
/// Switch between the three modes and watch the circle's **left** edge, the side facing the wide pill:
///
///  * `parts` — shades match **and** the circle is rimmed all the way round.
///  * `clipped` — shades match, but the circle's left side has no rim: it is interior to the rect the
///    effect was given.
///  * `two views` — the circle is rimmed all the way round, but its shade no longer matches the wide
///    pill's.
class Pr77LiquidGlassPartsTestPage extends StatefulWidget {
  const Pr77LiquidGlassPartsTestPage({super.key});

  @override
  State<Pr77LiquidGlassPartsTestPage> createState() =>
      _Pr77LiquidGlassPartsTestPageState();
}

enum _Mode { parts, clipped, twoViews }

class _Pr77LiquidGlassPartsTestPageState
    extends State<Pr77LiquidGlassPartsTestPage> {
  static const double _barHeight = 64;
  static const double _gap = 10;
  static const double _circle = 64;

  _Mode _mode = _Mode.parts;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #77: LiquidGlass parts'),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSegmentedControl<_Mode>(
                groupValue: _mode,
                onValueChanged: (_Mode value) => setState(() => _mode = value),
                children: const <_Mode, Widget>{
                  _Mode.parts: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('parts'),
                  ),
                  _Mode.clipped: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('clipped'),
                  ),
                  _Mode.twoViews: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('two views'),
                  ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _blurb,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Stack(
                  children: <Widget>[
                    // Dark under the wide pill, light under the circle: the split that makes two
                    // separate effects disagree.
                    Positioned.fill(
                      child: Row(
                        children: const <Widget>[
                          Expanded(
                            flex: 3,
                            child: ColoredBox(color: Color(0xFF1B2430)),
                          ),
                          Expanded(
                            flex: 2,
                            child: ColoredBox(color: Color(0xFFF2EDE4)),
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: _barHeight,
                          child: LayoutBuilder(builder: _buildBar),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _blurb {
    switch (_mode) {
      case _Mode.parts:
        return 'One effect, shaped as both pills. Expect matching shades and a rim all the way round '
            'the circle.';
      case _Mode.clipped:
        return 'One rect of glass, pills cut out with ClipPath. Shades match, but the circle has no '
            'rim on its left side.';
      case _Mode.twoViews:
        return 'A container per pill. Each is rimmed, but the shades no longer match.';
    }
  }

  Widget _buildBar(BuildContext context, BoxConstraints constraints) {
    final double wide = constraints.maxWidth - _circle - _gap;
    final List<CNGlassPart> parts = <CNGlassPart>[
      CNGlassPart(
        left: 0,
        top: 0,
        width: wide,
        height: _barHeight,
        radius: _barHeight / 2,
      ),
      CNGlassPart(
        left: wide + _gap,
        top: 0,
        width: _circle,
        height: _barHeight,
        radius: _barHeight / 2,
      ),
    ];

    return Stack(
      children: <Widget>[
        if (_mode == _Mode.parts)
          Positioned.fill(
            child: LiquidGlassContainer(
              config: LiquidGlassConfig(
                effect: CNGlassEffect.regular,
                parts: parts,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        if (_mode == _Mode.clipped)
          Positioned.fill(
            child: ClipPath(
              clipper: _PartsClipper(parts),
              child: const LiquidGlassContainer(
                config: LiquidGlassConfig(
                  effect: CNGlassEffect.regular,
                  shape: CNGlassEffectShape.rect,
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
        if (_mode == _Mode.twoViews)
          Row(
            children: <Widget>[
              SizedBox(
                width: wide,
                child: const LiquidGlassContainer(
                  config: LiquidGlassConfig(effect: CNGlassEffect.regular),
                  child: SizedBox.expand(),
                ),
              ),
              const SizedBox(width: _gap),
              SizedBox(
                width: _circle,
                child: const LiquidGlassContainer(
                  config: LiquidGlassConfig(effect: CNGlassEffect.regular),
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        // Flutter-drawn markers on the same rects the glass is given.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _PartsOutline(parts)),
          ),
        ),
      ],
    );
  }
}

class _PartsClipper extends CustomClipper<Path> {
  const _PartsClipper(this.parts);

  final List<CNGlassPart> parts;

  @override
  Path getClip(Size size) {
    final Path path = Path();
    for (final CNGlassPart part in parts) {
      path.addRRect(
        RRect.fromLTRBR(
          part.left,
          part.top,
          part.left + part.width,
          part.top + part.height,
          Radius.circular(part.radius),
        ),
      );
    }
    return path;
  }

  @override
  bool shouldReclip(_PartsClipper oldClipper) => oldClipper.parts != parts;
}

class _PartsOutline extends CustomPainter {
  const _PartsOutline(this.parts);

  final List<CNGlassPart> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFF00AA);
    for (final CNGlassPart part in parts) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          part.left,
          part.top,
          part.left + part.width,
          part.top + part.height,
          Radius.circular(part.radius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PartsOutline oldDelegate) => oldDelegate.parts != parts;
}
