import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #74 verification — the native `CNTabBar` has no Liquid Glass material
/// on iOS 26.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/74
/// Reported by @eugene-dp.
///
/// ### The claim
///
/// `makeAppearance()` in `CupertinoTabBarPlatformView.swift` configures the
/// bar's `UITabBarAppearance` with `configureWithTransparentBackground()` on
/// every iOS version. On iOS 26 that is not "glass without a tint" — it is no
/// background material at all, so whatever is behind the bar renders through
/// it at full sharpness. The only glassy thing left is the selection pill,
/// which iOS draws itself. The PR switches iOS 26+ to
/// `configureWithDefaultBackground()`.
///
/// ### How this screen proves it
///
/// The page puts two things over the **same backdrop**:
///
///  * a **reference** — a `LiquidGlassContainer` capsule (SwiftUI
///    `.glassEffect(.regular)`), roughly the size of the floating tab bar,
///    which is known-good Liquid Glass (see the PR #69 page: `.regular`
///    frosts fine detail);
///  * the **`CNTabBar`** itself, pinned to the bottom.
///
/// The default `stripes` backdrop is fine vertical stripes that never vary
/// along y, so the reference and the bar sit over pixel-identical content no
/// matter where each lands. `text` is the reporter's real-world case: body
/// copy scrolling under the bar.
///
///  * **Bug present:** the stripes (or the text) behind the tab bar are as
///    crisp as the uncovered backdrop around it — the bar does not frost them
///    — while the same stripes under the reference capsule are smeared. Only
///    the selection pill around the selected tab looks like glass.
///  * **Bug fixed:** a glass capsule (platter) behind the tab items frosts
///    the stripes, with a rim. It may frost less than the reference; the test
///    is frosted vs crisp, not identical. The area outside that capsule stays
///    crisp — a standalone `UITabBar` never gets the soft blur band a
///    `UITabBarController` installs, because that band is a scroll-view edge
///    effect. A full-width frosted band would mean the legacy material, not
///    Liquid Glass.
///
/// Judge the **settled** bar, not the first frame: before the platform view
/// exists `CNTabBar` draws a Flutter fallback. The readout's last field says
/// whether the page is on the `native` path at all; the Flutter fallback
/// (iOS < 26) has nothing to do with this PR, so a `fallback` readout proves
/// nothing.
///
/// `split` builds two bars through a separate path in the same Swift file,
/// sharing `makeAppearance()` — expect two platters after the fix. `search`
/// is a **control the PR does not touch**: `CNTabBar(searchItem:)` is a
/// different platform view (`CupertinoTabBarSearchPlatformView`) that sets a
/// clear background directly and never calls `makeAppearance()`, so it
/// should look the same before and after.
///
/// This PR edits the same `makeAppearance()` as the Issue #70 fix
/// (`backgroundColor` lost after mount). Whatever lands must be re-checked on
/// both this page and `Testing → #70: CNTabBar backgroundColor`; this page
/// always creates the bar **without** a `backgroundColor`.
class Pr74TabBarGlassBackgroundTestPage extends StatefulWidget {
  const Pr74TabBarGlassBackgroundTestPage({super.key});

  @override
  State<Pr74TabBarGlassBackgroundTestPage> createState() =>
      _Pr74TabBarGlassBackgroundTestPageState();
}

class _Pr74TabBarGlassBackgroundTestPageState
    extends State<Pr74TabBarGlassBackgroundTestPage> {
  static const List<String> _layouts = <String>['single', 'split', 'search'];

  /// Fixed geometry so the reference capsule lands at the same place in
  /// every screenshot, just above the bar.
  static const double _referenceHeight = 62;
  static const double _referenceInset = 16;
  static const double _referenceGapAboveBar = 110;

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

  String _layout = 'single';
  bool _stripes = true;
  bool _dark = false;
  int _tabIndex = 0;

  /// Part of the bar's key; bumped on layout change and *Remount*, so the
  /// creation-params path is what gets exercised every time.
  int _epoch = 1;

  Color get _ink => _dark ? const Color(0xFFF2F2F7) : const Color(0xFF101014);
  Color get _paper => _dark ? const Color(0xFF101014) : const Color(0xFFF2F2F7);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _paper,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #74 · tab bar glass'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: _backdrop()),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Align(alignment: Alignment.topCenter, child: _controls()),
            ),
          ),
          Positioned(
            left: _referenceInset,
            right: _referenceInset,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: _referenceGapAboveBar),
                child: _reference(),
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

  Widget _backdrop() {
    if (_stripes) {
      return CustomPaint(
        painter: _StripePainter(ink: _ink, paper: _paper),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 220, 16, 160),
      itemCount: 60,
      itemBuilder: (BuildContext context, int i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          '${i + 1}. The quick brown fox jumps over the lazy dog. Pack my '
          'box with five dozen liquor jugs. Sphinx of black quartz, judge '
          'my vow.',
          style: TextStyle(fontSize: 15, height: 1.3, color: _ink),
        ),
      ),
    );
  }

  Widget _reference() {
    return SizedBox(
      height: _referenceHeight,
      child: LiquidGlassContainer(
        config: const LiquidGlassConfig(
          effect: CNGlassEffect.regular,
          shape: CNGlassEffectShape.capsule,
        ),
        child: Center(
          child: Text(
            'reference · LiquidGlassContainer .regular',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBar() {
    return CNTabBar(
      key: ValueKey<String>('$_layout#$_epoch'),
      items: _items,
      currentIndex: _tabIndex,
      onTap: (int i) => setState(() => _tabIndex = i),
      tint: CupertinoColors.systemBlue,
      split: _layout == 'split',
      searchItem: _layout == 'search'
          ? const CNTabBarSearchItem(placeholder: 'Search')
          : null,
    );
  }

  Widget _controls() {
    final String backend = PlatformVersion.shouldUseNativeGlass
        ? 'native'
        : 'fallback';
    final int? ios = PlatformVersion.iosVersion;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Bug: the stripes behind the tab bar (outside the selected '
            'pill) are as crisp as the bare backdrop, while under the '
            'reference capsule they are smeared. Fixed: a glass capsule '
            'behind the tabs frosts them. search = untouched control.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoSegmentedControl<String>(
              groupValue: _layout,
              onValueChanged: (String v) => setState(() {
                _layout = v;
                _epoch++;
              }),
              children: <String, Widget>{
                for (final String l in _layouts)
                  l: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(l, style: const TextStyle(fontSize: 12)),
                  ),
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: CupertinoSegmentedControl<bool>(
                  groupValue: _stripes,
                  onValueChanged: (bool v) => setState(() => _stripes = v),
                  children: const <bool, Widget>{
                    true: Text('stripes', style: TextStyle(fontSize: 12)),
                    false: Text('text', style: TextStyle(fontSize: 12)),
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoSegmentedControl<bool>(
                  groupValue: _dark,
                  onValueChanged: (bool v) => setState(() => _dark = v),
                  children: const <bool, Widget>{
                    false: Text('light', style: TextStyle(fontSize: 12)),
                    true: Text('dark', style: TextStyle(fontSize: 12)),
                  },
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                onPressed: () => setState(() => _epoch++),
                child: const Text('Remount', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$_layout · ${_stripes ? 'stripes' : 'text'} · '
            '${_dark ? 'dark' : 'light'} · mount #$_epoch · '
            'iOS ${ios ?? '?'} · $backend',
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
}

/// Fine vertical stripes, constant along y, so the reference capsule and the
/// tab bar sit over pixel-identical content wherever each lands. `.regular`
/// glass smears a 4 pt period into flat grey; a bar with no material leaves
/// it crisp.
class _StripePainter extends CustomPainter {
  const _StripePainter({required this.ink, required this.paper});

  final Color ink;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    const double period = 8;
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final Paint stripe = Paint()..color = ink;
    for (double x = 0; x < size.width; x += period) {
      canvas.drawRect(Rect.fromLTWH(x, 0, period / 2, size.height), stripe);
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.paper != paper;
}
