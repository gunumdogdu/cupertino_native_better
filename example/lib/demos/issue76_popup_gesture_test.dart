import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #76 — `CNPopupGesture` dims the screen on long press but shows no
/// menu until a hot reload; the menu has no glass and ignores SF Symbols.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/76
/// Reported by @dogankarakus.
///
/// ### The claim
///
/// Long-pressing a child wrapped in `CNPopupGesture` shows the dimmed
/// backdrop, but the menu itself appears only after a hot reload. When it
/// does appear it has none of the iOS 26 Liquid Glass that
/// `CNPopupMenuButton`'s menu has, and the items' `icon`s are ignored. The
/// reporter's snippet is the widget's own dartdoc example; it is mirrored
/// below unchanged except for `const` and the `onSelected` body (which still
/// prints `Selected: $index`).
///
/// Reading `lib/components/popup_gesture.dart` explains all three, plus one
/// more the report does not mention:
///
///  1. **Invisible menu.** The menu is a Flutter `showGeneralDialog`, and a
///     `ModalRoute` calls its `pageBuilder` once and caches the result; it
///     is rebuilt only when an inherited dependency changes. The stateless
///     `_CNPopupMenuOverlay` reads `Opacity(opacity: animation.value)` in
///     that single build, on the first frame of the open animation, where
///     the value is 0.0. Nothing rebuilds it as the animation runs, so the
///     menu stays at opacity 0 for as long as the route is up. The barrier
///     and the grey highlight drawn over the child sit outside that
///     `Opacity` — that is the "overlay" the reporter sees. A hot reload
///     rebuilds every element, the builder runs again with the value at
///     1.0, and the menu appears. `Opacity` does not block hit testing, so
///     the invisible items still take taps.
///  2. **Icons.** A `CNSymbol` icon is drawn as a hard-coded
///     `CupertinoIcons.circle` (there is a TODO for SF Symbol rendering).
///  3. **No glass.** It is a Flutter card filled with the scaffold colour at
///     95 % opacity, not a native `UIMenu`.
///  4. **Wrong index** (not in the report). Every item's `onPressed` closure
///     captures the same `itemIndex` variable, declared outside the loop and
///     incremented after each item, so every item reports the final count:
///     both Copy and Share call `onSelected(2)`, out of range for two items.
///
/// ### How this screen proves it
///
///  * **Route readout.** Every 100 ms the page checks its own
///    `Route.isCurrent`. When something is above it, the root navigator's
///    top route is named — peeked with a `popUntil` predicate that returns
///    `true` on the first route, so nothing is popped. `anyModalDepth` is
///    the plugin's own `CNTabBarRouteObserver` counter (registered at the
///    example app's root), a second, independent witness. The readout
///    ticking does not rebuild the menu: the dialog lives in its own
///    overlay entry.
///  * **Dashed box** above *Long press me* = where `_CNPopupMenuOverlay`
///    puts the menu: 220 wide, centred on the child, two 48 pt rows plus a
///    1 pt divider, ending 7 pt above the child. Its halves are the Copy and
///    Share items.
///  * **Rebuild switch.** When on, once a `RawDialogRoute` has been up for
///    1.5 s the page calls `WidgetsBinding.instance.reassembleApplication()`
///    — the widget-tree half of a hot reload — so "appears only after a hot
///    reload" can be seen on the phone with no laptop attached.
///  * **Control.** A `CNPopupMenuButton` with the same two items: a native
///    menu, Liquid Glass, real SF Symbols, and no Flutter route at all.
///
/// Verdicts, rebuild switch off unless stated:
///
///  * **Bug present:** the long press dims the screen and puts a faint grey
///    box over *Long press me*; the readout says `RawDialogRoute` and
///    `anyModalDepth 1`, and the control button should disappear
///    (`autoHideOnModal` hides native popups while a modal route is up) —
///    yet the dashed box stays empty. Tapping the box's top half logs
///    `onSelected(2 = OUT OF RANGE)` and lifts the dim. With the switch on,
///    the menu pops into the dashed box 1.5 s after the long press: a
///    near-opaque card with no glass and plain circles where `doc.on.doc`
///    and `square.and.arrow.up` belong. The control's menu shows both real
///    symbols on glass.
///  * **Bug fixed:** the menu is visible as soon as the long press fires,
///    with the real symbols; Copy logs `onSelected(0 = Copy)` and Share
///    `onSelected(1 = Share)`. If the fix goes native, the readout stays at
///    `none` and `anyModalDepth 0` during the long press — the same as the
///    control — the menu is glass, and the switch never fires.
///
/// Fallback if the readout ever disagrees with your eyes: while the dim is
/// up, tap anywhere outside the dashed box. An invisible barrier is there —
/// the tap only lifts the dim and never reaches what you tapped, and the log
/// says the route closed with no `onSelected`.
class Issue76PopupGestureTestPage extends StatefulWidget {
  const Issue76PopupGestureTestPage({super.key});

  @override
  State<Issue76PopupGestureTestPage> createState() =>
      _Issue76PopupGestureTestPageState();
}

class _Issue76PopupGestureTestPageState
    extends State<Issue76PopupGestureTestPage> {
  static const List<String> _labels = <String>['Copy', 'Share'];

  /// Where `_CNPopupMenuOverlay` places the menu for a two-item list: it
  /// computes `top = child.top - 2 * 48 - 8`, then lays out two 48 pt rows
  /// (24 pt icon + 12 pt padding above and below) with a 1 pt divider
  /// between them, so the 97 pt menu ends 7 pt above the child.
  static const double _menuWidth = 220;
  static const double _rowHeight = 48;
  static const double _menuHeight = 2 * _rowHeight + 1;
  static const double _menuGap = 7;

  static const Duration _rebuildAfter = Duration(milliseconds: 1500);

  final Stopwatch _clock = Stopwatch()..start();
  final List<String> _log = <String>[];
  Timer? _poll;
  ModalRoute<Object?>? _ownRoute;

  /// The route currently above this page, or null.
  Route<dynamic>? _above;
  Duration _aboveSince = Duration.zero;
  int _depth = 0;
  bool _autoRebuild = false;
  bool _rebuiltThisRoute = false;

  int _menuRoutes = 0;
  int _rebuilds = 0;
  int _gestureCalls = 0;
  int _gestureCallsAtOpen = 0;
  int? _gestureLast;
  int _controlCalls = 0;
  int? _controlLast;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 100), _tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ownRoute = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _tick(Timer _) {
    if (!mounted) return;
    final ModalRoute<Object?>? own = _ownRoute;
    final Route<dynamic>? above = own != null && own.isActive && !own.isCurrent
        ? _topRoute()
        : null;
    final int depth = CNTabBarRouteObserver.anyModalDepth.value;
    final bool routeChanged = !identical(above, _above);
    final bool changed = routeChanged || depth != _depth;

    if (routeChanged) {
      final Route<dynamic>? closed = _above;
      if (closed != null) {
        String how = '';
        if (closed is RawDialogRoute) {
          how = _gestureCalls > _gestureCallsAtOpen
              ? ' · via an item'
              : ' · no onSelected, so a barrier tap';
        }
        _addLog(
          '${_describe(closed)} closed after '
          '${_secs(_clock.elapsed - _aboveSince)}$how',
        );
      }
      if (above != null) {
        if (above is RawDialogRoute) _menuRoutes++;
        _gestureCallsAtOpen = _gestureCalls;
        _addLog(
          above is RawDialogRoute
              ? 'long press → ${_describe(above)} pushed'
              : '${_describe(above)} pushed above this page',
        );
      }
      _above = above;
      _aboveSince = _clock.elapsed;
      _rebuiltThisRoute = false;
    }
    _depth = depth;

    if (above is RawDialogRoute &&
        _autoRebuild &&
        !_rebuiltThisRoute &&
        _clock.elapsed - _aboveSince >= _rebuildAfter) {
      _rebuiltThisRoute = true;
      _rebuilds++;
      _addLog('rebuilt the whole widget tree (= hot reload)');
      unawaited(WidgetsBinding.instance.reassembleApplication());
    }

    if (changed || above != null) setState(() {});
  }

  /// The root navigator's topmost route. `Navigator` has no public getter
  /// for it, but `popUntil` hands its predicate the topmost route first, and
  /// returning `true` stops it there before anything is popped.
  /// `showGeneralDialog` pushes onto the root navigator by default.
  Route<dynamic>? _topRoute() {
    Route<dynamic>? top;
    Navigator.of(context, rootNavigator: true).popUntil((Route<dynamic> r) {
      top = r;
      return true;
    });
    return top;
  }

  void _addLog(String line) {
    _log.insert(0, '+${_secs(_clock.elapsed)}  $line');
    if (_log.length > 8) _log.removeLast();
  }

  String _secs(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

  String _describe(Route<dynamic> route) => route is RawDialogRoute
      ? 'RawDialogRoute (showGeneralDialog)'
      : '${route.runtimeType}';

  String _name(int? index) {
    if (index == null) return '—';
    if (index >= 0 && index < _labels.length) {
      return '$index = ${_labels[index]}';
    }
    return '$index = OUT OF RANGE';
  }

  void _onGestureSelected(int index) {
    // The reporter's snippet prints exactly this.
    debugPrint('Selected: $index');
    setState(() {
      _gestureCalls++;
      _gestureLast = index;
      _addLog('CNPopupGesture onSelected(${_name(index)})');
    });
  }

  void _onControlSelected(int index) {
    setState(() {
      _controlCalls++;
      _controlLast = index;
      _addLog('control onSelected(${_name(index)})');
    });
  }

  void _reset() {
    setState(() {
      _log.clear();
      _menuRoutes = 0;
      _rebuilds = 0;
      _gestureCalls = 0;
      _gestureCallsAtOpen = 0;
      _gestureLast = null;
      _controlCalls = 0;
      _controlLast = null;
      _clock
        ..reset()
        ..start();
      _aboveSince = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#76 · CNPopupGesture'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _controls(),
            const SizedBox(height: 24),
            _sectionTitle(context, "Reporter's snippet — long-press the words"),
            const SizedBox(height: 16),
            _menuSlot(context),
            const SizedBox(height: _menuGap),
            Center(
              // Only enlarges the text so it is easier to long-press; the
              // snippet inside is the reporter's, as written in the dartdoc.
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                child: CNPopupGesture(
                  items: const [
                    CNPopupMenuItem(
                      label: 'Copy',
                      icon: CNSymbol('doc.on.doc'),
                    ),
                    CNPopupMenuItem(
                      label: 'Share',
                      icon: CNSymbol('square.and.arrow.up'),
                    ),
                  ],
                  onSelected: _onGestureSelected,
                  child: const Text('Long press me'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _routeStatus(context),
            const SizedBox(height: 32),
            _sectionTitle(context, 'Control — CNPopupMenuButton, same items'),
            const SizedBox(height: 12),
            Center(
              child: CNPopupMenuButton(
                buttonLabel: 'Copy / Share',
                buttonStyle: CNButtonStyle.glass,
                shrinkWrap: true,
                items: const [
                  CNPopupMenuItem(label: 'Copy', icon: CNSymbol('doc.on.doc')),
                  CNPopupMenuItem(
                    label: 'Share',
                    icon: CNSymbol('square.and.arrow.up'),
                  ),
                ],
                onSelected: _onControlSelected,
              ),
            ),
            const SizedBox(height: 32),
            _sectionTitle(context, 'Log, newest first'),
            const SizedBox(height: 8),
            _logView(context),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final Route<dynamic>? above = _above;
    final String aboveText = above == null
        ? 'none'
        : '${_describe(above)} · up ${_secs(_clock.elapsed - _aboveSince)}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Long-press "Long press me". Bug: the screen dims and the readout '
            'says RawDialogRoute, but the dashed box stays empty; tapping its '
            'top half logs onSelected(2 = OUT OF RANGE). With rebuild on, the '
            'menu pops in after 1.5 s with plain circles and no glass. Fixed: '
            'the menu shows at once with real icons; Copy logs 0, Share 1. '
            'The control always shows real icons on glass.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              CupertinoSwitch(
                value: _autoRebuild,
                onChanged: (bool v) => setState(() => _autoRebuild = v),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Rebuild 1.5 s after the menu route opens (= hot reload)',
                  style: TextStyle(fontSize: 12, color: CupertinoColors.white),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                onPressed: _reset,
                child: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'route above page: $aboveText\n'
            'anyModalDepth $_depth · menu routes $_menuRoutes · '
            'rebuilds $_rebuilds\n'
            'gesture onSelected: $_gestureCalls× · '
            'last ${_name(_gestureLast)}\n'
            'control onSelected: $_controlCalls× · '
            'last ${_name(_controlLast)}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: CupertinoColors.white,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }

  /// The footprint the menu should occupy. Drawn on the page, so it shows
  /// through the 30 % barrier; a visible menu covers it exactly.
  Widget _menuSlot(BuildContext context) {
    final Color line = CupertinoColors.systemGrey.resolveFrom(context);
    final TextStyle style = TextStyle(
      fontSize: 12,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return Center(
      child: CustomPaint(
        foregroundPainter: _DashedBoxPainter(color: line),
        child: SizedBox(
          width: _menuWidth,
          height: _menuHeight,
          child: Column(
            children: <Widget>[
              SizedBox(
                height: _rowHeight,
                child: Center(
                  child: Text('Copy row · expect onSelected(0)', style: style),
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: line.withValues(alpha: 0.35),
              ),
              SizedBox(
                height: _rowHeight,
                child: Center(
                  child: Text('Share row · expect onSelected(1)', style: style),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routeStatus(BuildContext context) {
    final Route<dynamic>? above = _above;
    final bool menuUp = above is RawDialogRoute;
    final String text;
    if (above == null) {
      text = 'no route above this page';
    } else if (menuUp) {
      text =
          'menu route up ${_secs(_clock.elapsed - _aboveSince)} — '
          'is the dashed box filled?';
    } else {
      text = '${_describe(above)} above this page';
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: menuUp
            ? CupertinoColors.systemOrange.resolveFrom(context)
            : CupertinoColors.secondaryLabel.resolveFrom(context),
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _logView(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: CupertinoColors.label.resolveFrom(context),
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _log.isEmpty
            ? 'Nothing yet — long-press the words above.'
            : _log.join('\n'),
        style: style,
      ),
    );
  }
}

/// A dashed rounded rectangle: the outline of where the menu should be.
class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    for (final metric in outline.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBoxPainter oldDelegate) =>
      oldDelegate.color != color;
}
