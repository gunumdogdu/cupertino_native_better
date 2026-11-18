import 'dart:ui' as ui;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #176: Reduce Transparency for Flutter, and a shorter
/// `CNScrollEdgeEffect` band in that mode.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/176
/// Reported by @Ashhad08.
///
/// ### The request
///
/// Flutter has no Reduce Transparency flag, so an app that draws its own
/// blur can't swap it for a solid colour when the user turns the setting on.
/// And with Reduce Transparency on, iOS draws `CNScrollEdgeEffect` as an
/// opaque band: a band sized for a soft blur behind a whole floating bar
/// becomes a tall slab that hides the content.
///
/// ### How this screen proves it
///
/// A list of coloured rows under a floating contact bar drawn in Flutter,
/// with a bottom `CNScrollEdgeEffect` as tall as the bar. The bar follows
/// `CNAccessibility.reduceTransparency`: a blur when the setting is off, a
/// solid colour when it is on. The segmented control picks the effect's
/// `reduceTransparencyHeight`: 34 (the home indicator area), none (the
/// whole bar) or 0. Turn Reduce Transparency on and off in Settings, with
/// the app running:
///
///  * **Before:** the bar stays a blur, and with the setting on the effect
///    is an opaque band as tall as the bar.
///  * **Now:** the line at the top and the bar change at once; with 34 the
///    opaque band covers only the home indicator area, with 0 there is none.
///
/// AUTO prints `CNB_READY 176` and `CNB_RT on|off` on every change.
class Issue176ReduceTransparencyTestPage extends StatefulWidget {
  /// Creates the #176 test page.
  const Issue176ReduceTransparencyTestPage({
    super.key,
    this.autoCycle = false,
    this.initialMode = '34',
  });

  /// Prints `CNB_READY 176` and `CNB_RT on|off`.
  final bool autoCycle;

  /// The `reduceTransparencyHeight` picked at the start: '34', 'none' or
  /// '0'.
  final String initialMode;

  @override
  State<Issue176ReduceTransparencyTestPage> createState() =>
      _Issue176ReduceTransparencyTestPageState();
}

class _Issue176ReduceTransparencyTestPageState
    extends State<Issue176ReduceTransparencyTestPage> {
  static const _barHeight = 64.0;
  static const _modes = ['34', 'none', '0'];
  late String _mode = _modes.contains(widget.initialMode)
      ? widget.initialMode
      : _modes.first;

  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    CNAccessibility.reduceTransparency.addListener(_log);
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        debugPrint('CNB_READY 176');
        _log();
      });
    }
  }

  @override
  void dispose() {
    CNAccessibility.reduceTransparency.removeListener(_log);
    _controller.dispose();
    super.dispose();
  }

  void _log() {
    final on = CNAccessibility.reduceTransparency.value;
    debugPrint('CNB_RT ${on ? 'on' : 'off'} mode=$_mode');
  }

  double? get _rtHeight => switch (_mode) {
    '34' => 34,
    '0' => 0,
    _ => null,
  };

  static const _colors = [
    CupertinoColors.systemRed,
    CupertinoColors.systemOrange,
    CupertinoColors.systemYellow,
    CupertinoColors.systemGreen,
    CupertinoColors.systemTeal,
    CupertinoColors.systemBlue,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPurple,
  ];

  Widget _contactBar(BuildContext context, double bottomInset) {
    final bar = Row(
      children: [
        const Expanded(
          child: Text(
            'Contact the seller',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          onPressed: () {},
          child: const Text('Call'),
        ),
      ],
    );
    return ValueListenableBuilder<bool>(
      valueListenable: CNAccessibility.reduceTransparency,
      builder: (context, reduce, child) {
        final panel = Container(
          height: _barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: reduce
                ? CupertinoColors.secondarySystemBackground.resolveFrom(context)
                : CupertinoColors.systemBackground
                      .resolveFrom(context)
                      .withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: reduce
                ? panel
                : BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: panel,
                  ),
          ),
        );
      },
      child: bar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final caption = TextStyle(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#176 Reduce Transparency'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: CNAccessibility.reduceTransparency,
                    builder: (_, reduce, _) => Text(
                      'Reduce Transparency: ${reduce ? 'On' : 'Off'}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bottom effect height: the bar. reduceTransparencyHeight:',
                    style: caption,
                  ),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: _mode,
                    children: const {
                      '34': Text('34'),
                      'none': Text('none'),
                      '0': Text('0'),
                    },
                    onValueChanged: (m) {
                      if (m == null) return;
                      setState(() => _mode = m);
                      _log();
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _controller,
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: bottomInset + _barHeight + 24,
                  ),
                  itemCount: 40,
                  itemExtent: 56,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _colors[i % _colors.length],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'Row $i',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                CNScrollEdgeEffect(
                  edge: CNScrollEdge.bottom,
                  controller: _controller,
                  height: bottomInset + _barHeight + 8,
                  reduceTransparencyHeight: _rtHeight,
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _contactBar(context, bottomInset),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
