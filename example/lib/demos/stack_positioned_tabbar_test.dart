import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Stack + Positioned layout pattern (borrowed from adaptive_platform_ui).
///
/// Hypothesis: putting `CNTabBar` inside a `Stack` with `Positioned(bottom: 0)`
/// — instead of in `Scaffold.bottomNavigationBar` — solves BOTH:
///   1. The iOS 26 Liquid Glass selection pill renders fully (no clip),
///   2. The modal bottom-sheet shadow does NOT bleed over the modal,
///      because the modal is drawn at a higher z-index in the same Stack
///      and naturally covers the tab bar AND its drop shadow.
///
/// Combined with Swift-side `clipsToBounds = false` on iOS 26+, this should
/// give us a clean answer to both Issue #2 and the pill-clip trade-off.
///
/// To verify on a real device:
///  1. Open this page. Bright teal background so any clipping at the top of
///     the bar is obvious.
///  2. Tap each tab — the pill should render fully (no top crop).
///  3. Tap "Show modal bottom sheet" — watch the top edge of the sheet for
///     a shadow line bleeding from the tab bar. There should be none.
class StackPositionedTabBarTest extends StatefulWidget {
  const StackPositionedTabBarTest({super.key});

  @override
  State<StackPositionedTabBarTest> createState() =>
      _StackPositionedTabBarTestState();
}

class _StackPositionedTabBarTestState extends State<StackPositionedTabBarTest> {
  int _currentIndex = 0;

  void _showCupertinoModal() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Modal bottom sheet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Watch the TOP edge of this sheet. With Stack+Positioned '
                  'layout, the tab bar\'s shadow should be naturally covered '
                  'by the modal — no bleed.',
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemTeal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemTeal,
        middle: const Text('Stack + Positioned tab bar'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      // KEY: Stack with Positioned tab bar at bottom, OVER the body content.
      // NOT in `Scaffold.bottomNavigationBar`. This is what adaptive_platform_ui
      // does, and what makes the modal-shadow leak go away naturally.
      child: Stack(
        children: [
          // Body content — full screen, extends behind the tab bar.
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stack + Positioned tab bar pattern',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'CNTabBar is inside a Stack with Positioned(bottom: 0). '
                        'Test both:\n\n'
                        '1. Tap each tab — pill should render fully (no top crop).\n\n'
                        '2. Tap "Show modal" — top edge of sheet should NOT '
                        'show a shadow line bleeding from the tab bar.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  onPressed: _showCupertinoModal,
                  child: const Text('Show modal bottom sheet'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Selected tab index: $_currentIndex',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Tab bar at the bottom of the same Stack.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CNTabBar(
                items: const [
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
                    label: 'Profile',
                    icon: CNSymbol('person'),
                    activeIcon: CNSymbol('person.fill'),
                  ),
                ],
                currentIndex: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
