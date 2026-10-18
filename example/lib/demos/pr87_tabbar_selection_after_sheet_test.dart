import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Issue #86 verification (PR #87, resubmitted as #91) — `CNTabBar`
/// highlights the wrong tab after a sheet closes.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/91
/// (resubmission of #87; on device neither removes the visible slide or the
/// truncated labels, see the PR thread)
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/86
/// Reported and contributed by @TjarkGomollaDev.
///
/// ### The claim
///
/// While a sheet is up `CNTabBar` destroys its native view, and recreates it
/// when the sheet closes. `_onCreated` then sends `setSelectedIndex` +
/// `refresh` at +50 ms and again at +200 ms. Each native `refresh` remembers
/// the selected item, steps the selection through every tab (10 ms apart, to
/// force label layout) and restores the remembered item. If the first cycle
/// is still running when the second starts, the second remembers an item from
/// the middle of the first and restores *that*, so the bar highlights a
/// different tab than `currentIndex`. The delegate is detached during a
/// cycle, so `onTap` never fires and Dart never notices. Timing-dependent;
/// more items make a cycle longer and an overlap likelier.
///
/// ### How this screen proves it
///
/// The bar has five items and starts on the last one. *Start* runs a loop
/// that opens a sheet, closes it, then pauses so you can look at the bar —
/// ten times. The large label above the bar names the tab that **should** be
/// highlighted; the native highlight cannot be read from Dart, so the
/// comparison is by eye (a screen recording makes it easy to step through).
///
///  * **Bug present:** after at least one cycle the highlighted tab is not
///    the one the label names — typically one in the middle — while the label
///    and `onTap ×0` stay unchanged.
///  * **Bug fixed:** across several runs, with both sheet types, the
///    highlight always returns to the named tab.
///
/// Because it is timing-dependent, one clean run on `main` proves nothing:
/// do at least three runs per sheet type, and try a middle tab too (tap it
/// before *Start*). It only applies to the native iOS 26 bar; the readout's
/// last field must say `native`.
///
/// ### The direct trigger (no sheet, close to deterministic)
///
/// *Direct ×2* skips the sheet and sends exactly what `_onCreated` sends —
/// `setSelectedIndex` + `refresh`, twice — straight to the bar's native
/// channel (`CupertinoNativeTabBar_<viewId>`, found through the bar's
/// `RenderUiKitView`; the page only calls `invokeMethod` on it and never
/// replaces the bar's own handler), with the gap picked next to the button.
/// From reading the code, on `main`:
///
///  * gap `0` — no overlap: the second `refresh` runs before the first has
///    stepped, so both remember the right tab. Expected correct.
///  * gap `20`/`40` ms — the second starts while the first is stepping
///    (five items × 10 ms): expected **wrong tab** most of the time.
///  * gap `150` ms — the first has finished: expected correct.
///
/// With the PR applied every gap must leave the named tab highlighted in
/// `single`. `split` (`rightCount: 1`) is offered because the review found
/// that the PR guards only the single-bar path — split is expected to stay
/// broken, possibly with a tab highlighted on each half.
///
/// After the PR, also check that all five labels are still drawn after every
/// recreate (best at a larger system Text Size): the PR drops the second
/// refresh while the first runs, and that second pass exists for Issue #6's
/// missing labels (see also #60).
class Pr87TabBarSelectionAfterSheetTestPage extends StatefulWidget {
  const Pr87TabBarSelectionAfterSheetTestPage({super.key});

  @override
  State<Pr87TabBarSelectionAfterSheetTestPage> createState() =>
      _Pr87TabBarSelectionAfterSheetTestPageState();
}

enum _SheetKind { bottom, cupertino }

class _Pr87TabBarSelectionAfterSheetTestPageState
    extends State<Pr87TabBarSelectionAfterSheetTestPage> {
  static const int _cycles = 10;

  /// How long each sheet stays up, and how long the loop pauses on the
  /// recreated bar before the next cycle — long enough for both refresh
  /// cycles (+50 ms, +200 ms) to finish and for you to look.
  static const Duration _sheetUp = Duration(milliseconds: 700);
  static const Duration _observe = Duration(milliseconds: 1800);

  static const List<String> _labels = <String>[
    'Home',
    'Library',
    'Chat',
    'Alerts',
    'Profile',
  ];

  static const List<CNTabBarItem> _items = <CNTabBarItem>[
    CNTabBarItem(
      label: 'Home',
      icon: CNSymbol('house'),
      activeIcon: CNSymbol('house.fill'),
    ),
    CNTabBarItem(
      label: 'Library',
      icon: CNSymbol('books.vertical'),
      activeIcon: CNSymbol('books.vertical.fill'),
    ),
    CNTabBarItem(
      label: 'Chat',
      icon: CNSymbol('bubble.left'),
      activeIcon: CNSymbol('bubble.left.fill'),
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

  int _tabIndex = 4;
  bool _split = false;
  int _gapMs = 40;
  int _directRuns = 0;
  final GlobalKey _barKey = GlobalKey();
  int _taps = 0;
  _SheetKind _kind = _SheetKind.bottom;

  bool _running = false;
  int _cycle = 0;
  String _phase = 'idle';

  /// Context of the sheet currently up, so the loop can close it.
  BuildContext? _sheetContext;

  @override
  void dispose() {
    _running = false;
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) {
      setState(() => _running = false);
      return;
    }
    setState(() {
      _running = true;
      _cycle = 0;
    });
    for (int i = 1; i <= _cycles; i++) {
      if (!mounted || !_running) break;
      setState(() {
        _cycle = i;
        _phase = 'sheet up';
      });
      final Future<void> closed = _openSheet();
      await Future<void>.delayed(_sheetUp);
      final BuildContext? sheet = _sheetContext;
      if (sheet != null && sheet.mounted) Navigator.of(sheet).pop();
      await closed;
      _sheetContext = null;
      if (!mounted) return;
      setState(() => _phase = 'look at the bar');
      await Future<void>.delayed(_observe);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _phase = 'done';
    });
  }

  /// The bar's native view id, read from the `RenderUiKitView` in its
  /// subtree, or null while the Flutter fallback is showing.
  int? _nativeViewId() {
    final BuildContext? barContext = _barKey.currentContext;
    if (barContext is! Element) return null;
    int? id;
    void visit(Element element) {
      if (id != null) return;
      final RenderObject? render = element.renderObject;
      if (render is RenderUiKitView) {
        id = render.viewController.id;
        return;
      }
      element.visitChildElements(visit);
    }

    visit(barContext);
    return id;
  }

  /// Sends what `_onCreated` sends after a recreate — `setSelectedIndex` +
  /// `refresh`, twice — [_gapMs] apart, straight to the bar's channel. Only
  /// `invokeMethod` is used; a handler set here would replace `CNTabBar`'s.
  Future<void> _directDoubleRefresh() async {
    final int? id = _nativeViewId();
    if (id == null) {
      setState(() => _phase = 'no native view yet');
      return;
    }
    final MethodChannel channel = MethodChannel('CupertinoNativeTabBar_$id');
    String? failure;
    // Each pass catches its own errors: the first one runs unobserved while
    // the gap elapses.
    Future<void> pass() async {
      try {
        await channel.invokeMethod<void>('setSelectedIndex', <String, int>{
          'index': _tabIndex,
        });
        await channel.invokeMethod<void>('refresh');
      } on PlatformException catch (e) {
        failure = e.code;
      } on MissingPluginException {
        failure = 'no channel';
      }
    }

    setState(() {
      _directRuns++;
      _phase = 'direct #$_directRuns, ${_gapMs}ms gap — look at the bar';
    });
    final Future<void> first = pass();
    await Future<void>.delayed(Duration(milliseconds: _gapMs));
    await Future.wait(<Future<void>>[first, pass()]);
    if (failure != null && mounted) {
      setState(() => _phase = 'direct failed: $failure');
    }
  }

  Future<void> _openSheet() {
    Widget body(BuildContext ctx) {
      _sheetContext = ctx;
      return SizedBox(
        height: 260,
        child: Center(
          child: Text(
            'Cycle $_cycle of $_cycles — closing by itself',
            style: const TextStyle(fontSize: 17),
          ),
        ),
      );
    }

    switch (_kind) {
      case _SheetKind.bottom:
        return CNBottomSheet.show<void>(context: context, builder: body);
      case _SheetKind.cupertino:
        return CNBottomSheet.showCupertino<void>(
          context: context,
          pageBuilder: (BuildContext ctx) =>
              CupertinoPageScaffold(child: body(ctx)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#86 · selection after sheet'),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _controls(),
                  const Spacer(),
                  _expected(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CNTabBar(
                key: _barKey,
                items: _items,
                split: _split,
                rightCount: 1,
                currentIndex: _tabIndex,
                onTap: (int i) => setState(() {
                  _tabIndex = i;
                  _taps++;
                }),
                tint: CupertinoColors.systemBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The tab that must be highlighted, big enough to compare at a glance.
  Widget _expected() {
    return Column(
      children: <Widget>[
        Text(
          'highlight should be on',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_labels[_tabIndex]}  ↓',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ],
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
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Bug: after a cycle the highlight is not on the tab named below, '
            'while onTap stays ×0. Sheet loop is timing-dependent (3+ runs '
            'per type). Direct ×2 at 20–40 ms should show it almost every '
            'time on main; 0 and 150 ms should not.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: CupertinoSegmentedControl<_SheetKind>(
                  groupValue: _kind,
                  onValueChanged: (_SheetKind v) {
                    if (!_running) setState(() => _kind = v);
                  },
                  children: const <_SheetKind, Widget>{
                    _SheetKind.bottom: Text(
                      'bottom sheet',
                      style: TextStyle(fontSize: 12),
                    ),
                    _SheetKind.cupertino: Text(
                      'cupertino sheet',
                      style: TextStyle(fontSize: 12),
                    ),
                  },
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                onPressed: _start,
                child: Text(
                  _running ? 'Stop' : 'Start',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              CupertinoSegmentedControl<bool>(
                groupValue: _split,
                onValueChanged: (bool v) {
                  if (!_running) setState(() => _split = v);
                },
                children: const <bool, Widget>{
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('single', style: TextStyle(fontSize: 12)),
                  ),
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('split', style: TextStyle(fontSize: 12)),
                  ),
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoSegmentedControl<int>(
                  groupValue: _gapMs,
                  onValueChanged: (int v) => setState(() => _gapMs = v),
                  children: const <int, Widget>{
                    0: Text('0', style: TextStyle(fontSize: 12)),
                    20: Text('20', style: TextStyle(fontSize: 12)),
                    40: Text('40', style: TextStyle(fontSize: 12)),
                    150: Text('150', style: TextStyle(fontSize: 12)),
                  },
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                onPressed: _running ? null : _directDoubleRefresh,
                child: const Text('Direct ×2', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_split ? 'split' : 'single'} · gap ${_gapMs}ms · '
            'cycle $_cycle/$_cycles · $_phase · '
            'currentIndex $_tabIndex (${_labels[_tabIndex]}) · '
            'onTap ×$_taps · $backend',
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
}
