import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// PR #24 Test Page - buttonCustomIconColor + menu item iconColor
class PR24PopupIconColorTestPage extends StatelessWidget {
  const PR24PopupIconColorTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #24 Test'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              'Test 1: buttonCustomIconColor (Blue)',
              'Custom icon button should be BLUE',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonCustomIcon: CupertinoIcons.ellipsis_circle,
                    buttonCustomIconColor: CupertinoColors.systemBlue,
                    items: [
                      CNPopupMenuItem(label: 'Edit', icon: CNSymbol('pencil')),
                      CNPopupMenuItem(label: 'Delete', icon: CNSymbol('trash')),
                    ],
                    onSelected: (i) => debugPrint('Test1: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Blue custom icon button'),
                ],
              ),
            ),
            _section(
              'Test 2: buttonCustomIconColor (Red)',
              'Custom icon button should be RED',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonCustomIcon: CupertinoIcons.gear_alt_fill,
                    buttonCustomIconColor: CupertinoColors.systemRed,
                    items: [
                      CNPopupMenuItem(label: 'Settings', icon: CNSymbol('gear')),
                      CNPopupMenuItem(label: 'About', icon: CNSymbol('info.circle')),
                    ],
                    onSelected: (i) => debugPrint('Test2: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Red custom icon button'),
                ],
              ),
            ),
            _section(
              'Test 3: Menu items with iconColor',
              'Open the popup — menu item icons should have different colors',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonIcon: CNSymbol('ellipsis.circle.fill'),
                    items: [
                      CNPopupMenuItem(
                        label: 'Green Edit',
                        customIcon: CupertinoIcons.pencil,
                        iconColor: CupertinoColors.systemGreen,
                      ),
                      CNPopupMenuItem(
                        label: 'Orange Star',
                        customIcon: CupertinoIcons.star_fill,
                        iconColor: CupertinoColors.systemOrange,
                      ),
                      CNPopupMenuItem(
                        label: 'Red Delete',
                        customIcon: CupertinoIcons.trash,
                        iconColor: CupertinoColors.systemRed,
                      ),
                    ],
                    onSelected: (i) => debugPrint('Test3: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Colored menu item icons'),
                ],
              ),
            ),
            _section(
              'Test 4: Both button + menu item colors',
              'Purple button icon + colored menu items',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonCustomIcon: CupertinoIcons.plus_circle_fill,
                    buttonCustomIconColor: CupertinoColors.systemPurple,
                    items: [
                      CNPopupMenuItem(
                        label: 'Blue New File',
                        customIcon: CupertinoIcons.doc_fill,
                        iconColor: CupertinoColors.systemBlue,
                      ),
                      CNPopupMenuItem(
                        label: 'Green New Folder',
                        customIcon: CupertinoIcons.folder_fill,
                        iconColor: CupertinoColors.systemGreen,
                      ),
                    ],
                    onSelected: (i) => debugPrint('Test4: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Purple button + colored items'),
                ],
              ),
            ),
            _section(
              'Test 5: No colors (default behavior)',
              'Should look the same as before this PR',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonCustomIcon: CupertinoIcons.heart_fill,
                    items: [
                      CNPopupMenuItem(label: 'Like', icon: CNSymbol('hand.thumbsup')),
                      CNPopupMenuItem(label: 'Share', icon: CNSymbol('square.and.arrow.up')),
                    ],
                    onSelected: (i) => debugPrint('Test5: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Default (no colors set)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String subtitle, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
