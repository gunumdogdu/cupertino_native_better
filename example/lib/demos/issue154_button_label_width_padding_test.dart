import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #154 reproduction: a glass `CNButton` whose label changes often (an
/// image counter such as "7/12").
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/154
/// Reported by @Ashhad08.
///
/// ### The claim
///
/// 1. With `shrinkWrap: true`, `setButtonTitle` shows the new label at once,
///    inside the old width, and only then asks for the new size. For one
///    frame a wider label is drawn truncated (`8/…`), then the width snaps.
///    A new button also shows a frame at the 80 pt placeholder width.
/// 2. `CNButtonConfig.padding` top and bottom do nothing: only the
///    horizontal values reach the UIKit button, and Flutter sizes the
///    height from `minHeight ?? 44`.
///
/// ### How this screen proves it
///
/// The reporter's counter, on their grey background. Row A is shrink-wrapped,
/// row B is 90 pt wide (always clean). "Next" steps the counter; "Remount"
/// builds row A again. Rows C and D compare vertical and horizontal padding.
///
///  * **Bug:** a frame of row A shows the new label truncated or at the old
///    width, or at 80 pt after "Remount"; `v 4` and `v 20` are the same
///    height.
///  * **Fixed:** every frame of row A shows a whole label at its own width;
///    with `animateSizeChanges` (row A2) the glass eases to the new width;
///    `v 20` is taller than `v 4`.
///
/// Row E, found while reading the code: a tint or style change rebuilt the
/// UIKit configuration and dropped the padding and the label font. Bug: after
/// "Tint" the label grows to 17 pt with the system padding. Fixed: only the
/// colour changes.
class Issue154ButtonLabelWidthPaddingTestPage extends StatefulWidget {
  const Issue154ButtonLabelWidthPaddingTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Steps the counter every 0.7 s and remounts row A every eighth step.
  final bool autoCycle;

  @override
  State<Issue154ButtonLabelWidthPaddingTestPage> createState() =>
      _Issue154ButtonLabelWidthPaddingTestPageState();
}

class _Issue154ButtonLabelWidthPaddingTestPageState
    extends State<Issue154ButtonLabelWidthPaddingTestPage> {
  int _index = 7;
  int _generation = 0;
  int _steps = 0;
  bool _red = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        debugPrint('CNB_SHOT padding');
        setState(() => _red = true);
        Timer(const Duration(milliseconds: 800), () {
          if (mounted) debugPrint('CNB_SHOT tinted');
        });
        _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
          if (!mounted) return;
          _steps++;
          if (_steps % 8 == 0) {
            setState(() => _generation++);
            debugPrint('CNB_STEP remount');
          } else {
            _next();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    setState(() => _index = _index == 12 ? 1 : _index + 1);
    debugPrint('CNB_STEP $_index/12');
  }

  CNButtonConfig _counter({required bool shrinkWrap, bool animate = false}) =>
      CNButtonConfig(
        style: CNButtonStyle.glass,
        shrinkWrap: shrinkWrap,
        animateSizeChanges: animate,
        minHeight: 25,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        labelFontSize: 14,
        labelFontWeight: FontWeight.w500,
      );

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
    ),
  );

  Widget _padded(String label, EdgeInsets padding) => CNButton(
    label: label,
    onPressed: () {},
    config: CNButtonConfig(
      style: CNButtonStyle.glass,
      shrinkWrap: true,
      padding: padding,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final label = '$_index/12';
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF8E8E93),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#154: Button label width'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                CupertinoButton.filled(
                  sizeStyle: CupertinoButtonSize.small,
                  onPressed: _next,
                  child: const Text('Next'),
                ),
                const SizedBox(width: 12),
                CupertinoButton.filled(
                  sizeStyle: CupertinoButtonSize.small,
                  onPressed: () => setState(() => _generation++),
                  child: const Text('Remount'),
                ),
                const SizedBox(width: 12),
                CupertinoButton.filled(
                  sizeStyle: CupertinoButtonSize.small,
                  onPressed: () => setState(() => _red = !_red),
                  child: const Text('Tint'),
                ),
              ],
            ),
            _caption('A: shrinkWrap: true'),
            Row(
              children: [
                KeyedSubtree(
                  key: ValueKey('a$_generation'),
                  child: CNButton(
                    label: label,
                    onPressed: () {},
                    config: _counter(shrinkWrap: true),
                  ),
                ),
              ],
            ),
            _caption('A2: shrinkWrap + animateSizeChanges'),
            Row(
              children: [
                KeyedSubtree(
                  key: ValueKey('a2$_generation'),
                  child: CNButton(
                    label: label,
                    onPressed: () {},
                    config: _counter(shrinkWrap: true, animate: true),
                  ),
                ),
              ],
            ),
            _caption('B: SizedBox(width: 90), shrinkWrap: false'),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: CNButton(
                    label: label,
                    onPressed: () {},
                    config: _counter(shrinkWrap: false),
                  ),
                ),
              ],
            ),
            _caption('C: padding vertical 4 vs vertical 20'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _padded(
                  'v 4',
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                const SizedBox(width: 16),
                _padded(
                  'v 20',
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                ),
              ],
            ),
            _caption('D: padding horizontal 4 vs horizontal 40'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _padded(
                  'h 4',
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                ),
                const SizedBox(width: 16),
                _padded(
                  'h 40',
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                ),
              ],
            ),
            _caption('E: "Tint" keeps the padding and the 14 pt font'),
            Row(
              children: [
                CNButton(
                  label: 'Tinted 14 pt',
                  tint: _red
                      ? CupertinoColors.systemRed
                      : CupertinoColors.systemBlue,
                  onPressed: () {},
                  config: const CNButtonConfig(
                    style: CNButtonStyle.glass,
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    labelFontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
