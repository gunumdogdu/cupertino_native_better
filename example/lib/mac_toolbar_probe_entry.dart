// macOS probe for CNToolbar (NSToolbar on the window): opens the Toolbar
// demo, reads what VoiceOver sees of the toolbar and the Flutter view's
// geometry (cnb_mac_audit `toolbarAX`), clicks and types through the app's
// own event queue, puts a stand-in sidebar split view controller on the
// window and takes it away, and leaves the page.
//
//   flutter run -d macos -t lib/mac_toolbar_probe_entry.dart
//     [--dart-define=BRIGHTNESS=dark] [--dart-define=SCENARIO=<name>]
//     [--dart-define=FLOW=full|shot] [--dart-define=WIN=1180x780]
//     [--dart-define=PAGE=toolbar|search_scaffold]
//
// Prints PROBE lines and pauses at PROBE_SHOT <name> lines so a script can
// capture the window; PROBE_DONE at the end. SCENARIO is the demo page's
// autoScenario (cycle, search, compact, expanded, plain).

import 'dart:async';
import 'dart:convert';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'demos/search_scaffold.dart';
import 'demos/toolbar.dart';

const MethodChannel _audit = MethodChannel('cnb_mac_audit');
const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);
const String _scenario = String.fromEnvironment('SCENARIO');
const String _flow = String.fromEnvironment('FLOW', defaultValue: 'full');
const String _window = String.fromEnvironment('WIN', defaultValue: '1180x780');

/// `toolbar` (the Toolbar demo) or `search_scaffold` (the Search Scaffold
/// demo, whose toolbar holds its tabs and search field).
const String _page = String.fromEnvironment('PAGE', defaultValue: 'toolbar');

final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CupertinoApp(
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [CNTabBarRouteObserver()],
      theme: CupertinoThemeData(
        brightness: _brightness == 'dark' ? Brightness.dark : Brightness.light,
      ),
      home: const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Home')),
        child: Center(child: Text('Home page: no toolbar')),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_drive()));
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Future<void> _shot(String name) async {
  await _audit.invokeMethod<void>('toScreen', {'x': 0.0, 'y': 0.0});
  await _wait(700);
  debugPrint('PROBE_SHOT $name');
  await _wait(3000);
}

Future<Map<String, Object?>> _ax() async {
  final raw = await _audit.invokeMapMethod<String, Object?>('toolbarAX');
  return raw ?? const {};
}

List<Map<String, Object?>> _elements(Map<String, Object?> ax) => [
  for (final e in (ax['elements'] as List? ?? const []))
    (e as Map).cast<String, Object?>(),
];

/// Prints the window state and every toolbar element VoiceOver sees.
Future<Map<String, Object?>> _report(String tag) async {
  final ax = await _ax();
  debugPrint(
    'PROBE $tag window=${jsonEncode(ax['window'])} '
    'content=${jsonEncode(ax['content'])} '
    'flutterView=${jsonEncode(ax['flutterView'])} '
    'contentLayoutTop=${ax['contentLayoutTop']} '
    'title="${ax['title']}" subtitle="${ax['subtitle']}" '
    'hasToolbar=${ax['hasToolbar']} appearance=${ax['appearance']}',
  );
  debugPrint('PROBE $tag items=${jsonEncode(ax['toolbarItems'])}');
  for (final e in _elements(ax)) {
    final f = (e['frame'] as Map).cast<String, Object?>();
    debugPrint(
      'PROBE $tag ax role=${e['role']} subrole=${e['subrole']} '
      'label="${e['label']}" title="${e['title']}" help="${e['help']}" '
      'enabled=${e['enabled']} at=(${(f['x'] as num).round()},'
      '${(f['y'] as num).round()} ${(f['w'] as num).round()}x'
      '${(f['h'] as num).round()})',
    );
  }
  return ax;
}

/// Clicks the toolbar element whose label or title is [name].
Future<bool> _clickToolbar(String name, {String? role}) async {
  final ax = await _ax();
  for (final e in _elements(ax)) {
    if (e['label'] != name && e['title'] != name) continue;
    if (role != null && e['role'] != role) continue;
    final f = (e['frame'] as Map).cast<String, Object?>();
    final x = (f['x'] as num) + (f['w'] as num) / 2;
    final y = (f['y'] as num) + (f['h'] as num) / 2;
    debugPrint('PROBE click "$name" (${e['role']}) at ($x,$y)');
    await _audit.invokeMethod<void>('click', {
      'x': x.toDouble(),
      'y': y.toDouble(),
    });
    await _wait(900);
    return true;
  }
  debugPrint('PROBE click "$name" NOT FOUND');
  return false;
}

/// Clicks the toolbar's search field until it has the keyboard: a click
/// into a window of an app that is not active (another app took the focus
/// on the shared screen) only activates it.
Future<bool> _clickSearch() async {
  for (var attempt = 0; attempt < 3; attempt++) {
    await _clickToolbar('Search');
    final responder = await _audit.invokeMethod<String>('firstResponder');
    debugPrint('PROBE firstResponder after search click: $responder');
    if (responder == 'NSTextView') return true;
  }
  return false;
}

Future<void> _key(int code, {int delayMs = 0}) async {
  await _audit.invokeMethod<void>('key', {'keyCode': code});
  await _wait(400 + delayMs);
}

Future<void> _type(String text) async {
  await _audit.invokeMethod<void>('type', {'text': text});
  await _wait(600);
}

/// Clicks the Flutter switch in the row labelled [label] on the demo page.
Future<void> _toggleRow(String label) async {
  RenderBox? rowBox;
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && w.data == label) {
      Element? row;
      e.visitAncestorElements((a) {
        if (a.widget is Row) {
          row = a;
          return false;
        }
        return true;
      });
      final box = row?.findRenderObject();
      if (box is RenderBox) rowBox = box;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  final box = rowBox;
  if (box == null) {
    debugPrint('PROBE row "$label" NOT FOUND');
    return;
  }
  // The switch is at the trailing end of the row.
  final p = box.localToGlobal(Offset(box.size.width - 30, box.size.height / 2));
  await _audit.invokeMethod<void>('click', {'x': p.dx, 'y': p.dy});
  await _wait(900);
}

Future<void> _drive() async {
  final parts = _window.split('x').map(double.parse).toList();
  await _audit.invokeMethod<void>('resize', {
    'width': parts[0],
    'height': parts[1],
  });
  await _wait(1500);
  await _report('home');
  await _shot('home');

  unawaited(
    _navigator.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => _page == 'search_scaffold'
            ? SearchScaffoldDemoPage(
                autoScenario: _scenario.isEmpty ? null : _scenario,
              )
            : ToolbarDemoPage(
                autoScenario: _scenario.isEmpty ? null : _scenario,
              ),
      ),
    ),
  );
  await _wait(2500);
  await _report('page');
  await _shot('toolbar');
  if (_page == 'search_scaffold') {
    await _scaffoldFlow();
    return;
  }
  if (_scenario == 'cycle') {
    for (var i = 0; i < 3; i++) {
      await _wait(1500);
      await _report('cycle$i');
      await _shot('cycle$i');
    }
  }
  if (_flow != 'full') {
    debugPrint('PROBE_DONE');
    return;
  }

  // Buttons, segments, toggles.
  await _clickToolbar('New Message');
  await _clickToolbar('Back');
  await _clickToolbar('Forward');
  await _clickToolbar('Grid');
  await _clickToolbar('Flagged');
  await _report('clicked');
  await _shot('clicked');

  // The menu: open, shoot, close with a click on the empty page. (Keys
  // would reach Flutter, and move its focus to the back button, whenever
  // another app on the shared screen closes the menu first. Choosing an
  // item with the keyboard was checked by hand: `Sort [1]`.)
  await _clickToolbar('Sort');
  await _wait(600);
  debugPrint('PROBE_SHOT menu');
  await _wait(3000);
  await _audit.invokeMethod<void>('click', {'x': 40.0, 'y': 700.0});
  await _wait(800);

  // Search: click the field, type, submit, end with Esc twice (only while
  // the field has the keyboard: Esc in Flutter would leave the page).
  if (await _clickSearch()) {
    await _type('inv');
    await _key(36);
    debugPrint('PROBE_SHOT search');
    await _wait(3000);
    await _key(53, delayMs: 600);
    final afterOne = await _audit.invokeMethod<String>('firstResponder');
    debugPrint('PROBE firstResponder after one Esc: $afterOne');
    if (afterOne == 'NSTextView') await _key(53, delayMs: 600);
    debugPrint(
      'PROBE firstResponder after two Esc: '
      '${await _audit.invokeMethod<String>('firstResponder')}',
    );
  }

  // In-place updates from the page's controls.
  await _toggleRow('Flag button');
  await _toggleRow('Filter toggles');
  await _toggleRow('Prominent New Message');
  await _report('updated');
  await _shot('updated');
  await _toggleRow('Flag button');
  await _toggleRow('Filter toggles');
  await _toggleRow('Prominent New Message');

  // A window with a sidebar: the sidebar items appear, and go again.
  await _audit.invokeMethod<void>('debugSplit', {'on': true});
  await _wait(1500);
  await _report('split');
  await _shot('split');
  await _clickToolbar('Sidebar') ||
      await _clickToolbar('Show Sidebar') ||
      await _clickToolbar('Hide Sidebar') ||
      await _clickToolbar('Toggle Sidebar');
  await _wait(800);
  await _shot('split-collapsed');
  await _audit.invokeMethod<void>('debugSplit', {'on': false});
  await _wait(1500);
  await _report('nosplit');

  // Leaving the page gives the window its own toolbar and title back.
  _navigator.currentState!.pop();
  await _wait(1500);
  await _report('popped');
  await _shot('popped');
  debugPrint('PROBE_DONE');
}

/// The Search Scaffold demo: tabs in the toolbar, then a search.
Future<void> _scaffoldFlow() async {
  if (_flow != 'full') {
    debugPrint('PROBE_DONE');
    return;
  }
  await _clickToolbar('Library');
  await _shot('library');
  if (await _clickSearch()) {
    await _type('an');
    await _key(36);
    await _report('searching');
    await _shot('searching');
    await _key(53, delayMs: 400);
    await _key(53, delayMs: 600);
  }
  debugPrint(
    'PROBE firstResponder after Esc: '
    '${await _audit.invokeMethod<String>('firstResponder')}',
  );
  await _clickToolbar('Home');
  await _shot('home-tab');
  _navigator.currentState!.pop();
  await _wait(1500);
  await _report('popped');
  debugPrint('PROBE_DONE');
}
