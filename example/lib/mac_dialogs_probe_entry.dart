// macOS probe for CNAlert, CNActionSheet and CNContextMenu (debug only).
//
//   flutter run -d macos -t lib/mac_dialogs_probe_entry.dart \
//     [--dart-define=BRIGHTNESS=dark|light|system] [--dart-define=ONLY=a,b]
//
// Runs every step below: opens a demo page with an `autoScenario` (or
// right-clicks a card through the debug-only `cnb_mac_audit` channel of
// `MainFlutterWindow.swift`, which posts the events to the app's own queue
// and never moves the real cursor), prints `CNB_SHOT <name>` once the native
// alert or menu is up so a script can capture the windows, then answers it
// with key presses (Return, Escape, arrows, typed text) through the same
// channel. The demo pages print `CNB_RESULT ...` with what came back.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'demos/action_sheet.dart';
import 'demos/alert.dart';
import 'demos/context_menu.dart';

const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);
const String _only = String.fromEnvironment('ONLY');
const MethodChannel _audit = MethodChannel('cnb_mac_audit');
final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();

const int _return = 36;
const int _escape = 53;
const int _tab = 48;
const int _down = 125;
const int _right = 124;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final print = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.startsWith('CNB_RESULT ')) {
      _results.add(message);
    }
    print(message, wrapWidth: wrapWidth);
  };
  runApp(
    CupertinoApp(
      navigatorKey: _nav,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: switch (_brightness) {
          'dark' => Brightness.dark,
          'system' => null,
          _ => Brightness.light,
        },
      ),
      home: const CupertinoPageScaffold(child: Center(child: Text('probe'))),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

/// Keys for an `NSMenu` ([menu]) are posted by the run script to this
/// process only (`CGEvent.postToPid`, on a `CNB_KEYS` line): a menu chooses
/// an item only on a key from the window server, not on an event the app
/// posts to itself. Keys for an alert sheet go through the app's own event
/// queue, which reaches the sheet even while another app is in front.
Future<void> _key(int code, {int times = 1, bool menu = false}) async {
  if (menu) {
    debugPrint('CNB_KEYS ${List.filled(times, code).join(' ')}');
    await _wait(500 + 260 * times);
    return;
  }
  for (var i = 0; i < times; i++) {
    await _audit.invokeMethod<void>('key', {'keyCode': code});
    await _wait(250);
  }
}

Future<void> _type(String text) async {
  await _audit.invokeMethod<void>('key', {'text': text});
  await _wait(300);
}

Future<void> _shot(String name) async {
  debugPrint('CNB_SHOT ${_brightness}_$name');
  await _wait(2200);
}

Future<void> _open(Widget page) async {
  _nav.currentState!.popUntil((r) => r.isFirst);
  await _wait(600);
  unawaited(_nav.currentState!.push(CupertinoPageRoute<void>(builder: (_) => page)));
  await _wait(1600);
}

Offset? _centerOf(Key key, {double dx = 0}) {
  Offset? found;
  void visit(Element e) {
    if (found != null) return;
    if (e.widget.key == key) {
      final box = e.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        found = box.localToGlobal(box.size.center(Offset.zero)) + Offset(dx, 0);
        return;
      }
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  return found;
}

Future<void> _rightClick(Key key, {double dx = 0, bool activate = true}) async {
  final c = _centerOf(key, dx: dx)!;
  debugPrint('CNB_CLICK right $key at $c');
  await _audit.invokeMethod<void>('click', {
    'x': c.dx,
    'y': c.dy,
    'button': 'right',
    'activate': activate,
  });
  await _wait(900);
}

/// A step: its name, the `CNB_RESULT` text it must produce (null when it
/// produces none), and what it does.
typedef _Step = (String, String?, Future<void> Function());

Future<void> _openContextMenuPage() async {
  if (_centerOf(ContextMenuDemoPage.photoCardKey) == null) {
    await _open(const ContextMenuDemoPage());
  }
}

final List<_Step> _steps = [
  ('alert_two', 'alert value=allow text=[]', () async {
    await _open(const AlertDemoPage(autoScenario: 'twobutton'));
    await _shot('alert_two');
    await _key(_return); // the default action
  }),
  ('alert_destructive', 'alert value=cancel text=[]', () async {
    await _open(const AlertDemoPage(autoScenario: 'destructive'));
    await _shot('alert_destructive');
    await _key(_return); // no default: nothing happens
    await _wait(600);
    await _key(_escape); // the cancel action
  }),
  ('alert_three', 'alert value=cancel text=[]', () async {
    await _open(const AlertDemoPage(autoScenario: 'threebutton'));
    await _shot('alert_three');
    await _key(_escape);
  }),
  ('alert_disabled', 'alert value=png text=[]', () async {
    await _open(const AlertDemoPage(autoScenario: 'disabled'));
    await _shot('alert_disabled');
    await _key(_return);
  }),
  ('alert_text', 'alert value=save text=[Holiday]', () async {
    await _open(const AlertDemoPage(autoScenario: 'textfield'));
    await _shot('alert_text');
    await _type('Holiday');
    await _shot('alert_text_typed');
    await _key(_return);
  }),
  ('alert_secure', 'alert value=signin text=[hunter2]', () async {
    await _open(const AlertDemoPage(autoScenario: 'secure'));
    await _type('hunter2');
    await _shot('alert_secure');
    await _key(_return);
  }),
  ('alert_two_fields', 'alert value=continue text=[emir, secret]', () async {
    await _open(const AlertDemoPage(autoScenario: 'twofields'));
    await _type('emir');
    await _key(_tab);
    await _type('secret');
    await _shot('alert_two_fields');
    await _key(_return);
  }),
  ('alert_supersede', 'alert value=second text=[]', () async {
    await _open(const AlertDemoPage(autoScenario: 'supersede'));
    await _shot('alert_supersede');
    await _key(_return); // the first call resolved to null
  }),
  ('sheet_anchored', 'action_sheet remove', () async {
    await _open(const ActionSheetDemoPage(autoScenario: 'anchored'));
    await _shot('sheet_anchored');
    await _key(_down, times: 3, menu: true);
    await _shot('sheet_anchored_destructive_highlighted');
    await _key(_return, menu: true);
  }),
  ('sheet_alert', 'action_sheet null', () async {
    await _open(const ActionSheetDemoPage(autoScenario: 'destructive'));
    await _shot('sheet_alert');
    await _key(_escape); // the cancel button
  }),
  ('sheet_long', 'action_sheet null', () async {
    await _open(const ActionSheetDemoPage(autoScenario: 'longlist'));
    await _shot('sheet_long');
    await _key(_escape);
  }),
  ('sheet_nocancel', null, () async {
    await _open(const ActionSheetDemoPage(autoScenario: 'nocancel'));
    await _shot('sheet_nocancel');
    // No cancel and no default, so no key answers it: the next step's
    // sheet replaces it, and this call resolves to null.
  }),
  ('sheet_anchored_cancel', 'action_sheet null', () async {
    await _open(const ActionSheetDemoPage(autoScenario: 'anchored'));
    await _shot('sheet_anchored_again');
    await _key(_escape, menu: true);
  }),
  ('ctx_menu', 'photo [1] Share', () async {
    await _openContextMenuPage();
    await _rightClick(ContextMenuDemoPage.photoCardKey);
    await _shot('ctx_menu');
    await _key(_down, times: 2, menu: true);
    await _key(_return, menu: true);
  }),
  ('ctx_submenu', 'photo [4, 1] Move to › Family', () async {
    await _openContextMenuPage();
    await _rightClick(ContextMenuDemoPage.photoCardKey);
    await _key(_down, times: 4, menu: true);
    await _key(_right, menu: true);
    await _shot('ctx_submenu');
    await _key(_down, menu: true);
    await _key(_return, menu: true);
  }),
  ('ctx_inline', 'photo [5, 1] Rotate › Rotate right', () async {
    await _openContextMenuPage();
    await _rightClick(ContextMenuDemoPage.photoCardKey);
    await _key(_down, times: 6, menu: true);
    await _key(_return, menu: true);
  }),
  ('ctx_destructive', 'photo [9] Delete', () async {
    await _openContextMenuPage();
    await _rightClick(ContextMenuDemoPage.photoCardKey);
    await _key(_down, times: 8, menu: true);
    await _shot('ctx_destructive_highlighted');
    await _key(_return, menu: true);
  }),
  ('ctx_cancel', null, () async {
    await _openContextMenuPage();
    await _rightClick(ContextMenuDemoPage.photoCardKey);
    await _key(_escape, menu: true); // no result
  }),
  ('ctx_popup_gesture', 'CNPopupGesture onSelected(1)', () async {
    await _openContextMenuPage();
    await _rightClick(ContextMenuDemoPage.gestureCardKey);
    await _shot('ctx_popup_gesture');
    await _key(_down, times: 2, menu: true);
    await _key(_return, menu: true);
  }),
  ('ctx_background', 'photo [0] Copy', () async {
    // A right click on the window while another app is in front opens the
    // menu there, without bringing the app forward, as on any Mac window.
    await _openContextMenuPage();
    await _audit.invokeMethod<void>('deactivate');
    await _wait(800);
    await _rightClick(ContextMenuDemoPage.photoCardKey, activate: false);
    await _shot('ctx_background');
    await _key(_down, menu: true);
    await _key(_return, menu: true);
  }),
  ('ctx_resized', 'photo [0] Copy', () async {
    await _openContextMenuPage();
    await _audit.invokeMethod<void>('resize', {'width': 560.0, 'height': 640.0});
    await _wait(1200);
    await _rightClick(ContextMenuDemoPage.photoCardKey, dx: 120);
    await _shot('ctx_resized');
    await _key(_down, menu: true);
    await _key(_return, menu: true);
    await _audit.invokeMethod<void>('resize', {'width': 820.0, 'height': 900.0});
    await _wait(800);
  }),
];

/// Every `CNB_RESULT` line printed so far.
final List<String> _results = <String>[];

Future<void> _run() async {
  if (const bool.fromEnvironment('TRACE')) {
    HardwareKeyboard.instance.addHandler((event) {
      debugPrint('CNB_TRACE key ${event.runtimeType} ${event.logicalKey.debugName} '
          'synth=${event.synthesized}');
      return false;
    });
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent || event is PointerUpEvent) {
        debugPrint(
          'CNB_TRACE ${event.runtimeType} buttons=${event.buttons} '
          'kind=${event.kind} ctrl=${HardwareKeyboard.instance.isControlPressed}',
        );
      }
    });
  }
  await _audit.invokeMethod<void>('resize', {'width': 820.0, 'height': 900.0});
  await _wait(2500);
  final only = _only.isEmpty ? null : _only.split(',').toSet();
  final failed = <String>[];
  for (final (name, expected, step) in _steps) {
    if (only != null && !only.any(name.startsWith)) continue;
    // Other apps on this Mac take the focus now and then, which closes an
    // open menu or sends the keys elsewhere: a step without its result is
    // run again, up to three times.
    var ok = false;
    for (var attempt = 1; attempt <= 3 && !ok; attempt++) {
      debugPrint('CNB_STEP $name${attempt > 1 ? ' (attempt $attempt)' : ''}');
      // Front and key again before each step.
      await _audit.invokeMethod<void>('toScreen', {'x': 0.0, 'y': 0.0});
      await _wait(300);
      final before = _results.length;
      await step();
      await _wait(1200);
      ok = expected == null ||
          _results.skip(before).any((r) => r.endsWith(expected));
    }
    if (!ok) failed.add(name);
  }
  debugPrint('CNB_SUMMARY failed=${failed.isEmpty ? 'none' : failed.join(',')}');
  debugPrint('CNB_DONE');
}
