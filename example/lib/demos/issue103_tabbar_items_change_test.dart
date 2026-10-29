import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #103 — `CNTabBar` stays on its Flutter fallback when its items
/// change while the native bar is being prepared.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/103
/// Found in the Kinetrio app, where a Team tab appears once team data loads,
/// right after launch.
///
/// ### The claim
///
/// `_prepareCreationParams` awaits several times and read `widget.items`
/// again after each await. When the items grew in between, it indexed a list
/// built for the old items past its end and threw. `catchError` swallowed the
/// error and nothing prepared again, so the bar stayed on the Flutter
/// fallback for the rest of the session.
///
/// ### How this screen proves it
///
/// Every mount starts with four tabs and adds a fifth one a moment later
/// (after the first frame, then 16, 40 and 100 ms on each *Replay*). The tabs
/// use SVG image assets, so preparation awaits asset lookups, which is where
/// the window opens. The readout says whether the bar is still the Flutter
/// fallback (a `CupertinoTabBar` under it) or the native bar.
///
///  * **Bug present (1.8.1, simulator, iOS 27):** right after the first
///    frame, "fallback" stays: a flat Flutter tab bar whose selected icon is
///    black (Issue #104). At 16 and 40 ms the native bar appears but keeps
///    the four tabs it was prepared with; Team never shows.
///  * **Bug fixed:** the Liquid Glass bar with five tabs after every mount.
///
/// [autoCycle] replays every four seconds, for screenshots from a device.
class Issue103TabBarItemsChangeTestPage extends StatefulWidget {
  const Issue103TabBarItemsChangeTestPage({super.key, this.autoCycle = false});

  final bool autoCycle;

  @override
  State<Issue103TabBarItemsChangeTestPage> createState() =>
      _Issue103TabBarItemsChangeTestPageState();
}

class _Issue103TabBarItemsChangeTestPageState
    extends State<Issue103TabBarItemsChangeTestPage> {
  static const List<Duration> _delays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 16),
    Duration(milliseconds: 40),
    Duration(milliseconds: 100),
  ];

  static const List<CNTabBarItem> _four = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Home',
      imageAsset: CNImageAsset('assets/icons/home.svg'),
      activeImageAsset: CNImageAsset('assets/icons/home_filled.svg'),
    ),
    CNTabBarItem(
      label: 'Chat',
      imageAsset: CNImageAsset('assets/icons/chat.svg'),
      activeImageAsset: CNImageAsset('assets/icons/chat-filled.svg'),
    ),
    CNTabBarItem(
      label: 'Search',
      imageAsset: CNImageAsset('assets/icons/search.svg'),
      activeImageAsset: CNImageAsset('assets/icons/search-filled.svg'),
    ),
    CNTabBarItem(
      label: 'Profile',
      imageAsset: CNImageAsset('assets/icons/profile.svg'),
      activeImageAsset: CNImageAsset('assets/icons/profile-filled.svg'),
    ),
  ];

  static const CNTabBarItem _team = CNTabBarItem(
    label: 'Team',
    imageAsset: CNImageAsset('assets/icons/card-add.svg'),
  );

  final GlobalKey _barArea = GlobalKey();
  final Stopwatch _sinceMount = Stopwatch();
  Timer? _grow;
  Timer? _poll;
  Timer? _cycle;
  int _mount = 1;
  int _delayIndex = 0;
  int _tabIndex = 0;
  bool _grown = false;
  String _state = '—';

  @override
  void initState() {
    super.initState();
    _start();
    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) => _check());
    if (widget.autoCycle) {
      _cycle = Timer.periodic(const Duration(seconds: 4), (_) => _replay());
    }
  }

  @override
  void dispose() {
    _grow?.cancel();
    _poll?.cancel();
    _cycle?.cancel();
    super.dispose();
  }

  void _start() {
    _grow?.cancel();
    _grown = false;
    _tabIndex = 0;
    _state = '—';
    _sinceMount
      ..reset()
      ..start();
    final Duration delay = _delays[_delayIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _grow = Timer(delay, () {
        if (mounted) setState(() => _grown = true);
      });
    });
  }

  void _replay() {
    setState(() {
      _delayIndex = (_delayIndex + 1) % _delays.length;
      _mount++;
      _start();
    });
  }

  /// The fallback is a `CupertinoTabBar`. Its icons are platform views too,
  /// so looking for a `UiKitView` would not tell the two apart.
  bool _onFallback() {
    final BuildContext? area = _barArea.currentContext;
    if (area is! Element) return true;
    bool found = false;
    void visit(Element element) {
      if (found) return;
      if (element.widget is CupertinoTabBar) {
        found = true;
        return;
      }
      element.visitChildElements(visit);
    }

    visit(area);
    return found;
  }

  void _check() {
    if (!mounted) return;
    final int ms = _sinceMount.elapsedMilliseconds;
    final String state = !_onFallback()
        ? 'native (count the tabs: 5 ✓, 4 ✗)'
        : ms > 3000
        ? 'fallback after ${ms ~/ 1000} s ✗ stuck'
        : 'fallback…';
    if (state != _state) setState(() => _state = state);
  }

  @override
  Widget build(BuildContext context) {
    final List<CNTabBarItem> items = <CNTabBarItem>[
      ..._four,
      if (_grown) _team,
    ];
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#103 · items change early'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(bottom: false, child: _controls(items.length)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              key: _barArea,
              top: false,
              child: CNTabBar(
                key: ValueKey<int>(_mount),
                items: items,
                currentIndex: _tabIndex.clamp(0, items.length - 1),
                onTap: (int i) => setState(() => _tabIndex = i),
                tint: CupertinoColors.systemBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(int count) {
    final Duration delay = _delays[_delayIndex];
    return Align(
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
              'Bug: the bar stays a flat Flutter tab bar (black selected '
              'icon), or the glass bar keeps four tabs. Fixed: the Liquid '
              'Glass bar with five tabs, after every Replay.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 10),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 10),
              onPressed: _replay,
              child: const Text('Replay', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Text(
              'mount #$_mount · 5th tab after first frame'
              '${delay == Duration.zero ? '' : ' + ${delay.inMilliseconds} ms'}'
              ' · $count tabs\nbar: $_state',
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.white,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
