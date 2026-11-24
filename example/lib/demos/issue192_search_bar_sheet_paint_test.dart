import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, FilledButton, Material, showModalBottomSheet;

/// Issue #192: sheet content below a focused `CNSearchBar` isn't painted.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/192
/// Reported by @FaaizParacha, narrowed down by @Ashhad08 (PR #193).
///
/// ### The claim
///
/// A sheet holds a glass close button, a `CNSearchBar`, and a Flutter button
/// below the bar. When the bar takes the focus and the keyboard comes up,
/// the button below it is no longer painted (it still takes taps). It
/// happens only when the page under the sheet has a `CNTabBar` with
/// `autoHideOnModal: false` **and** one more live CN view.
///
/// ### How this screen proves it
///
/// A `CNTabScaffold` with a `CNTabBar` holds a page with a
/// `CNSegmentedControl`, a `CNSwitch` and a `CNPopupMenuButton` near the top.
/// The sheet has a close button, an open `CNSearchBar`, a **red 30 pt bar**
/// and a Save button, inside a `Padding` with the keyboard inset. The
/// switches at the top of the page set the tab bar's and the host views'
/// `autoHideOnModal`, turn the host views off, and choose a Material bottom
/// sheet or a Cupertino sheet. AUTO opens the sheet, focuses the bar,
/// prints `CNB_RECT192` with the red bar's and Save's rects and
/// `CNB_SHOT 192-<step>`, then closes the keyboard and the sheet.
///
///  * **Bug:** with the keyboard up, the red bar and Save are gone; the
///    sheet is white there.
///  * **Fixed:** the red bar and Save stay painted above the keyboard, and
///    the tab bar is still there under the sheet once the keyboard is down.
class Issue192SearchBarSheetPaintTestPage extends StatefulWidget {
  /// Creates the #192 test page.
  const Issue192SearchBarSheetPaintTestPage({
    super.key,
    this.autoCycle = false,
    this.tabBarHides = false,
    this.hostHides = false,
    this.hostViews = true,
    this.tabBar = true,
    this.cupertinoSheet = false,
    this.clipDialog = false,
    this.form = false,
    this.autofocus = false,
    this.maxLength,
    this.stay = false,
  });

  /// Opens the sheet, focuses the bar and prints the steps.
  final bool autoCycle;

  /// The tab bar's `autoHideOnModal`.
  final bool tabBarHides;

  /// The host views' `autoHideOnModal`.
  final bool hostHides;

  /// Whether the page shows the native host views.
  final bool hostViews;

  /// Whether the page has a native tab bar.
  final bool tabBar;

  /// A Cupertino sheet instead of a Material bottom sheet.
  final bool cupertinoSheet;

  /// Clips the dialog card to its rounded corners.
  final bool clipDialog;

  /// Adds a row with a live `CNSwitch` at the end of the sheet and of the
  /// dialog, so the red bars come between two native views.
  final bool form;

  /// The search bar's `autofocus`; AUTO then doesn't focus it itself.
  final bool autofocus;

  /// The search bar's `maxLength`.
  final int? maxLength;

  /// AUTO stops with the keyboard up, for typing into the bar.
  final bool stay;

  @override
  State<Issue192SearchBarSheetPaintTestPage> createState() =>
      _Issue192SearchBarSheetPaintTestPageState();
}

class _Issue192SearchBarSheetPaintTestPageState
    extends State<Issue192SearchBarSheetPaintTestPage> {
  late bool _tabBarHides = widget.tabBarHides;
  late bool _hostHides = widget.hostHides;
  late bool _hostViews = widget.hostViews;
  late bool _tabBar = widget.tabBar;
  late bool _cupertinoSheet = widget.cupertinoSheet;
  int _tab = 0;
  int _segment = 0;
  bool _alerts = true;
  int _saves = 0;

  final _search = CNSearchBarController();
  final _markerKey = GlobalKey();
  final _saveKey = GlobalKey();
  final _tabBarKey = GlobalKey();
  final _dialogMarkerKey = GlobalKey();

  static const _items = [
    CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
    CNTabBarItem(label: 'Search', icon: CNSymbol('magnifyingglass')),
    CNTabBarItem(label: 'Saved', icon: CNSymbol('heart')),
    CNTabBarItem(label: 'More', icon: CNSymbol('ellipsis')),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) Future.delayed(const Duration(seconds: 4), _auto);
  }

  void _printRect(String name, GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) {
      debugPrint('CNB_RECT192 $name none');
      return;
    }
    final r = box.localToGlobal(Offset.zero) & box.size;
    String f(double v) => v.toStringAsFixed(1);
    debugPrint(
      'CNB_RECT192 $name ${f(r.left)} ${f(r.top)} ${f(r.right)} '
      '${f(r.bottom)}',
    );
  }

  Future<void> _auto() async {
    debugPrint(
      'CNB_192 tabBar=$_tabBar tabBarHides=$_tabBarHides '
      'hostViews=$_hostViews hostHides=$_hostHides '
      'sheet=${_cupertinoSheet ? 'cupertino' : 'material'} '
      'clip=${widget.clipDialog} form=${widget.form} '
      'autofocus=${widget.autofocus} maxLength=${widget.maxLength}',
    );
    _printRect('tabbar', _tabBarKey);
    debugPrint('CNB_SHOT 192-page');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    _openSheet();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _printRect('marker-closed', _markerKey);
    _printRect('save-closed', _saveKey);
    debugPrint('CNB_SHOT 192-sheet');
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    // With `autofocus` the bar takes the focus by itself as the sheet opens.
    if (!widget.autofocus) _search.focus();
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    _printRect('marker', _markerKey);
    _printRect('save', _saveKey);
    debugPrint('CNB_SHOT 192-keyboard');
    if (widget.stay) return;
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    _search.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 192-keyboard-down');
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _printRect('tabbar', _tabBarKey);
    debugPrint('CNB_SHOT 192-closed');
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    _openDialog();
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    _printRect('dialog-marker', _dialogMarkerKey);
    debugPrint('CNB_SHOT 192-dialog');
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    debugPrint('CNB_SHOT 192-done');
  }

  /// A dialog with a glass button and a red bar below it: no keyboard, no
  /// search bar.
  void _openDialog() {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: _clip(
          Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: CNButton(
                    label: 'Glass button',
                    autoHideOnModal: false,
                    onPressed: () => Navigator.pop(context),
                    config: const CNButtonConfig(style: CNButtonStyle.glass),
                  ),
                ),
                const SizedBox(height: 16),
                Container(key: _dialogMarkerKey, height: 30, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Text below the button',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF000000)),
                ),
                if (widget.form) _formRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The dialog card, in a rounded clip with [Issue192SearchBarSheetPaintTestPage.clipDialog].
  Widget _clip(Widget card) => widget.clipDialog
      ? ClipRRect(borderRadius: BorderRadius.circular(20), child: card)
      : card;

  void _openSheet() {
    if (_cupertinoSheet) {
      showCupertinoSheet<void>(
        context: context,
        scrollableBuilder: (_, _) => Material(
          color: Colors.white,
          child: Align(alignment: Alignment.topCenter, child: _sheet()),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (_) => _sheet(),
      );
    }
  }

  Widget _sheet() {
    return Builder(
      builder: (context) => Padding(
        // The keyboard inset: the sheet's content sits above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Rename',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CNButton.icon(
                      autoHideOnModal: false,
                      icon: const CNSymbol('xmark', size: 17),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: CNSearchBar(
                controller: _search,
                expandable: false,
                initiallyExpanded: true,
                autoHideOnModal: false,
                showCancelButton: false,
                initialText: 'Porsche 911',
                autofocus: widget.autofocus,
                maxLength: widget.maxLength,
                placeholder: 'Name',
              ),
            ),
            const SizedBox(height: 20),
            // Anything painted here vanishes while the keyboard is up.
            Container(key: _markerKey, height: 30, color: Colors.red),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilledButton(
                key: _saveKey,
                onPressed: () {
                  setState(() => _saves++);
                  debugPrint('CNB_192 save tapped $_saves');
                },
                child: const Text('Save'),
              ),
            ),
            if (widget.form) _formRow(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// A row with a live `CNSwitch` after the content, so the red bar and
  /// Save come between two native views
  /// ([Issue192SearchBarSheetPaintTestPage.form]).
  Widget _formRow() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      children: [
        const Expanded(
          child: Text('Notify me', style: TextStyle(color: Color(0xFF000000))),
        ),
        CNSwitch(
          value: _alerts,
          autoHideOnModal: false,
          onChanged: (v) => setState(() => _alerts = v),
        ),
      ],
    ),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF000000)),
          ),
        ),
        CupertinoSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _page() {
    return ColoredBox(
      color: const Color(0xFFF2F2F7),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            const Text(
              '#192 Sheet under a focused search bar',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 10),
            if (_hostViews) ...[
              SizedBox(
                height: 36,
                child: CNSegmentedControl(
                  key: ValueKey('seg$_hostHides'),
                  autoHideOnModal: _hostHides,
                  labels: const ['Ads', 'Searches'],
                  selectedIndex: _segment,
                  onValueChanged: (i) => setState(() => _segment = i),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Alerts for this search',
                      style: TextStyle(color: Color(0xFF000000)),
                    ),
                  ),
                  CNSwitch(
                    key: ValueKey('sw$_hostHides'),
                    autoHideOnModal: _hostHides,
                    value: _alerts,
                    onChanged: (v) => setState(() => _alerts = v),
                  ),
                  const SizedBox(width: 8),
                  CNPopupMenuButton.icon(
                    key: ValueKey('pop$_hostHides'),
                    autoHideOnModal: _hostHides,
                    buttonIcon: const CNSymbol('ellipsis.circle'),
                    size: 32,
                    buttonStyle: CNButtonStyle.plain,
                    items: const [CNPopupMenuItem(label: 'Rename')],
                    onSelected: (_) => _openSheet(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            _toggle('Tab bar', _tabBar, (v) => setState(() => _tabBar = v)),
            _toggle(
              'Tab bar autoHideOnModal',
              _tabBarHides,
              (v) => setState(() => _tabBarHides = v),
            ),
            _toggle(
              'Host CN views',
              _hostViews,
              (v) => setState(() => _hostViews = v),
            ),
            _toggle(
              'Host views autoHideOnModal',
              _hostHides,
              (v) => setState(() => _hostHides = v),
            ),
            _toggle(
              'Cupertino sheet',
              _cupertinoSheet,
              (v) => setState(() => _cupertinoSheet = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton.filled(
                    onPressed: _openSheet,
                    child: const Text('Open sheet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoButton.filled(
                    onPressed: _openDialog,
                    child: const Text('Open dialog'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Save taps: $_saves',
              style: const TextStyle(color: Color(0xFF3C3C43)),
            ),
            for (var i = 0; i < 12; i++)
              Container(
                height: 52,
                margin: const EdgeInsets.only(top: 8),
                color: const Color(0xFFFFFFFF),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Row $i',
                  style: const TextStyle(color: Color(0xFF000000)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_tabBar) return _page();
    return CNTabScaffold(
      items: _items,
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      body: _page(),
      tabBarBuilder: (context) => KeyedSubtree(
        key: _tabBarKey,
        child: CNTabBar(
          key: ValueKey('tab$_tabBarHides'),
          items: _items,
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          autoHideOnPageTransition: false,
          autoHideOnModal: _tabBarHides,
        ),
      ),
    );
  }
}
