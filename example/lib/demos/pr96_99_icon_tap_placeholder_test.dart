import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #96 and PR #99 verification — `CNIcon` inside a tappable, and what
/// `CNIcon` shows before its native view exists.
///
/// PRs: https://github.com/gunumdogdu/cupertino_native_better/pull/96 and
/// https://github.com/gunumdogdu/cupertino_native_better/pull/99
/// By @yagizdo.
///
/// ### The claims
///
///  * #96: `CNIcon` draws an SF Symbol in a `UiKitView`. Inside a
///    `CupertinoButton` (or any `GestureDetector`), a tap that lands on the
///    symbol shows the pressed state but never calls `onPressed`: the
///    platform view's recognizer joins the gesture arena ahead of the
///    button's and wins the sweep. Only taps on the padding count. This is
///    what `CNButton.icon`, `CNPopupMenuButton` and the `CNTabBar` fallback
///    do below iOS 26, and what any app does that puts a `CNIcon` in its own
///    button on any iOS version.
///  * #99: in debug and profile builds `CNIcon` waits up to 500 ms after a
///    cold start or hot restart for `PlatformViewGuard`, and draws a filled
///    circle meanwhile, so a black dot shows where every icon will land.
///
/// ### How this screen proves it
///
/// The top row is three plain `CNIcon`s. After a cold start or a hot
/// restart in a debug build, watch their first half second:
///
///  * **#99 bug present:** black filled circles, then the symbols.
///  * **#99 fixed:** empty space of the same size, then the symbols.
///
/// Below, two buttons whose whole child is a `CNIcon`, each with a counter:
/// a `CupertinoButton` and a `GestureDetector`. Tap the symbol itself,
/// not the space around it.
///
///  * **#96 bug present:** the counter does not move (the button dims, but
///    `onPressed` never runs).
///  * **#96 fixed:** every tap on the symbol counts.
///
/// The integration test `integration_test/pr96_icon_tap_test.dart` taps the
/// same widgets through the gesture arena on a simulator or device.
class Pr96And99IconTapPlaceholderTestPage extends StatefulWidget {
  const Pr96And99IconTapPlaceholderTestPage({super.key});

  @override
  State<Pr96And99IconTapPlaceholderTestPage> createState() =>
      _Pr96And99IconTapPlaceholderTestPageState();
}

class _Pr96And99IconTapPlaceholderTestPageState
    extends State<Pr96And99IconTapPlaceholderTestPage> {
  int _button = 0;
  int _detector = 0;

  @override
  Widget build(BuildContext context) {
    final Color label = CupertinoColors.label.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #96 / #99 · CNIcon'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              '#99: after a cold start or hot restart (debug), the icons below '
              'must not appear as black dots first.',
              style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                CNIcon(symbol: CNSymbol('star.fill', size: 32)),
                CNIcon(symbol: CNSymbol('heart.fill', size: 32)),
                CNIcon(symbol: CNSymbol('bell.fill', size: 32)),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '#96: tap the symbols themselves. Each tap must count.',
              style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    CupertinoButton(
                      key: const ValueKey<String>('pr96-button'),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => setState(() => _button++),
                      child: const CNIcon(
                        symbol: CNSymbol('hand.tap.fill', size: 56),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CupertinoButton: $_button',
                      style: TextStyle(color: label),
                    ),
                  ],
                ),
                Column(
                  children: <Widget>[
                    GestureDetector(
                      key: const ValueKey<String>('pr96-detector'),
                      onTap: () => setState(() => _detector++),
                      child: const CNIcon(
                        symbol: CNSymbol('hand.point.up.left.fill', size: 56),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GestureDetector: $_detector',
                      style: TextStyle(color: label),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
