import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Issue #135 reproduction: a `CNPopover` that can't be shown returns null
/// like a cancel, and a popover has no progress or gauge row.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/135
/// Reported by @cogwheel0.
///
/// ### The claims
///
/// 1. `CNPopover.show` answers null when the anchor has no rect, when the
///    native side reports an error, and when UIKit refuses the
///    presentation, just as when the user closes it. The app can't fall
///    back to another UI.
/// 2. Feature request: a native progress/gauge row (storage used, a quota).
///
/// ### How this screen proves it
///
///  * **Gauges**: opens a popover with two `CNPopoverGauge`s under the
///    message: "Storage, 42 GB of 128 GB" with its bar a third full, and
///    "Quota" in orange at 90%, above an action. VoiceOver reads each as
///    "Storage, 42 GB of 128 GB".
///  * **Refused**: presents a `CNAlert` and, in the same frame, a popover
///    with `throwOnFailure: true`. UIKit refuses the popover while the alert
///    is coming in. **Fixed:** the status shows
///    `PlatformException(refused)`. Without `throwOnFailure` (the old
///    behaviour) the same failure shows as `null`, like a cancel.
///  * **Cancel**: open the gauges popover and tap outside: the status shows
///    `null`, and no exception.
class Issue135PopoverGaugeFailureTestPage extends StatefulWidget {
  const Issue135PopoverGaugeFailureTestPage({
    super.key,
    this.autoCycle = false,
  });

  /// Opens the gauges popover, then runs the refused case, printing
  /// `CNB_SHOT <step>`.
  final bool autoCycle;

  @override
  State<Issue135PopoverGaugeFailureTestPage> createState() =>
      _Issue135PopoverGaugeFailureTestPageState();
}

class _Issue135PopoverGaugeFailureTestPageState
    extends State<Issue135PopoverGaugeFailureTestPage> {
  final GlobalKey _anchor = GlobalKey();
  String _status = '—';

  static const _content = CNPopoverContent(
    title: 'iCloud',
    message: 'Your plan and what is used of it.',
    gauges: [
      CNPopoverGauge(
        label: 'Storage',
        value: 42,
        max: 128,
        valueText: '42 GB of 128 GB',
      ),
      CNPopoverGauge(
        label: 'Quota',
        value: 0.9,
        valueText: '90%',
        tint: CupertinoColors.systemOrange,
      ),
    ],
    actions: [
      CNPopoverAction(
        id: 'manage',
        label: 'Manage',
        style: CNPopoverActionStyle.defaultAction,
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoCycle) _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final gauges = _showGauges();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    debugPrint('CNB_SHOT 135-gauges');
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    await CNPopover.dismiss();
    await gauges;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final refused = _showRefused(throwOnFailure: true);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    debugPrint('CNB_SHOT 135-refused');
    await refused;
  }

  Future<void> _showGauges() async {
    final result = await CNPopover.show(
      context: context,
      anchorKey: _anchor,
      content: _content,
      throwOnFailure: true,
    );
    if (mounted) setState(() => _status = 'gauges → $result');
  }

  /// A popover in the same frame as an alert: UIKit refuses it.
  Future<void> _showRefused({required bool throwOnFailure}) async {
    final alert = CNAlert.show<String>(
      context: context,
      title: 'An alert',
      message: 'The popover tried to open with it.',
      actions: const [CNAlertAction(label: 'OK', value: 'ok')],
    );
    String status;
    try {
      final result = await CNPopover.show(
        context: context,
        anchorKey: _anchor,
        content: _content,
        throwOnFailure: throwOnFailure,
      );
      status = 'popover → $result';
    } on PlatformException catch (e) {
      status = 'popover → PlatformException(${e.code})';
    }
    if (mounted) setState(() => _status = status);
    debugPrint('CNB_135 $status');
    await alert;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#135: Popover gauges, failures'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CupertinoButton.filled(
                key: _anchor,
                onPressed: _showGauges,
                child: const Text('Gauges'),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: () => _showRefused(throwOnFailure: true),
              child: const Text('Refused (throwOnFailure)'),
            ),
            CupertinoButton(
              onPressed: () => _showRefused(throwOnFailure: false),
              child: const Text('Refused (default)'),
            ),
            const SizedBox(height: 16),
            Text(
              'status: $_status',
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gauges: two labelled bars under the message.\n'
              'Refused (throwOnFailure): PlatformException(refused).\n'
              'Refused (default): null, as before.\n'
              'Tap outside the gauges popover: null.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
