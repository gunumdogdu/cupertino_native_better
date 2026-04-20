import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Scaffold, ScaffoldState, showModalBottomSheet;

/// Reproduction for: when CNTabBar has a `searchItem`, the split-variant
/// native view uses `container.clipsToBounds = false` so the floating
/// Liquid Glass search orb can render above the bar. That unclipped
/// container lets the tab-bar drop shadow bleed through the top edge of
/// any modal/popup pushed over the page.
///
/// Tests all four sheet variants so we can verify which of them still
/// leak shadow into the modal:
///  - showCupertinoSheet (full-screen Cupertino sheet, PageRoute)
///  - showCupertinoModalPopup (action-sheet popup, PopupRoute)
///  - showModalBottomSheet (Material modal, PopupRoute)
///  - showBottomSheet (persistent Material sheet, NOT a route — needs
///    manual `CNTabBarRouteObserver.markAnyModalActive/Inactive`)
class TabBarSplitSearchClipTest extends StatefulWidget {
  const TabBarSplitSearchClipTest({super.key});

  @override
  State<TabBarSplitSearchClipTest> createState() =>
      _TabBarSplitSearchClipTestState();
}

class _TabBarSplitSearchClipTestState extends State<TabBarSplitSearchClipTest> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  String _searchText = '';

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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CupertinoColors.systemTeal,
      body: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemTeal,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemTeal,
          middle: const Text('Split-search tab bar'),
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
                            'Split-search tab bar — sheet z-order test',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This CNTabBar has `searchItem` set. On iOS 26+ the '
                            'native split-search view leaves its container '
                            'UNCLIPPED so the floating search orb can render '
                            'above the bar\'s top edge. Tap each sheet button '
                            'and watch for shadow bleed across the sheet\'s '
                            'top border.',
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
                    Text(
                      'Current tab: $_currentIndex',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_searchText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Search query: "$_searchText"'),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: CNTabBar(
                items: const [
                  CNTabBarItem(
                    label: 'Library',
                    icon: CNSymbol('photo.on.rectangle'),
                    activeIcon: CNSymbol('photo.on.rectangle.fill'),
                  ),
                  CNTabBarItem(
                    label: 'Albums',
                    icon: CNSymbol('square.stack'),
                    activeIcon: CNSymbol('square.stack.fill'),
                  ),
                ],
                currentIndex: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
                searchItem: CNTabBarSearchItem(
                  placeholder: 'Search...',
                  onSearchChanged: (q) => setState(() => _searchText = q),
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
                  'Watch the TOP edge of this sheet against the split-search '
                  'CNTabBar underneath. If a translucent shadow / glass halo '
                  'bleeds across the top border, the containment fix is '
                  'missing for this sheet type.',
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
