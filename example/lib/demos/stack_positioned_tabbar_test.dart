import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Scaffold, ScaffoldState, showModalBottomSheet;

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
/// Tests all four sheet variants so the user can verify each layer of the
/// halo-containment fix:
///  - showCupertinoSheet (full-screen Cupertino sheet, PageRoute)
///  - showCupertinoModalPopup (action-sheet popup, PopupRoute)
///  - showModalBottomSheet (Material modal, PopupRoute)
///  - showBottomSheet (persistent Material sheet, NOT a route — needs
///    manual `CNTabBarRouteObserver.markAnyModalActive/Inactive`)
class StackPositionedTabBarTest extends StatefulWidget {
  const StackPositionedTabBarTest({super.key});

  @override
  State<StackPositionedTabBarTest> createState() =>
      _StackPositionedTabBarTestState();
}

class _StackPositionedTabBarTestState extends State<StackPositionedTabBarTest> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  void _showCupertinoSheet() {
    showCupertinoSheet<void>(
      context: context,
      builder: (ctx) => _SheetBody(
        title: 'showCupertinoSheet',
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showCupertinoModalPopup() {
    final screenH = MediaQuery.of(context).size.height;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _SheetBody(
        title: 'showCupertinoModalPopup',
        height: screenH * 0.5,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showMaterialBottomSheet() {
    final screenH = MediaQuery.of(context).size.height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SheetBody(
        title: 'showModalBottomSheet',
        height: screenH * 0.5,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showPersistentBottomSheet() {
    // Persistent (non-modal) sheet anchored to ScaffoldState. The
    // NavigatorObserver does not see it, so we manually bump the
    // `anyModalDepth` counter so CNTabBar's auto-hide and any glass
    // widget's containment still engages.
    final state = _scaffoldKey.currentState;
    if (state == null) return;
    final screenH = MediaQuery.of(context).size.height;
    final controller = state.showBottomSheet(
      (ctx) => _SheetBody(
        title: 'showBottomSheet (persistent)',
        height: screenH * 0.5,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
    CNTabBarRouteObserver.markAnyModalActive();
    controller.closed.whenComplete(CNTabBarRouteObserver.markAnyModalInactive);
  }

  @override
  Widget build(BuildContext context) {
    // Material `Scaffold` wraps so `showBottomSheet` has an anchor.
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CupertinoColors.systemTeal,
      body: CupertinoPageScaffold(
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
        child: Stack(
          children: [
            // Body content — full screen, extends behind the tab bar.
            SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
                          'Stack + Positioned tab bar — sheet z-order test',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'CNTabBar is inside a Stack with Positioned(bottom: 0). '
                          'Tap each sheet button below and watch the TOP edge of '
                          'the sheet for any tab-bar shadow / glass halo bleeding '
                          'through. There should be none in any of the four cases.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: _showCupertinoSheet,
                    child: const Text('showCupertinoSheet'),
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton.filled(
                    onPressed: _showCupertinoModalPopup,
                    child: const Text('showCupertinoModalPopup'),
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton.filled(
                    onPressed: _showMaterialBottomSheet,
                    child: const Text('showModalBottomSheet'),
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton.filled(
                    onPressed: _showPersistentBottomSheet,
                    child: const Text('showBottomSheet (persistent)'),
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
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.onClose,
    this.height = 320,
  });

  final String title;
  final VoidCallback onClose;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
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
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Watch the TOP edge of this sheet against the CNTabBar '
                  'underneath. If a translucent shadow / glass halo bleeds '
                  'across the top border, the containment fix is missing '
                  'for this sheet type.',
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: onClose,
                child: const Text('Close'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
