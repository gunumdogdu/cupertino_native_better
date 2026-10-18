import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #65 verification — native controls other than `CNTabBar` lose their
/// touches to ancestor gesture recognizers.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/65
/// Follow-up to #62 / PR #63, which fixed `CNTabBar` only (see
/// `Issue62TabBarGestureArenaTestPage`).
///
/// ### The claim
///
/// Only `CNTabBar` makes its platform view claim pointers in Flutter's
/// gesture arena (`EagerGestureRecognizer`, v1.5.3). For every other control
/// an ancestor recognizer — a debug overlay's `GestureDetector(onLongPress:)`
/// such as `requests_inspector`, a `PageView`'s horizontal drag, a
/// `ListView`'s vertical drag — is said to win the arena, so the native
/// control's tap or drag is silently lost:
///
///  * `CNButton` and `CNPopupMenuButton` pass a bare `TapGestureRecognizer()`;
///  * `CNSwitch` and `CNSlider` pass a bare tap plus a bare
///    `HorizontalDragGestureRecognizer()`;
///  * `CNSegmentedControl` and `CNGlassButtonGroup` pass no recognizers.
///
/// The issue reads the bare recognizers as no-ops, because
/// `TapGestureRecognizer.isPointerAllowed` refuses a recognizer that has no
/// callbacks.
///
/// **Caveat found while writing this page.** For platform views that is not
/// the whole story: `_UiKitViewGestureRecognizer`
/// (`rendering/platform_view.dart`, lines 490–499 in Flutter 3.38.4) sets
/// `onTapDown ??= (_) {}` on a bare tap recognizer and `onDown ??= (_) {}` on
/// a bare drag recognizer, so both *do* enter the arena. The issue's proposed
/// `TapGestureRecognizer()..onTap = () {}` is therefore, as far as the arena
/// is concerned, what `main` already does for button and menu. What the
/// source does show is a timing difference. In **None** the platform view is
/// the only arena member and is accepted right after pointer-down. Under any
/// ancestor a quick tap is decided at pointer-*up*: the ancestor gives up and
/// the platform view wins the sweep, and only then does UIKit receive the
/// touches it was holding back. For `CNTabBar` that late release was fatal:
/// the first #62 patch (e8544da, a bare tap recognizer) still lost every tap
/// on-device, and only eager claiming (3609950) fixed it. Whether each
/// control below survives the late release is what this page measures.
///
/// ### How this screen proves it
///
/// Pick a component and a scenario in the dark panel. The zone below it
/// always holds two things in the same subtree: the **native** control under
/// test, and its **Flutter twin** (`CupertinoButton`, `CupertinoSwitch`, …).
/// The twin is the reference: it shows what Flutter's own arena decides for
/// the same gesture under the same ancestor, which settles the cases where
/// the "right" winner is a matter of taste.
///
///  * **None** — no ancestor recognizer at all. This is the control row: if
///    a control fails here, the other rows prove nothing.
///  * **Hold** — the zone is wrapped in `GestureDetector(onLongPress:)`, the
///    #62 repro. Holding the yellow strip shows the ancestor is alive.
///  * **Tap** — the zone is wrapped in `GestureDetector(onTap:)`. Tapping the
///    blue strip shows the ancestor is alive.
///  * **Pages** — the control sits on every page of a horizontal `PageView`.
///  * **List** — the control sits in a vertically scrolling `ListView`.
///
/// The readout counts the control's own callback (`onPressed`, `onSelected`,
/// `onValueChanged` or `onChanged`), the twin's, and the ancestor's
/// (long-presses, taps, or user drags that the `PageView` / `ListView`
/// started). It also counts **touches**: pointer-downs that landed on the
/// native view, seen by a `Listener`, which never enters the arena. The last
/// touch is classified by duration and travel (`tap` / `hold` / `drag`), so
/// a lost tap can be told apart from a finger that moved. The slider counts
/// drags (bursts of `onChanged`), not individual calls. Counters reset when
/// the component or the scenario changes, and on *Reset*. They update
/// without rebuilding the control, so measuring cannot disturb the gesture.
///
///  * **Bug present:** in None, five quick taps give `native 5`. In Hold,
///    Tap, Pages or List, five quick taps (the readout says `tap`) give
///    `touches 5`, but `native` stays at 0 or below 5, while the twin counts
///    every tap. In Tap, the ancestor counter takes the taps instead. For the
///    slider, drag the thumb instead of tapping.
///  * **Bug fixed:** `native` equals `touches` for quick taps in every
///    scenario, **and** these regression checks still hold:
///     - List: a vertical drag that *starts on* the control scrolls the list
///       (`list drags` +1, `native` unchanged), for every component. The twin
///       behaves the same way, `CupertinoSlider` and `CupertinoSwitch`
///       included. An eager fix on switch or slider would break this.
///     - Pages: a sideways drag on the slider, or on the switch thumb, moves
///       the control and `page drags` stays 0, as with the twin. A swipe that
///       starts on a button, menu or group turns the page, as it does for
///       `CupertinoButton`. An eager fix on those would break this.
///
/// Some precedence is genuinely ambiguous. Record it, but do not count it as
/// pass or fail:
///
///  * Hold, pressing the control for 0.5 s or longer and then releasing:
///    Flutter gives this to the ancestor (the twin's `onPressed` does not
///    fire). An eager fix like #62's gives it to the native control, and the
///    ancestor never fires over the control.
///  * Pages, a sideways drag that starts on the segmented control: the twin
///    (`CupertinoSlidingSegmentedControl`) keeps it. A tap-only recognizer
///    lets the page take it.
///
/// **iOS 26+ only.** Below iOS 26 every CN control here is a Flutter
/// fallback, and the panel says so. macOS is out of scope: in Flutter
/// 3.38.4 `RenderAppKitView.updateGestureRecognizers` is empty
/// (flutter/flutter#128519), so `gestureRecognizers` has no effect there.
class Issue65GestureArenaComponentsTestPage extends StatefulWidget {
  const Issue65GestureArenaComponentsTestPage({super.key});

  @override
  State<Issue65GestureArenaComponentsTestPage> createState() =>
      _Issue65GestureArenaComponentsTestPageState();
}

enum _Component {
  button('Button', 'onPressed'),
  menu('Menu', 'onSelected'),
  group('Group', 'onPressed'),
  segmented('Seg', 'onValueChanged'),
  toggle('Switch', 'onChanged'),
  slider('Slider', 'onChanged drags');

  const _Component(this.label, this.callback);

  /// Picker label.
  final String label;

  /// What the native counter counts.
  final String callback;
}

enum _Scenario {
  none('None', 'ancestor'),
  hold('Hold', 'ancestor long-press'),
  tap('Tap', 'ancestor onTap'),
  pages('Pages', 'page drags'),
  list('List', 'list drags');

  const _Scenario(this.label, this.ancestor);

  /// Picker label.
  final String label;

  /// What the ancestor counter counts.
  final String ancestor;
}

class _Issue65GestureArenaComponentsTestPageState
    extends State<Issue65GestureArenaComponentsTestPage> {
  /// Travel past which Flutter's recognizers treat a touch as a drag
  /// (`kTouchSlop`).
  static const double _slop = 18;

  /// Press length after which an ancestor `onLongPress` fires
  /// (`kLongPressTimeout`).
  static const int _holdMs = 500;

  /// A pause longer than this between two slider `onChanged` calls starts a
  /// new drag in the count.
  static const Duration _dragGap = Duration(milliseconds: 250);

  _Component _component = _Component.button;
  _Scenario _scenario = _Scenario.none;

  // Counters. They are mutated without setState and published through
  // [_tick], so bumping one rebuilds only the readout, never the control
  // under test.
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  int _native = 0;
  int _twin = 0;
  int _touches = 0;
  int _ancestor = 0;
  int _pageChanges = 0;
  int _page = 0;
  String _lastNative = '—';
  String _lastTouch = '—';
  Duration? _downAt;
  Offset? _downPos;
  DateTime _nativeSliderAt = DateTime(0);
  DateTime _twinSliderAt = DateTime(0);

  // Control values. These do go through setState: the controls are
  // controlled widgets and have to be rebuilt with the new value.
  int _nativeSegment = 0;
  int _twinSegment = 0;
  bool _nativeSwitch = false;
  bool _twinSwitch = false;
  double _nativeSlider = 0.5;
  double _twinSlider = 0.5;

  static const List<String> _segments = <String>['A', 'B', 'C'];
  static const List<String> _menuItems = <String>['One', 'Two', 'Three'];

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  void _bump(VoidCallback change) {
    change();
    _tick.value++;
  }

  void _zero() {
    _bump(() {
      _native = 0;
      _twin = 0;
      _touches = 0;
      _ancestor = 0;
      _pageChanges = 0;
      _lastNative = '—';
      _lastTouch = '—';
    });
  }

  // ── Touch probe (a Listener: sees every pointer, never joins the arena) ──

  void _onTouchDown(PointerDownEvent e) {
    _downAt = e.timeStamp;
    _downPos = e.position;
    _bump(() => _touches++);
  }

  void _onTouchUp(PointerUpEvent e) {
    final Duration? at = _downAt;
    final Offset? pos = _downPos;
    _downAt = null;
    _downPos = null;
    if (at == null || pos == null) return;
    final int ms = (e.timeStamp - at).inMilliseconds;
    final double pt = (e.position - pos).distance;
    final String kind = pt > _slop ? 'drag' : (ms >= _holdMs ? 'hold' : 'tap');
    _bump(() => _lastTouch = '$kind · $ms ms · ${pt.round()} pt');
  }

  void _onTouchCancel(PointerCancelEvent e) {
    _downAt = null;
    _downPos = null;
    _bump(() => _lastTouch = 'cancelled by the system');
  }

  // ── Page ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Issue #65 · gesture arena'),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _controls(),
            Expanded(
              // A fresh subtree per combination, so every native view is
              // created under the ancestor it is being tested with.
              child: KeyedSubtree(
                key: ValueKey<String>('${_scenario.name}/${_component.name}'),
                child: _zone(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final bool native = PlatformVersion.shouldUseNativeGlass;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Bug: None counts every tap, but under Hold / Tap / Pages / List '
            'quick taps raise touches while native lags and the twin counts. '
            'Fixed: native = touches everywhere, and drags that start on the '
            'control still reach the list and the page (see the card).',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          _picker<_Component>(
            _component,
            _Component.values,
            (_Component c) => c.label,
            (_Component c) => setState(() {
              _component = c;
              _zero();
            }),
          ),
          const SizedBox(height: 8),
          _picker<_Scenario>(
            _scenario,
            _Scenario.values,
            (_Scenario s) => s.label,
            (_Scenario s) => setState(() {
              _scenario = s;
              _page = 0;
              _zero();
            }),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: _readout()),
              const SizedBox(width: 8),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                onPressed: _zero,
                child: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (!native) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'iOS ${PlatformVersion.iosVersion ?? '?'}: below iOS 26 every '
              'CN control here is a Flutter fallback, so this page proves '
              'nothing on this device.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: CupertinoColors.systemOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _picker<T extends Enum>(
    T value,
    List<T> values,
    String Function(T) label,
    ValueChanged<T> onChanged,
  ) {
    return CupertinoSegmentedControl<T>(
      groupValue: value,
      padding: EdgeInsets.zero,
      onValueChanged: onChanged,
      children: <T, Widget>{
        for (final T v in values)
          v: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(label(v), style: const TextStyle(fontSize: 12)),
          ),
      },
    );
  }

  Widget _readout() {
    return ValueListenableBuilder<int>(
      valueListenable: _tick,
      builder: (BuildContext context, int tick, Widget? child) {
        final String ancestor = _scenario == _Scenario.none
            ? '—'
            : '$_ancestor';
        final String pages = _scenario == _Scenario.pages
            ? ' · page ${_page + 1} (changes $_pageChanges)'
            : '';
        return Text(
          'native ${_component.callback}  $_native  ·  touches  $_touches\n'
          'Flutter twin  $_twin  ·  ${_scenario.ancestor}  $ancestor$pages\n'
          'last touch  $_lastTouch\n'
          'last native  $_lastNative',
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: CupertinoColors.white,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }

  // ── Scenarios ───────────────────────────────────────────────────────────

  Widget _zone() {
    switch (_scenario) {
      case _Scenario.none:
        return _column();
      case _Scenario.hold:
        return GestureDetector(
          // The #62 repro, and what `requests_inspector` wraps apps in.
          // No Scrollable inside on purpose: a vertical drag recognizer
          // would beat the long-press on any finger jitter.
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _bump(() => _ancestor++),
          child: _column(
            strip: _strip(
              'HOLD HERE ~½ s',
              'fires the ancestor onLongPress',
              CupertinoColors.systemYellow,
            ),
          ),
        );
      case _Scenario.tap:
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _bump(() => _ancestor++),
          child: _column(
            strip: _strip(
              'TAP HERE',
              'fires the ancestor onTap',
              CupertinoColors.systemBlue,
            ),
          ),
        );
      case _Scenario.pages:
        return NotificationListener<ScrollStartNotification>(
          onNotification: _onScrollStart,
          child: PageView(
            onPageChanged: (int i) => _bump(() {
              _page = i;
              _pageChanges++;
            }),
            children: <Widget>[for (int i = 0; i < 3; i++) _pageAt(i)],
          ),
        );
      case _Scenario.list:
        return NotificationListener<ScrollStartNotification>(
          onNotification: _onScrollStart,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: <Widget>[
              _card(),
              const SizedBox(height: 16),
              _stage(),
              const SizedBox(height: 20),
              for (int i = 1; i <= 24; i++) _filler(i),
            ],
          ),
        );
    }
  }

  /// Counts drags that the `PageView` / `ListView` itself started, i.e. the
  /// times the ancestor won the arena with a drag.
  bool _onScrollStart(ScrollStartNotification n) {
    if (n.depth == 0 && n.dragDetails != null) _bump(() => _ancestor++);
    return false;
  }

  Widget _column({Widget? strip}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _card(),
          const SizedBox(height: 16),
          _stage(),
          const SizedBox(height: 16),
          Expanded(child: strip ?? const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _pageAt(int i) {
    const List<CupertinoDynamicColor> tints = <CupertinoDynamicColor>[
      CupertinoColors.systemBlue,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
    ];
    final Color tint = tints[i].resolveFrom(context);
    return Container(
      color: tint.withValues(alpha: 0.16),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _card(),
          const SizedBox(height: 16),
          _stage(),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(
                'PAGE ${i + 1} OF 3\nswipe ⇐ ⇒ on the colour',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _strip(String title, String subtitle, CupertinoDynamicColor color) {
    final Color c = color.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c, width: 2),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        '$title\n$subtitle',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }

  Widget _filler(int i) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Row $i — drag anywhere to scroll',
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  // ── What to do for this component × scenario ────────────────────────────

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _steps(),
        style: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }

  String get _act {
    switch (_component) {
      case _Component.button:
        return 'Tap Native button';
      case _Component.menu:
        return 'Tap Native menu and pick an item,';
      case _Component.group:
        return 'Tap either glass button';
      case _Component.segmented:
        return 'Tap a segment that is not selected';
      case _Component.toggle:
        return 'Tap the switch';
      case _Component.slider:
        return 'Drag the native thumb sideways';
    }
  }

  String get _pagesDrag {
    switch (_component) {
      case _Component.button:
      case _Component.menu:
      case _Component.group:
        return 'A swipe starting on the native control turns the page, as '
            'it does on the twin.';
      case _Component.segmented:
        return 'A swipe starting on it is ambiguous (the twin keeps it): '
            'just note who wins.';
      case _Component.toggle:
        return 'Sliding the switch thumb sideways toggles it and page '
            'drags stays 0, as on the twin.';
      case _Component.slider:
        return 'Slider drags move the slider and page drags stays 0, as on '
            'the twin.';
    }
  }

  String _steps() {
    switch (_scenario) {
      case _Scenario.none:
        return '$_act 5× → native +5. Control row: if it fails here, the '
            'other scenarios prove nothing.';
      case _Scenario.hold:
        return '$_act 5× → native +5, ancestor 0. Hold the yellow strip → '
            'ancestor +1. Then hold the native control ~1 s and release: '
            'note who fires (on the twin, the ancestor wins).';
      case _Scenario.tap:
        return '$_act 5× → native +5, ancestor onTap stays 0. Tap the '
            'blue strip → ancestor +1.';
      case _Scenario.pages:
        return '$_act 5× → native +5. Swipe on the colour → page drags +1. '
            '$_pagesDrag';
      case _Scenario.list:
        return '$_act 5× → native +5. Then start a vertical drag ON the '
            'native control → the list scrolls (list drags +1) and native '
            'does not move, as on the twin.';
    }
  }

  // ── The control under test and its Flutter twin ─────────────────────────

  Widget _stage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _caption('NATIVE · under test'),
        const SizedBox(height: 6),
        Listener(
          // deferToChild (the default): only touches that hit the native
          // view itself count.
          onPointerDown: _onTouchDown,
          onPointerUp: _onTouchUp,
          onPointerCancel: _onTouchCancel,
          child: _nativeControl(),
        ),
        const SizedBox(height: 14),
        _caption('FLUTTER TWIN · reference'),
        const SizedBox(height: 6),
        _twinControl(),
      ],
    );
  }

  Widget _caption(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }

  Widget _nativeControl() {
    switch (_component) {
      case _Component.button:
        return Center(
          child: CNButton(
            label: 'Native button',
            config: const CNButtonConfig(
              style: CNButtonStyle.glass,
              shrinkWrap: true,
            ),
            onPressed: () => _bump(() {
              _native++;
              _lastNative = 'pressed';
            }),
          ),
        );
      case _Component.menu:
        return Center(
          child: CNPopupMenuButton(
            buttonLabel: 'Native menu',
            buttonStyle: CNButtonStyle.glass,
            shrinkWrap: true,
            height: 44,
            items: <CNPopupMenuEntry>[
              for (final String item in _menuItems)
                CNPopupMenuItem(label: item),
            ],
            onSelected: (int i) => _bump(() {
              _native++;
              _lastNative = 'picked ${_menuItems[i]}';
            }),
          ),
        );
      case _Component.group:
        // Inside a Row the group gets unbounded width and sizes itself to
        // its two 44 pt buttons, so the native view has no dead margin.
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CNGlassButtonGroup(
              buttons: <CNButtonData>[
                CNButtonData.icon(
                  icon: const CNSymbol('heart.fill'),
                  onPressed: () => _bump(() {
                    _native++;
                    _lastNative = 'heart';
                  }),
                ),
                CNButtonData.icon(
                  icon: const CNSymbol('star.fill'),
                  onPressed: () => _bump(() {
                    _native++;
                    _lastNative = 'star';
                  }),
                ),
              ],
            ),
          ],
        );
      case _Component.segmented:
        return Center(
          child: SizedBox(
            width: 240,
            child: CNSegmentedControl(
              labels: _segments,
              selectedIndex: _nativeSegment,
              onValueChanged: (int i) => setState(() {
                _nativeSegment = i;
                _native++;
                _lastNative = 'segment ${_segments[i]}';
              }),
            ),
          ),
        );
      case _Component.toggle:
        return Center(
          child: CNSwitch(
            value: _nativeSwitch,
            onChanged: (bool v) => setState(() {
              _nativeSwitch = v;
              _native++;
              _lastNative = v ? 'on' : 'off';
            }),
          ),
        );
      case _Component.slider:
        return Center(
          child: SizedBox(
            width: 260,
            child: CNSlider(
              value: _nativeSlider,
              onChanged: (double v) {
                final DateTime now = DateTime.now();
                setState(() {
                  if (now.difference(_nativeSliderAt) > _dragGap) _native++;
                  _nativeSliderAt = now;
                  _nativeSlider = v;
                  _lastNative = v.toStringAsFixed(2);
                });
              },
            ),
          ),
        );
    }
  }

  Widget _twinControl() {
    switch (_component) {
      case _Component.button:
      case _Component.menu:
        // For the menu the twin counts presses: the arena question is
        // whether the press that opens the menu gets through.
        return Center(
          child: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            minimumSize: Size.zero,
            onPressed: () => _bump(() => _twin++),
            child: Text(
              _component == _Component.menu ? 'Flutter menu' : 'Flutter button',
            ),
          ),
        );
      case _Component.group:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (final IconData icon in const <IconData>[
              CupertinoIcons.heart_fill,
              CupertinoIcons.star_fill,
            ])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: CupertinoButton.tinted(
                  padding: const EdgeInsets.all(10),
                  minimumSize: Size.zero,
                  onPressed: () => _bump(() => _twin++),
                  child: Icon(icon, size: 22),
                ),
              ),
          ],
        );
      case _Component.segmented:
        return Center(
          child: SizedBox(
            width: 240,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _twinSegment,
              children: <int, Widget>{
                for (int i = 0; i < _segments.length; i++)
                  i: Text(_segments[i]),
              },
              onValueChanged: (int? v) {
                if (v == null || v == _twinSegment) return;
                setState(() {
                  _twinSegment = v;
                  _twin++;
                });
              },
            ),
          ),
        );
      case _Component.toggle:
        return Center(
          child: CupertinoSwitch(
            value: _twinSwitch,
            onChanged: (bool v) => setState(() {
              _twinSwitch = v;
              _twin++;
            }),
          ),
        );
      case _Component.slider:
        return Center(
          child: SizedBox(
            width: 260,
            child: CupertinoSlider(
              value: _twinSlider,
              onChanged: (double v) {
                final DateTime now = DateTime.now();
                setState(() {
                  if (now.difference(_twinSliderAt) > _dragGap) _twin++;
                  _twinSliderAt = now;
                  _twinSlider = v;
                });
              },
            ),
          ),
        );
    }
  }
}
