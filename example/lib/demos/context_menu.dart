import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Demo for `CNContextMenu`.
///
/// Right-click (or two-finger click, or Control-click) anywhere on a card on
/// macOS: a native `NSMenu` opens at the pointer. Long-press on iOS: the
/// system `UIMenu` opens from the pressed point (iOS 17.4+; a
/// `CupertinoActionSheet` below). The menu uses the same entries as
/// `CNPopupMenuButton`: SF Symbol and custom icons, subtitles, a checked
/// item, a disabled one, a destructive one, dividers, a nested submenu and an
/// inline section. Every choice is logged with its path.
///
/// The last card is a `CNPopupGesture`, which on macOS now opens the native
/// menu on a secondary click too (its long press keeps its own menu).
class ContextMenuDemoPage extends StatefulWidget {
  const ContextMenuDemoPage({super.key, this.autoScenario});

  /// When set, the named scenario fires on the first frame instead of waiting
  /// for a gesture, for screenshot runs without tap automation: `open`
  /// (the photo card's menu at its centre), `rows` (the first row's menu).
  final String? autoScenario;

  /// Key of the photo card, for the macOS driver's synthesized right click.
  static const Key photoCardKey = ValueKey<String>('ctx-photo-card');

  /// Key of the first file row.
  static const Key firstRowKey = ValueKey<String>('ctx-row-0');

  /// Key of the `CNPopupGesture` card.
  static const Key gestureCardKey = ValueKey<String>('ctx-gesture-card');

  @override
  State<ContextMenuDemoPage> createState() => _ContextMenuDemoPageState();
}

class _ContextMenuDemoPageState extends State<ContextMenuDemoPage> {
  final GlobalKey<CNContextMenuState> _photoMenu = GlobalKey();
  final GlobalKey<CNContextMenuState> _rowMenu = GlobalKey();
  String _lastResult = '—';
  bool _favourite = false;

  @override
  void initState() {
    super.initState();
    final scenario = widget.autoScenario;
    if (scenario == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      switch (scenario) {
        case 'open':
          _photoMenu.currentState?.showMenu();
        case 'rows':
          _rowMenu.currentState?.showMenu();
      }
    });
  }

  void _record(String what) {
    debugPrint('CNB_RESULT $what');
    if (!mounted) return;
    setState(() => _lastResult = what);
  }

  List<CNPopupMenuEntry> get _photoItems => [
    const CNPopupMenuItem(
      label: 'Copy',
      icon: CNSymbol('doc.on.doc', size: 16),
    ),
    const CNPopupMenuItem(
      label: 'Share',
      subtitle: 'AirDrop, Messages, Mail',
      icon: CNSymbol('square.and.arrow.up', size: 16),
    ),
    CNPopupMenuItem(
      label: 'Favourite',
      icon: const CNSymbol('heart', size: 16),
      checked: _favourite,
    ),
    const CNPopupMenuDivider(),
    const CNPopupMenuSubmenu(
      label: 'Move to',
      subtitle: '3 albums',
      icon: CNSymbol('folder', size: 16),
      items: [
        CNPopupMenuItem(label: 'Travel', icon: CNSymbol('airplane', size: 16)),
        CNPopupMenuItem(label: 'Family', icon: CNSymbol('person.2', size: 16)),
        CNPopupMenuDivider(),
        CNPopupMenuItem(
          label: 'New album…',
          icon: CNSymbol('plus.rectangle.on.folder', size: 16),
        ),
      ],
    ),
    const CNPopupMenuSubmenu(
      label: 'Rotate',
      style: CNPopupMenuSubmenuStyle.inline,
      items: [
        CNPopupMenuItem(
          label: 'Rotate left',
          icon: CNSymbol('rotate.left', size: 16),
        ),
        CNPopupMenuItem(
          label: 'Rotate right',
          icon: CNSymbol('rotate.right', size: 16),
        ),
      ],
    ),
    const CNPopupMenuDivider(),
    const CNPopupMenuItem(
      label: 'Print',
      icon: CNSymbol('printer', size: 16),
      enabled: false,
    ),
    const CNPopupMenuItem(
      label: 'Edit with a custom icon',
      customIcon: CupertinoIcons.pencil_outline,
    ),
    const CNPopupMenuItem(
      label: 'Delete',
      icon: CNSymbol('trash', size: 16),
      isDestructive: true,
    ),
  ];

  static const List<CNPopupMenuEntry> _rowItems = [
    CNPopupMenuItem(label: 'Open', icon: CNSymbol('arrow.up.forward.app')),
    CNPopupMenuItem(label: 'Rename', icon: CNSymbol('pencil')),
    CNPopupMenuItem(
      label: 'Duplicate',
      icon: CNSymbol('plus.square.on.square'),
    ),
    CNPopupMenuDivider(),
    CNPopupMenuItem(
      label: 'Move to Trash',
      icon: CNSymbol('trash'),
      isDestructive: true,
    ),
  ];

  /// Names a path by the labels on it.
  String _describe(List<CNPopupMenuEntry> items, List<int> path) {
    final labels = <String>[];
    var level = items;
    for (final i in path) {
      if (i < 0 || i >= level.length) break;
      final e = level[i];
      if (e is CNPopupMenuItem) labels.add(e.label);
      if (e is CNPopupMenuSubmenu) {
        labels.add(e.label);
        level = e.items;
      }
    }
    return '$path ${labels.join(' › ')}';
  }

  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final gesture = isMac
        ? 'Right-click (or Control-click)'
        : 'Long-press';
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Context Menu')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '$gesture a card to open its native context menu. Each choice '
              'is reported with its path: one index per level, dividers '
              'included.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text(
                    'Last result: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Text(
                      _lastResult,
                      style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CNContextMenu(
              key: _photoMenu,
              items: _photoItems,
              onSelected: (path) {
                if (path.length == 1 && path.first == 2) {
                  setState(() => _favourite = !_favourite);
                }
                _record('photo ${_describe(_photoItems, path)}');
              },
              child: Container(
                key: ContextMenuDemoPage.photoCardKey,
                height: 180,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5AC8FA), Color(0xFF007AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CNIcon(
                      symbol: CNSymbol(
                        'photo',
                        size: 40,
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Photo — ${gesture.toLowerCase()} me',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'FILES',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < 3; i++)
              CNContextMenu(
                key: i == 0 ? _rowMenu : null,
                items: _rowItems,
                onSelected: (path) =>
                    _record('row $i ${_describe(_rowItems, path)}'),
                child: Container(
                  key: i == 0 ? ContextMenuDemoPage.firstRowKey : null,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemGroupedBackground
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const CNIcon(symbol: CNSymbol('doc.text', size: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Document ${i + 1}.pages')),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        onPressed: () => _record('row $i tapped'),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            CNPopupGesture(
              enableHapticFeedback: false,
              items: const [
                CNPopupMenuItem(
                  label: 'Copy',
                  icon: CNSymbol('doc.on.doc', size: 16),
                ),
                CNPopupMenuDivider(),
                CNPopupMenuItem(
                  label: 'Share',
                  icon: CNSymbol('square.and.arrow.up', size: 16),
                ),
              ],
              onSelected: (index) => _record('CNPopupGesture onSelected($index)'),
              child: Container(
                key: ContextMenuDemoPage.gestureCardKey,
                height: 72,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  isMac
                      ? 'CNPopupGesture — right-click or long-press'
                      : 'CNPopupGesture — long-press',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
