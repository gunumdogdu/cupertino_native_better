import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #97 and PR #98 verification — what a fresh `CNTabBar` shows in its
/// first moments on iOS 26 and later.
///
/// PRs: https://github.com/gunumdogdu/cupertino_native_better/pull/97 and
/// https://github.com/gunumdogdu/cupertino_native_better/pull/98
/// By @yagizdo.
///
/// ### The claims
///
///  * #97: until its creation params are ready (and, in debug builds, for
///    `PlatformViewGuard`'s 500 ms after a cold start), `CNTabBar` builds the
///    pre-iOS 26 `CupertinoTabBar` fallback, so a flat full-width bar flashes
///    before the Liquid Glass bar replaces it.
///  * #98: right after the native bar is created, `refresh` cycles the
///    selection through every tab (a workaround for missing labels, #6),
///    yielding to the run loop between tabs, so the Liquid Glass pill jumps
///    across the tabs before it settles on `currentIndex` (the #35 glitch).
///
/// ### How this screen proves it
///
/// *Remount* gives the bar a new key, so a fresh native bar is built with
/// `currentIndex` 0 (Home). Record the screen and step through the frames
/// after each remount.
///
///  * **#97 bug present:** a flat, full-width bar (the fallback) in the first
///    frames. **Fixed:** an empty slot, then the glass bar.
///  * **#98 bug present:** the selection pill on Library, Alerts or Profile
///    in some frames before it rests on Home. **Fixed:** every frame shows
///    Home selected.
///
/// [autoCycle] remounts every three seconds, alternating single and split.
class Pr97And98TabBarMountTestPage extends StatefulWidget {
  const Pr97And98TabBarMountTestPage({super.key, this.autoCycle = false});

  final bool autoCycle;

  @override
  State<Pr97And98TabBarMountTestPage> createState() =>
      _Pr97And98TabBarMountTestPageState();
}

class _Pr97And98TabBarMountTestPageState
    extends State<Pr97And98TabBarMountTestPage> {
  static const List<CNTabBarItem> _items = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Home',
      icon: CNSymbol('house'),
      activeIcon: CNSymbol('house.fill'),
    ),
    CNTabBarItem(
      label: 'Library',
      icon: CNSymbol('books.vertical'),
      activeIcon: CNSymbol('books.vertical.fill'),
    ),
    CNTabBarItem(
      label: 'Alerts',
      icon: CNSymbol('bell'),
      activeIcon: CNSymbol('bell.fill'),
    ),
    CNTabBarItem(
      label: 'Profile',
      icon: CNSymbol('person'),
      activeIcon: CNSymbol('person.fill'),
    ),
  ];

  int _mount = 1;
  int _index = 0;
  bool _split = false;
  Timer? _cycle;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _cycle = Timer.periodic(const Duration(seconds: 3), (_) {
        _remount(split: _mount.isEven ? !_split : _split);
      });
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  void _remount({bool? split}) {
    setState(() {
      _mount++;
      _index = 0;
      _split = split ?? _split;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #97 / #98 · tab bar mount'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.all(12),
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
                        'Record the screen and step through the frames after '
                        'Remount. Bug: a flat full-width bar first (#97), or '
                        'the selection pill visiting other tabs before it '
                        'rests on Home (#98).',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CupertinoSegmentedControl<bool>(
                        groupValue: _split,
                        onValueChanged: (bool v) => _remount(split: v),
                        children: const <bool, Widget>{
                          false: Text('single', style: TextStyle(fontSize: 12)),
                          true: Text('split', style: TextStyle(fontSize: 12)),
                        },
                      ),
                      const SizedBox(height: 10),
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onPressed: _remount,
                        child: const Text(
                          'Remount',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'mount #$_mount · ${_split ? 'split' : 'single'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
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
                key: ValueKey<int>(_mount),
                items: _items,
                currentIndex: _index,
                onTap: (int i) => setState(() => _index = i),
                tint: CupertinoColors.systemBlue,
                split: _split,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
