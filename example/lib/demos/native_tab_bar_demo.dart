import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Test harness for [CNTabBarNative] — exercises every feature:
/// native-list tabs, a working (filtering) search tab, the bottom accessory,
/// all four minimize behaviors, tint color, dark mode, and every callback
/// (logged below; the log is visible after you close the tab bar).
class NativeTabBarDemoPage extends StatefulWidget {
  const NativeTabBarDemoPage({super.key});

  @override
  State<NativeTabBarDemoPage> createState() => _NativeTabBarDemoPageState();
}

class _NativeTabBarDemoPageState extends State<NativeTabBarDemoPage> {
  CNTabMinimizeBehavior _behavior = CNTabMinimizeBehavior.onScrollDown;
  bool _dark = false;
  bool _showAccessory = true;
  bool _asRoot = false;
  bool _launched = false;
  int _flutterTaps = 0;
  Color _tint = CupertinoColors.systemBlue;
  final List<String> _log = [];

  static const _tints = <MapEntry<String, Color>>[
    MapEntry('Blue', CupertinoColors.systemBlue),
    MapEntry('Pink', CupertinoColors.systemPink),
    MapEntry('Green', CupertinoColors.systemGreen),
  ];

  void _addLog(String s) {
    setState(() {
      _log.insert(0, s);
      if (_log.length > 40) _log.removeLast();
    });
  }

  // Mutable so we can demonstrate the live mutation API (setItems).
  final List<CNListItem> _feed = [
    for (var i = 1; i <= 50; i++)
      CNListItem(
        title: 'Post #$i',
        subtitle: 'Liquid Glass demo row $i',
        leadingSymbol: CNSymbol('photo'),
        showChevron: true,
      ),
  ];
  int _feedBadge = 0;
  int _added = 0;

  List<CNListItem> get _profileItems => const [
    CNListItem(
      title: 'Account',
      subtitle: 'Name, email, password',
      leadingSymbol: CNSymbol('person.crop.circle'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Notifications',
      subtitle: 'Sounds, badges',
      leadingSymbol: CNSymbol('bell'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Privacy',
      subtitle: 'Permissions',
      leadingSymbol: CNSymbol('lock'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Appearance',
      subtitle: 'Theme, text size',
      leadingSymbol: CNSymbol('paintbrush'),
      showChevron: true,
    ),
    CNListItem(
      title: 'About',
      subtitle: 'Version 1.0',
      leadingSymbol: CNSymbol('info.circle'),
      showChevron: true,
    ),
  ];

  List<CNListItem> get _searchItems => const [
    CNListItem(
      title: 'Dashboard',
      subtitle: 'View your stats',
      leadingSymbol: CNSymbol('chart.pie'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Settings',
      subtitle: 'Manage preferences',
      leadingSymbol: CNSymbol('gear'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Profile',
      subtitle: 'Edit your account',
      leadingSymbol: CNSymbol('person.circle'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Notifications',
      subtitle: '3 unread',
      leadingSymbol: CNSymbol('bell'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Help Center',
      subtitle: 'Get support',
      leadingSymbol: CNSymbol('questionmark.circle'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Privacy',
      subtitle: 'View policy',
      leadingSymbol: CNSymbol('lock.shield'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Downloads',
      subtitle: '8 items',
      leadingSymbol: CNSymbol('arrow.down.circle'),
      showChevron: true,
    ),
    CNListItem(
      title: 'Favorites',
      subtitle: '15 items',
      leadingSymbol: CNSymbol('heart'),
      showChevron: true,
    ),
  ];

  Future<void> _launch() async {
    await CNTabBarNative.enable(
      tabs: [
        CNTab(
          title: 'Feed',
          sfSymbol: CNSymbol('list.bullet'),
          nativeList: CNNativeList(items: _feed),
        ),
        CNTab(
          title: 'Profile',
          sfSymbol: CNSymbol('person'),
          badgeCount: 3,
          nativeList: CNNativeList(items: _profileItems),
        ),
        // No nativeList → hosts real Flutter content (root mode only).
        CNTab(title: 'Flutter', sfSymbol: CNSymbol('f.circle')),
        CNTab(
          title: 'Search',
          isSearchTab: true,
          nativeList: CNNativeList(items: _searchItems),
        ),
      ],
      minimizeBehavior: _behavior,
      bottomAccessory: _showAccessory
          ? CNTabAccessory(
              text: 'This is bottom accessory',
              sfSymbol: CNSymbol('music.note'),
            )
          : null,
      tintColor: _tint,
      isDark: _dark,
      asRoot: _asRoot,
      onDismissed: () => setState(() => _launched = false),
      onTabSelected: (i) {
        _addLog('onTabSelected($i)');
        // Demo: hide the accessory on the Flutter tab (index 2), show elsewhere.
        if (_showAccessory) {
          CNTabBarNative.setBottomAccessory(
            i == 2
                ? null
                : CNTabAccessory(
                    text: 'This is bottom accessory',
                    sfSymbol: CNSymbol('music.note'),
                  ),
          );
        }
      },
      onListItemTap: (t, i) => _addLog('onListItemTap(tab: $t, item: $i)'),
      onSearchChanged: (q) => _addLog('onSearchChanged("$q")'),
      // Demonstrates the live mutation API: tapping the accessory adds a Feed
      // row and bumps the Feed badge while the bar stays presented.
      onAccessoryTap: () {
        _added++;
        _feedBadge++;
        _feed.insert(
          0,
          CNListItem(
            title: 'NEW Post ($_added)',
            subtitle: 'Added live via setItems()',
            leadingSymbol: CNSymbol('sparkles'),
            showChevron: true,
          ),
        );
        CNTabBarNative.setItems(tabIndex: 0, items: _feed);
        CNTabBarNative.setBadgeCounts([_feedBadge, 3, null, null]);
        _addLog('onAccessoryTap → setItems + Feed badge=$_feedBadge');
      },
    );
    if (mounted) setState(() => _launched = true);
  }

  @override
  Widget build(BuildContext context) {
    // Once launched in root mode, the Flutter root is embedded into the
    // "Flutter" tab — so render that tab's content here.
    if (_launched) return _flutterTabContent(context);
    return _configScreen(context);
  }

  // Real, interactive Flutter content shown inside the "Flutter" tab.
  Widget _flutterTabContent(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.flame_fill,
                size: 56,
                color: CupertinoColors.systemOrange,
              ),
              const SizedBox(height: 12),
              const Text(
                'Real Flutter content in a native tab',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tapped $_flutterTaps times',
                style: const TextStyle(color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () => setState(() => _flutterTaps++),
                child: const Text('Tap me (Flutter)'),
              ),
              const SizedBox(height: 24),
              const Text(
                'This is a Flutter widget, live inside the native tab bar.\n'
                'Switch tabs to see native lists + minimize; come back here\n'
                'for Flutter. Tap ✕ on a list tab to exit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _configScreen(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Minimize + Accessory'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Configure, then Launch. Scroll the Feed DOWN to collapse the bar '
              '(accessory slides inline); tap the Search circle and type to '
              'filter; tap any row to push a detail; tap ✕ to return.\n\n'
              'Tap the bottom-accessory pill to LIVE-ADD a Feed row + badge '
              '(exercises the mutation API: setItems + setBadgeCounts). '
              'Callbacks are logged below (visible after you close).',
            ),
            const SizedBox(height: 20),

            _label('Minimize behavior'),
            CupertinoSlidingSegmentedControl<CNTabMinimizeBehavior>(
              groupValue: _behavior,
              onValueChanged: (v) => setState(() => _behavior = v!),
              children: const {
                CNTabMinimizeBehavior.automatic: Text('auto'),
                CNTabMinimizeBehavior.never: Text('never'),
                CNTabMinimizeBehavior.onScrollDown: Text('down'),
                CNTabMinimizeBehavior.onScrollUp: Text('up'),
              },
            ),
            const SizedBox(height: 16),

            _label('Tint'),
            CupertinoSlidingSegmentedControl<Color>(
              groupValue: _tint,
              onValueChanged: (v) => setState(() => _tint = v!),
              children: {
                for (final t in _tints)
                  t.value: Text(t.key, style: TextStyle(color: t.value)),
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Expanded(child: Text('Dark mode')),
                CupertinoSwitch(
                  value: _dark,
                  onChanged: (v) => setState(() => _dark = v),
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('Bottom accessory')),
                CupertinoSwitch(
                  value: _showAccessory,
                  onChanged: (v) => setState(() => _showAccessory = v),
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('Present as app root (vs modal)')),
                CupertinoSwitch(
                  value: _asRoot,
                  onChanged: (v) => setState(() => _asRoot = v),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _launch,
                child: const Text('Launch tab bar'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                onPressed: () => CNTabBarNative.disable(),
                child: const Text('Dismiss (programmatic)'),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _label('Event log')),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(_log.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (_log.isEmpty)
              const Text(
                '— no events yet —',
                style: TextStyle(color: CupertinoColors.systemGrey),
              ),
            for (final entry in _log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  entry,
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}
