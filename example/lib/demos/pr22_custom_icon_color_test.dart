import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// PR #22 Test Page - Custom button icon color for CNPopupMenuButton
class PR22CustomIconColorTestPage extends StatelessWidget {
  const PR22CustomIconColorTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      CNPopupMenuItem(label: 'Option A', icon: CNSymbol('1.circle')),
      CNPopupMenuItem(label: 'Option B', icon: CNSymbol('2.circle')),
      CNPopupMenuItem(label: 'Option C', icon: CNSymbol('3.circle')),
    ];

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #22 Test'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              'Test 1: customButtonIconColor with IconData',
              'Custom icon (CupertinoIcons) should be RED',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonCustomIcon: CupertinoIcons.ellipsis_circle_fill,
                    customButtonIconColor: CupertinoColors.systemRed,
                    items: items,
                    onSelected: (i) => debugPrint('Red icon: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Red custom icon'),
                ],
              ),
            ),
            _section(
              'Test 2: customButtonIconColor GREEN',
              'Same custom icon but GREEN',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonCustomIcon: CupertinoIcons.gear_alt_fill,
                    customButtonIconColor: CupertinoColors.systemGreen,
                    items: items,
                    onSelected: (i) => debugPrint('Green icon: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Green custom icon'),
                ],
              ),
            ),
            _section(
              'Test 3: customButtonIconColor BLUE',
              'Custom icon with BLUE color',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonCustomIcon: CupertinoIcons.person_fill,
                    customButtonIconColor: CupertinoColors.systemBlue,
                    items: items,
                    onSelected: (i) => debugPrint('Blue icon: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Blue custom icon'),
                ],
              ),
            ),
            _section(
              'Test 4: No customButtonIconColor (default)',
              'Custom icon with NO color set — should use default behavior',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonCustomIcon: CupertinoIcons.star_fill,
                    items: items,
                    onSelected: (i) => debugPrint('Default icon: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Default color (no customButtonIconColor)'),
                ],
              ),
            ),
            _section(
              'Test 5: SF Symbol icon (should be unaffected)',
              'Using buttonIcon (CNSymbol) — customButtonIconColor should NOT apply',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonIcon: CNSymbol('ellipsis.circle.fill'),
                    items: items,
                    onSelected: (i) => debugPrint('SF Symbol: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('SF Symbol (unaffected)'),
                ],
              ),
            ),
            _section(
              'Test 6: SF Symbol with its own color',
              'Using buttonIcon with color — should still work as before',
              Row(
                children: [
                  CNPopupMenuButton.icon(
                    buttonIcon: CNSymbol(
                      'ellipsis.circle.fill',
                      color: CupertinoColors.systemPurple,
                    ),
                    items: items,
                    onSelected: (i) => debugPrint('Purple SF: $i'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Purple SF Symbol (own color)'),
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
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
