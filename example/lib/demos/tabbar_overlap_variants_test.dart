import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Isolates the iOS 26.2 label-over-icon overlap seen with the #60 reporter's
/// bar: four bars that differ in one property each.
class TabBarOverlapVariantsTestPage extends StatelessWidget {
  const TabBarOverlapVariantsTestPage({super.key});

  static const _a = <CNTabBarItem>[
    CNTabBarItem(label: 'Habits', icon: CNSymbol('house.fill')),
    CNTabBarItem(label: 'Calendar', icon: CNSymbol('calendar')),
    CNTabBarItem(label: 'Stats', icon: CNSymbol('chart.bar.fill')),
    CNTabBarItem(label: 'Settings', icon: CNSymbol('gearshape.fill')),
  ];

  @override
  Widget build(BuildContext context) {
    Widget row(String name, Widget bar) =>
        Column(children: [Text(name), bar, const SizedBox(height: 12)]);
    return CupertinoPageScaffold(
      child: SafeArea(
        child: ListView(
          children: [
            row('plain', CNTabBar(items: _a, currentIndex: 0, onTap: (_) {})),
            row(
              'height 85',
              CNTabBar(items: _a, currentIndex: 0, height: 85, onTap: (_) {}),
            ),
            row(
              'tint',
              CNTabBar(
                items: _a,
                currentIndex: 0,
                tint: CupertinoColors.systemGreen,
                onTap: (_) {},
              ),
            ),
            row(
              'height 85 + tint',
              CNTabBar(
                items: _a,
                currentIndex: 0,
                height: 85,
                tint: CupertinoColors.systemGreen,
                onTap: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
