import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Issue #33 reproduction: SVG icons not rendering in CNTabBar.
///
/// Reporter's setup (verbatim from the issue):
///   ```dart
///   CNTabBar(
///     currentIndex: currentIndex,
///     onTap: onTap,
///     tint: AppColors.primary,
///     iconSize: 24,
///     items: items.map((item) => CNTabBarItem(
///       label: item.label,
///       imageAsset: CNImageAsset(item.icon),
///       activeImageAsset: CNImageAsset(item.activeIcon ?? item.icon),
///     )).toList(growable: false),
///   );
///   ```
///   with a `NavBarItem` model wrapping `label / icon / activeIcon` paths.
///
/// To verify:
///  1. Open this page from "Testing → #33: SVG in CNTabBar".
///  2. Are the SVG icons visible at the bottom? Or blank slots / empty space?
///  3. Tap each tab — does the icon switch to its `active` variant?
///
/// Note: there's already a similar demo at "Bottom Nav Test (Custom Icons)"
/// using the same `assets/icons/*.svg` files; this one mirrors the reporter's
/// exact `NavBarItem` wrapper pattern so we can compare both renderings.
class Issue33SvgTabBarTest extends StatefulWidget {
  const Issue33SvgTabBarTest({super.key});

  @override
  State<Issue33SvgTabBarTest> createState() => _Issue33SvgTabBarTestState();
}

class _NavBarItem {
  final String label;
  final String icon;
  final String? activeIcon;
  const _NavBarItem({required this.label, required this.icon, this.activeIcon});
}

class _Issue33SvgTabBarTestState extends State<Issue33SvgTabBarTest> {
  int _currentIndex = 0;

  // Mirrors the reporter's `_ctvNavItems` list shape.
  static const List<_NavBarItem> _items = [
    _NavBarItem(
      label: 'Home',
      icon: 'assets/icons/home.svg',
      activeIcon: 'assets/icons/home_filled.svg',
    ),
    _NavBarItem(
      label: 'Search',
      icon: 'assets/icons/search.svg',
      activeIcon: 'assets/icons/search-filled.svg',
    ),
    _NavBarItem(
      label: 'Chat',
      icon: 'assets/icons/chat.svg',
      activeIcon: 'assets/icons/chat-filled.svg',
    ),
    _NavBarItem(
      label: 'Profile',
      icon: 'assets/icons/profile.svg',
      activeIcon: 'assets/icons/profile-filled.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // Bright contrasting background so any clipping / halo around the
      // CNTabBar at the bottom of the screen is obvious against the page.
      backgroundColor: CupertinoColors.systemTeal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemTeal,
        middle: const Text('#33: SVG in CNTabBar'),
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
                          'Repro: Issue #33 — SVG icons in CNTabBar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Mirrors the reporter\'s exact NavBarItem wrapper '
                          'pattern with iconSize: 24 and tint set. SVG icons '
                          'should render in the tab bar at the bottom. If '
                          'you see blank slots, the bug is reproduced.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Selected tab: ${_items[_currentIndex].label}'),
                  const SizedBox(height: 8),
                  Text(
                    'icon path: ${_items[_currentIndex].icon}',
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                  ),
                  Text(
                    'active path: ${_items[_currentIndex].activeIcon}',
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            // Reporter's exact CNTabBar shape — tint + iconSize + the
            // .map(...) over a NavBarItem-style model.
            child: CNTabBar(
              tint: CupertinoColors.systemBlue,
              iconSize: 24,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: _items
                  .map(
                    (item) => CNTabBarItem(
                      label: item.label,
                      imageAsset: CNImageAsset(item.icon),
                      activeImageAsset: CNImageAsset(
                        item.activeIcon ?? item.icon,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}
