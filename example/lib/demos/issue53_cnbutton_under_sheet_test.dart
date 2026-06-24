import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Issue #53 reproduction — EXACT mirror of @tiyberius's repro fork.
///
/// Reporter: https://github.com/gunumdogdu/cupertino_native_better/issues/53
/// Fork:     https://github.com/tiyberius/cupertino_native_better/tree/bug/ISSUE-53-CNButton-underneath-bottom-sheet
///
/// What he did: modified the existing "Glass widgets modal halo test" screen
/// to (a) add 3 small glass `CNButton.icon` at the bottom-right, and (b) make
/// `showModalBottomSheet` open his `FilterBottomSheetContent` (which contains
/// a `CNSwitch` + `CNSegmentedControl` + filter pills). The bug surfaces when
/// the sheet is open AND being dragged — the underlying glass widgets bleed
/// halo artifacts into the sheet content.
///
/// This screen is a faithful copy of his page-under-the-sheet, so the bug
/// reproduces exactly:
///   - CNPopupMenuButton row (2 buttons)
///   - CNGlassButtonGroup row (3 icon buttons)
///   - 4 sheet-opener buttons
///   - 3 small SmallEditButton (CNButton.icon glass) at the bottom-right
///
/// How to reproduce:
///   1. Tap "showModalBottomSheet".
///   2. Watch the sheet content (CNSwitch + CNSegmentedControl) and the
///      sheet's top edge for rendering artifacts.
///   3. **Drag** the sheet up/down — bleed is most visible here.
class Issue53CNButtonUnderSheetTest extends StatefulWidget {
  const Issue53CNButtonUnderSheetTest({super.key});

  @override
  State<Issue53CNButtonUnderSheetTest> createState() =>
      _Issue53CNButtonUnderSheetTestState();
}

class _Issue53CNButtonUnderSheetTestState
    extends State<Issue53CNButtonUnderSheetTest> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _popupSelected = -1;

  // ── Sheet openers (kept for parity with reporter's fork) ─────────────────

  void _showCupertinoSheet() {
    final screenH = MediaQuery.of(context).size.height;
    // Use CNBottomSheet.showCupertino so the geometry probe is injected and
    // host-page CN-widgets get position-aware hide instead of all-or-nothing.
    CNBottomSheet.showCupertino<void>(
      context: context,
      pageBuilder: (ctx) => _PlaceholderSheet(
        title: 'showCupertinoSheet (via CNBottomSheet)',
        height: screenH * 0.85,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showCupertinoModalPopup() {
    final screenH = MediaQuery.of(context).size.height;
    // Use CNBottomSheet.showModalPopup for position-aware hide.
    CNBottomSheet.showModalPopup<void>(
      context: context,
      builder: (ctx) => _PlaceholderSheet(
        title: 'showCupertinoModalPopup (via CNBottomSheet)',
        height: screenH * 0.85,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  // The repro-trigger button: opens the FilterBottomSheetContent via
  // CNBottomSheet.show — the position-aware wrapper that publishes the
  // sheet's live rect so host-page CN-widgets above the sheet stay alive.
  void _showMaterialBottomSheet() {
    final screenH = MediaQuery.of(context).size.height;
    CNBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[100],
      builder: (ctx) => SizedBox(
        height: screenH * 0.85,
        child: const SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [FilterBottomSheetContent()],
          ),
        ),
      ),
    );
  }

  void _showPersistentBottomSheet() {
    final state = _scaffoldKey.currentState;
    if (state == null) return;
    final screenH = MediaQuery.of(context).size.height;
    // Scaffold.showBottomSheet returns a controller (not a Future), so we
    // can't use the CNBottomSheet.show wrapper. Manually wrap the builder
    // in CNSheetGeometryProbe so host-page CN-widgets still get position-
    // aware hide for this sheet.
    final controller = state.showBottomSheet(
      (ctx) => CNSheetGeometryProbe(
        child: _PlaceholderSheet(
          title: 'showBottomSheet (persistent, manual probe)',
          height: screenH * 0.85,
          onClose: () => Navigator.of(ctx).pop(),
        ),
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
      body: Stack(
        children: [
          // Main content.
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 60, // reserve room for the right-edge button column
                top: 16,
                bottom: 16,
              ),
              children: [
                const _SectionTitle('Instructions'),
                const Text(
                  'Issue #53 repro (reported by @tiyberius). The page under the '
                  'sheet is the same as the existing "Glass widgets modal halo '
                  "test\" minus LiquidGlassContainer/CNSearchBar — exact mirror "
                  'of his fork. Tap "showModalBottomSheet" and DRAG the sheet '
                  'up/down to see the halo bleed through the sheet content.',
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

                const SizedBox(height: 120),

                // The CNButtons that, sitting UNDER the modal bottom sheet,
                // cause the reporter's halo-bleed artifacts.
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _SmallEditButton(),
                    _SmallEditButton(),
                    _SmallEditButton(),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
          // Vertical column of CNButtons down the right edge — gives the
          // user a way to test the sheet-drag against PlatformViews at the
          // top, middle, AND bottom of the screen simultaneously.
          Positioned(
            top: 0,
            bottom: 0,
            right: 8,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _SmallEditButton(),
                  _SmallEditButton(),
                  _SmallEditButton(),
                  _SmallEditButton(),
                  _SmallEditButton(),
                  _SmallEditButton(),
                  _SmallEditButton(),
                  _SmallEditButton(),
                  _SmallEditButton(),
                ],
              ),
            ),
          ),
        ],
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

class _PlaceholderSheet extends StatelessWidget {
  const _PlaceholderSheet({
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
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'For #53, use the showModalBottomSheet button — it opens '
                  'the FilterBottomSheetContent with CNSwitch + '
                  'CNSegmentedControl which is where the bug surfaces.',
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

/// The exact CNButton variant from the reporter's repro — small icon-only
/// glass button (36×36, square.and.pencil).
class _SmallEditButton extends StatelessWidget {
  const _SmallEditButton();

  @override
  Widget build(BuildContext context) {
    return UnconstrainedBox(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(height: 36, width: 36),
          child: CNButton.icon(
            icon: const CNSymbol('square.and.pencil', size: 18),
            onPressed: () {},
            config: const CNButtonConfig(
              style: CNButtonStyle.glass,
              padding: EdgeInsets.zero,
              labelFontSize: 16,
              shrinkWrap: true,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom sheet content (verbatim mirror of tiyberius's filtering_options_bottom_sheet.dart) ──

class FilterBottomSheetContent extends StatefulWidget {
  const FilterBottomSheetContent({super.key});

  @override
  State<FilterBottomSheetContent> createState() =>
      _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<FilterBottomSheetContent> {
  static const _availableAreas = ['Pill', 'Another Pill'];
  bool _toggleValue = false;
  int _selectedForecastIndex = 0;
  final Set<String> _selectedAreas = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(CupertinoIcons.line_horizontal_3_decrease_circle),
                      SizedBox(width: 6),
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _toggleValue = false;
                      _selectedForecastIndex = 0;
                      _selectedAreas.clear();
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            // CNSwitch + animated CNSegmentedControl.
            _GroupedContainer(
              children: [
                // Original CNSwitch row (the reporter's exact setup).
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CNSwitch Row',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      CNSwitch(
                        value: _toggleValue,
                        onChanged: (v) => setState(() => _toggleValue = v),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => SizeTransition(
                    sizeFactor: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _toggleValue
                      ? Padding(
                          key: const ValueKey('timing_picker'),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: CNSegmentedControl(
                              labels: const [
                                'Anytime',
                                'Within 3 Days',
                                'On Weekend',
                              ],
                              selectedIndex: _selectedForecastIndex,
                              onValueChanged: (i) =>
                                  setState(() => _selectedForecastIndex = i),
                              color: Colors.blue,
                              height: 32.0,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // AREAS label + pills.
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'AREAS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            _GroupedContainer(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _availableAreas.map((area) {
                        final isSelected = _selectedAreas.contains(area);
                        return _FilterPill(
                          label: area,
                          isSelected: isSelected,
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selectedAreas.remove(area);
                            } else {
                              _selectedAreas.add(area);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Show Results'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GroupedContainer extends StatelessWidget {
  const _GroupedContainer({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: children),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : CupertinoColors.systemGrey4.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
