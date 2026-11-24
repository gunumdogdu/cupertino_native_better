import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #190: a `CNGlassButtonGroup` that changes its number of buttons
/// keeps drawing them in its old width, and a group without badges is 6 pt
/// narrower than its frame on the right.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/190
///
/// ### The claim
///
/// 1. A group that stays mounted while its buttons change in number (an app
///    bar whose actions depend on the page, say 2 then 1) is resized by
///    Flutter, but on iOS the SwiftUI hosting view keeps its old width. The
///    buttons are centred in the old width and drawn past the group's frame:
///    about 20 pt for 2 to 1. A group created with 1 button is drawn right.
/// 2. The group always keeps 6 pt on its right for a badge, so with no badge
///    a right-aligned group stops 6 pt short of the edge it is aligned to,
///    while a left-aligned one lines up.
///
/// ### How this screen proves it
///
/// A bar like an app bar: a 1-button group on the left and a group on the
/// right, each with a magenta outline at its Flutter frame. **Buttons**
/// switches the right group between 1, 2 and 3 buttons, and **Badge** gives
/// its first button a count. AUTO switches 2, 1, 2, 3, 1 with and without a
/// badge, and prints `CNB_RECT190` with the group's Flutter rect after each
/// step.
///
///  * **Before:** after 2 to 1 the right glass reaches about 20 pt past its
///    outline, and without a badge the right group's glass ends 6 pt inside
///    its outline.
///  * **After:** the glass fills its outline after every switch, on both
///    sides; with a badge the group keeps 6 pt on its right for it.
class Issue190GlassButtonGroupResizeTestPage extends StatefulWidget {
  /// Creates the #190 test page.
  const Issue190GlassButtonGroupResizeTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Switches the right group through its steps and prints its rect.
  final bool autoCycle;

  @override
  State<Issue190GlassButtonGroupResizeTestPage> createState() =>
      _Issue190GlassButtonGroupResizeTestPageState();
}

class _Issue190GlassButtonGroupResizeTestPageState
    extends State<Issue190GlassButtonGroupResizeTestPage> {
  static const _symbols = ['plus', 'ellipsis', 'square.and.arrow.up'];
  static const _steps = [
    (2, false),
    (1, false),
    (2, false),
    (3, false),
    (1, false),
    (2, true),
    (1, true),
  ];

  final GlobalKey _rightKey = GlobalKey();
  int _count = 2;
  bool _badge = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      var step = 0;
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (step == _steps.length) {
          _timer?.cancel();
          return;
        }
        final (count, badge) = _steps[step++];
        setState(() {
          _count = count;
          _badge = badge;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _printRect());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _printRect() {
    final box = _rightKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    debugPrint(
      'CNB_RECT190 count=$_count badge=$_badge '
      'x=${origin.dx.toStringAsFixed(1)} w=${box.size.width.toStringAsFixed(1)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#190: Group resize'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // the bar: a fixed group on the left, the changing one on the right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Outlined(
                  child: CNGlassButtonGroup(
                    buttons: [
                      CNButtonData.icon(
                        icon: const CNSymbol('line.3.horizontal'),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                _Outlined(
                  key: _rightKey,
                  child: CNGlassButtonGroup(
                    buttons: [
                      for (var i = 0; i < _count; i++)
                        CNButtonData.icon(
                          icon: CNSymbol(_symbols[i]),
                          badgeCount: i == 0 && _badge ? 3 : null,
                          onPressed: () {},
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Buttons'),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _count,
              children: const {1: Text('1'), 2: Text('2'), 3: Text('3')},
              onValueChanged: (value) => setState(() => _count = value ?? 2),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Badge on the first button')),
                CupertinoSwitch(
                  value: _badge,
                  onChanged: (value) => setState(() => _badge = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'The glass should fill each magenta outline after every '
              'switch. Before the fix, going from 2 buttons to 1 drew the '
              'right group about 20 pt past its outline, and without a '
              'badge its glass ended 6 pt inside the outline.',
            ),
          ],
        ),
      ),
    );
  }
}

/// A magenta outline at the child's Flutter frame.
class _Outlined extends StatelessWidget {
  const _Outlined({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFF00FF)),
      ),
      child: child,
    );
  }
}
