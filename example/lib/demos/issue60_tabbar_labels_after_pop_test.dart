import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

/// Issue #60 reproduction — `CNTabBar` labels go missing after a sheet on a
/// pushed page, until a tab is tapped.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/60
/// Reported by @ashellz; also hit by @iamfiro and @bernd70.
///
/// ### The claim
///
/// The reporter's home page has a `CNTabBar` with four labelled SF-symbol
/// items, `height: 85` and a tint. `Navigator.push` to a second page, open a
/// `showModalBottomSheet` there, close it, pop back: the home bar shows its
/// icons without labels until a tab is tapped. A sheet opened on the home
/// page does not do it, and staying on page 2 for 15 s without a sheet does
/// not either. @bernd70 sees it only when the system Text Size is above
/// 100 % and shared commit c3d0b3e, which adds a `layoutSubviews` hook that
/// cycles the selection again once the container first gets a non-zero
/// width. (That commit's message says "!= 100 %", so a smaller size may
/// matter too.)
///
/// Mechanism (matches the code, not yet confirmed on device):
/// `ModalBottomSheetRoute` matches `CNTabBarRouteObserver`'s narrow `Sheet`
/// rule, and `modalDepth` is global, so the sheet on page 2 also makes the
/// covered home bar destroy its native view (`autoHideOnModal`). When the
/// sheet closes, the depth drops and the bar is recreated at once, while the
/// home page is still offstage under page 2. The new `UITabBar` exists but
/// has only been laid out at width 0. The `setSelectedIndex` + `refresh`
/// calls that `_onCreated` schedules at +50 ms and +200 ms run against that
/// zero-width bar, and nothing lays the labels out again when the real width
/// arrives after the pop. With a sheet on the home page, the bar is recreated
/// on stage at full width before the refreshes run. `height: 85` also skips
/// `getIntrinsicSize`, so the Flutter box is full width either way and the
/// gap is on the native side.
///
/// ### How this screen proves it
///
/// This page plays the reporter's home page: the same four items, symbols,
/// `height: 85`, a tint and the same `onTap` guard, with the bar at the
/// bottom. Like the reporter's app, the example app registers
/// `CNTabBarRouteObserver` on the root navigator. Dart cannot read the
/// native labels, so you judge by eye. The strip above the bar names the
/// four labels that must be there.
///
///  * *Push → sheet → pop* is the reporter's flow, by hand. Page 2 has
///    *Open sheet* (a raw `showModalBottomSheet`, the API from the report)
///    and *Pop back*. *Auto* runs the same flow hands-off so you can repeat
///    it: push, wait until the push settles plus 400 ms, open the sheet,
///    close it after 800 ms, wait 600 ms, pop. Both refreshes run inside
///    that 600 ms, while the home page is still covered.
///  * Control A, *Sheet here*: the same sheet on this page, closed after
///    800 ms.
///  * Control B, *Push, wait, pop*: page 2 for 2 s with no sheet.
///
/// Judge the bar after each flow has finished and the pop has settled:
///
///  * **Bug present:** after *Push → sheet → pop* (or *Auto*), one or more of
///    the four labels are missing (icons only) until a tab is tapped. The
///    selected tab may keep a cut-off label while the others have none.
///    Both controls leave all four labels visible.
///  * **Bug fixed:** all four labels are visible after every flow, at both
///    text sizes.
///
/// Run every flow twice: once at the default Text Size and once at a larger
/// one (Settings → Display & Brightness → Text Size, or Settings →
/// Accessibility → Display & Text Size → Larger Text). A larger size is
/// reportedly required, so a clean run at the default size proves nothing on
/// its own. The readout shows the scale Flutter sees (`text 1.00× (default)`).
/// If labels go missing, tap a tab to bring them back before the next run.
/// Only the native iOS 26 bar is in scope, so the readout's last field must
/// say `native`.
///
/// Open PR #87 changes the same native `refresh` handler: `refreshInFlight`
/// drops a refresh that arrives while one is still running, and
/// `desiredIndex` chooses the item that is restored afterwards. Re-check
/// this screen once #87 is applied, whichever of the two lands first.
class Issue60TabBarLabelsAfterPopTestPage extends StatefulWidget {
  const Issue60TabBarLabelsAfterPopTestPage({super.key});

  @override
  State<Issue60TabBarLabelsAfterPopTestPage> createState() =>
      _Issue60TabBarLabelsAfterPopTestPageState();
}

enum _Flow { manual, auto, controlA, controlB }

class _Issue60TabBarLabelsAfterPopTestPageState
    extends State<Issue60TabBarLabelsAfterPopTestPage> {
  /// The reporter's bar height.
  static const double _barHeight = 85;

  /// The reporter passes the app's primary colour; any non-default tint
  /// stands in for it.
  static const Color _tint = CupertinoColors.systemGreen;

  /// Auto timings. [_afterSheet] covers the sheet's exit animation and both
  /// `_onCreated` refreshes (+50 ms, +200 ms), so they run before the pop,
  /// while the home page is still covered.
  static const Duration _beforeSheet = Duration(milliseconds: 400);
  static const Duration _sheetUp = Duration(milliseconds: 800);
  static const Duration _afterSheet = Duration(milliseconds: 600);
  static const Duration _noSheetWait = Duration(seconds: 2);

  static const List<String> _labels = <String>[
    'Habits',
    'Calendar',
    'Stats',
    'Settings',
  ];

  /// The reporter's items, verbatim: `icon` only, no `activeIcon`.
  static const List<CNTabBarItem> _items = <CNTabBarItem>[
    CNTabBarItem(label: 'Habits', icon: CNSymbol('house.fill')),
    CNTabBarItem(label: 'Calendar', icon: CNSymbol('calendar')),
    CNTabBarItem(label: 'Stats', icon: CNSymbol('chart.bar.fill')),
    CNTabBarItem(label: 'Settings', icon: CNSymbol('gearshape.fill')),
  ];

  int _tabIndex = 0;

  int _runs = 0;
  _Flow? _flow;
  String _phase = 'idle';
  bool _busy = false;

  /// Sheets opened on page 2 during the current manual run. Zero means the
  /// run was really control B.
  int _page2Sheets = 0;

  /// Context of the sheet currently up, so a timed run can close it.
  BuildContext? _sheetContext;

  static String _flowName(_Flow flow) => switch (flow) {
    _Flow.manual => 'push → sheet → pop (by hand)',
    _Flow.auto => 'push → sheet → pop (auto)',
    _Flow.controlA => 'A · sheet here',
    _Flow.controlB => 'B · push, wait, pop',
  };

  static String _scaleName(double scale) {
    if ((scale - 1).abs() < 0.005) return 'default';
    return scale > 1 ? 'larger' : 'smaller';
  }

  void _begin(_Flow flow, String phase) {
    setState(() {
      _busy = true;
      _flow = flow;
      _runs++;
      _phase = phase;
    });
  }

  void _setPhase(String phase) {
    if (mounted) setState(() => _phase = phase);
  }

  void _finish(String phase) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _phase = phase;
    });
  }

  /// Completes once [route]'s push transition has stopped running.
  static Future<void> _settled(TransitionRoute<void> route) {
    final Animation<double>? animation = route.animation;
    if (animation == null || animation.isCompleted) {
      return Future<void>.value();
    }
    final Completer<void> done = Completer<void>();
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.forward) return;
      animation.removeStatusListener(listener);
      if (!done.isCompleted) done.complete();
    }

    animation.addStatusListener(listener);
    return done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  }

  CupertinoPageRoute<void> _page2Route({
    required String note,
    ValueChanged<BuildContext>? onOpenSheet,
  }) {
    return CupertinoPageRoute<void>(
      builder: (BuildContext ctx) =>
          _SecondPage(note: note, onOpenSheet: onOpenSheet),
    );
  }

  /// The reporter's sheet call: a raw `showModalBottomSheet`, not
  /// `CNBottomSheet`.
  Future<void> _openSheet(
    BuildContext ctx, {
    required bool onPage2,
    required bool timed,
  }) {
    return showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      builder: (BuildContext sheetCtx) {
        _sheetContext = sheetCtx;
        return _SheetBody(onPage2: onPage2, timed: timed);
      },
    );
  }

  void _closeSheet() {
    final BuildContext? sheet = _sheetContext;
    _sheetContext = null;
    if (sheet == null || !sheet.mounted) return;
    if (ModalRoute.of(sheet)?.isCurrent ?? false) Navigator.of(sheet).pop();
  }

  // ── flows ────────────────────────────────────────────────────────────────

  Future<void> _runManual() async {
    _page2Sheets = 0;
    _begin(_Flow.manual, 'on page 2');
    await Navigator.of(context).push(
      _page2Route(
        note:
            'The reporter\'s flow, by hand. Tap Open sheet (a raw '
            'showModalBottomSheet). Close it with Close, by dragging it down '
            'or by tapping outside. Then tap Pop back or use the back button, '
            'and look at the labels on the home tab bar.',
        onOpenSheet: (BuildContext page2) {
          _page2Sheets++;
          _openSheet(page2, onPage2: true, timed: false);
        },
      ),
    );
    if (!mounted) return;
    _finish(
      _page2Sheets == 0
          ? 'no sheet opened, so that was control B, not the bug flow'
          : 'sheet ×$_page2Sheets on page 2 · look at the labels',
    );
  }

  Future<void> _runAuto() async {
    _begin(_Flow.auto, 'pushing page 2');
    final CupertinoPageRoute<void> route = _page2Route(
      note:
          'Automated run, hands off. The sheet opens once this page has '
          'settled plus 400 ms, closes after 800 ms, and this page pops '
          '600 ms later.',
    );
    final Future<void> popped = Navigator.of(context).push(route);
    await _settled(route);
    await Future<void>.delayed(_beforeSheet);
    if (!mounted) return;
    final BuildContext? page2 = route.subtreeContext;
    if (page2 == null || !page2.mounted || !route.isCurrent) {
      _finish('interrupted, run again');
      return;
    }
    _setPhase('sheet up on page 2');
    final Future<void> closed = _openSheet(page2, onPage2: true, timed: true);
    await Future<void>.delayed(_sheetUp);
    _closeSheet();
    await closed;
    _setPhase('sheet closed · bar recreated under page 2');
    await Future<void>.delayed(_afterSheet);
    if (!mounted) return;
    if (!route.isCurrent) {
      _finish('interrupted, run again');
      return;
    }
    _setPhase('popping');
    route.navigator!.pop();
    await popped;
    _finish('done · look at the labels');
  }

  Future<void> _runControlA() async {
    _begin(_Flow.controlA, 'sheet up on this page');
    final Future<void> closed = _openSheet(
      context,
      onPage2: false,
      timed: true,
    );
    await Future<void>.delayed(_sheetUp);
    _closeSheet();
    await closed;
    _setPhase('sheet closed');
    await Future<void>.delayed(_afterSheet);
    _finish('done · look at the labels');
  }

  Future<void> _runControlB() async {
    _begin(_Flow.controlB, 'pushing page 2');
    final CupertinoPageRoute<void> route = _page2Route(
      note:
          'Control B, hands off. There is no sheet: this page pops by itself '
          'after 2 s.',
    );
    final Future<void> popped = Navigator.of(context).push(route);
    await _settled(route);
    _setPhase('on page 2, no sheet');
    await Future<void>.delayed(_noSheetWait);
    if (!mounted) return;
    if (!route.isCurrent) {
      _finish('interrupted, run again');
      return;
    }
    _setPhase('popping');
    route.navigator!.pop();
    await popped;
    _finish('done · look at the labels');
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Read before the clamp below: this is the scale the system reports.
    final double textScale = MediaQuery.textScalerOf(context).scale(100) / 100;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#60 · labels after pop'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              // The test needs a larger Text Size, so keep this page's own
              // Flutter text usable at it. The native bar ignores this clamp.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(child: _controls(textScale)),
                    ),
                    _reference(),
                    SizedBox(height: _barHeight + bottomInset + 12),
                  ],
                ),
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

  /// The reporter's bar config (`tint`, `height: 85`, four items, the
  /// `onTap` guard). Not keyed: the native view is only recreated by the
  /// modal hide path, which is the path this issue is about.
  Widget _tabBar() {
    return CNTabBar(
      tint: _tint,
      height: _barHeight,
      items: _items,
      currentIndex: _tabIndex,
      onTap: (int i) {
        if (_tabIndex != i) setState(() => _tabIndex = i);
      },
    );
  }

  /// The four labels that must be visible in the bar below.
  Widget _reference() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'all four labels must show in the bar  ↓',
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (final String label in _labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls(double textScale) {
    final String backend = PlatformVersion.shouldUseNativeGlass
        ? 'native'
        : 'fallback';
    final _Flow? flow = _flow;
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
            'Bug: after Push → sheet → pop (or Auto), one or more of the 4 '
            'labels are missing (icons only) until a tab is tapped, while A '
            'and B keep all 4. Fixed: all 4 labels after every flow, at both '
            'text sizes. Tap a tab to restore labels between runs.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _button('Push → sheet → pop', _runManual),
              const SizedBox(width: 8),
              _button('Auto', _runAuto),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _button('A · Sheet here', _runControlA),
              const SizedBox(width: 8),
              _button('B · Push, wait, pop', _runControlB),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Run every flow at the default Text Size AND at a larger one: '
            'Settings → Display & Brightness → Text Size, or Accessibility → '
            'Display & Text Size → Larger Text. Reportedly it only breaks '
            'when the text is larger.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemYellow,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'run #$_runs · ${flow == null ? 'no flow yet' : _flowName(flow)} '
            '· $_phase · text ${textScale.toStringAsFixed(2)}× '
            '(${_scaleName(textScale)}) · $backend',
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

  Widget _button(String label, VoidCallback onPressed) {
    return Expanded(
      child: CupertinoButton.filled(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        onPressed: _busy ? null : onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

/// Page 2 of the reporter's flow. With [onOpenSheet] null it offers no
/// buttons, so a timed run cannot be disturbed.
class _SecondPage extends StatelessWidget {
  const _SecondPage({required this.note, this.onOpenSheet});

  final String note;
  final ValueChanged<BuildContext>? onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<BuildContext>? open = onOpenSheet;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('#60 · page 2')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              note,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            if (open != null) ...<Widget>[
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () => open(context),
                child: const Text('Open sheet'),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Pop back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Content of the raw Material sheet.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.onPage2, required this.timed});

  final bool onPage2;
  final bool timed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            const Text(
              'Raw showModalBottomSheet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                onPage2
                    ? 'Opened on page 2. While it is up, the home tab bar is '
                          'destroyed. It is recreated the moment this sheet '
                          'closes, while the home page is still covered by '
                          'page 2.'
                    : 'Control A: opened on the home page. The bar is '
                          'destroyed while this is up and recreated on '
                          'screen when it closes.',
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            if (timed)
              const Text('Closes by itself…')
            else
              CupertinoButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
