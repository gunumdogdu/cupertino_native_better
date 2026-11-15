import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

/// PR #162: touches in the room above `CNTabBar`'s capsule were dropped.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/162
/// Reported by @djedi.
///
/// ### The claim
///
/// The native bar sits 14 pt below the top of its platform view, to leave
/// room for the Liquid Glass pill, and the iOS 26 capsule doesn't fill the
/// bar's width. A touch in that room, or beside the capsule, hit the bare
/// view behind the bar and did nothing, where a native app sends it to the
/// content behind the bar. Now the native bar tells Flutter where it takes
/// touches, found with UIKit's own hit testing, and any other touch on the
/// view goes to the Flutter content behind it.
///
/// A bar shorter than its own height draws its icons up past its capsule,
/// into that room. A touch on that part of an icon now selects its tab, as
/// a touch on the capsule does.
///
/// ### How this screen proves it
///
/// A list scrolls behind a floating `CNTabBar`; tapping a row shows it at
/// the top. **Short bar** swaps in an icon-only bar 60 pt high, whose icons
/// reach above its capsule. AUTO taps the room above the capsule and the
/// space beside it, printing `CNB_TAP` lines and `CNB_SHOT 162-<step>`.
///
///  * **Bug:** a tap just above or beside the capsule does nothing.
///  * **Fixed:** that tap reaches the row behind the bar, and a tap on the
///    top of a short bar's icon selects its tab.
class Issue162TabBarTouchRegionsTestPage extends StatefulWidget {
  /// Creates the #162 test page.
  const Issue162TabBarTouchRegionsTestPage({super.key, this.autoCycle = false});

  /// Taps above and beside the capsule on its own and prints the results.
  final bool autoCycle;

  @override
  State<Issue162TabBarTouchRegionsTestPage> createState() =>
      _Issue162TabBarTouchRegionsTestPageState();
}

class _Issue162TabBarTouchRegionsTestPageState
    extends State<Issue162TabBarTouchRegionsTestPage> {
  final _barKey = GlobalKey();
  int _tab = 0;
  bool _short = false;
  String _last = 'Tap a row, or just above or beside the tab bar.';
  int _pointer = 7000;

  static const _labeled = <CNTabBarItem>[
    CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
    CNTabBarItem(label: 'Search', icon: CNSymbol('magnifyingglass')),
    CNTabBarItem(label: 'Profile', icon: CNSymbol('person.fill')),
  ];
  static const _iconOnly = <CNTabBarItem>[
    CNTabBarItem(icon: CNSymbol('house.fill'), semanticLabel: 'Home'),
    CNTabBarItem(icon: CNSymbol('magnifyingglass'), semanticLabel: 'Search'),
    CNTabBarItem(icon: CNSymbol('person.fill'), semanticLabel: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future.delayed(const Duration(seconds: 5), _auto);
    }
  }

  Future<void> _tapAt(Offset global) async {
    final p = _pointer++;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: p, position: global),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(pointer: p, position: global),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _auto() async {
    for (final short in [false, true]) {
      if (!mounted) return;
      setState(() => _short = short);
      await Future<void>.delayed(const Duration(seconds: 2));
      final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !mounted) return;
      final step = short ? 'short' : 'intrinsic';
      final spots = <String, Offset>{
        'above': Offset(box.size.width / 2, 4),
        'beside': Offset(6, box.size.height - 20),
      };
      for (final spot in spots.entries) {
        final before = _last;
        await _tapAt(box.localToGlobal(spot.value));
        debugPrint(
          'CNB_TAP 162-$step at=${spot.key} '
          'reachedRow=${_last != before && _last.startsWith('Row')} last="$_last"',
        );
      }
      debugPrint('CNB_SHOT 162-$step');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top + 44;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('#162 Tab bar touches'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _short = !_short),
          child: Text(_short ? 'Full bar' : 'Short bar'),
        ),
      ),
      child: Stack(
        children: [
          ListView.builder(
            padding: EdgeInsets.only(top: top + 44, bottom: 140 + bottom),
            itemCount: 40,
            itemBuilder: (context, i) => CupertinoListTile(
              title: Text('Row $i'),
              subtitle: const Text('Tap me, or tap the bar\'s empty room'),
              onTap: () => setState(() => _last = 'Row $i tapped'),
            ),
          ),
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: CupertinoColors.systemGroupedBackground.resolveFrom(
                context,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  '$_last  ·  tab $_tab',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: CNTabBar(
              key: _barKey,
              items: _short ? _iconOnly : _labeled,
              currentIndex: _tab,
              height: _short ? 60 : null,
              onTap: (i) => setState(() {
                _tab = i;
                _last = 'Tab $i selected';
              }),
            ),
          ),
        ],
      ),
    );
  }
}
