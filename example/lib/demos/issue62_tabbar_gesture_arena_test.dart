import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #62 / PR #63 verification — `CNTabBar` taps swallowed by an ancestor
/// gesture recognizer.
///
/// Reporter: https://github.com/gunumdogdu/cupertino_native_better/issues/62
/// PR:       https://github.com/gunumdogdu/cupertino_native_better/pull/63
///
/// The reporter's minimal repro is `GestureDetector(onLongPress: () {}, child:
/// CNTabBar(...))` — any ancestor with an *active* recognizer suffices to make
/// the tab bar silently ignore taps. In the wild this shows up via the
/// `requests_inspector` package, which wraps the whole app in a long-press
/// GestureDetector to open its debug UI.
///
/// The fix adds `gestureRecognizers: {Factory<TapGestureRecognizer>(...)}`
/// to the iOS 26+ `UiKitView` (and the macOS `AppKitView`) inside
/// `_buildNativeTabBarPlatformView`, so the platform view's tap wins the
/// gesture arena against ancestor recognizers of other kinds (LongPress,
/// HorizontalDrag, etc.).
///
/// **Only affects iOS 26+ / macOS (native path).** iOS <26 uses a Flutter
/// `CupertinoTabBar` fallback that was never affected. Verify on iOS 26+.
///
/// ### Scenarios
///
/// 1. **Reporter's minimal repro** — `GestureDetector(onLongPress:)` ancestor.
///    Pre-fix: tapping tabs does nothing. Post-fix: tabs switch AND long-press
///    on the ancestor still fires.
///
/// 2. **PageView ancestor** — `PageView` with a horizontal-drag recognizer,
///    CNTabBar inside a page. Pre-fix: tapping tabs does nothing (drag arena
///    wins). Post-fix: tabs switch, and horizontal swipes still change pages
///    outside the tab bar.
///
/// 3. **Baseline** — plain CNTabBar with no ancestor competition. Should
///    behave exactly like it always did (regression check that the fix
///    doesn't break anything).
class Issue62TabBarGestureArenaTestPage extends StatefulWidget {
  const Issue62TabBarGestureArenaTestPage({super.key});

  @override
  State<Issue62TabBarGestureArenaTestPage> createState() =>
      _Issue62TabBarGestureArenaTestPageState();
}

class _Issue62TabBarGestureArenaTestPageState
    extends State<Issue62TabBarGestureArenaTestPage> {
  int _scenario = 0; // 0 = LongPress, 1 = PageView, 2 = Baseline

  int _tabIndex = 0;
  int _tabTapCount = 0;
  int _ancestorLongPressCount = 0;
  int _pageIndex = 0;
  final _pageController = PageController();

  static const _tabs = [
    ('house.fill', 'Home'),
    ('magnifyingglass', 'Search'),
    ('bell.fill', 'Alerts'),
    ('person.fill', 'Profile'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Issue #62 / PR #63'),
        trailing: CupertinoSegmentedControl<int>(
          groupValue: _scenario,
          children: const {
            0: Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('LongPress')),
            1: Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('PageView')),
            2: Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('Baseline')),
          },
          onValueChanged: (v) => setState(() => _scenario = v),
        ),
      ),
      child: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_scenario) {
      case 0:
        return _longPressAncestorScenario();
      case 1:
        return _pageViewAncestorScenario();
      case 2:
      default:
        return _baselineScenario();
    }
  }

  // ── Scenario 1: reporter's exact minimal repro ──────────────────────────

  Widget _longPressAncestorScenario() {
    return GestureDetector(
      // Reporter's minimal repro: any active ancestor recognizer causes the
      // pre-fix bug. Long-press is what `requests_inspector` uses in the
      // wild — a real-world source of this bug.
      onLongPress: () => setState(() => _ancestorLongPressCount++),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            // NOTE: no ListView / SingleChildScrollView here on purpose.
            // Any Scrollable's VerticalDragGestureRecognizer beats
            // LongPressGestureRecognizer to the arena on any finger jitter,
            // making the ancestor long-press look broken when it isn't.
            // Using a plain Padding+Column keeps the arena clean so
            // ancestor onLongPress fires reliably on the yellow zone.
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _explain(
                    'Scenario 1: ancestor GestureDetector(onLongPress:)',
                    'Reporter\'s minimal repro from Issue #62. With the '
                        'fix, tapping tabs works AND long-pressing on the '
                        'yellow area below fires the ancestor counter.',
                  ),
                  const SizedBox(height: 12),
                  _counterRow('Tab index', _tabIndex.toString()),
                  _counterRow('Tab tap count', _tabTapCount.toString()),
                  _counterRow('Ancestor onLongPress count',
                      _ancestorLongPressCount.toString()),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3B0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: CupertinoColors.systemYellow
                              .resolveFrom(context),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'HOLD HERE FOR ~½ SECOND\nto fire ancestor onLongPress',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF000000),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _tabBar(),
        ],
      ),
    );
  }

  // ── Scenario 2: PageView ancestor (drag-vs-tap competition) ─────────────

  Widget _pageViewAncestorScenario() {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            children: [
              _pageViewPage(0),
              _pageViewPage(1),
              _pageViewPage(2),
            ],
          ),
        ),
        _tabBar(),
      ],
    );
  }

  Widget _pageViewPage(int i) {
    final colors = [
      CupertinoColors.systemBlue,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
    ];
    // NOTE: no ListView here on purpose — same reason as Scenario 1.
    // A Scrollable child inside a PageView page limits the horizontal-drag
    // region PageView actually sees, making page swipes look flaky.
    // Plain filled Container = obvious full-page swipe target.
    return Container(
      color: colors[i].resolveFrom(context).withValues(alpha: 0.18),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Page $i',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: colors[i].resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SWIPE  ⇐   ⇒  ANYWHERE\nto change page',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          _counterRow('Tab index', _tabIndex.toString()),
          _counterRow('Tab tap count', _tabTapCount.toString()),
          _counterRow('Current page', _pageIndex.toString()),
        ],
      ),
    );
  }

  // ── Scenario 3: no ancestor (regression check) ──────────────────────────

  Widget _baselineScenario() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _explain(
                'Scenario 3: baseline (no ancestor competition)',
                'Plain CNTabBar with no gesture-competing ancestor. Sanity '
                    'check that the PR doesn\'t break anything for normal '
                    'usage.',
              ),
              const SizedBox(height: 12),
              _counterRow('Tab index', _tabIndex.toString()),
              _counterRow('Tab tap count', _tabTapCount.toString()),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Expected: exactly what CNTabBar always did. Tap → switch. '
                  'This is the regression check.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        _tabBar(),
      ],
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────

  Widget _tabBar() {
    return CNTabBar(
      currentIndex: _tabIndex,
      onTap: (i) => setState(() {
        _tabIndex = i;
        _tabTapCount++;
      }),
      items: [
        for (final (icon, label) in _tabs)
          CNTabBarItem(icon: CNSymbol(icon), label: label),
      ],
    );
  }

  Widget _explain(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: CupertinoTheme.of(context)
                .textTheme
                .navTitleTextStyle
                .copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text(body,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                )),
      ],
    );
  }

  Widget _counterRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
