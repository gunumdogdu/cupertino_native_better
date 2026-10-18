import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Issue #68 verification — `CNTabBar` drops the second of two rapid taps on
/// different tabs.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/68
/// Reported by @rcahuich (1.5.4, Flutter 3.44.9, iPhone 17 simulator on
/// iOS 26.5, debug build).
///
/// ### The claim
///
/// Tap one tab and then, straight away, a different one: `onTap` fires for
/// the first and never for the second — not late, not out of order, never.
/// The native highlight stays on the first tab as well. The same app logic
/// on a Flutter bar (Android) keeps both taps, so only the iOS platform-view
/// path loses them.
///
/// **Step 0 — the reporter's own repro, before using this screen.** In the
/// example app open *Testing → Bottom Nav Test (IndexedStack)*, tap *Browse*
/// and then *Library* as fast as you can, go back to *Home* and read *Total
/// Taps* and the *Tap Log*. Bug present: one tap short, and the highlight
/// stuck on *Browse*.
///
/// ### Where the touch can be lost
///
/// Nothing in the plugin filters a tap once the native bar has selected:
/// Swift `tabBar(_:didSelect:)` always sends `valueChanged`, Dart always
/// calls `onTap` for it (reselects included), and `setSelectedIndex` sets
/// no suppression flag. The plugin's only drop window is its `refresh`
/// cycle, which sets `bar.delegate = nil` for tens of milliseconds at +50 ms
/// and +200 ms after every native view creation — over long before a user
/// taps a settled bar. That leaves two layers below the plugin:
///
///  1. **UIKit side** — Flutter receives the touch and the platform view's
///     `EagerGestureRecognizer` claims it, but the native `UITabBar` never
///     selects: it ignores a touch during its iOS 26 selection animation, or
///     the engine's delaying gesture recognizer does not release the touch.
///  2. **Engine side** — the touch never reaches Flutter at all: the engine's
///     forwarding gesture recognizer is stuck (flutter/flutter#179907 removed
///     its reset workaround on iOS 26).
///
/// ### How this screen proves it
///
/// The bar sits in a `Listener`, which sees every pointer Flutter receives
/// over the bar without entering the gesture arena, so it cannot change the
/// outcome. It logs each `down` (with its x and the gap since the previous
/// down), each `up` and any `CANCEL`; each `onTap` is logged with the gap
/// since the previous `onTap`. Times are milliseconds since the page opened.
/// After 0.7 s without events, everything since the last pause is closed
/// into a *burst* and tallied as `downs/onTaps`.
///
/// Tap two different tabs fast (under ~250 ms apart — the log shows the
/// gap), pause a second, and repeat about twenty times. Tap item centres,
/// with one finger. Each pair then reads as one of:
///
///  * `2/2` — both touches reached Flutter and the bar: no drop this time.
///  * `2/1` — Flutter got the second touch but the native bar never selected
///    it: layer 1 (UIKit, delaying recognizer), or the plugin's refresh
///    window if the lines carry an `R+` stamp. A down marked `OVERLAP`
///    landed before the first finger lifted; a `UIView` takes one touch at a
///    time unless it is `multipleTouchEnabled`, so redo such a pair with one
///    finger before counting it.
///  * `1/1` (after two taps) — the second touch never reached Flutter:
///    layer 2, the engine. Not fixable in the plugin.
///  * any `CANCEL` — the engine cancelled a forwarded touch; note it with
///    the pair.
///
///  * **Bug present:** with `CNTabBar`, some fast pairs read `2/1` or `1/1`
///    and the highlight stays on the first tab of the pair, while both
///    controls below stay clean. Which of the two patterns shows up is the
///    answer to where the touch is lost.
///  * **Bug fixed:** twenty fast pairs on `CNTabBar` all read `2/2`, in a
///    debug build and in a profile or release build.
///
/// ### Controls
///
///  * **CupertinoTabBar** — the same five items in the same `Listener`, all
///    Flutter, no platform view. Expect `2/2` for every pair; if it drops
///    too, the problem is the tapping, not the native bar.
///  * **Slow taps** — on `CNTabBar`, tap, wait a second, tap another tab.
///    Each tap is its own burst and must read `1/1`.
///  * **Recreate bar** — remounts `CNTabBar` under a new key, which creates
///    a new native view and runs both refresh passes again. This probes the
///    plugin's own drop window, not the reported bug: press it, then at once
///    tap one *different* tab. Events are stamped `R+ms` since the press. A
///    `1/0` burst at roughly R+100…400 ms is the refresh window eating the
///    tap. Taps in the first frames after the press land on the Flutter
///    fallback bar `CNTabBar` draws while it prepares, which always fires
///    `onTap`.
///
/// Test in a debug build first and then, because the timing differs, in a
/// profile or release build; the readout names the mode. Only the native
/// iOS 26 bar is under test, so the readout must end in `native`. If this
/// screen never drops but step 0 does, the difference is that page's content
/// (an `IndexedStack` swap on every tap) — itself worth noting on the issue.
class Issue68TabBarRapidTapsTestPage extends StatefulWidget {
  const Issue68TabBarRapidTapsTestPage({super.key});

  @override
  State<Issue68TabBarRapidTapsTestPage> createState() =>
      _Issue68TabBarRapidTapsTestPageState();
}

enum _Bar { native, flutter }

/// One log line; [alert] lines are bursts that lost a tap.
class _LogLine {
  const _LogLine(this.text, {this.alert = false});

  final String text;
  final bool alert;
}

class _Issue68TabBarRapidTapsTestPageState
    extends State<Issue68TabBarRapidTapsTestPage> {
  /// Quiet time that closes a burst. A fast pair sits well inside it; taps a
  /// second apart land in separate bursts.
  static const Duration _quiet = Duration(milliseconds: 700);

  /// How long after *Recreate bar* events carry an `R+ms` stamp.
  static const int _recreateWindowMs = 1500;

  static const int _maxLog = 40;

  static const List<String> _labels = <String>[
    'Home',
    'Library',
    'Chat',
    'Alerts',
    'Profile',
  ];

  // No iconSize anywhere, so no setItems call is involved.
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
      label: 'Chat',
      icon: CNSymbol('bubble.left'),
      activeIcon: CNSymbol('bubble.left.fill'),
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

  static const List<BottomNavigationBarItem> _flutterItems =
      <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          label: 'Home',
          icon: Icon(CupertinoIcons.house),
          activeIcon: Icon(CupertinoIcons.house_fill),
        ),
        BottomNavigationBarItem(
          label: 'Library',
          icon: Icon(CupertinoIcons.book),
          activeIcon: Icon(CupertinoIcons.book_fill),
        ),
        BottomNavigationBarItem(
          label: 'Chat',
          icon: Icon(CupertinoIcons.chat_bubble),
          activeIcon: Icon(CupertinoIcons.chat_bubble_fill),
        ),
        BottomNavigationBarItem(
          label: 'Alerts',
          icon: Icon(CupertinoIcons.bell),
          activeIcon: Icon(CupertinoIcons.bell_fill),
        ),
        BottomNavigationBarItem(
          label: 'Profile',
          icon: Icon(CupertinoIcons.person),
          activeIcon: Icon(CupertinoIcons.person_fill),
        ),
      ];

  final Stopwatch _clock = Stopwatch();

  _Bar _bar = _Bar.native;
  int _tabIndex = 0;

  /// Part of the `CNTabBar` key; bumped by *Recreate bar*.
  int _mount = 1;
  int? _recreatedAtMs;

  int _downs = 0;
  int _ups = 0;
  int _cancels = 0;
  int _taps = 0;
  int? _lastDownMs;
  int? _lastTapMs;

  /// Pointers currently down over the bar, to flag a second finger landing
  /// before the first lifted.
  final Set<int> _activePointers = <int>{};

  int _burstDowns = 0;
  int _burstTaps = 0;
  int _burstCancels = 0;
  bool _burstOverlap = false;
  Timer? _burstTimer;

  /// `downs/onTaps` → number of bursts, in first-seen order.
  final Map<String, int> _tally = <String, int>{};

  /// Newest first.
  final List<_LogLine> _log = <_LogLine>[];

  @override
  void initState() {
    super.initState();
    _clock.start();
  }

  @override
  void dispose() {
    _burstTimer?.cancel();
    super.dispose();
  }

  int get _now => _clock.elapsedMilliseconds;

  String get _mode => kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';

  void _add(int t, String what, {bool alert = false}) {
    final int? r = _recreatedAtMs;
    final String since = r != null && t - r <= _recreateWindowMs
        ? '  R+${t - r}'
        : '';
    _log.insert(
      0,
      _LogLine('+${'$t'.padLeft(6)} ms  $what$since', alert: alert),
    );
    if (_log.length > _maxLog) _log.removeLast();
  }

  void _onDown(PointerDownEvent e) {
    final int t = _now;
    final bool overlap = _activePointers.isNotEmpty;
    _activePointers.add(e.pointer);
    final int? prev = _lastDownMs;
    setState(() {
      _downs++;
      _burstDowns++;
      if (overlap) _burstOverlap = true;
      _lastDownMs = t;
      _add(
        t,
        'down  x ${e.localPosition.dx.round()}'
        '${prev == null ? '' : '  (gap ${t - prev} ms)'}'
        '${overlap ? '  OVERLAP' : ''}',
      );
    });
    _armBurst();
  }

  void _onUp(PointerUpEvent e) {
    _activePointers.remove(e.pointer);
    setState(() {
      _ups++;
      _add(_now, 'up');
    });
    _armBurst();
  }

  void _onCancel(PointerCancelEvent e) {
    _activePointers.remove(e.pointer);
    setState(() {
      _cancels++;
      _burstCancels++;
      _add(_now, 'CANCEL', alert: true);
    });
    _armBurst();
  }

  void _onTap(int i) {
    final int t = _now;
    final int? prev = _lastTapMs;
    setState(() {
      _tabIndex = i;
      _taps++;
      _burstTaps++;
      _lastTapMs = t;
      _add(
        t,
        'onTap $i ${_labels[i]}'
        '${prev == null ? '' : '  (gap ${t - prev} ms)'}',
      );
    });
    _armBurst();
  }

  void _armBurst() {
    _burstTimer?.cancel();
    _burstTimer = Timer(_quiet, _closeBurst);
  }

  void _closeBurst() {
    if (!mounted) return;
    if (_burstDowns == 0 && _burstTaps == 0) return;
    final String key = '$_burstDowns/$_burstTaps';
    final bool lost = _burstDowns != _burstTaps || _burstCancels > 0;
    setState(() {
      _tally[key] = (_tally[key] ?? 0) + 1;
      _add(_now, '── burst $key  ${_meaning()}', alert: lost);
      _burstDowns = 0;
      _burstTaps = 0;
      _burstCancels = 0;
      _burstOverlap = false;
    });
  }

  /// What the current burst's numbers mean, per the class doc.
  String _meaning() {
    if (_burstCancels > 0) return 'engine cancelled a touch';
    if (_burstDowns == _burstTaps) {
      return _burstDowns == 1
          ? 'one touch seen (a fast pair? then the 2nd never reached Flutter)'
          : 'ok';
    }
    if (_burstDowns > _burstTaps) {
      return _burstOverlap
          ? 'fingers overlapped, redo with one finger'
          : 'Flutter got it, native bar did not select';
    }
    return 'more onTaps than downs';
  }

  void _reset() {
    _burstTimer?.cancel();
    setState(() {
      _downs = 0;
      _ups = 0;
      _cancels = 0;
      _taps = 0;
      _lastDownMs = null;
      _lastTapMs = null;
      _activePointers.clear();
      _burstDowns = 0;
      _burstTaps = 0;
      _burstCancels = 0;
      _burstOverlap = false;
      _recreatedAtMs = null;
      _tally.clear();
      _log.clear();
    });
  }

  void _switchBar(_Bar bar) {
    if (bar == _bar) return;
    _reset();
    setState(() => _bar = bar);
  }

  void _recreate() {
    final int t = _now;
    setState(() {
      _mount++;
      _recreatedAtMs = t;
      _add(t, 'recreate → mount #$_mount');
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Issue #68 · rapid tab taps'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _controls(),
                  Expanded(child: _logPanel()),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: _tabBar()),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    final Widget bar = switch (_bar) {
      _Bar.native => CNTabBar(
        key: ValueKey<int>(_mount),
        items: _items,
        currentIndex: _tabIndex,
        onTap: _onTap,
        tint: CupertinoColors.systemBlue,
      ),
      _Bar.flutter => CupertinoTabBar(
        items: _flutterItems,
        currentIndex: _tabIndex,
        onTap: _onTap,
        activeColor: CupertinoColors.systemBlue,
      ),
    };
    // A Listener only observes pointers; it never joins the gesture arena,
    // so it cannot decide who gets the touch.
    return Listener(
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: bar,
    );
  }

  Widget _logPanel() {
    final String tally = _tally.isEmpty
        ? 'none yet'
        : _tally.entries.map((e) => '${e.key} ×${e.value}').join('   ');
    final Color text = CupertinoColors.label.resolveFrom(context);
    final Color red = CupertinoColors.systemRed.resolveFrom(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'bursts (downs/onTaps)   $tally',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: text,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _log.isEmpty
                ? Center(
                    child: Text(
                      'Tap two different tabs fast ↓',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _log.length,
                    itemBuilder: (BuildContext context, int i) {
                      final _LogLine line = _log[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          line.text,
                          style: TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: line.alert
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: line.alert ? red : text,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    final String backend = PlatformVersion.shouldUseNativeGlass
        ? 'native'
        : 'fallback';
    final bool native = _bar == _Bar.native;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Tap two different tabs fast, pause 1 s, repeat ×20; each pause '
            'tallies a burst as downs/onTaps. 2/2 no drop · 2/1 Flutter got '
            'the touch, the native bar did not select (UIKit / delaying '
            'recognizer; with R+ the refresh window) · 1/1 after two taps '
            'the 2nd touch never reached Flutter (engine). CupertinoTabBar '
            'pairs and slow taps (1/1 each) must stay clean.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Recreate bar probes the plugin's own drop window: press it, then "
            'tap one other tab at once — 1/0 near R+100…400 ms is the '
            'refresh cycle. Test in debug, then profile or release.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoSegmentedControl<_Bar>(
              groupValue: _bar,
              onValueChanged: _switchBar,
              children: const <_Bar, Widget>{
                _Bar.native: Text('CNTabBar', style: TextStyle(fontSize: 12)),
                _Bar.flutter: Text(
                  'CupertinoTabBar',
                  style: TextStyle(fontSize: 12),
                ),
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _button('Reset', _reset),
              const SizedBox(width: 8),
              _button('Recreate bar', native ? _recreate : null),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'down $_downs · up $_ups · cancel $_cancels · onTap $_taps · '
            '${native ? 'CNTabBar mount #$_mount' : 'CupertinoTabBar'} · '
            '$_mode · $backend',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.white,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback? onPressed) {
    return Expanded(
      child: CupertinoButton.filled(
        padding: const EdgeInsets.symmetric(vertical: 10),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
