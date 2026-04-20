import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Scaffold, ScaffoldState, showModalBottomSheet;

/// Modal halo test for the remaining iOS 26 glass platform views:
///   - CNPopupMenuButton
///   - CNGlassButtonGroup
///   - CNFloatingIsland
///   - LiquidGlassContainer
///   - CNSearchBar
///
/// Each widget is rendered on a bright teal background so any Liquid
/// Glass halo / drop shadow bleeding through a modal's top edge is
/// obvious. Four sheet types are wired (same pattern as the CNButton
/// and split-search tests):
///   - showCupertinoSheet (PageRoute, full-screen)
///   - showCupertinoModalPopup (PopupRoute)
///   - showModalBottomSheet (PopupRoute)
///   - showBottomSheet (persistent, NOT a route — uses manual
///     `CNTabBarRouteObserver.markAnyModalActive/Inactive`)
///
/// Currently only CNButton and CNTabBar have the `setTransitioning` +
/// `anyModalDepth` containment wired up. If you see halo bleed on any
/// widget here, that widget needs the same pattern mirrored.
class GlassWidgetsModalHaloTest extends StatefulWidget {
  const GlassWidgetsModalHaloTest({super.key});

  @override
  State<GlassWidgetsModalHaloTest> createState() =>
      _GlassWidgetsModalHaloTestState();
}

class _GlassWidgetsModalHaloTestState extends State<GlassWidgetsModalHaloTest> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _popupSelected = -1;
  final CNFloatingIslandController _islandController =
      CNFloatingIslandController();
  String _searchText = '';

  // -------- sheet openers --------

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
          middle: const Text('Glass widgets modal halo'),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionTitle('Instructions'),
              const Text(
                'Each section below renders one of the iOS 26 glass '
                'widgets. Tap one of the four sheet buttons at the bottom '
                "and watch the sheet's top edge for a Liquid Glass halo "
                'bleeding through. Report which widget + which sheet type '
                'leaks.',
                style: TextStyle(fontSize: 13, color: CupertinoColors.black),
              ),

              const SizedBox(height: 12),
              const _SectionTitle('CNPopupMenuButton'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CNPopupMenuButton(
                    buttonLabel: 'Actions',
                    items: const [
                      CNPopupMenuItem(label: 'First'),
                      CNPopupMenuItem(label: 'Second'),
                      CNPopupMenuItem(label: 'Third'),
                    ],
                    onSelected: (i) => setState(() => _popupSelected = i),
                    buttonStyle: CNButtonStyle.glass,
                  ),
                  const SizedBox(width: 16),
                  CNPopupMenuButton.icon(
                    buttonIcon: const CNSymbol('ellipsis', size: 18),
                    size: 44,
                    items: const [
                      CNPopupMenuItem(label: 'Edit'),
                      CNPopupMenuItem(label: 'Delete'),
                    ],
                    onSelected: (i) => setState(() => _popupSelected = i),
                    buttonStyle: CNButtonStyle.glass,
                  ),
                ],
              ),
              if (_popupSelected >= 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Last selected: $_popupSelected',
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 12),
              const _SectionTitle('CNGlassButtonGroup'),
              CNGlassButtonGroup(
                axis: Axis.horizontal,
                spacing: 8.0,
                spacingForGlass: 40.0,
                buttons: [
                  CNButtonData.icon(
                    icon: const CNSymbol('house.fill', size: 18),
                    onPressed: () {},
                    config: const CNButtonDataConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                  CNButtonData.icon(
                    icon: const CNSymbol('magnifyingglass', size: 18),
                    onPressed: () {},
                    config: const CNButtonDataConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                  CNButtonData.icon(
                    icon: const CNSymbol('person.fill', size: 18),
                    onPressed: () {},
                    config: const CNButtonDataConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const _SectionTitle('LiquidGlassContainer'),
              const Center(
                child: LiquidGlassContainer(
                  config: LiquidGlassConfig(
                    effect: CNGlassEffect.regular,
                    shape: CNGlassEffectShape.capsule,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Text(
                      'Liquid glass container',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const _SectionTitle('CNSearchBar'),
              Center(
                child: SizedBox(
                  width: 320,
                  child: CNSearchBar(
                    placeholder: 'Search...',
                    initiallyExpanded: true,
                    onChanged: (q) => setState(() => _searchText = q),
                  ),
                ),
              ),
              if (_searchText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Query: "$_searchText"',
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 12),

              const _SectionTitle('Open a sheet'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  CupertinoButton.filled(
                    onPressed: _showCupertinoSheet,
                    child: const Text('showCupertinoSheet'),
                  ),
                  CupertinoButton.filled(
                    onPressed: _showCupertinoModalPopup,
                    child: const Text('showCupertinoModalPopup'),
                  ),
                  CupertinoButton.filled(
                    onPressed: _showMaterialBottomSheet,
                    child: const Text('showModalBottomSheet'),
                  ),
                  CupertinoButton.filled(
                    onPressed: _showPersistentBottomSheet,
                    child: const Text('showBottomSheet'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.black,
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
                  "Watch the TOP edge of this sheet against each glass "
                  'widget above. A halo / shadow bleed across the top '
                  'border means that widget needs the setTransitioning + '
                  'anyModalDepth containment pattern.',
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: onClose,
                child: const Text('Close'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
