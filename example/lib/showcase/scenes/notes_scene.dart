import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../ios_kit.dart';

/// A notes list: a tab bar whose "+" item opens a native menu, and a header
/// menu with a formatting palette, an inline section and items that keep the
/// menu open.
class NotesScene extends StatefulWidget {
  const NotesScene({super.key});

  @override
  State<NotesScene> createState() => _NotesSceneState();
}

class _NotesSceneState extends State<NotesScene> {
  int _tab = 0;

  static const _seed = [
    ('Trip to Lisbon', 'Tram 28 · Time Out Market · LX Factory', 'Today'),
    ('Groceries', 'Oat milk, lemons, sourdough, basil', 'Today'),
    ('Book club', 'Chapter 7 discussion questions', 'Yesterday'),
    ('Gift ideas', 'Record player for Mia, a good fountain pen', 'Monday'),
    ('Workout plan', 'Mon run · Wed swim · Fri strength', 'Sunday'),
  ];

  double _scale = 1;
  final _notes = [..._seed];

  void _onCreate(List<int> path) {
    final title = switch (path) {
      [1] => 'New Checklist',
      [2, 0] => 'Imported Photo',
      [2, 1] => 'Imported File',
      [3] => 'Scanned Document',
      _ => 'New Note',
    };
    setState(() => _notes.insert(0, (title, 'No additional text', 'Now')));
  }

  void _onView(List<int> path) {
    // Larger and Smaller Text keep the menu open, so the list grows behind it.
    if (path.length != 1) return;
    setState(() {
      if (path[0] == 3) _scale = (_scale + 0.12).clamp(0.8, 1.6);
      if (path[0] == 4) _scale = (_scale - 0.12).clamp(0.8, 1.6);
    });
  }

  static const _create = <CNPopupMenuEntry>[
    CNPopupMenuItem(
      label: 'New Note',
      subtitle: 'Text, lists and photos',
      icon: CNSymbol('square.and.pencil'),
    ),
    CNPopupMenuItem(label: 'New Checklist', icon: CNSymbol('checklist')),
    CNPopupMenuDivider(),
    CNPopupMenuSubmenu(
      label: 'Import',
      icon: CNSymbol('square.and.arrow.down'),
      items: [
        CNPopupMenuItem(label: 'From Photos', icon: CNSymbol('photo')),
        CNPopupMenuItem(label: 'From Files', icon: CNSymbol('folder')),
      ],
    ),
    CNPopupMenuItem(label: 'Scan Document', icon: CNSymbol('doc.viewfinder')),
  ];

  static const _view = <CNPopupMenuEntry>[
    CNPopupMenuSubmenu(
      label: 'Format',
      style: CNPopupMenuSubmenuStyle.palette,
      items: [
        CNPopupMenuItem(label: 'Bold', icon: CNSymbol('bold')),
        CNPopupMenuItem(label: 'Italic', icon: CNSymbol('italic')),
        CNPopupMenuItem(label: 'Underline', icon: CNSymbol('underline')),
        CNPopupMenuItem(
          label: 'Strikethrough',
          icon: CNSymbol('strikethrough'),
        ),
      ],
    ),
    CNPopupMenuSubmenu(
      label: 'Sort By',
      style: CNPopupMenuSubmenuStyle.inline,
      elementSize: CNPopupMenuElementSize.medium,
      items: [
        CNPopupMenuItem(label: 'Edited', icon: CNSymbol('pencil')),
        CNPopupMenuItem(label: 'Created', icon: CNSymbol('calendar')),
        CNPopupMenuItem(label: 'Title', icon: CNSymbol('textformat')),
      ],
    ),
    CNPopupMenuDivider(),
    CNPopupMenuItem(
      label: 'Larger Text',
      icon: CNSymbol('textformat.size.larger'),
      keepsMenuPresented: true,
    ),
    CNPopupMenuItem(
      label: 'Smaller Text',
      icon: CNSymbol('textformat.size.smaller'),
      keepsMenuPresented: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    return Stack(
      children: [
        IOSPage(
          largeTitle: 'Notes',
          trailing: CNPopupMenuButton.icon(
            buttonIcon: const CNSymbol('ellipsis', size: 18),
            size: 44,
            items: _view,
            onPathSelected: _onView,
          ),
          bottomPadding: 120,
          children: [
            IOSSection(
              rows: [
                for (final note in _notes)
                  SizedBox(
                    width: double.infinity,
                    height: 56 + 16 * _scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.$1,
                            style: IOS.body.copyWith(
                              color: label,
                              fontSize: 17 * _scale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${note.$3}  ${note.$2}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: IOS.footnote.copyWith(
                              color: secondary,
                              fontSize: 15 * _scale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: CNTabBar(
              items: const [
                CNTabBarItem(label: 'Notes', icon: CNSymbol('note.text')),
                CNTabBarItem(label: 'Folders', icon: CNSymbol('folder')),
                CNTabBarItem(label: 'Shared', icon: CNSymbol('person.2')),
                CNTabBarItem(icon: CNSymbol('plus'), menuItems: _create),
              ],
              currentIndex: _tab,
              split: true,
              rightCount: 1,
              tint: CupertinoColors.systemYellow,
              onTap: (i) => setState(() => _tab = i),
              onMenuSelected: (_, path) => _onCreate(path),
            ),
          ),
        ),
      ],
    );
  }
}
