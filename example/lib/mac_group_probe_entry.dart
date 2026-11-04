// macOS probe for CNGlassButtonGroup and CNProgressIndicator: opens a demo
// page, clicks through the app's own event queue (cnb_mac_audit) and prints
// what the widgets report.
//
//   flutter run -d macos -t lib/mac_group_probe_entry.dart
//     --dart-define=PAGE=group|progress [--dart-define=BRIGHTNESS=dark]

import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'demos/glass_button_group.dart';
import 'demos/progress_indicator.dart';

const MethodChannel _audit = MethodChannel('cnb_mac_audit');
const String _page = String.fromEnvironment('PAGE', defaultValue: 'group');
const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [CNTabBarRouteObserver()],
      theme: CupertinoThemeData(
        brightness: _brightness == 'dark' ? Brightness.dark : Brightness.light,
      ),
      home: _page == 'progress'
          ? const ProgressIndicatorDemoPage()
          : const GlassButtonGroupDemoPage(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_drive()));
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Future<void> _shot(String name) async {
  debugPrint('PROBE_SHOT $name');
  await _wait(2500);
}

/// Rect of the [index]th widget of type [T], in global coordinates.
Rect? _rect<T extends Widget>([int index = 0]) {
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
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> _click(Offset p) =>
    _audit.invokeMethod<void>('click', {'x': p.dx, 'y': p.dy});

Future<void> _drive() async {
  await _wait(3500);
  if (_page == 'progress') {
    // Activates the window, so the indicators show their colours.
    await _click(const Offset(400, 700));
    await _wait(1000);
    await _shot('page');
    await _wait(1500);
    await _shot('later');
    debugPrint('PROBE done');
    return;
  }
  await _shot('page');
  // Activates the window: an inactive window takes the first click itself.
  await _click(const Offset(400, 600));
  await _wait(600);

  // The first group is centred: four 44 pt buttons, 8 pt apart, in a view
  // 6 pt wider than the row.
  final union = _rect<CNGlassButtonGroup>(0)!;
  final rowWidth = union.width - 6;
  const groupWidth = 4 * 44 + 3 * 8.0;
  final left = union.left + (rowWidth - groupWidth) / 2;
  final y = union.top + 3 + 22;
  for (final i in [0, 0, 1, 3]) {
    debugPrint('PROBE click format $i');
    await _click(Offset(left + i * 52 + 22, y));
    await _wait(600);
  }
  await _click(Offset(left + 3 * 52 + 22, y));
  await _wait(600);

  // The second group: the badge button, then the menu (Down, Return picks
  // its first item while it is open).
  final second = _rect<CNGlassButtonGroup>(1)!;
  final secondY = second.top + 3 + 22;
  // Three buttons: 44, 44 and the labelled one (about 112), centred.
  final rowCenter = second.left + (second.width - 6) / 2;
  final badgeX = rowCenter - (44 + 8 + 44 + 8 + 112) / 2 + 22;
  await _click(Offset(badgeX, secondY));
  await _wait(600);
  await _shot('badge_changed');
  await _audit.invokeMethod<void>('type', {
    'keyCodes': [125, 36],
    'delayMs': 1200,
  });
  await _click(Offset(badgeX + 52, secondY));
  await _wait(2500);
  await _shot('after_menu');
  debugPrint('PROBE done');
}
