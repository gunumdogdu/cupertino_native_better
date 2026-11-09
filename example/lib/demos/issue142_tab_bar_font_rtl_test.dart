import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #142: the iOS 26 `CNTabBar` can't find a font from `pubspec.yaml`,
/// has one weight for every tab, and doesn't take right-to-left from
/// Flutter.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/142
/// Reported by @Ashhad08.
///
/// ### The claims
///
/// 1. `labelFontFamily: 'Tajawal'` (declared under `fonts:` in the example's
///    `pubspec.yaml`) fell back to the system font: UIKit doesn't know a
///    Flutter font asset.
/// 2. No different weight for the selected tab.
/// 3. With the app in Arabic (`Directionality` right to left) the native bar
///    stayed left to right, while the Flutter fallback bar is right to left.
///
/// ### How this screen proves it
///
/// The bar at the bottom uses Tajawal, Medium for the tabs and Bold for the
/// selected one. The switches put the page in Arabic (right to left) and
/// switch the font off for comparison.
///
///  * **Font:** **bug:** the labels are in San Francisco. **Fixed:** they are
///    in Tajawal (compare with the font switch off), the selected one bold.
///  * **Arabic:** **bug:** the first tab, الرئيسية, stays on the left.
///    **Fixed:** it moves to the right, with its badge, and the bar reads
///    right to left like the Flutter text above it.
class Issue142TabBarFontRtlTestPage extends StatefulWidget {
  const Issue142TabBarFontRtlTestPage({super.key, this.arabic = false});

  /// Starts in Arabic (right to left), for the probe entry.
  final bool arabic;

  @override
  State<Issue142TabBarFontRtlTestPage> createState() =>
      _Issue142TabBarFontRtlTestPageState();
}

class _Issue142TabBarFontRtlTestPageState
    extends State<Issue142TabBarFontRtlTestPage> {
  late bool _arabic = widget.arabic;
  bool _font = true;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final labels = _arabic
        ? const ['الرئيسية', 'البحث', 'الإعدادات']
        : const ['Home', 'Search', 'Settings'];
    return Directionality(
      textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
      child: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('#142: Tab bar font, RTL'),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Arabic (right to left)')),
                      CupertinoSwitch(
                        value: _arabic,
                        onChanged: (v) => setState(() => _arabic = v),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Expanded(child: Text("labelFontFamily: 'Tajawal'")),
                      CupertinoSwitch(
                        value: _font,
                        onChanged: (v) => setState(() => _font = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    labels.join(' · '),
                    style: TextStyle(
                      fontFamily: _font ? 'Tajawal' : null,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The bar below should use the font of the line above, the '
                    'selected tab bold, and in Arabic put its first tab on the '
                    'right.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CNTabBar(
                labelFontFamily: _font ? 'Tajawal' : null,
                labelFontSize: 12,
                labelFontWeight: FontWeight.w500,
                selectedLabelFontWeight: FontWeight.w700,
                items: [
                  CNTabBarItem(
                    label: labels[0],
                    icon: const CNSymbol('house'),
                    badge: '2',
                  ),
                  CNTabBarItem(
                    label: labels[1],
                    icon: const CNSymbol('magnifyingglass'),
                  ),
                  CNTabBarItem(
                    label: labels[2],
                    icon: const CNSymbol('gearshape'),
                  ),
                ],
                currentIndex: _tab,
                onTap: (i) => setState(() => _tab = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
