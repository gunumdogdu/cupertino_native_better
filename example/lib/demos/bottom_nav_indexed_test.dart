import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Bottom Navigation Test with IndexedStack
/// This version preserves state when switching tabs
class BottomNavIndexedTestPage extends StatefulWidget {
  const BottomNavIndexedTestPage({super.key});

  @override
  State<BottomNavIndexedTestPage> createState() => _BottomNavIndexedTestPageState();
}

class _BottomNavIndexedTestPageState extends State<BottomNavIndexedTestPage> {
  int _currentIndex = 0;
  int _tapCount = 0;
  int _reselectCount = 0;
  final List<String> _tapLog = [];

  void _onTabTap(int index) {
    final isReselect = index == _currentIndex;
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
        middle: const Text('IndexedStack Test'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: Column(
        children: [
          // IndexedStack keeps all screens alive
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _HomeScreen(
                  tapCount: _tapCount,
                  reselectCount: _reselectCount,
                  tapLog: _tapLog,
                  onReset: () => setState(() {
                    _tapCount = 0;
                    _reselectCount = 0;
                    _tapLog.clear();
                  }),
                ),
                const _CounterScreen(title: 'Browse', color: CupertinoColors.systemOrange),
                const _CounterScreen(title: 'Library', color: CupertinoColors.systemGreen),
                const _CounterScreen(title: 'Profile', color: CupertinoColors.systemPurple),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: CNTabBar(
              items: [
                CNTabBarItem(label: 'Home', icon: CNSymbol('house'), activeIcon: CNSymbol('house.fill')),
                CNTabBarItem(label: 'Browse', icon: CNSymbol('square.grid.2x2'), activeIcon: CNSymbol('square.grid.2x2.fill')),
                CNTabBarItem(label: 'Library', icon: CNSymbol('books.vertical'), activeIcon: CNSymbol('books.vertical.fill')),
                CNTabBarItem(label: 'Profile', icon: CNSymbol('person'), activeIcon: CNSymbol('person.fill')),
              ],
              currentIndex: _currentIndex,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.tapCount,
    required this.reselectCount,
    required this.tapLog,
    required this.onReset,
  });

  final int tapCount;
  final int reselectCount;
  final List<String> tapLog;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IndexedStack Version', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('State is PRESERVED when switching tabs. Try incrementing counters on other tabs, then come back.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
          CupertinoButton.filled(onPressed: onReset, child: const Text('Reset')),
        ],
      ),
    );
  }
}

/// Stateful counter screen to demonstrate state preservation
class _CounterScreen extends StatefulWidget {
  const _CounterScreen({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  State<_CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<_CounterScreen> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.number_circle, size: 64, color: widget.color),
            const SizedBox(height: 16),
            Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text(
              '$_counter',
              style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: widget.color),
            ),
            const SizedBox(height: 8),
            const Text('Counter (preserved with IndexedStack)', style: TextStyle(color: CupertinoColors.systemGrey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  onPressed: () => setState(() => _counter--),
                  child: const Text('-'),
                ),
                const SizedBox(width: 16),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  onPressed: () => setState(() => _counter++),
                  child: const Text('+'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Switch to another tab, then come back.\nThe counter value should be preserved!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
