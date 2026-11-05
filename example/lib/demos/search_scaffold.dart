import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Demo for `CNSearchScaffold`: three tabs and a search tab.
///
/// iOS 26+: a native tab bar with the Liquid Glass search tab. macOS: the
/// tabs are a segmented control in the middle of the window toolbar and the
/// search tab is the toolbar's search field. Typing filters the fruit list
/// on the search tab.
class SearchScaffoldDemoPage extends StatefulWidget {
  const SearchScaffoldDemoPage({super.key, this.autoScenario});

  /// `search`: types "an" into the search through its controller once the
  /// page is up, which selects the search tab. `tab1`: opens on the second
  /// tab.
  final String? autoScenario;

  @override
  State<SearchScaffoldDemoPage> createState() => _SearchScaffoldDemoPageState();
}

const List<String> _fruits = <String>[
  'Apple',
  'Apricot',
  'Banana',
  'Blueberry',
  'Cherry',
  'Grape',
  'Mango',
  'Orange',
  'Peach',
  'Pear',
];

class _SearchScaffoldDemoPageState extends State<SearchScaffoldDemoPage> {
  final CNTabBarSearchController _search = CNTabBarSearchController();
  int _index = 0;
  String _query = '';
  bool _active = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoScenario == 'tab1') _index = 1;
    if (widget.autoScenario == 'search') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        setState(() => _index = 3);
        _search.text = 'an';
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _page(String title, String body, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: CupertinoColors.systemGrey),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ),
  );

  Widget _results() {
    final matches = _fruits
        .where((f) => f.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _query.isEmpty
              ? 'Type to search${_active ? ' (searching)' : ''}'
              : '${matches.length} results for "$_query"',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 8),
        for (final fruit in matches)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(fruit, style: const TextStyle(fontSize: 17)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Search Scaffold'),
      ),
      child: SafeArea(
        bottom: false,
        child: CNSearchScaffold(
          items: const [
            CNSearchScaffoldItem(
              label: 'Home',
              icon: CNSymbol('house'),
              activeIcon: CNSymbol('house.fill'),
            ),
            CNSearchScaffoldItem(
              label: 'Library',
              icon: CNSymbol('books.vertical'),
            ),
            CNSearchScaffoldItem(
              label: 'Settings',
              icon: CNSymbol('gearshape'),
            ),
            CNSearchScaffoldItem(
              label: 'Search',
              icon: CNSymbol('magnifyingglass'),
              isSearchTab: true,
            ),
          ],
          currentIndex: _index,
          onTap: (i) {
            debugPrint('CNB_RESULT tab $i');
            setState(() => _index = i);
          },
          searchPlaceholder: 'Search fruit',
          searchController: _search,
          onSearchChanged: (text) {
            debugPrint('CNB_RESULT search "$text"');
            setState(() => _query = text);
          },
          onSearchSubmit: (text) => debugPrint('CNB_RESULT submit "$text"'),
          onSearchActiveChanged: (active) {
            debugPrint('CNB_RESULT search active $active');
            setState(() => _active = active);
          },
          children: [
            _page('Home', 'The first tab', CupertinoIcons.house),
            _page('Library', 'The second tab', CupertinoIcons.book),
            _page('Settings', 'The third tab', CupertinoIcons.settings),
            _results(),
          ],
        ),
      ),
    );
  }
}
