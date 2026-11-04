import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Demo for `CNAlert`.
///
/// On iOS every trigger presents a real `UIAlertController` in `.alert` style,
/// so what you see is the system control: system typography and button
/// dividers, the destructive red, the preferred action in a heavier weight,
/// and — on iOS 26 — the Liquid Glass appearance the system applies with no
/// opt-in.
///
/// Unlike an action sheet, an alert is always centred and cannot be dismissed
/// by tapping outside it, so every scenario here has at least one button.
class AlertDemoPage extends StatefulWidget {
  const AlertDemoPage({super.key, this.autoScenario});

  /// When set, the named scenario fires on the first frame instead of waiting
  /// for a tap.
  ///
  /// The simulator here has no tap automation (see `lib/pr_probe_entry.dart`),
  /// so screenshot verification drives the page through this instead. One of:
  /// `twobutton`, `destructive`, `threebutton`, `titleonly`, `disabled`,
  /// `textfield`, `secure`, `twofields`, `supersede`.
  final String? autoScenario;

  @override
  State<AlertDemoPage> createState() => _AlertDemoPageState();
}

class _AlertDemoPageState extends State<AlertDemoPage> {
  String _lastResult = '—';

  @override
  void initState() {
    super.initState();
    final scenario = widget.autoScenario;
    if (scenario == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (scenario) {
        case 'twobutton':
          _showTwoButton();
        case 'destructive':
          _showDestructive();
        case 'threebutton':
          _showThreeButton();
        case 'titleonly':
          _showTitleOnly();
        case 'disabled':
          _showDisabled();
        case 'textfield':
          _showTextField();
        case 'secure':
          _showSecure();
        case 'twofields':
          _showTwoFields();
        case 'supersede':
          _showSupersede();
      }
    });
  }

  void _record(CNAlertResult<String>? result) {
    // Every caller awaits `CNAlert.show` first, and a superseded alert resolves
    // its caller as soon as the next one is requested, so the page can be gone
    // by the time the result lands.
    debugPrint(
      'CNB_RESULT alert ${result == null ? 'null' : 'value=${result.value} '
                'text=${result.textFields}'}',
    );
    if (!mounted) return;
    setState(() {
      _lastResult = result == null
          ? '(no answer)'
          : 'value=${result.value ?? 'null'} text=${result.textFields}';
    });
  }

  Future<void> _showTwoButton() async {
    _record(
      await CNAlert.show<String>(
        context: context,
        title: 'Turn on notifications?',
        message: 'You can change this later in Settings.',
        actions: const [
          CNAlertAction(label: 'Not now', value: 'later', isCancel: true),
          CNAlertAction(label: 'Allow', value: 'allow', isDefault: true),
        ],
      ),
    );
  }

  Future<void> _showDestructive() async {
    _record(
      await CNAlert.show<String>(
        context: context,
        title: 'Delete photo?',
        message: 'This cannot be undone.',
        actions: const [
          CNAlertAction(label: 'Cancel', value: 'cancel', isCancel: true),
          CNAlertAction(label: 'Delete', value: 'delete', isDestructive: true),
        ],
      ),
    );
  }

  /// Three buttons is past the HIG's recommended ceiling of two, which is what
  /// makes UIKit stack them vertically instead of laying them out side by side.
  Future<void> _showThreeButton() async {
    _record(
      await CNAlert.show<String>(
        context: context,
        title: 'Unsaved changes',
        message: 'What should happen to your draft?',
        actions: const [
          CNAlertAction(label: 'Save', value: 'save', isDefault: true),
          CNAlertAction(
            label: 'Discard',
            value: 'discard',
            isDestructive: true,
          ),
          CNAlertAction(label: 'Cancel', value: 'cancel', isCancel: true),
        ],
      ),
    );
  }

  Future<void> _showTitleOnly() async {
    _record(
      await CNAlert.show<String>(
        context: context,
        title: 'Saved',
        actions: const [
          CNAlertAction(label: 'OK', value: 'ok', isDefault: true),
        ],
      ),
    );
  }

  /// `enabled: false` blocks taps on every iOS version. Early iOS 26 also
  /// failed to grey the label out (Apple developer forums 794819 / 794833);
  /// iOS 26.2 renders it greyed out correctly.
  Future<void> _showDisabled() async {
    _record(
      await CNAlert.show<String>(
        context: context,
        title: 'Export',
        message: 'PDF export needs a paid plan.',
        actions: const [
          CNAlertAction(label: 'Export as PNG', value: 'png'),
          CNAlertAction(label: 'Export as PDF', value: 'pdf', enabled: false),
        ],
      ),
    );
  }

  Future<void> _showTextField() async {
    _record(
      await CNAlert.show<String>(
        context: context,
        title: 'Rename',
        message: 'Pick a new name for this album.',
        textFields: const [
          CNAlertTextField(placeholder: 'Name', initialText: 'Untitled'),
        ],
        actions: const [
          CNAlertAction(label: 'Cancel', value: 'cancel', isCancel: true),
          CNAlertAction(label: 'Save', value: 'save', isDefault: true),
        ],
      ),
    );
  }

  Future<void> _showSecure() async {
    _record(
      await CNAlert.show<String>(
        context: context,
        title: 'Sign in',
        message: 'Enter your password to continue.',
        textFields: const [
          CNAlertTextField(placeholder: 'Password', obscureText: true),
        ],
        actions: const [
          CNAlertAction(label: 'Cancel', value: 'cancel', isCancel: true),
          CNAlertAction(label: 'Sign in', value: 'signin', isDefault: true),
        ],
      ),
    );
  }

  /// Two fields prove the returned list keeps the order they were declared in.
  Future<void> _showTwoFields() async {
    _record(
      await CNAlert.show<String>(
        context: context,
        title: 'Log in',
        textFields: const [
          CNAlertTextField(placeholder: 'Username'),
          CNAlertTextField(placeholder: 'Password', obscureText: true),
        ],
        actions: const [
          CNAlertAction(label: 'Cancel', value: 'cancel', isCancel: true),
          CNAlertAction(label: 'Continue', value: 'continue', isDefault: true),
        ],
      ),
    );
  }

  /// Fires two `CNAlert.show` calls back to back, the second while the first
  /// alert is still animating in — the double-tap case.
  ///
  /// Expected: the "Second" alert is the one on screen, the first call resolves
  /// to null, and pressing OK reports `value=second`. Before the supersede fix
  /// this path left *no* alert on screen and the second call never resolved,
  /// because UIKit refuses a presentation onto a controller that is still
  /// dismissing the alert it replaces.
  Future<void> _showSupersede() async {
    final first = CNAlert.show<String>(
      context: context,
      title: 'First',
      message: 'Superseded before it can be answered.',
      actions: const [CNAlertAction(label: 'OK', value: 'first')],
    );
    final second = CNAlert.show<String>(
      context: context,
      title: 'Second',
      message: 'This is the alert that must be on screen.',
      actions: const [CNAlertAction(label: 'OK', value: 'second')],
    );

    debugPrint(
      'CNAlert supersede: first resolved to ${(await first)?.value ?? 'null'}',
    );
    _record(await second);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Alert')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Every trigger below presents a native UIAlertController in '
              '.alert style on iOS. The destructive label should be the system '
              'red, the default action a heavier weight, and the dialog drawn '
              'in the system material. An alert cannot be dismissed by tapping '
              'outside it, so each one has to be answered with a button.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text(
                    'Last result: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Text(
                      _lastResult,
                      style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _trigger('Two buttons + default', _showTwoButton),
            _trigger('Destructive + cancel', _showDestructive),
            _trigger('Three buttons (stacked)', _showThreeButton),
            _trigger('Title only', _showTitleOnly),
            _trigger('Disabled action', _showDisabled),
            _trigger('Text field', _showTextField),
            _trigger('Secure text field', _showSecure),
            _trigger('Two text fields', _showTwoFields),
            _trigger('Supersede (two shows at once)', _showSupersede),

            const SizedBox(height: 8),
            const Text(
              'Note: a disabled action refuses taps on every iOS version — '
              'press "Export as PDF" and nothing happens. Early iOS 26 also '
              'failed to grey the label out (Apple developer forums 794819 / '
              '794833); iOS 26.2 renders it greyed out correctly.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trigger(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: CNButton(label: label, onPressed: onPressed),
      ),
    );
  }
}
