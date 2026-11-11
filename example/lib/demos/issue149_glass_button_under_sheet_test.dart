import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

/// Issue #149 reproduction: a glass `CNButton` loses its glass while a
/// bottom sheet is open, even when the sheet is nowhere near the button.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/149
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// Only sheets opened through `CNBottomSheet` publish their frame, so with
/// any other sheet `ModalHideMixin` can't tell where the sheet is and hides
/// every CN widget on the page (`autoHideOnModal: true`). With
/// `autoHideOnModal: false` the widget stays, but `HaloContainmentMixin`
/// clips its glass for as long as any modal is up, so it looks flat.
///
/// ### How this screen proves it
///
/// Two glass close buttons in the header, over a striped backdrop: **A**
/// with the default `autoHideOnModal: true`, **B** with `false`. The sheets
/// below open at about 40% of the screen height, well below the header.
/// AUTO opens each sheet in turn and prints `CNB_SHOT 149-<sheet>-up`,
/// `-closing` and `-closed`.
///
///  * **Bug:** with `showModalBottomSheet` and `showCupertinoModalPopup`, A
///    is gone while the sheet is up, and B is flat (no rim or shadow).
///  * **Fixed:** A and B look as they do with no sheet (dimmed by the
///    sheet's barrier, like the rest of the page), with every sheet API.
///  * `CNBottomSheet.showModalPopup` is the reference: it publishes its
///    frame, so A already stays.
class Issue149GlassButtonUnderSheetTestPage extends StatefulWidget {
  const Issue149GlassButtonUnderSheetTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Opens and closes each sheet, printing `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue149GlassButtonUnderSheetTestPage> createState() =>
      _Issue149GlassButtonUnderSheetTestPageState();
}

enum _Sheet { material, popup, cnPopup }

class _Issue149GlassButtonUnderSheetTestPageState
    extends State<Issue149GlassButtonUnderSheetTestPage> {
  int _closeTaps = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    debugPrint('CNB_SHOT 149-rest');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    for (final sheet in _Sheet.values) {
      if (!mounted) return;
      _open(sheet);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      debugPrint('CNB_SHOT 149-${sheet.name}-up');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      debugPrint('CNB_SHOT 149-${sheet.name}-closing');
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      debugPrint('CNB_SHOT 149-${sheet.name}-closed');
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    debugPrint('CNB_SHOT 149-done');
  }

  Future<void> _open(_Sheet sheet) {
    final height = MediaQuery.sizeOf(context).height * 0.4;
    Widget body(String title) => _SheetBody(title: title, height: height);
    switch (sheet) {
      case _Sheet.material:
        return showModalBottomSheet<void>(
          context: context,
          builder: (_) => body('showModalBottomSheet'),
        );
      case _Sheet.popup:
        return showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => body('showCupertinoModalPopup'),
        );
      case _Sheet.cnPopup:
        return CNBottomSheet.showModalPopup<void>(
          context: context,
          builder: (_) => body('CNBottomSheet.showModalPopup'),
        );
    }
  }

  Widget _closeButton({required bool autoHide}) {
    return CNButton.icon(
      icon: const CNSymbol('xmark', size: 17),
      config: const CNButtonConfig(
        style: CNButtonStyle.glass,
        width: 44,
        minHeight: 44,
      ),
      autoHideOnModal: autoHide,
      onPressed: () => setState(() => _closeTaps++),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          const Positioned.fill(child: _Stripes()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _closeButton(autoHide: true),
                      const SizedBox(width: 8),
                      const Text('A', style: _label),
                      const Spacer(),
                      const Text('B', style: _label),
                      const SizedBox(width: 8),
                      _closeButton(autoHide: false),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'A: autoHideOnModal true · B: false',
                    style: _caption,
                  ),
                ),
                const SizedBox(height: 24),
                for (final sheet in _Sheet.values)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: CupertinoButton.filled(
                      onPressed: () => _open(sheet),
                      child: Text(switch (sheet) {
                        _Sheet.material => 'showModalBottomSheet',
                        _Sheet.popup => 'showCupertinoModalPopup',
                        _Sheet.cnPopup => 'CNBottomSheet.showModalPopup',
                      }),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '#149 · close taps: $_closeTaps\n'
                    'Bug: A vanishes and B goes flat while a sheet is up. '
                    'Fixed: both keep their glass with every sheet.',
                    style: _caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _label = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: CupertinoColors.white,
);

const _caption = TextStyle(
  fontSize: 14,
  height: 1.4,
  color: CupertinoColors.white,
);

/// Diagonal stripes, so the glass's refraction and rim are easy to see.
class _Stripes extends StatelessWidget {
  const _Stripes();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment(-0.82, -0.86),
          tileMode: TileMode.repeated,
          colors: [
            Color(0xFF1F6FEB),
            Color(0xFF1F6FEB),
            Color(0xFFF4A261),
            Color(0xFFF4A261),
          ],
          stops: [0, 0.5, 0.5, 1],
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.height});

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label.resolveFrom(context),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
