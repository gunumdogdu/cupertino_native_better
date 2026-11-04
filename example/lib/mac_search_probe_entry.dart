// macOS probe for CNSearchBar (NSSearchField): opens the Search Bar demo,
// clicks and types through the app's own event queue (cnb_mac_audit) and
// prints what the widget reports, plus who holds the keyboard.
//
//   flutter run -d macos -t lib/mac_search_probe_entry.dart
//     [--dart-define=BRIGHTNESS=dark] [--dart-define=SHOTS=true]
//
// Prints PROBE lines; with SHOTS it pauses at PROBE_SHOT <name> lines so a
// script can capture the window.

import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'demos/search_bar.dart';

const MethodChannel _audit = MethodChannel('cnb_mac_audit');
const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent) {
      debugPrint('PROBE flutter_key "${event.character ?? ''}"');
    }
    return false;
  });
  runApp(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [CNTabBarRouteObserver()],
      theme: CupertinoThemeData(
        brightness: _brightness == 'dark' ? Brightness.dark : Brightness.light,
      ),
      home: const SearchBarDemoPage(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_drive()));
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Future<String> _responder() async =>
    await _audit.invokeMethod<String>('firstResponder') ?? '?';

Future<void> _shot(String name) async {
  debugPrint('PROBE_SHOT $name');
  await _wait(2500);
}

/// Centre of the [index]th widget of type [T], in global coordinates.
Offset? _center<T extends Widget>([int index = 0, double dx = 0]) {
  final hits = <RenderBox>[];
  void visit(Element e) {
    if (e.widget is T) {
      final box = e.findRenderObject();
      if (box is RenderBox && box.attached) hits.add(box);
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  if (hits.length <= index) return null;
  final box = hits[index];
  final rect = box.localToGlobal(Offset.zero) & box.size;
  return Offset(dx == 0 ? rect.center.dx : rect.left + dx, rect.center.dy);
}

Future<void> _click(Offset p) =>
    _audit.invokeMethod<void>('click', {'x': p.dx, 'y': p.dy});

Future<void> _type({String? text, int? keyCode}) =>
    _audit.invokeMethod<void>('type', {
      if (text != null) 'text': text,
      if (keyCode != null) 'keyCodes': [keyCode],
    });

String _flutterFieldText() {
  var text = '?';
  void visit(Element e) {
    if (e is StatefulElement && e.state is EditableTextState) {
      text = (e.state as EditableTextState).textEditingValue.text;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  return text;
}

Future<void> _drive() async {
  await _wait(3000);
  debugPrint('PROBE start responder=${await _responder()}');
  await _shot('collapsed');

  // 1. Click the collapsed magnifying glass: opens and focuses the field.
  final bar = _center<CNSearchBar>(0, 22)!;
  await _click(bar);
  await _wait(800);
  debugPrint('PROBE after_click responder=${await _responder()}');

  // 2. Type, Return, Esc (clears), Esc (ends the search).
  await _type(text: 'hello');
  await _wait(600);
  await _shot('typed');
  await _type(keyCode: 36);
  await _wait(400);
  debugPrint('PROBE after_return responder=${await _responder()}');
  await _type(keyCode: 53);
  await _wait(400);
  debugPrint('PROBE after_esc1 responder=${await _responder()}');
  await _type(keyCode: 53);
  await _wait(800);
  debugPrint('PROBE after_esc2 responder=${await _responder()}');
  // Flutter has the keyboard again: its key handler sees this.
  await _type(text: 'z');
  await _wait(400);

  // 3. The always-open tinted field with recents: type, Return, then click
  // the Flutter text field and type there.
  final open = _center<CNSearchBar>(1)!;
  await _click(open);
  await _wait(500);
  await _type(text: 'report');
  await _type(keyCode: 36);
  await _wait(500);
  await _shot('open_typed');
  final flutterField = _center<CupertinoTextField>()!;
  await _click(flutterField);
  await _wait(500);
  debugPrint('PROBE after_flutter_click responder=${await _responder()}');
  await _type(text: 'abc');
  await _wait(500);
  debugPrint('PROBE flutter_field "${_flutterFieldText()}"');

  // 4. The controller: set text, focus, unfocus, collapse.
  final setText = _center<CupertinoButton>(2)!;
  await _click(setText);
  await _wait(800);
  await _shot('controller_set_text');
  final focus = _center<CupertinoButton>(4)!;
  await _click(focus);
  await _wait(500);
  debugPrint('PROBE after_focus responder=${await _responder()}');
  final unfocus = _center<CupertinoButton>(5)!;
  await _click(unfocus);
  await _wait(500);
  debugPrint('PROBE after_unfocus responder=${await _responder()}');
  final collapse = _center<CupertinoButton>(1)!;
  await _click(collapse);
  await _wait(800);
  await _shot('final');
  // 5. A new tint reaches the open field (setConfig).
  final tint = _center<CupertinoButton>(6)!;
  await _click(tint);
  await _wait(800);
  await _shot('tint_pink');
  debugPrint('PROBE done');
}
