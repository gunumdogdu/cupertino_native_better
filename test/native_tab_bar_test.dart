import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn_native_tab_bar');
  final enables = <Map<Object?, Object?>>[];

  setUp(() {
    enables.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'enable') {
            enables.add(call.arguments as Map<Object?, Object?>);
          }
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
}
