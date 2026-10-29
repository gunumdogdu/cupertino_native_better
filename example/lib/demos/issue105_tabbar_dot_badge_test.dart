import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #105 — a dot badge on `CNTabBar` and `CNTabRail` tabs.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/105
/// Requested from the Kinetrio app.
///
/// ### The request
///
/// A tab that only says "something is new": a small red dot, no count.
/// `UITabBarItem` has no dot badge (an empty value means none), and the
/// Kinetrio app's zero-width-space badge drew a full-size red badge with no
/// text on iOS 26 and 27. `badge: CNTabBarItem.dotBadge` now draws a 9 pt dot
/// at the top-right of the icon.
///
/// ### How this screen checks it
///
/// Home and Alerts carry a dot, Library a count of 3, and *Dot on Profile*
/// adds or removes a dot through the badge-only update path. The rail on the
/// right shows the same items.
///
///  * **Before:** a full-size empty red badge on Home and Alerts.
///  * **After:** a small dot at the top-right of their icons, in place after
///    *Next tab*, *split* and *Dot on Profile*, and in the rail.
///
/// [autoCycle] steps through those cases on its own every two seconds, for
/// screenshots from a device.
class Issue105TabBarDotBadgeTestPage extends StatefulWidget {
  const Issue105TabBarDotBadgeTestPage({super.key, this.autoCycle = false});

  final bool autoCycle;

  @override
  State<Issue105TabBarDotBadgeTestPage> createState() =>
      _Issue105TabBarDotBadgeTestPageState();
}

class _Issue105TabBarDotBadgeTestPageState
    extends State<Issue105TabBarDotBadgeTestPage> {
  bool _split = false;
  bool _profileDot = false;
  int _tabIndex = 0;
  int _step = 0;
  Timer? _cycle;

  List<CNTabBarItem> get _items => <CNTabBarItem>[
    const CNTabBarItem(
      label: 'Home',
      icon: CNSymbol('house'),
      activeIcon: CNSymbol('house.fill'),
      badge: CNTabBarItem.dotBadge,
    ),
    const CNTabBarItem(
      label: 'Library',
      icon: CNSymbol('books.vertical'),
      activeIcon: CNSymbol('books.vertical.fill'),
      badge: '3',
    ),
    const CNTabBarItem(
      label: 'Alerts',
      icon: CNSymbol('bell'),
      activeIcon: CNSymbol('bell.fill'),
      badge: CNTabBarItem.dotBadge,
    ),
    CNTabBarItem(
      label: 'Profile',
      icon: const CNSymbol('person'),
      activeIcon: const CNSymbol('person.fill'),
      badge: _profileDot ? CNTabBarItem.dotBadge : null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _cycle = Timer.periodic(const Duration(seconds: 2), (_) => _advance());
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  /// One case per tick: the next tab four times, then the Profile dot, then
  /// split, and again.
  void _advance() {
    setState(() {
      _step++;
      if (_step % 6 == 4) {
        _profileDot = !_profileDot;
      } else if (_step % 6 == 5) {
        _split = !_split;
      } else {
        _tabIndex = (_tabIndex + 1) % 4;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#105 · dot badge'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _controls(),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: CNTabRail(
                        items: _items,
                        currentIndex: _tabIndex,
                        onTap: (int i) => setState(() => _tabIndex = i),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CNTabBar(
                key: ValueKey<bool>(_split),
                items: _items,
                currentIndex: _tabIndex,
                onTap: (int i) => setState(() => _tabIndex = i),
                tint: CupertinoColors.systemBlue,
                split: _split,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Before: a full-size empty red badge on Home and Alerts. After: '
            'a small dot at the top-right of their icons, also after Next '
            'tab, split and Dot on Profile, and in the rail.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          CupertinoSegmentedControl<bool>(
            groupValue: _split,
            onValueChanged: (bool v) => setState(() => _split = v),
            children: const <bool, Widget>{
              false: Text('single', style: TextStyle(fontSize: 12)),
              true: Text('split', style: TextStyle(fontSize: 12)),
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _button(
                'Next tab',
                () => setState(() => _tabIndex = (_tabIndex + 1) % 4),
              ),
              const SizedBox(width: 8),
              _button(
                'Dot on Profile',
                () => setState(() => _profileDot = !_profileDot),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_split ? 'split' : 'single'} · tab $_tabIndex · Profile dot '
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
