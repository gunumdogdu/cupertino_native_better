import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show showModalBottomSheet;

/// Issue #43 reproduction — native glass widgets still react to taps while a
/// dialog or a modal bottom sheet is up.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/43
/// Reported by @josec-ecw (also seen by @tiyberius).
///
/// ### The claim
///
/// While a dialog or a modal bottom sheet is up, the page behind it should be
/// dead: the barrier takes every tap. The reporter added a `CNButton.icon` to
/// the nav bar of the "Glass widgets modal halo" page to open a
/// `showCupertinoDialog`. This page reuses that snippet as-is. The glass items
/// behind the dialog still played their press animation, but `onTap` /
/// `onPressed` did not fire. It did fire with a persistent `showBottomSheet`,
/// which has no barrier at all. In his app, a `CNButton.icon` that sat above a
/// modal bottom sheet stayed tappable.
///
/// State on `main`: since 1.5.1, `ModalHideMixin` destroys every mixin widget
/// on the page while a dialog or a raw sheet is up, because no sheet rect is
/// published and the fallback is to hide them all. So both original scenarios
/// should no longer reproduce for those widgets. Two gaps remain:
///
///  1. The interaction guard is reverted ("TAPPING-FIX REVERT"):
///     `wrapWithModalInteractionGuard` is a passthrough, and Dart no longer
///     calls the native `setInteractive`. `CNBottomSheet.show` publishes the
///     sheet's rect, so hiding is position-aware: a widget outside that rect
///     stays mounted, which means it stays live under the scrim.
///  2. A `CNTabBar` without a `searchItem` hides on the narrow `modalDepth`.
///     That counter only counts routes whose type name contains `Sheet`.
///     Dialogs and `showCupertinoModalPopup` don't move it, so the bar stays
///     live under them.
///
/// ### How this screen proves it
///
/// The reporter's nav-bar button sits top right. Below it, a strip holds a
/// `CNGlassButtonGroup`, a `CNPopupMenuButton`, a `CNSwitch` and a
/// `CNSegmentedControl`, placed above the top edge of a 40 % sheet. A
/// `CNTabBar` sits at the bottom. Each callback has a counter that also
/// records how many times it fired while a modal was up. The switch, the
/// segmented control and the tab bar also print the value Dart holds.
///
/// Four triggers. Each modal closes only from its own button (no barrier
/// dismiss, no drag):
///
///  * a dialog;
///  * a raw `showModalBottomSheet` at 40 %;
///  * `CNBottomSheet.show` at 40 %;
///  * `showCupertinoModalPopup`, raised above the tab bar so the bar stays
///    in view.
///
/// The readout shows `anyModalDepth` (the strip's gate), `modalDepth` (the
/// tab bar's gate) and the published sheet rect, live.
///
/// With each modal up, tap every native widget you can still see:
///
///  * **Bug present:** one of them plays a press animation, opens its menu,
///    moves its thumb or selection, or its "under modal" count rises. The
///    reported symptom is an animation with no count, and it still counts as
///    the bug. After you close the modal, a widget that looks different from
///    its printed Dart value took a tap that Dart never saw. Expected on
///    `main`: the strip and the nav-bar button under `CNBottomSheet.show`,
///    and the tab bar under the dialog and under the modal popup.
///  * **Bug fixed:** nothing behind any modal reacts and every "under modal"
///    count stays 0. The tap lands on the barrier and nothing happens.
///
/// Control: the same taps with no modal up raise every counter. With nothing
/// up, the nav-bar button also opens the reporter's dialog.
class Issue43GlassInteractableUnderModalTestPage extends StatefulWidget {
  const Issue43GlassInteractableUnderModalTestPage({super.key});

  @override
  State<Issue43GlassInteractableUnderModalTestPage> createState() =>
      _Issue43GlassInteractableUnderModalTestPageState();
}

/// The native callbacks this page counts.
enum _Target {
  navButton('Nav-bar CNButton.icon'),
  group('CNGlassButtonGroup'),
  popup('CNPopupMenuButton'),
  toggle('CNSwitch'),
  segment('CNSegmentedControl'),
  tabBar('CNTabBar');

  const _Target(this.label);

  final String label;
}

class _Issue43GlassInteractableUnderModalTestPageState
    extends State<Issue43GlassInteractableUnderModalTestPage> {
  static const List<String> _segments = <String>['One', 'Two', 'Three'];
  static const List<String> _tabs = <String>['Home', 'Library', 'Profile'];
  static const List<CNTabBarItem> _tabItems = <CNTabBarItem>[
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
      label: 'Profile',
      icon: CNSymbol('person'),
      activeIcon: CNSymbol('person.fill'),
    ),
  ];

  /// Wraps the tab bar and its label, so the modal popup can sit above both.
  final GlobalKey _tabBarAreaKey = GlobalKey();

  final Map<_Target, int> _fires = <_Target, int>{
    for (final _Target t in _Target.values) t: 0,
  };
  final Map<_Target, int> _firesUnderModal = <_Target, int>{
    for (final _Target t in _Target.values) t: 0,
  };
  String _last = '—';

  /// The modal this page has up, or null. Set before the push and cleared
  /// when its future completes (that is, at pop).
  String? _modal;

  /// Fires counted while the current modal is up. The modal's own panel
  /// listens to this, because a page `setState` does not rebuild a route's
  /// builder.
  final ValueNotifier<({int count, String last})> _modalLog =
      ValueNotifier<({int count, String last})>((count: 0, last: ''));

  bool _switchValue = false;
  int _segment = 0;
  int _tab = 0;

  @override
  void dispose() {
    _modalLog.dispose();
    super.dispose();
  }

  /// Counts one native callback. [apply] runs inside the same `setState`.
  void _hit(_Target target, [String detail = '', VoidCallback? apply]) {
    if (!mounted) return;
    final String? modal = _modal;
    final String name = '${target.label}$detail';
    setState(() {
      apply?.call();
      _fires[target] = _fires[target]! + 1;
      if (modal != null) {
        _firesUnderModal[target] = _firesUnderModal[target]! + 1;
        _last = '$name fired UNDER $modal';
      } else {
        _last = '$name (no modal)';
      }
    });
    if (modal != null) {
      _modalLog.value = (count: _modalLog.value.count + 1, last: name);
    }
  }

  Future<void> _present(String name, Future<void> Function() show) async {
    if (_modal != null) return;
    _modalLog.value = (count: 0, last: '');
    setState(() => _modal = name);
    try {
      await show();
    } finally {
      if (mounted) setState(() => _modal = null);
    }
  }

  /// The reporter's nav-bar button. It always counts. It opens his dialog
  /// only when nothing is up, so a press that leaks through a modal is
  /// counted rather than stacking a second modal.
  void _onNavButton() {
    final bool idle = _modal == null;
    _hit(_Target.navButton);
    if (idle) _showDialog();
  }

  /// The reporter's snippet, verbatim apart from argument order.
  Future<void> _showDialog() => _present(
    'showCupertinoDialog',
    () => showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: const Text('Dialog'),
        content: const Text(
          'Just testing a dialog, check if you can interact with any glass '
          'item.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );

  Future<void> _showRawSheet() {
    final double screenH = MediaQuery.sizeOf(context).height;
    final Color surface = CupertinoColors.systemBackground.resolveFrom(context);
    return _present(
      'raw showModalBottomSheet',
      () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: surface,
        builder: (BuildContext ctx) => _ModalPanel(
          title: 'Raw showModalBottomSheet · 40%',
          note:
              'No geometry probe, so main tears down every CN widget on the '
              'page and the tab bar too (its route name contains "Sheet"). '
              'Expected: the strip above is empty. If any widget is still '
              'there, tap it.',
          height: screenH * 0.4,
          log: _modalLog,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _showCNSheet() {
    final double screenH = MediaQuery.sizeOf(context).height;
    final Color surface = CupertinoColors.systemBackground.resolveFrom(context);
    return _present(
      'CNBottomSheet.show',
      () => CNBottomSheet.show<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: surface,
        builder: (BuildContext ctx) => _ModalPanel(
          title: 'CNBottomSheet.show · 40%',
          note:
              'Publishes its rect, so main tears down only the widgets it '
              'overlaps. The nav-bar button and the strip above stay mounted '
              'under the scrim. Tap each one: a press animation, a menu, or a '
              'thumb or selection change is the bug.',
          height: screenH * 0.4,
          log: _modalLog,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _showModalPopup() {
    final double screenH = MediaQuery.sizeOf(context).height;
    final double lift = _liftAboveTabBar();
    return _present(
      'showCupertinoModalPopup',
      () => showCupertinoModalPopup<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, lift),
          child: _ModalPanel(
            title: 'showCupertinoModalPopup',
            note:
                'Raised so the tab bar stays in view. This is not a "Sheet" '
                'route, so modalDepth stays 0 and the tab bar stays mounted '
                'under the barrier. Tap a different tab: any reaction is the '
                'bug. The strip is torn down because no rect is published.',
            height: screenH * 0.3,
            painted: true,
            log: _modalLog,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  /// Distance from the screen bottom to just above the tab bar's label.
  double _liftAboveTabBar() {
    final double screenH = MediaQuery.sizeOf(context).height;
    final RenderObject? box = _tabBarAreaKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return screenH - box.localToGlobal(Offset.zero).dy + 12;
    }
    return MediaQuery.paddingOf(context).bottom + 110;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Issue #43 · under modal'),
        trailing: CNButton.icon(
          icon: const CNSymbol('square.and.arrow.up', size: 18),
          onPressed: _onNavButton,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 170),
                children: <Widget>[
                  _strip(),
                  const SizedBox(height: 12),
                  _controls(),
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
              child: Column(
                key: _tabBarAreaKey,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _tabBarLabel(),
                  CNTabBar(
                    items: _tabItems,
                    currentIndex: _tab,
                    onTap: (int i) =>
                        _hit(_Target.tabBar, ' → ${_tabs[i]}', () => _tab = i),
                    tint: CupertinoColors.systemBlue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The native widgets, high enough that a 40 % sheet leaves them
  /// uncovered.
  Widget _strip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemIndigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          _row(_Target.navButton, 'top right ↗'),
          _row(
            _Target.group,
            'any of the three',
            CNGlassButtonGroup(
              buttons: <CNButtonData>[
                for (final (int i, String symbol) in const <(int, String)>[
                  (0, 'house.fill'),
                  (1, 'magnifyingglass'),
                  (2, 'person.fill'),
                ])
                  CNButtonData.icon(
                    icon: CNSymbol(symbol, size: 18),
                    onPressed: () => _hit(_Target.group, ' #$i'),
                    config: const CNButtonDataConfig(
                      style: CNButtonStyle.glass,
                    ),
                  ),
              ],
            ),
          ),
          _row(
            _Target.popup,
            'a menu opening counts',
            CNPopupMenuButton(
              buttonLabel: 'Actions',
              buttonStyle: CNButtonStyle.glass,
              items: const <CNPopupMenuEntry>[
                CNPopupMenuItem(label: 'First'),
                CNPopupMenuItem(label: 'Second'),
                CNPopupMenuItem(label: 'Third'),
              ],
              onSelected: (int i) => _hit(_Target.popup, ' item $i'),
            ),
          ),
          _row(
            _Target.toggle,
            'Dart value ${_switchValue ? 'on' : 'off'}',
            CNSwitch(
              value: _switchValue,
              onChanged: (bool v) =>
                  _hit(_Target.toggle, ' → $v', () => _switchValue = v),
            ),
          ),
          _row(
            _Target.segment,
            'Dart index $_segment (${_segments[_segment]})',
            SizedBox(
              width: 180,
              child: CNSegmentedControl(
                labels: _segments,
                selectedIndex: _segment,
                onValueChanged: (int i) => _hit(
                  _Target.segment,
                  ' → ${_segments[i]}',
                  () => _segment = i,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(_Target target, String hint, [Widget? child]) {
    final int under = _firesUnderModal[target]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  target.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                Text(
                  '×${_fires[target]} · $under under modal · $hint',
                  style: TextStyle(
                    fontSize: 11,
                    color: under > 0
                        ? CupertinoColors.systemRed.resolveFrom(context)
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (child != null) ...<Widget>[const SizedBox(width: 8), child],
        ],
      ),
    );
  }

  /// Sits right above the bar, so it stays readable under the dialog and the
  /// raised modal popup.
  Widget _tabBarLabel() {
    final int under = _firesUnderModal[_Target.tabBar]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'CNTabBar onTap ×${_fires[_Target.tabBar]} · $under under modal · '
        'Dart tab ${_tabs[_tab]}',
        style: TextStyle(
          fontSize: 12,
          color: under > 0
              ? CupertinoColors.systemRed.darkColor
              : CupertinoColors.white,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _controls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Readout first: it sits just under the strip, so a 40 % sheet
          // leaves it readable.
          _readout(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _trigger('Dialog', _showDialog),
              _trigger('Raw sheet 40%', _showRawSheet),
              _trigger('CNBottomSheet 40%', _showCNSheet),
              _trigger('Modal popup', _showModalPopup),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Bug: with a modal up, a native widget behind it plays a press '
            'animation, opens its menu, moves its thumb or selection, or its '
            '"under modal" count rises. An animation with no count is the '
            'reported symptom and still counts. After closing, a widget that '
            'looks different from its Dart value took a tap Dart never saw. '
            'Expected on main: the strip and the nav-bar button under '
            'CNBottomSheet, and the tab bar under the dialog and the modal '
            'popup. Fixed: nothing behind any modal reacts. Control: the '
            'same taps with no modal up raise every counter. Each modal '
            'closes only from its own button.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readout() {
    final String backend = PlatformVersion.shouldUseNativeGlass
        ? 'native'
        : 'fallback';
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        CNTabBarRouteObserver.anyModalDepth,
        CNTabBarRouteObserver.modalDepth,
        CNTabBarRouteObserver.topModalRect,
      ]),
      builder: (BuildContext context, Widget? _) {
        final int any = CNTabBarRouteObserver.anyModalDepth.value;
        final int sheetDepth = CNTabBarRouteObserver.modalDepth.value;
        final Rect? rect = CNTabBarRouteObserver.topModalRect.value;
        final int under = _firesUnderModal.values.fold<int>(
          0,
          (int sum, int n) => sum + n,
        );
        final String stripGate = any == 0
            ? ''
            : rect == null
            ? ' · no rect → all hide'
            : ' · rect top ${rect.top.round()} → only overlapped hide';
        final String barGate = any > 0 && sheetDepth == 0
            ? ' → bar NOT hidden'
            : '';
        return Text(
          'open: ${_modal ?? 'none'} · $backend\n'
          'anyModalDepth $any (strip gate)$stripGate\n'
          'modalDepth $sheetDepth (tab-bar gate)$barGate\n'
          'fires under a modal: $under\n'
          'last: $_last',
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: CupertinoColors.white,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }

  Widget _trigger(String label, VoidCallback onPressed) {
    return CupertinoButton.filled(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// Body shared by the two bottom sheets and the modal popup. It closes only
/// from its own button, and shows a live count of the fires behind it.
class _ModalPanel extends StatelessWidget {
  const _ModalPanel({
    required this.title,
    required this.note,
    required this.height,
    required this.log,
    required this.onClose,
    this.painted = false,
  });

  final String title;
  final String note;
  final double height;
  final ValueListenable<({int count, String last})> log;
  final VoidCallback onClose;

  /// Paints its own rounded surface, for the modal popup. Bottom sheets
  /// bring their own surface, so they leave this false.
  final bool painted;

  @override
  Widget build(BuildContext context) {
    final Color label = CupertinoColors.label.resolveFrom(context);
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: label,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          note,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<({int count, String last})>(
          valueListenable: log,
          builder: (BuildContext context, ({int count, String last}) v, _) {
            return Text(
              v.count == 0
                  ? 'nothing behind this modal has fired'
                  : '${v.count} fired behind this modal · last: ${v.last}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: v.count == 0
                    ? label
                    : CupertinoColors.systemRed.resolveFrom(context),
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            );
          },
        ),
        const Spacer(),
        CupertinoButton.filled(onPressed: onClose, child: const Text('Close')),
      ],
    );
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: painted
          ? BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      // The raised popup is not at the screen edge, so it skips the bottom
      // inset.
      child: painted ? body : SafeArea(top: false, child: body),
    );
  }
}
