import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'
    show
        AppBar,
        DropdownButton,
        DropdownMenuItem,
        Material,
        PopupMenuButton,
        PopupMenuButtonState,
        PopupMenuItem,
        Scaffold,
        showDialog,
        showModalBottomSheet;

/// Issue #188 reproduction: a Material `DropdownButton` menu is measured as
/// the whole screen, so every `autoHideOnModal: true` widget hides.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/188
/// Reported by @LucasLau00.
///
/// ### The claim
///
/// `CNTabBarRouteObserver` measures what a modal route paints by walking its
/// render tree through render objects known to paint only their children.
/// The dropdown route's page starts with a `LayoutBuilder`, whose render
/// object isn't on that list, so the walk stops at the route's root and the
/// whole screen counts as the menu. Every CN widget with
/// `autoHideOnModal: true` overlaps that and hides.
///
/// ### How this screen proves it
///
/// A Material app bar with a glass `CNButton.icon` as `leading` and one in
/// `actions` (both `autoHideOnModal: true` unless switched off). The body has
/// a `DropdownButton`, a `PopupMenuButton`, a small bottom sheet and a dialog,
/// all well below the app bar, and a readout of
/// `CNTabBarRouteObserver.anyModalDepth` and `.modalRect`. AUTO opens each in
/// turn and prints `CNB_SHOT 188-<step>` with the measured rect.
///
///  * **Bug:** with the dropdown open, the rect is the full screen
///    (`L0 T0 R<width> B<height>`) and both app bar buttons are gone.
///  * **Fixed:** the rect is the menu's own bounds, like the popup menu,
///    sheet and dialog, and the app bar buttons stay (dimmed by nothing:
///    the dropdown has no barrier colour).
class Issue188DropdownModalRectTestPage extends StatefulWidget {
  const Issue188DropdownModalRectTestPage({super.key, this.autoCycle = false});

  /// Opens and closes each modal, printing `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue188DropdownModalRectTestPage> createState() =>
      _Issue188DropdownModalRectTestPageState();
}

class _Issue188DropdownModalRectTestPageState
    extends State<Issue188DropdownModalRectTestPage> {
  final _dropdownKey = GlobalKey();
  final _popupKey = GlobalKey<PopupMenuButtonState<String>>();
  final _leadingKey = GlobalKey();
  final _actionKey = GlobalKey();
  bool _autoHide = true;
  String _fruit = 'Apple';
  int _pointer = 900;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _tapCentre(GlobalKey key) async {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final centre = box.localToGlobal(box.size.center(Offset.zero));
    final p = _pointer++;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: p, position: centre),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(pointer: p, position: centre),
    );
  }

  Future<void> _shot(String step) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    debugPrint('CNB_RECT188 $step ${_describe()}');
    debugPrint('CNB_SHOT 188-$step');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  }

  Future<void> _close() async {
    if (!mounted) return;
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 900));
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    await _shot('idle');
    for (final autoHide in [true, false]) {
      if (!mounted) return;
      setState(() => _autoHide = autoHide);
      final tag = autoHide ? 'hide' : 'keep';
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _tapCentre(_dropdownKey);
      await _shot('dropdown-$tag');
      await _close();
      if (!autoHide) break;
      _popupKey.currentState?.showButtonMenu();
      await _shot('popup-$tag');
      await _close();
      _openSheet();
      await _shot('sheet-$tag');
      await _close();
      _openDialog();
      await _shot('dialog-$tag');
      await _close();
    }
    debugPrint('CNB_SHOT 188-done');
  }

  Rect? _globalRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  String _describe() {
    String f(double v) => v.toStringAsFixed(0);
    final depth = CNTabBarRouteObserver.anyModalDepth.value;
    final r = CNTabBarRouteObserver.modalRect;
    final screen = MediaQuery.sizeOf(context);
    final rect = r == null
        ? 'unknown'
        : 'L${f(r.left)} T${f(r.top)} R${f(r.right)} B${f(r.bottom)}';
    final buttons = [_leadingKey, _actionKey].map(_globalRect).nonNulls;
    final covers =
        depth > 0 && (r == null || buttons.any((b) => b.overlaps(r)));
    return 'depth=$depth rect=$rect screen=${f(screen.width)}x'
        '${f(screen.height)} coversAppBarButtons=$covers';
  }

  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const SizedBox(
        height: 220,
        child: Center(child: Text('Small bottom sheet')),
      ),
    );
  }

  void _openDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => Center(
        child: Material(
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            width: 260,
            height: 140,
            child: Center(child: Text('Dialog')),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: SizedBox(
            key: _leadingKey,
            width: 44,
            height: 44,
            child: CNButton.icon(
              icon: const CNSymbol('chevron.left'),
              autoHideOnModal: _autoHide,
              onPressed: () {},
            ),
          ),
        ),
        title: const Text('#188 Dropdown'),
        actions: [
          SizedBox(
            key: _actionKey,
            width: 44,
            height: 44,
            child: CNButton.icon(
              icon: const CNSymbol('ellipsis'),
              autoHideOnModal: _autoHide,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<int>(
            valueListenable: CNTabBarRouteObserver.anyModalDepth,
            builder: (context, _, _) => ValueListenableBuilder<Rect?>(
              valueListenable: CNTabBarRouteObserver.routeModalRect,
              builder: (context, _, _) => Text(
                _describe().replaceAll(' ', '\n'),
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('autoHideOnModal'),
              const Spacer(),
              CupertinoSwitch(
                value: _autoHide,
                onChanged: (v) => setState(() => _autoHide = v),
              ),
            ],
          ),
          const SizedBox(height: 120),
          Center(
            child: DropdownButton<String>(
              key: _dropdownKey,
              value: _fruit,
              items: [
                for (final f in ['Apple', 'Banana', 'Cherry', 'Date'])
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (v) => setState(() => _fruit = v ?? _fruit),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: PopupMenuButton<String>(
              key: _popupKey,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'a', child: Text('Popup item A')),
                PopupMenuItem(value: 'b', child: Text('Popup item B')),
              ],
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Text('PopupMenuButton'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          CupertinoButton(
            onPressed: _openSheet,
            child: const Text('Small bottom sheet'),
          ),
          CupertinoButton(onPressed: _openDialog, child: const Text('Dialog')),
        ],
      ),
    );
  }
}
