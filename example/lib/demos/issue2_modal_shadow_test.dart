import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// Issue #2 Reproduction: top shadow showing when flutter modal bottom sheet opens.
///
/// Reported regressed in v1.3.8 / v1.3.9 (originally fixed in v1.3.0).
///
/// Steps:
///  1. Open this page - CNTabBar is at the bottom.
///  2. Tap "Show Modal Bottom Sheet" - the modal should cover the tab bar.
///  3. Look at the top edge of where the tab bar was - a thin shadow line
///     should NOT appear above the modal. If you see a shadow drawn over
///     the modal, the regression is present.
class Issue2ModalShadowTest extends StatefulWidget {
  const Issue2ModalShadowTest({super.key});

  @override
  State<Issue2ModalShadowTest> createState() => _Issue2ModalShadowTestState();
}

class _Issue2ModalShadowTestState extends State<Issue2ModalShadowTest> {
  int _currentIndex = 0;

  void _showCupertinoModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 400,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'CupertinoModalPopup',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Watch the top edge of this sheet - no tab-bar shadow line '
                  'should be visible above this content.',
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

  void _showFullScreenSheet() {
    Navigator.of(context).push(
      CupertinoModalPopupRoute<void>(
        builder: (ctx) => Container(
          margin: const EdgeInsets.only(top: 200),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'CupertinoModalPopupRoute (sheet)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Watch the top edge of this sheet - no tab-bar shadow line '
                    'should appear above this content.',
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
      ),
    );
  }

  // ── #37-style sheets (added for cross-screen comparison) ─────────────────
  //
  // These mirror the sheet openers in `issue37_appbar_button_halo_test.dart`
  // so you can verify whether the labels-disappear-after-close bug reproduces
  // with the SAME sheets but a DIFFERENT layout (Column + CNTabBar here vs.
  // Material Scaffold + bottomNavigationBar in #37). If the bug only shows in
  // #37 with these sheets, the Scaffold setup is the culprit, not the sheet.

  Widget _sheetBody(BuildContext ctx, String title, double? height) {
    return SizedBox(
      height: height,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Close this sheet and look at the CNTabBar below. If labels '
                  'go blank until you tap each tab, the labels-disappear bug '
                  'reproduces in THIS layout too.',
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

  void _showCupertinoSheet37() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoSheetRoute<void>(
        builder: (ctx) => _sheetBody(ctx, 'showCupertinoSheet (full)', null),
      ),
    );
  }

  void _showFullModalBottomSheet37() {
    final h = MediaQuery.of(context).size.height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: false,
      builder: (ctx) => _sheetBody(ctx, 'showModalBottomSheet (100%)', h),
    );
  }

  void _showTallModalBottomSheet37() {
    final h = MediaQuery.of(context).size.height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _sheetBody(ctx, 'showModalBottomSheet (90%)', h * 0.9),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Issue #2: Modal shadow'),
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
                          'Issue #2 Regression Test',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Open a modal bottom sheet below and watch the TOP '
                          'edge of the sheet. On v1.3.8/v1.3.9 a thin shadow '
                          'line from the tab bar appears above the sheet. '
                          'Fixed means no such line is visible.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: _showCupertinoModal,
                    child: const Text('Show CupertinoModalPopup'),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton.filled(
                    onPressed: _showFullScreenSheet,
                    child: const Text('Show CupertinoModalPopupRoute (sheet)'),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Cross-screen comparison — same sheets as #37. Open '
                      'each, close, then check whether labels disappear. If '
                      'they DON\'T here but DO in #37, the difference is the '
                      'layout (Scaffold + bottomNavigationBar vs. Column).',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton.filled(
                    onPressed: _showCupertinoSheet37,
                    child: const Text('showCupertinoSheet (full)'),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton.filled(
                    onPressed: _showFullModalBottomSheet37,
                    child: const Text('showModalBottomSheet (100%)'),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton.filled(
                    onPressed: _showTallModalBottomSheet37,
                    child: const Text('showModalBottomSheet (90%)'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Current tab index: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('$_currentIndex'),
                ],
              ),
            ),
          ),
          SafeArea(
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
                  label: 'Library',
                  icon: CNSymbol('books.vertical'),
                  activeIcon: CNSymbol('books.vertical.fill'),
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
        ],
      ),
    );
  }
}
