// macOS probe for CNPopupMenuButton menus (debug only).
//
//   flutter run -d macos -t lib/mac_popup_probe_entry.dart \
//     [--dart-define=BRIGHTNESS=dark|light] [--dart-define=ONLY=a,b]
//
// Opens the Popup Menu Button demo page and the Display and Files showcase
// scenes and opens a popup button's native menu. A run script presses the
// NSButton through accessibility on a `CNB_PRESS <x> <y>` line (the way
// VoiceOver does, which works while another app is in front), or with
// PRESS=false the debug-only `cnb_mac_audit` channel of
// `MainFlutterWindow.swift` clicks it through the app's own event queue; the
// real cursor never moves. While the menu is open the probe prints
// `CNB_SHOT <name>` so the script can capture the windows, and the script
// answers the menu: `CNB_KEYS <codes>` lines are key presses it posts to
// this process (an NSMenu only takes keys from the window server),
// `CNB_AX <name>` asks it to dump the open menu's accessibility tree
// (titles, enabled, checkmarks) and `CNB_AXPRESS <name> <title>` to press an
// item through accessibility. `CNB_PLACE` asks it to move the window clear
// of other windows. The demo page prints `CNB_RESULT popup <menu>
// index=<i>` / `path=<p>` for each selection.

import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'package:flutter/services.dart';

import 'demos/popup_menu_button.dart';
import 'showcase/showcase_app.dart' show buildShowcaseScene;

const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);
const String _only = String.fromEnvironment('ONLY');

/// PRESS=false clicks the popup buttons through the app's own event queue
/// instead of pressing them through accessibility; a click only opens the
/// menu while this app is the active one.
const bool _press = bool.fromEnvironment('PRESS', defaultValue: true);
const MethodChannel _audit = MethodChannel('cnb_mac_audit');
final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();

const int _return = 36;
const int _escape = 53;
const int _down = 125;
const int _up = 126;
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
        brightness: _brightness == 'dark' ? Brightness.dark : Brightness.light,
      ),
      home: const CupertinoPageScaffold(child: Center(child: Text('probe'))),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

/// Keys for the open menu, posted by the run script to this process.
Future<void> _keys(List<int> codes) async {
  debugPrint('CNB_KEYS ${codes.join(' ')}');
  await _wait(500 + 260 * codes.length);
}

/// Highlights the enabled item [fromEnd] places above the last one: Down
/// until the end (menus do not wrap), then Up. The real cursor may rest over
/// the menu and highlight an item when it opens, so counting from the top
/// would depend on where it is.
Future<void> _highlightFromEnd(int fromEnd) =>
    _keys([...List.filled(14, _down), ...List.filled(fromEnd, _up)]);

/// Chooses the enabled item [fromEnd] places above the last one.
Future<void> _chooseFromEnd(int fromEnd) async {
  await _highlightFromEnd(fromEnd);
  await _keys([_return]);
}

Future<void> _shot(String name) async {
  debugPrint('CNB_SHOT ${_brightness}_$name');
  await _wait(2200);
}

Future<void> _ax(String name) async {
  debugPrint('CNB_AX ${_brightness}_$name');
  await _wait(2500);
}

Future<void> _axPress(String name, String title) async {
  debugPrint('CNB_AXPRESS ${_brightness}_$name $title');
  await _wait(2500);
}

/// Which page a step needs.
enum _Page { demo, display, files }

_Page? _current;

Future<void> _open(_Page page) async {
  if (_current == page) return;
  _nav.currentState!.popUntil((r) => r.isFirst);
  await _wait(600);
  final Widget child = switch (page) {
    _Page.demo => const PopupMenuButtonDemoPage(),
    _Page.display => buildShowcaseScene('display'),
    _Page.files => buildShowcaseScene('files'),
  };
  unawaited(
    _nav.currentState!.push(CupertinoPageRoute<void>(builder: (_) => child)),
  );
  _current = page;
  await _wait(2000);
}

String? _firstLabel(CNPopupMenuButton w) {
  final first = w.items.isEmpty ? null : w.items.first;
  if (first is CNPopupMenuItem) return first.label;
  if (first is CNPopupMenuSubmenu) return first.label;
  return null;
}

/// The demo page's menus, by the name the page prints.
final Map<String, bool Function(CNPopupMenuButton)> _menus = {
  'actions': (w) => w.buttonLabel == 'Actions',
  'kinds': (w) => w.buttonLabel == 'Item kinds',
  'layout': (w) => _firstLabel(w) == 'Format',
  'colored': (w) => w.buttonStyle == CNButtonStyle.bordered &&
      _firstLabel(w) == 'New File',
  'custom': (w) => w.buttonCustomIcon != null,
  'svg': (w) => w.buttonStyle == CNButtonStyle.glass &&
      _firstLabel(w) == 'Home' &&
      w.buttonImageAsset != null,
  'colored_svg': (w) => w.buttonStyle == CNButtonStyle.borderedProminent &&
      _firstLabel(w) == 'Home',
  'png': (w) => w.buttonStyle == CNButtonStyle.glass &&
      _firstLabel(w) == 'Check',
  'colored_png': (w) => w.buttonStyle == CNButtonStyle.borderedProminent &&
      _firstLabel(w) == 'Check',
  'display': (w) => _firstLabel(w) == 'Clear',
  'files': (w) => _firstLabel(w) == 'Select',
};

Element? _find(bool Function(CNPopupMenuButton) test) {
  Element? found;
  void visit(Element e) {
    if (found != null) return;
    final w = e.widget;
    if (w is CNPopupMenuButton &&
        test(w) &&
        (ModalRoute.of(e)?.isCurrent ?? false)) {
      found = e;
      return;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  return found;
}

ScrollPosition? _pageScroll() {
  ScrollableState? last;
  void visit(Element e) {
    if (e is StatefulElement &&
        e.state is ScrollableState &&
        (e.state as ScrollableState).position.axis == Axis.vertical &&
        (ModalRoute.of(e)?.isCurrent ?? false)) {
      last ??= e.state as ScrollableState;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  return last?.position;
}

/// Scrolls the menu's button into view and clicks it with an AppKit click.
Future<void> _openMenu(String menu) async {
  final test = _menus[menu]!;
  var element = _find(test);
  final position = _pageScroll();
  if (element == null && position != null) {
    position.jumpTo(0);
    await WidgetsBinding.instance.endOfFrame;
    element = _find(test);
    while (element == null && position.pixels < position.maxScrollExtent) {
      position.jumpTo(
        (position.pixels + 250).clamp(0.0, position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
      element = _find(test);
    }
  }
  if (element == null) {
    debugPrint('CNB_MISSING menu $menu');
    return;
  }
  await Scrollable.ensureVisible(element, alignment: 0.2);
  await WidgetsBinding.instance.endOfFrame;
  // The platform view follows the scroll a frame later.
  await _wait(700);
  final box = element.findRenderObject()! as RenderBox;
  final c = box.localToGlobal(box.size.center(Offset.zero));
  if (_press) {
    // The run script presses the NSButton at that point through
    // accessibility (`CNB_PRESS x y`, screen points), which works while
    // another app is in front; a click on a window in the background only
    // brings it forward.
    final screen = await _audit.invokeMapMethod<String, double>(
      'toScreen',
      {'x': c.dx, 'y': c.dy},
    );
    debugPrint('CNB_PRESS ${screen!['x']} ${screen['y']}');
    await _wait(1800);
    return;
  }
  await _audit.invokeMethod<void>('click', {'x': c.dx, 'y': c.dy});
  await _wait(1200);
}

/// A step: its name, the `CNB_RESULT` lines it must produce (none: it must
/// produce no result), and what it does.
typedef _Step = (String, List<String>, _Page, Future<void> Function());

// The menus' enabled items, which the keys go through:
//   actions  New File, New Folder, Rename (Delete is disabled)
//   kinds    Show Preview, Move to ›, Search (SVG), Coins (PNG),
//            Star (custom icon), Delete (Archive is disabled)
//     Move to › Home, Recents, Favourites (Elsewhere is disabled)
//   layout   Bold, Italic, Underline, Strikethrough, Name, Date, Size,
//            Zoom in, Zoom out
final List<_Step> _steps = [
  // A disabled item is greyed out and cannot be chosen: pressing it through
  // accessibility does nothing, and the arrow keys skip it.
  ('actions_disabled', <String>[], _Page.demo, () async {
    await _openMenu('actions');
    await _shot('actions_menu');
    await _ax('actions_menu');
    await _axPress('actions_press_disabled', 'Delete');
    await _keys([_escape]);
  }),
  ('actions_keys', ['popup actions index=3'], _Page.demo, () async {
    await _openMenu('actions');
    await _chooseFromEnd(0); // Rename, or Delete if it were enabled
  }),
  ('kinds_checked', ['popup kinds index=0', 'popup kinds path=[0]'], _Page.demo,
      () async {
    await _openMenu('kinds');
    await _shot('kinds_menu');
    await _ax('kinds_menu');
    await _chooseFromEnd(5);
  }),
  ('kinds_unchecked', ['popup kinds index=0', 'popup kinds path=[0]'],
      _Page.demo, () async {
    // The last step unchecked the item: the menu shows it so.
    await _openMenu('kinds');
    await _ax('kinds_menu_unchecked');
    await _chooseFromEnd(5);
  }),
  ('kinds_disabled', <String>[], _Page.demo, () async {
    await _openMenu('kinds');
    await _axPress('kinds_press_disabled', 'Archive');
    await _keys([_escape]);
  }),
  ('kinds_submenu', ['popup kinds index=3', 'popup kinds path=[3, 1]'],
      _Page.demo, () async {
    await _openMenu('kinds');
    await _highlightFromEnd(4); // Move to
    await _keys([_right]); // opens the submenu
    await _shot('kinds_submenu');
    await _ax('kinds_submenu');
    await _chooseFromEnd(1); // Recents
  }),
  ('kinds_svg', ['popup kinds index=4', 'popup kinds path=[4]'], _Page.demo,
      () async {
    await _openMenu('kinds');
    await _chooseFromEnd(3);
  }),
  ('kinds_png', ['popup kinds index=5', 'popup kinds path=[5]'], _Page.demo,
      () async {
    await _openMenu('kinds');
    await _chooseFromEnd(2);
  }),
  ('kinds_custom', ['popup kinds index=6', 'popup kinds path=[6]'], _Page.demo,
      () async {
    await _openMenu('kinds');
    await _chooseFromEnd(1);
  }),
  ('kinds_destructive', ['popup kinds index=8', 'popup kinds path=[8]'],
      _Page.demo, () async {
    await _openMenu('kinds');
    await _highlightFromEnd(0);
    await _shot('kinds_destructive_highlighted');
    await _keys([_return]);
  }),
  ('layout_inline', ['popup layout path=[1, 1]'], _Page.demo, () async {
    await _openMenu('layout');
    await _shot('layout_menu');
    await _ax('layout_menu');
    await _chooseFromEnd(3); // Date
  }),
  ('layout_keeps', ['popup layout path=[3]'], _Page.demo, () async {
    // keepsMenuPresented has no AppKit counterpart: the item fires once and
    // the menu closes, as documented.
    await _openMenu('layout');
    await _chooseFromEnd(1); // Zoom in
    await _ax('layout_after_keeps');
  }),
  ('svg', ['popup svg index=1'], _Page.demo, () async {
    await _openMenu('svg');
    await _shot('svg_menu');
    await _chooseFromEnd(2); // Search
  }),
  ('png', ['popup png index=3'], _Page.demo, () async {
    await _openMenu('png');
    await _shot('png_menu');
    await _chooseFromEnd(1); // Close
  }),
  ('custom', <String>[], _Page.demo, () async {
    await _openMenu('custom');
    await _shot('custom_menu');
    await _keys([_escape]);
  }),
  ('colored', <String>[], _Page.demo, () async {
    await _openMenu('colored');
    await _shot('colored_menu');
    await _keys([_escape]);
  }),
  ('colored_svg', <String>[], _Page.demo, () async {
    await _openMenu('colored_svg');
    await _shot('colored_svg_menu');
    await _keys([_escape]);
  }),
  ('colored_png', <String>[], _Page.demo, () async {
    await _openMenu('colored_png');
    await _shot('colored_png_menu');
    await _keys([_escape]);
  }),
  ('display', <String>[], _Page.display, () async {
    await _openMenu('display');
    await _shot('display_menu');
    await _ax('display_menu');
    await _chooseFromEnd(0); // Tinted
    await _shot('display_after');
  }),
  ('files', <String>[], _Page.files, () async {
    await _openMenu('files');
    await _shot('files_menu');
    await _highlightFromEnd(1); // Sort By
    await _keys([_right]);
    await _shot('files_submenu');
    await _chooseFromEnd(1); // Date
    await _wait(800);
    await _openMenu('files');
    await _highlightFromEnd(1);
    await _keys([_right]);
    await _shot('files_submenu_after');
    await _ax('files_submenu_after');
    await _keys([_escape, _escape]);
  }),
];

/// Every `CNB_RESULT` line printed so far.
final List<String> _results = <String>[];

Future<void> _run() async {
  // The run script moves the window (`CNB_PLACE`): a short one at the top
  // of the screen, so each menu opens below its button with room for every
  // item, and clear of other windows, which would cover it.
  debugPrint('CNB_PLACE');
  await _wait(2500);
  final only = _only.isEmpty ? null : _only.split(',').toSet();
  final failed = <String>[];
  for (final (name, expected, page, step) in _steps) {
    if (only != null && !only.any(name.startsWith)) continue;
    // Other apps on this Mac take the focus now and then, which closes an
    // open menu or sends the keys elsewhere: a step without its results is
    // run again, up to three times.
    var ok = false;
    for (var attempt = 1; attempt <= 3 && !ok; attempt++) {
      debugPrint('CNB_STEP $name${attempt > 1 ? ' (attempt $attempt)' : ''}');
      await _open(page);
      // Front and key again before each step.
      await _audit.invokeMethod<void>('toScreen', {'x': 0.0, 'y': 0.0});
      await _wait(300);
      final before = _results.length;
      await step();
      await _wait(1200);
      final got = _results.skip(before).toList();
      ok = expected.isEmpty
          ? got.isEmpty
          : expected.every((e) => got.any((r) => r.endsWith(e)));
      debugPrint('CNB_CHECK $name ${ok ? 'ok' : 'FAILED'} got=$got');
      // A step that must produce nothing is not repeated.
      if (expected.isEmpty) break;
    }
    if (!ok) failed.add(name);
  }
  debugPrint(
    'CNB_SUMMARY failed=${failed.isEmpty ? 'none' : failed.join(',')}',
  );
  debugPrint('CNB_DONE');
}
