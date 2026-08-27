import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #69 verification — `LiquidGlassConfig.effect` never reaches the glass.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/69
/// Reported by @johndavid92.
///
/// ### The claim
///
/// `LiquidGlassConfig.effect` is serialised over the channel as
/// `'effect': config.effect.name`, parsed natively, stored, handed to the
/// SwiftUI view and even used as an `.animation(_:value:)` key — and then
/// `glassEffectForConfig()` ignores it and hardcodes `Glass.regular` on both
/// iOS and macOS. So `CNGlassEffect.regular` and `CNGlassEffect.prominent`
/// render identically, and SwiftUI's third variant, `Glass.clear`, is
/// unreachable.
///
/// ### How this screen proves it
///
/// One panel per value of `CNGlassEffect.values`, so this file compiles both
/// before the PR (two panels) and after it (three) without edits — the panel
/// count is itself a readout of the enum.
///
/// Every panel is the **same size at the same x**, stacked vertically over a
/// backdrop of **vertical stripes that never vary along y**. That matters:
/// it means each panel sees a pixel-identical backdrop, so any difference
/// between two panel crops is the glass and nothing else. Crop two panels out
/// of a screenshot, diff them, and the answer is not a matter of opinion:
///
///  * **Bug present:** the `regular` and `prominent` crops are identical to
///    the pixel — the effect never reached the glass.
///  * **Bug fixed:** `clear` is visibly sharper than the other two, because
///    it passes the stripes through instead of frosting them.
///
/// Fine stripes are deliberate. `.regular` frosts what is behind it, so it
/// smears a high-frequency pattern into flat grey; `.clear` leaves the
/// stripes legible. A photo backdrop is also offered, since "glass over
/// imagery" is the case that motivated the PR.
class Pr69GlassEffectTestPage extends StatefulWidget {
  const Pr69GlassEffectTestPage({
    super.key,
    this.initialBackdrop,
    this.initialTinted,
  });

  /// `stripes` or `photo`. Lets a probe launch pick a configuration without
  /// tapping through the UI.
  final String? initialBackdrop;

  /// Whether to apply a tint, which is the other input `glassEffectForConfig`
  /// reads — useful for checking the fix didn't disturb it.
  final bool? initialTinted;

  @override
  State<Pr69GlassEffectTestPage> createState() =>
      _Pr69GlassEffectTestPageState();
}

class _Pr69GlassEffectTestPageState extends State<Pr69GlassEffectTestPage> {
  bool _photo = false;
  bool _tinted = false;

  /// Fixed geometry so panel crops line up across builds and screenshots.
  static const double _panelWidth = 300;
  static const double _panelHeight = 92;
  static const double _panelGap = 26;

  @override
  void initState() {
    super.initState();
    if (widget.initialBackdrop == 'photo') _photo = true;
    if (widget.initialTinted != null) _tinted = widget.initialTinted!;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('PR #69 · ${CNGlassEffect.values.length} effect values'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _photo
                ? Image.asset('assets/home.jpg', fit: BoxFit.cover)
                : CustomPaint(painter: _StripePainter()),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  if (widget.initialBackdrop == null) _controls(),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: CNGlassEffect.values
                            .map(_panel)
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(CNGlassEffect effect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _panelGap),
      child: SizedBox(
        width: _panelWidth,
        height: _panelHeight,
        child: LiquidGlassContainer(
          config: LiquidGlassConfig(
            effect: effect,
            shape: CNGlassEffectShape.rect,
            cornerRadius: 22,
            tint: _tinted ? CupertinoColors.systemPink : null,
          ),
          child: Center(
            child: Text(
              effect.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
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
          const Text(
            'Panels are identical in size and x, stacked over stripes that '
            'never vary along y — so every panel sees the same backdrop. '
            'Two panels that render differently can only differ because of '
            'the glass.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              CupertinoSegmentedControl<bool>(
                groupValue: _photo,
                onValueChanged: (bool v) => setState(() => _photo = v),
                children: const <bool, Widget>{
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('stripes', style: TextStyle(fontSize: 12)),
                  ),
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('photo', style: TextStyle(fontSize: 12)),
                  ),
                },
              ),
              const SizedBox(width: 12),
              CupertinoSegmentedControl<bool>(
                groupValue: _tinted,
                onValueChanged: (bool v) => setState(() => _tinted = v),
                children: const <bool, Widget>{
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('no tint', style: TextStyle(fontSize: 12)),
                  ),
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('tinted', style: TextStyle(fontSize: 12)),
                  ),
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vertical stripes, constant along y.
///
/// Constant-along-y is the whole point: panels at different heights sit over
/// an identical backdrop, so their crops can be compared directly. Fine
/// stripes also make frosting obvious — `.regular` smears them, `.clear`
/// does not.
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double period = 8;
    final Paint dark = Paint()..color = const Color(0xFF101014);
    final Paint light = Paint()..color = const Color(0xFFF2F2F7);
    canvas.drawRect(Offset.zero & size, dark);
    for (double x = 0; x < size.width; x += period) {
      canvas.drawRect(Rect.fromLTWH(x, 0, period / 2, size.height), light);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
