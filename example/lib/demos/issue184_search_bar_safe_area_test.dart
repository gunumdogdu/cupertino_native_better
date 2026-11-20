import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #184: a `CNSearchBar` drawn a few points higher inside its own
/// frame on some opens of a bottom sheet.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/184
/// Reported by @FaaizParacha. Fix proposed in PR #185.
///
/// ### The claim
///
/// The SwiftUI search bar lives in a `UIHostingController` that takes the
/// window's safe area. When the platform view is laid out while it overlaps
/// a safe-area region (the home indicator while a sheet slides up, or the
/// keyboard), the host insets the fixed-height bar by the overlap, and the
/// field is drawn off-centre in its frame.
///
/// ### How this screen proves it
///
/// Each native view has a magenta outline drawn over it at its Flutter
/// frame. Two rows hold the same views: one in the middle of the screen,
/// and one whose bottom 16 pt reach into the home-indicator area. A third
/// group is a sheet header (a 48 pt search bar and a glass icon button, as
/// in the issue) that slides up from the bottom.
///
///  * **Bug:** in the bottom row (and in some sheet opens) the search
///    field sits higher than its outline; in the middle row it is centred.
///  * **Fixed:** every field is centred in its outline in every row.
///
/// The switch, the stepper and the glass button (the SwiftUI path, with a
/// `glassEffectUnionId`) sit in both rows too, since their hosts took the
/// safe area the same way.
///
/// With `islands`, three `CNFloatingIsland`s take the screen instead, since
/// their host took the safe area too.
///
/// AUTO prints `CNB_RECT <name> l t r b` for every outline, then
/// `CNB_SHOT <step>` at each step: the rows, then four sheet opens, each
/// right after the last one closed (the last two close with the keyboard
/// up).
class Issue184SearchBarSafeAreaTestPage extends StatefulWidget {
  /// Creates the #184 test page.
  const Issue184SearchBarSafeAreaTestPage({
    super.key,
    this.autoCycle = false,
    this.islands = false,
  });

  /// Steps through the rows and the sheet opens on its own.
  final bool autoCycle;

  /// Shows three `CNFloatingIsland`s instead: one reaching into the status
  /// bar, one in the middle and one reaching into the home-indicator area.
  final bool islands;

  @override
  State<Issue184SearchBarSafeAreaTestPage> createState() =>
      _Issue184SearchBarSafeAreaTestPageState();
}

const Color _magenta = Color(0xFFFF00FF);

/// How far the bottom row reaches into the home-indicator area.
const double _overlap = 16;

class _Issue184SearchBarSafeAreaTestPageState
    extends State<Issue184SearchBarSafeAreaTestPage> {
  final Map<String, GlobalKey> _keys = {};
  bool _switch = true;
  double _stepper = 3;
  bool _alive = true;

  GlobalKey _key(String name) => _keys.putIfAbsent(name, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle && widget.islands) {
      Future<void>.delayed(const Duration(seconds: 5), () {
        debugPrint('CNB_SHOT islands');
      });
    } else if (widget.autoCycle) {
      _run();
    }
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  void _printRects(List<String> names) {
    for (final name in names) {
      final box = _keys[name]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      debugPrint(
        'CNB_RECT $name ${rect.left.toStringAsFixed(1)} '
        '${rect.top.toStringAsFixed(1)} ${rect.right.toStringAsFixed(1)} '
        '${rect.bottom.toStringAsFixed(1)}',
      );
    }
  }

  static const _rowNames = [
    'mid_search',
    'mid_switch',
    'mid_stepper',
    'mid_button',
    'bottom_search',
    'bottom_switch',
    'bottom_stepper',
    'bottom_button',
  ];

  Future<void> _run() async {
    await _wait(5000);
    if (!_alive) return;
    _printRects(_rowNames);
    debugPrint('CNB_SHOT rows');
    await _wait(8000);
    for (var i = 1; i <= 4 && _alive; i++) {
      final controller = CNSearchBarController();
      final closed = _openSheet(i, controller);
      await _wait(2500);
      if (!_alive) return;
      _printRects(['sheet_search', 'sheet_button']);
      debugPrint('CNB_SHOT sheet$i');
      await _wait(6000);
      if (i == 4 || !_alive) break;
      if (i >= 2) {
        // Close with the keyboard up, as when an item is picked while
        // typing, and open the next sheet at once.
        await controller.focus();
        await _wait(1200);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      await closed;
      await _wait(150);
    }
    debugPrint('CNB_DONE 184');
  }

  Future<void> _openSheet(int n, CNSearchBarController? controller) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _Sheet(
        n: n,
        searchKey: _key('sheet_search'),
        buttonKey: _key('sheet_button'),
        controller: controller,
      ),
    );
  }

  Widget _row(String prefix) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _Outlined(
            key: _key('${prefix}_search'),
            child: const CNSearchBar(
              placeholder: 'Search cars',
              expandable: false,
              expandedHeight: 48,
              showCancelButton: false,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Outlined(
          key: _key('${prefix}_switch'),
          child: CNSwitch(
            value: _switch,
            onChanged: (v) => setState(() => _switch = v),
          ),
        ),
        const SizedBox(width: 8),
        _Outlined(
          key: _key('${prefix}_stepper'),
          child: CNStepper(
            value: _stepper,
            onChanged: (v) => setState(() => _stepper = v),
          ),
        ),
        const SizedBox(width: 8),
        _Outlined(
          key: _key('${prefix}_button'),
          child: CNButton.icon(
            icon: const CNSymbol('xmark'),
            onPressed: () {},
            config: const CNButtonConfig(
              style: CNButtonStyle.glass,
              glassEffectUnionId: 'issue184',
              minHeight: 48,
              width: 48,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.islands) return const _Islands();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#184 Search bar safe area'),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            top: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Middle of the screen: the fields are centred in their '
                  'magenta outlines.',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 28),
                _row('mid'),
                const SizedBox(height: 32),
                CupertinoButton.filled(
                  onPressed: () => _openSheet(0, null),
                  child: const Text('Open a sheet'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bottom row: its lowest ${_overlap.toInt()} pt reach into '
                  'the home-indicator area (${bottomInset.toInt()} pt).',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            // The row's bottom edge sits _overlap points into the inset.
            bottom: bottomInset > _overlap ? bottomInset - _overlap : 0,
            child: _row('bottom'),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.n,
    required this.searchKey,
    required this.buttonKey,
    this.controller,
  });

  final int n;
  final GlobalKey searchKey;
  final GlobalKey buttonKey;
  final CNSearchBarController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 460,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Outlined(
                  key: searchKey,
                  child: CNSearchBar(
                    placeholder: n.isEven ? 'Search makes' : 'Search models',
                    expandable: false,
                    expandedHeight: 48,
                    showCancelButton: false,
                    controller: controller,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _Outlined(
                key: buttonKey,
                child: CNButton.icon(
                  icon: const CNSymbol('xmark'),
                  onPressed: () => Navigator.of(context).pop(),
                  config: const CNButtonConfig(minHeight: 48, width: 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(n == 0 ? 'Sheet' : 'Sheet $n'),
        ],
      ),
    );
  }
}

/// Three floating islands, 160 x 44, each with a magenta outline at the
/// frame Flutter gives it: the top one's upper 42 pt are in the status bar
/// area (on an iPhone 17 Pro), the bottom one's lower 16 pt in the
/// home-indicator area. The glass pill should fill each outline.
class _Islands extends StatelessWidget {
  const _Islands();

  static const double _w = 160;
  static const double _h = 44;

  Widget _island(
    String label,
    CNFloatingIslandPosition position,
    EdgeInsets margin,
  ) {
    return CNFloatingIsland(
      position: position,
      margin: margin,
      collapsedWidth: _w,
      collapsedHeight: _h,
      collapsed: SizedBox(
        width: _w - 32,
        height: _h,
        child: Center(child: Text(label)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final left = (size.width - _w) / 2;
    final bottomMargin = padding.bottom > _overlap
        ? padding.bottom - _overlap
        : 0.0;
    const topMargin = 20.0;
    const midTop = 380.0;
    Widget outline(double top) => Positioned(
      left: left,
      top: top,
      width: _w,
      height: _h,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _magenta, width: 1),
          ),
        ),
      ),
    );
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          _island(
            'Top',
            CNFloatingIslandPosition.top,
            const EdgeInsets.only(top: topMargin),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: midTop,
            height: _h,
            child: _island(
              'Middle',
              CNFloatingIslandPosition.top,
              EdgeInsets.zero,
            ),
          ),
          _island(
            'Bottom',
            CNFloatingIslandPosition.bottom,
            EdgeInsets.only(bottom: bottomMargin),
          ),
          outline(topMargin),
          outline(midTop),
          outline(size.height - bottomMargin - _h),
        ],
      ),
    );
  }
}

/// Draws a magenta outline over [child] at its exact frame.
class _Outlined extends StatelessWidget {
  const _Outlined({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: _magenta, width: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
