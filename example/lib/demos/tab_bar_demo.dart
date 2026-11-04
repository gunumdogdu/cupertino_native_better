import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// CNTabBar: badges, a tint and a font, a search tab, items that change at
/// runtime and items with image assets and custom icons, each on its own bar.
///
/// On iOS 26+ each bar is a `UITabBar`; on macOS an `NSSegmentedControl`
/// used as tabs, with the badge drawn over the tab. The buttons change the
/// bars at runtime (badges, font, items), which reach the native bar through
/// `setBadges`, `setFont` and `setItems`.
///
/// [autoCycle] presses the buttons on a timer, so the page can be checked
/// from screenshots without tapping (`PROBE=tabbar AUTO=true`).
class TabBarDemoPage extends StatefulWidget {
  const TabBarDemoPage({super.key, this.autoCycle = false});

  /// Changes badges, font, items and selection every 1.5 s.
  final bool autoCycle;

  @override
  State<TabBarDemoPage> createState() => _TabBarDemoPageState();
}

class _TabBarDemoPageState extends State<TabBarDemoPage> {
  int _badgeTab = 0;
  int _inbox = 3;
  bool _dot = true;

  int _styledTab = 1;
  bool _largeFont = false;

  int _searchTab = 0;
  bool _searchActive = false;
  final CNTabBarSearchController _search = CNTabBarSearchController();

  int _itemsTab = 0;
  bool _fourItems = false;

  int _imageTab = 0;
  bool _alternateImages = false;

  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        _tick++;
        setState(() {
          _inbox = _inbox >= 12 ? 0 : _inbox + 3;
          _dot = !_dot;
          _badgeTab = (_badgeTab + 1) % 3;
          _largeFont = !_largeFont;
          _styledTab = (_styledTab + 1) % 3;
          _fourItems = !_fourItems;
          _itemsTab = 0;
          _alternateImages = !_alternateImages;
          _imageTab = (_imageTab + 1) % 3;
        });
        if (_tick % 2 == 0) {
          _search.activateSearch();
        } else {
          _search.deactivateSearch();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Widget _section(String title, Widget bar, [Widget? controls]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          bar,
          ?controls,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Tab Bar')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              'Badges: a count and a dot',
              CNTabBar(
                items: [
                  CNTabBarItem(
                    label: 'Inbox',
                    icon: const CNSymbol('tray'),
                    activeIcon: const CNSymbol('tray.fill'),
                    badge: _inbox > 0 ? '$_inbox' : null,
                  ),
                  CNTabBarItem(
                    label: 'Updates',
                    icon: const CNSymbol('bell'),
                    activeIcon: const CNSymbol('bell.fill'),
                    badge: _dot ? CNTabBarItem.dotBadge : null,
                  ),
                  const CNTabBarItem(
                    label: 'Profile',
                    icon: CNSymbol('person'),
                    activeIcon: CNSymbol('person.fill'),
                  ),
                ],
                currentIndex: _badgeTab,
                onTap: (i) => setState(() => _badgeTab = i),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoButton(
                    child: const Text('+3'),
                    onPressed: () => setState(() => _inbox += 3),
                  ),
                  CupertinoButton(
                    child: const Text('Clear'),
                    onPressed: () => setState(() => _inbox = 0),
                  ),
                  CupertinoButton(
                    child: Text(_dot ? 'Hide dot' : 'Show dot'),
                    onPressed: () => setState(() => _dot = !_dot),
                  ),
                ],
              ),
            ),
            _section(
              'Tint and label font',
              CNTabBar(
                items: const [
                  CNTabBarItem(label: 'Today', icon: CNSymbol('sun.max')),
                  CNTabBarItem(
                    label: 'Library',
                    icon: CNSymbol('books.vertical'),
                  ),
                  CNTabBarItem(
                    label: 'Search',
                    icon: CNSymbol('magnifyingglass'),
                  ),
                ],
                currentIndex: _styledTab,
                tint: CupertinoColors.systemPink,
                labelFontSize: _largeFont ? 15 : null,
                onTap: (i) => setState(() => _styledTab = i),
              ),
              CupertinoButton(
                child: Text(_largeFont ? 'System font size' : 'Font size 15'),
                onPressed: () => setState(() => _largeFont = !_largeFont),
              ),
            ),
            _section(
              'Search tab',
              CNTabBar(
                items: const [
                  CNTabBarItem(
                    label: 'Recents',
                    icon: CNSymbol('clock'),
                    activeIcon: CNSymbol('clock.fill'),
                  ),
                  CNTabBarItem(
                    label: 'Browse',
                    icon: CNSymbol('folder'),
                    activeIcon: CNSymbol('folder.fill'),
                  ),
                ],
                currentIndex: _searchTab,
                searchItem: CNTabBarSearchItem(
                  placeholder: 'Search',
                  onSearchActiveChanged: (active) =>
                      setState(() => _searchActive = active),
                ),
                searchController: _search,
                onTap: (i) => setState(() {
                  _searchTab = i;
                  _searchActive = false;
                }),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _searchActive
                      ? 'Search tab selected'
                      : 'Tab $_searchTab selected',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _section(
              'Items that change',
              CNTabBar(
                items: [
                  const CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                  const CNTabBarItem(
                    label: 'Music',
                    icon: CNSymbol('music.note'),
                  ),
                  const CNTabBarItem(
                    label: 'Videos',
                    icon: CNSymbol('play.rectangle'),
                  ),
                  if (_fourItems)
                    const CNTabBarItem(
                      label: 'Podcasts',
                      icon: CNSymbol('mic'),
                    ),
                ],
                currentIndex: _itemsTab,
                onTap: (i) => setState(() => _itemsTab = i),
              ),
              CupertinoButton(
                child: Text(_fourItems ? 'Remove a tab' : 'Add a tab'),
                onPressed: () => setState(() {
                  _fourItems = !_fourItems;
                  _itemsTab = 0;
                }),
              ),
            ),
            _section(
              'Image assets and a custom icon',
              CNTabBar(
                items: [
                  // An SVG asset, with a filled SVG for the selected tab.
                  CNTabBarItem(
                    label: 'Home',
                    imageAsset: CNImageAsset(
                      _alternateImages
                          ? 'assets/icons/profile.svg'
                          : 'assets/icons/home.svg',
                    ),
                    activeImageAsset: CNImageAsset(
                      _alternateImages
                          ? 'assets/icons/profile-filled.svg'
                          : 'assets/icons/home_filled.svg',
                    ),
                  ),
                  // A PNG asset (resolved for the pixel ratio).
                  CNTabBarItem(
                    label: 'Recent',
                    imageAsset: CNImageAsset('assets/icons/clock.png'),
                    activeImageAsset: CNImageAsset(
                      'assets/icons/clock_filled.png',
                    ),
                  ),
                  // A Flutter IconData rendered to an image.
                  const CNTabBarItem(
                    label: 'Chats',
                    customIcon: CupertinoIcons.chat_bubble,
                    activeCustomIcon: CupertinoIcons.chat_bubble_fill,
                  ),
                ],
                currentIndex: _imageTab,
                onTap: (i) => setState(() => _imageTab = i),
              ),
              CupertinoButton(
                child: Text(
                  _alternateImages ? 'Home icon' : 'Profile icon',
                ),
                onPressed: () =>
                    setState(() => _alternateImages = !_alternateImages),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
