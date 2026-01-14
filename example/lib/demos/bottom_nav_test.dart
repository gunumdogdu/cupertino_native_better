import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Bottom Navigation Test Page
/// Simple example showing CNTabBar with screen switching
class BottomNavTestPage extends StatefulWidget {
  const BottomNavTestPage({super.key});

  @override
  State<BottomNavTestPage> createState() => _BottomNavTestPageState();
}

class _BottomNavTestPageState extends State<BottomNavTestPage> {
  int _currentIndex = 0;
  int _tapCount = 0;
  int _reselectCount = 0;
  final List<String> _tapLog = [];
  double _iconSize = 25.0; // Default tab bar icon size

  void _onTabTap(int index) {
    final isReselect = index == _currentIndex;

    // Log the tap
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    setState(() {
      _tapCount++;
      if (isReselect) _reselectCount++;
      _tapLog.insert(0, '[$timestamp] Tab $index ${isReselect ? "(RESELECT)" : ""}');
      if (_tapLog.length > 15) _tapLog.removeLast();
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Bottom Nav Test'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: Column(
        children: [
          // Main content - just switch between widgets
          Expanded(
            child: _buildCurrentScreen(),
          ),
          // CNTabBar at bottom
          SafeArea(
            top: false,
            child: CNTabBar(
              iconSize: _iconSize,  // Global icon size for all tabs
              items: [
                CNTabBarItem(
                  label: 'Home',
                  icon: CNSymbol('house'),
                  activeIcon: CNSymbol('house.fill'),
                ),
                CNTabBarItem(
                  label: 'Browse',
                  icon: CNSymbol('square.grid.2x2'),
                  activeIcon: CNSymbol('square.grid.2x2.fill'),
                ),
                CNTabBarItem(
                  label: 'Library',
                  icon: CNSymbol('books.vertical'),
                  activeIcon: CNSymbol('books.vertical.fill'),
                ),
                CNTabBarItem(
                  label: 'Profile',
                  icon: CNSymbol('person'),
                  activeIcon: CNSymbol('person.fill'),
                ),
              ],
              currentIndex: _currentIndex,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }

  /// Simple switch - no IndexedStack needed for basic navigation
  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _HomeScreen(
          tapCount: _tapCount,
          reselectCount: _reselectCount,
          tapLog: _tapLog,
          iconSize: _iconSize,
          onIconSizeChanged: (size) => setState(() => _iconSize = size),
          onReset: () => setState(() {
            _tapCount = 0;
            _reselectCount = 0;
            _tapLog.clear();
          }),
        );
      case 1:
        return const _BrowseScreen();
      case 2:
        return const _LibraryScreen();
      case 3:
        return const _ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

// =============================================================================
// SCREEN WIDGETS
// =============================================================================

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.tapCount,
    required this.reselectCount,
    required this.tapLog,
    required this.iconSize,
    required this.onIconSizeChanged,
    required this.onReset,
  });

  final int tapCount;
  final int reselectCount;
  final List<String> tapLog;
  final double iconSize;
  final ValueChanged<double> onIconSizeChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Icon Size Control
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Icon Size Control',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      onPressed: iconSize > 15 ? () => onIconSizeChanged(iconSize - 2) : null,
                      child: const Text('-', style: TextStyle(fontSize: 20)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            '${iconSize.toInt()}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const Text('pt', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                        ],
                      ),
                    ),
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      onPressed: iconSize < 40 ? () => onIconSizeChanged(iconSize + 2) : null,
                      child: const Text('+', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use CNTabBar(iconSize: X) to set icon size',
                  style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Issue #13 test card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Issue #13: Reselect Test',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap HOME tab multiple times. Each tap should be logged, including reselects.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('$tapCount', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: CupertinoColors.systemBlue)),
                    const Text('Total Taps', style: TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Text('$reselectCount', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: CupertinoColors.systemOrange)),
                    const Text('Reselects', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tap log
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tap Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (tapLog.isEmpty)
                  const Text('Tap tabs to see log...', style: TextStyle(color: CupertinoColors.systemGrey))
                else
                  ...tapLog.map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Menlo',
                        color: log.contains('RESELECT') ? CupertinoColors.systemOrange : null,
                      ),
                    ),
                  )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CupertinoButton.filled(
            onPressed: onReset,
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _BrowseScreen extends StatelessWidget {
  const _BrowseScreen();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Issue #9: Height Clipping Test', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Scroll to bottom. Item 20 should be fully visible above tab bar.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 20 items to test scrolling
          for (int i = 1; i <= 20; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text('$i', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      i == 20 ? 'LAST ITEM - Should be visible!' : 'Item $i',
                      style: TextStyle(
                        fontWeight: i == 20 ? FontWeight.bold : FontWeight.normal,
                        color: i == 20 ? CupertinoColors.systemRed : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LibraryScreen extends StatelessWidget {
  const _LibraryScreen();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.book_fill, size: 64, color: CupertinoColors.systemGreen),
            const SizedBox(height: 16),
            const Text('Library', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Screen switches work!', style: TextStyle(color: CupertinoColors.systemGrey)),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_fill, size: 64, color: CupertinoColors.systemPurple),
            const SizedBox(height: 16),
            const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Screen switches work!', style: TextStyle(color: CupertinoColors.systemGrey)),
          ],
        ),
      ),
    );
  }
}
