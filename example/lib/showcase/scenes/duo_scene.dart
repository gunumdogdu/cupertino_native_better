import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../ios_kit.dart';

/// Files on iPhone Duo: `CNTabScaffold` moves the tabs to the vertical bar
/// when closed and to a sidebar when open, and the book pose splits the
/// list and the selected file at the fold.
class DuoScene extends StatelessWidget {
  const DuoScene({super.key});

  @override
  Widget build(BuildContext context) =>
      const CNFoldableScope(child: _DuoFiles());
}

class _Doc {
  const _Doc(
    this.name,
    this.symbol,
    this.color,
    this.kind,
    this.size,
    this.modified,
  );
  final String name;
  final String symbol;
  final Color color;
  final String kind;
  final String size;
  final String modified;
}

const _docs = [
  _Doc(
    'Q4 Roadmap',
    'tablecells.fill',
    CupertinoColors.systemGreen,
    'Spreadsheet',
    '284 KB',
    'Today at 9:12 AM',
  ),
  _Doc(
    'Keynote Script',
    'doc.richtext.fill',
    CupertinoColors.systemOrange,
    'Document',
    '1.2 MB',
    'Today at 8:40 AM',
  ),
  _Doc(
    'Invoice 2026-118',
    'doc.text.fill',
    CupertinoColors.systemRed,
    'PDF Document',
    '96 KB',
    'Yesterday at 4:05 PM',
  ),
  _Doc(
    'Brand Guidelines',
    'doc.richtext.fill',
    CupertinoColors.systemBlue,
    'Document',
    '4.8 MB',
    'Yesterday at 11:30 AM',
  ),
  _Doc(
    'Launch Teaser',
    'play.rectangle.fill',
    CupertinoColors.systemIndigo,
    'Movie',
    '38.2 MB',
    'Oct 28 at 6:20 PM',
  ),
  _Doc(
    'Interview Notes',
    'waveform',
    CupertinoColors.systemPurple,
    'Audio',
    '3.1 MB',
    'Oct 29 at 10:02 AM',
  ),
  _Doc(
    'Budget 2027',
    'tablecells.fill',
    CupertinoColors.systemGreen,
    'Spreadsheet',
    '112 KB',
    'Oct 27 at 2:48 PM',
  ),
  _Doc(
    'Contract Draft',
    'doc.text.fill',
    CupertinoColors.systemRed,
    'PDF Document',
    '220 KB',
    'Oct 22 at 9:15 AM',
  ),
];

class _DuoFiles extends StatefulWidget {
  const _DuoFiles();

  @override
  State<_DuoFiles> createState() => _DuoFilesState();
}

class _DuoFilesState extends State<_DuoFiles> {
  int _tab = 0;
  int _selected = 0;

  static const _items = [
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
  ];

  @override
  Widget build(BuildContext context) {
    final foldable = CNFoldable.of(context);
    return CNTabScaffold(
      items: _items,
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      sidebarOnWideScreens: true,
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The fold is in the Flutter view's coordinates; the body only
          // moves by a sidebar's width on the left.
          final view = View.of(context);
          final viewWidth = view.physicalSize.width / view.devicePixelRatio;
          final origin = Offset(
            viewWidth - MediaQuery.sizeOf(context).width,
            0,
          );
          final fold = foldable.activeFold;
          final local = fold?.frame.shift(-origin);
          final book =
              fold != null &&
              !fold.isHorizontal &&
              local!.left >= 160 &&
              local.right <= constraints.maxWidth - 160;
          if (!book) return _list(context);
          return Row(
            children: [
              SizedBox(
                width: local.left,
                child: MediaQuery.removePadding(
                  context: context,
                  removeRight: true,
                  child: _list(context, selectable: true),
                ),
              ),
              SizedBox(width: local.width),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeLeft: true,
                  child: _detail(context, _docs[_selected]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _list(BuildContext context, {bool selectable = false}) {
    final highlight = CupertinoColors.systemFill.resolveFrom(context);
    return IOSPage(
      largeTitle: const ['Recents', 'Shared', 'Browse'][_tab],
      children: [
        IOSSection(
          rows: [
            for (var i = 0; i < _docs.length; i++)
              ColoredBox(
                color: selectable && i == _selected
                    ? highlight
                    : const Color(0x00000000),
                child: IOSRow(
                  title: _docs[i].name,
                  subtitle: '${_docs[i].modified} · ${_docs[i].size}',
                  leading: SizedBox(
                    width: IOS.tileSize,
                    child: CNIcon(
                      symbol: CNSymbol(
                        _docs[i].symbol,
                        size: 26,
                        color: _docs[i].color,
                      ),
                    ),
                  ),
                  onTap: () => setState(() => _selected = i),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, _Doc doc) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return IOSPage(
      children: [
        const SizedBox(height: 24),
        Center(
          child: CNIcon(
            symbol: CNSymbol(doc.symbol, size: 96, color: doc.color),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            doc.name,
            style: IOS.largeTitle.copyWith(
              fontSize: 26,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '${doc.kind} · ${doc.size}',
            style: IOS.footnote.copyWith(color: secondary),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CNButton(
                label: 'Open',
                config: const CNButtonConfig(
                  style: CNButtonStyle.prominentGlass,
                  minHeight: 44,
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  shrinkWrap: true,
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                height: 44,
                child: CNButton.icon(
                  icon: CNSymbol(
                    'square.and.arrow.up',
                    size: 17,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                  semanticLabel: 'Share',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        IOSSection(
          header: 'Information',
          rows: [
            IOSRow(title: 'Kind', value: doc.kind),
            IOSRow(title: 'Size', value: doc.size),
            IOSRow(title: 'Modified', value: doc.modified),
            const IOSRow(title: 'Where', value: 'iCloud Drive'),
          ],
        ),
      ],
    );
  }
}
