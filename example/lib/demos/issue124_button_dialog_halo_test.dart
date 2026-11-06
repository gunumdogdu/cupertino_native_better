import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show AlertDialog, TextButton, showDialog;
import 'package:flutter/scheduler.dart' show timeDilation;

/// Issue #124 reproduction: a glass `CNButton` with `autoHideOnModal: false`
/// shows the #29 halo square while a dialog fades in.
///
/// Issue: https://github.com/gunumdogdu/cupertino_native_better/issues/124
/// Reported by @LucasLau00.
///
/// ### The claim
///
/// The reporter has a glass `CNButton.icon(autoHideOnModal: false)` that opens
/// `showDialog`. While the dialog's barrier fades in, a lighter rectangle shows
/// around the button: the platform view's full bounds with the un-clipped
/// Liquid Glass glow, the same artifact as #29.
///
/// Root cause, as reported and checked in the code: halo containment
/// (`setTransitioning`) follows only the host route's `secondaryAnimation`.
/// A dialog is a `PopupRoute`, and a page route's `canTransitionTo` refuses
/// popups, so that animation never moves when a dialog opens. A widget with
/// `autoHideOnModal: true` is protected anyway, because `ModalHideMixin`
/// removes its platform view while the dialog is up. With
/// `autoHideOnModal: false` nothing protects it.
///
/// ### How this screen proves it
///
/// Turn on *Slow motion* so the barrier takes about two seconds to fade in.
/// The two buttons sit on a saturated panel, so a lighter box stands out
/// against the dimmed colour. Tap a button to open the dialog, and watch the
/// **left** button (`autoHideOnModal: false`) while the barrier fades in, and
/// again while it fades out after *Close*:
///
///  * **Bug present:** a lighter square or rectangle shows around the left
///    button during the fade. It is not the button's round glass shape; it
///    is the box the button sits in.
///  * **Bug fixed:** the left button darkens evenly with the panel. No box at
///    any point of the fade-in or fade-out.
///
/// The **right** button keeps the default `autoHideOnModal: true`. It
/// disappears while the dialog is up (the platform view is removed) and comes
/// back after it closes. It is the control: it shows that the default path
/// was never affected, and it must stay that way after a fix.
///
/// *Dialog* picks the route: Material `showDialog` (the reporter's case) or
/// `showCupertinoDialog`. Both are `PopupRoute`s, so both should reproduce.
class Issue124ButtonDialogHaloTestPage extends StatefulWidget {
  const Issue124ButtonDialogHaloTestPage({super.key});

  @override
  State<Issue124ButtonDialogHaloTestPage> createState() =>
      _Issue124ButtonDialogHaloTestPageState();
}

enum _DialogKind { material, cupertino }

class _Issue124ButtonDialogHaloTestPageState
    extends State<Issue124ButtonDialogHaloTestPage> {
  bool _slow = false;
  _DialogKind _kind = _DialogKind.material;

  @override
  void dispose() {
    timeDilation = 1;
    super.dispose();
  }

  void _setSlow(bool slow) {
    setState(() => _slow = slow);
    timeDilation = slow ? 10 : 1;
  }

  Future<void> _openDialog() async {
    switch (_kind) {
      case _DialogKind.material:
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('showDialog'),
            content: const Text(
              'Watch the left button while this fades in and out.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      case _DialogKind.cupertino:
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('showCupertinoDialog'),
            content: const Text(
              'Watch the left button while this fades in and out.',
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('#124: Button halo under dialog'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: Text('Slow motion (10×)')),
                CupertinoSwitch(value: _slow, onChanged: _setSlow),
              ],
            ),
            const SizedBox(height: 12),
            CupertinoSlidingSegmentedControl<_DialogKind>(
              groupValue: _kind,
              onValueChanged: (kind) {
                if (kind != null) setState(() => _kind = kind);
              },
              children: const <_DialogKind, Widget>{
                _DialogKind.material: Text('showDialog'),
                _DialogKind.cupertino: Text('showCupertinoDialog'),
              },
            ),
            const SizedBox(height: 20),
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFE8590C), Color(0xFFC2255C)],
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _Column(
                      caption: 'autoHideOnModal: false\n(the report)',
                      button: CNButton.icon(
                        icon: const CNSymbol('plus', size: 20),
                        autoHideOnModal: false,
                        onPressed: _openDialog,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Column(
                      caption: 'default\n(control)',
                      button: CNButton.icon(
                        icon: const CNSymbol('plus', size: 20),
                        onPressed: _openDialog,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bug: a lighter box shows around the LEFT button while the '
              'dialog fades in or out.\n'
              'Fixed: the left button darkens evenly with the panel.\n'
              'Control: the right button disappears while the dialog is up '
              'and comes back after Close.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.caption, required this.button});

  final String caption;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        button,
        const SizedBox(height: 14),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
