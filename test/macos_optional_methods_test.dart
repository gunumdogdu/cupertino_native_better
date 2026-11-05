// #47: a call the macOS side does not implement ends in a
// MissingPluginException. Widgets send most calls from didUpdateWidget
// without awaiting them, so such an exception escapes as an uncaught async
// error, and a debugger that breaks on uncaught exceptions pauses the UI
// isolate on it, which on macOS (merged platform and UI threads) is the main
// thread: the app hangs.
//
// Two guards, neither of which lists what macOS happens to lack today:
// - every method a widget sends with invokeMethod is one its macOS view (or
//   the plugin) answers, read from the Dart and Swift sources;
// - every method a widget sends with invokeOptionalMethod (the calls a
//   platform may leave out) is harmless when the native side lacks it.

import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/optional_method_call.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _macSources =
    'macos/cupertino_native_better/Sources/cupertino_native_better';

/// Methods a widget may send with invokeMethod although macOS does not
/// answer them, because only its iOS code path sends them. Empty: add a
/// method here only with the reason it can never reach macOS.
const Map<String, Set<String>> _iosOnlyPaths = {};

/// The `'name'` of every `.invokeMethod('name'` (or `invokeMapMethod`) in
/// [source], and of the components' `_invoke(channel, 'name'` and
/// `_invoke('name'` helpers.
Set<String> _requiredCalls(String source) => {
  for (final m in RegExp(
    r"\.invoke(?:Map|List)?Method(?:<[^>]*>)?\(\s*'(\w+)'",
  ).allMatches(source))
    m.group(1)!,
  for (final m in RegExp(
    r"_invoke(?:<[^>]*>)?\(\s*(?:\w+,\s*)?'(\w+)'",
  ).allMatches(source))
    m.group(1)!,
};

/// Window-level channels (no platform view) that macOS never opens, with
/// the reason. `cn_foldable` is iPhone Duo hardware; its Dart side returns
/// early off iOS.
const Map<String, String> _iosOnlyChannels = {'cn_foldable': 'iPhone Duo only'};

/// The `'name'` of every `.invokeOptionalMethod('name'` in [source].
Set<String> _optionalCalls(String source) => {
  for (final m in RegExp(
    r"\.invokeOptionalMethod\(\s*'(\w+)'",
  ).allMatches(source))
    m.group(1)!,
};

/// Every `case "a", "b":` string of the Swift files that handle [channel].
Set<String> _swiftCases(Iterable<File> files) => {
  for (final f in files)
    for (final c in RegExp(
      r'case\s+((?:"\w+"\s*,?\s*)+):',
    ).allMatches(f.readAsStringSync()))
      for (final n in RegExp(r'"(\w+)"').allMatches(c.group(1)!)) n.group(1)!,
};

List<File> _swiftFiles() => Directory(_macSources)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.swift'))
    .toList();

List<File> _componentFiles() => Directory('lib/components')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// The channel prefix (`CupertinoNativeButton` for
/// `MethodChannel('CupertinoNativeButton_$id')`) of a component's source.
String? _channelPrefix(String source) =>
    RegExp(r"MethodChannel\('(\w+)_\$").firstMatch(source)?.group(1);

/// What each platform view channel is sent with optional calls, by prefix.
Map<String, Set<String>> _optionalCallsByChannel() => {
  for (final f in _componentFiles())
    if (_channelPrefix(f.readAsStringSync()) case final prefix?)
      prefix: _optionalCalls(f.readAsStringSync()),
};

/// Window-level channels (no platform view): the Dart file that sends on
/// each and the macOS Swift file that answers it.
const Map<String, (String, String)> _windowChannels = {
  'cn_toolbar': ('lib/components/toolbar.dart', 'CNToolbarManager.swift'),
};

/// The `'name'` of every `_invoke('name'` and `invokeFor(this, 'name'` in
/// [source]: the calls a window channel's Dart code sends.
Set<String> _windowCalls(String source) => {
  for (final m in RegExp(
    r"(?:_invoke|invokeFor)\((?:this,\s*)?'(\w+)'",
  ).allMatches(source))
    m.group(1)!,
};

/// The view types every channel below mocks, and so the widgets the host
/// builds.
const _viewTypes = <String>[
  'CupertinoNativeButton',
  'CupertinoNativeSwitch',
  'CupertinoNativeSlider',
  'CupertinoNativeSegmentedControl',
  'CupertinoNativePopupMenuButton',
  'CupertinoNativeProgressIndicator',
  'CupertinoNativePopUpButton',
  'CupertinoNativeGauge',
  'CupertinoNativeTabBar',
  'CNSearchBar',
];

class _Host extends StatefulWidget {
  const _Host({super.key, required this.search});

  final CNTabBarSearchController search;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool on = false;

  void toggle() => setState(() => on = !on);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    theme: CupertinoThemeData(
      brightness: on ? Brightness.dark : Brightness.light,
    ),
    home: CupertinoPageScaffold(
      child: ListView(
        children: [
          Row(
            children: [
              CNButton(
                label: 'Theme',
                semanticLabel: on ? 'Switch to light' : 'Switch to dark',
                config: CNButtonConfig(
                  interaction: !on,
                  labelFontSize: on ? 17 : null,
                ),
                onPressed: () {},
              ),
              CNSwitch(
                value: on,
                semanticLabel: on ? 'Dark' : 'Light',
                onChanged: (_) {},
              ),
              CNPopupMenuButton(
                buttonLabel: 'Menu',
                semanticLabel: on ? 'More, dark' : 'More',
                items: const [CNPopupMenuItem(label: 'One')],
                onSelected: (_) {},
              ),
            ],
          ),
          CNSlider(
            value: 0.5,
            semanticLabel: on ? 'Volume, dark' : 'Volume',
            onChanged: (_) {},
          ),
          CNSegmentedControl(
            labels: const ['A', 'B'],
            selectedIndex: 0,
            semanticLabel: on ? 'Mode, dark' : 'Mode',
            onValueChanged: (_) {},
          ),
          CNProgressIndicator(
            value: on ? 0.8 : 0.2,
            tint: on ? CupertinoColors.systemPink : null,
          ),
          CNPopUpButton<int>(
            value: on ? 1 : 0,
            items: const [
              CNPopUpButtonItem(value: 0, label: 'A'),
              CNPopUpButtonItem(value: 1, label: 'B'),
            ],
            semanticLabel: on ? 'Pick, dark' : 'Pick',
            buttonStyle: on ? CNButtonStyle.glass : null,
            onChanged: (_) {},
          ),
          CNGauge(
            value: on ? 0.8 : 0.2,
            tint: on ? CupertinoColors.systemPink : null,
          ),
          CNSearchBar(placeholder: on ? 'Find' : 'Search'),
          CNTabBar(
            items: const [
              CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
              CNTabBarItem(label: 'Files', icon: CNSymbol('folder')),
            ],
            currentIndex: 0,
            onTap: (_) {},
            searchItem: const CNTabBarSearchItem(placeholder: 'Search'),
            searchController: widget.search,
          ),
        ],
      ),
    ),
  );
}

void main() {
  test('every method sent with invokeMethod is answered on macOS', () {
    final swift = _swiftFiles();
    final missing = <String>[];

    // The plugin's own channel (CNTransitionObserver's beginTransition and
    // endTransition, sent unawaited on every route change, among them).
    final pluginCalls = _requiredCalls(
      File('lib/cupertino_native_method_channel.dart').readAsStringSync(),
    );
    final pluginCases = _swiftCases(
      swift.where((f) => f.path.endsWith('/CupertinoNativePlugin.swift')),
    );
    for (final m in pluginCalls.difference(pluginCases)) {
      missing.add('cupertino_native: $m');
    }

    // Each component's platform view channel.
    var checked = 0;
    for (final file in _componentFiles()) {
      final source = file.readAsStringSync();
      final prefix = _channelPrefix(source);
      if (prefix == null) continue;
      final handlers = swift
          .where((f) => f.readAsStringSync().contains('"${prefix}_\\('))
          .toList();
      if (handlers.isEmpty) {
        // An iOS-only widget; it must not create an AppKit view either.
        expect(
          source.contains('AppKitView('),
          isFalse,
          reason: '${file.path} creates an AppKitView that macOS lacks',
        );
        continue;
      }
      checked++;
      final name = file.uri.pathSegments.last;
      final allowed = _iosOnlyPaths[name] ?? const <String>{};
      final unanswered = _requiredCalls(
        source,
      ).difference(_swiftCases(handlers)).difference(allowed);
      for (final m in unanswered) {
        missing.add('$name ($prefix): $m');
      }
    }

    expect(checked, greaterThan(10), reason: 'the sources were not found');
    expect(
      missing,
      isEmpty,
      reason:
          'implement these in the macOS view, or send them with '
          'invokeOptionalMethod if macOS cannot have them',
    );
  });

  test('every method sent on a window-level channel is answered on macOS', () {
    // Channels with no platform view (alerts, action sheets, menus,
    // popovers): `MethodChannel('cn_…')` in Dart, a manager owning
    // `FlutterMethodChannel(name: "cn_…")` in Swift.
    // Channels a platform never uses on macOS (CNFoldable: iPhone Duo).
    final iosOnly = _iosOnlyChannels.keys.toSet();
    final swift = _swiftFiles();
    final dart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final missing = <String>[];
    final checked = <String>{};
    for (final file in dart) {
      final source = file.readAsStringSync();
      for (final m in RegExp(
        r"MethodChannel\('(cn_\w+)'\)",
      ).allMatches(source)) {
        final name = m.group(1)!;
        if (iosOnly.contains(name)) continue;
        final owners = swift
            .where(
              (f) => f.readAsStringSync().contains(
                'FlutterMethodChannel(name: "$name"',
              ),
            )
            .toList();
        if (owners.isEmpty) {
          missing.add('$name: no macOS manager');
          continue;
        }
        checked.add(name);
        for (final call in _requiredCalls(
          source,
        ).difference(_swiftCases(owners))) {
          missing.add('$name: $call');
        }
      }
    }
    expect(
      checked,
      containsAll([
        'cn_alert',
        'cn_action_sheet',
        'cn_context_menu',
        'cn_popover',
        'cn_native_tab_bar',
        'cn_native_sheet',
      ]),
    );
    expect(missing, isEmpty);
  });

  test('every method sent on a window channel is answered on macOS', () {
    for (final MapEntry(key: channel, value: (dart, swiftName))
        in _windowChannels.entries) {
      final calls = _windowCalls(File(dart).readAsStringSync());
      expect(calls, isNotEmpty, reason: '$dart sends nothing on $channel');
      final handlers = _swiftFiles()
          .where((f) => f.path.endsWith('/$swiftName'))
          .toList();
      expect(handlers, hasLength(1), reason: '$swiftName not found');
      expect(handlers.single.readAsStringSync(), contains('"$channel"'));
      expect(
        calls.difference(_swiftCases(handlers)),
        isEmpty,
        reason: '$channel: implement these in $swiftName',
      );
    }
  });

  group('a native side without the optional methods', () {
    final calls = <String>[];
    late Map<String, Set<String>> optional;

    setUp(() {
      calls.clear();
      optional = _optionalCallsByChannel();
    });

    void mockNative(WidgetTester tester) {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async => null,
      );
      for (final type in _viewTypes) {
        for (var id = 0; id < 40; id++) {
          messenger.setMockMethodCallHandler(MethodChannel('${type}_$id'), (
            call,
          ) async {
            calls.add(call.method);
            if (optional[type]?.contains(call.method) ?? false) {
              throw MissingPluginException();
            }
            if (call.method == 'getIntrinsicSize') {
              return {'width': 200.0, 'height': 44.0};
            }
            return null;
          });
        }
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final type in _viewTypes) {
          for (var id = 0; id < 40; id++) {
            messenger.setMockMethodCallHandler(
              MethodChannel('${type}_$id'),
              null,
            );
          }
        }
      });
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets(
      'updates that send them throw nothing, and still send them',
      (tester) async {
        expect(optional.values.expand((m) => m), isNotEmpty);
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        mockNative(tester);
        final search = CNTabBarSearchController();
        final host = GlobalKey<_HostState>();
        await tester.pumpWidget(_Host(key: host, search: search));
        await settle(tester);

        host.currentState!.toggle();
        search.activateSearch();
        await settle(tester);
        host.currentState!.toggle();
        search.deactivateSearch();
        await settle(tester);

        expect(tester.takeException(), isNull);
        // Sent all the same, so a platform that has them (iOS) gets them.
        expect(
          calls,
          containsAll(<String>[
            'setSemanticLabel',
            'setInteraction',
            'setLabelStyle',
            'setValue',
            'setConfig',
            'activateSearch',
            'deactivateSearch',
          ]),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        search.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
      // The native path needs PlatformVersion's real platform: a Mac.
      skip: !Platform.isMacOS,
    );
  });

  group('invokeOptionalMethod', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('optional_method_test');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('ignores a method the native side does not implement', () async {
      await expectLater(channel.invokeOptionalMethod('missing'), completes);
    });

    test('still reports other errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'bad_args'),
          );
      await expectLater(
        channel.invokeOptionalMethod('broken'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
