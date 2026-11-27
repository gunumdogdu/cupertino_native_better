import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #199: report the scroll edge band's light or dark appearance to
/// Flutter, so content in the band can match.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/199
/// Requested by @Ashhad08 (PR #200).
///
/// ### The claim
///
/// Over dark content iOS draws the edge effect dark and switches the views
/// in its container to the dark appearance, so a native title turns white.
/// A Flutter title in the band can't follow by itself; a dynamic colour
/// follows the app's brightness. `CNScrollEdgeEffect.onAppearanceChanged`
/// reports each switch.
///
/// ### How this screen proves it
///
/// A list of light and dark blocks runs under a top `CNScrollEdgeEffect`. A
/// Flutter "Title" sits in the band, white while the last reported
/// appearance is dark and black otherwise; the pill at the bottom shows it.
/// AUTO scrolls a dark block, a light block and a dark block under the band,
/// then switches to `hard` and back over the dark block, then puts a dark
/// block under an explicitly `soft` band (iOS 27's default is hard), printing
/// `CNB_SHOT 199-<step> <appearance>` after each step and
/// `CNB_APPEAR199 <appearance>` for every report.
///
///  * **Expected on iOS 26:** the title is white over the dark blocks and
///    black over the light one. With `hard` the band is an opaque band of
///    the page colour, so the title should be dark there, as with Reduce
///    Transparency on.
///  * **Expected on iOS 27:** "light" at every step. iOS 27 doesn't switch
///    the band, not even a `soft` one; the status bar stays dark too.
class Issue199ScrollEdgeAppearanceTestPage extends StatefulWidget {
  /// Creates the #199 test page.
  const Issue199ScrollEdgeAppearanceTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Steps through the blocks and styles, printing `CNB_SHOT`.
  final bool autoCycle;

  @override
  State<Issue199ScrollEdgeAppearanceTestPage> createState() =>
      _Issue199ScrollEdgeAppearanceTestPageState();
}

class _Issue199ScrollEdgeAppearanceTestPageState
    extends State<Issue199ScrollEdgeAppearanceTestPage> {
  static const double _block = 220;
  static const double _gap = 56;

  final ScrollController _controller = ScrollController();
  CNScrollEdgeStyle _style = CNScrollEdgeStyle.automatic;
  Brightness? _band;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) unawaited(_run());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The scroll offset that puts block [index]'s top 10 pt above the screen,
  /// so the band is inside the block.
  double _offsetFor(int index) =>
      MediaQuery.paddingOf(context).top + _gap + index * _block + 10;

  Future<void> _run() async {
    Future<void> step(String tag, FutureOr<void> Function() action) async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) debugPrint('CNB_SHOT 199-$tag ${_band?.name ?? 'none'}');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await step('rest', () {});
    await step('dark1', () => _controller.jumpTo(_offsetFor(1)));
    await step('light2', () => _controller.jumpTo(_offsetFor(2)));
    await step('dark3', () => _controller.jumpTo(_offsetFor(3)));
    await step('hard', () => setState(() => _style = CNScrollEdgeStyle.hard));
    await step(
      'automatic',
      () => setState(() => _style = CNScrollEdgeStyle.automatic),
    );
    await step('light4', () => _controller.jumpTo(_offsetFor(4)));
    await step('softDark5', () {
      setState(() => _style = CNScrollEdgeStyle.soft);
      _controller.jumpTo(_offsetFor(5));
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final dark = _band == Brightness.dark;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          ListView.builder(
            controller: _controller,
            padding: EdgeInsets.fromLTRB(
              0,
              padding.top + _gap,
              0,
              padding.bottom + 400,
            ),
            itemCount: 8,
            itemBuilder: (context, i) => Container(
              height: _block,
              alignment: Alignment.center,
              color: i.isOdd
                  ? const Color(0xFF101014)
                  : const Color(0xFFF2F2F7),
              child: Text(
                'Block $i',
                style: TextStyle(
                  fontSize: 22,
                  color: i.isOdd
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF000000),
                ),
              ),
            ),
          ),
          CNScrollEdgeEffect(
            height: padding.top + 44,
            style: _style,
            controller: _controller,
            onAppearanceChanged: (b) {
              debugPrint('CNB_APPEAR199 ${b.name}');
              setState(() => _band = b);
            },
          ),
          Positioned(
            top: padding.top + 10,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Title',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: dark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF000000),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: padding.bottom + 12,
            child: Center(
              child: CNButton(
                label:
                    'Band: ${_band?.name ?? 'not reported'} · ${_style.name}',
                config: const CNButtonConfig(shrinkWrap: true),
                onPressed: () => setState(
                  () => _style = _style == CNScrollEdgeStyle.hard
                      ? CNScrollEdgeStyle.automatic
                      : CNScrollEdgeStyle.hard,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
