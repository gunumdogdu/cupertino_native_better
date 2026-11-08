import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #130 reproduction: `CNIcon.replaceTransition` is cut short when the
/// colour changes in the same rebuild (iOS).
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/130
/// Reported by @cogwheel0.
///
/// ### The claim
///
/// Dart sends a symbol and colour change as two calls: `setSymbol`, then
/// `setStyle`. On iOS, `setSymbol` starts the replace transition. `setStyle`
/// then rebuilds the image, finds the symbol already shown under the new
/// name, and assigns it directly, which replaces the image the transition
/// was animating to.
///
/// ### How this screen proves it
///
/// Two large icons side by side, both with `replaceTransition: replace`.
///
///  * **Left — symbol only:** play ↔ pause, colour unchanged. The control:
///    the replace transition plays (the old symbol shrinks and blurs away,
///    the new one grows in).
///  * **Right — symbol + colour:** play ↔ pause and blue ↔ grey in the same
///    `setState`, as in the report (a play button that turns into a
///    disabled pause while something loads).
///
/// Tap **Toggle** and compare the two.
///
///  * **Bug present:** the right icon jumps to the new symbol without the
///    transition (or the transition stops after a frame), while the left one
///    animates.
///  * **Bug fixed:** both icons animate the same way, and the right one ends
///    on the new symbol in the new colour.
///
/// [autoCycle] presses **Toggle** every three seconds and prints
/// `CNB_SHOT 130-toggle<n>` at each press, for a simulator recording.
class Issue130IconReplaceColorTestPage extends StatefulWidget {
  const Issue130IconReplaceColorTestPage({super.key, this.autoCycle = false});

  /// Toggles on its own every three seconds, for simulator recordings.
  final bool autoCycle;

  @override
  State<Issue130IconReplaceColorTestPage> createState() =>
      _Issue130IconReplaceColorTestPageState();
}

class _Issue130IconReplaceColorTestPageState
    extends State<Issue130IconReplaceColorTestPage> {
  bool _playing = false;
  Timer? _cycle;
  int _toggles = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      _cycle = Timer.periodic(const Duration(seconds: 3), (_) {
        _toggles++;
        debugPrint('CNB_SHOT 130-toggle$_toggles');
        setState(() => _playing = !_playing);
      });
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  CNSymbolReplaceTransition _transition = CNSymbolReplaceTransition.replace;

  @override
  Widget build(BuildContext context) {
    final name = _playing ? 'pause.fill' : 'play.fill';
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#130: Icon replace + colour'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            CupertinoSlidingSegmentedControl<CNSymbolReplaceTransition>(
              groupValue: _transition,
              onValueChanged: (t) {
                if (t != null) setState(() => _transition = t);
              },
              children: const <CNSymbolReplaceTransition, Widget>{
                CNSymbolReplaceTransition.replace: Text('replace'),
                CNSymbolReplaceTransition.downUp: Text('downUp'),
                CNSymbolReplaceTransition.offUp: Text('offUp'),
              },
            ),
            const SizedBox(height: 32),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Cell(
                    caption: 'symbol only\n(control)',
                    icon: CNIcon(
                      symbol: CNSymbol(name, size: 64),
                      color: CupertinoColors.systemBlue,
                      replaceTransition: _transition,
                    ),
                  ),
                ),
                Expanded(
                  child: _Cell(
                    caption: 'symbol + colour\n(the report)',
                    icon: CNIcon(
                      symbol: CNSymbol(name, size: 64),
                      color: _playing
                          ? CupertinoColors.systemGrey
                          : CupertinoColors.systemBlue,
                      replaceTransition: _transition,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: CupertinoButton.filled(
                onPressed: () => setState(() => _playing = !_playing),
                child: const Text('Toggle'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bug: the RIGHT icon jumps to the new symbol without the '
              'transition, while the left one animates.\n'
              'Fixed: both animate the same way; the right one ends on the '
              'new symbol in the new colour (grey pause, blue play).',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.caption, required this.icon});

  final String caption;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(width: 90, height: 90, child: Center(child: icon)),
        const SizedBox(height: 12),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
