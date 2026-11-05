import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// [CNSidebar], the native macOS sidebar that Flutter lays out, and the two
/// widgets that use it on macOS: [CNTabRail] (rail and sidebar styles) and
/// [CNTabScaffold] with its sidebar placement.
///
/// On iOS the same page shows the [CNTabRail] that stands in for the
/// sidebar there.
class SidebarDemoPage extends StatefulWidget {
  const SidebarDemoPage({super.key, this.initialView = 0});

  /// The view shown first: 0 [CNSidebar], 1 [CNTabRail], 2 [CNTabScaffold].
  /// Used by the screenshot probes.
  final int initialView;

  @override
  State<SidebarDemoPage> createState() => _SidebarDemoPageState();
}

class _SidebarDemoPageState extends State<SidebarDemoPage> {
  late int _view = widget.initialView;
  int _selected = 0;
  int _railIndex = 1;
  int _scaffoldIndex = 0;
  int _unread = 3;
  bool _iconsOnly = false;

  List<CNSidebarSection> get _sections => [
    CNSidebarSection(
      items: [
        CNSidebarItem(
          title: 'Inbox',
          sfSymbol: const CNSymbol('tray'),
          activeSfSymbol: const CNSymbol('tray.fill'),
          badge: _unread > 0 ? '$_unread' : null,
        ),
        const CNSidebarItem(
          title: 'Flagged',
          sfSymbol: CNSymbol('flag'),
          badge: CNSidebarItem.dotBadge,
        ),
        const CNSidebarItem(title: 'Sent', sfSymbol: CNSymbol('paperplane')),
      ],
    ),
    const CNSidebarSection(
      title: 'Smart Mailboxes',
      items: [
        CNSidebarItem(title: 'Today', sfSymbol: CNSymbol('calendar')),
        CNSidebarItem(
          title: 'Attachments',
          customIcon: CupertinoIcons.paperclip,
        ),
      ],
    ),
    const CNSidebarSection(
      title: 'iCloud',
      items: [
        CNSidebarItem(title: 'Archive', sfSymbol: CNSymbol('archivebox')),
        CNSidebarItem(title: 'Trash', sfSymbol: CNSymbol('trash')),
      ],
    ),
  ];

  static const _railItems = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Home',
      icon: CNSymbol('house'),
      activeIcon: CNSymbol('house.fill'),
    ),
    CNTabBarItem(label: 'Photos', icon: CNSymbol('photo'), badge: '2'),
    CNTabBarItem(label: 'Music', icon: CNSymbol('music.note')),
    CNTabBarItem(label: 'Settings', icon: CNSymbol('gear')),
  ];

  String get _title {
    var i = _selected;
    for (final section in _sections) {
      if (i < section.items.length) return section.items[i].title;
      i -= section.items.length;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Sidebar')),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _view,
                onValueChanged: (v) => setState(() => _view = v ?? 0),
                children: const {
                  0: Text('CNSidebar'),
                  1: Text('CNTabRail'),
                  2: Text('CNTabScaffold'),
                },
              ),
            ),
            Expanded(
              child: switch (_view) {
                1 => _rails(context),
                2 => _scaffold(context),
                _ => _sidebar(context),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    final label = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
          child: SizedBox(
            width: _iconsOnly ? CNTabRail.railWidth : CNSidebar.width,
            child: CNSidebar(
              sections: _sections,
              selectedIndex: _selected,
              iconsOnly: _iconsOnly,
              semanticLabel: 'Mailboxes',
              onSelected: (i) => setState(() => _selected = i),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Row $_selected selected', style: TextStyle(color: label)),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () => setState(() => _unread++),
                child: const Text('New mail (badge +1)'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                onPressed: () => setState(() => _unread = 0),
                child: const Text('Mark all read'),
              ),
              CupertinoButton(
                onPressed: () =>
                    setState(() => _selected = (_selected + 1) % 7),
                child: const Text('Select the next row'),
              ),
              Row(
                children: [
                  const Expanded(child: Text('Icons only')),
                  CupertinoSwitch(
                    value: _iconsOnly,
                    onChanged: (v) => setState(() => _iconsOnly = v),
                  ),
                ],
              ),
              if (defaultTargetPlatform != TargetPlatform.macOS) ...[
                const SizedBox(height: 12),
                Text(
                  'iOS has no standalone sidebar: CNSidebar draws a '
                  'CNTabRail, without the section headers.',
                  style: TextStyle(color: label, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _rails(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        CNTabRail(
          items: _railItems,
          currentIndex: _railIndex,
          onTap: (i) => setState(() => _railIndex = i),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 360,
          child: CNTabRail(
            items: _railItems,
            currentIndex: _railIndex,
            style: CNTabRailStyle.sidebar,
            onTap: (i) => setState(() => _railIndex = i),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _railItems[_railIndex].label!,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scaffold(BuildContext context) {
    return CNFoldableScope(
      child: CNTabScaffold(
        items: _railItems,
        currentIndex: _scaffoldIndex,
        onTap: (i) => setState(() => _scaffoldIndex = i),
        sidebarOnWideScreens: true,
        body: Center(
          child: Text(
            _railItems[_scaffoldIndex].label!,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
