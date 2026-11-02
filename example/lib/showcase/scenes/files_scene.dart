import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../ios_kit.dart';

/// A Files-style app: the native tab bar with a search tab, and a "…" menu
/// with subtitles and submenus that sorts the list.
class FilesScene extends StatefulWidget {
  const FilesScene({super.key});

  @override
  State<FilesScene> createState() => _FilesSceneState();
}

class _File {
  const _File(
    this.name,
    this.symbol,
    this.color,
    this.kind,
    this.age,
    this.detail,
    this.size,
  );
  final String name;
  final String symbol;
  final Color color;
  final String kind;

  /// Minutes since the file was modified, for sorting by date.
  final int age;
  final String detail;
  final int size;
}

const _folderBlue = Color(0xFF3D9BF6);

const _recents = [
  _File(
    'Q4 Roadmap',
    'tablecells.fill',
    CupertinoColors.systemGreen,
    'Spreadsheet',
    29,
    'Today at 9:12 AM · 284 KB',
    284,
  ),
  _File(
    'Keynote Script',
    'doc.richtext.fill',
    CupertinoColors.systemOrange,
    'Document',
    61,
    'Today at 8:40 AM · 1.2 MB',
    1200,
  ),
  _File(
    'Invoice 2026-118',
    'doc.text.fill',
    CupertinoColors.systemRed,
    'PDF',
    1440,
    'Yesterday · 96 KB',
    96,
  ),
  _File(
    'Brand Guidelines',
    'doc.richtext.fill',
    CupertinoColors.systemBlue,
    'Document',
    1500,
    'Yesterday · 4.8 MB',
    4800,
  ),
  _File(
    'Product Shots',
    'folder.fill',
    _folderBlue,
    'Folder',
    4320,
    'Oct 30 · 24 items',
    0,
  ),
  _File(
    'Interview Notes',
    'waveform',
    CupertinoColors.systemPurple,
    'Audio',
    5760,
    'Oct 29 · 12:40',
    3100,
  ),
  _File(
    'Launch Teaser',
    'play.rectangle.fill',
    CupertinoColors.systemIndigo,
    'Movie',
    7200,
    'Oct 28 · 38.2 MB',
    38200,
  ),
  _File(
    'Budget 2027',
    'tablecells.fill',
    CupertinoColors.systemGreen,
    'Spreadsheet',
    8640,
    'Oct 27 · 112 KB',
    112,
  ),
  _File(
    'Team Offsite',
    'folder.fill',
    _folderBlue,
    'Folder',
    12960,
    'Oct 24 · 9 items',
    0,
  ),
  _File(
    'Contract Draft',
    'doc.text.fill',
    CupertinoColors.systemRed,
    'PDF',
    15840,
    'Oct 22 · 220 KB',
    220,
  ),
];

class _FilesSceneState extends State<FilesScene> {
  int _tab = 0;
  int _sort = 2; // Name, Kind, Date, Size
  int _view = 1; // Icons, List

  static const _sortNames = ['Name', 'Kind', 'Date', 'Size'];
  static const _titles = ['Recents', 'Shared', 'Browse'];

  List<_File> get _sorted {
    final files = [..._recents];
    switch (_sort) {
      case 0:
        files.sort((a, b) => a.name.compareTo(b.name));
      case 1:
        files.sort((a, b) => a.kind.compareTo(b.kind));
      case 2:
        files.sort((a, b) => a.age.compareTo(b.age));
      case 3:
        files.sort((a, b) => b.size.compareTo(a.size));
    }
    return files;
  }

  void _onMenu(List<int> path) {
    setState(() {
      if (path.first == 3 && path.length == 2) _sort = path[1];
      if (path.first == 4 && path.length == 2) _view = path[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IOSPage(
            largeTitle: _titles[_tab],
            trailing: CNPopupMenuButton.icon(
              buttonIcon: CNSymbol(
                'ellipsis',
                size: 17,
                color: CupertinoColors.label.resolveFrom(context),
              ),
              semanticLabel: 'More',
              items: [
                const CNPopupMenuItem(
                  label: 'Select',
                  icon: CNSymbol('checkmark.circle'),
                ),
                const CNPopupMenuItem(
                  label: 'New Folder',
                  icon: CNSymbol('folder.badge.plus'),
                ),
                const CNPopupMenuDivider(),
                CNPopupMenuSubmenu(
                  label: 'Sort By',
                  subtitle: _sortNames[_sort],
                  icon: const CNSymbol('arrow.up.arrow.down'),
                  items: [
                    for (var i = 0; i < _sortNames.length; i++)
                      CNPopupMenuItem(
                        label: _sortNames[i],
                        checked: _sort == i,
                      ),
                  ],
                ),
                CNPopupMenuSubmenu(
                  label: 'View',
                  subtitle: _view == 0 ? 'Icons' : 'List',
                  icon: CNSymbol(
                    _view == 0 ? 'square.grid.2x2' : 'list.bullet',
                  ),
                  items: [
                    CNPopupMenuItem(
                      label: 'Icons',
                      icon: const CNSymbol('square.grid.2x2'),
                      checked: _view == 0,
                    ),
                    CNPopupMenuItem(
                      label: 'List',
                      icon: const CNSymbol('list.bullet'),
                      checked: _view == 1,
                    ),
                  ],
                ),
              ],
              onPathSelected: _onMenu,
            ),
            bottomPadding: 120,
            children: switch (_tab) {
              0 => [
                IOSSection(rows: [for (final f in _sorted) _fileRow(f)]),
              ],
              1 => [
                IOSSection(
                  header: 'Shared with You',
                  rows: [
                    _fileRow(_recents[3], detail: 'From Maya · Yesterday'),
                    _fileRow(_recents[4], detail: 'From Leo · Oct 30'),
                    _fileRow(_recents[0], detail: 'From Ava · Today'),
                  ],
                ),
                IOSSection(
                  header: 'Shared by Me',
                  rows: [
                    _fileRow(_recents[8], detail: '4 people · Oct 24'),
                    _fileRow(_recents[6], detail: '2 people · Oct 28'),
                  ],
                ),
              ],
              _ => const [
                IOSSection(
                  header: 'Locations',
                  rows: [
                    IOSRow(
                      title: 'iCloud Drive',
                      icon: 'icloud.fill',
                      iconColor: CupertinoColors.systemBlue,
                      chevron: true,
                    ),
                    IOSRow(
                      title: 'On My iPhone',
                      icon: 'iphone',
                      iconColor: CupertinoColors.systemGrey,
                      chevron: true,
                    ),
                    IOSRow(
                      title: 'Recently Deleted',
                      icon: 'trash.fill',
                      iconColor: CupertinoColors.systemGrey2,
                      chevron: true,
                    ),
                  ],
                ),
                IOSSection(
                  header: 'Favorites',
                  rows: [
                    IOSRow(
                      title: 'Downloads',
                      icon: 'arrow.down.circle.fill',
                      iconColor: CupertinoColors.systemBlue,
                      chevron: true,
                    ),
                    IOSRow(
                      title: 'Documents',
                      icon: 'doc.fill',
                      iconColor: CupertinoColors.systemTeal,
                      chevron: true,
                    ),
                    IOSRow(
                      title: 'Desktop',
                      icon: 'menubar.dock.rectangle',
                      iconColor: CupertinoColors.systemIndigo,
                      chevron: true,
                    ),
                  ],
                ),
                IOSSection(
                  header: 'Tags',
                  rows: [
                    IOSRow(
                      title: 'Work',
                      icon: 'circle.fill',
                      iconColor: CupertinoColors.systemOrange,
                    ),
                    IOSRow(
                      title: 'Personal',
                      icon: 'circle.fill',
                      iconColor: CupertinoColors.systemGreen,
                    ),
                    IOSRow(
                      title: 'Important',
                      icon: 'circle.fill',
                      iconColor: CupertinoColors.systemRed,
                    ),
                  ],
                ),
              ],
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: CNTabBar(
              items: const [
                CNTabBarItem(
                  label: 'Recents',
                  icon: CNSymbol('clock'),
                  activeIcon: CNSymbol('clock.fill'),
                ),
                CNTabBarItem(
                  label: 'Shared',
                  icon: CNSymbol('folder.badge.person.crop'),
                  activeIcon: CNSymbol('folder.fill.badge.person.crop'),
                ),
                CNTabBarItem(
                  label: 'Browse',
                  icon: CNSymbol('folder'),
                  activeIcon: CNSymbol('folder.fill'),
                ),
              ],
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              searchItem: const CNTabBarSearchItem(placeholder: 'Search'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fileRow(_File f, {String? detail}) {
    return IOSRow(
      title: f.name,
      subtitle: detail ?? f.detail,
      leading: SizedBox(
        width: IOS.tileSize,
        child: CNIcon(symbol: CNSymbol(f.symbol, size: 26, color: f.color)),
      ),
    );
  }
}
