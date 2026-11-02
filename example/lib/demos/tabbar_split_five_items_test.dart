import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// `CNTabBar(split: true, rightCount: 1)` on iOS 26+, with five items.
///
/// ### The problem
///
/// With five items, the right bar got 1/5 of the width, and iOS 26 drew its
/// single item as a narrow pill, taller than wide, with the icon and label
/// shrunk inside. With four it got 1/4 and was a circle. The gap between
/// the two groups was also `splitSpacing` plus about 44 pt: iOS 26 centres
/// each glass capsule in its bar, with about 22 pt of empty bar on each side.
///
/// ### How this screen checks it
///
/// The bar is not keyed, so each control goes through its own native update
/// path: *Labels* rebuilds the items (`setItems`), *Split* the layout
/// (`setLayout`), and *Dot on Profile* puts a dot badge on the right item.
///
///  * **Before:** a narrow pill around a shrunken Profile icon, far from the
///    other four.
///  * **After:** Profile in a circle with its label, about 12 pt from the
///    capsule of the other four, after each control too. Tapping between
///    the two capsules selects nothing.
class TabBarSplitFiveItemsTestPage extends StatefulWidget {
  const TabBarSplitFiveItemsTestPage({super.key});

  @override
  State<TabBarSplitFiveItemsTestPage> createState() =>
      _TabBarSplitFiveItemsTestPageState();
}

class _TabBarSplitFiveItemsTestPageState
    extends State<TabBarSplitFiveItemsTestPage> {
  bool _split = true;
  bool _labels = true;
  bool _profileDot = false;
  int _tabIndex = 0;

  List<CNTabBarItem> get _items => <CNTabBarItem>[
    CNTabBarItem(
      label: _labels ? 'Home' : null,
      icon: const CNSymbol('house.fill'),
    ),
    CNTabBarItem(
      label: _labels ? 'Search' : null,
      icon: const CNSymbol('magnifyingglass'),
    ),
    CNTabBarItem(
      label: _labels ? 'Map' : null,
      icon: const CNSymbol('map.fill'),
    ),
    CNTabBarItem(
      label: _labels ? 'Activity' : null,
      icon: const CNSymbol('bell.fill'),
    ),
    CNTabBarItem(
      label: _labels ? 'Profile' : null,
      icon: const CNSymbol('person.crop.circle.fill'),
      badge: _profileDot ? CNTabBarItem.dotBadge : null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('TabBar split · five items'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: SafeArea(bottom: false, child: _controls())),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CNTabBar(
                items: _items,
                currentIndex: _tabIndex,
                onTap: (int i) => setState(() => _tabIndex = i),
                tint: CupertinoColors.systemBlue,
                split: _split,
                rightCount: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Before: a narrow pill around a shrunken Profile icon, far from '
            'the other tabs. After: Profile in a circle with its label, '
            'about 12 pt away, also after Labels, Split and Dot on Profile.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _button('Labels', () => setState(() => _labels = !_labels)),
              const SizedBox(width: 8),
              _button('Split', () => setState(() => _split = !_split)),
              const SizedBox(width: 8),
              _button(
                'Dot on Profile',
                () => setState(() => _profileDot = !_profileDot),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_split ? 'split' : 'single'} · labels '
            '${_labels ? 'on' : 'off'} · tab $_tabIndex · Profile dot '
            '${_profileDot ? 'on' : 'off'}',
            style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed) {
    return Expanded(
      child: CupertinoButton.filled(
        padding: const EdgeInsets.symmetric(vertical: 10),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
