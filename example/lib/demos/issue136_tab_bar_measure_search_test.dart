import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #136 reproduction: `CNTabBar` doesn't measure itself again when
/// `height` changes, and the bar with a `searchItem` ignores images,
/// badges, names and the search icon, and can't select its search tab from
/// code.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/136
/// Reported by @cogwheel0.
///
/// ### The claims
///
/// 1. A bar created with `height: 60` that later gets `height: null` stays
///    at the 50 pt fallback: it never measured itself.
/// 2. With a `searchItem`, items with `imageAsset` show no icon, `badge` is
///    ignored, the search tab shows the system magnifying glass instead of
///    `CNTabBarSearchItem.icon`, and `activateSearch()` leaves the previous
///    tab selected.
///
/// ### How this screen proves it
///
///  * **Measure** (top bar, split view): *compact* starts on, giving
///    `height: 60`. Turn it off. The line under the switch shows the bar's
///    laid-out height. **Bug:** 50.0. **Fixed:** the bar's own height
///    (about 62 on iOS 27).
///  * **Search bar** (bottom): Clock (PNG, badge "3"), Done (PNG, a dot),
///    Coins (SF Symbol) and the search tab drawn with
///    `text.magnifyingglass`. **Bug:** the PNG tabs are empty, no badges, the
///    plain magnifying glass. **Fixed:** all drawn.
///  * **activateSearch()**: **bug:** Clock stays selected. **Fixed:** the
///    search tab is selected, and *deactivateSearch()* puts Clock back.
class Issue136TabBarMeasureSearchTestPage extends StatefulWidget {
  const Issue136TabBarMeasureSearchTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Turns compact off and activates search, printing `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue136TabBarMeasureSearchTestPage> createState() =>
      _Issue136TabBarMeasureSearchTestPageState();
}

class _Issue136TabBarMeasureSearchTestPageState
    extends State<Issue136TabBarMeasureSearchTestPage> {
  final GlobalKey _measureKey = GlobalKey();
  final CNTabBarSearchController _search = CNTabBarSearchController();
  bool _compact = true;
  int _topTab = 0;
  int _tab = 0;
  bool _searchActive = false;
  bool _customSearchIcon = const bool.fromEnvironment(
    'SEARCH_ICON',
    defaultValue: true,
  );
  double? _height;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    if (widget.autoCycle) _run();
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    final h = box?.hasSize == true ? box!.size.height : null;
    if (h != _height) setState(() => _height = h);
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    debugPrint('CNB_SHOT 136-start h=$_height');
    if (!mounted) return;
    setState(() => _compact = false);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 136-measured h=$_height');
    _search.activateSearch();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 136-search');
    _search.deactivateSearch();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 136-back');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#136: Measure, search bar'),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('compact (height: 60)')),
                    CupertinoSwitch(
                      value: _compact,
                      onChanged: (v) => setState(() => _compact = v),
                    ),
                  ],
                ),
                Text(
                  'bar height: ${_height?.toStringAsFixed(1) ?? '—'}  '
                  '(bug: 50.0 after compact off)',
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  key: _measureKey,
                  child: CNTabBar(
                    height: _compact ? 60 : null,
                    items: const [
                      CNTabBarItem(label: 'Inbox', icon: CNSymbol('tray')),
                      CNTabBarItem(
                        label: 'Archive',
                        icon: CNSymbol('archivebox'),
                      ),
                    ],
                    currentIndex: _topTab,
                    onTap: (i) => setState(() => _topTab = i),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    CupertinoButton(
                      onPressed: _search.activateSearch,
                      child: const Text('activateSearch()'),
                    ),
                    CupertinoButton(
                      onPressed: _search.deactivateSearch,
                      child: const Text('deactivate'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text('search icon: text.magnifyingglass'),
                    ),
                    CupertinoSwitch(
                      value: _customSearchIcon,
                      onChanged: (v) => setState(() => _customSearchIcon = v),
                    ),
                  ],
                ),
                Text(
                  'tab: $_tab  search active: $_searchActive',
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bottom bar: Clock with badge 3, Done with a dot, Coins, and '
                  'the search tab as text.magnifyingglass. activateSearch() '
                  'selects the search tab.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CNTabBar(
              // The search icon is set when the bar is created.
              key: ValueKey(_customSearchIcon),
              items: const [
                CNTabBarItem(
                  label: 'Clock',
                  imageAsset: CNImageAsset('assets/icons/clock.png', size: 24),
                  badge: '3',
                  semanticLabel: 'Clock',
                ),
                CNTabBarItem(
                  label: 'Done',
                  imageAsset: CNImageAsset(
                    'assets/icons/checkcircle.png',
                    size: 24,
                  ),
                  badge: CNTabBarItem.dotBadge,
                ),
                CNTabBarItem(
                  label: 'Coins',
                  icon: CNSymbol('dollarsign.circle'),
                ),
              ],
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              searchItem: CNTabBarSearchItem(
                icon: _customSearchIcon
                    ? const CNSymbol('text.magnifyingglass')
                    : null,
                onSearchActiveChanged: (a) => setState(() => _searchActive = a),
              ),
              searchController: _search,
            ),
          ),
        ],
      ),
    );
  }
}
