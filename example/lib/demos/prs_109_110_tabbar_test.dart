import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PRs #109 and #110 — `CNTabBar` after its size or its props change.
///
/// PR #109: https://github.com/gunumdogdu/cupertino_native_better/pull/109
/// PR #110: https://github.com/gunumdogdu/cupertino_native_better/pull/110
/// Both by @yagizdo.
///
/// ### The claims
///
///  * **#109:** a bar first laid out narrow or invisible keeps labels sized
///    for that width once it gets its real size ("Favo…", missing or shrunk
///    labels), on iOS 26 and 27.
///  * **#110:** with `autoHideOnModal`, a bar destroyed under a sheet comes
///    back with the props it was first created with: a badge, label or tint
///    changed after mount reverts when the sheet closes.
///
/// ### How this screen proves it
///
/// Each mode plays by itself (`PROBE=pr109fade`, `pr109narrow`, `pr110`):
///
///  * **fade** mounts the bar inside `Opacity(0)` and fades it in at 3 s.
///  * **narrow** mounts the bar 140 pt wide and widens it at 3 s.
///  * **props** shows badge 3, "Discover" and blue; at 3 s it switches to
///    badge 7, "Explore" and pink; at 4.5 s it opens a sheet and closes it
///    at 6.5 s. Needs `CNTabBarRouteObserver` (`--dart-define=OBSERVER=true`).
///
/// Judge the settled bar after the last step:
///
///  * **Bug present:** cut, missing or shrunk labels (#109); badge 3,
///    "Discover" or blue after the sheet (#110).
///  * **Fixed:** full labels; badge 7, "Explore" and pink after the sheet.
class Prs109110TabBarTestPage extends StatefulWidget {
  const Prs109110TabBarTestPage({super.key, required this.mode});

  /// `fade`, `narrow` or `props`.
  final String mode;

  @override
  State<Prs109110TabBarTestPage> createState() =>
      _Prs109110TabBarTestPageState();
}

class _Prs109110TabBarTestPageState extends State<Prs109110TabBarTestPage> {
  int _tab = 0;
  bool _changed = false;
  String _step = 'start';
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _after(
      3000,
      () => setState(() {
        _changed = true;
        _step = widget.mode == 'props' ? 'props changed' : 'resized';
      }),
    );
    if (widget.mode == 'props') {
      _after(4500, () {
        setState(() => _step = 'sheet open');
        CNBottomSheet.showCupertino<void>(
          context: context,
          pageBuilder: (_) =>
              const CupertinoPageScaffold(child: Center(child: Text('Sheet'))),
        );
      });
      _after(6500, () {
        Navigator.of(context).maybePop();
        setState(() => _step = 'sheet closed');
      });
    }
  }

  void _after(int ms, VoidCallback f) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }),
  );

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  List<CNTabBarItem> get _items => [
    const CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
    CNTabBarItem(
      label: _changed && widget.mode == 'props' ? 'Explore' : 'Discover',
      icon: const CNSymbol('safari'),
      badge: _changed && widget.mode == 'props' ? '7' : '3',
    ),
    const CNTabBarItem(label: 'Favourites', icon: CNSymbol('heart.fill')),
    const CNTabBarItem(label: 'Settings', icon: CNSymbol('gearshape.fill')),
  ];

  @override
  Widget build(BuildContext context) {
    final bar = CNTabBar(
      items: _items,
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      tint: _changed && widget.mode == 'props'
          ? CupertinoColors.systemPink
          : CupertinoColors.systemBlue,
    );
    final Widget placed = switch (widget.mode) {
      'fade' => AnimatedOpacity(
        opacity: _changed ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        child: bar,
      ),
      'narrow' => Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: Duration.zero,
          width: _changed ? MediaQuery.sizeOf(context).width : 140,
          child: bar,
        ),
      ),
      _ => bar,
    };
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('#109 / #110 · ${widget.mode}'),
      ),
      child: Column(
        children: [
          Expanded(child: Center(child: Text('step: $_step'))),
          SafeArea(top: false, child: placed),
        ],
      ),
    );
  }
}
