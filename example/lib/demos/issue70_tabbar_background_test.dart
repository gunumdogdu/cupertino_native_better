import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #70 reproduction — `CNTabBar.backgroundColor` never reaches the
/// native bar.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/70
/// Reported by @dolapobabs.
///
/// ### The claim
///
/// Passing `backgroundColor` to `CNTabBar` (the reporter uses
/// `tint: primaryColor, backgroundColor: Colors.white`) shows the colour only
/// briefly during the initial Flutter render; once the native tab bar
/// platform view mounts, the bar returns to the default system appearance and
/// the colour is gone.
///
/// Root cause, in one sentence: the native view applies the colour through the
/// legacy `UITabBar.barTintColor` while also assigning a transparent
/// `UITabBarAppearance` from `makeAppearance()`, and on iOS 13+ an assigned
/// appearance wins, so the colour is silently discarded.
///
/// ### How this screen proves it
///
/// The page is near-black and a list of dark rows scrolls *under* the bar, so
/// an opaque white bar and a translucent glass bar cannot be confused. The
/// verdict is the **settled** bar, not any flash on the way in:
///
///  * **Bug present:** once the bar has settled it is the system glass bar,
///    dark rows showing through, even though `backgroundColor` is white. (A
///    brief white bar before that is only the Flutter fallback, drawn until
///    the platform view exists; whether you see it at all depends on timing,
///    so do not judge by it.) Tapping *Colour* changes nothing — that is the
///    `setStyle` half of the same bug.
///  * **Bug fixed:** the settled bar is opaque white, and *Colour* recolours
///    it live (white → yellow → green) without a remount.
///
/// The readout's last field says whether the bar on screen is the `native`
/// platform view or the Flutter `fallback` (iOS < 26, or any other reason
/// `PlatformVersion.shouldUseNativeGlass` is false). The fallback bar honours
/// `backgroundColor` on its own, so a `fallback` readout proves nothing about
/// this issue.
///
/// The `none` scenario is the control: an identical bar created with no
/// `backgroundColor`, i.e. what glass is supposed to look like on this page.
/// `split` and `search` exercise the other native layouts, where a solid
/// colour makes the bar's real rect (and the split gap) visible. *Remount*
/// recreates the native view with whatever colour is current.
///
/// ### Sheet and Popup — the Issue #2 shadow check and the modal round-trip
///
/// *Popup* presents a `showCupertinoModalPopup`-style action sheet. That route
/// is deliberately excluded from `CNTabBarRouteObserver`'s narrow hide
/// heuristic, so in `white`, `none` and `split` the coloured bar **stays
/// mounted** under the popup and relies on the Swift `clipsToBounds`
/// containment from the Issue #2 fix: no tab-bar shadow or hairline may bleed
/// over the popup's top edge, coloured bar or not. This is the only check on
/// this page that can catch an opaque-appearance regression of #2. In
/// `search` the bar listens to the broad `anyModalDepth` counter and hides
/// under the popup too, so the check is meaningful for the other three only.
///
/// *Sheet* presents a `showModalBottomSheet` route, which matches the narrow
/// heuristic: `CNTabBar` **destroys** the native view in every scenario while
/// the sheet is up and recreates it on dismiss from its cached creation
/// params. Only `selectedIndex` is refreshed in those params, so a colour
/// applied later through `setStyle` (the *Colour* button) would be lost on
/// the recreate while the package still believes it was sent. To keep the
/// readout truthful this page bumps the mount counter when the sheet (or, in
/// `search`, the popup) closes, so the bar is keyed fresh with the current
/// colour. Fix author: the Dart side needs the same refresh as
/// `selectedIndex` — set `_creationParams!['style']['backgroundColor']` from
/// `widget.backgroundColor` next to the `selectedIndex` refresh in
/// `tab_bar.dart`, otherwise a Swift-only fix still loses `setStyle` colours
/// after every sheet.
class Issue70TabBarBackgroundTestPage extends StatefulWidget {
  const Issue70TabBarBackgroundTestPage({super.key});

  @override
  State<Issue70TabBarBackgroundTestPage> createState() =>
      _Issue70TabBarBackgroundTestPageState();
}

class _Issue70TabBarBackgroundTestPageState
    extends State<Issue70TabBarBackgroundTestPage> {
  static const Color _pageBackground = Color(0xFF101418);
  static const Color _rowEven = Color(0xFF1C2128);
  static const Color _rowOdd = Color(0xFF161B22);
  static const int _rowCount = 40;

  /// Scenario → the `backgroundColor` a fresh bar is created with.
  static const Map<String, Color?> _scenarioColour = <String, Color?>{
    'white': CupertinoColors.white,
    'none': null,
    'split': CupertinoColors.systemRed,
    'search': CupertinoColors.white,
  };

  /// The *Colour* button walks this list, starting from its head when the
  /// current colour is not in it (`none`, `split`).
  static const List<Color> _cycle = <Color>[
    CupertinoColors.white,
    CupertinoColors.systemYellow,
    CupertinoColors.systemGreen,
  ];

  static const List<CNTabBarItem> _items = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Home',
      icon: CNSymbol('house'),
      activeIcon: CNSymbol('house.fill'),
    ),
    CNTabBarItem(
      label: 'Search',
      icon: CNSymbol('magnifyingglass'),
      activeIcon: CNSymbol('magnifyingglass'),
    ),
    CNTabBarItem(
      label: 'Alerts',
      icon: CNSymbol('bell'),
      activeIcon: CNSymbol('bell.fill'),
    ),
    CNTabBarItem(
      label: 'Profile',
      icon: CNSymbol('person'),
      activeIcon: CNSymbol('person.fill'),
    ),
  ];

  String _scenario = 'white';

  /// Colour pushed through `setStyle` on top of the scenario's creation-time
  /// colour. Null means "whatever the bar was created with".
  Color? _override;

  /// Part of the bar's key. Bumped on every remount and scenario change, and
  /// after any modal round-trip that made `CNTabBar` destroy and recreate the
  /// native view (see the class doc), so `mount #N` in the readout counts
  /// native views truthfully and the recreated bar is created with the
  /// current [_colour] rather than the stale cached creation params.
  int _epoch = 1;

  int _tabIndex = 0;

  Color? get _colour => _override ?? _scenarioColour[_scenario];

  /// Whether the bar listens to the broad `anyModalDepth` counter, i.e. hides
  /// under popup-type routes too (the search variant does).
  bool get _hidesUnderPopup => _scenario == 'search';

  void _selectScenario(String scenario) {
    setState(() {
      _scenario = scenario;
      _override = null;
      _epoch++;
    });
  }

  void _nextColour() {
    final Color? current = _colour;
    final int i = current == null ? -1 : _cycle.indexOf(current);
    setState(() => _override = _cycle[(i + 1) % _cycle.length]);
  }

  void _remount() => setState(() => _epoch++);

  void _showSheet() {
    CNBottomSheet.show<void>(
      context: context,
      builder: (BuildContext ctx) => SizedBox(
        height: 320,
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 16),
              const Text(
                'Modal round-trip',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'The native bar is destroyed while this sheet is up. On '
                  'Dismiss it is recreated with the colour in the readout '
                  'and the mount counter goes up by one.',
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Dismiss'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ).whenComplete(_onModalRoundTrip);
  }

  void _showPopup() {
    CNBottomSheet.showModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Issue #2 check'),
        message: Text(
          _hidesUnderPopup
              ? 'In the search scenario the bar hides under popups too, so '
                    'there is nothing to check here; use white, none or '
                    'split.'
              : 'The coloured bar is still mounted under this popup. No '
                    'tab-bar shadow or hairline may bleed over the top edge '
                    'of this popup.',
        ),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Dismiss'),
        ),
      ),
    ).whenComplete(() {
      if (_hidesUnderPopup) _onModalRoundTrip();
    });
  }

  /// The route that just closed made `CNTabBar` destroy and recreate its
  /// native view; key the bar fresh so it is created with [_colour] and the
  /// readout's mount counter stays honest.
  void _onModalRoundTrip() {
    if (mounted) setState(() => _epoch++);
  }

  static String _colourName(Color? c) {
    if (c == null) return 'none';
    if (c == CupertinoColors.white) return 'white';
    if (c == CupertinoColors.systemYellow) return 'yellow';
    if (c == CupertinoColors.systemGreen) return 'green';
    if (c == CupertinoColors.systemRed) return 'red';
    return '#${c.toARGB32().toRadixString(16)}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _pageBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#70 · tab bar background'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _controls(),
                  Expanded(child: _rows()),
                ],
              ),
            ),
          ),
          // Same placement as the other Stack-based tab bar test pages: the
          // rows above extend to the screen bottom and scroll under the bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: _tabBar()),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return CNTabBar(
      // A new key per scenario / remount / modal round-trip forces a fresh
      // native view, so the creation-time params path is exercised; the
      // Colour button keeps the key and goes through setStyle instead.
      key: ValueKey<String>('$_scenario#$_epoch'),
      items: _items,
      currentIndex: _tabIndex,
      onTap: (int i) => setState(() => _tabIndex = i),
      tint: CupertinoColors.systemBlue,
      backgroundColor: _colour,
      split: _scenario == 'split',
      searchItem: _scenario == 'search'
          ? const CNTabBarSearchItem(placeholder: 'Search')
          : null,
    );
  }

  Widget _rows() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 140),
      itemCount: _rowCount,
      itemBuilder: (BuildContext context, int i) => Container(
        height: 44,
        color: i.isEven ? _rowEven : _rowOdd,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          'Row ${i + 1}',
          style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
        ),
      ),
    );
  }

  Widget _controls() {
    final String backend = PlatformVersion.shouldUseNativeGlass
        ? 'native'
        : 'fallback';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Bug: once the bar has settled it is the system glass bar even '
            'though backgroundColor is white (a brief white bar before that '
            'is just the Flutter fallback). Fixed: the settled bar is opaque '
            'white and Colour recolours it live.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoSegmentedControl<String>(
              groupValue: _scenario,
              onValueChanged: _selectScenario,
              children: <String, Widget>{
                for (final String s in _scenarioColour.keys)
                  s: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(s, style: const TextStyle(fontSize: 12)),
                  ),
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _button('Colour', _nextColour),
              const SizedBox(width: 8),
              _button('Remount', _remount),
              const SizedBox(width: 8),
              _button('Sheet', _showSheet),
              const SizedBox(width: 8),
              _button('Popup', _showPopup),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$_scenario · colour: ${_colourName(_colour)} · mount #$_epoch '
            '· $backend',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.white,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
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
