import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #42 reproduction (before applying the fix).
///
/// Bug being tested: `CNTabBar.iconSize` is silently ignored for tabs
/// that use `customIcon` (any `IconData` like `CupertinoIcons.house` or
/// `Icons.home`). It works for SF Symbols (`icon: CNSymbol(...)`) and
/// for `imageAsset`, but custom icons render at a hard-coded 25 pt
/// regardless of what `iconSize` says.
///
/// What to look for: drag the slider. The top tab bar (SF Symbols)
/// scales smoothly with the slider. The bottom tab bar (custom icons
/// from CupertinoIcons) stays the same size — that's the bug.
///
/// After PR #42's fix is merged, the bottom bar will start scaling too.
class Pr42TabBarIconSizeCustomIconTest extends StatefulWidget {
  const Pr42TabBarIconSizeCustomIconTest({super.key});

  @override
  State<Pr42TabBarIconSizeCustomIconTest> createState() =>
      _Pr42TabBarIconSizeCustomIconTestState();
}

class _Pr42TabBarIconSizeCustomIconTestState
    extends State<Pr42TabBarIconSizeCustomIconTest> {
  double _iconSize = 40;
  int _sfIndex = 0;
  int _customIndex = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('#42')),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CNTabBar.iconSize — SF Symbols vs customIcon',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Drag the slider. The SF Symbol row scales. The customIcon row '
                "stays stuck at ~25pt regardless — that's PR #42's bug.",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('iconSize:'),
                  Expanded(
                    child: CupertinoSlider(
                      min: 12,
                      max: 64,
                      divisions: 52,
                      value: _iconSize,
                      onChanged: (v) => setState(() => _iconSize = v),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${_iconSize.toStringAsFixed(0)}pt',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text(
                'Row A — SF Symbols (CNSymbol). EXPECTED to scale.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              CNTabBar(
                iconSize: _iconSize,
                items: const [
                  CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
                  CNTabBarItem(
                    label: 'Search',
                    icon: CNSymbol('magnifyingglass'),
                  ),
                  CNTabBarItem(label: 'Profile', icon: CNSymbol('person.fill')),
                ],
                currentIndex: _sfIndex,
                onTap: (i) => setState(() => _sfIndex = i),
              ),

              const SizedBox(height: 12),

              const Text(
                'Row B — customIcon (CupertinoIcons). BUG: stays ~25pt.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              CNTabBar(
                iconSize: _iconSize,
                items: const [
                  CNTabBarItem(label: 'Home', customIcon: CupertinoIcons.home),
                  CNTabBarItem(
                    label: 'Search',
                    customIcon: CupertinoIcons.search,
                  ),
                  CNTabBarItem(
                    label: 'Profile',
                    customIcon: CupertinoIcons.person_fill,
                  ),
                ],
                currentIndex: _customIndex,
                onTap: (i) => setState(() => _customIndex = i),
              ),

              const SizedBox(height: 12),

              const Text(
                'Row C — imageAsset (SVG). Mirrors issue #39 reporter\'s '
                'exact config: iconSize on bar + size on CNImageAsset + tint.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              CNTabBar(
                iconSize: _iconSize,
                tint: CupertinoColors.systemGreen,
                items: [
                  CNTabBarItem(
                    label: 'Trang chủ',
                    imageAsset: CNImageAsset(
                      'assets/icons/home-03.svg',
                      size: _iconSize,
                    ),
                    activeImageAsset: CNImageAsset(
                      'assets/icons/home-03.svg',
                      size: _iconSize,
                    ),
                  ),
                  CNTabBarItem(
                    label: 'Camera',
                    imageAsset: CNImageAsset(
                      'assets/icons/camera-01.svg',
                      size: _iconSize,
                    ),
                    activeImageAsset: CNImageAsset(
                      'assets/icons/camera-01.svg',
                      size: _iconSize,
                    ),
                  ),
                  CNTabBarItem(
                    label: 'Chromecast',
                    imageAsset: CNImageAsset(
                      'assets/icons/chromecast.svg',
                      size: _iconSize,
                    ),
                    activeImageAsset: CNImageAsset(
                      'assets/icons/chromecast.svg',
                      size: _iconSize,
                    ),
                  ),
                  CNTabBarItem(
                    label: 'Card',
                    imageAsset: CNImageAsset(
                      'assets/icons/card-add.svg',
                      size: _iconSize,
                    ),
                    activeImageAsset: CNImageAsset(
                      'assets/icons/card-add.svg',
                      size: _iconSize,
                    ),
                  ),
                ],
                currentIndex: _customIndex,
                onTap: (i) => setState(() => _customIndex = i),
              ),

              const SizedBox(height: 24),
              const Text(
                'After PR #42 merges, Row B should scale identically to Row A. '
                'Row C demonstrates a separate reported issue: SVG imageAssets '
                'cause label/icon overlap and inconsistent spacing on iOS 26 '
                "(see attached screenshot in user's bug report).",
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
