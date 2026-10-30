import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Subtitles and submenus in `CNPopupMenuButton`.
///
/// This screen verifies that:
///   • `CNPopupMenuItem.subtitle` shows a second line under the label
///     (`UIAction.subtitle` on iOS, `NSMenuItem.subtitle` on macOS 14.4+).
///   • `CNPopupMenuSubmenu` opens a nested menu, nested again inside it, and
///     a disabled one cannot be opened.
///   • `onPathSelected` gets the full path of every selection, and
///     `onSelected` the index of the top-level entry it is under.
///   • a custom icon after a divider stays on its own item (it used to take
///     the icon of the entry before it, or none).
///   • with `preserveTopToBottomOrder`, a menu opening upward from the bottom
///     of the screen keeps its order, in its submenus too (iOS 16+).
///   • on iOS < 26 / non-iOS, the CupertinoActionSheet fallback shows the
///     subtitles and opens each submenu as a second sheet.
class PopupMenuSubmenusTest extends StatefulWidget {
  const PopupMenuSubmenusTest({super.key});

  @override
  State<PopupMenuSubmenusTest> createState() => _PopupMenuSubmenusTestState();
}

class _PopupMenuSubmenusTestState extends State<PopupMenuSubmenusTest> {
  final List<String> _log = [];

  void _addLog(String msg) {
    setState(() {
      _log.insert(0, msg);
      if (_log.length > 12) _log.removeLast();
    });
  }

  static const _sortItems = <CNPopupMenuEntry>[
    CNPopupMenuItem(
      label: 'Name',
      subtitle: 'A to Z',
      icon: CNSymbol('textformat', size: 18),
      checked: true,
    ),
    CNPopupMenuItem(
      label: 'Date modified',
      subtitle: 'Newest first',
      icon: CNSymbol('calendar', size: 18),
    ),
    CNPopupMenuItem(label: 'Size', icon: CNSymbol('internaldrive', size: 18)),
  ];

  static const _actionItems = <CNPopupMenuEntry>[
    CNPopupMenuItem(label: 'Rename', icon: CNSymbol('pencil', size: 18)),
    CNPopupMenuDivider(),
    CNPopupMenuSubmenu(
      label: 'Export',
      subtitle: '3 formats',
      icon: CNSymbol('square.and.arrow.up', size: 18),
      items: [
        CNPopupMenuItem(
          label: 'PDF',
          subtitle: 'Best for printing',
          icon: CNSymbol('doc.richtext', size: 18),
        ),
        CNPopupMenuItem(label: 'Image', icon: CNSymbol('photo', size: 18)),
        CNPopupMenuDivider(),
        CNPopupMenuSubmenu(
          label: 'Spreadsheet',
          icon: CNSymbol('tablecells', size: 18),
          items: [
            CNPopupMenuItem(label: 'CSV', subtitle: 'Semicolon separated'),
            CNPopupMenuItem(label: 'Numbers'),
          ],
        ),
      ],
    ),
    CNPopupMenuSubmenu(
      label: 'Move to',
      subtitle: 'No other folder',
      icon: CNSymbol('folder', size: 18),
      enabled: false,
      items: [CNPopupMenuItem(label: 'Unreachable')],
    ),
    CNPopupMenuDivider(),
    CNPopupMenuItem(
      label: 'Favourite',
      customIcon: CupertinoIcons.heart,
      iconColor: CupertinoColors.systemPink,
    ),
    CNPopupMenuItem(
      label: 'Delete',
      icon: CNSymbol('trash', size: 18),
      isDestructive: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PopupMenu subtitles & submenus'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildList()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bottom button — opens upward, preserveTopToBottomOrder',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  CNPopupMenuButton.icon(
                    buttonIcon: const CNSymbol('plus', size: 20),
                    semanticLabel: 'Add',
                    preserveTopToBottomOrder: true,
                    items: _actionItems,
                    onPathSelected: (path) =>
                        _addLog('Bottom: onPathSelected($path)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Text button — items with subtitles (onSelected only)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: CNPopupMenuButton(
            buttonLabel: 'Sort by',
            shrinkWrap: true,
            buttonStyle: CNButtonStyle.glass,
            items: _sortItems,
            onSelected: (i) => _addLog('Sort: onSelected($i)'),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Icon button — nested and disabled submenus (both callbacks)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          '"Favourite" comes after a divider and must keep its pink heart.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: CNPopupMenuButton.icon(
            buttonIcon: const CNSymbol('ellipsis', size: 18),
            semanticLabel: 'Actions',
            items: _actionItems,
            onSelected: (i) => _addLog('Actions: onSelected($i)'),
            onPathSelected: (path) => _addLog('Actions: onPathSelected($path)'),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Text button — onPathSelected only',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: CNPopupMenuButton(
            buttonLabel: 'Share',
            shrinkWrap: true,
            buttonStyle: CNButtonStyle.glass,
            items: _actionItems,
            onPathSelected: (path) => _addLog('Share: onPathSelected($path)'),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Log', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final line in _log)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(line, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}
