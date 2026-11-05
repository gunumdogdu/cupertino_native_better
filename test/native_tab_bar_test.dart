import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn_native_tab_bar');
  final enables = <Map<Object?, Object?>>[];
  final disables = <String>[];

  var failEnable = false;

  setUp(() {
    enables.clear();
    disables.clear();
    failEnable = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'enable') {
            enables.add(call.arguments as Map<Object?, Object?>);
            if (failEnable) {
              throw PlatformException(code: 'no_window');
            }
          }
          if (call.method == 'disable') disables.add('disable');
          return null;
        });
  });

  tearDown(() async {
    await CNTabBarNative.disable();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  final tabs = [
    CNTab(title: 'Home', sfSymbol: const CNSymbol('house.fill')),
    CNTab(title: 'Search', isSearchTab: true),
  ];

  test(
    'enable shows the close button by default',
    () async {
      await CNTabBarNative.enable(tabs: tabs);
      expect(enables.single['showCloseButton'], isTrue);
    },
    skip: !(Platform.isMacOS || Platform.isIOS),
  );

  test('showCloseButton: false hides it', () async {
    await CNTabBarNative.enable(
      tabs: tabs,
      asRoot: true,
      showCloseButton: false,
    );
    expect(enables.single['showCloseButton'], isFalse);
    expect(enables.single['asRoot'], isTrue);
  }, skip: !(Platform.isMacOS || Platform.isIOS));

  test(
    'a prominent tab is marked; the others carry no key',
    () async {
      await CNTabBarNative.enable(
        tabs: [
          ...tabs,
          CNTab(
            title: 'New',
            sfSymbol: const CNSymbol('plus'),
            isProminent: true,
          ),
        ],
      );
      final sent = (enables.single['tabs'] as List).cast<Map>();
      expect(sent.map((t) => t.containsKey('isProminent')), [
        false,
        false,
        true,
      ]);
      expect(sent.last['isProminent'], isTrue);
    },
    skip: !(Platform.isMacOS || Platform.isIOS),
  );

  group('macOS', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      // The window's sidebar needs no Liquid Glass: every macOS has it.
      PlatformVersion.debugOverrideVersions(macOSVersion: 15);
    });
    tearDown(PlatformVersion.reset);

    test(
      'enable sends the tabs on every macOS, isDark only when given',
      () async {
        final events = <String>[];
        await CNTabBarNative.enable(
          tabs: tabs,
          selectedIndex: 0,
          onTabSelected: (i) => events.add('tab $i'),
          onSearchChanged: (q) => events.add('search $q'),
          onListItemTap: (t, i) => events.add('item $t $i'),
        );
        expect(CNTabBarNative.isEnabled, isTrue);
        final args = enables.single;
        expect((args['tabs'] as List).length, 2);
        expect((args['tabs'] as List).last, containsPair('isSearch', true));
        expect(
          args.containsKey('isDark'),
          isFalse,
          reason: 'follows the system',
        );

        Future<void> fromNative(String method, Object? args) =>
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
                  channel.name,
                  channel.codec.encodeMethodCall(MethodCall(method, args)),
                  (_) {},
                );
        await fromNative('onTabSelected', {'index': 1});
        await fromNative('onSearchChanged', {'query': 'ad'});
        await fromNative('onListItemTap', {'tabIndex': 1, 'itemIndex': 0});
        expect(events, ['tab 1', 'search ad', 'item 1 0']);
      },
      skip: !Platform.isMacOS,
    );

    test('isDark is sent when given', () async {
      await CNTabBarNative.enable(tabs: tabs, isDark: true);
      expect(enables.single['isDark'], isTrue);
    }, skip: !Platform.isMacOS);

    test('no window: enable leaves the bar disabled', () async {
      failEnable = true;
      await CNTabBarNative.enable(tabs: tabs);
      expect(enables, hasLength(1));
      expect(CNTabBarNative.isEnabled, isFalse);
    }, skip: !Platform.isMacOS);

    test(
      'disable reaches the window even after a hot restart',
      () async {
        // The restarted Dart side does not know about the sidebar the window
        // still shows.
        expect(CNTabBarNative.isEnabled, isFalse);
        await CNTabBarNative.disable();
        expect(disables, ['disable']);
      },
      skip: !Platform.isMacOS,
    );
  });

  test(
    'iOS keeps the disable guard; without isDark (light there) no key',
    () async {
      await CNTabBarNative.disable();
      expect(disables, isEmpty);
      await CNTabBarNative.enable(tabs: tabs);
      expect(enables.single.containsKey('isDark'), isFalse);
    },
    skip: !(Platform.isMacOS || Platform.isIOS),
  );
}
