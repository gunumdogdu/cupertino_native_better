import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #126 reproduction: `CNSearchBarController` methods do nothing on
/// iOS.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/126
/// Reported by @cogwheel0.
///
/// ### The claim
///
/// `CNSearchBarController.setText`, `clear`, `focus` and `unfocus` complete
/// without error on iOS, but the field does not change. The iOS platform view
/// answers each call with `result(nil)` and never touches the SwiftUI state
/// that backs the field. `expand` and `collapse` are answered the same way.
/// macOS implements all six.
///
/// ### How this screen proves it
///
/// The search bar starts expanded and empty. Each button sends one
/// controller call; the log under the buttons lists every call made and
/// every `onChanged` / `onExpandStateChanged` the bar reported back.
///
///  * **setText "kite"**: the field must show `kite`, and the log must show
///    `onChanged: kite`.
///  * **focus**: the keyboard must come up with the cursor in the field.
///  * **unfocus**: type something first, then tap it: the keyboard must go
///    down.
///  * **clear**: the field must empty, and the log must show `onChanged: ""`.
///  * **collapse / expand**: the bar must shrink to the round search button
///    and grow back.
///
/// **Bug present:** the call shows up in the log, but the field does not
/// change and no callback follows it.
///
/// **Bug fixed:** every button does what its name says, and the callbacks
/// follow in the log.
///
/// [autoCycle] runs the steps on its own and prints `CNB_SHOT <step>` after
/// each, for simulator screenshots.
class Issue126SearchBarControllerTestPage extends StatefulWidget {
  const Issue126SearchBarControllerTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Runs every button in turn, for simulator screenshots.
  final bool autoCycle;

  @override
  State<Issue126SearchBarControllerTestPage> createState() =>
      _Issue126SearchBarControllerTestPageState();
}

class _Issue126SearchBarControllerTestPageState
    extends State<Issue126SearchBarControllerTestPage> {
  final CNSearchBarController _controller = CNSearchBarController();
  final List<String> _log = <String>[];

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _runSteps();
  }

  Future<void> _runSteps() async {
    final steps = <(String, Future<void> Function())>[
      ('settext', () => _controller.setText('kite')),
      ('focus', _controller.focus),
      ('unfocus', _controller.unfocus),
      ('clear', _controller.clear),
      ('collapse', _controller.collapse),
      ('expand', _controller.expand),
    ];
    await Future<void>.delayed(const Duration(seconds: 3));
    for (final (name, call) in steps) {
      if (!mounted) return;
      await _call(name, call);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      debugPrint('CNB_SHOT 126-$name');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }

  void _record(String line) {
    setState(() {
      _log.insert(0, line);
      if (_log.length > 12) _log.removeLast();
    });
  }

  Future<void> _call(String name, Future<void> Function() call) async {
    _record('→ $name');
    try {
      await call();
    } catch (e) {
      _record('  $name threw: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#126: SearchBar controller'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            SizedBox(
              height: 44,
              child: CNSearchBar(
                controller: _controller,
                placeholder: 'Search',
                initiallyExpanded: true,
                onChanged: (text) => _record('onChanged: "$text"'),
                onSubmitted: (text) => _record('onSubmitted: "$text"'),
                onExpandStateChanged: (expanded) =>
                    _record('onExpandStateChanged: $expanded'),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Button(
                  'setText "kite"',
                  () => _call(
                    'setText("kite")',
                    () => _controller.setText('kite'),
                  ),
                ),
                _Button('focus', () => _call('focus()', _controller.focus)),
                _Button(
                  'unfocus',
                  () => _call('unfocus()', _controller.unfocus),
                ),
                _Button('clear', () => _call('clear()', _controller.clear)),
                _Button(
                  'collapse',
                  () => _call('collapse()', _controller.collapse),
                ),
                _Button('expand', () => _call('expand()', _controller.expand)),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Bug: the call shows in the log, but the field does not change '
              'and no callback follows.\n'
              'Fixed: each button does what it says, and onChanged / '
              'onExpandStateChanged follow in the log.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(
                  context,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _log.isEmpty ? 'Log (newest first)' : _log.join('\n'),
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.tinted(
      sizeStyle: CupertinoButtonSize.small,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
