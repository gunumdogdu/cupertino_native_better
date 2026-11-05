import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Demo for `CNPopover`.
///
/// Buttons sit at the corners, the middle and the bottom of the page, each
/// opening a native popover on the side of the button that has room:
/// `NSPopover` on macOS, a UIKit popover on iPhone and iPad (it stays a
/// popover on iPhone), with Liquid Glass on macOS 26 and iOS 26. The content
/// is native: a choice list with a checkmark, switches that report changes
/// while the popover stays open, buttons (default, cancel, destructive), and
/// rows with symbols, subtitles and trailing text. The grey area opens a
/// popover at the point that was tapped, through an explicit `anchorRect`.
class PopoverDemoPage extends StatefulWidget {
  const PopoverDemoPage({super.key, this.autoScenario});

  /// When set, the named scenario runs on the first frame instead of
  /// waiting for a tap, for screenshot runs without tap automation:
  /// `sort`, `view`, `details`, `leading`, `delete`, `account` or `rect`
  /// opens that popover; `tour` opens each in turn and then checks closing
  /// from code, replacing, updating, a route pushed over the page and the
  /// page popped. Prints `CNB_SHOT <name>` while each popover is up and
  /// `CNB_RESULT <what>` for every result.
  final String? autoScenario;

  @override
  State<PopoverDemoPage> createState() => _PopoverDemoPageState();
}

class _PopoverDemoPageState extends State<PopoverDemoPage> {
  final GlobalKey _sortKey = GlobalKey();
  final GlobalKey _viewKey = GlobalKey();
  final GlobalKey _leadingKey = GlobalKey();
  final GlobalKey _detailsKey = GlobalKey();
  final GlobalKey _deleteKey = GlobalKey();
  final GlobalKey _accountKey = GlobalKey();
  final GlobalKey _areaKey = GlobalKey();

  String _sort = 'date';
  bool _foldersOnTop = true;
  bool _showHidden = false;
  bool _preview = true;
  String _lastResult = '—';
  final List<String> _toggleLog = [];

  @override
  void initState() {
    super.initState();
    final scenario = widget.autoScenario;
    if (scenario == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      if (scenario == 'tour') {
        await _tour();
      } else {
        unawaited(_open(scenario));
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        debugPrint('CNB_SHOT $scenario');
      }
    });
  }

  void _record(String what) {
    debugPrint('CNB_RESULT $what');
    if (!mounted) return;
    setState(() => _lastResult = what);
  }

  void _onToggle(String id, bool value) {
    debugPrint('CNB_RESULT toggle $id=$value');
    if (!mounted) return;
    setState(() {
      switch (id) {
        case 'folders':
          _foldersOnTop = value;
        case 'hidden':
          _showHidden = value;
        case 'preview':
          _preview = value;
      }
      _toggleLog.insert(0, '$id → ${value ? 'on' : 'off'}');
      if (_toggleLog.length > 4) _toggleLog.removeLast();
    });
  }

  // MARK: Popovers

  Future<void> _open(String name) async {
    switch (name) {
      case 'sort':
        return _showSort();
      case 'view':
        return _showView();
      case 'details':
        return _showDetails();
      case 'leading':
        return _showLeading();
      case 'delete':
        return _showDelete();
      case 'account':
        return _showAccount();
      case 'rect':
        final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        return _showAtPoint(
          box.localToGlobal(box.size.center(Offset.zero) + const Offset(60, 0)),
        );
    }
  }

  /// A choice list: the current choice carries a checkmark, a tap closes
  /// the popover and returns the row's id.
  Future<void> _showSort() async {
    const options = [
      ('name', 'Name', 'textformat'),
      ('kind', 'Kind', 'square.grid.2x2'),
      ('date', 'Date Modified', 'calendar'),
      ('size', 'Size', 'externaldrive'),
    ];
    final id = await CNPopover.show(
      context: context,
      anchorKey: _sortKey,
      content: CNPopoverContent(
        title: 'Sort By',
        rows: [
          for (final (id, label, symbol) in options)
            CNPopoverRow(
              id: id,
              item: CNListItem(title: label, leadingSymbol: CNSymbol(symbol)),
              checked: id == _sort,
            ),
        ],
      ),
    );
    _record('sort → ${id ?? 'null'}');
    if (id != null && mounted) setState(() => _sort = id);
  }

  /// Switches that stay open and report each change, and buttons.
  Future<void> _showView() async {
    final id = await CNPopover.show(
      context: context,
      anchorKey: _viewKey,
      content: _viewContent(),
      onToggleChanged: _onToggle,
    );
    _record('view → ${id ?? 'null'}');
  }

  CNPopoverContent _viewContent({String? message}) => CNPopoverContent(
    title: 'View Options',
    message: message,
    toggles: [
      CNPopoverToggle(
        id: 'folders',
        label: 'Folders on top',
        value: _foldersOnTop,
        symbol: const CNSymbol('folder'),
      ),
      CNPopoverToggle(
        id: 'hidden',
        label: 'Show hidden files',
        subtitle: 'Names starting with a dot',
        value: _showHidden,
        symbol: const CNSymbol('eye'),
      ),
      CNPopoverToggle(
        id: 'preview',
        label: 'Show preview',
        value: _preview,
        symbol: const CNSymbol('sidebar.right'),
      ),
    ],
    actions: const [
      CNPopoverAction.cancel(label: 'Cancel'),
      CNPopoverAction(
        id: 'apply',
        label: 'Apply',
        style: CNPopoverActionStyle.defaultAction,
      ),
    ],
  );

  /// Everything at once, from the middle of the page, on the trailing side.
  Future<void> _showDetails() async {
    final id = await CNPopover.show(
      context: context,
      anchorKey: _detailsKey,
      preferredEdge: CNPopoverEdge.trailing,
      content: CNPopoverContent(
        title: 'Project.pages',
        message: 'Edited today at 09:41 by you.',
        rows: const [
          CNPopoverRow(
            id: 'open',
            item: CNListItem(
              title: 'Open',
              leadingSymbol: CNSymbol('arrow.up.forward.app'),
            ),
          ),
          CNPopoverRow(
            id: 'versions',
            item: CNListItem(
              title: 'Browse versions',
              subtitle: '12 saved versions',
              leadingSymbol: CNSymbol('clock.arrow.circlepath'),
              showChevron: true,
            ),
          ),
          CNPopoverRow(
            id: 'size',
            item: CNListItem(
              title: 'Size',
              leadingSymbol: CNSymbol('internaldrive'),
              trailingText: '2.4 MB',
            ),
            enabled: false,
          ),
        ],
        toggles: [
          CNPopoverToggle(
            id: 'preview',
            label: 'Show preview',
            value: _preview,
          ),
        ],
        actions: const [
          CNPopoverAction(
            id: 'share',
            label: 'Share',
            style: CNPopoverActionStyle.defaultAction,
          ),
        ],
      ),
      onToggleChanged: _onToggle,
    );
    _record('details → ${id ?? 'null'}');
  }

  /// A short list on the leading side of its button.
  Future<void> _showLeading() async {
    final id = await CNPopover.show(
      context: context,
      anchorKey: _leadingKey,
      preferredEdge: CNPopoverEdge.leading,
      content: const CNPopoverContent(
        rows: [
          CNPopoverRow(
            id: 'copy',
            item: CNListItem(
              title: 'Copy',
              leadingSymbol: CNSymbol('doc.on.doc'),
            ),
          ),
          CNPopoverRow(
            id: 'duplicate',
            item: CNListItem(
              title: 'Duplicate',
              leadingSymbol: CNSymbol('plus.square.on.square'),
            ),
          ),
          CNPopoverRow(
            id: 'rename',
            item: CNListItem(
              title: 'Rename',
              leadingSymbol: CNSymbol('pencil'),
            ),
          ),
        ],
      ),
    );
    _record('leading → ${id ?? 'null'}');
  }

  /// A confirmation above a button at the bottom: a title, a message and a
  /// destructive button.
  Future<void> _showDelete() async {
    final id = await CNPopover.show(
      context: context,
      anchorKey: _deleteKey,
      preferredEdge: CNPopoverEdge.top,
      content: const CNPopoverContent(
        title: 'Delete 3 items?',
        message:
            'They will be moved to the Trash. You can restore them '
            'for 30 days.',
        actions: [
          CNPopoverAction.cancel(label: 'Cancel'),
          CNPopoverAction(
            id: 'delete',
            label: 'Delete',
            style: CNPopoverActionStyle.destructive,
          ),
        ],
      ),
    );
    _record('delete → ${id ?? 'null'}');
  }

  /// Rows with subtitles and trailing text above a button at the bottom.
  Future<void> _showAccount() async {
    final id = await CNPopover.show(
      context: context,
      anchorKey: _accountKey,
      preferredEdge: CNPopoverEdge.top,
      content: const CNPopoverContent(
        title: 'Signed in as Alex',
        rows: [
          CNPopoverRow(
            id: 'profile',
            item: CNListItem(
              title: 'Profile',
              subtitle: 'Name, photo, email',
              leadingSymbol: CNSymbol('person.crop.circle'),
            ),
          ),
          CNPopoverRow(
            id: 'storage',
            item: CNListItem(
              title: 'Storage',
              leadingSymbol: CNSymbol('icloud'),
              trailingText: '42 GB',
            ),
          ),
          CNPopoverRow(
            id: 'signout',
            item: CNListItem(
              title: 'Sign Out',
              leadingSymbol: CNSymbol('rectangle.portrait.and.arrow.right'),
            ),
          ),
        ],
      ),
    );
    _record('account → ${id ?? 'null'}');
  }

  /// A popover at a point, through an explicit anchor rect.
  Future<void> _showAtPoint(Offset point) async {
    final id = await CNPopover.show(
      context: context,
      anchorRect: Rect.fromCenter(center: point, width: 4, height: 4),
      content: CNPopoverContent(
        title: 'Point',
        message:
            '${point.dx.toStringAsFixed(0)}, ${point.dy.toStringAsFixed(0)}',
        rows: const [
          CNPopoverRow(
            id: 'pin',
            item: CNListItem(
              title: 'Drop a pin',
              leadingSymbol: CNSymbol('pin'),
            ),
          ),
        ],
      ),
    );
    _record('rect → ${id ?? 'null'}');
  }

  // MARK: Probe

  /// Every popover in turn, then the ways a popover closes from code.
  Future<void> _tour() async {
    Future<void> wait(int ms) =>
        Future<void>.delayed(Duration(milliseconds: ms));
    for (final name in const [
      'sort',
      'view',
      'details',
      'leading',
      'delete',
      'account',
      'rect',
    ]) {
      if (!mounted) return;
      unawaited(_open(name));
      await wait(1300);
      debugPrint('CNB_SHOT $name');
      await wait(2000);
      await CNPopover.dismiss();
      await wait(700);
    }

    // A second show while one is open: the first returns null.
    unawaited(_showSort());
    await wait(900);
    unawaited(_showView());
    await wait(1300);
    debugPrint('CNB_SHOT replaced');
    await wait(2000);
    await CNPopover.dismiss();
    await wait(700);

    // update() while open: a message appears and a switch flips.
    unawaited(_showView());
    await wait(1100);
    _showHidden = !_showHidden;
    await CNPopover.update(
      _viewContent(message: 'Updated from Dart while open.'),
    );
    await wait(1100);
    debugPrint('CNB_SHOT updated');
    await wait(2000);
    await CNPopover.dismiss();
    await wait(700);

    // A route pushed over the page closes the popover.
    if (!mounted) return;
    unawaited(_showSort());
    await wait(1000);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(middle: Text('Pushed')),
            child: Center(child: Text('The popover closed.')),
          ),
        ),
      ),
    );
    await wait(1200);
    debugPrint('CNB_RESULT shown after push: ${CNPopover.isShown}');
    debugPrint('CNB_SHOT pushed');
    await wait(2000);
    if (!mounted) return;
    Navigator.of(context).pop();
    await wait(900);

    // macOS, through real AppKit events: a click on the Sort button (with
    // the debug-only `cnb_mac_audit` channel of the example's
    // MainFlutterWindow.swift, which posts the events to the app's own
    // queue and never moves the cursor), Escape, a click outside, a row and
    // a switch pressed through the accessibility API (CNB_AXPRESS, done by
    // the script), and Return for the default button.
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _click(_sortKey);
      await wait(1200);
      debugPrint('CNB_RESULT shown after click: ${CNPopover.isShown}');
      debugPrint('CNB_FOCUS');
      debugPrint('CNB_SHOT clicked');
      await wait(2000);
      await _key(53);
      await wait(1200);
      debugPrint('CNB_RESULT shown after escape: ${CNPopover.isShown}');

      await _click(_viewKey);
      await wait(1200);
      final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final p = box.localToGlobal(box.size.center(Offset.zero));
        await _audit('click', {'x': p.dx, 'y': p.dy - 140});
      }
      await wait(1200);
      debugPrint('CNB_RESULT shown after click outside: ${CNPopover.isShown}');

      await _click(_sortKey);
      await wait(1200);
      debugPrint('CNB_AXPRESS Size');
      await wait(2000);

      await _click(_viewKey);
      await wait(1200);
      debugPrint('CNB_AXPRESS Show hidden files');
      await wait(1500);
      debugPrint('CNB_SHOT toggled');
      await wait(2000);
      await _key(36);
      await wait(1500);
      debugPrint('CNB_RESULT shown after return: ${CNPopover.isShown}');
    }

    // The page popped while its popover is open.
    if (!mounted) return;
    unawaited(_showDelete());
    await wait(1000);
    if (!mounted) return;
    Navigator.of(context).pop();
    await wait(1200);
    debugPrint('CNB_RESULT shown after pop: ${CNPopover.isShown}');
    debugPrint('CNB_DONE');
  }

  static const MethodChannel _auditChannel = MethodChannel('cnb_mac_audit');

  Future<void> _audit(String method, Map<String, Object> args) async {
    try {
      await _auditChannel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      debugPrint('CNB_RESULT no audit channel (release build?)');
    }
  }

  /// Clicks the centre of [key]'s widget with an AppKit click.
  Future<void> _click(GlobalKey key) async {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final p = box.localToGlobal(box.size.center(Offset.zero));
    await _audit('click', {'x': p.dx, 'y': p.dy});
  }

  /// Presses a key (a virtual key code) in the app's key window.
  Future<void> _key(int code) => _audit('key', {'keyCode': code});

  // MARK: Layout

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Popover')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CNButton(key: _sortKey, label: 'Sort', onPressed: _showSort),
                  const Spacer(),
                  CNButton(key: _viewKey, label: 'View', onPressed: _showView),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last result: $_lastResult',
                      style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sort: $_sort · folders on top: $_foldersOnTop · '
                      'hidden: $_showHidden · preview: $_preview',
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                    if (_toggleLog.isNotEmpty)
                      Text(
                        'Switches: ${_toggleLog.join(', ')}',
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CNButton(
                    key: _leadingKey,
                    label: 'Leading',
                    onPressed: _showLeading,
                  ),
                  const SizedBox(width: 16),
                  CNButton(
                    key: _detailsKey,
                    label: 'Details',
                    onPressed: _showDetails,
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                key: _areaKey,
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _showAtPoint(d.globalPosition),
                child: Container(
                  height: 90,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tap anywhere here: a popover at that point '
                    '(anchorRect)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CNButton(
                    key: _deleteKey,
                    label: 'Delete',
                    onPressed: _showDelete,
                  ),
                  const Spacer(),
                  CNButton(
                    key: _accountKey,
                    label: 'Account',
                    onPressed: _showAccount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
