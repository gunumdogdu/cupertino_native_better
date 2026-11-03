import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// `CNTabBarItem.menuItems`: a tab bar item that opens a native menu.
///
/// ### What it is for
///
/// A "+" item that lets the user pick what to create, each entry leading to
/// its own page, where an app would otherwise float a button above the bar.
/// The item never gets selected: the menu opens from it, and the chosen
/// entry goes to `CNTabBar.onMenuSelected` with its path, as in
/// `CNPopupMenuButton.onPathSelected`.
///
/// ### How this screen checks it
///
///  * **"+"** (split on the right) opens a menu with subtitles, a divider, a
///    submenu inside a submenu and a disabled entry. Opening the submenus
///    must not close or redraw the menu.
///  * **Menu on Library** gives the second item a menu too, to check an item
///    inside the left group.
///  * Sliding a finger along the bar onto an item with a menu opens it too.
///  * **Change entries** rebuilds the "+" menu (`setMenus`) while the bar
///    stays.
///  * The log shows `onTap` and `onMenuSelected`: tapping an item with a
///    menu never calls `onTap`, and the selection stays where it was.
class TabBarItemMenusTestPage extends StatefulWidget {
  const TabBarItemMenusTestPage({super.key});

  @override
  State<TabBarItemMenusTestPage> createState() =>
      _TabBarItemMenusTestPageState();
}

class _TabBarItemMenusTestPageState extends State<TabBarItemMenusTestPage> {
  final List<String> _log = [];
  int _tabIndex = 0;
  bool _libraryMenu = false;
  bool _otherEntries = false;

  void _addLog(String msg) {
    setState(() {
      _log.insert(0, msg);
      if (_log.length > 10) _log.removeLast();
    });
  }

  List<CNPopupMenuEntry> get _createMenu => [
    const CNPopupMenuItem(
      label: 'New note',
      subtitle: 'Text, lists and photos',
      icon: CNSymbol('square.and.pencil', size: 18),
    ),
    const CNPopupMenuItem(
      label: 'New folder',
      icon: CNSymbol('folder.badge.plus', size: 18),
    ),
    const CNPopupMenuDivider(),
    CNPopupMenuSubmenu(
      label: 'Import',
      icon: const CNSymbol('square.and.arrow.down', size: 18),
      items: [
        const CNPopupMenuItem(
          label: 'Photo',
          icon: CNSymbol('photo', size: 18),
        ),
        CNPopupMenuSubmenu(
          label: 'File',
          icon: const CNSymbol('doc', size: 18),
          items: [
            const CNPopupMenuItem(label: 'PDF'),
            CNPopupMenuItem(label: _otherEntries ? 'Markdown' : 'Text'),
          ],
        ),
      ],
    ),
    const CNPopupMenuItem(
      label: 'Scan',
      subtitle: 'No camera',
      icon: CNSymbol('doc.viewfinder', size: 18),
      enabled: false,
    ),
  ];

  List<CNTabBarItem> get _items => [
    const CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
    CNTabBarItem(
      label: 'Library',
      icon: const CNSymbol('books.vertical.fill'),
      menuItems: _libraryMenu
          ? const [
              CNPopupMenuItem(label: 'Books'),
              CNPopupMenuItem(label: 'Audiobooks'),
            ]
          : null,
    ),
    const CNTabBarItem(label: 'Profile', icon: CNSymbol('person.fill')),
    CNTabBarItem(icon: const CNSymbol('plus'), menuItems: _createMenu),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('TabBar item menus'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: SafeArea(bottom: false, child: _controls())),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CNTabBar(
                items: _items,
                currentIndex: _tabIndex,
                onTap: (int i) {
                  setState(() => _tabIndex = i);
                  _addLog('onTap($i)');
                },
                onMenuSelected: (int index, List<int> path) =>
                    _addLog('onMenuSelected($index, $path)'),
                tint: CupertinoColors.systemBlue,
                split: true,
                rightCount: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Tap "+" for a menu with a submenu inside a submenu. Tapping an '
            'item with a menu never calls onTap nor moves the selection.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _button(
                'Menu on Library',
                () => setState(() => _libraryMenu = !_libraryMenu),
              ),
              const SizedBox(width: 8),
              _button(
                'Change entries',
                () => setState(() => _otherEntries = !_otherEntries),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'tab $_tabIndex · Library menu ${_libraryMenu ? 'on' : 'off'} · '
            'File > ${_otherEntries ? 'Markdown' : 'Text'}',
            style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
          ),
          const SizedBox(height: 8),
          for (final line in _log)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed) {
    return Expanded(
      child: CupertinoButton.filled(
        padding: const EdgeInsets.symmetric(vertical: 10),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
