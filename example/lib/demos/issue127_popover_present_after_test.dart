import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Issue #127 reproduction: `CNPopover.show` completes while the popover is
/// still animating away, so presenting something from its result fails.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/127
/// Reported by @cogwheel0.
///
/// ### The claim
///
/// When a row or button is chosen, the iOS popover starts
/// `dismiss(animated: true)` and answers the Dart call in the same moment. An
/// app that presents something from that answer (an in-app browser, a share
/// sheet, an alert) does it while UIKit is still dismissing the popover, and
/// UIKit drops the new presentation with only a log line.
///
/// Found while checking it: `CNAlert` picks the top of the presentation
/// chain, which at that moment is the popover on its way out. UIKit drops the
/// alert, and as nothing answers the call, `CNAlert.show` may never complete.
///
/// ### How this screen proves it
///
/// Each button opens a popover with an **Open** button. Choose **Open**; the
/// app then presents a native alert from the result, either at once (the
/// report) or 700 ms later (the reporter's workaround, the control). The
/// status line says what the alert call returned, or that it is still
/// waiting.
///
///  * **Bug present:** with *At once*, no alert appears. The status stays at
///    `alert: waiting…` (the call never completes) or shows `alert: null`
///    without an alert having been on screen.
///  * **Bug fixed:** with *At once*, the alert slides in as soon as the
///    popover has gone. Tap OK and the status shows `alert: ok`.
///  * **Control:** with *After 700 ms*, the alert appears on every build.
///
/// *Dismiss from code → alert* (found while checking it) opens a popover,
/// closes it with `CNPopover.dismiss()` a second later and calls
/// `CNAlert.show` at once, while the popover is still leaving. **Bug:** no
/// alert and the status stays at `alert: waiting…`. **Fixed:** the alert
/// appears once the popover has gone; OK shows `alert: ok`.
///
/// *Popover → popover* opens a second popover from the first one's result.
/// `CNPopover` already waits for the first to finish leaving, so this one
/// works before and after the fix; it shows the difference.
///
/// [autoCycle] opens the *At once* popover by itself and prints
/// `CNB_SHOT 127-popover`; choosing **Open** is left to the tester.
class Issue127PopoverPresentAfterTestPage extends StatefulWidget {
  const Issue127PopoverPresentAfterTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Opens the first popover on its own, for simulator runs.
  final bool autoCycle;

  @override
  State<Issue127PopoverPresentAfterTestPage> createState() =>
      _Issue127PopoverPresentAfterTestPageState();
}

class _Issue127PopoverPresentAfterTestPageState
    extends State<Issue127PopoverPresentAfterTestPage> {
  final GlobalKey _nowKey = GlobalKey();
  final GlobalKey _laterKey = GlobalKey();
  final GlobalKey _popoverKey = GlobalKey();
  final GlobalKey _codeKey = GlobalKey();
  String _status = 'Choose a button, then Open in the popover.';

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        _thenAlert(_nowKey, wait: false);
        Future<void>.delayed(
          const Duration(milliseconds: 1500),
          () => debugPrint('CNB_SHOT 127-popover'),
        );
      });
    }
  }

  CNPopoverContent get _content => const CNPopoverContent(
    title: 'Example source',
    message: 'example.com',
    actions: <CNPopoverAction>[
      CNPopoverAction.cancel(label: 'Cancel'),
      CNPopoverAction(id: 'open', label: 'Open'),
    ],
  );

  Future<void> _thenAlert(GlobalKey anchor, {required bool wait}) async {
    final choice = await CNPopover.show(
      context: context,
      anchorKey: anchor,
      content: _content,
    );
    if (!mounted) return;
    if (choice != 'open') {
      setState(() => _status = 'popover → $choice');
      return;
    }
    if (wait) await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(
      () => _status =
          'popover → open\n'
          'alert (${wait ? 'after 700 ms' : 'at once'}): waiting…',
    );
    final result = await CNAlert.show<String>(
      context: context,
      title: 'Opened',
      message: 'This alert was presented from the popover result.',
      actions: const <CNAlertAction<String>>[
        CNAlertAction(label: 'OK', value: 'ok', isDefault: true),
      ],
    );
    if (!mounted) return;
    setState(
      () => _status =
          'popover → open\n'
          'alert (${wait ? 'after 700 ms' : 'at once'}): '
          '${result?.value ?? 'null'}',
    );
  }

  /// Opens a popover, closes it from code a second later and shows an alert
  /// at once, while the popover is still animating away. `CNAlert` has to
  /// wait for it instead of being dropped (found while checking #127).
  Future<void> _dismissThenAlert() async {
    final shown = CNPopover.show(
      context: context,
      anchorKey: _codeKey,
      content: const CNPopoverContent(
        title: 'Closing from code',
        message: 'An alert follows as this popover leaves.',
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _status = 'dismiss from code\nalert: waiting…');
    await CNPopover.dismiss();
    if (!mounted) return;
    final result = await CNAlert.show<String>(
      context: context,
      title: 'After dismiss',
      message: 'Shown while the popover was closing.',
      actions: const <CNAlertAction<String>>[
        CNAlertAction(label: 'OK', value: 'ok', isDefault: true),
      ],
    );
    await shown;
    if (!mounted) return;
    setState(
      () => _status = 'dismiss from code\nalert: ${result?.value ?? 'null'}',
    );
  }

  Future<void> _thenPopover() async {
    final choice = await CNPopover.show(
      context: context,
      anchorKey: _popoverKey,
      content: _content,
    );
    if (!mounted) return;
    if (choice != 'open') {
      setState(() => _status = 'popover → $choice');
      return;
    }
    setState(() => _status = 'popover → open\nsecond popover: waiting…');
    final second = await CNPopover.show(
      context: context,
      anchorKey: _popoverKey,
      content: const CNPopoverContent(
        title: 'Second popover',
        message: 'Presented from the first one\'s result.',
        actions: <CNPopoverAction>[CNPopoverAction(id: 'done', label: 'Done')],
      ),
    );
    if (!mounted) return;
    setState(
      () => _status = 'popover → open\nsecond popover: ${second ?? 'null'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#127: Present after popover'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _Row(
              anchor: _nowKey,
              label: 'Popover → alert, at once',
              caption: 'the report',
              onPressed: () => _thenAlert(_nowKey, wait: false),
            ),
            _Row(
              anchor: _laterKey,
              label: 'Popover → alert, after 700 ms',
              caption: 'control: the workaround',
              onPressed: () => _thenAlert(_laterKey, wait: true),
            ),
            _Row(
              anchor: _popoverKey,
              label: 'Popover → popover',
              caption: 'control: already waits',
              onPressed: _thenPopover,
            ),
            _Row(
              anchor: _codeKey,
              label: 'Dismiss from code → alert',
              caption: 'found: CNAlert during a dismissal',
              onPressed: _dismissThenAlert,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(
                  context,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _status,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bug: "at once" shows no alert; the status stays at waiting… '
              'or shows null.\n'
              'Fixed: the alert appears as soon as the popover has gone, and '
              'OK shows "ok".\n'
              'Control: "after 700 ms" and "popover → popover" work either '
              'way.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.anchor,
    required this.label,
    required this.caption,
    required this.onPressed,
  });

  final GlobalKey anchor;
  final String label;
  final String caption;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          CupertinoButton.filled(
            key: anchor,
            sizeStyle: CupertinoButtonSize.medium,
            onPressed: onPressed,
            child: Text(label),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
