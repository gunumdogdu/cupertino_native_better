import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #78 verification — there is no native action sheet; the only option is
/// a Flutter-drawn `CupertinoActionSheet`.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/78
/// Contributed by @yagizdo.
///
/// ### The claim
///
/// This is a feature PR (`CNActionSheet`, a real `UIAlertController` in
/// `.actionSheet` style), so the "bug" is what an app gets today. Its only
/// action sheet is Flutter's `CupertinoActionSheet` behind
/// `showCupertinoModalPopup`, which:
///
///  * is drawn by Flutter, so on iOS 26 it keeps the pre-26 look (detached
///    cancel row pinned to the bottom) instead of the system Liquid Glass
///    sheet;
///  * cannot anchor to the control that opened it — iOS 26 anchors action
///    sheets to their source on iPhone too, Flutter always slides up from the
///    bottom;
///  * has no disabled action state;
///  * is a Flutter `PopupRoute`, so `CNTabBarRouteObserver` counts it in
///    `anyModalDepth`, and every inline CN platform view on the page that
///    uses `ModalHideMixin` is **destroyed** while it is up and recreated
///    when it closes. A native `UIAlertController` is a UIKit presentation,
///    not a Flutter route, so it should leave them alone.
///
/// ### How this screen proves it
///
/// The top strip holds three inline native widgets (two glass `CNButton`s
/// and a `CNSegmentedControl`), and the readout shows `anyModalDepth` live.
/// Each scenario matches one in the PR's demo page and has a **Flutter**
/// button (today's sheet) and a **Native** button (`CNActionSheet`) built
/// from the same description:
///
///  * **Gap present (Flutter):** the pre-iOS 26 look; *Anchored* slides up
///    from the bottom; while the sheet is up the readout says
///    `modal depth 1 · strip torn down` and the strip blinks back after
///    dismiss.
///  * **Fixed (Native):** the iOS 26 system look; *Anchored* pops from its
///    Native button; the disabled action is greyed and ignores taps; the
///    strip stays visible and the depth stays `0`; the same taps return the
///    same value as Flutter.
///
/// The **Native stress** rows exercise the paths the review flagged. Each
/// call gets its own slot in the readout (`#1 … · #2 …`); a slot stuck on
/// `pending…` after every sheet is gone is a call that never resolves.
///
///  * *Show twice at once* — expected `#1 (cancelled)` at once and the
///    second sheet (Sort by) on screen.
///  * *Second sheet after 1 s* — the first sheet is replaced by Sort by after
///    a second; expected `#1 (cancelled)`.
///  * *Chained* — pick in Sort by, then Delete photo? opens by itself.
///  * *No actions, no cancel* — expected `#1 (cancelled)` at once and
///    nothing on screen.
///  * *From a CNBottomSheet* — the native sheet opens above a Flutter bottom
///    sheet and answers normally.
class Pr78ActionSheetTestPage extends StatefulWidget {
  const Pr78ActionSheetTestPage({super.key});

  @override
  State<Pr78ActionSheetTestPage> createState() =>
      _Pr78ActionSheetTestPageState();
}

typedef _Action = ({
  String label,
  String value,
  bool destructive,
  bool enabled,
});

typedef _Sheet = ({
  String? title,
  String? message,
  List<_Action> actions,
  String? cancelLabel,
});

class _Pr78ActionSheetTestPageState extends State<Pr78ActionSheetTestPage> {
  static const _Sheet _destructive = (
    title: 'Delete photo?',
    message: 'This cannot be undone.',
    actions: <_Action>[
      (label: 'Delete', value: 'delete', destructive: true, enabled: true),
      (
        label: 'Duplicate',
        value: 'duplicate',
        destructive: false,
        enabled: true,
      ),
    ],
    cancelLabel: 'Cancel',
  );

  static const _Sheet _noCancel = (
    title: 'Sort by',
    message: null,
    actions: <_Action>[
      (label: 'Name', value: 'name', destructive: false, enabled: true),
      (label: 'Date', value: 'date', destructive: false, enabled: true),
      (label: 'Size', value: 'size', destructive: false, enabled: true),
    ],
    cancelLabel: null,
  );

  static const _Sheet _titleAndMessage = (
    title: 'Unsaved changes',
    message: 'Your draft will be kept until you close the app.',
    actions: <_Action>[
      (label: 'Discard', value: 'discard', destructive: false, enabled: true),
    ],
    cancelLabel: 'Keep editing',
  );

  static const _Sheet _disabled = (
    title: 'Export',
    message: 'PDF export needs a paid plan.',
    actions: <_Action>[
      (label: 'Export as PNG', value: 'png', destructive: false, enabled: true),
      (
        label: 'Export as PDF',
        value: 'pdf',
        destructive: false,
        enabled: false,
      ),
    ],
    cancelLabel: 'Cancel',
  );

  static const _Sheet _longList = (
    title: 'Move to album',
    message: null,
    actions: <_Action>[
      (
        label: 'Favourites',
        value: 'favourites',
        destructive: false,
        enabled: true,
      ),
      (label: 'Travel', value: 'travel', destructive: false, enabled: true),
      (
        label: 'Screenshots',
        value: 'screenshots',
        destructive: false,
        enabled: true,
      ),
      (label: 'Receipts', value: 'receipts', destructive: false, enabled: true),
      (label: 'Family', value: 'family', destructive: false, enabled: true),
      (
        label: 'Recently deleted',
        value: 'deleted',
        destructive: false,
        enabled: true,
      ),
    ],
    cancelLabel: 'Cancel',
  );

  /// Flutter has no anchor, so its button opens like the others; the Native
  /// one passes its own rect as `anchorRect`.
  static const _Sheet _anchored = (
    title: null,
    message: null,
    actions: <_Action>[
      (label: 'Share', value: 'share', destructive: false, enabled: true),
      (label: 'Copy link', value: 'copy', destructive: false, enabled: true),
      (label: 'Remove', value: 'remove', destructive: true, enabled: true),
    ],
    cancelLabel: 'Cancel',
  );

  final GlobalKey _anchorKey = GlobalKey();
  String _lastResult = '—';
  int _segment = 0;

  /// Shows one slot per call — `#1 pending… · #2 pending…` — and fills each
  /// in as its future completes, so a call that never resolves stays
  /// visible instead of showing the last result.
  void _track(List<Future<String?>> calls) {
    final List<String> slots = List<String>.filled(calls.length, 'pending…');
    void show() {
      if (!mounted) return;
      setState(() {
        _lastResult = calls.length == 1
            ? slots.single
            : <String>[
                for (int i = 0; i < slots.length; i++) '#${i + 1} ${slots[i]}',
              ].join(' · ');
      });
    }

    show();
    for (int i = 0; i < calls.length; i++) {
      calls[i].then(
        (String? value) {
          slots[i] = value ?? '(cancelled)';
          show();
        },
        onError: (Object error) {
          slots[i] = 'error: $error';
          show();
        },
      );
    }
  }

  /// Today's only option. Each action pops with its value; a disabled
  /// action is drawn grey and does nothing, since Flutter has no disabled
  /// state for it.
  Future<String?> _showFlutter(_Sheet sheet) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: sheet.title == null ? null : Text(sheet.title!),
        message: sheet.message == null ? null : Text(sheet.message!),
        actions: <Widget>[
          for (final _Action a in sheet.actions)
            CupertinoActionSheetAction(
              isDestructiveAction: a.destructive,
              onPressed: a.enabled
                  ? () => Navigator.of(ctx).pop(a.value)
                  : () {},
              child: Text(
                a.label,
                style: a.enabled
                    ? null
                    : const TextStyle(color: CupertinoColors.inactiveGray),
              ),
            ),
        ],
        cancelButton: sheet.cancelLabel == null
            ? null
            : CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(sheet.cancelLabel!),
              ),
      ),
    );
  }

  Future<String?> _showNative(_Sheet sheet, {Rect? anchorRect}) {
    return CNActionSheet.show<String>(
      context: context,
      title: sheet.title,
      message: sheet.message,
      actions: <CNActionSheetAction<String>>[
        for (final _Action a in sheet.actions)
          CNActionSheetAction<String>(
            label: a.label,
            value: a.value,
            isDestructive: a.destructive,
            enabled: a.enabled,
          ),
      ],
      cancelLabel: sheet.cancelLabel,
      anchorRect: anchorRect,
    );
  }

  Rect? _rectOf(GlobalKey key) {
    final RenderObject? box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _showTwiceAtOnce() => _track(<Future<String?>>[
    _showNative(_destructive),
    _showNative(_noCancel),
  ]);

  void _supersedeAfterDelay() => _track(<Future<String?>>[
    _showNative(_destructive),
    Future<String?>.delayed(
      const Duration(seconds: 1),
      () => _showNative(_noCancel),
    ),
  ]);

  void _chained() {
    final Future<String?> first = _showNative(_noCancel);
    _track(<Future<String?>>[
      first,
      first.then((_) => _showNative(_destructive)),
    ]);
  }

  void _empty() => _track(<Future<String?>>[
    CNActionSheet.show<String>(
      context: context,
      actions: const <CNActionSheetAction<String>>[],
    ),
  ]);

  void _fromBottomSheet() {
    CNBottomSheet.show<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'A Flutter bottom sheet. The native action sheet should open '
                'above it.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () =>
                    _track(<Future<String?>>[_showNative(_destructive)]),
                child: const Text('Native action sheet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #78 · action sheet'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              'Flutter: pre-iOS 26 look, no anchor, no disabled state, and '
              'the strip below is torn down (depth 1). Native: iOS 26 look, '
              'Anchored pops from its button, strip stays live (depth 0).',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 16),
            _nativeStrip(),
            const SizedBox(height: 12),
            _readout(),
            const SizedBox(height: 20),
            _scenario('Destructive + cancel', _destructive),
            _scenario('No cancel button', _noCancel),
            _scenario('Title and message only', _titleAndMessage),
            _scenario('Disabled action', _disabled),
            _scenario('Long list (6 actions)', _longList),
            _scenario('Anchored to Native', _anchored, nativeKey: _anchorKey),
            const SizedBox(height: 12),
            const Text(
              'NATIVE STRESS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 10),
            _stress('Show twice at once', _showTwiceAtOnce),
            _stress('Second sheet after 1 s', _supersedeAfterDelay),
            _stress('Chained: pick, then another', _chained),
            _stress('No actions, no cancel', _empty),
            _stress('From a CNBottomSheet', _fromBottomSheet),
          ],
        ),
      ),
    );
  }

  /// Inline CN platform views that `ModalHideMixin` tears down under any
  /// Flutter popup route.
  Widget _nativeStrip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemIndigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: CNButton(label: 'Glass button', onPressed: () {}),
              ),
              const SizedBox(width: 12),
              CNButton.icon(
                icon: const CNSymbol('heart.fill'),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 12),
          CNSegmentedControl(
            labels: const <String>['One', 'Two', 'Three'],
            selectedIndex: _segment,
            onValueChanged: (int i) => setState(() => _segment = i),
          ),
        ],
      ),
    );
  }

  Widget _readout() {
    return ValueListenableBuilder<int>(
      valueListenable: CNTabBarRouteObserver.anyModalDepth,
      builder: (BuildContext context, int depth, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'modal depth $depth · strip ${depth > 0 ? 'torn down' : 'live'}\n'
          'last result: $_lastResult',
          style: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _scenario(String label, _Sheet sheet, {GlobalKey? nativeKey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          _button(
            'Flutter',
            CupertinoColors.activeBlue,
            () => _track(<Future<String?>>[_showFlutter(sheet)]),
          ),
          const SizedBox(width: 8),
          _button(
            'Native',
            CupertinoColors.systemGreen,
            () => _track(<Future<String?>>[
              _showNative(
                sheet,
                anchorRect: nativeKey == null ? null : _rectOf(nativeKey),
              ),
            ]),
            key: nativeKey,
          ),
        ],
      ),
    );
  }

  Widget _stress(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          _button('Native', CupertinoColors.systemGreen, onPressed),
        ],
      ),
    );
  }

  Widget _button(
    String label,
    Color color,
    VoidCallback onPressed, {
    Key? key,
  }) {
    return CupertinoButton(
      key: key,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
      ),
    );
  }
}
