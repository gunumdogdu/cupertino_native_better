import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Reproduction for: when CNTabBar has a `searchItem`, the right-side search
/// button (a floating Liquid Glass orb on iOS 26) gets its TOP edge clipped.
/// This is caused by Issue #2's `clipsToBounds = true` on the right tab bar
/// in split mode — the search orb extends slightly above its UITabBar bounds
/// and the clip cuts it off.
///
/// To verify the bug:
///  1. Open this page (it sits a CNTabBar with searchItem at the bottom).
///  2. Look at the magnifying-glass button on the right side of the tab bar.
///  3. Its TOP edge should be visibly cropped — only the bottom curve shows.
///  4. Compare against the left tabs (Library, Albums) which render fully.
class TabBarSplitSearchClipTest extends StatefulWidget {
  const TabBarSplitSearchClipTest({super.key});

  @override
  State<TabBarSplitSearchClipTest> createState() =>
      _TabBarSplitSearchClipTestState();
}

class _TabBarSplitSearchClipTestState extends State<TabBarSplitSearchClipTest> {
  int _currentIndex = 0;
  String _searchText = '';

  void _showCupertinoModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Modal bottom sheet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Watch the TOP edge of this sheet. With the split-search '
                  'tab bar (clipsToBounds = false on iOS 26+), does a '
                  'shadow line bleed across the top?',
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // Bright background so any clipping/halo on the dark CNTabBar at the
      // bottom is obviously visible.
      backgroundColor: CupertinoColors.systemTeal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemTeal,
        middle: const Text('Split-search clip repro'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemYellow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repro: split-search clip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Look at the magnifying-glass button at the bottom-'
                          'right. Its top edge should be visibly cropped by '
                          'the right tab bar\'s clipsToBounds. The left tabs '
                          '(Library, Albums) render fully — only the search '
                          'orb is clipped.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: _showCupertinoModal,
                    child: const Text(
                      'Show modal bottom sheet (Issue #2 shadow check)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current tab: $_currentIndex',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_searchText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Search query: "$_searchText"'),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: CNTabBar(
              items: const [
                CNTabBarItem(
                  label: 'Library',
                  icon: CNSymbol('photo.on.rectangle'),
                  activeIcon: CNSymbol('photo.on.rectangle.fill'),
                ),
                CNTabBarItem(
                  label: 'Albums',
                  icon: CNSymbol('square.stack'),
                  activeIcon: CNSymbol('square.stack.fill'),
                ),
              ],
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              searchItem: CNTabBarSearchItem(
                placeholder: 'Search...',
                onSearchChanged: (q) => setState(() => _searchText = q),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
