import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Demo for `CNToolbar`.
///
/// macOS: the window gets a native toolbar while this page is open, with
/// every item kind: navigational Back and Forward, a prominent Compose
/// button with a badge, a view-mode group, filter toggles, a Sort menu,
/// a search field, and the sidebar items (shown only while the window has
/// a sidebar). The window title and subtitle are the toolbar's. The controls
/// on the page change the items, which update in place; leaving the page
/// gives the window its own toolbar and title back.
///
/// iOS 26+: the same items as a Liquid Glass `UIToolbar` at the bottom of
/// the page (search and the sidebar items have no iOS counterpart).
class ToolbarDemoPage extends StatefulWidget {
  const ToolbarDemoPage({super.key, this.autoScenario});

  /// When set, the page starts in a state for screenshot runs:
  /// - `cycle`: changes the items every 1.5 s (badge, selection, an added
  ///   and removed button, the prominent style), to watch in-place updates.
  /// - `search`: puts "Invoices" in the search field through its controller.
  /// - `compact` / `expanded`: the other toolbar styles.
  /// - `plain`: the toolbar without badge, filters or prominent style.
  /// - `relayout`: the view group gets a segment while there is a query, so
  ///   the window rebuilds that group while the user types in the search
  ///   field (which keeps the keyboard).
  final String? autoScenario;

  @override
  State<ToolbarDemoPage> createState() => _ToolbarDemoPageState();
}

class _ToolbarDemoPageState extends State<ToolbarDemoPage> {
  final CNTabBarSearchController _search = CNTabBarSearchController();
  CNToolbarStyle _style = CNToolbarStyle.unified;
  bool _showsTitle = true;
  bool _prominent = true;
  bool _extraButton = true;
  bool _filters = true;
  bool _columnsEnabled = true;
  int _badge = 3;
  int _viewMode = 0;
  Set<int> _filterSelection = {0};
  String _sort = 'Date';
  bool _ascending = false;
  String _query = '';
  final List<String> _log = <String>[];
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    switch (widget.autoScenario) {
      case 'cycle':
        _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
          if (!mounted) return;
          setState(() {
            _tick++;
            _badge = (_badge + 1) % 6;
            _viewMode = (_viewMode + 1) % 3;
            _extraButton = _tick.isEven;
            _prominent = _tick % 3 != 0;
            _filterSelection = {_tick % 3};
            _columnsEnabled = _tick.isEven;
            if (!_columnsEnabled && _viewMode == 2) _viewMode = 0;
          });
          _record('cycle $_tick');
        });
      case 'search':
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          _search.text = 'Invoices';
        });
      case 'compact':
        _style = CNToolbarStyle.unifiedCompact;
      case 'expanded':
        _style = CNToolbarStyle.expanded;
      case 'plain':
        _prominent = false;
        _badge = 0;
        _filters = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _record(String what) {
    debugPrint('CNB_RESULT $what');
    if (!mounted) return;
    setState(() {
      _log.insert(0, what);
      if (_log.length > 8) _log.removeLast();
    });
  }

  /// Every item kind. An iPhone is too narrow for all of them (the rest
  /// would go to the toolbar's overflow menu), so there Back, Forward, the
  /// filters and Flag are left out.
  List<CNToolbarItem> _items({required bool wide}) => [
    const CNToolbarSidebarToggle(),
    const CNToolbarSidebarTrackingSeparator(),
    if (wide) ...[
      CNToolbarButton(
        id: 'back',
        label: 'Back',
        icon: const CNSymbol('chevron.left'),
        isNavigational: true,
        onPressed: () => _record('Back'),
      ),
      CNToolbarButton(
        id: 'forward',
        label: 'Forward',
        icon: const CNSymbol('chevron.right'),
        isNavigational: true,
        enabled: false,
        onPressed: () => _record('Forward'),
      ),
    ],
    CNToolbarSegmentedGroup(
      id: 'view',
      label: 'View',
      segments: [
        const CNToolbarSegment(
          label: 'List',
          icon: CNSymbol('list.bullet'),
          tooltip: 'Show as list',
        ),
        if (widget.autoScenario == 'relayout' && _query.isNotEmpty)
          const CNToolbarSegment(
            label: 'Results',
            icon: CNSymbol('magnifyingglass'),
          ),
        const CNToolbarSegment(
          label: 'Grid',
          icon: CNSymbol('square.grid.2x2'),
          tooltip: 'Show as grid',
        ),
        CNToolbarSegment(
          label: 'Columns',
          icon: const CNSymbol('rectangle.split.3x1'),
          tooltip: 'Show in columns',
          enabled: _columnsEnabled,
        ),
      ],
      selectedIndices: {_viewMode},
      onSelected: (i) {
        setState(() => _viewMode = i);
        _record('View $i');
      },
    ),
    if (_filters && wide)
      CNToolbarSegmentedGroup(
        id: 'filters',
        label: 'Filters',
        selectionMode: CNToolbarSelectionMode.selectAny,
        segments: const [
          CNToolbarSegment(label: 'Unread', icon: CNSymbol('envelope.badge')),
          CNToolbarSegment(label: 'Flagged', icon: CNSymbol('flag')),
          CNToolbarSegment(label: 'Files', icon: CNSymbol('paperclip')),
        ],
        selectedIndices: _filterSelection,
        onSelectionChanged: (s) {
          setState(() => _filterSelection = s);
          _record('Filters ${(s.toList()..sort())}');
        },
      ),
    const CNToolbarSpace.flexible(),
    CNToolbarMenu(
      id: 'sort',
      label: 'Sort',
      icon: const CNSymbol('arrow.up.arrow.down'),
      tooltip: 'Sort messages',
      items: [
        for (final key in const ['Date', 'Sender', 'Subject'])
          CNPopupMenuItem(
            label: key,
            checked: _sort == key,
            icon: CNSymbol(switch (key) {
              'Date' => 'calendar',
              'Sender' => 'person',
              _ => 'textformat',
            }, size: 16),
          ),
        const CNPopupMenuDivider(),
        CNPopupMenuItem(label: 'Ascending', checked: _ascending),
        CNPopupMenuItem(label: 'Descending', checked: !_ascending),
        const CNPopupMenuDivider(),
        const CNPopupMenuSubmenu(
          label: 'Group by',
          icon: CNSymbol('square.stack.3d.up', size: 16),
          items: [
            CNPopupMenuItem(label: 'Conversation'),
            CNPopupMenuItem(label: 'Day'),
          ],
        ),
      ],
      onSelected: (path) {
        const sorts = ['Date', 'Sender', 'Subject'];
        setState(() {
          if (path.first < 3) _sort = sorts[path.first];
          if (path.first == 4) _ascending = true;
          if (path.first == 5) _ascending = false;
        });
        _record('Sort $path');
      },
    ),
    if (_extraButton && wide)
      CNToolbarButton(
        id: 'flag',
        label: 'Flag',
        icon: const CNSymbol('flag'),
        tooltip: 'Flag the message',
        onPressed: () => _record('Flag'),
      ),
    CNToolbarButton(
      id: 'compose',
      label: 'New Message',
      icon: const CNSymbol('square.and.pencil'),
      tooltip: 'Write a new message',
      style: _prominent
          ? CNToolbarItemStyle.prominent
          : CNToolbarItemStyle.plain,
      badge: _badge > 0 ? CNToolbarBadge.count(_badge) : null,
      onPressed: () {
        setState(() => _badge = 0);
        _record('New Message');
      },
    ),
    // Appears while there is a query: the toolbar changes while the user
    // types, and the search field keeps the keyboard.
    if (_query.isNotEmpty && wide)
      CNToolbarButton(
        id: 'save',
        label: 'Save Search',
        icon: const CNSymbol('bookmark'),
        onPressed: () => _record('Save Search "$_query"'),
      ),
    CNToolbarSearch(
      id: 'search',
      placeholder: 'Search mail',
      controller: _search,
      onChanged: (text) {
        setState(() => _query = text);
        _record('Search "$text"');
      },
      onSubmitted: (text) => _record('Submit "$text"'),
      onActiveChanged: (active) => _record('Search active $active'),
    ),
  ];

  Widget _row(String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        control,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final wide = mac || MediaQuery.sizeOf(context).width >= 600;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final toolbar = CNToolbar(
      title: 'Inbox',
      subtitle: _badge > 0 ? '$_badge unread' : 'All read',
      showsTitle: _showsTitle,
      style: _style,
      items: _items(wide: wide),
    );
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Toolbar')),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Text(
                    mac
                        ? 'This page puts a native toolbar on the window. '
                              'Change the items below: they update in place.'
                        : 'A native toolbar sits at the bottom of the page. '
                              'Change the items below: they update in place.',
                    style: TextStyle(color: secondary),
                  ),
                  const SizedBox(height: 12),
                  if (mac)
                    _row(
                      'Style',
                      SizedBox(
                        width: 260,
                        child: CNSegmentedControl(
                          labels: const ['Unified', 'Compact', 'Expanded'],
                          selectedIndex: _style.index,
                          onValueChanged: (i) =>
                              setState(() => _style = CNToolbarStyle.values[i]),
                        ),
                      ),
                    ),
                  if (mac)
                    _row(
                      'Window title',
                      CNSwitch(
                        value: _showsTitle,
                        onChanged: (v) => setState(() => _showsTitle = v),
                      ),
                    ),
                  _row(
                    'Prominent New Message',
                    CNSwitch(
                      value: _prominent,
                      onChanged: (v) => setState(() => _prominent = v),
                    ),
                  ),
                  if (wide)
                    _row(
                      'Flag button',
                      CNSwitch(
                        value: _extraButton,
                        onChanged: (v) => setState(() => _extraButton = v),
                      ),
                    ),
                  if (wide)
                    _row(
                      'Filter toggles',
                      CNSwitch(
                        value: _filters,
                        onChanged: (v) => setState(() => _filters = v),
                      ),
                    ),
                  _row(
                    'Badge: $_badge',
                    CNStepper(
                      value: _badge.toDouble(),
                      min: 0,
                      max: 99,
                      onChanged: (v) => setState(() => _badge = v.round()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'View: $_viewMode · '
                    'Sort: $_sort ${_ascending ? '↑' : '↓'}'
                    '${mac ? ' · Search: "$_query"' : ''}',
                  ),
                  const SizedBox(height: 16),
                  Text('Events', style: TextStyle(color: secondary)),
                  for (final line in _log)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(line),
                    ),
                ],
              ),
            ),
            toolbar,
          ],
        ),
      ),
    );
  }
}
