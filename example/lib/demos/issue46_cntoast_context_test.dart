import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Issue #46 reproduction — two distinct bugs in `CNToast`:
///
///  * **Bug A: Queue crash on dispose.** `CNToast` stores the caller's
///    `BuildContext` in its internal `_queue`. `_showNext()` (called from
///    a `Timer` after each toast's duration) then does
///    `Overlay.of(entry.context)`. If the caller widget was disposed
///    while toasts were still pending, that context is deactivated and
///    the framework throws `Looking up a deactivated widget's ancestor
///    is unsafe.` After the throw, `_isShowing` is left `true`, so the
///    queue is permanently stuck until app restart — only
///    `CNToast.loading()` still works (it bypasses the queue).
///
///  * **Bug B: Yellow lines under `MaterialApp`.** Reporter's issue.
///    `_ToastOverlay` renders `Text` inside an `OverlayEntry` with no
///    `Material` ancestor. Under `MaterialApp`, the ambient
///    `DefaultTextStyle` is `_errorTextStyle` (dim red monospace with
///    yellow double-underline) — Flutter's "no Material ancestor"
///    visual warning. The reporter's screenshot in
///    https://github.com/gunumdogdu/cupertino_native_better/issues/46
///    shows exactly that style.
///
/// This screen has one scenario per bug. Neither scenario reproduces
/// inside the example's own `CupertinoApp` — that's why we need to
/// (a) actively spam-and-pop to hit Bug A, and (b) enter a nested
/// `MaterialApp` subtree to hit Bug B.
class Issue46CNToastContextTestPage extends StatefulWidget {
  const Issue46CNToastContextTestPage({super.key});

  @override
  State<Issue46CNToastContextTestPage> createState() =>
      _Issue46CNToastContextTestPageState();
}

class _Issue46CNToastContextTestPageState
    extends State<Issue46CNToastContextTestPage> {
  /// **Bug A repro.** Queue 5 toasts and pop back before the queue can
  /// drain. Around the time the first toast's timer fires, `_showNext()`
  /// tries to `Overlay.of(entry.context)` with this-widget's now-deactivated
  /// context — the framework crash appears in the debug console and the
  /// queue is permanently stuck. Come back to this screen and try any
  /// non-loading variant: nothing shows until app restart.
  Future<void> _spamAndPop() async {
    for (var i = 1; i <= 5; i++) {
      CNToast.info(
        context: context,
        message: 'Queued toast #$i (spam & pop)',
        position: CNToastPosition.bottom,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) Navigator.of(context).pop();
  }

  /// **Bug B repro.** Push a route whose body embeds a nested `MaterialApp`.
  /// Inside that subtree, the `Overlay` used by `CNToast` inherits
  /// `_errorTextStyle` (yellow underlines). Same call, same content,
  /// different ambient text style — that's how the reporter's app looks.
  void _openMaterialAppScenario() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const _NestedMaterialAppScenario(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Issue #46 Test'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              context,
              title: 'Bug A — queue crash on dispose',
              subtitle:
                  'Queues 5 toasts, then pops this route ~250ms later while '
                  'the first is still showing. Watch the debug console for '
                  '"Looking up a deactivated widget\'s ancestor is unsafe." '
                  'After the crash, come back to this screen and press any '
                  'non-loading trigger below — they will be silently queued '
                  'without displaying until app restart. Only .loading() '
                  'still works.',
              action: CupertinoButton.filled(
                onPressed: _spamAndPop,
                child: const Text('Spam & pop'),
              ),
            ),
            const SizedBox(height: 24),
            _section(
              context,
              title: 'Bug B — yellow underlines under MaterialApp',
              subtitle:
                  'Enters a nested MaterialApp subtree, where the overlay '
                  'inherits _errorTextStyle. Reporter\'s exact conditions.',
              action: CupertinoButton.filled(
                onPressed: _openMaterialAppScenario,
                child: const Text('Open MaterialApp scenario'),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Quick triggers (single toast, no async, no pop) — expected '
                'to work normally in this Cupertino subtree. If they stop '
                'responding, it means Bug A already fired and the queue is '
                'stuck.',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickTrigger('show', () => CNToast.show(
                      context: context,
                      message: 'show',
                      position: CNToastPosition.bottom,
                    )),
                _quickTrigger('success', () => CNToast.success(
                      context: context,
                      message: 'success',
                      position: CNToastPosition.bottom,
                    )),
                _quickTrigger('error', () => CNToast.error(
                      context: context,
                      message: 'error',
                      position: CNToastPosition.bottom,
                    )),
                _quickTrigger('warning', () => CNToast.warning(
                      context: context,
                      message: 'warning',
                      position: CNToastPosition.bottom,
                    )),
                _quickTrigger('info', () => CNToast.info(
                      context: context,
                      message: 'info',
                      position: CNToastPosition.bottom,
                    )),
                _quickTrigger('loading (2s)', () async {
                  final h = CNToast.loading(
                    context: context,
                    message: 'loading…',
                    position: CNToastPosition.bottom,
                  );
                  await Future<void>.delayed(const Duration(seconds: 2));
                  h.dismiss();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickTrigger(String label, VoidCallback onPressed) {
    return CupertinoButton(
      color: CupertinoColors.systemGrey5,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onPressed: onPressed,
      child: Text(label,
          style: const TextStyle(color: CupertinoColors.label, fontSize: 14)),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: CupertinoTheme.of(context)
                .textTheme
                .navTitleTextStyle
                .copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                )),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: action),
      ],
    );
  }
}

/// **Bug B scenario.** A nested `MaterialApp` inside the outer `CupertinoApp`.
/// Nested MaterialApp is unusual in real apps, but it's the smallest reliable
/// way to place `CNToast`'s overlay inside a subtree whose ambient
/// `DefaultTextStyle` is `_errorTextStyle` — the exact rendering the reporter
/// hit in a normal MaterialApp-based app.
///
/// After Fix B lands (`Material(type: MaterialType.transparency)` wrapping
/// the toast overlay), toasts here should render with normal styling.
class _NestedMaterialAppScenario extends StatelessWidget {
  const _NestedMaterialAppScenario();

  @override
  Widget build(BuildContext outerContext) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Nested MaterialApp (Bug B)'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    Navigator.of(outerContext, rootNavigator: true).pop(),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'This subtree is inside a nested MaterialApp. Any CNToast '
                    'fired from here uses this MaterialApp\'s overlay, which '
                    'ambient-inherits _errorTextStyle. Tap any variant below — '
                    'the toast should render with yellow double-underlines '
                    'and a monospace-ish fallback font.',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => CNToast.error(
                      context: context,
                      message: 'Chat cancelled due to insufficient credits',
                      position: CNToastPosition.bottom,
                    ),
                    child: const Text(
                        'CNToast.error (reporter\'s exact message)'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => CNToast.success(
                      context: context,
                      message: 'Success message',
                      position: CNToastPosition.bottom,
                    ),
                    child: const Text('CNToast.success'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => CNToast.info(
                      context: context,
                      message: 'Info message',
                      position: CNToastPosition.bottom,
                    ),
                    child: const Text('CNToast.info'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => CNToast.warning(
                      context: context,
                      message: 'Warning message',
                      position: CNToastPosition.bottom,
                    ),
                    child: const Text('CNToast.warning'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => CNToast.show(
                      context: context,
                      message: 'Generic show',
                      position: CNToastPosition.bottom,
                    ),
                    child: const Text('CNToast.show'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
