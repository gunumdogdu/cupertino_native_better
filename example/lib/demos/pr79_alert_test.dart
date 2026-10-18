import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// PR #79 verification — there is no native alert; the only option is a
/// Flutter-drawn `CupertinoAlertDialog`.
///
/// PR: https://github.com/gunumdogdu/cupertino_native_better/pull/79
/// Contributed by @yagizdo.
///
/// ### The claim
///
/// This is a feature PR (`CNAlert`, a real `UIAlertController` in `.alert`
/// style), so the "bug" is what an app gets today. Its only alert is
/// Flutter's `CupertinoAlertDialog` behind `showCupertinoDialog`, which:
///
///  * is drawn by Flutter, so on iOS 26 it keeps the pre-26 look — it does
///    not get the system Liquid Glass alert appearance;
///  * is a Flutter `PopupRoute`, so `CNTabBarRouteObserver` counts it in
///    `anyModalDepth`, and every inline CN platform view on the page that
///    uses `ModalHideMixin` (buttons, segmented controls, …) is **destroyed**
///    while it is up and recreated when it closes. A native
///    `UIAlertController` is a UIKit presentation, not a Flutter route, so it
///    should leave them alone.
///
/// ### How this screen proves it
///
/// The top strip holds three inline native widgets (two glass `CNButton`s
/// and a `CNSegmentedControl`), and the readout shows `anyModalDepth` live.
/// Each scenario matches one in the PR's demo page and has a **Flutter**
/// button (today's dialog) and a **Native** button (`CNAlert`) built from the
/// same description:
///
///  * **Gap present (Flutter):** the pre-iOS 26 look; while it is up the
///    readout says `modal depth 1 · strip torn down` and the strip blinks
///    back after dismiss.
///  * **Fixed (Native):** the iOS 26 system alert look; the strip stays
///    visible under the system dim and the depth stays `0`; the same taps
///    and typing return the same value/text as Flutter.
///
/// The **Native stress** rows exercise the paths the review flagged. Each
/// call gets its own slot in the readout (`#1 … · #2 …`); a slot stuck on
/// `pending…` after every alert is gone is a call that never resolves.
///
///  * *Show twice at once* — expected `#1 (no answer)` at once and the
///    second alert (Delete photo?) on screen.
///  * *Second alert after 1 s* — the first alert is replaced after a second;
///    expected `#1 (no answer)`.
///  * *Chained* — answer the first, then Delete photo? opens by itself.
///  * *All actions disabled* — expected `#1 (no answer)` at once and nothing
///    on screen.
///  * *From a CNBottomSheet* — the native alert opens above a Flutter bottom
///    sheet and answers normally.
class Pr79AlertTestPage extends StatefulWidget {
  const Pr79AlertTestPage({super.key});

  @override
  State<Pr79AlertTestPage> createState() => _Pr79AlertTestPageState();
}

typedef _Field = ({String placeholder, String initial, bool obscure});

typedef _Action = ({
  String label,
  String value,
  bool isDefault,
  bool destructive,
});

typedef _Alert = ({
  String title,
  String? message,
  List<_Field> fields,
  List<_Action> actions,
  Set<String> disabled,
});

class _Pr79AlertTestPageState extends State<Pr79AlertTestPage> {
  static const _Alert _twoButton = (
    title: 'Turn on notifications?',
    message: 'You can change this later in Settings.',
    fields: <_Field>[],
    actions: <_Action>[
      (label: 'Not now', value: 'later', isDefault: false, destructive: false),
      (label: 'Allow', value: 'allow', isDefault: true, destructive: false),
    ],
    disabled: <String>{},
  );

  static const _Alert _destructive = (
    title: 'Delete photo?',
    message: 'This cannot be undone.',
    fields: <_Field>[],
    actions: <_Action>[
      (label: 'Cancel', value: 'cancel', isDefault: false, destructive: false),
      (label: 'Delete', value: 'delete', isDefault: false, destructive: true),
    ],
    disabled: <String>{},
  );

  static const _Alert _threeButton = (
    title: 'Unsaved changes',
    message: 'What should happen to your draft?',
    fields: <_Field>[],
    actions: <_Action>[
      (label: 'Save', value: 'save', isDefault: true, destructive: false),
      (label: 'Discard', value: 'discard', isDefault: false, destructive: true),
      (label: 'Cancel', value: 'cancel', isDefault: false, destructive: false),
    ],
    disabled: <String>{},
  );

  static const _Alert _titleOnly = (
    title: 'Saved',
    message: null,
    fields: <_Field>[],
    actions: <_Action>[
      (label: 'OK', value: 'ok', isDefault: true, destructive: false),
    ],
    disabled: <String>{},
  );

  static const _Alert _disabled = (
    title: 'Export',
    message: 'PDF export needs a paid plan.',
    fields: <_Field>[],
    actions: <_Action>[
      (
        label: 'Export as PNG',
        value: 'png',
        isDefault: false,
        destructive: false,
      ),
      (
        label: 'Export as PDF',
        value: 'pdf',
        isDefault: false,
        destructive: false,
      ),
    ],
    disabled: <String>{'pdf'},
  );

  static const _Alert _textField = (
    title: 'Rename',
    message: 'Pick a new name for this album.',
    fields: <_Field>[
      (placeholder: 'Name', initial: 'Untitled', obscure: false),
    ],
    actions: <_Action>[
      (label: 'Cancel', value: 'cancel', isDefault: false, destructive: false),
      (label: 'Save', value: 'save', isDefault: true, destructive: false),
    ],
    disabled: <String>{},
  );

  static const _Alert _secure = (
    title: 'Sign in',
    message: 'Enter your password to continue.',
    fields: <_Field>[(placeholder: 'Password', initial: '', obscure: true)],
    actions: <_Action>[
      (label: 'Cancel', value: 'cancel', isDefault: false, destructive: false),
      (label: 'Sign in', value: 'signin', isDefault: true, destructive: false),
    ],
    disabled: <String>{},
  );

  static const _Alert _twoFields = (
    title: 'Log in',
    message: null,
    fields: <_Field>[
      (placeholder: 'Username', initial: '', obscure: false),
      (placeholder: 'Password', initial: '', obscure: true),
    ],
    actions: <_Action>[
      (label: 'Cancel', value: 'cancel', isDefault: false, destructive: false),
      (
        label: 'Continue',
        value: 'continue',
        isDefault: true,
        destructive: false,
      ),
    ],
    disabled: <String>{},
  );

  String _lastResult = '—';
  int _segment = 0;

  static String _describe(String? value, List<String> text) {
    if (value == null) return '(no answer)';
    return 'value=$value${text.isEmpty ? '' : ' text=$text'}';
  }

  /// Shows one slot per call — `#1 pending… · #2 pending…` — and fills each
  /// in as its future completes, so a call that never resolves stays
  /// visible instead of showing the last result.
  void _track(List<Future<String>> calls) {
    final List<String> slots = List<String>.filled(calls.length, 'pending…');
    void show() {
      if (!mounted) return;
      setState(() {
        _lastResult = calls.length == 1
            ? slots.single
            : <String>[
                for (int i = 0; i < slots.length; i++) '#${i + 1} ${slots[i]}',
              ].join(' · ');
      });
    }

    show();
    for (int i = 0; i < calls.length; i++) {
      calls[i].then(
        (String result) {
          slots[i] = result;
          show();
        },
        onError: (Object error) {
          slots[i] = 'error: $error';
          show();
        },
      );
    }
  }

  /// Today's only option. Each action pops with its value; fields become
  /// [CupertinoTextField]s whose contents are returned alongside, like
  /// `CNAlertResult.textFields`. Disabled actions get a null `onPressed`,
  /// which is Flutter's disabled state.
  Future<String> _showFlutter(_Alert alert) async {
    final List<TextEditingController> controllers = <TextEditingController>[
      for (final _Field f in alert.fields)
        TextEditingController(text: f.initial),
    ];
    final String? value = await showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: Text(alert.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (alert.message != null) Text(alert.message!),
            for (int i = 0; i < alert.fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CupertinoTextField(
                  controller: controllers[i],
                  placeholder: alert.fields[i].placeholder,
                  obscureText: alert.fields[i].obscure,
                ),
              ),
          ],
        ),
        actions: <Widget>[
          for (final _Action a in alert.actions)
            CupertinoDialogAction(
              isDefaultAction: a.isDefault,
              isDestructiveAction: a.destructive,
              onPressed: alert.disabled.contains(a.value)
                  ? null
                  : () => Navigator.of(ctx).pop(a.value),
              child: Text(a.label),
            ),
        ],
      ),
    );
    final List<String> text = <String>[
      for (final TextEditingController c in controllers) c.text,
    ];
    for (final TextEditingController c in controllers) {
      c.dispose();
    }
    return _describe(value, text);
  }

  /// The same alert through `CNAlert`. The action whose value is `cancel`
  /// gets the UIKit cancel style, which Flutter's dialog has no notion of.
  Future<String> _showNative(_Alert alert) async {
    final CNAlertResult<String>? result = await CNAlert.show<String>(
      context: context,
      title: alert.title,
      message: alert.message,
      textFields: <CNAlertTextField>[
        for (final _Field f in alert.fields)
          CNAlertTextField(
            placeholder: f.placeholder,
            initialText: f.initial,
            obscureText: f.obscure,
          ),
      ],
      actions: <CNAlertAction<String>>[
        for (final _Action a in alert.actions)
          CNAlertAction<String>(
            label: a.label,
            value: a.value,
            isDefault: a.isDefault,
            isCancel: a.value == 'cancel',
            isDestructive: a.destructive,
            enabled: !alert.disabled.contains(a.value),
          ),
      ],
    );
    if (result == null) return _describe(null, const <String>[]);
    return _describe(result.value, result.textFields);
  }

  void _showTwiceAtOnce() => _track(<Future<String>>[
    _showNative(_twoButton),
    _showNative(_destructive),
  ]);

  void _supersedeAfterDelay() => _track(<Future<String>>[
    _showNative(_twoButton),
    Future<String>.delayed(
      const Duration(seconds: 1),
      () => _showNative(_destructive),
    ),
  ]);

  void _chained() {
    final Future<String> first = _showNative(_twoButton);
    _track(<Future<String>>[
      first,
      first.then((_) => _showNative(_destructive)),
    ]);
  }

  void _allDisabled() => _track(<Future<String>>[
    CNAlert.show<String>(
      context: context,
      title: 'Locked',
      actions: const <CNAlertAction<String>>[
        CNAlertAction<String>(label: 'OK', value: 'ok', enabled: false),
      ],
    ).then((CNAlertResult<String>? r) => _describe(r?.value, const <String>[])),
  ]);

  void _fromBottomSheet() {
    CNBottomSheet.show<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'A Flutter bottom sheet. The native alert should open above '
                'it.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () =>
                    _track(<Future<String>>[_showNative(_destructive)]),
                child: const Text('Native alert'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PR #79 · alert'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              'Flutter: pre-iOS 26 look, and the strip below is torn down '
              '(depth 1). Native: iOS 26 look, strip stays live (depth 0).',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 16),
            _nativeStrip(),
            const SizedBox(height: 12),
            _readout(),
            const SizedBox(height: 20),
            _scenario('Two buttons + default', _twoButton),
            _scenario('Destructive + cancel', _destructive),
            _scenario('Three buttons (stacked)', _threeButton),
            _scenario('Title only', _titleOnly),
            _scenario('Disabled action', _disabled),
            _scenario('Text field', _textField),
            _scenario('Secure text field', _secure),
            _scenario('Two text fields', _twoFields),
            const SizedBox(height: 12),
            const Text(
              'NATIVE STRESS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 10),
            _stress('Show twice at once', _showTwiceAtOnce),
            _stress('Second alert after 1 s', _supersedeAfterDelay),
            _stress('Chained: answer, then another', _chained),
            _stress('All actions disabled', _allDisabled),
            _stress('From a CNBottomSheet', _fromBottomSheet),
          ],
        ),
      ),
    );
  }

  /// Inline CN platform views that `ModalHideMixin` tears down under any
  /// Flutter popup route.
  Widget _nativeStrip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemIndigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: CNButton(label: 'Glass button', onPressed: () {}),
              ),
              const SizedBox(width: 12),
              CNButton.icon(
                icon: const CNSymbol('heart.fill'),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 12),
          CNSegmentedControl(
            labels: const <String>['One', 'Two', 'Three'],
            selectedIndex: _segment,
            onValueChanged: (int i) => setState(() => _segment = i),
          ),
        ],
      ),
    );
  }

  Widget _readout() {
    return ValueListenableBuilder<int>(
      valueListenable: CNTabBarRouteObserver.anyModalDepth,
      builder: (BuildContext context, int depth, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'modal depth $depth · strip ${depth > 0 ? 'torn down' : 'live'}\n'
          'last result: $_lastResult',
          style: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _scenario(String label, _Alert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          _button(
            'Flutter',
            CupertinoColors.activeBlue,
            () => _track(<Future<String>>[_showFlutter(alert)]),
          ),
          const SizedBox(width: 8),
          _button(
            'Native',
            CupertinoColors.systemGreen,
            () => _track(<Future<String>>[_showNative(alert)]),
          ),
        ],
      ),
    );
  }

  Widget _stress(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          _button('Native', CupertinoColors.systemGreen, onPressed),
        ],
      ),
    );
  }

  Widget _button(String label, Color color, VoidCallback onPressed) {
    return CupertinoButton(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
      ),
    );
  }
}
