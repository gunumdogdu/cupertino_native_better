import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #72 verification — the glass keeps its old size when the platform view
/// is resized.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/72
/// Reported by @johndavid92.
///
/// ### The claim
///
/// `LiquidGlassContainerSwiftUI` sizes its shape from a `GeometryReader`,
/// which only re-evaluates when SwiftUI re-renders the hosted view. UIKit
/// attaching or resizing the platform view does neither, so once the
/// container's box changes after creation the glass keeps drawing at its old
/// size: a squashed or undersized shape inside a correctly sized box. It shows
/// up wherever a container is long-lived and resized rather than rebuilt (the
/// reporter keeps a full-screen player page mounted while it collapses and is
/// moved with a transform) and, per the PR, on the very first layout too: the
/// view is created at zero size and laid out at its real size a moment later.
/// The only Dart workaround is changing the widget key, which disposes the
/// `UiKitView` and flashes.
///
/// ### How this screen proves it
///
/// One `LiquidGlassContainer` that stays mounted: same tree position, same
/// `ValueKey(_epoch)`, a parent chain that never changes shape between
/// toggles. `LiquidGlassContainer` is a passthrough `Stack` sized exactly by
/// its child, with the platform view `Positioned.fill` inside it — so the
/// child's box IS the box the native view is laid out into. Here that child
/// is an `AnimatedContainer` with a 2 px red border and a readout of its
/// target size, which makes the red rectangle, by construction, the frame
/// Flutter hands to the native view.
///
///  * **Bug present:** after a size change the glass does not fill the red
///    box — squashed, undersized, or stuck at the previous size.
///  * **Bug fixed:** the glass matches the red box every time, once the
///    350 ms animation settles.
///
/// The readout turns white and gains a ✓ when both `AnimatedContainer`s have
/// reported `onEnd`, i.e. the box is at its target and nothing is moving.
/// Judge (and screenshot) only frames that show the ✓: mid-animation the
/// glass is legitimately in motion and the readout already names the target,
/// so an un-ticked frame looks like the bug even when it is fixed.
///
/// **Recreate** bumps `_epoch`, which changes the key, disposes the
/// `UiKitView` and creates a fresh one at the current box. That is the Dart
/// workaround the PR describes and it is the control: with the bug present
/// the glass matches the box right after Recreate, proving the mismatch is
/// stale native state rather than a Dart layout problem.
///
/// Scenarios (segmented control), each mapped to the native code path it
/// drives:
///
///  * `resize` — long-lived container resized in place, 300×92 ↔ 160×220.
///    Native: `layoutSubviews` with a new bounds size.
///  * `collapse` — the reporter's player page: 340×300 at dy 0 ↔ 340×64
///    translated 180 pt down. Size and transform change together while the
///    container stays mounted. The translation is applied by an
///    `AnimatedContainer` *above* the glass, as in the reporter's app: a
///    transform on the child would move the red box but not the platform
///    view, which fills the child's untransformed bounds. Native: as
///    `resize`.
///  * `zero` — "created at zero size, laid out at its real size a moment
///    later": Toggle sets the child to 0×0 **and bumps `_epoch`**, so the
///    platform view is created and first composited at a zero frame, then
///    grows to 300×92 after 1.5 s. This is the reporter's init case and the
///    target of the PR's `DispatchQueue.main.async { refreshGlass() }`.
///    (Every platform view starts at `CGRectZero` in the engine and gets its
///    real frame on its first composite, so Recreate at a non-zero box is the
///    same thing at a smaller scale; before this scenario bumped the key,
///    pressing Recreate by luck mid-sequence was the only way to create a
///    view while the box was 0×0.)
///  * `offscreen` — resized in place while out of view: Toggle translates the
///    panel 1400 pt down (past the bottom edge), swaps the size 400 ms later
///    while it is invisible, and brings it back 900 ms after that. On iOS the
///    platform view **stays in the window** throughout — the engine never
///    culls a subtree that contains a platform view, so the view is simply
///    composited off screen — which makes this another `layoutSubviews`
///    case, just one the maintainer cannot watch happen. It does NOT hit
///    `didMoveToWindow`; `detach` does.
///  * `detach` — resized while detached from the window: Toggle pushes an
///    opaque `CupertinoPageRoute` over this page. Once its transition ends
///    the page is an offstage overlay entry, is no longer painted, and the
///    engine removes the platform view from the `FlutterView`
///    (`removeFromSuperview`, `window == nil`). 900 ms after the push the box
///    is swapped 300×92 ↔ 160×220 with a zero-duration change (the entry is
///    offstage, so its tickers are muted; a real animation would only start
///    after the pop and the view would come back at its old size). 1.8 s
///    after the push the cover is popped, the entry is painted again, the
///    view is re-added at its new frame and `didMoveToWindow` fires with a
///    window. Caveat: the push/pop drives `setTransitioning` on the
///    container, but that only toggles UIKit clip/corner properties on the
///    host view (`applyTransitionContainment`) — it does not invalidate the
///    SwiftUI body. The body IS re-rendered on every route transition in apps
///    that register `CNTransitionObserver` in `navigatorObservers` (the
///    example app and the probe do not), and there the glass can self-heal
///    on pop without the PR, so a correct result in such an app is not
///    evidence for the fix.
///
/// **Auto** repeats Toggle on a timer — 1.6 s for `resize` / `collapse`,
/// 3.2 s for the three multi-step scenarios so each sequence settles before
/// the next one starts. The probe entrypoint turns it on so a screenshot needs
/// no taps. Sequences carry a run token, so a Toggle or scenario change during
/// a sequence cancels its remaining steps (and pops a still-open cover).
///
/// Fixed geometry over the vertical-stripe backdrop of the PR #69 screen
/// (constant along y), so before/after screenshots line up.
class Pr72GlassResizeTestPage extends StatefulWidget {
  const Pr72GlassResizeTestPage({
    super.key,
    this.initialScenario,
    this.label,
    this.autoCycle = false,
  });

  /// One of [scenarios]; anything else falls back to `resize`.
  final String? initialScenario;

  /// Stamped into the nav bar so a before/after screenshot pair can't be
  /// mixed up.
  final String? label;

  /// Start with the Auto switch on, so the panel toggles without any taps.
  final bool autoCycle;

  /// Segmented-control keys, in display order.
  static const List<String> scenarios = <String>[
    'resize',
    'collapse',
    'zero',
    'offscreen',
    'detach',
  ];

  @override
  State<Pr72GlassResizeTestPage> createState() =>
      _Pr72GlassResizeTestPageState();
}

/// Target geometry for one end of a scenario: the child's size and the
/// vertical translation applied above the glass.
class _Box {
  const _Box(this.w, this.h, [this.dy = 0]);

  final double w;
  final double h;
  final double dy;
}

class _Pr72GlassResizeTestPageState extends State<Pr72GlassResizeTestPage> {
  static const Duration _anim = Duration(milliseconds: 350);
  static const double _offscreenDy = 1400;

  /// [A, B] ends per scenario. `zero`'s B is the transient 0×0 state; the
  /// panel always returns to A on its own.
  static const Map<String, List<_Box>> _ends = <String, List<_Box>>{
    'resize': <_Box>[_Box(300, 92), _Box(160, 220)],
    'collapse': <_Box>[_Box(340, 300), _Box(340, 64, 180)],
    'zero': <_Box>[_Box(300, 92), _Box(0, 0)],
    'offscreen': <_Box>[_Box(300, 92), _Box(160, 220)],
    'detach': <_Box>[_Box(300, 92), _Box(160, 220)],
  };

  static const Map<String, String> _descriptions = <String, String>{
    'resize': 'Long-lived view resized in place.',
    'collapse':
        'Player page: expanded ↔ collapsed and moved 180 pt down; size and '
        'transform change together.',
    'zero': 'View created at 0×0, grown to its real size 1.5 s later.',
    'offscreen':
        'Resized in place while translated below the screen (the view stays '
        'in the window).',
    'detach':
        'Covered by a page so the view leaves the window, resized there, '
        'uncovered 1.8 s after the push.',
  };

  String _scenario = 'resize';

  /// Which end of the scenario the last Toggle went to (A = false).
  bool _atB = false;

  double _w = 300;
  double _h = 92;
  double _dy = 0;

  /// True while the size change should apply with a zero-duration animation
  /// (the `detach` swap, made while the page is offstage and tickers are
  /// muted).
  bool _snap = false;

  /// `onEnd` bookkeeping for the two `AnimatedContainer`s. Cleared whenever
  /// the corresponding value changes; set again when its animation ends.
  bool _sizeSettled = true;
  bool _dySettled = true;

  /// Bumped by Recreate (and by `zero`'s Toggle); it is the glass container's
  /// key.
  int _epoch = 0;

  /// Run token: delayed steps only apply while they belong to the latest run.
  int _run = 0;

  /// The opaque route pushed by `detach`, while it is up.
  CupertinoPageRoute<void>? _cover;

  bool _autoOn = false;
  Timer? _auto;

  _Box get _a => _ends[_scenario]![0];
  _Box get _b => _ends[_scenario]![1];

  bool get _settled => _sizeSettled && _dySettled;

  Duration get _autoPeriod =>
      _scenario == 'zero' || _scenario == 'offscreen' || _scenario == 'detach'
      ? const Duration(milliseconds: 3200)
      : const Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    if (Pr72GlassResizeTestPage.scenarios.contains(widget.initialScenario)) {
      _scenario = widget.initialScenario!;
    }
    _apply(_a);
    if (widget.autoCycle) {
      _autoOn = true;
      _startAuto();
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  /// Sets the target geometry, clearing the settled flag of each value that
  /// actually changes (an unchanged value never animates, so its `onEnd`
  /// would never come).
  void _apply(_Box b) {
    _applySize(b.w, b.h);
    _applyDy(b.dy);
  }

  void _applySize(double w, double h) {
    if (w == _w && h == _h) return;
    _w = w;
    _h = h;
    _sizeSettled = false;
  }

  void _applyDy(double dy) {
    if (dy == _dy) return;
    _dy = dy;
    _dySettled = false;
  }

  void _toggle() {
    final int run = ++_run;
    _popCover();
    switch (_scenario) {
      case 'zero':
        setState(() {
          _snap = false;
          _applySize(_b.w, _b.h);
          // New key: the platform view is created while the box is 0×0. The
          // fresh child starts at 0×0 with nothing to animate, so it is
          // settled right away.
          _epoch++;
          _sizeSettled = true;
        });
        _after(1500, run, () => _applySize(_a.w, _a.h));
      case 'offscreen':
        _atB = !_atB;
        final _Box target = _atB ? _b : _a;
        setState(() {
          _snap = false;
          _applyDy(_offscreenDy);
        });
        _after(400, run, () => _applySize(target.w, target.h));
        _after(1300, run, () => _applyDy(target.dy));
      case 'detach':
        _atB = !_atB;
        final _Box target = _atB ? _b : _a;
        setState(() => _snap = false);
        _pushCover();
        // 900 ms: the 500 ms push transition is over, the page is offstage
        // and the view has left the window. Snap the size (tickers are muted
        // offstage; see the doc comment).
        _after(900, run, () {
          _snap = true;
          _applySize(target.w, target.h);
        });
        _after(1800, run, () {
          _snap = false;
          _popCover();
        });
      default:
        _atB = !_atB;
        setState(() {
          _snap = false;
          _apply(_atB ? _b : _a);
        });
    }
  }

  /// Applies [step] in a `setState` after [ms], unless the page went away or a
  /// newer Toggle / scenario change superseded [run].
  void _after(int ms, int run, VoidCallback step) {
    Future<void>.delayed(Duration(milliseconds: ms), () {
      if (!mounted || run != _run) return;
      setState(step);
    });
  }

  void _pushCover() {
    if (_cover != null) return;
    final CupertinoPageRoute<void> route = CupertinoPageRoute<void>(
      builder: (_) => const _CoverPage(),
    );
    _cover = route;
    Navigator.of(context).push(route).whenComplete(() {
      // Also covers a manual back-swipe on the cover page.
      if (identical(_cover, route)) _cover = null;
    });
  }

  void _popCover() {
    final CupertinoPageRoute<void>? route = _cover;
    if (route == null) return;
    _cover = null;
    if (!route.isActive) return;
    final NavigatorState nav = Navigator.of(context);
    if (route.isCurrent) {
      nav.pop();
    } else {
      nav.removeRoute(route);
    }
  }

  void _selectScenario(String scenario) {
    ++_run;
    _popCover();
    _atB = false;
    setState(() {
      _scenario = scenario;
      _snap = false;
      _apply(_a);
    });
    if (_autoOn) _startAuto();
  }

  void _setAuto(bool on) {
    setState(() => _autoOn = on);
    if (on) {
      _startAuto();
    } else {
      _auto?.cancel();
      _auto = null;
    }
  }

  void _startAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(_autoPeriod, (_) => _toggle());
  }

  /// The fresh child is built at the current target, so nothing animates on
  /// it; only the outer (dy) animation can still be in flight.
  void _recreate() => setState(() {
    _epoch++;
    _sizeSettled = true;
  });

  /// `onEnd` can fire synchronously inside a build: a zero-duration change
  /// (the `detach` snap) completes in `AnimatedContainer.didUpdateWidget`,
  /// where `setState` on this page is not allowed. A microtask runs after the
  /// frame in every case.
  void _markSettled({bool size = false, bool dy = false}) {
    scheduleMicrotask(() {
      if (!mounted) return;
      setState(() {
        if (size) _sizeSettled = true;
        if (dy) _dySettled = true;
      });
    });
  }

  String get _readout {
    final String size = '${_w.round()} × ${_h.round()}';
    final String pos = _dy == 0
        ? size
        : '$size · dy ${_dy > 0 ? '+' : ''}${_dy.round()}';
    return _settled ? '$pos ✓' : pos;
  }

  @override
  Widget build(BuildContext context) {
    final String label = widget.label ?? '';
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          label.isEmpty
              ? 'PR #72 · glass resize'
              : 'PR #72 · glass resize · $label',
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: _StripePainter())),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  _controls(),
                  Expanded(child: Center(child: _glassPanel())),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The one glass container under test. Its tree position and key are stable
  /// across toggles; only Recreate (and `zero`'s Toggle) changes the key.
  Widget _glassPanel() {
    // The translation lives above the glass so the platform view moves with
    // the red box (a transform on the child would move only the child).
    return AnimatedContainer(
      duration: _anim,
      curve: Curves.easeInOut,
      transform: Matrix4.translationValues(0, _dy, 0),
      onEnd: () => _markSettled(dy: true),
      child: LiquidGlassContainer(
        key: ValueKey<int>(_epoch),
        config: const LiquidGlassConfig(
          effect: CNGlassEffect.regular,
          shape: CNGlassEffectShape.rect,
          cornerRadius: 22,
        ),
        // This child sizes the container, so its red border is exactly the
        // frame the native platform view is laid out into.
        child: AnimatedContainer(
          duration: _snap ? Duration.zero : _anim,
          curve: Curves.easeInOut,
          width: _w,
          height: _h,
          onEnd: () => _markSettled(size: true),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemRed, width: 2),
            borderRadius: BorderRadius.circular(22),
          ),
          child: ClipRect(
            child: Center(
              child: Text(
                _readout,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _settled
                      ? CupertinoColors.white
                      : CupertinoColors.systemGrey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
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
            'Red border = the box the native view is laid out into. Bug: the '
            'glass does not fill it after a size change. Fixed: it always '
            'does. Judge only frames whose readout shows ✓. Recreate rebuilds '
            'the view (Dart workaround) and always matches.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _descriptions[_scenario]!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 10),
          CupertinoSegmentedControl<String>(
            groupValue: _scenario,
            onValueChanged: _selectScenario,
            children: <String, Widget>{
              for (final String s in Pr72GlassResizeTestPage.scenarios)
                s: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(s, style: const TextStyle(fontSize: 12)),
                ),
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.small,
                onPressed: _toggle,
                child: const Text('Toggle'),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                sizeStyle: CupertinoButtonSize.small,
                onPressed: _recreate,
                child: const Text('Recreate'),
              ),
              const Spacer(),
              const Text(
                'Auto',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(width: 6),
              CupertinoSwitch(value: _autoOn, onChanged: _setAuto),
            ],
          ),
        ],
      ),
    );
  }
}

/// The opaque page `detach` pushes over the test page. While it is the
/// current route the test page is an offstage overlay entry, so its platform
/// view is removed from the window.
class _CoverPage extends StatelessWidget {
  const _CoverPage();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('PR #72 · cover')),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The glass view is detached from the window behind this page. '
            'It is resized here and the page pops on its own.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
          ),
        ),
      ),
    );
  }
}

/// Vertical stripes, constant along y — the PR #69 backdrop, copied so this
/// file does not depend on that screen's private painter.
///
/// Fine stripes make the glass edge unmistakable: `.regular` frosts them into
/// flat grey, so where the frosting stops is where the glass stops.
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double period = 8;
    final Paint dark = Paint()..color = const Color(0xFF101014);
    final Paint light = Paint()..color = const Color(0xFFF2F2F7);
    canvas.drawRect(Offset.zero & size, dark);
    for (double x = 0; x < size.width; x += period) {
      canvas.drawRect(Rect.fromLTWH(x, 0, period / 2, size.height), light);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
