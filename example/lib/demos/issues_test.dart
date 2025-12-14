import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Issues Test Page - Testing CNTabBar with search
class IssuesTestPage extends StatefulWidget {
  const IssuesTestPage({super.key});

  @override
  State<IssuesTestPage> createState() => _IssuesTestPageState();
}

class _IssuesTestPageState extends State<IssuesTestPage> {
  int _tabIndex = 0;
  bool _switchValue = false;
  final TextEditingController _textController = TextEditingController();
  final CNTabBarSearchController _searchController = CNTabBarSearchController();

  // Search state
  String _searchQuery = '';
  bool _isSearchActive = false;

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Issues Test')),
      child: Stack(
        children: [
          // Main content
          Positioned.fill(
            child: _isSearchActive
                ? _buildSearchResults()
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            'Issue #3: Popup menu order',
                            'Test popup that opens upward',
                            _buildIssue3Test(),
                          ),
                          _buildSection(
                            'Issue #4: CNSwitch + keyboard',
                            'Type in field to show keyboard',
                            _buildIssue4Test(),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          // Native tab bar with search
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            child: CNTabBar(
              items: [
                CNTabBarItem(label: 'Início', icon: CNSymbol('house.fill')),
                CNTabBarItem(
                  label: 'Lançamentos',
                  icon: CNSymbol('play.rectangle.fill'),
                ),
                CNTabBarItem(label: 'Resumo', icon: CNSymbol('chart.bar.fill')),
              ],
              currentIndex: _tabIndex,
              onTap: (index) => setState(() => _tabIndex = index),
              searchItem: CNTabBarSearchItem(
                label: 'Buscar',
                placeholder: 'Search...',
                automaticallyActivatesSearch: false,
                onSearchChanged: (query) {
                  setState(() => _searchQuery = query);
                },
                onSearchActiveChanged: (active) {
                  setState(() => _isSearchActive = active);
                },
              ),
              searchController: _searchController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return SafeArea(
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _searchQuery.isEmpty
                    ? 'Start typing to search...'
                    : 'Results for "$_searchQuery"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: _searchQuery.isEmpty
                  ? Center(
                      child: Icon(
                        CupertinoIcons.search,
                        size: 64,
                        color: CupertinoColors.inactiveGray,
                      ),
                    )
                  : ListView.builder(
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return CupertinoListTile(
                          title: Text(
                            'Result ${index + 1} for "$_searchQuery"',
                          ),
                          leading: const Icon(CupertinoIcons.doc),
                          trailing: const Icon(CupertinoIcons.chevron_forward),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, Widget child) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildIssue3Test() {
    final items = [
      CNPopupMenuItem(label: '1. First Item', icon: CNSymbol('1.circle')),
      CNPopupMenuItem(label: '2. Second Item', icon: CNSymbol('2.circle')),
      CNPopupMenuItem(label: '3. Third Item', icon: CNSymbol('3.circle')),
      CNPopupMenuItem(label: '4. Fourth Item', icon: CNSymbol('4.circle')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CNPopupMenuButton.icon(
              buttonIcon: CNSymbol('ellipsis.circle.fill'),
              items: items,
              onSelected: (index) {
                debugPrint('Native behavior - Selected item $index');
              },
            ),
            const SizedBox(width: 8),
            const Text('Native (reversed when upward)'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CNPopupMenuButton.icon(
              buttonIcon: CNSymbol('ellipsis.circle.fill'),
              items: items,
              preserveTopToBottomOrder: true,
              onSelected: (index) {
                debugPrint('Preserved order - Selected item $index');
              },
            ),
            const SizedBox(width: 8),
            const Text('preserveTopToBottomOrder: true'),
          ],
        ),
      ],
    );
  }

  Widget _buildIssue4Test() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('CNSwitch: '),
            CNSwitch(
              value: _switchValue,
              onChanged: (v) => setState(() => _switchValue = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CupertinoTextField(
          controller: _textController,
          placeholder: 'Type here to show keyboard',
        ),
      ],
    );
  }
}
