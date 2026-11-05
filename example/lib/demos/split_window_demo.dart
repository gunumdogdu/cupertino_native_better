import 'dart:async';
import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Mac window's split view: [CNTabBarNative] as the window's sidebar and
/// [CNNativeSheet] as its inspector, alone or together, around this Flutter
/// page, which keeps working between them: type in the text field, scroll
/// the list, right-click the card.
///
/// On iOS the same switches present the native tab bar and the native sheet.
class SplitWindowDemoPage extends StatefulWidget {
  const SplitWindowDemoPage({super.key, this.autoScenario});

  /// A scenario that runs on its own for screenshot runs on macOS (debug
  /// builds, through the example's `cnb_mac_audit` channel): `sidebar`,
  /// `inspector`, `both`, `search`, `checks` (typing, scrolling and a right
  /// click with both shown; `plain` without them), `toggle` (the View
  /// menu's Show Sidebar), `stress` (on and off many times), `resize`,
  /// `restart` (prints `CNB_RESTART` for the driver to hot restart, then
  /// checks that the left-over sidebar is replaced) and `fullscreen`.
  final String? autoScenario;

  @override
  State<SplitWindowDemoPage> createState() => _SplitWindowDemoPageState();
}

class _SplitWindowDemoPageState extends State<SplitWindowDemoPage> {
  static const MethodChannel _audit = MethodChannel('cnb_mac_audit');

  bool _sidebar = false;
  bool _inspector = false;
  bool _dismissible = true;
  int _tab = 0;
  int _page = 0;
  String _query = '';
  String _menu = '—';
  final List<String> _log = [];
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  double _offset = 0;

  static const _tabs = <CNTab>[
    CNTab(
      title: 'Home',
      sfSymbol: CNSymbol('house'),
      activeSfSymbol: CNSymbol('house.fill'),
    ),
    CNTab(
      title: 'Inbox',
      sfSymbol: CNSymbol('tray'),
      badgeCount: 3,
      nativeList: CNNativeList(
        items: [
          CNListItem(
            title: 'Weekly sync',
            subtitle: 'Agenda for Thursday',
            leadingSymbol: CNSymbol('calendar'),
            showChevron: true,
          ),
          CNListItem(
            title: 'Design review',
            subtitle: 'Sidebar and inspector',
            leadingSymbol: CNSymbol('paintbrush'),
            showChevron: true,
          ),
          CNListItem(
            title: 'Release notes',
            subtitle: 'Draft for 2.3.0',
            leadingSymbol: CNSymbol('doc.text'),
            showChevron: true,
          ),
        ],
      ),
    ),
    CNTab(title: 'Library', sfSymbol: CNSymbol('books.vertical')),
    CNTab(
      title: 'Search',
      isSearchTab: true,
      nativeList: CNNativeList(
        items: [
          CNListItem(
            title: 'Settings',
            subtitle: 'Preferences',
            leadingSymbol: CNSymbol('gear'),
          ),
          CNListItem(
            title: 'Sidebar',
            subtitle: 'Window layout',
            leadingSymbol: CNSymbol('sidebar.left'),
          ),
          CNListItem(
            title: 'Inspector',
            subtitle: 'Window layout',
            leadingSymbol: CNSymbol('sidebar.right'),
          ),
        ],
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => setState(() => _offset = _scroll.offset));
    final scenario = widget.autoScenario;
    if (scenario != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(scenario));
    }
  }

  @override
  void dispose() {
    CNTabBarNative.disable();
    CNNativeSheet.dismiss();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _addLog(String entry) {
    debugPrint('CNB_EVENT $entry');
    if (!mounted) return;
    setState(() {
      _log.insert(0, entry);
      if (_log.length > 30) _log.removeLast();
    });
  }

  /// The app's brightness: its theme's, or the system's when the theme
  /// sets none.
  bool get _isDark => CupertinoTheme.brightnessOf(context) == Brightness.dark;

  Future<void> _setSidebar(bool on) async {
    if (on) {
      await CNTabBarNative.enable(
        tabs: _tabs,
        selectedIndex: _tab,
        isDark: _isDark,
        asRoot: true,
        showCloseButton: false,
        onTabSelected: (i) {
          _addLog('onTabSelected($i)');
          setState(() => _tab = i);
        },
        onListItemTap: (t, i) => _addLog('onListItemTap($t, $i)'),
        onSearchChanged: (q) {
          _addLog('onSearchChanged("$q")');
          setState(() => _query = q);
        },
        onDismissed: () {
          _addLog('sidebar onDismissed');
          setState(() => _sidebar = false);
        },
      );
    } else {
      await CNTabBarNative.disable();
    }
    if (mounted) setState(() => _sidebar = CNTabBarNative.isEnabled);
  }

  Future<void> _setInspector(bool on) async {
    if (on) {
      final shown = await CNNativeSheet.show(
        pages: const [
          CNSheetPage(
            title: 'Details',
            sfSymbol: CNSymbol('info.circle'),
            buttons: [
              CNSheetButton(
                id: 'share',
                sfSymbol: CNSymbol('square.and.arrow.up'),
                label: 'Share',
              ),
              CNSheetButton(
                id: 'add',
                sfSymbol: CNSymbol('plus'),
                label: 'Add',
              ),
            ],
            items: [
              CNListItem(
                title: 'Kind',
                subtitle: 'Flutter window',
                leadingSymbol: CNSymbol('macwindow'),
              ),
              CNListItem(
                title: 'Layout',
                subtitle: 'Sidebar, content, inspector',
                trailingText: '3',
                leadingSymbol: CNSymbol('rectangle.split.3x1'),
              ),
              CNListItem(
                title: 'Updated',
                subtitle: 'Just now',
                leadingSymbol: CNSymbol('clock'),
                showChevron: true,
              ),
            ],
          ),
          CNSheetPage(
            title: 'Activity',
            sfSymbol: CNSymbol('bolt'),
            activeSfSymbol: CNSymbol('bolt.fill'),
            badgeCount: 2,
            items: [
              CNListItem(
                title: 'Sidebar shown',
                subtitle: 'CNTabBarNative',
                leadingSymbol: CNSymbol('sidebar.left'),
              ),
              CNListItem(
                title: 'Inspector shown',
                subtitle: 'CNNativeSheet',
                leadingSymbol: CNSymbol('sidebar.right'),
              ),
            ],
          ),
          CNSheetPage(title: 'Notes', sfSymbol: CNSymbol('note.text')),
        ],
        selectedPage: _page,
        dismissible: _dismissible,
        isDark: _isDark,
        onPageSelected: (p) {
          _addLog('onPageSelected($p)');
          setState(() => _page = p);
        },
        onItemTap: (p, i) => _addLog('onItemTap($p, $i)'),
        onButtonTap: (p, id) => _addLog('onButtonTap($p, $id)'),
        onDismissed: () {
          _addLog('inspector onDismissed');
          setState(() => _inspector = false);
        },
      );
      if (mounted) setState(() => _inspector = shown);
    } else {
      await CNNativeSheet.dismiss();
      if (mounted) setState(() => _inspector = false);
    }
  }

  // ── Scenarios (macOS screenshot runs) ──────────────────────────────────

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Brings the window to the front and makes it key: Flutter draws no
  /// frames while its window is hidden behind others, and AppKit draws a
  /// window in the background in its inactive colours.
  Future<void> _front() async {
    await _audit.invokeMethod<void>('toScreen', <String, double>{
      'x': 0,
      'y': 0,
    });
    await _wait(400);
  }

  /// Asks the driver for a screenshot and gives it time to take it.
  Future<void> _shot(String name) async {
    await _front();
    debugPrint('CNB_SHOT $name');
    await _wait(1800);
  }

  /// A click at a point of the Flutter view; a negative x lands in the
  /// sidebar to its left.
  Future<void> _click(double x, double y, {bool right = false}) =>
      _audit.invokeMethod<void>('click', <String, Object>{
        'x': x,
        'y': y,
        if (right) 'button': 'right',
      });

  /// The centre of [key]'s widget in the Flutter view.
  Offset? _centre(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// Scrolls the page until [key]'s widget is in view.
  Future<void> _reveal(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(context, alignment: 0.5);
    await _wait(300);
  }

  /// The Flutter view's width now.
  double get _width => MediaQuery.sizeOf(context).width;

  /// Milliseconds from [change] to the first frame at a new width.
  Future<int> _timed(Future<void> Function() change) async {
    final before = _width;
    final watch = Stopwatch()..start();
    await change();
    while (mounted && _width == before && watch.elapsedMilliseconds < 3000) {
      await WidgetsBinding.instance.endOfFrame;
      await _wait(1);
    }
    return watch.elapsedMilliseconds;
  }

  void _size(String label) {
    final size = MediaQuery.sizeOf(context);
    debugPrint('CNB_RESULT $label flutter=${size.width}x${size.height}');
  }

  final GlobalKey _fieldKey = GlobalKey();
  final GlobalKey _scrollKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();

  /// Sidebar rows (x, y) in the Flutter view's coordinates: the sidebar is
  /// [MacSplitWindow.sidebarWidth] (220) wide to the left of the Flutter
  /// view, its search field on top, then rows 32 points apart.
  Offset _row(int row) => Offset(-130, 60.0 + row * 32);
  static const Offset _searchField = Offset(-110, 18);

  Future<void> _run(String scenario) async {
    await _wait(1200);
    _size('start');
    switch (scenario) {
      case 'sidebar':
        await _setSidebar(true);
        await _wait(1200);
        _size('sidebar');
        await _shot('sidebar');
        await _click(_row(1).dx, _row(1).dy); // Inbox: a native list
        await _wait(900);
        await _shot('list');
        await _click(_row(2).dx, _row(2).dy); // Library: Flutter again
        await _wait(900);
        await _shot('flutter');
      case 'search':
        await _setSidebar(true);
        await _wait(1200);
        await _click(_searchField.dx, _searchField.dy);
        await _wait(400);
        await _audit.invokeMethod<void>('type', <String, Object>{
          'text': 'side',
        });
        await _wait(1200);
        await _shot('search');
        await CNTabBarNative.deactivateSearch();
        await _wait(900);
        await _shot('cleared');
      case 'inspector':
        await _setInspector(true);
        await _wait(1200);
        _size('inspector');
        await _shot('inspector');
        await CNNativeSheet.setSelectedPage(1);
        await _wait(700);
        await _shot('page2');
      case 'both':
        // How long the window takes to show the split view: the frame after
        // the change must not wait for Flutter's resize timeout (1 s).
        final first = await _timed(() async {
          await _setSidebar(true);
          await _setInspector(true);
        });
        debugPrint('CNB_RESULT split shown in $first ms');
        await _wait(1400);
        // Off, then on again, now that the native views exist.
        final inspectorOff = await _timed(() => _setInspector(false));
        debugPrint('CNB_RESULT inspector off in $inspectorOff ms');
        await _wait(800);
        final sidebarOff = await _timed(() => _setSidebar(false));
        debugPrint('CNB_RESULT sidebar off in $sidebarOff ms');
        await _wait(800);
        _size('off');
        final sidebarOn = await _timed(() => _setSidebar(true));
        debugPrint('CNB_RESULT sidebar shown in $sidebarOn ms');
        await _wait(800);
        final inspectorOn = await _timed(() => _setInspector(true));
        debugPrint('CNB_RESULT inspector shown in $inspectorOn ms');
        await _wait(800);
        _size('both');
        await _shot('both');
        // The accessibility tree, as VoiceOver reads it.
        debugPrint('CNB_AX both');
        await _wait(2500);
      case 'toggle':
        // View > Show Sidebar (Control-Command-S), the standard command the
        // split view adds to the View menu, collapses and restores it.
        await _setSidebar(true);
        await _wait(1200);
        _size('before toggle');
        await _front();
        debugPrint('CNB_TOGGLE');
        await _wait(1800);
        _size('after toggle');
        await _shot('collapsed');
        debugPrint('CNB_AX collapsed');
        await _wait(2000);
        await _front();
        debugPrint('CNB_TOGGLE');
        await _wait(1800);
        _size('toggled back');
        await _shot('expanded');
      case 'checks':
        await _checks();
      case 'plain':
        // The same checks without the split view, for comparison.
        await _checks(split: false, prefix: 'plain_');
      case 'stress':
        await _stress();
      case 'resize':
        await _setSidebar(true);
        await _setInspector(true);
        await _wait(1000);
        for (final (w, h) in [
          (1200.0, 800.0),
          (760.0, 560.0),
          (980.0, 700.0),
        ]) {
          await _audit.invokeMethod<void>('resize', <String, double>{
            'width': w,
            'height': h,
          });
          await _wait(1200);
          _size('resize ${w.toInt()}x${h.toInt()}');
          await _shot('resize${w.toInt()}');
        }
      case 'restart':
        // First run: show both, then ask the driver for a hot restart. The
        // restarted app finds the marker file and the window still split:
        // its Dart side knows nothing of the sidebar and the inspector, and
        // disable() / dismiss() must still remove them.
        final marker = File('${Directory.systemTemp.path}/cnb_split_restart');
        if (!marker.existsSync()) {
          marker.writeAsStringSync('1');
          await _setSidebar(true);
          await _setInspector(true);
          await _wait(1200);
          _size('before restart');
          await _shot('before_restart');
          debugPrint('CNB_RESTART');
          return;
        }
        marker.deleteSync();
        _size('after restart');
        await _shot('after_restart');
        await CNTabBarNative.disable();
        await CNNativeSheet.dismiss();
        await _wait(1000);
        _size('cleaned');
        await _shot('cleaned');
        await _setSidebar(true);
        await _setInspector(true);
        await _wait(1200);
        _size('again');
        await _shot('again');
      case 'fullscreen':
        await _setSidebar(true);
        await _setInspector(true);
        await _wait(1000);
        debugPrint('CNB_FULLSCREEN');
        await _wait(4000);
        _size('fullscreen');
        await _checks(prefix: 'fs_');
        debugPrint('CNB_FULLSCREEN');
        await _wait(3000);
        _size('windowed');
    }
    await _wait(600);
    debugPrint('CNB_DONE');
  }

  Future<void> _checks({String prefix = '', bool split = true}) async {
    if (split && !_sidebar) await _setSidebar(true);
    if (split && !_inspector) await _setInspector(true);
    await _wait(1200);
    // Typing into a Flutter text field after the view moved.
    final field = _centre(_fieldKey);
    if (field != null) {
      await _click(field.dx, field.dy);
      await _wait(500);
      await _audit.invokeMethod<void>('type', <String, Object>{
        'text': 'typed',
      });
      await _wait(800);
    }
    final responder = await _audit.invokeMethod<String>('firstResponder');
    debugPrint('CNB_RESULT ${prefix}text="${_text.text}" responder=$responder');
    // Scrolling: wheel events over the list.
    await _reveal(_scrollKey);
    final list = _centre(_scrollKey);
    if (list != null) {
      await _audit.invokeMethod<void>('scroll', <String, Object>{
        'x': list.dx,
        'y': list.dy,
        'dy': -12,
        'count': 20,
      });
      await _wait(1500);
      debugPrint('CNB_RESULT ${prefix}scroll=${_offset.toStringAsFixed(0)}');
    }
    // A right click opens the native context menu; Down and Return choose
    // its first item.
    await _reveal(_menuKey);
    final card = _centre(_menuKey);
    if (card != null) {
      await _click(card.dx, card.dy, right: true);
      await _wait(1200);
      await _shot('${prefix}menu');
      await _audit.invokeMethod<void>('key', <String, Object>{'keyCode': 125});
      await _audit.invokeMethod<void>('key', <String, Object>{'keyCode': 36});
      await _wait(900);
      debugPrint('CNB_RESULT ${prefix}menu=$_menu');
    }
    await _shot('${prefix}checks');
  }

  Future<void> _stress() async {
    for (var i = 0; i < 12; i++) {
      await _setSidebar(true);
      await _wait(60);
      await _setSidebar(false);
    }
    _size('after sidebar x12');
    for (var i = 0; i < 12; i++) {
      await _setInspector(true);
      await _wait(60);
      await _setInspector(false);
    }
    _size('after inspector x12');
    for (var i = 0; i < 8; i++) {
      await _setSidebar(true);
      await _setInspector(true);
      await _wait(40);
      await _setSidebar(false);
      await _wait(40);
      await _setInspector(false);
    }
    await _wait(800);
    _size('after mixed x8');
    await _shot('off');
    await _setInspector(true);
    await _setSidebar(true);
    await _wait(1200);
    _size('final both');
    await _shot('both');
  }

  // ── Page ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final label = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_sidebar ? _tabs[_tab].title : 'Mac Window'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              mac
                  ? 'The sidebar is CNTabBarNative, the inspector is '
                        'CNNativeSheet: both native parts of this window, '
                        'around this Flutter page. Inbox and Search show '
                        'native lists; Home and Library show this page.'
                  : 'On iOS the switches present the native tab bar and '
                        'the native sheet.',
              style: TextStyle(color: label),
            ),
            const SizedBox(height: 12),
            _switchRow('Sidebar (CNTabBarNative)', _sidebar, _setSidebar),
            _switchRow('Inspector (CNNativeSheet)', _inspector, _setInspector),
            _switchRow(
              'Inspector can be closed',
              _dismissible,
              (v) => setState(() => _dismissible = v),
            ),
            const SizedBox(height: 8),
            Text(
              'Tab $_tab · page $_page · search "$_query"',
              style: TextStyle(color: label, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const Text('Typing', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            CupertinoTextField(
              key: _fieldKey,
              controller: _text,
              placeholder: 'Type here',
            ),
            const SizedBox(height: 16),
            Text(
              'Scrolling (offset ${_offset.toStringAsFixed(0)})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SizedBox(
              key: _scrollKey,
              height: 140,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: 40,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text('Row ${i + 1}'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CNContextMenu(
              key: _menuKey,
              items: const [
                CNPopupMenuItem(label: 'Copy', icon: CNSymbol('doc.on.doc')),
                CNPopupMenuItem(
                  label: 'Share',
                  icon: CNSymbol('square.and.arrow.up'),
                ),
              ],
              onSelected: (path) {
                _addLog('context menu $path');
                setState(() => _menu = path.join('.'));
              },
              child: Container(
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Right-click here (last: $_menu)'),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Events', style: TextStyle(fontWeight: FontWeight.w600)),
            if (_log.isEmpty)
              Text('— no events yet —', style: TextStyle(color: label)),
            for (final entry in _log)
              Text(
                entry,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String text, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
