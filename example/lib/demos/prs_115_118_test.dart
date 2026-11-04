import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #115: `CNTabBar` drops split, font and icon size changes made in the
/// same rebuild as a badge change.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/115
/// By @yagizdo.
///
/// ### The claim
///
/// When the badges change, the tab bar sends only the badges and returns,
/// so a split, label font or icon size change in the same `setState` never
/// reaches the native bar.
///
/// ### How this screen proves it
///
/// Every 2 s one `setState` bumps the Inbox badge together with one more
/// change: split on, then a 16 pt label font, then 30 pt icons. The caption
/// says what the bar should show.
///
///  * **Bug present:** only the badge counts change; the bar never splits
///    and its labels and icons keep their size.
///  * **Fixed:** after step 1 Search sits apart on the right, after step 2
///    the labels are larger, after step 3 the icons are larger.
class Pr115TabBarBadgeSyncPage extends StatefulWidget {
  const Pr115TabBarBadgeSyncPage({super.key});

  @override
  State<Pr115TabBarBadgeSyncPage> createState() =>
      _Pr115TabBarBadgeSyncPageState();
}

class _Pr115TabBarBadgeSyncPageState extends State<Pr115TabBarBadgeSyncPage> {
  int _step = 0;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (_step >= 3) return t.cancel();
      setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final split = _step >= 1;
    final font = _step >= 2 ? 16.0 : null;
    final iconSize = _step >= 3 ? 30.0 : null;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#115 badge + props'),
      ),
      child: Column(
        children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Step $_step · badge $_step · split ${split ? 'on' : 'off'} · '
              'font ${font?.toInt() ?? 'default'} · icons '
              '${iconSize?.toInt() ?? 'default'}',
              textAlign: TextAlign.center,
            ),
          ),
          SafeArea(
            top: false,
            child: CNTabBar(
              items: [
                const CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
                const CNTabBarItem(
                  label: 'Library',
                  icon: CNSymbol('books.vertical.fill'),
                ),
                CNTabBarItem(
                  label: 'Inbox',
                  icon: const CNSymbol('tray.fill'),
                  badge: _step == 0 ? null : '$_step',
                ),
                const CNTabBarItem(
                  label: 'Search',
                  icon: CNSymbol('magnifyingglass'),
                ),
              ],
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              split: split,
              rightCount: 1,
              labelFontSize: font,
              iconSize: iconSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// PR #116: the `CNSearchBar` fallback overflows any parent narrower than
/// the screen.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/116
/// By @yagizdo.
///
/// ### The claim
///
/// Below iOS 26 the fallback sizes the bar to the screen width, so in a
/// padded list, column or row it overflows, and with Cancel shown the
/// Cancel button sits off screen.
///
/// ### How this screen proves it
///
/// Run below iOS 26, or with `FALLBACK=true`, in a debug build. Three
/// expanded bars with Cancel, in a `ListView` with 16 px padding, a padded
/// `Column` and a padded `Row` with `Expanded`.
///
///  * **Bug present:** yellow and black overflow stripes on the right of
///    each bar, and no Cancel.
///  * **Fixed:** no stripes; each bar ends 16 px from the edge with Cancel
///    beside it.
class Pr116SearchBarWidthPage extends StatelessWidget {
  const Pr116SearchBarWidthPage({super.key});

  Widget _bar() => const CNSearchBar(
    placeholder: 'Search',
    expandable: true,
    initiallyExpanded: true,
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#116 search bar width'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('In a ListView with 16 px padding'),
            const SizedBox(height: 8),
            _bar(),
            const SizedBox(height: 32),
            const Text('In a padded Column'),
            const SizedBox(height: 8),
            Column(children: [_bar()]),
            const SizedBox(height: 32),
            const Text('In a padded Row, Expanded'),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: _bar())]),
          ],
        ),
      ),
    );
  }
}

/// PR #117: an uncoloured `CNIcon` is drawn black, whatever the theme.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/117
/// By @yagizdo.
///
/// ### The claim
///
/// Without a colour the native icon view draws black, which a dark theme
/// hides. Below iOS 26 every `CNButton` with an SF Symbol draws its icon
/// this way.
///
/// ### How this screen proves it
///
/// The page switches its own theme between light and dark every 2 s. The
/// first three icons have no colour, the fourth is pink, the fifth is
/// hierarchical.
///
///  * **Bug present:** on the dark page the first three icons are black,
///    almost invisible.
///  * **Fixed:** they are white on the dark page and black on the light
///    one; the pink icon stays pink.
class Pr117IconDefaultColorPage extends StatefulWidget {
  const Pr117IconDefaultColorPage({super.key});

  @override
  State<Pr117IconDefaultColorPage> createState() =>
      _Pr117IconDefaultColorPageState();
}

class _Pr117IconDefaultColorPageState extends State<Pr117IconDefaultColorPage> {
  bool _dark = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => setState(() => _dark = !_dark),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: _dark ? Brightness.dark : Brightness.light,
      ),
      child: Builder(
        builder: (context) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text('#117 icon colour · ${_dark ? 'dark' : 'light'}'),
          ),
          child: const Center(
            child: Wrap(
              spacing: 24,
              children: [
                CNIcon(symbol: CNSymbol('heart.fill'), size: 36),
                CNIcon(symbol: CNSymbol('star.fill'), size: 36),
                CNIcon(symbol: CNSymbol('bell.fill'), size: 36),
                CNIcon(
                  symbol: CNSymbol('heart.fill'),
                  size: 36,
                  color: CupertinoColors.systemPink,
                ),
                CNIcon(
                  symbol: CNSymbol('cloud.sun.fill'),
                  size: 36,
                  mode: CNSymbolRenderingMode.hierarchical,
                  color: CupertinoColors.systemBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PR #118: modals, pickers and the segmented fallback follow the theme.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/118
/// By @yagizdo.
///
/// ### The claim
///
///  * In an app that follows the system, an open `CNAlert` or
///    `CNActionSheet` keeps the old look when the system appearance
///    changes, and so do an open colour picker and compact date popover.
///  * The `CNSegmentedControl` fallback draws white segments on a dark
///    page.
///
/// ### How this screen proves it
///
/// Run with `BRIGHTNESS=system` (the theme sets no brightness). Open the
/// alert, the colour picker or the date popover, then switch the phone to
/// Dark Mode (`xcrun simctl ui <udid> appearance dark`). For the segmented
/// control, run with `FALLBACK=true` and `BRIGHTNESS=dark`.
///
///  * **Bug present:** the open alert, picker or popover stays light; the
///    fallback segments are white on the dark page.
///  * **Fixed:** they turn dark with the system; the segments are dark.
class Pr118ThemeFollowPage extends StatefulWidget {
  const Pr118ThemeFollowPage({super.key, this.openAlert = false});

  /// Opens the alert on the first frame, for headless runs.
  final bool openAlert;

  @override
  State<Pr118ThemeFollowPage> createState() => _Pr118ThemeFollowPageState();
}

class _Pr118ThemeFollowPageState extends State<Pr118ThemeFollowPage> {
  Color _color = CupertinoColors.systemTeal;
  DateTime _date = DateTime(2026, 11, 4, 9, 41);
  int _segment = 0;

  @override
  void initState() {
    super.initState();
    if (widget.openAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _alert());
    }
  }

  void _alert() => CNAlert.show<String>(
    context: context,
    title: 'Follows the system?',
    message: 'Switch the phone to Dark Mode while this is open.',
    actions: const [CNAlertAction(label: 'OK', isCancel: true)],
  );

  void _sheet() => CNActionSheet.show<String>(
    context: context,
    title: 'Follows the system?',
    actions: const [CNActionSheetAction(label: 'Share', value: 'share')],
    cancelLabel: 'Cancel',
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#118 theme follow'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CupertinoButton.filled(
              onPressed: _alert,
              child: const Text('Alert'),
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              onPressed: _sheet,
              child: const Text('Action sheet'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Text('Colour well')),
                CNColorWell(
                  color: _color,
                  onChanged: (c) => setState(() => _color = c),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Date')),
                CNDatePicker(
                  value: _date,
                  style: CNDatePickerStyle.compact,
                  onChanged: (d) => setState(() => _date = d),
                ),
              ],
            ),
            const SizedBox(height: 24),
            CNSegmentedControl(
              labels: const ['Day', 'Week', 'Month'],
              selectedIndex: _segment,
              onValueChanged: (i) => setState(() => _segment = i),
            ),
          ],
        ),
      ),
    );
  }
}
